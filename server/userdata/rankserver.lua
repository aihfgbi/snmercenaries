local skynet = require "skynet"
local cluster = require "skynet.cluster"
local crypt = require "skynet.crypt"
local rankname = skynet.getenv("rank_list_name")

local base64decode = crypt.base64decode

local CMD = {}

local lasttime
local redis

local range1 = {}
local range2 = {}
local range3 = {}

local needclear1 = nil

local function rank_list_1(time)
	-- 今日红包榜
	if needclear1 or os.date("%j", time) ~= os.date("%j", lasttime) then
		LOG_DEBUG("今日红包榜跨天，清理数据")
		local ok = pcall(skynet.call, redis, "lua", "execute", "DEL", rankname.."1")
		if not ok then
			LOG_DEBUG("清理今日红包榜失败，error")
			needclear1 = true
		else
			needclear1 = nil
		end
		return
	end
	local ok, data = pcall(skynet.call, redis, "lua", "execute", "ZREVRANGE", rankname.."1", 0, 100, "WITHSCORES")
	if ok then
		-- LOG_DEBUG("list name:"..rankname.."1")
		-- luadump(data)
		range1 = {}
		if data and #data > 0 then
			local info,score
			local nickname,uid
			for i=1,(#data/2) do
				info = data[(i-1)*2+1]
				score = data[(i-1)*2+2]
				uid,nickname = string.match(info, "([^:]*):([^:]*)")
				nickname = base64decode(nickname)
				range1[i] = {uid, score, nickname}
			end
		end
	else
		LOG_DEBUG("链接redis失败，请重试:")
	end
end

local function rank_list_2(time)
	-- 累计红包榜
	local ok, data = pcall(skynet.call, redis, "lua", "execute", "ZREVRANGE", rankname.."2", 0, 100, "WITHSCORES")
	if ok then
		-- LOG_DEBUG("list name:"..rankname.."2")
		-- luadump(data)
		range2 = {}
		if data and #data > 0 then
			local info,score
			local nickname,uid
			for i=1,(#data/2) do
				info = data[(i-1)*2+1]
				score = data[(i-1)*2+2]
				uid,nickname = string.match(info, "([^:]*):([^:]*)")
				nickname = base64decode(nickname)
				range2[i] = {uid, score, nickname}
			end
		end
	else
		LOG_DEBUG("链接redis失败，请重试")
	end
end

local function rank_list_3(time)
	-- 财富榜
	local ok, data = pcall(skynet.call, redis, "lua", "execute", "ZREVRANGE", rankname.."3", 0, 100, "WITHSCORES")
	if ok then
		-- LOG_DEBUG("list name:"..rankname.."3")
		-- luadump(data)
		range3 = {}
		if data and #data > 0 then
			local info,score
			local nickname,uid
			for i=1,(#data/2) do
				info = data[(i-1)*2+1]
				score = data[(i-1)*2+2]
				uid,nickname = string.match(info, "([^:]*):([^:]*)")
				nickname = base64decode(nickname)
				range3[i] = {uid, score, nickname}
			end
		end
	else
		LOG_DEBUG("链接redis失败，请重试")
	end
end

local function tick_tick()
	local time
	while true do
		time = os.time()
		rank_list_1(time)
		skynet.sleep(100)
		rank_list_2(time)
		skynet.sleep(100)
		rank_list_3(time)
		skynet.sleep(5*100)
		lasttime = time
	end
end

function CMD.get_range(type)
	LOG_DEBUG("type="..type)
	if type == 1 then
		return range1
	elseif type == 2 then
		return range2
	elseif type == 3 then
		return range3
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		-- LOG_DEBUG("需要执行:"..command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
	
	redis = skynet.uniqueservice("redispool")

	lasttime = os.time()
	skynet.fork(tick_tick)
end)

