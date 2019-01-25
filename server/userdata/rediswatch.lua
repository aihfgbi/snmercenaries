local skynet = require "skynet"
local crypt = require "skynet.crypt"
local redisWatch = skynet.getenv("redis_watch")
local base64decode = crypt.base64decode
local CMD = {}
local redis = require "skynet.db.redis"
local _logredis

local redis_pwd = skynet.getenv("redis_pwd")
if redis_pwd == "" then
	redis_pwd = nil
end

local conf = {
		host = skynet.getenv("redis_host") ,
		port = skynet.getenv("redis_port") ,
		auth = redis_pwd ,
	}

function watching()
	local w = redis.watch(conf)
	w:subscribe("admin-pubsub")
	-- w:psubscribe "hello.*"
	while true do
		luadump(w:message(),"Watch==")
	end
end

function test(  )
	while true do
		local ok,a = pcall(
			skynet.send,
			_logredis,
			"lua",
			"publishMsg",
			"admin-pubsub",
			"123asdgadaeadsgads"
		)
		if ok then
			-- body
			LOG_DEBUG("发送成功"..a)
		end
		skynet.sleep(5*100)
	end
end

skynet.start(function()
	LOG_DEBUG("开起监听")
	skynet.dispatch("lua", function(_,_, command, ...)
		-- LOG_DEBUG("需要执行:"..command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
	_logredis = skynet.uniqueservice("redispool")
	skynet.fork(watching)
end)

