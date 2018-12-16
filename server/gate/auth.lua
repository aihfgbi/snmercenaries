local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local cluster = require "skynet.cluster"
local crypt = require "skynet.crypt"
local json = require "cjson"
local protobuf = require "protobuf"

local LOGIN_TIMEOUT = 5 --秒

local USE_DEBUG = skynet.getenv "use_debug"
local verificationCode = skynet.getenv "verification_code"

local nodename = skynet.getenv "nodename"
local dbs_count = skynet.getenv "dbs_count"
dbs_count = tonumber(dbs_count)

local base64encode = crypt.base64encode
local base64decode = crypt.base64decode
local get_userdata = get_userdata

local CMD = {}
local SOCKET = {}
local gate
local login
local gate_type
local active = false --服务器还没准备好
local disable = false

local unlogined = {} -- fd ==> addr
local loginning = {} -- uid ==> fd
local sessionlist = {} -- fd ==> session

local dbs_list = {}

local redis

local socket = require "skynet.socket"
--暂时先放在这里
local rootpath = "../serviceqq/"
local msgcmd

local function get_userdata(uid)
    local index =  0-- uid % dbs_count
    --LOG_DEBUG("index=="..index..",uid="..uid..",dbs_count="..dbs_count)
    -- index = index + 1
    local dbs = dbs_list[index]
    local node = "dbs" .. index
    --LOG_DEBUG("node=="..node)
    if not dbs then
        local ok, id = pcall(cluster.query, node, "manager") --远端可以通过调用 cluster.query(node, name) 查询到这个名字对应的数字地址。如果名字不存在，则抛出 error 。
        if not ok then
            return false
        end

        dbs = id
        dbs_list[index] = id
    end

    local ok, addr = pcall(cluster.call, node, dbs, "forward", uid, nodename) --调用了usermanager里面的 -- CMD.forward
    if not ok then
        dbs_list[index] = nil
        LOG_DEBUG("error forward:"..addr)
        return false
    end

    return node, addr
end

-- 创建网关心跳的组播
local function create_heart_cast()
    while true do
        for i = 1, dbs_count do
            local addr = dbs_list[i]
            if not addr then
                local ok, id = pcall(cluster.query, "dbs" .. (i-1), "manager")
                if ok and id then
                    addr = id
                    dbs_list[i] = addr
                end
            end

            if addr then
                local ok, result = pcall(cluster.call, "dbs" .. (i-1), addr, "gate_heart", nodename)
                if not ok then
                    LOG_ERROR("gate_heart error!!!!!------" .. tostring(result))
                    dbs_list[i] = nil
                end
            end
        end

        skynet.sleep(5 * 100)
    end
end

--连接login服务
local function connect_to_login(first)
    while true do
        local ok, id = pcall(cluster.query, "login", "loginstatus")
        if ok and id then
            LOG_DEBUG("connected with login service,gate is ready!")
            if first then
                pcall(cluster.call, "login", id, "gate_online", nodename, gate)
            end
            login = id
            active = true
            break
        end
        LOG_DEBUG("wait for login service!!!")
        skynet.sleep(5 * 100)
    end
end

--[[
    @desc: 发送消息
    author:{author}
    time:2018-12-06 22:57:52
    @return:
]]
local function send_msg_to_client(fd, cmd, msg)
    if not cmd or not msg then
        LOG_DEBUG("没有找到cmd")
        return
    end
    local len = string.len(msg)
    local tmp = string.format(">I4>I4c%d", len)
    local package = string.pack(tmp, cmd, len + 8, msg)
    socket.write(fd, package)
    LOG_DEBUG("发送信息成功" .. cmd)
    return
end

--数据错误全部返回 		199
--连接断开了			198
--服务器还没准备好		101
--设备绑定错误       	103
--重复登录请求 		 	104 (等待2秒重试)
--需要重新登录		 	200
--账号被冻结			105
--验证账号冻结出错      106
--redis链接失败			107
--token验证不通过       108
--php设置的用户信息有误 109
--服务器已经关闭		110

-- 这里会有一个理论上会出现的BUG，滚服的时候，玩家在旧服务器处于启动agent的状态，重复登陆验证已经通过，但是还没注册到login服务
-- 这时候新服务器同一个玩家也连上来了，重复验证也已经通过，那么会出现同一个玩家，同时在新旧服务器上登陆，所以，滚服的时候，要求
-- 输入滚服命令5秒之后再迁移服务器
--[[
    @desc: 验证登录命令，如果不是登录命令直接断掉链接
    author:{author}
    time:2018-10-12 17:41:12
    --@fd:
	--@msg: 
    @return:
]]
local function do_auth(fd, msg)
    if disable then
        return 110
    end
    if unlogined[fd] then
        unlogined[fd] = nil
        -- 解析proto
        local ok, pbmsg = pcall(protobuf.decode, "hall.reqLogin", msg)
        if not ok then
            return 199
        end
        
        local token = tostring(pbmsg.token)
        -- 去reids里面取用户信息
        local ok, uid = pcall(skynet.call, redis, "lua", "execute", "get", "USER-LOGIN-"..token)
        if not ok then
            LOG_DEBUG("redis链接失败")
            return 107
        end
        if not uid then
            LOG_DEBUG("token错误，没有获取到用户数据:"..token)
            return 108
        end

        if loginning[uid] then
            return 104
        end
        if not active then
            return 101
        end
        loginning[uid] = fd

        -- 验证重复登陆
        -- CMD.user_online(uid, node, addr, fd)
        local ok, result = pcall(cluster.call, "login", login, "user_online", uid, nodename, gate, fd)
        if not ok then
            LOG_DEBUG("disconnected with login service!!!")
            active = false
            loginning[uid] = nil
            sessionlist[fd] = nil
            skynet.fork(connect_to_login)
            return 101
        end

        local dbsnode, dbsaddr = get_userdata(uid)
        if not dbsnode or not dbsaddr then
            LOG_DEBUG("disconnected with data service!!!")
            loginning[uid] = nil
            sessionlist[fd] = nil
            return 101
        end

        local a = skynet.newservice("agent") --验证成功后启动一个代理来跑这个用户，并调用start函数
        local ok,
            result =
            pcall(
            skynet.call,
            a,
            "lua",
            "start",
            {
                gate = gate,
                client = fd,
                uid = uid,
                auth = skynet.self(),
                dbs_count = dbs_count,
                nodename = nodename,
                dbnode = dbsnode,
                dbaddr = dbsaddr,
                gate_type = gate_type,
                session = sessionlist[fd]
            }
        )
        loginning[uid] = nil
        sessionlist[fd] = nil
        if not ok or not result then --启动失败返回数据错误
            return 199
        end
        LOG_DEBUG("login success:" .. fd)
        return
    end
