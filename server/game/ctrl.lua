local skynet = require "skynet"
local cluster = require "skynet.cluster"

local game_conf = require "game_conf"
local room_conf = require "room_conf"
local nodename = skynet.getenv("nodename")
local goldmanager  		--goldgamemanager的地址

local free_tables = {} --空闲的桌子
local total_tables = {} -- 总的桌子 table addr ==> gameid
local lock_list = {} --暂时锁定的桌子
local CMD = {}
local api = {}
local players = {}
local ctrl
local user_count = {}
local kickbackInfo = {}
local logredis
local logname = skynet.getenv("logname")

--发给gmctrl服的信息
local gmctrl_storage = {
	-- gameid = 222,
	-- sysearn = 23,
	-- kickback = 12,
	-- defKickback = 123,
	-- k = 232,
}

local DEFAULT_COST = 100 * 1000000
local DEFAULT_EARN = 98 * 1000000
local DEFAULT_KICKBACK = 0.02

local function log(type, content)
	-- LOG_DEBUG(tostring(_uid)..","..tostring(type)..","..tostring(content))
	local log = string.format('{"type":"%s","uid":0,"time":%d,"data":%s}', type, os.time(), content)
	-- LOG_DEBUG("[log]"..log)
	if logname and #logname > 0 then
		local ok, result = pcall(skynet.send, logredis, "lua", "execute", "LPUSH", logname, log)
		if not ok then
			LOG_ERROR("error：写入日志失败:"..tostring(result))
		end
	end
end

local function send_goldmanager(cmd, ...)
	skynet.send(goldmanager, "lua", cmd, ...)
end

local function send_msg(self, name, msg)
	if not self.online then return end
--	LOG_DEBUG("send msg:"..name..","..self.uid)
	local ok, result = pcall(cluster.send, self.agnode, self.agaddr, "send_to_client", self.uid, name, msg)
	if not ok then
		LOG_ERROR("send_msg error:"..tostring(result))
		LOG_ERROR("name:"..name..",node:"..tostring(self.agnode)..",addr="..tostring(self.agaddr))
	end
end

local function call_all_table(name, ... )
	for t,gameid in pairs(total_tables) do
		skynet.call(t, "lua", "call_table", name, ...)
	end
end

local function send_to_all(name, msg, gameid)
	local i = 0
	for uid,p in pairs(players) do
		if p and (not gameid or p.gameid == gameid) then
			send_msg(p, name, msg)
			i = i + 1
			if i > 499 then
				i = 0
				-- 500个一轮,休息50ms
				skynet.sleep(5)
			end
		end
	end
end

function api.call_all_table(name, ...)
	skynet.fork(call_all_table, name, ...)
end

function api.call_table(t, name, ...)
	if total_tables[t] then
		return skynet.call(t, "lua", "call_table", name, ...)
	end
end

function api.send_msg(uid, name, msg)
	local p = players[uid]
	if p then
		send_msg(p, name, msg)
	end
end

-- 注意，不是强消息发送，个别用户可能会收不到
-- 强消息发送用另一个消息推送接口
function api.send_to_all(name, msg, gameid)
	skynet.fork(send_to_all, name, msg, gameid)
end

function api.get_user_count(gameid)
	return user_count[gameid] or 0
end

local function tick_tick()
	while true do
		if ctrl then
			ctrl.update()
		end
		skynet.sleep(10)
	end
end

local function lock(t)
	-- body
	lock_list[t] = 1
end

local function unlock(t)
	-- body
	lock_list[t] = nil
end

local function check_lock(t)
	return lock_list[t]
end

local function send_gmctrl_storage()
	if next(gmctrl_storage) then
		send_goldmanager("send_gmctrl_storage", gmctrl_storage)
	end

	table.clear(gmctrl_storage)
end

local function set_kickback(gameid)
	for addr,gid in pairs(total_tables) do
		if gid == gameid then
			pcall(skynet.call, addr, "lua", "set_kickback", kickbackInfo[gameid].kickback,(kickbackInfo[gameid].cost or 0) - (kickbackInfo[gameid].earn or 0))
		end
	end
end

