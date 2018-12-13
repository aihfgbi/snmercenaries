local skynet = require "skynet"
local cluster = require "skynet.cluster"

local nodename = skynet.getenv("nodename")

local crypt = require "skynet.crypt"
local json = require "cjson"

local base64encode = crypt.base64encode
local base64decode = crypt.base64decode


skynet.start(function()
	local robotmanager = skynet.uniqueservice("robotmanager")
	cluster.register("manager", robotmanager)
	cluster.open(nodename)--打开在clustername.lua里面写的对应节点的监听
	skynet.exit()
end)
