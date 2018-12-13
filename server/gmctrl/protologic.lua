--金权
--2018年2月5日
--控制器

--玩家基础数据
--[[
	uid				用户id
	gold			用户金币
	hongbao			用户红包
	nickname		用户昵称
	bank		用户银行金币
	entergold		用户最后转入金币（充值）
	weekwin			最近一周输赢
	totalhongbao	累计红包
]]

--玩家控制数据
--[[
	gameid			游戏Id
	roomid			房间Id
	ctrltype		控制类型(1:输,2：赢)
	ctrlrate		控制概率(1~100)
	ctrllevel		控制等级(1~12)
	ctrlmaxgold		控制最大输赢
	ctrlnowgold		控制当前输赢
	ctrlstarttime	控制开始时间
	ctrloverttime	控制结束时间
	ctrlcount		控制次数
	ctrlcaijin		控制彩金(1:不能中，2：可以中)
]]

local this = {}
local gameconf = require "game_conf"

--数据列表
local gm = {}
local players
local now_time
local game_list = {}
local players_cnt = 0

--控制时间
local ctrl_over_time = {}
local ctrl_start_time = {}

--------------------本地函数-------------------
local send_msg
local total_ctrl
local send_to_all
local player_stop_ctrl
local player_start_ctrl
local ctrl_gold_changed
local tremove = table.remove
local tinsert = table.insert

-----------------赋值函数------------------
--添加结束时间
local function add_over_time(p)
	if p.ctrloverttime then
		local over_time = p.ctrloverttime 
		if ctrl_over_time[over_time] then
			tinsert(ctrl_over_time[over_time],p.uid)
		else
			ctrl_over_time[over_time] = {}
			tinsert(ctrl_over_time[over_time],p.uid)
		end
	end
end

--删除结束时间
local function delete_over_time(p)
	if p.ctrloverttime then
		local over_time = p.ctrloverttime 
		if ctrl_over_time[over_time] then
			for k,v in pairs(ctrl_over_time[over_time]) do
				if v == p.uid then
					tremove(ctrl_over_time[over_time],k)
					break
				end
			end
		end
	end
end

--添加开始时间
local function add_start_time(p)
	if p.ctrlstarttime then
		local start_time = p.ctrlstarttime 
		if ctrl_start_time[start_time] then
			tinsert(ctrl_start_time[start_time],p.uid)
		else
			ctrl_start_time[start_time] = {}
			tinsert(ctrl_start_time[start_time],p.uid)
		end
	end
end

--删除开始时间
local function delete_start_time(p)
	if p.ctrlstarttime then
		local start_time = p.ctrlstarttime 
		if ctrl_start_time[start_time] then
			for k,v in pairs(ctrl_start_time[start_time]) do
				if v == p.uid then
					tremove(ctrl_start_time[start_time],k)
					break
				end
			end
		end
	end
end

-----------------发送消息------------------
--发送游戏列表
local function send_gamelist(uid)
	--发送游戏列表
	local rep_msg = {}
	local games = {}
	for k,v in pairs(game_list) do
		local game_info = {}
		game_info.gameid = v.gameid
		game_info.online = v.online
		game_info.gamename = v.gamename
		game_info.type = v.type

		--插入数据
		tinsert(games,game_info)
	end
	rep_msg.games = games

	--发送消息
	send_msg(uid, "gm.GameListRep", rep_msg)
end

