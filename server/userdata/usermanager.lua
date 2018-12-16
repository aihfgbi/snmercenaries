-- 每个userdata在用户离线之后，会保持在线5分钟
-- 与网关的心跳时间是5秒，所以如果要在线切换网关或者重启网关的时候，老的网关必须离线超过10秒以上

local skynet = require "skynet"
local cluster = require "skynet.cluster"
local cfgRoom = require "room_conf"
local sharedata = require "skynet.sharedata"
local socket = require "skynet.socket"
local json = require "cjson"
local nodename = skynet.getenv("nodename")
local nodeindex = tonumber(skynet.getenv("nodeindex"))
local dbscnt = tonumber(skynet.getenv("dbs_count"))
local gamecnt = skynet.getenv("game_count")
local centerbank = skynet.getenv("use_center_bank")

local CMD = {}

local user_map = {}
local user_cnt = 0 --持有的userdata数量，不是在线人数
local gate_list = {}  -- nodename ====> timeoutcnt
local game_list = {} --gameid ====> {nodename, nodename...}
local goldgame_list = {} --gameid ====> {nodename, nodename...}
local match_list = {}
local game_manager = {}
local goldgame_manager = {}
local match_manager = {}
local bank_fd
local bank_session = 0
local bank_proto = {}

local function get_bank_session()
	bank_session = bank_session + 1
	if bank_session > 0xffffff00 then
		bank_session = 1
	end
	return bank_session
end

local function get_index_by_code(code)
	local index = math.floor(code/100)
	index = code - index * 100
	return index
end

