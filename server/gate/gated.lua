local skynet = require "skynet"
local gateserver = require "snax.gateserver"
local netpack = require "skynet.netpack"

local watchdog
local connection = {} -- fd -> connection : { fd , uid, agent , ip }
local forwarding = {} -- agent -> connection

local user_cnt = 0

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT
}

local handler = {}

function handler.open(source, conf)
    watchdog = conf.watchdog or source
end

function handler.message(fd, msg, sz)
    -- recv a package, forward it
    --LOG_DEBUG("recive:" .. sz)
    local c = connection[fd]
    local agent = c.agent
    if agent then
        skynet.send(agent, "lua", "websocket_dispatch", netpack.tostring(msg, sz))
        -- skynet.redirect(agent, 0, "client", 1, msg, sz)
    else
        skynet.send(watchdog, "lua", "socket", "auth", fd, sz, netpack.tostring(msg, sz))
    end
end

function handler.connect(fd, addr)
    local c = {
        fd = fd,
        ip = addr
    }
    connection[fd] = c
    LOG_DEBUG("connect:" .. fd)
    skynet.send(watchdog, "lua", "socket", "open", fd, addr)
end

local function unforward(c)
    if c.agent then
        forwarding[c.agent] = nil
        c.agent = nil
        c.uid = nil
    end
end

local function close_fd(fd)
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

function handler.disconnect(fd)
    -- 只要调用了gateserver.closeclient(fd)，一定会调用到这里
    LOG_DEBUG("disconnect:" .. fd)
    close_fd(fd)
end

function handler.error(fd, msg)
    close_fd(fd)
end

function handler.warning(fd, size)
    if size > 1000 * 1024 then
        LOG_DEBUG("有数据包太大了，踢了")
        CMD.kick(nil, fd)
    end
end

local CMD = {}

function CMD.forward(source, fd, uid, address)
    -- local c = assert(connection[fd])
    -- print("client="..tostring(uid))
    user_cnt = user_cnt + 1
    c = connection[fd]
    if not c then
        LOG_DEBUG("登陆的时候用户已经下线:" .. fd)
        skynet.send(source, "lua", "kick")
        return
    end
    LOG_DEBUG("user count:" .. user_cnt)
    unforward(c)
    c.uid = uid or 0 --暂时无用
    c.agent = address or source --anget的地址
    forwarding[c.agent] = c
    -- gateserver.openclient(fd)
end

function CMD.reqCl()
    -- body
end

function CMD.accept(source, fd)
    local c = assert(connection[fd])
    unforward(c)
    gateserver.openclient(fd)
end

function CMD.agent_stop(source, fd)
    user_cnt = user_cnt - 1
    CMD.stop(source, fd)
end

function CMD.stop(source, fd, reason)
    LOG_DEBUG("stop:" .. fd)

    if reason then
        LOG_DEBUG("reason = " .. reason)
        reason = tonumber(reason)
        if reason == 110 then
        -- 服务器已经关闭，需要通知客户端
        -- ws:send_binary(string.pack(">s2", string.pack(">I2I4", 1, reason)))
        -- local package = string.pack(">s2", pack)
        -- return socket.write(fd, package)
        end
    end
    gateserver.closeclient(fd)
    -- LOG_DEBUG("kick done:"..fd)
end

-- 将用户踢出去，注意与close的区别，close只是关闭链接，kick的话还会去通知agent做离线之前的准备工作
function CMD.kick(source, fd, reason)
    local c = connection[fd]
    if c and c.agent then
        pcall(skynet.call, c.agent, "lua", "kick", reason)
    else
        gateserver.closeclient(fd)
    end
end

function CMD.heart()
    return user_cnt or 0
end

function CMD.ctrl(cmd)
    -- 1 停服，踢出所有玩家
    -- 2 滚服，不踢出玩家
    -- 3 重新开启服务
    LOG_DEBUG("收到服务器指令:" .. cmd)
end

function handler.command(cmd, source, ...)
    local f = assert(CMD[cmd])
    return f(source, ...)
end

gateserver.start(handler)
