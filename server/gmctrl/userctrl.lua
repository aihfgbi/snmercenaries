local skynet = require "skynet"
local cluster = require "skynet.cluster"
local proto = require "protologic"
local nodename = skynet.getenv("nodename")
local dbscnt = skynet.getenv("dbs_count")
local json = require "cjson"
--定义变量
local CMD = {}
local gm_list = {}
local user_map = {}

local usermanagers = {}
local _redis

local function get_dbnode_addr(name)
	local ok, addr = pcall(cluster.query, name, "manager")
	if ok and addr then
		return addr
	end
end

local function init_usermanagers()
	local dbnode_name = "dbs"
	for i=0, dbscnt-1 do
		dbnode_name = dbnode_name..i
		if not usermanagers[dbnode_name] then
			usermanagers[dbnode_name] = get_dbnode_addr(dbnode_name)
		end
	end
end

local function send_userdata(uid, cmd, ...)
	local player = user_map[uid]
	if player then
		local ok, result = pcall(cluster.send, player.datnode, player.dataddr, cmd, uid, ...)
		if not ok then
			LOG_ERROR("seng to userdata faild: %s", tostring(result))
		end
	else
		LOG_WARNING("player not in user_map")	
	end
end

local function send_usermanagers(cmd, ...)
	LOG_DEBUG("send_usermanagers cmd:%s", cmd)
	init_usermanagers()
	for name, addr in pairs(usermanagers) do
		local ok, result = pcall(cluster.send, name, addr, cmd, nodename, skynet.self(), ...)
		if not ok then
			LOG_ERROR("send_usermanager [%s] faild : %s", tostring(cmd), tostring(result))
			usermanagers[name] = nil
		end
	end
end

------------------api函数---------------
--发送消息给GM
local function send_msg(uid, name, msg)
	local gm_data = gm_list[uid]
	if not gm_data then
		LOG_WARNING("no gmdata matching uid[%s]", tostring(uid))
		return
	end
	local ok, result = pcall(cluster.send, gm_data.agnode, gm_data.agaddr, "send_to_client", gm_data.uid, name, msg)
	if not ok then
		LOG_ERROR("send_msg error:"..tostring(result))
		LOG_ERROR("name:"..name..",node:"..tostring(self.agnode)..",addr="..tostring(self.agaddr))
		return
	end
	
	-- --给接管的机器人发消息
	-- if self.replace_robot then
	-- 	send_msg(self.replace_robot, name, msg)
	-- end
end

--发送消息给所有GM（按等级）
local function send_to_all(level, name, msg)
	for uid, gmdata in pairs(gm_list) do
		if gmdata.level >= level then
--			LOG_DEBUG(uid..":"..name)
			send_msg(uid, name, msg)
		end
	end
end

--全局控制
--type：【1】输，【2】赢
--rate：0~100，0就是不控制
local function total_ctrl(type,rate)
	
end

--玩家开始控制(参数在proto赋值)
local function player_start_ctrl(uid)
	LOG_DEBUG("user[%s] start ctrl", tostring(uid))
	local player = user_map[uid]
	if player then
		local ctrl_info = {
			ctrltype = player.ctrltype,
			ctrlrate = player.ctrlrate,
			ctrlmaxgold = player.ctrlmaxgold,
			ctrlnowgold = player.ctrlnowgold,
			ctrlstarttime = player.ctrlstarttime,
			ctrloverttime = player.ctrloverttime,
			ctrllevel = player.ctrllevel,
			ctrlcount = player.ctrlcount,
			ctrlcaijin = player.ctrlcaijin,
		}
		
		send_userdata(uid, "player_start_ctrl", ctrl_info)
	else
		LOG_WARNING("player[%s] not exist", tostring(uid))
	end
	
end

--玩家停止控制
local function player_stop_ctrl(uid)
	-- LOG_WARNING("user[%s] stop ctrl", tostring(uid))
	-- PRINT_T(user_map[uid])
	send_userdata(uid, "player_stop_ctrl")
end

--控制金币发生变化
local function ctrl_gold_changed(uid, gold)
	send_userdata(uid, "ctrl_gold_changed", gold)
end

--查询在线玩家
--此接口只用于通知user服将在线玩家发送过来
local function query_online_user()
	skynet.sleep(100)
	send_usermanagers("query_online_user")
end

--协议逻辑初始化
local function init_proto()
	--数据赋值
	local api = {}
	api.send_msg = send_msg
	api.total_ctrl = total_ctrl
	api.send_to_all = send_to_all
	api.player_stop_ctrl = player_stop_ctrl
	api.player_start_ctrl = player_start_ctrl
	api.ctrl_gold_changed = ctrl_gold_changed
	
	--初始化
	proto.init(api,user_map,gm_list)
	skynet.fork(query_online_user)
end

