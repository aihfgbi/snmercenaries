local skynet = require "skynet"
local cluster = require "skynet.cluster"
local os_time = os.time
local CMD = {}

local ai

local api = {}
local manager
local gmnode
local gmaddr
local robot_uid
--延迟调用的函数
local delay_funcs = {
--	{time = number,fun = fun}
}

function api.send_msg(name, msg, uid)
--	LOG_DEBUG("robot send_msg[%s]", name)
	local ok, result = pcall(cluster.call, gmnode, gmaddr, "dispatch", uid or robot_uid, name, msg)
	if not ok then
		LOG_ERROR("call [%s][%s] error: %s", tostring(gmnode), tostring(gmaddr), tostring(result))
	end
end

function api.leave( ... )
	CMD.free()
end

function api.register_delay_fun(time, cb, params)
	time = os_time() + time
	local pa = table.deepcopy(params)
	table.insert(delay_funcs, {time = time, fun = cb, params = pa})
end

local function check_delay_funcs()
	local now_time = os_time()
	for i=#delay_funcs,	1, -1 do
		if delay_funcs[i].time <= now_time then
			local ok, result = pcall(delay_funcs[i].fun, delay_funcs[i].params)
			if not ok then
				LOG_ERROR("exec call back func error: %s", tostring(result))
			end
		--	skynet.fork(delay_funcs[i].fun)
			table.remove(delay_funcs, i)
		end
	end
end

local function tick_tick()
	while true do
		check_delay_funcs()
		if ai and ai.update then
			ai.update()
		end
		skynet.sleep(10)
	end
end

--[[
    @desc: 机器人退出
    author:{author}
    time:2019-02-21 01:28:13
    --@uid: 
    @return:
]]
local function robot_exit(uid)
	pcall(skynet.call, manager, "lua", "free_robot", uid)
	--by judith
	CMD.free()
end

function CMD.init(type, gameid, gamenode, gameaddr, mgr, uid, gold)
	gmaddr = gameaddr
	gmnode = gamenode
	manager = mgr
	robot_uid = uid
--	LOG_WARNING("init type:"..type)
	local ok, ai_mgr =pcall(require, "ai_"..type)
	if ok and ai_mgr then
		ai = ai_mgr
		ai.init(api, robot_uid, gameid, gold)
	else
		LOG_WARNING("require ai_"..type.." faild :[%s]", tostring(ai_mgr))
		ai = nil
	end
end

function CMD.send_to_client(uid, name, msg)
--	LOG_DEBUG("robot[%d] receive msg name[%s]", uid, name)
	if name == "exit" then
		robot_exit(uid)
	else
		name = string.split(name, ".")[2]
		if name == "resLeaveTable" and msg.uid == robot_uid then
			robot_exit(uid)
		elseif ai then
			ai.dispatch(name, msg)
		end
	end
end

function CMD.free()
	delay_funcs = nil
	if ai then
		ai.free()
	end
	LOG_DEBUG("robot[%d] exit", robot_uid)
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		if not f then
			LOG_WARNING("command[%s]", command)
		end
		skynet.ret(skynet.pack(f(...)))
	end)
	skynet.fork(tick_tick)
	collectgarbage("collect")
	collectgarbage("collect")
	collectgarbage("collect")
end)