end

-- 当5秒没有握手成功，那么需要关闭链接
local function kick_unlogined_fd(fd)
    skynet.sleep(LOGIN_TIMEOUT * 100)
    if unlogined[fd] then
        LOG_DEBUG("登录超时，踢出:" .. fd)
        skynet.call(gate, "lua", "stop", fd)
        unlogined[fd] = nil
        sessionlist[fd] = nil
    end
end

function SOCKET.open(fd, addr)
    skynet.error("New client from : " .. addr .. ",fd=" .. tostring(fd))
    unlogined[fd] = addr
    -- skynet.sleep(3*100)
    skynet.fork(kick_unlogined_fd, fd)
    skynet.call(gate, "lua", "accept", fd)
    --返回连接成功
    send_msg_to_client(fd, msgcmd["hall.resConnect"], "success")
end



--[[
    @desc: 收到消息执行验证
    author:{author}
    time:2018-12-06 23:38:51
    --@fd:
	--@sz:
	--@msg: 
    @return:
]]
function SOCKET.auth(fd, sz, msg)
    --解析cmd
    local cmd = tonumber(string.sub(msg, 1, 5))
    LOG_DEBUG("cmd:" .. cmd .. ",sz:" .. sz)
    local session = string.sub(msg, 6, 9)
    if cmd == msgcmd["hall.reqVerification"] then --验证
        local code = string.sub(msg, 10, sz)
        -- LOG_DEBUG("code:" .. code .. ",verificationCode:" .. verificationCode)
        if session == "0000" and code == verificationCode then
            local tmp = RAND_STR(4)
            sessionlist[fd] = tmp
            send_msg_to_client(fd, msgcmd["hall.resVerification"], tmp)
        else --验证失败直接踢掉
            skynet.call(gate, "lua", "stop", fd, 108)
        end
    elseif cmd == msgcmd["hall.reqLogin"] then --登陆
        -- LOG_DEBUG("sessionlist[fd]="..sessionlist[fd]..",session="..session)
        if sessionlist[fd] and session == sessionlist[fd] then
            local result = do_auth(fd, string.sub(msg, 10, sz))
            LOG_DEBUG("auth:" .. tostring(result) .. "," .. fd)
            if result then
                skynet.call(gate, "lua", "stop", fd, result)
                local ok,dd = pcall(protobuf.encode, "hall.resLogin", {result = result})
                send_msg_to_client(fd, msgcmd["hall.resLogin"], dd)
            end
        else
            skynet.call(gate, "lua", "stop", fd, 108)
        end
    end
end

function CMD.ctrl(cmd)
    if cmd == 1 then
        -- 停服
        disable = true
    elseif cmd == 2 then
        -- 滚服
        disable = true
    elseif cmd == 3 then
        -- 重新开服
        disable = false
    end
end

function CMD.start(conf)
    if conf.loginType == "webgate" then
        gate = skynet.newservice("webgate")
        gate_type = "webgate"
    else
        gate = skynet.newservice("gated")
        gate_type = "gate"
    end
    skynet.fork(connect_to_login, true)
    skynet.fork(create_heart_cast)

    local f = assert(io.open(rootpath .. "protocol/hall.pb", "r"))
    local buffer = f:read "*a"
    f:close()
    sharedata.new("hall", {buffer})
    protobuf.register(buffer)

    -- f = assert(io.open(rootpath .. "protocol/user.proto" , "r"))
    -- buffer = f:read "*a"
    -- f:close()
    -- sharedata.new("proto_user", {buffer})

    -- f = assert(io.open(rootpath .. "protocol/gm.proto" , "r"))
    -- buffer = f:read "*a"
    -- f:close()
    -- sharedata.new("proto_gm", {buffer})

    sharedata.new("cmd", "@" .. rootpath .. "protocol/cmd.lua")

    msgcmd = sharedata.query("cmd")
    conf.auth = skynet.self()
    skynet.call(gate, "lua", "open", conf)
end

function CMD.kick(uid)
    local ok, result = pcall(cluster.call, "login", login, "user_offline", uid)
    if not ok then
        LOG_DEBUG("disconnected with login!!!")
        active = false
    end
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(session, source, cmd, subcmd, ...)
                if cmd == "socket" then
                    -- socket api don't need return
                    local f = SOCKET[subcmd]
                    skynet.ret(skynet.pack(f(...)))
                else
                    local f = assert(CMD[cmd])
                    skynet.ret(skynet.pack(f(subcmd, ...)))
                end
            end
        )

        redis = skynet.uniqueservice("redispool")
    end
)
