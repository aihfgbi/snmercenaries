local skynet = require "skynet"
local cluster = require "skynet.cluster"

local game_conf = require "game_conf"
local room_conf = require "room_conf"
local match_conf = require "match_conf"
local nodename = skynet.getenv("nodename")

local gmmanager

local CMD = {}

local players = {}
local match_list = {}

local free_tables = {} --空闲的桌子
local total_tables = {} -- 总的桌子 table addr ==> gameid
local lock_list = {} --暂时锁定的桌子
local user_count = {}
local max_list = {} --玩家当前比赛的最高水平
local gameid2matchid = {}

local redis

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

local function send_msg(self, name, msg)
	-- if self.online ~= 1 then return end
	LOG_DEBUG("send msg:"..name..","..self.uid)
	local ok, result = pcall(cluster.send, self.agnode, self.agaddr, "send_to_client", self.uid, name, msg)
	if not ok then
		LOG_ERROR("send_msg error:"..tostring(result))
		LOG_ERROR("name:"..name..",node:"..tostring(self.agnode)..",addr="..tostring(self.agaddr))
	end
end

local function lock(t)
	lock_list[t] = 1
end

local function unlock(t)
	lock_list[t] = nil
end

local function check_lock(t)
	return lock_list[t]
end

local function check_time_in_format_time(time, time1, time2)
	time = time or 0
	if not time1 or not time2 then return end
	local nottime = os.date("*t", os.time())
	time1 = string.split(time1, ".")
	time2 = string.split(time2, ".")
	if tonumber(time1[1]) == 0 then
		time1[1] = nottime.year
		time2[1] = nottime.year
	end
	if tonumber(time1[2]) == 0 then
		time1[2] = nottime.month
		time2[2] = nottime.month
	end
	if tonumber(time1[3]) == 0 then
		time1[3] = nottime.day
		time2[3] = nottime.day
	end
	time1 = os.time({day=time1[3], month=time1[2], year=time1[1], hour=time1[4], min=time1[5], second=time1[6]})
	time2 = os.time({day=time2[3], month=time2[2], year=time2[1], hour=time2[4], min=time2[5], second=time2[6]})

	if time < time1 or time > time2 then
		return
	end

	return true, time1, time2
end

local function end_match(matchid)
	local list = players[matchid]
	if list then
		for uid,_ in pairs(list) do
			pcall(skynet.send, redis, "lua", "execute", "LREM", "match->"..uid, 100, matchid)
		end
		pcall(skynet.send, redis, "lua", "execute", "DEL", "match_range->"..matchid)
		players[matchid] = {}
		max_list[matchid] = {}
	end
end

local function timer_tick()
	while true do
		-- 一秒间隔
		skynet.sleep(100)
		local now = os.time()
		for id,node in pairs(match_list) do
			if not node.started then
				if check_time_in_format_time(now, node.time1, node.time2) then
					-- 开启比赛
					LOG_DEBUG("开启比赛了:"..id)
					node.started = now
				end
			else
				if not check_time_in_format_time(now, node.time1, node.time2) then
					-- 结束比赛
					LOG_DEBUG("比赛结束了:"..id)
					node.started = nil
					skynet.fork(end_match, id)
				end
			end
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
-- 1011 比赛不存在
-- 1012 比赛时间未到
-- 1013 未知门票
function CMD.join(matchid, p)
	LOG_DEBUG(tostring(p.uid).."join:"..matchid)
	if not match_list[matchid] then return 1011 end
	if not match_list[matchid].started then return 1012 end

	local cfg = match_conf[matchid]
	local gameid = cfg.gameid
	local conf = game_conf[gameid]

	if cfg.ticketCount > 0 then
		players[matchid] = players[matchid] or {}
		if not players[matchid][p.uid] then
			-- 需要报名参赛
			local funname
			if cfg.ticket == 1002 then
				-- 钻石
				funname = "sub_money"
				reason = 1007
			elseif cfg.ticket == 1003 then
				-- 金币
				funname = "sub_gold"
				reason = 105
			elseif cfg.ticket == 1004 then
				-- 红包
				funname = "sub_hongbao"
				reason = 1003
			else
				return 1013
			end

			local ok, result = pcall(cluster.call, p.datnode, p.dataddr, funname, p.uid, cfg.ticketCount, reason)
			if not ok then
				return 1000
			end
			if not result then
				return 1010
			end
			pcall(skynet.send, redis, "lua", "execute", "LPUSH", "match->"..p.uid, matchid)
			players[matchid][p.uid] = 0
		end
	end

	free_tables[matchid] = free_tables[matchid] or {}
	local list = free_tables[matchid]
	local table
	for t,_ in pairs(list) do
		if t and not check_lock(t) then
			table = t
			break
		end
	end

	if not table then
		table = skynet.newservice("table")
		local ok, result = pcall(skynet.call, table, "lua", "init", conf, gameid, 0, 0, 0, 0, p, skynet.self(), 1, matchid)
		if not ok then
			LOG_DEBUG(result)
			return 1007
		end
		list[table] = true
		total_tables[table] = matchid
	end

	lock(table)
	-- join需要阻塞，防止unlock的时候如果人已经满了，还没将桌子从空闲里面移出去
	local ok, result = pcall(skynet.call, table, "lua", "join", p)
	if not ok then return 1007 end
	if result then return result end
	unlock(table)
	p.online = true
	players[p.uid] = p
	user_count[matchid] = user_count[matchid] or 0
	user_count[matchid] = user_count[matchid] + 1
	send_to_gmctrl("user_joingame", p.uid, 3, {gameid=matchid, node=nodename, addr=table})
	return nodename, table
