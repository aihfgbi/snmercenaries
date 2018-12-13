local skynet = require "skynet"
require "skynet.manager"
local mysql = require "skynet.db.mysql"

local CMD = {}
local pool = {}

local maxconn
local index = 1
local name = ...

local function getconn()
	local db = pool[index]
	index = index + 1
	if index > maxconn then
		index = 1
	end
	return db
end

function CMD.start(cfg, maxcnt)
	maxconn = tonumber(maxcnt) or 10
	assert(maxconn >= 2)

	LOG_INFO("mysqlpool stat init, maxconn=%d", maxconn)

	for i = 1, maxconn do
		local db = mysql.connect(cfg)
		if db then
			table.insert(pool, db)
			db:query("set names utf8")
			LOG_INFO("mysql conn(%d) %s:%d %s connect ok", i, cfg.host, tonumber(cfg.port), cfg.database)
		else
			LOG_ERROR("!!mysql connect error")
		end
	end
end

function CMD.execute(sql)
	local db = getconn()
	return db:query(sql)
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

	LOG_DEBUG("register:"..name)
	skynet.register(name)
end)