--发送玩家列表
local function send_playerlist(uid)
	--数据赋值
	local msg = {}
	local msg_num = 5
	local player_list = {}

	--发送消息
	for p_uid,p in pairs(players) do
		--数据赋值
		local player = {}

		--基本数据
		player.uid = p.uid
		player.gold = p.gold
		player.hongbao = p.hongbao
		player.weekwin = p.weekwin
		player.nickname = p.nickname
		player.bankgold = p.bank
		player.entergold = p.entergold
		player.totalhongbao = p.totalhongbao

		--房间数据
		if p.gameid then
			player.gameid = p.gameid
			player.roomid = p.roomid
		end

		--控制数据
		if p.ctrltype then
			player.ctrltype = p.ctrltype
		    player.ctrlrate = p.ctrlrate
		    player.ctrllevel = p.ctrllevel
		    player.ctrlmaxgold = p.ctrlmaxgold
		    player.ctrlnowgold = p.ctrlnowgold
		    player.ctrlstarttime = p.ctrlstarttime
		    player.ctrloverttime = p.ctrlstarttime
		end

		--插入数据
		tinsert(player_list, player)

		--判断发送
		if #player_list == msg_num then
			--数据赋值
			msg.isover = 0
			msg.players = player_list

			--发送消息
			send_msg(uid, "gm.GameListRep", msg)

			--数据清空
			msg = {}
			player_list = {}
		end
	end

	--数据赋值
	msg.isover = 1
	msg.players = player_list

	--发送消息
	send_msg(uid, "gm.PlayerListRep", msg)
end

--发送在线人数改变
local function send_game_online(gameid)
	local msg = {}
	msg.gameid = gameid
	msg.online = game_list[gameid].online

	--发送给所有
	send_to_all(0, "gm.OnlineNtf", msg)
end

--发送玩家上线
local function send_player_online(p)
	--数据赋值
	local msg = {}

	--基本数据
	msg.uid = p.uid
	msg.gold = p.gold
	msg.hongbao = p.hongbao
	msg.weekwin = p.weekwin
	msg.nickname = p.nickname
	msg.bankgold = p.bank
	msg.entergold = p.entergold
	msg.totalhongbao = p.totalhongbao

	--房间数据
	if p.gameid then
		msg.gameid = p.gameid
		msg.roomid = p.roomid
	end

	--控制数据
	if p.ctrltype then
		msg.ctrltype = p.ctrltype
		msg.ctrlrate = p.ctrlrate
		msg.ctrllevel = p.ctrllevel
		msg.ctrlmaxgold = p.ctrlmaxgold
		msg.ctrlnowgold = p.ctrlnowgold
		msg.ctrlstarttime = p.ctrlstarttime
		msg.ctrloverttime = p.ctrlstarttime
	end
	
	--发送给所有
	send_to_all(0, "gm.PlayerOnLineNtf", msg)
end

--发送玩家下线
local function send_player_offline(uid)
	local msg = {}
	msg.uid = uid
	
	--发送给所有
	send_to_all(0, "gm.PlayerOffLineNtf", msg)
end

--发送玩家进入游戏
local function send_enter_game(uid, gameid, roomid)
	local msg = {}
	msg.uid = uid
	msg.gameid = gameid
	msg.roomid = roomid
	
	--发送给所有
	send_to_all(0, "gm.PlayerEnterGameNtf", msg)
end

--发送玩家离开游戏
local function send_leave_game(uid, gameid)
	local msg = {}
	msg.uid = uid
	msg.gameid = gameid
	
	--发送给所有
	send_to_all(0, "gm.PlayerLeaveGameNtf", msg)
end

--发送数据改变
local function send_data_change(uid)
	local msg = {}
	msg.uid = uid
	msg.gold = players[uid].gold
	msg.weekwin = players[uid].weekwin
	msg.hongbao = players[uid].hongbao
	msg.bankgold = players[uid].bank
	msg.entergold = players[uid].entergold
	msg.totalhongbao = players[uid].totalhongbao
	msg.ctrlnowgold = players[uid].ctrlnowgold
	
	--发送给所有
	send_to_all(0, "gm.PlayerGoldChangeNtf", msg)
end

-----------------收到协议------------------
--游戏列表请求
function this.GameListReq(uid, msg)
	LOG_DEBUG("GM uid[%d] login", uid)

	--发送游戏列表
	send_gamelist(uid)
end

