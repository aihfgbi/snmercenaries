local ai_mgr = {}
local server_msg = {}
local robot_api
local robot_info

local function send_to_server(name, msg)
	LOG_DEBUG("send_to_server [%s]", name)
	robot_api.send_msg(name, msg)
end

function server_msg.jqr_yz(msg)
	-- LOG_DEBUG("机器人押注！！！！！！！！！！！！！！！！！！！")
	send_to_server("PourHORSE", {pourobject = msg.object ,pourmoney = msg.money})
end

function ai_mgr.init(api, uid)
	robot_api = api
	robot_info = robot_info or {}
	robot_info.uid = uid
	LOG_DEBUG("robot uid[%d]", robot_info.uid)
end

function ai_mgr.dispatch(name, msg)
	local f = server_msg[name]
	if name == "jqr_yz" then --机器人押注
		f(msg)
	end
end

function ai_mgr.free()
	robot_info = nil
end

return ai_mgr