
local skynet = require "skynet"
require "skynet.manager"
local ssdb = require "ssdb"

local CMD = {}
local pool = {}

local maxconn
local index = 1

local function getconn()
	local db = pool[index]
	index = index + 1
	if index > maxconn then
		index = 1
	end
	return db
end

function CMD.start()
	maxconn = tonumber(skynet.getenv("ssdb_maxconn")) or 10
	assert(maxconn >= 2)

	LOG_INFO("ssdbpool stat init, maxconn=%d", maxconn)

	for i = 1, maxconn do
		local db = ssdb.connect{
			host = skynet.getenv("ssdb_host"),
			port = tonumber(skynet.getenv("ssdb_port")),
			password = skynet.getenv("ssdb_pwd"),
		}

		if db then
			table.insert(pool, db)
			LOG_INFO("ssdb conn(%d) %s:%d connect ok", i, skynet.getenv("ssdb_host"), tonumber(skynet.getenv("ssdb_port")))
		else
			LOG_ERROR("!!ssdb connect error")
		end
	end
end

function CMD.execute(opt, ...)
	local db = getconn()

	local f = db[opt]

	if f then
		return f(db, ...)
	else
		LOG_WARNING("[ssdbpool] unknow opt type:"..(opt or ""))
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

	skynet.register(".ssdbpool")
end)
