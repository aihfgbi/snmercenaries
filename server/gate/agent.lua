local skynet = require "skynet"
local protobuf = require "protobuf"
local parser = require "parser" --pbc里面的东西
local sharedata = require "skynet.sharedata"
local cluster = require "skynet.cluster"
local socket = require "skynet.socket"
local time = require "timesp"

local msgcmd

local CMD = {}

local HEART_TIME = 2
local TIME_OUT_COUNT = 8

local _client_fd

local _gate
local _uid
local _timeout_count
local _gate_type = "gate"
local _active = false
local _session --跟客户端的验证代码

local _dbnode
local _dbaddr
local _gamenode
local _gameaddr
local _gm

local function kick(reason)
	CMD.kick(reason)
end

--[[
    @desc: 消息解包
    author:{author}
    time:2018-12-11 11:22:15
    --@data: 
    @return:
]]
local function msg_decode(data)
	if not data or data == "" then return end
	-- if _gate_type == "webgate" then
	-- 	-- data = data:sub(3)
	-- elseif _gate_type == "gate" then

	-- end

	if #data < 9 then
		LOG_DEBUG("agent msg_decode fail, #data < 9  #data="..#data)
		return
	end

	local msgid = data:sub(1, 5)
	local name = msgcmd[msgid]
	msgid = tonumber(msgid)
	if not name then
		LOG_DEBUG("agent msg_decode unkonw msg, msgid="..msgid)
		return
	end
	
	local ss = data:sub(6, 9)
	if ss ~= _session then
		LOG_DEBUG("agent msg_decode session error, msgid="..msgid)
		return
	end

	local ok,msg
	if #data > 9 then
		ok,msg = pcall(protobuf.decode,name,data:sub(10))
		assert(ok and msg, "agent msg_decode protobuf.decode fail, msgid="..msgid)
		luadump(msg,"msg_decode,msg========")
	end
	if msgid ~= 10005 then
		-- body
		LOG_DEBUG("解析消息成功->"..msgid..",name:"..name)
	end

	return msgid,name,msg
end

--[[
    @desc: 消息打包
    author:{author}
    time:2018-09-30 16:47:15
    --@name:
	--@msg: 
    @return:
]]
local function msg_encode(name, msg)
	assert(name)
	local msgid = msgcmd[name]
	assert(msgid, "agent msg_encode fail, unknow msg, msgname="..name)

	local ok,data
	if type(msg) == "table" then
		ok,data = pcall(protobuf.encode, name, msg)
		assert(ok, "agent msg_encode protobuf.encode fail, msgname="..name)
	end

	local len = string.len(data)
    local tmp = string.format(">I4>I4c%d", len)
	local package = string.pack(tmp, msgid, len + 8, data)
	
	return package
end

local function send_package(pack)
	if _client_fd then
		if _gate_type == "gate" then
			return socket.write(_client_fd, pack)
		elseif _gate_type == "webgate" then
			-- local package = string.pack(">s2", pack)
			-- skynet.call(_gate, "lua", "send_package", _client_fd, _uid , package) --这里实际上调用了webgate里面的send_package
		end
	end
end

local function send_heartbeat()
	--LOG_DEBUG("send heart time:"..time.time())
	local ok,data = pcall(msg_encode, "hall.resHeart", {time = time.time()})
	if ok then
		send_package(data)
	end
end

local function msg_dispatch( msg )
	local ok,msgid,msgname,msgdata = pcall(msg_decode, msg)
	if not ok then 
		LOG_WARNING(msgid)
		LOG_WARNING("user msg_decode fail. uid=%d fd=%d", _uid or 0, _client_fd or 0)
		kick(2)
		return
	elseif not msgid then
		LOG_DEBUG("消息号错误")
		return
	end

	_timeout_count = 0--重置心跳计时
	if msgid == msgcmd["hall.reqHeart"] then
		send_heartbeat()
		return
	end

	msgname = msgname or ""
	local module, method = msgname:match "([^.]*).(.*)"
	module = module or "" 
	method = method or ""

	LOG_DEBUG("======================================================")
	LOG_DEBUG("recive:"..method)
	luadump(msgdata)
	LOG_DEBUG("======================================================")

	local respname,respdata
	if module == "hall" then
		local ok
		ok, respname, respdata = pcall(cluster.call, _dbnode, _dbaddr, "client_req", _uid, method, msgdata)
		if not ok then
			LOG_INFO("calling to user.%s error:%s", method, respname)
			return
		end
	elseif module == "game" then
		if _gamenode and _gameaddr then
			local ok
			ok, respname, respdata = pcall(cluster.call, _gamenode, _gameaddr, "dispatch", _uid, method, msgdata)
			if not ok then
				LOG_INFO("calling to game.%s error:%s", method, respname)
				-- kick(8)
				return
			end
		else
			-- kick(8)
			LOG_DEBUG("没有进入游戏:".._uid)
		end
	elseif module == "gm" then
		local ok
		LOG_DEBUG("gm="..tostring(_gm))
		if not _gm then return end
		ok, respname, respdata = pcall(cluster.call, _dbnode, _dbaddr, "gm_req", _uid, method, msgdata)
		if not ok then
			LOG_INFO("calling to gm.%s error:%s", method, respname)
			return
		end
	end

	if respname then

		LOG_DEBUG("======================================================")
		LOG_DEBUG("send:"..respname)
		luadump(respdata)
		LOG_DEBUG("======================================================")

		local ok,data = pcall(msg_encode, respname, respdata)
		if ok then
			send_package(data)
		else
			LOG_WARNING(data)
		end
	end
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
	dispatch = function (_, _, msg)
		msg_dispatch(msg)
	end
}


