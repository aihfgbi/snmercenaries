local skynet = require "skynet"
local crypt = require "skynet.crypt"
local sharedata = require "skynet.sharedata"
local redisWatchMsg = skynet.getenv("redis_watch_msg")
local redisWatchList = skynet.getenv("redis_watch_list")
local redisPushMsg = skynet.getenv("redis_push_msg")
local redisPushList = skynet.getenv("redis_push_list")
local redis = require "skynet.db.redis"
local cluster = require "skynet.cluster"
local base64decode = crypt.base64decode
local CMD = {}
local MSGAPI = {}
local _logredis
local _sendMsgList
local json = require "cjson"
local lock  --鎖定不能操作數組
local _checkTime
local _msgcmd = require("cmd")
local _dbnode, _dbaddr
local _robnode,_robaddr
local redis_pwd = skynet.getenv("redis_pwd")
if redis_pwd == "" then
    redis_pwd = nil
end

local conf = {
    host = skynet.getenv("redis_host"),
    port = skynet.getenv("redis_port"),
    auth = redis_pwd
}

function doMsgFunc(data)
    data = json.decode(data)
    luadump(data, "admin msg===")
    local cmd = math.floor(tonumber(data.type))
    for k, v in pairs(data.data) do
        if type(v) == "number" then
            v = math.floor(v)
        end
    end
    if cmd > 40000 and cmd < 60000 then
        if not _msgcmd then
            LOG_DEBUG("没有cmd")
        end

        local msgname = _msgcmd[tostring(cmd)] or ""
        local module, method = msgname:match "([^.]*).(.*)"
        module = module or ""
        method = method or ""
        -- LOG_DEBUG("msgname:"..msgname..",module="..module..",method="..method)
        if module == "robot" then
            -- local ok = pcall(cluster.call, _robnode, _robaddr, "client_req", 1017, method, data)
            -- if ok then
            --     LOG_DEBUG("調用成功")
            -- end
        else
            LOG_DEBUG("錯誤的消息號" .. cmd)
        end
    end
end

--[[
    @desc: 监听订阅，收到消息就去队列里面读取一条消息
    author:{author}
    time:2019-02-17 21:03:21
    @return:
]]
function watching()
    local w = redis.watch(conf)
    w:subscribe(redisWatchMsg)
    -- w:psubscribe "hello.*"
    while true do
        local msg = w:message()
        -- luadump(msg,"Watch==")
        -- 收到订阅消息，去队列里面读取消息
        if msg then
            local ok, a = pcall(skynet.call, _logredis, "lua", "execute", "LPOP", redisWatchList)
            if ok and a and a ~= "" then
                doMsgFunc(a)
            end
        end
    end
end

--[[
    @desc: 每隔一段时间读取一次消息列表，每秒检测插入信息列表，有新信息就发送
    author:{author}
    time:2019-02-17 21:54:24
    @return:
]]
function readMsg()
    while true do
        if not lock and #_sendMsgList > 0 then
            local mm = table.remove(_sendMsgList)
            if mm and type(mm) == "string" then
                local ok, a = pcall(skynet.send, _logredis, "lua", "execute", "LPUSH", redisPushList, mm)
                if ok then
                    local k, b = pcall(skynet.call, _logredis, "lua", "publishMsg", redisPushMsg, "123asdgadaeadsgads")
                    -- if k then
                    --     LOG_DEBUG("发送订阅消息成功===" .. b)
                    -- end
                end
            end
        end
        _checkTime = _checkTime + 1
        if _checkTime >= 30 then --30秒去自动读取一次
            while true do
                local ok, a = pcall(skynet.call, _logredis, "lua", "execute", "LPOP", redisWatchList)
                if ok and a and a ~= "" then
                    doMsgFunc(a)
                else
                    break
                end
            end
            _checkTime = 0
        end
        skynet.sleep(1 * 100)
    end
end

--[[
    @desc: 插入消息
    author:{author}
    time:2019-02-03 22:24:21
    --@type:消息类型
	--@data: 消息内容
    @return:
]]
function CMD.pushMsg(type, data)
    if not type or not data or data == "" then
        return
    end
    lock = true
    local cmd = _msgcmd[type]
    local msg = {}
    local time = tostring(os.time())
    local randStr = RAND_STR(5)
    local len = #time
    local tmplist = {}
    for i = 1, len do
        tmplist[i] = string.sub(time, i, i)
    end
    for i = 1, 5 do
        local instr = string.sub(randStr, i, i)
        local idx = math.random(1, #tmplist)
        table.insert(tmplist, idx, instr)
    end
    msg.id = table.concat(tmplist)
    msg.type = cmd
    msg.data = data
    table.insert(_sendMsgList, json.encode(msg))
    lock = false
end

--[[
    @desc: 添加userdatamanger地址
    author:{author}
    time:2019-02-19 23:17:27
    --@apilist: 
    @return:
]]
function CMD.initdbNode(node, addr)
    _dbnode = node
    _dbaddr = addr
end

--[[
    @desc: 添加robotmanager地址
    author:{author}
    time:2019-02-20 23:39:14
    --@node:
	--@addr: 
    @return:
]]
function CMD.initrobNode(node, addr)
    _robnode = node
    _robaddr = addr
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(_, _, command, ...)
                -- LOG_DEBUG("需要执行:"..command)
                local f = CMD[command]
                skynet.ret(skynet.pack(f(...)))
            end
        )

        _logredis = skynet.uniqueservice("redispool")
        _sendMsgList = {}
        _checkTime = 0
        skynet.fork(watching)
        skynet.fork(readMsg)
    end
)
