local skynet = require "skynet"
local cluster = require "skynet.cluster"

local nodename = skynet.getenv("nodename")
local port = skynet.getenv("port")

skynet.start(function()
	local redis = skynet.uniqueservice("redispool")
	skynet.call(redis, "lua", "start")
	local httpgate = skynet.uniqueservice("httpgate", port)
	cluster.register("httpgate", httpgate)
	cluster.open(nodename)--打开在clustername.lua里面写的对应节点的监听
	skynet.exit()
end)