local function start_heart()
	while true do
		skynet.sleep(HEART_TIME*100)
		-- LOG_DEBUG("heart")
		_timeout_count = _timeout_count + 1
		if _timeout_count >= TIME_OUT_COUNT then
			LOG_DEBUG("心跳超时:".._uid)
			kick(3)
		end
	end
end

function CMD.websocket_dispatch(msg)
	msg_dispatch(msg)
end

function CMD.start(conf)
	-- { gate = gate, client = fd, uid = uid }
	_client_fd = conf.client
	_gate = conf.gate
	_uid = conf.uid
	_auth = conf.auth
	_dbnode = conf.dbnode
	_dbaddr = conf.dbaddr
	local nodename = conf.nodename
	_timeout_count = 0
	_gate_type = conf.gate_type
	_session = conf.session

	-- 初始化userdata
	-- function CMD.online(uid, node, addr, ip, nickname)调用了userdata/userdata.lua里面的CMD.online函数
	local ok, result = pcall(cluster.call, _dbnode, _dbaddr, "online", _uid, nodename, skynet.self())
	if not ok or not result then
		LOG_DEBUG("error:调用dbs的online失败:"..tostring(_uid))
		return false
	end

	_active = true
	skynet.call(_gate, "lua", "forward", _client_fd, _uid)

	-- 登录成功了！！
	LOG_DEBUG("send time:"..time.time())
	LOG_DEBUG("%d登录成功了",_uid)
	local ok,data = pcall(msg_encode, "hall.resLogin", {result = 1,uid = _uid})
	if ok then
		send_package(data)
	end
	skynet.fork(start_heart)

	return true
end

-- 将玩家踢下线，agent资源会被释放
-- 0 客户端发起的socke关闭, reason = 1 被挤下线, reason = 2 解码失败， reason = 3 超时 , reason = 4 被锁定 5 数据包太大了  6 被封号
-- 7 意外错误，有玩家在线，但是再次请求了开启一个userdata服务，处理方式是将之前的一个agent踢掉(被挤号)
-- 8 找不到game服
-- 9 停服了
function CMD.kick(reason)
	LOG_DEBUG(tostring(_uid).." kick by value:"..tostring(_active)..",reason="..tostring(reason))
	if not _active then return end
	reason = reason or 0
	_active = false
	-- 通知userdata
	if reason ~= 7 then
		pcall(cluster.call, _dbnode, _dbaddr, "offline", reason)
	end
	if reason ~= 0 then
		reason = tostring(reason)
		local len = string.len(reason)
        local tmp = string.format(">I4>I4c%d", len)
		send_package(string.pack(tmp, 29999, len+8, reason))
	end
	skynet.call(_gate, "lua", "agent_stop", _client_fd)
	skynet.exit()
end

-- 发送协议到客户端
function CMD.send_to_client(uid, name, body)
	if uid ~= _uid then return end
	-- LOG_DEBUG("======================================================")
	-- LOG_DEBUG("send:"..name)
	-- luadump(body)
	-- LOG_DEBUG("======================================================")
	if name then
		local ok,data = pcall(msg_encode, name, body)
		if ok then
			send_package(data)
		else
			LOG_WARNING(data)
		end
	end
end

function CMD.join_game(node, addr)
	_gamenode = node
	_gameaddr = addr
end
function CMD.leave_game()
	_gameaddr = nil
	_gamenode = nil
end

skynet.start(function()
	-- local files = {}
	-- files["test20.proto"] = sharedata.query("test20")[1]

	msgcmd = sharedata.query("cmd")

	-- parser.register2(files) --注册protocol协议文件
	protobuf.register(sharedata.query("hall")[1])
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	collectgarbage("collect") --这个是内存回收的
	collectgarbage("collect")
	collectgarbage("collect")
end)