-- 计算抽水比值
local function calcKickBack()
-- {earn = 0, cost = 0, defEarn = conf.default_earn or DEFAULT_EARN,
-- 		 defCost = conf.default_cost or DEFAULT_COST, defKickback = conf.kickback or DEFAULT_KICKBACK}
	local k
	while true do
		for gameid,v in pairs(kickbackInfo) do
			if v and v.isSave then
				v.isSave = false
				k = (v.earn + v.defEarn)/(v.cost + v.defCost)
				v.kickback = 1/(k+v.defKickback) - v.defKickback
				-- LOG_DEBUG("游戏"..gameid.."cost="..v.cost..",earn="..v.earn..",过去一段时间内的营收比值是:"..k..",设定的目标抽水率是:"..v.defKickback..",调解后的kickback="..v.kickback)
				skynet.fork(set_kickback, gameid)
				log("kickback", string.format('{"gameid":"%d","earn":%s,"cost":%s,"k":%s,"target":%s,"kickback":%s}', 
					gameid,v.earn,v.cost,k,v.defKickback,v.kickback))
				table.insert(gmctrl_storage, {gameid = gameid,
											  sysearn = (v.cost or 0) - (v.earn or 0),
											  kickback = v.kickback,
											  defKickback = v.defKickback,
											  k = k})
			end
		end

		send_gmctrl_storage()
		skynet.sleep(5*100)
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
-- 1010 钻石不够
-- 1012 金币条件不足
function CMD.join(gameid, p)
	LOG_DEBUG(tostring(p.uid).."join:"..gameid)
	local conf = game_conf[gameid]
	if conf.min_gold and (not conf.test_gold or conf.test_gold < 1) then
		if not p.gold or p.gold < conf.min_gold then
			return 1012
		end
	end
	free_tables[gameid] = free_tables[gameid] or {}
	local list = free_tables[gameid]
	local table
	for t,_ in pairs(list) do
		if t and not check_lock(t) then
			table = t
			break
		end
	end

	if not table then
		kickbackInfo[gameid] = kickbackInfo[gameid] or {earn = 0, cost = 0, defEarn = conf.default_earn or DEFAULT_EARN,
		defCost = conf.default_cost or DEFAULT_COST, defKickback = conf.kickback or DEFAULT_KICKBACK, kickback = 1-DEFAULT_KICKBACK}

		table = skynet.newservice("table")
		local ok, result = pcall(skynet.call, table, "lua", "init", conf, gameid, 0, 0, 0, 0, p, skynet.self(), 1, nil, nil, kickbackInfo[gameid].kickback)
		if not ok then
			LOG_DEBUG(result)
			return 1007
		end
		list[table] = true
		total_tables[table] = gameid
	end

	lock(table)
	-- join需要阻塞，防止unlock的时候如果人已经满了，还没将桌子从空闲里面移出去
	local ok, result = pcall(skynet.call, table, "lua", "join", p)
	if not ok then return 1007 end
	if result then return result end
	unlock(table)
	p.online = true
	players[p.uid] = p
	p.gameid = gameid
	user_count[gameid] = user_count[gameid] or 0
	user_count[gameid] = user_count[gameid] + 1
	return nodename, table
end

function CMD.kick(uid, gameid)
	if players[uid] then
		players[uid] = nil
		if user_count[gameid] then
			user_count[gameid] = user_count[gameid] - 1
		else
			LOG_DEBUG("error:踢出玩家的gameid错误"..tostring(gameid))
		end
	end
end

function CMD.online(uid)
	if players[uid] then
		players[uid].online = true
	end
end

function CMD.offline(uid)
	if players[uid] then
		players[uid].online = nil
	end
end

function CMD.lock_table(gameid, t)
	if free_tables[gameid] then
		free_tables[gameid][t] = nil
	end
end

function CMD.unlock_table(gameid, t)
	if free_tables[gameid] then
		free_tables[gameid][t] = true
	end
end

function CMD.free_table(gameid, t)
	CMD.lock_table(gameid,t)
	total_tables[t] = nil
end

function CMD.init(type, manager)
	LOG_DEBUG(type)
	local ok
	ok, ctrl = pcall(require, "roomctrl_"..type)
	if ok and ctrl then
		ctrl.init(type,api,players,free_table,total_tables)
	else
		ctrl = nil
	end
	goldmanager = manager
	skynet.fork(tick_tick)
end

function CMD.report(addr, gameid, usercost, userearn)
	if total_tables[addr] and total_tables[addr] == gameid and kickbackInfo[gameid] then
		kickbackInfo[gameid].isSave = false --是否保存到redis
		if usercost ~= 0 or userearn ~= 0 then --有变化才存
			kickbackInfo[gameid].isSave = true
		end
		kickbackInfo[gameid].cost = kickbackInfo[gameid].cost + usercost
		kickbackInfo[gameid].earn = kickbackInfo[gameid].earn + userearn
		-- LOG_DEBUG("收到房间上报数据:"..addr..","..gameid..","..usercost..","..userearn)
	else
		LOG_ERROR("report error!!!!!")
	end
end

function CMD.call_ctrl(name, ...)
	if ctrl then
		local f = ctrl[name]
		if f then
			return f(...)
		end
	end
end

-- function CMD.resume(uid, gameid)
-- 	send_goldmanager("resume", uid, gameid)
-- end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	local cfg = room_conf[nodename]
	assert(cfg, "节点配置有误："..tostring(nodename))
	logredis = skynet.uniqueservice("logredispool")
	skynet.fork(calcKickBack)
end)
