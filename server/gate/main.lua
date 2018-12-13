local skynet = require "skynet"
local cluster = require "skynet.cluster"

local max_client = skynet.getenv "max_client"
local port = skynet.getenv "port"
local nodename = skynet.getenv("nodename")

skynet.start(function()
	skynet.error("Server start")

	local redis = skynet.uniqueservice("redispool")
	skynet.call(redis, "lua", "start")

	local loginType
	if nodename:find("webgate") then
		LOG_DEBUG("webgate!!")
		loginType = "webgate"
	else
		LOG_DEBUG("gate")
		loginType = "gate"
	end
	local auth = skynet.uniqueservice("auth")
	skynet.call(auth, "lua", "start", {
		port = port,
		maxclient = tonumber(max_client),
		nodelay = true,
		loginType = loginType,
		watchdog
	})
	skynet.error("gate listen on", port)
	cluster.open(nodename)--打开在clustername.lua里面写的对应节点的监听
	skynet.exit()
end)
