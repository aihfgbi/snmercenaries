local skynet = require "skynet"

if skynet.getenv("daemon") then
	CONSOLE_LOG = false
end

NODE_NAME = skynet.getenv("nodename")

local SERVICE_NAME = SERVICE_NAME

function LOG_DEBUG(fmt, ...)
	local params = {...}
	local msg
	if #params > 0 then
		msg = string.format(fmt, ...)
		local info = debug.getinfo(2)
		if info then
			msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
		end
	else
		msg = fmt
		local info = debug.getinfo(2)
		if info then
			msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
		end
	end

	skynet.error(msg)
	-- skynet.send(".logger", "lua", "debug", SERVICE_NAME, msg)
end

function LOG_INFO(fmt, ...)
	local msg = string.format(fmt, ...)
	local info = debug.getinfo(2)
	if info then
		msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
	end

	skynet.send(".logger", "lua", "info", SERVICE_NAME, msg)
end

function LOG_WARNING(fmt, ...)
	local msg = string.format(fmt, ...)
	local info = debug.getinfo(2)
	if info then
		msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
	end

	skynet.send(".logger", "lua", "warning", SERVICE_NAME, msg)
end

function LOG_ERROR(fmt, ...)
	local msg = string.format(fmt, ...)
	local info = debug.getinfo(2)
	if info then
		msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
	end

	skynet.send(".logger", "lua", "error", SERVICE_NAME, msg)
end

function LOG_FATAL(fmt, ...)
	local msg = string.format(fmt, ...)
	local info = debug.getinfo(2)
	if info then
		msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
	end

	skynet.send(".logger", "lua", "fatal", SERVICE_NAME, msg)
end