--定时器(1s),在这里面加一个检测redis里面的内容，后台添加控制后，每秒读取一次
-- optional int32 ctrltype = 11; //控制类型(1:输,2：赢)
-- optional int32 ctrlrate = 12; //控制概率(1~100)
-- optional int32 ctrllevel = 13; //控制等级(1~12)
-- optional sint64 ctrlmaxgold = 14; //控制最大输赢
-- optional sint64 ctrlnowgold = 15; //控制当前输赢
-- optional string ctrlstarttime = 16; //控制开始时间
-- optional string ctrloverttime = 17; //控制结束时间
-- optional int32 ctrlcount = 18; //控制次数
-- optional int32 ctrlcaijin = 19; //控制彩金(1:不能中，2：可以中)
local function tick_tick()
	while true do
		if proto then
			proto.update()

			--读取redis里面的信息，如果有控制信息就调用proto里面的PlayerStartCtrl
			local ok, data = pcall(skynet.call, _redis, "lua", "execute", "hkeys", "ctrl_map") --找出所有的key
			if not ok then
				LOG_DEBUG("get ctrl keys error:"..data)
			elseif data and #data > 0 then
				for k,uid in pairs(data) do
					local res,data1 = pcall(skynet.call, _redis, "lua", "execute", "hget", "ctrl_map",uid) --通过key查找内容
					if not ok then
						LOG_DEBUG("get ctrl info error:"..data1..",uid="..uid)
					elseif data1 and data1 ~= "" then
						luadump(user_map,"user_map===")
						if user_map and user_map[tostring(uid)] then --在线
							local ctrlInfo = json.decode(data1)
							if ctrlInfo and ctrlInfo.ctrltype then
								if ctrlInfo.ctrltype == 1 or ctrlInfo.ctrltype == 2 then
									proto.PlayerStartCtrl(uid, ctrlInfo) --开始控制
								else
									proto.PlayerStopCtrl(uid, ctrlInfo) --停止控制
								end
							end
						else
							-- LOG_DEBUG("用户不在线无法进行控制==="..uid)
						end
						pcall(skynet.call, _redis, "lua", "execute", "hdel", "ctrl_map",uid) --用完后删除掉该key的内容
					end
				end
			end

		end
		skynet.sleep(100)
	end
end

------------------外部调用函数----------------
--GM上线
function CMD.gm_online(gm)
	LOG_DEBUG("gm_online")
	gm.level = 1
	gm_list[gm.uid] = gm
	-- {uid=xx, level=xx, agnode=xx, agaddr=xx}
end

--GM下线
function CMD.gm_offline(uid)
	LOG_DEBUG("gm_offline")
	gm_list[uid] = nil
end

--玩家上线
function CMD.user_online(p)
	LOG_DEBUG("user_online")
	--必要数据获取（测试，应该在传入的时候就有赋值）
	p.weekwin = 0			-- 最近一周输赢
	p.entergold = 0			-- 用户最后转入金币

	--调用proto
	proto.PlayerOnline(p)
end

--玩家下线
function CMD.user_offline(uid)
	--调用proto
	proto.PlayerOffline(uid)
end

--type 1开房模式 2金币 3比赛
--gameinfo={gameid=123,node="str",addr=22}
function CMD.user_joingame(uid, type, gameinfo)
	if not user_map[uid] then
		LOG_WARNING("user[%s] not online", tostring(uid))
		return
	end

	LOG_DEBUG("user_joingame uid[%d] type[%d] gameid[%d]", uid, type, gameinfo.gameid)

	--调用proto
	proto.PlayerEnterGame(uid,gameinfo,type)
end

function CMD.user_leavegame(uid)
	if not user_map[uid] then
		LOG_WARNING("user[%s] not online", tostring(uid))
		return
	end

	LOG_DEBUG("user_leavegame uid[%d]", uid)
	
	--调用proto
	proto.PlayerLeaveGame(uid)
end

--num>0 加 num<0 减 reason这里是gameid
function CMD.gold_change(uid, num, reason)
	if user_map[uid] then
		proto.PlayerGoldChange(uid, num, reason)
	else
		LOG_WARNING("player[%s] not in user_map when gold_change", tostring(uid))
	end
end

--银行
function CMD.set_bank(uid, value, reason)
	if user_map[uid] then
		proto.PlayerSetBank(uid, value, reason)
	else
		LOG_WARNING("player[%s] not in user_map when set_bank", tostring(uid))
	end
end

--红包变化
function CMD.hongbao_change(uid, cur, total)
	if user_map[uid] then
		proto.PlayerHongbaoChange(uid, cur, total)
	else
		LOG_WARNING("player[%s] not in user_map when hongbao_change", tostring(uid))
	end
end

--库存
function CMD.game_storage(info)
	-- PRINT_T(info)
end

--玩家断线重连
function CMD.user_resume(uid, type, gameid)
	CMD.user_joingame(uid, type, gameid)
end

--usermanager发来的在线玩家数据
function CMD.receive_player_list(list)
--	PRINT_T(list)
	proto.online_player_list(list)
end

function CMD.dispatch(uid, name, msg)
	LOG_DEBUG(name)
	local f = proto[name]
	if f and gm_list[uid] then
		return f(uid, msg)
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)

	_redis = skynet.uniqueservice("redispool")
	skynet.call(_redis, "lua", "start")
	--初始化proto
	init_proto()

	--定时器
	skynet.fork(tick_tick)
end)
