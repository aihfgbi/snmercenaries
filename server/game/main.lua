local skynet = require "skynet"
local cluster = require "skynet.cluster"

local nodename = skynet.getenv("nodename")

skynet.start(function()
	local redis = skynet.uniqueservice("redispool")
	skynet.call(redis, "lua", "start")
	local logredis = skynet.uniqueservice("logredispool")
	skynet.call(logredis, "lua", "start")
	
	local manager
	if nodename:match("goldgame") then
		manager = skynet.uniqueservice("goldgamemanager")
	elseif nodename:match("match") then
		manager = skynet.uniqueservice("matchmanager")
	else 
		manager = skynet.uniqueservice("gamemanager")
	end
	LOG_DEBUG("game name: "..nodename..",game manager: "..manager)
	cluster.register("manager", manager)
	cluster.open(nodename)--打开在clustername.lua里面写的对应节点的监听
	skynet.exit()
end)
