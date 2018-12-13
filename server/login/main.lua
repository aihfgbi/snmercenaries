local skynet = require "skynet"
local cluster = require "skynet.cluster"

local nodename = skynet.getenv("nodename")

skynet.start(function()

	local loginstatus = skynet.uniqueservice("loginstatus")
	cluster.register("loginstatus", loginstatus)
	cluster.open(nodename)--打开在clustername.lua里面写的对应节点的监听
	skynet.exit()
end)