--请求玩家列表
function this.PlayerListReq(uid, msg)
	--发送玩家列表
	send_playerlist(uid)
end

--控制玩家
function this.PlayerStartCtrl(uid, msg)
	--数据赋值
	players[msg.uid].ctrlnowgold = 0
	players[msg.uid].ctrltype = msg.ctrltype
	players[msg.uid].ctrlrate = msg.ctrlrate
	players[msg.uid].ctrllevel = msg.ctrllevel
	players[msg.uid].ctrlmaxgold = msg.ctrlmaxgold
	players[msg.uid].ctrlstarttime = tonumber(msg.ctrlstarttime)
	players[msg.uid].ctrloverttime = tonumber(msg.ctrloverttime)
	players[msg.uid].ctrlcaijin = msg.ctrlcaijin
	if msg.ctrlcount then
		players[msg.uid].ctrlcount = msg.ctrlcount
	end
	
	--发送给所有
	send_to_all(0, "gm.PlayerStartCtrl", msg)

	--判断是否开始
	if now_time >= players[msg.uid].ctrlstarttime then
		--通知外部开始控制
		player_start_ctrl(msg.uid)
	else
		add_start_time(players[msg.uid])
	end
	add_over_time(players[msg.uid])

	--打印日志
	LOG_DEBUG("GM uid[%d] startctrl [%d]---->type: %d"  , uid, msg.uid, msg.ctrltype)
end

--结束控制
function this.PlayerStopCtrl(uid, msg)
	--移除控制
	delete_over_time(players[msg.uid])
	delete_start_time(players[msg.uid])

	--数据赋值
	players[msg.uid].ctrltype = nil
	players[msg.uid].ctrlrate = nil
	players[msg.uid].ctrllevel = nil
	players[msg.uid].ctrlmaxgold = nil
	players[msg.uid].ctrlnowgold = nil
	players[msg.uid].ctrlstarttime = nil
	players[msg.uid].ctrloverttime = nil
	players[msg.uid].ctrlcount = nil
	players[msg.uid].ctrlcaijin = nil

	--发送给所有
	send_to_all(0, "gm.PlayerStopCtrl", msg)
	
	--通知外部停止控制
	player_stop_ctrl(msg.uid)

	--打印日志
	if uid then
		LOG_DEBUG("GM uid[%d] stopctrl [%d]", uid, msg.uid)
	else
		LOG_DEBUG("timeout stopctrl [%d]", msg.uid)
	end
end

-----------------游戏接口------------------
--玩家上线
function this.PlayerOnline(p)
	local is_stop = false
	local is_start = false

	--判断赋值
	if not players[p.uid] then
		if p.ctrlinfo and p.ctrlinfo.ctrltype then
			--定义变量
			local over_time = p.ctrlinfo.ctrloverttime 
			local start_time = p.ctrlinfo.ctrlstarttime 
			
			--判断是否结束
			if over_time < now_time then
				--数据赋值
				is_stop = true
				p.ctrlinfo = nil
			else
				p.ctrltype = p.ctrlinfo.ctrltype
				p.ctrlrate = p.ctrlinfo.ctrlrate
				p.ctrlcount = p.ctrlinfo.ctrlcount
				p.ctrllevel = p.ctrlinfo.ctrllevel
				p.ctrlmaxgold = p.ctrlinfo.ctrlmaxgold
				p.ctrlnowgold = p.ctrlinfo.ctrlnowgold or 0
				p.ctrlstarttime = p.ctrlinfo.ctrlstarttime
				p.ctrloverttime = p.ctrlinfo.ctrloverttime
				p.ctrlcaijin = p.ctrlinfo.ctrlcaijin
				p.ctrlinfo = nil

				--增加结束时间
				add_over_time(p)
			end

			--判断是否开始
			if start_time > now_time and p.ctrltype then
				add_start_time(p)
			elseif p.ctrltype then
				is_start = true
			end
			LOG_DEBUG("over_time="..over_time..",start_time="..start_time..",now_time="..now_time)
		end
		players[p.uid] = p
		players_cnt = players_cnt + 1
	end
	players[p.uid].online = true
	players[p.uid].agnode = p.agnode
	players[p.uid].dataddr = p.dataddr
	players[p.uid].datnode = p.datnode
	
	--通知外部开始控制
	if is_start then
		--通知外部控制
		LOG_DEBUG("通知外部控制")
		player_start_ctrl(p.uid)
	end

	--通知外部停止控制
	if is_stop then
		--通知外部停止控制
		LOG_DEBUG("通知外部停止控制")
		player_stop_ctrl(p.uid)
	end

	--发送协议
	send_player_online(p)
