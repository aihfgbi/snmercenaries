local skynet = require "skynet"
require "skynet.manager"
local logger = require "log.core"

local LOG_PATH = skynet.getenv("customs_log_path")
 
local CMD = {}

local nodename = skynet.getenv("nodename")

function CMD.start()
	logger.init(LOG_LEVEL, 100, 5, CONSOLE_LOG or false, LOG_PATH, skynet.getenv("nodename"))
end

function CMD.stop( )
	logger.exit()
end

function CMD.debug(source, name, msg)
	logger.debug(string.format("[%s-%d] %s", nodename, source, msg))
end

function CMD.info(source, name, msg)
	logger.info(string.format("[%s-%d] %s", nodename, source, msg))
end

function CMD.warning(source, name, msg)
	logger.warning(string.format("[%s-%d] %s", nodename, source, msg))
end

function CMD.error(source, name, msg)
	logger.error(string.format("[%s-%d] %s", nodename, source, msg))
end

function CMD.fatal(source, name, msg)
	logger.fatal(string.format("[%s-%d] %s", nodename, source, msg))
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = assert(CMD[cmd], cmd .. "not found")
		if cmd == "start" or cmd == "stop" then
			skynet.retpack(f(...))
		else
			f(source, ...)
		end
	end)

	logger.init(LOG_LEVEL, 100, 5, CONSOLE_LOG or false, LOG_PATH, skynet.getenv("nodename"))

	skynet.register(".logger")
end)


skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	unpack = skynet.tostring,
	dispatch = function(_, address, msg)
		logger.warning(string.format("[%s-%d] %s", nodename, address, msg))
	end
}