local function get_game_manager(gameid, uid, index)
	local node
	if gameid then
		local list = game_list[gameid]
		if not list or #list < 1 then return end
		node = list[uid%#list+1]
	elseif index then
		if index > gamecnt - 1 then
			return
		end
		node = "game"..index
	end

	if not node then return end

	if not game_manager[node] then
		LOG_DEBUG("查询节点地址:"..node)
		local ok, addr = pcall(cluster.query, node, "manager")
		if ok and addr then
			LOG_DEBUG("获得地址:"..addr)
			game_manager[node] = addr
		else
			LOG_DEBUG(addr)
		end
	end

	return node, game_manager[node]
end

local function get_goldgame_manager(gameid, uid, index)
	local node
	if gameid then
		local list = goldgame_list[gameid]
		if not list or #list < 1 then return end
		node = list[uid%#list+1]
	elseif index then
		node = "goldgame"..index
	end

	if not node then return end

	if not goldgame_manager[node] then
		LOG_DEBUG("查询节点地址:"..node)
		local ok, addr = pcall(cluster.query, node, "manager")
		if ok and addr then
			LOG_DEBUG("获得地址:"..addr)
			goldgame_manager[node] = addr
		else
			LOG_DEBUG(addr)
		end
	end

	return node, goldgame_manager[node]
end

local function get_match_manager(matchid, uid, index)
	local node
	if matchid then
		local list = match_list[matchid]
		if not list or #list < 1 then return end
		node = list[uid%#list+1]
	elseif index then
		node = "match"..index
	end

	if not node then return end

	if not match_manager[node] then
		LOG_DEBUG("查询节点地址:"..node)
		local ok, addr = pcall(cluster.query, node, "manager")
		if ok and addr then
			LOG_DEBUG("获得地址:"..addr)
			match_manager[node] = addr
		else
			LOG_DEBUG(addr)
		end
	end

	return node, match_manager[node]
end

local function gate_offline(node)
	for uid,u in pairs(user_map) do
		if u and u.gatenode == node and u.userdata then
			skynet.call(u.userdata, "lua", "offline", uid)
		end
	end
end

local function check_gate_heart()
	while true do
		for node,v in pairs(gate_list) do
			gate_list[node] = gate_list[node] + 1
			if v > 1 then
				LOG_DEBUG(node.."离线了")
				gate_list[node] = nil
				gate_offline(node)
			end
		end
		skynet.sleep(5*100)
	end
end

local function get_offline_userdata(uid)
	local u = user_map[uid]
	if not u then
		local userdata = skynet.newservice("userdata")
		skynet.call(userdata, "lua", "start", skynet.self(), nodename)
		local ok = skynet.call(userdata, "lua", "offline_use", uid)
		if not ok then return end
		user_cnt = user_cnt + 1
		u = {userdata=userdata,gatenode=0}
		user_map[uid] = u
	end

	return u.userdata
end


local function connect_to_bank()
	if bank_fd then
		socket.close(bank_fd)
	end
	LOG_DEBUG("开始连接银行...")
	local ok
	ok, bank_fd = pcall(socket.open, skynet.getenv("bank_host"), skynet.getenv("bank_port"))
	if not ok or not bank_fd then
		LOG_ERROR("银行链接失败:"..tostring(bank_fd))
		skynet.sleep(500) --5秒后重新连接
		skynet.fork(connect_to_bank)
		return
	end
	LOG_DEBUG("连接上银行:"..skynet.getenv("bank_host").."@"..skynet.getenv("bank_port")..",bank_fd:"..tostring(bank_fd))
	while true do
		local done, str = pcall(socket.readline, bank_fd)
		if done and str then
			LOG_DEBUG(str)
			local ok, info = pcall(json.decode, str)
			if ok and info then
				if info.session and info.session and info.session > 0 then
					bank_proto[info.session] = info
				else
					if info.action == "change" and info.uid and info.bank then
						-- {"action":"change", "uid":100001, "taskid":34, "value":"-123", "bank":1234 ,"code":0}
						local uid = math.modf(info.uid)
						LOG_DEBUG("uid="..uid..",dbscnt="..dbscnt..",nodeindex="..nodeindex..","..tostring(uid%dbscnt))
						if (uid % dbscnt) == nodeindex then
							-- 本节点处理
							-- set_bank(uid, value, reason)
							-- local userdata = get_offline_userdata(uid)
							-- if userdata then
							-- 	return skynet.call(userdata, "lua", "set_bank", uid, info.bank, 1002)
							-- end
							local u = user_map[uid]
							if u and u.userdata then
								-- u.userdata
								skynet.call(u.userdata, "lua", "set_bank", uid, info.bank, 1002)
							end

							info.code = 0
							local str = json.encode(info)
							LOG_DEBUG("rep="..str)
							socket.write(bank_fd, str.."\n")
							skynet.sleep(1)
						end
					else
						
					end
				end
			else
				LOG_ERROR("银行数据出错:"..tostring(str)..",")
				bank_fd = nil
				skynet.fork(connect_to_bank)
				return
			end
		else
			LOG_DEBUG("链接中断!!")
			bank_fd = nil
			skynet.fork(connect_to_bank)
			break
		end
	end
end

local function receive_data(session)
	local count = 1
	while true do
		if bank_proto[session] then
			local data = bank_proto[session]
			bank_proto[session] = nil
			return data
		end
		count = count + 1
		if count > 300 then
			LOG_DEBUG("超时了")
			local fd = bank_fd
			bank_fd = nil
			socket.close(fd)
			return
		end
		skynet.sleep(1)
	end
end
-- bank	{"action":"query","uid":100001, "session":12}
-- 返回		{"action":"query","uid":100001, "session":12, "bank"=1234,"code"=0}
function CMD.query_bank(uid)
	LOG_DEBUG("bank_fd="..tostring(bank_fd))
	if not bank_fd then return end
	local session = get_bank_session()
	local ok = pcall(socket.write, bank_fd, '{"action":"query","uid":'..uid..', "session":'..session..'}'.."\n")
	if not ok then
		LOG_DEBUG("query_bank write error:"..tostring(uid))
		return
	end
	local data = receive_data(session)
	luadump(data)
	if data and data.uid == uid and data.bank and data.code == 0 then
		return data.bank
	end
end

function CMD.add_bank(uid, value)
	if not bank_fd then return end
	if not value or value < 0 then return end
	local session = get_bank_session()
	local cmd = '{"action":"save","uid":'..uid..', "session":'..session..', "value":'..value..'}'
	LOG_DEBUG("write::::"..cmd)
	local ok = pcall(socket.write, bank_fd, cmd.."\n")
	if not ok then
		LOG_DEBUG("add_bank write error:"..tostring(uid))
		return
	end
	local data = receive_data(session)
	luadump(data)
	if data and data.uid == uid and data.code == 0 then
		return data.bank
	end
	LOG_DEBUG("存钱失败！！！")
	return nil
end

function CMD.sub_bank(uid, value)
	if not bank_fd then return end
	if not value or value < 0 then return end
	local session = get_bank_session()
	local cmd = '{"action":"save","uid":'..uid..', "session":'..session..', "value":-'..value..'}'
	LOG_DEBUG("write::::"..cmd)
	local ok = pcall(socket.write, bank_fd, cmd.."\n")
	if not ok then
		LOG_DEBUG("sub_bank write error:"..tostring(uid))
		return
	end
	local data = receive_data(session)
	luadump(data)
	if data and data.uid == uid and data.code == 0 then
		return data.bank
	end
	LOG_DEBUG("取钱失败！！！")
	return nil
end


function CMD.forward(uid, nn)
	local u = user_map[uid]
	if not u then
		local userdata = skynet.newservice("userdata") --如果没有用户列表就第一次启动userdata，调用start，用户数量加1
		skynet.call(userdata, "lua", "start", skynet.self(), nodename)
		user_cnt = user_cnt + 1
		u = {userdata=userdata,gatenode=nn}
		user_map[uid] = u
		LOG_DEBUG("userdata count:"..user_cnt)
	end

	LOG_DEBUG("user forward:"..uid)
	u.gatenode = nn

	return u.userdata
end

-- 只给userdata调用，其他服务不能调用此接口
function CMD.unforward(uid)
	if user_map[uid] then
		user_map[uid] = nil
		user_cnt = user_cnt - 1
		LOG_DEBUG("unforward:"..uid)
	end
end

function CMD.bind_parent(child, parent)
	local userdata = get_offline_userdata(parent)
	if userdata then
		return skynet.call(userdata, "lua", "bind_parent", parent, child)
	end
	return false
end

-- 增加一个完成的下级
function CMD.add_done_child(parent, child)
	local userdata = get_offline_userdata(parent)
	if userdata then
		return skynet.call(userdata, "lua", "add_done_child", parent, child)
	end
	return false
end

function CMD.sub_gold(uid, gold, reason)
	-- offline_use
	local userdata = get_offline_userdata(uid)
	if userdata then
		return skynet.call(userdata, "lua", "sub_gold", uid, gold, reason)
	end
	return false
end

function CMD.add_gold(uid, gold, reason)
	local userdata = get_offline_userdata(uid)
	if userdata then
		return skynet.call(userdata, "lua", "add_gold", uid, gold, reason)
	end
	return false
end

function CMD.sub_money(uid, money, reason)
	-- offline_use
	local userdata = get_offline_userdata(uid)
	if userdata then
		return skynet.call(userdata, "lua", "sub_money", uid, money, reason)
	end
	return false
end

function CMD.add_money(uid, money, reason)
	local userdata = get_offline_userdata(uid)
	if userdata then
		return skynet.call(userdata, "lua", "add_money", uid, money, reason)
	end
	return false
end

function CMD.transfer_bank(uid, value, fromuid)
	local userdata = get_offline_userdata(uid)
	if userdata then
		return skynet.call(userdata, "lua", "transfer_bank", uid, value, fromuid)
	end
	return false
end

function CMD.check_user(uid)
	local userdata = get_offline_userdata(uid)
	if userdata then return true end
	return false
end

function CMD.get_user_json(uid)
	local userdata = get_offline_userdata(uid)
	if userdata then
		return skynet.call(userdata, "lua", "get_json")
	end
	return "{'msg':'error'}"
end

function CMD.gm_cmd(uid,cmd, ...)
	local userdata = get_offline_userdata(uid)
	if userdata then
		return skynet.call(userdata, "lua", "gm_cmd", uid, cmd, ...)
	end
	return false
end


function CMD.charge(uid, value, channel, order)
	local userdata = get_offline_userdata(uid)
	if userdata then
		LOG_DEBUG("charge")
		return skynet.call(userdata, "lua", "charge", uid, value, channel, order)
	end
	return false
end

function CMD.task_add_friend(uid, tType, target, cnt, childuid)
	local userdata = get_offline_userdata(uid)
	if userdata then
		LOG_DEBUG("task_add_friend")
		return skynet.call(userdata, "lua", "check_task", uid, tType, target, cnt, childuid)
	end
	return false
end


function CMD.gate_heart(nodename)
	--LOG_DEBUG("register gate:"..nodename)
	gate_list[nodename] = 0
end

-- 开房模式创建房间
-- 1000 游戏服务器链接不上
-- 1001 请再试一次
-- 1002 gameid错误
-- 1003 score参数错误
-- 1004 times参数错误
function CMD.create_table(gameid, pay, score, times, player, params)
	LOG_DEBUG("create_table:"..gameid)
	local gamenode, manager = get_game_manager(gameid, player.uid)
	if not manager or not gamenode then return 1000 end
	local ok, node, addr = pcall(cluster.call, gamenode, manager, "create", gameid, pay, score, times, player, params)
	if not ok then
		game_manager[gamenode] = nil
		return 1000
	end
	return node, addr
end

-- 开房模式加入房间
function CMD.join_table(code, player)
	local index = get_index_by_code(code)
	LOG_DEBUG("获得index="..index..",code="..code)
	local gamenode, manager = get_game_manager(nil, player.uid, index)
	if not manager or not gamenode then return 1005 end
	local ok, node, addr, gid = pcall(cluster.call, gamenode, manager, "join", code, player)
	if not ok then
		game_manager[gamenode] = nil
		return 1005
	end
	-- LOG_DEBUG("join_table:"..code..",uid="..player.uid..",addr="..tostring(addr))
	return node, addr, gid
end

-- 金币模式加入房间
function CMD.quick_join(gameid, player)
	local gamenode, manager = get_goldgame_manager(gameid, player.uid) --查询节点名字和地址
	if not gamenode or not manager then return 1000 end
	local ok, node, addr = pcall(cluster.call, gamenode, manager, "join", gameid, player) --调用节点里面的manager服务里面的join
	if not ok then
		LOG_DEBUG(tostring(node))
		goldgame_manager[gamenode] = nil
		return 1000
	end
	-- LOG_DEBUG("join_table:"..code..",uid="..player.uid..",addr="..tostring(addr))
	return node, addr
end

-- 加入比赛
function CMD.join_match(matchid, player)
	local gamenode, manager = get_match_manager(matchid, player.uid)
	if not gamenode or not manager then return 1000 end
	local ok, node, addr = pcall(cluster.call, gamenode, manager, "join", matchid, player)
	if not ok then
		LOG_DEBUG(tostring(node))
		match_manager[gamenode] = nil
		return 1000
	end
	return node, addr
end

function CMD.dissolve_table(code, uid)
	local index = get_index_by_code(code)
	LOG_DEBUG("获得index="..index..",code="..code)
	local gamenode, manager = get_game_manager(nil, uid, index)
	if not manager or not gamenode then return 1000 end
	local ok, result = pcall(cluster.call, gamenode, manager, "dissolve_table", code, uid)
	if ok and result then
		LOG_DEBUG(result)
		return result
	end
	return 1000
end

function CMD.query_online_user(gmnode, gmaddr)
	local player_list = {{}}
	local index = 1
	for uid, data in pairs(user_map) do
		local ok, result = pcall(skynet.call, data.userdata, "lua", "query_player_info", uid)
		if ok then
			--每20个玩家数据放一组方便发送
			if #(player_list[index]) == 20 then
				index = index + 1
				player_list[index] = {}
			end
			table.insert(player_list[index], result)
		end
	end

	if #player_list[1] > 0 then
		for i=1, #player_list do
			local ok, result = pcall(cluster.send, gmnode, gmaddr, "receive_player_list", table.remove(player_list))
			if not ok then
				LOG_ERROR("send player list faild : %s", tostring(result))
			end
		end
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	skynet.fork(check_gate_heart)

	-- this["goldgame1"] = {type="gold", fish={4001}, niuniu={1001,1002,1003}, jdddz={2001, 2002}}
	-- this["game1"] = {type="table", fish={4001}, niuniu={1001,1002,1003}, jdddz={2001, 2002}}
	-- this["match0"] = {type="match", list={1001,2001}}
	for nodename,node in pairs(cfgRoom) do
		if node.type == "gold" then
			-- goldgame_list
			for key,v in pairs(node) do
				if key ~= "type" then
					for _,gameid in ipairs(v) do
						goldgame_list[gameid] = goldgame_list[gameid] or {}
						if not table.indexof(goldgame_list[gameid], nodename) then
							table.insert(goldgame_list[gameid], nodename)
						end
					end
				end
			end
		elseif node.type == "table" then
			for key,v in pairs(node) do
				if key ~= "type" then
					for _,gameid in ipairs(v) do
						game_list[gameid] = game_list[gameid] or {}
						if not table.indexof(game_list[gameid], nodename) then
							table.insert(game_list[gameid], nodename)
						end
					end
				end
			end
		elseif node.type == "match" then
			-- match_list
			for _,id in pairs(node.list) do
				match_list[id] = match_list[id] or {}
				if not table.indexof(match_list[id], nodename) then
					table.insert(match_list[id], nodename)
				end
			end
		end
	end

	if centerbank then
		skynet.fork(connect_to_bank)
	end

	sharedata.new("shop_conf", require("shop_conf"))
	sharedata.new("goods_conf", require("goods_conf"))
	sharedata.new("data_conf", require("data_conf"))
	sharedata.new("task_conf", require("task_conf"))
end)
