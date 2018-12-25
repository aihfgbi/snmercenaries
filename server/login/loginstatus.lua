local skynet = require "skynet"
local cluster = require "skynet.cluster"

local CMD = {}

local user_map = {}
local user_cnt = 0

local gate_map = {}

local redis
-- function CMD.user_kick(uid)
-- 	-- 踢出玩家
-- end

function CMD.user_online(uid, node, addr, fd)
	-- 如果玩家重复登陆，那么会挤掉上一个号
	LOG_DEBUG("user online:"..uid..",count:"..user_cnt)
	if not gate_map[node] then
		gate_map[node] = {addr = addr, count = 0}
	end
	local u = user_map[uid]
	if u and u.node and u.addr and u.fd then
		if u.node ~= node and u.addr ~= addr and u.fd ~= fd then
			LOG_DEBUG("same user:"..node..","..addr)
			-- 被挤下线
			pcall(cluster.call, node, addr, "kick", u.fd, 1)
		else
			LOG_DEBUG("same fd,node,addr")
			user_cnt = user_cnt - 1
		end
	end
	user_cnt = user_cnt + 1
	user_map[uid] = {node = node, addr = addr, fd = fd}
end

function CMD.user_offline(uid)
	if user_map[uid] then
		user_cnt = user_cnt - 1
		LOG_DEBUG("user offline:"..uid..",count="..user_cnt)
		user_map[uid] = nil
	end
end

function CMD.gate_online(node, addr)
	LOG_DEBUG("gate online:"..node..","..addr)

	gate_map[node] = {addr=addr, count=0}

	for uid,u in pairs(user_map) do
		if u and u.node == node and u.addr == addr then
			-- 如果gate刚刚上线
			user_map[uid] = nil
			user_cnt = user_cnt - 1
		end
	end
end

function CMD.gate_status()
	return user_cnt, gate_map
end

function CMD.ctrl_gate(node, cmd)
	-- 1  关服
	-- 2  滚服
	-- 3  重新开启
	cmd = tonumber(cmd)
	if not cmd or cmd > 3 or cmd < 1 then return 3 end
	LOG_DEBUG("ctrl_gate:"..node..","..cmd)
	local info = gate_map[node]
	if info and info.addr then
		local ok, result = pcall(cluster.call, node, info.addr, "ctrl", cmd)
		if ok and result then
			return 0
		end
		return 1
	end
	return 2
end

--[[
	@desc: 网关的心跳,++记录每个网关的链接人数，把人数最少的网关存到redis，客户端获取后进行链接
	++
    author:{author}
    time:2018-09-30 17:40:45
    @return:
]]
local function gate_heart()
	while true do
		skynet.sleep(5*100)

		for node,v in pairs(gate_map) do
			if node and v and v.addr then
				local ok, count = pcall(cluster.call, node, v.addr, "heart")
				if ok then
					gate_map[node].count = count or 0
					--LOG_DEBUG(node..","..v.addr..":"..gate_map[node].count)
				else
					gate_map[node] = nil
				end
			end
		end
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	skynet.fork(gate_heart)

	redis = skynet.uniqueservice("redispool")
end)
