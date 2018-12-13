local skynet = require "skynet"
local cluster = require "skynet.cluster"

local nodename = skynet.getenv("nodename")

local crypt = require "skynet.crypt"
local json = require "cjson"

local base64encode = crypt.base64encode
local base64decode = crypt.base64decode


skynet.start(function()
	-- skynet.uniqueservice("debug_console",8000)
	-- skynet.newservice("simpledb")

	local redis = skynet.uniqueservice("redispool")
	skynet.call(redis, "lua", "start")

	local logredis = skynet.uniqueservice("logredispool")
	skynet.call(logredis, "lua", "start")

	-- skynet.getenv("mysql_maxconn")
	local cfg ={
		host = skynet.getenv("mysql_host"),
		port = tonumber(skynet.getenv("mysql_port")),
		database = skynet.getenv("mysql_db"),
		user = skynet.getenv("mysql_user"),
		password = skynet.getenv("mysql_pwd"),
		max_packet_size = 1024 * 1024
	}
	--local mysqlpool = skynet.newservice("mysqlpool", ".mysqlpool")
	--skynet.call(mysqlpool, "lua", "start", cfg, skynet.getenv("mysql_maxconn"))

	cfg ={
		host = skynet.getenv("his_mysql_host"),
		port = tonumber(skynet.getenv("his_mysql_port")),
		database = skynet.getenv("his_mysql_db"),
		user = skynet.getenv("his_mysql_user"),
		password = skynet.getenv("his_mysql_pwd"),
		max_packet_size = 1024 * 1024
	}
	--local histroysql = skynet.newservice("mysqlpool", ".histroysql")
	--skynet.call(histroysql, "lua", "start", cfg, skynet.getenv("mysql_maxconn"))

	skynet.uniqueservice("rankserver")
	
	local usermanager = skynet.uniqueservice("usermanager")
	cluster.register("manager", usermanager) --在本地进程内调用 cluster.register(name [,addr]) 可以把 addr 注册为 cluster 可见的一个字符串名字 name 。如果不传 addr 表示把自身注册为 name 。
	cluster.open(nodename) --打开在clustername.lua里面写的对应节点的监听
	skynet.exit()
end)
