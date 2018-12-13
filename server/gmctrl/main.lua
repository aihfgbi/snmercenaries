local skynet = require "skynet"
local cluster = require "skynet.cluster"

local nodename = skynet.getenv("nodename")

skynet.start(function()

	local userctrl = skynet.uniqueservice("userctrl")
	cluster.register("userctrl", userctrl)
	cluster.open(nodename)--打开在clustername.lua里面写的对应节点的监听
	skynet.exit()
end)