end

--玩家下线
function this.PlayerOffline(uid)
	--判断玩家
	if not players[uid] then
		LOG_WARNING("user[%s] not online", tostring(uid))
		return
	end
	
	--发送协议
	send_player_offline(uid)

	--判断赋值
	if not players[uid].ctrltype and not players[uid].gameid then
		players[uid] = nil
		players_cnt = players_cnt - 1
	else
		players[uid].online = false
	end
end

--房间赋值
local function ass_roomid(node, addr)
	local game_node_id
	local start_index, over_index = string.find(node, 'goldgame')
	if start_index then
		return string.sub(node, over_index + 1, string.len(node)).."-"..addr
	else
		start_index, over_index = string.find(node, 'game')
		if start_index then
			return string.sub(node, over_index + 1, string.len(node)).."-"..addr
		else
			return node..addr
		end
	end
end

--玩家进入游戏 -->gameinfo:{gameid=123,node="str",addr=22}
function this.PlayerEnterGame(uid,gameinfo,gametype)
	--判断数据
	if players[uid] then
		players[uid].gameid = gameinfo.gameid
		players[uid].roomid = ass_roomid(gameinfo.node, gameinfo.addr)
		game_list[gameinfo.gameid].online = game_list[gameinfo.gameid].online + 1
		
		--发送玩家上限
		send_enter_game(uid, players[uid].gameid, players[uid].roomid)

		--发送游戏在线人数
		send_game_online(gameinfo.gameid)
	end
end

--玩家离开游戏
function this.PlayerLeaveGame(uid)
	--清空数据
	if players[uid] and players[uid].gameid then
		--数据赋值
		local now_gameid = players[uid].gameid
		game_list[now_gameid].online = game_list[now_gameid].online - 1

		--发送玩家离开游戏
		send_leave_game(uid, now_gameid)

		--发送游戏在线人数
		send_game_online(now_gameid)

		--数据清空
		players[uid].gameid = nil
		players[uid].roomid = nil

		--判断离线玩家
		if not players[uid].online and not players[uid].ctrltype then
			players[uid] = nil
			players_cnt = players_cnt - 1
		end
	end
end

--玩家数据改变(num>0 加 num<0 减 reason这里是gameid)
function this.PlayerGoldChange(uid, num, reason)
	--数据赋值
	if players[uid] then
		--数据赋值
		players[uid].gold = players[uid].gold + num

		--判断赋值
		if reason > 1000 then
			if players[uid].ctrltype == 1 then
				players[uid].ctrlnowgold = players[uid].ctrlnowgold - num
			elseif players[uid].ctrltype == 2 then
				players[uid].ctrlnowgold = players[uid].ctrlnowgold + num
			end
		end

		--发送data服务
		ctrl_gold_changed(uid, players[uid].ctrlnowgold)
		
		--发送金币改变
		send_data_change(uid)
	end
end

--红包改变
function this.PlayerHongbaoChange(uid, cur, total)
	--数据赋值
	if players[uid] then
		--数据赋值
		players[uid].hongbao = cur
		players[uid].totalhongbao = total
		
		--发送金币改变
		send_data_change(uid)
	end
end

