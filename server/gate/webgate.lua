local skynet = require "skynet"

local netpack = require "skynet.netpack"


local skynet = require "skynet"
local socket = require "skynet.socket"
local string = require "string"
local websocket = require "websocket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"


local watchdog
local connection = {}   -- fd -> connection : { fd , uid, agent , ip }
local forwarding = {}   -- agent -> connection

local ids = {} -- id -> ws

local user_cnt = 0

-- skynet.register_protocol {
--     name = "client",
--     id = skynet.PTYPE_CLIENT,
-- }

local handler = {}
local CMD = {}

local function handler_data(ws, fd)
    while ws and ws.buffer and #ws.buffer >= ws.waitSize  do
        if ws.waitSize < 1 then
            if #ws.buffer < 2 then
                break
            end
            -- local msgid = string.unpack(">I2", data)
            ws.waitSize = string.unpack(">I2", ws.buffer)
            ws.buffer = ws.buffer:sub(3)
            if ws.waitSize > 1024 then
                -- function CMD.kick(source, fd, reason)
                skynet.fork(CMD.kick, skynet.self(), fd, 5)
                LOG_ERROR("玩家协议数据过大，踢出游戏:"..fd)
                break
            end
        elseif #ws.buffer >= ws.waitSize then
            local data = ws.buffer:sub(1, ws.waitSize)
            ws.buffer = ws.buffer:sub(ws.waitSize+1)
            ws.waitSize = 0
            local c = connection[fd]
            local agent = c.agent
            if agent then
                skynet.send(agent, "lua", "websocket_dispatch", data)
            else
                -- data = data:unpack(">cn")
                LOG_DEBUG(data)
                -- LOG_DEBUG(string.unpack(">s", data))
                -- LOG_DEBUG("=========================")
                skynet.send(watchdog, "lua", "socket", "auth", fd, data)
            end
        end
    end
end

function handler.on_message(ws, message)
    -- recv a package, forward it
    ws.buffer = ws.buffer .. message
    handler_data(ws, ws.id)
end

function handler.on_open(ws)
    local fd = ws.id
    local addr = "0"
    local c = {
        fd = fd,
        ip = addr,
    }
    connection[fd] = c
    ids[fd] = ws
    -- luadump(connection)
    skynet.call(watchdog, "lua", "socket", "open", fd, addr)
    -- ws:start()
end

local function unforward(c)
    if c.agent then
        forwarding[c.agent] = nil
        c.agent = nil
        c.uid = nil
    end
end

local function close_fd(fd)
    LOG_DEBUG("用户离线,fd="..fd)
    local c = connection[fd]
    if c then
        if c.agent then
            skynet.send(c.agent, "lua", "kick", 0)
            skynet.send(watchdog, "lua", "kick", c.uid)
        end
        unforward(c)
        connection[fd] = nil
    end
end

function handler.on_close(ws, code, reason)
    -- 只要调用了gateserver.closeclient(fd)，一定会调用到这里
    -- 现在怀疑调用了ws:close()，但是没有调到这里
    local fd = ws.id
    ws.buffer = nil
    ws.waitSize = nil
    LOG_DEBUG("disconnect:"..fd)
    ids[fd] = nil
    close_fd(fd)
end

local function handle_socket(id)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    LOG_DEBUG("handle_socket:"..id)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), nil)
    LOG_DEBUG(code..","..tostring(url)..","..tostring(method)..","..tostring(header)..","..tostring(body))
    if code then
        
        if url == "/ws" then
            local ws = websocket.new(id, header, handler)
            ws.buffer = ""
            ws.waitSize = 0
            ws:start()
        end
    end

end

function CMD.open(source, conf)
    watchdog = conf.auth

    local address = "0.0.0.0:"..conf.port
    LOG_DEBUG("Listening "..address)
    local id = assert(socket.listen(address)) --socket.listen(address, port)监听一个端口，返回一个 id ，供 start 使用。
    socket.start(id , function(id, addr)
       socket.start(id)
       pcall(handle_socket, id)
    end)
end

function CMD.forward(source, fd, uid, address)
    -- local c = assert(connection[fd])
    -- print("client="..tostring(uid))
    user_cnt = user_cnt + 1
    c = connection[fd]
    if not c then
        LOG_DEBUG("登陆的时候用户已经下线:"..fd)
        skynet.send(source, "lua", "kick")
        return
    end
    LOG_DEBUG("user count:"..user_cnt)
    unforward(c)
    c.uid = uid or 0 --暂时无用
    c.agent = address or source --anget的地址
    forwarding[c.agent] = c
    -- gateserver.openclient(fd)
end

function CMD.accept(source, fd)
    LOG_DEBUG("accept:"..fd)
    local ws = ids[fd]
    if not ws then
        LOG_DEBUG("error fd in CMD.accept:"..fd)
        return
    end
    
    local c = assert(connection[fd])
    unforward(c)
    -- LOG_DEBUG("done !!!!!!!!!")
    -- gateserver.openclient(fd)
    -- ws:start()
    -- skynet.fork(ws.start, ws)
end

function CMD.agent_stop(source, fd)
    user_cnt = user_cnt - 1
    CMD.stop(source, fd)
end

function CMD.stop(source, fd, reason)
    LOG_DEBUG(source..":::".."stop:"..fd)
    local ws = ids[fd]
    if not ws then
        LOG_DEBUG("error fd in CMD.stop:"..fd)
        return
    end
    if reason then
        LOG_DEBUG("reason = "..reason)
        reason = tonumber(reason)
        if reason == 110 then
            -- 服务器已经关闭，需要通知客户端
            ws:send_binary(string.pack(">s2", string.pack(">I2I4", 1, reason)))
        end
    end
    handler.on_close(ws)
    skynet.fork(ws.close, ws)
    -- gateserver.closeclient(fd)
    -- LOG_DEBUG("kick done:"..fd)
end

function CMD.heart()
    return user_cnt or 0
end

function CMD.ctrl(source, cmd)
    -- 1 停服，踢出所有玩家
    -- 2 滚服，不踢出玩家
    -- 3 重新开启服务
    LOG_DEBUG("收到服务器指令:"..cmd)

    skynet.call(watchdog, "lua", "ctrl", cmd)

    if cmd == 1 then
        for fd,ws in pairs(ids) do
            if fd and ws then
                local c = connection[fd]
                if c and c.agent then
                    pcall(skynet.call, c.agent, "lua", "kick", 9)
                else
                    skynet.fork(ws.close, ws)
                end
            end
        end
    end

    return true
end

-- 将用户踢出去，注意与close的区别，close只是关闭链接，kick的话还会去通知agent做离线之前的准备工作
-- 给loginstatus用的
function CMD.kick(source, fd, reason)
    LOG_DEBUG("kick fd:"..fd..","..reason)
    local ws = ids[fd]
    if not ws then
        LOG_DEBUG("error fd in CMD.kick:"..fd)
        return
    end

    local c = connection[fd]
    if c and c.agent then
        pcall(skynet.call, c.agent, "lua", "kick", reason)
    else
        skynet.fork(ws.close, ws)
    end
end

function CMD.send_package(source, fd, uid , package)
    local ws = ids[fd]
    local c = connection[fd]
    if c and ws and c.uid == uid then
        -- LOG_DEBUG("发送协议大小："..#package)
        ws:send_binary(package)
    end
end


skynet.start(function()

    skynet.dispatch("lua", function(session, source, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(source, ...)))
    end)

end)

