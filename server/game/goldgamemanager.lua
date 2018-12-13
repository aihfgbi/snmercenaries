local skynet = require "skynet"
local cluster = require "skynet.cluster"

local game_conf = require "game_conf"
local room_conf = require "room_conf"
local nodename = skynet.getenv("nodename")

local gmmanager
local ctrl_list = {}
local CMD = {}

local function get_gm_manager()
	if not gmmanager then
		local ok, addr = pcall(cluster.query, "gmctrl", "userctrl")
		if ok and addr then
			gmmanager = addr
		end
	end
	return gmmanager
end

local function send_to_gmctrl(cmd, ...)
	get_gm_manager()
	if gmmanager then
		local ok, result = pcall(cluster.call, "gmctrl", gmmanager, cmd, ...)
		if not ok then
			LOG_ERROR("call gmctrl [%s] faild : %s", tostring(cmd), tostring(result))
			gmmanager = nil
		end
	end
end

-- 100  已经在房间中了
-- 101  未知错误
-- 200  参数错误
-- 1000 游戏服务器链接不上
-- 1001 请再试一次
-- 1002 gameid错误
-- 1003 score参数错误
-- 1004 times参数错误
-- 1005 房间不存在
-- 1006 房间已满
-- 1007 创建房间失败
-- 1008 加入房间失败
-- 1009 房间不存在
-- 1010 钱不够
function CMD.join(gameid, p)
	local cfg = game_conf[gameid]
	if not cfg or not cfg.type then
		return 1002
	end
	if not ctrl_list[cfg.type] then
		return 1002
	end
	
	local nodename, addr = skynet.call(ctrl_list[cfg.type], "lua", "join", gameid, p) --调用了ctrl里面的join
	send_to_gmctrl("user_joingame", p.uid, 2, {gameid=gameid, node=nodename,addr=addr})
	return nodename, addr
end

-- --由ctrl发来的重连信息
-- function CMD.resume(uid, gameid)
-- 	send_to_gmctrl("user_resume", uid, 2, gameid)
-- end

-- 由ctrl发来的gmctrl_storage消息
function CMD.send_gmctrl_storage(info)
	send_to_gmctrl("game_storage", info)
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	local cfg = room_conf[nodename]
	assert(cfg, "节点配置有误："..tostring(nodename))
-- 	this["goldgame0"] = {type="gold", fish={4001}, niuniu={1001,1002,1003}, jdddz={2001, 2002}, majiang={6001},nbddz={3001},fqzs={10002},br_niuniu={5002},br_xiaojiu={5003},br_erbagang={5004},br_bieshi={5005},br_liangzhang={5006}}
	for key,list in pairs(cfg) do
		if key and key ~= "type" then
			if not ctrl_list[key] then
				local ctrl = skynet.newservice("ctrl")
				LOG_DEBUG(key)
				skynet.call(ctrl, "lua", "init", key, skynet.self())
				ctrl_list[key] = ctrl
			end		
		end
	end
end)
