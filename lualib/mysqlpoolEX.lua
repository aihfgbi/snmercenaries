local skynet = require "skynet"
require "skynet.manager"
local mysql = require "mysql"

local CMD = {}
local pool = {}

local _maxconn = 10
local index = 1

local function getconn()
	local db = pool[index]
	index = index + 1
	if index > _maxconn then
		index = 1
	end
	return db
end

function CMD.start(mysql_host, mysql_port, mysql_db, mysql_user, mysql_pwd)
	assert(_maxconn >= 2)
	LOG_INFO("mysqlpool stat init, _maxconn=%d", _maxconn)

	for i = 1, _maxconn do
		local db = mysql.connect{
			host = mysql_host,--skynet.getenv("mysql_host"),
			port = mysql_port,--tonumber(skynet.getenv("mysql_port")),
			database = mysql_db,--skynet.getenv("mysql_db"),
			user = mysql_user,--skynet.getenv("mysql_user"),
			password = mysql_pwd,--skynet.getenv("mysql_pwd"),
			max_packet_size = 1024 * 1024
		}
		if db then
			table.insert(pool, db)
			db:query("set names utf8")
			LOG_INFO("mysql conn(%d) %s:%d connect ok", i, mysql_host, mysql_port)
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

	skynet.register(".mysqlpoolEX")
end)
