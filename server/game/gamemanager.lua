local skynet = require "skynet"
local cluster = require "skynet.cluster"

local game_conf = require "game_conf"
local room_conf = require "room_conf"
local nodename = skynet.getenv("nodename")
local nodeindex = skynet.getenv("nodeindex")
local gmmanager

local tables = {}

local code_list = {}

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
-- 1011 房间资源不够了
function CMD.create(gameid, pay, score, times, player, params)
	local conf = game_conf[gameid]
	if not conf then return 1002 end
	if pay ~= 1 and pay ~= 2 then
		pay = 2
	end

	local function get_price()
		local tmp_conf
		local price_mode
		tmp_conf = conf.times
		price_mode = times
		
		local index
		for i,v in ipairs(tmp_conf) do
			if v == price_mode then
				index = i
				break
			end
		end
		if not index then
			LOG_ERROR("get_price error gameid[%d] game_times[%d] paytype[%d]", gameid, price_mode, pay)
			return
		end
		return tonumber(conf.price[index+(pay-1)*(#tmp_conf)])
	end

	-- if pay == 2 then
		local price = get_price()
		if not price then return 1002 end
		local ok, result = pcall(cluster.call, player.datnode, player.dataddr, "sub_money", player.uid, price, 1001)
		if not ok then
			return 1000
		end
		if not result then
			return 1010
		end
	-- end

	-- local code = tostring(math.random(9))..tostring(b)..tostring(math.random(9))..tostring(a)
	-- code = tonumber(code)
	if #code_list < 1 then return 1011 end
	local code = table.remove(code_list, math.random(#code_list))
	if tables[code] then
		return 1001
	end

	if not table.indexof(conf.score, score) then return 1003 end
	if not table.indexof(conf.times, times) then return 1004 end
	-- price = {40,160}
	local t = skynet.newservice("table")
	tables[code] = t
	-- function CMD.init(conf, gameid, times, score, paytype, code)
	local ok, result = pcall(skynet.call, t, "lua", "init", conf, gameid, times, score, pay, code, player, skynet.self(), nil, nil, params)
	if not ok then
		LOG_DEBUG(result)
		return 1007
	end
	ok, result = pcall(skynet.call, t, "lua", "join", player)
	if not ok then
		LOG_DEBUG(result)
		return 1007
	end
	if result then return result end
	send_to_gmctrl("user_joingame", player.uid, 1, {gameid=gameid, node=nodename, addr=t})
	return nodename, t
end

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
function CMD.join(code, player)
	local t = tables[code]
	if not t then
		return 1009
	end

	local ok, result = pcall(skynet.call, t, "lua", "join", player)
	if not ok then
		return 1007
	end
	
	if result then return result end
	ok, result = pcall(skynet.call, t, "lua", "query_gameid")
	if ok then
		send_to_gmctrl("user_joingame", player.uid, 1, {gameid=result, node=nodename, addr=t})
	else
		LOG_WARNING("query gameid faild")
	end
	return nodename, t, result
end

-- 1001 桌子不存在
-- 1002 解散失败
-- 1003 不是房主
function CMD.dissolve_table(code, uid)
	local t = tables[code]
	if not t then
		return 1001
	end
	local ok, result = pcall(skynet.call, t, "lua", "dissolve_table", uid)
	if ok and result then
		return result
	end
	return 1002
end

function CMD.free(code)
	tables[code] = nil
	table.insert(code_list, code)
end

-- --由table发来的重连信息
-- function CMD.resume(uid, gameid)
-- 	send_to_gmctrl("user_resume", uid, 1, gameid)
-- end

skynet.start(function()
	local c
	-- 每个节点可以开4000个房间
	for i=2001,9000 do
		c = i * 100 + tonumber(nodeindex)
		table.insert(code_list, c)
	end
	-- luadump(code_list)
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
