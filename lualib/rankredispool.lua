

local skynet = require "skynet"
local redis = require "redis"

local CMD = {}
local pool = {}

local maxconn
local index = 1

local rank_redis_pwd = skynet.getenv("rank_redis_pwd")
if rank_redis_pwd == "" then
	rank_redis_pwd = nil
end

local conf = {
		host = skynet.getenv("rank_redis_host") ,
		port = skynet.getenv("rank_redis_port") ,
		--auth = skynet.getenv("rank_redis_pwd") ,
		auth = rank_redis_pwd,
	}

local function getconn()
	local db = pool[index]
	index = index + 1
	if index > maxconn then
		index = 1
	end
	return db
end

function CMD.start()
	maxconn = tonumber(skynet.getenv("redis_maxconn")) or 3
	assert(maxconn >= 2)

	LOG_INFO("rankredispool stat init, maxconn=%d", maxconn)

	for i = 1, maxconn do
		local db = redis.connect(conf)

		if db then
			table.insert(pool, db)
			LOG_INFO("redis conn(%d) %s:%d connect ok", i, conf.host, tonumber(conf.port))
		else
			LOG_ERROR("!!redis connect error")
		end
	end
end

function CMD.execute(opt, ...)
	local db = getconn()

	local f = db[opt]

	if f then
		return f(db, ...)
	else
		LOG_WARNING("[redispool] unknow opt type:"..(opt or ""))
	end
end

function CMD.stop()
	for _, db in pairs(pool) do
		db:disconnect()
	end
	pool = {}
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = assert(CMD[cmd], cmd .. "not found")
		skynet.retpack(f(...))
	end)
end)