--设置银行金币
function this.PlayerSetBank(uid, value, reason)
	--数据赋值
	if players[uid] then
		players[uid].bank = value
	
		--发送金币改变
		send_data_change(uid)
	end
end

--初始化在线玩家
function this.online_player_list(list)
	--数据赋值
	for k,p in pairs(list) do
		local is_stop
		local is_start
		
		--判断是都结束
		if p.ctrlinfo and p.ctrlinfo.ctrltype then
			local over_time = p.ctrlinfo.ctrloverttime 
			local start_time = p.ctrlinfo.ctrlstarttime 
			
			--判断是否结束
			if over_time < now_time then
				--数据赋值
				is_stop = true
				p.ctrlinfo = nil
			else
				p.ctrltype = p.ctrlinfo.ctrltype
				p.ctrlrate = p.ctrlinfo.ctrlrate
				p.ctrlcount = p.ctrlinfo.ctrlcount
				p.ctrllevel = p.ctrlinfo.ctrllevel
				p.ctrlmaxgold = p.ctrlinfo.ctrlmaxgold
				p.ctrlnowgold = p.ctrlinfo.ctrlnowgold or 0
				p.ctrlstarttime = p.ctrlinfo.ctrlstarttime
				p.ctrloverttime = p.ctrlinfo.ctrloverttime
				p.ctrlcaijin = p.ctrlinfo.ctrlcaijin
				p.ctrlinfo = nil

				--增加结束时间
				add_over_time(p)
			end

			--判断是否开始
			if start_time > now_time and p.ctrltype then
				add_start_time(p)
			elseif p.ctrltype then
				is_start = true
			end
		end
		
		--房间信息赋值
		if p.gameid and p.gameddr then
			p.roomid = p.gameddr
		end

		--数据赋值
		if p.uid < 10000 or p.uid > 20000 then
			players[p.uid] = p
			players_cnt = players_cnt + 1

			--通知外部停止控制
			if is_stop then
				--通知外部停止控制
				player_stop_ctrl(p.uid)
			end

			--通知外部开始控制
			if is_start then
				--通知外部开始控制
				player_start_ctrl(p.uid)
			end
		end
	end
end

-----------------检测函数----------------
--检测到时间用户
local function check_over_ctrl()
	--当前时间赋值
	local time = os.time()

	--判断控制
	for i=now_time,time do
		--判断结束控制
		if ctrl_over_time[i] then
			for k,uid in pairs(ctrl_over_time[i]) do
				--结束控制
				this.PlayerStopCtrl(nil,{uid = uid})
			end
			ctrl_over_time[i] = nil
		end

		--判断开始控制
		if ctrl_start_time[i] then
			for k,uid in pairs(ctrl_start_time[i]) do
				--开始控制
				player_start_ctrl(uid)
			end
			ctrl_start_time[i] = nil
		end
	end

	--重新赋值
	now_time = time
end

-----------------外部调用-----------------
--1s调用
function this.update()
	if not now_time then
		return
	end

	--检测删除
	check_over_ctrl()

	--发送心跳包
	send_to_all(0, "gm.GMHart", {})
end

--初始化界面
function this.init(api,userlist,gmlist)
	--api函数赋值
	gm = gmlist
	players = userlist
	send_msg = api.send_msg
	total_ctrl = api.total_ctrl
	send_to_all = api.send_to_all
	player_stop_ctrl = api.player_stop_ctrl
	player_start_ctrl = api.player_start_ctrl
	ctrl_gold_changed = api.ctrl_gold_changed

	--游戏数据初始化
	for gameid,conf in pairs(gameconf) do
		game_list[gameid] = {}
		game_list[gameid].online = 0
		game_list[gameid].playerid = {}
		game_list[gameid].gameid = gameid
		game_list[gameid].type = conf.type
		game_list[gameid].gamename = conf.name
	end

	--当前时间赋值
	now_time = os.time()
end

return this