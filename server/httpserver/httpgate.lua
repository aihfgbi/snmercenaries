local skynet = require "skynet"
local socket = require "skynet.socket"
local json = require "cjson"
local sharedata = require "skynet.sharedata"
local crypt = require "skynet.crypt"

local port = ...

local function read_file(url)
	-- body
	local f = io.open(url)
	if f then
		local data = f:read("*a")
		f:close()
		return data
	end
	LOG_INFO("open file:%s fail. ", url or "")
	return false
end

local function read_user_conf()
	-- local str = read_file("../../config/admin.json")

	-- local ok, info = pcall(json.decode, str)
	while true do
		pcall(sharedata.update, "admin_conf", "@../service/config/admin_conf.lua")

		skynet.sleep(30*100)
	end
end

skynet.start(function()
	local agent = {}
	for i= 1, 2 do
		-- 启动 20 个代理服务用于处理 http 请求
		agent[i] = skynet.newservice("httpagent")
	end

	sharedata.new("admin_conf", {})
	skynet.fork(read_user_conf)

	-- LOG_DEBUG("==========")
	local balance = 1
	-- 监听一个 web 端口
	LOG_DEBUG("http listen:"..port)
	local id = socket.listen("0.0.0.0", port)  
	socket.start(id , function(id, addr)  
		-- 当一个 http 请求到达的时候, 把 socket id 分发到事先准备好的代理中去处理。
		skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
		skynet.send(agent[balance], "lua", id)
		balance = balance + 1
		if balance > #agent then
			balance = 1
		end
	end)
end)