end

function CMD.kick(uid, gameid, win)
	LOG_DEBUG("kick match "..gameid)
	luadump(gameid2matchid)
	local matchid = gameid2matchid[gameid]
	if not matchid then return end
	local to = -1
	if players[uid] then
		LOG_DEBUG("players:"..uid)
		local list = players[matchid]
		if list and list[uid] then
			if win then
				list[uid] = list[uid] + 1
				max_list[matchid] = max_list[matchid] or {}
				max_list[matchid][uid] = max_list[matchid][uid] or 0
				if list[uid] > max_list[matchid][uid] then
					max_list[matchid][uid] = list[uid]
					pcall(skynet.send, redis, "lua", "execute", "ZADD", "match_range->"..matchid, list[uid], uid)
				end
				to=1
			else
				-- 如果失败，丧失比赛资格
				list[uid] = nil
				pcall(skynet.send, redis, "lua", "execute", "LREM", "match->"..uid, 100, matchid)
			end
		end

		local ok, range = pcall(skynet.call, redis, "lua", "execute", "ZREVRANK", "match_range->"..matchid, uid)
		if not ok or not range then
			range = -1
		else
			range = tonumber(range) + 1
		end
		LOG_DEBUG("======================================")
		send_msg(players[uid], "user.MatchResultNft", {range=range, gameid=gameid, matchid=matchid, continue=to})
		players[uid] = nil
		if user_count[matchid] then
			user_count[matchid] = user_count[matchid] - 1
		else
			LOG_DEBUG("error:踢出玩家的matchid错误"..tostring(matchid))
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
	local matchid = gameid2matchid[gameid]
	if not matchid then return end
	if free_tables[matchid] then
		free_tables[matchid][t] = nil
	end
end

function CMD.unlock_table(gameid, t)
	local matchid = gameid2matchid[gameid]
	if not matchid then return end
	if free_tables[matchid] then
		free_tables[matchid][t] = true
	end
end

function CMD.free_table(gameid, t)
	CMD.lock_table(gameid,t)
	total_tables[t] = nil
end

-- --由table发来的重连信息
-- function CMD.resume(uid, gameid)
-- 	send_to_gmctrl("user_resume", uid, 3, gameid)
-- end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	-- local cfg = room_conf[nodename]
	-- assert(cfg, "节点配置有误："..tostring(nodename))
-- this[2001] = {
-- 	name="斗地主淘汰赛",
-- 	type = "taotai", --比赛模式套用的逻辑
-- 	time = "0-0-0-18-0-0:0-0-0-20-0-0", --开始时间，结束时间，年月日时分秒
-- 	ticket = 1002, --门票类型
-- 	ticketCount = 10,
-- 	minGold = 10000, --最低入场金额
-- 	minMoney = 10,
-- 	useGold = true, --是否使用玩家真实金币结算
-- 	gameid = 2002, --使用的游戏ID
-- 	active = true,
-- }
	redis = skynet.uniqueservice("redispool")
	local time1, time2
	for id,cfg in pairs(match_conf) do
		-- print(k,v)
		if cfg and cfg.active then
			time1 = string.split(cfg.time, ":")
			time2 = time1[2]
			time1 = time1[1]
			match_list[id] = {time1=time1,time2=time2,gameid=cfg.gameid}
			gameid2matchid[cfg.gameid] = id
		end
	end
	luadump(match_list)
	skynet.fork(timer_tick)
end)
