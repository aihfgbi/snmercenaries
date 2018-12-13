--定义变量
local ai_mgr = {}
local server_msg = {}

--api函数
local api_leave
local api_send_msg
local api_register_delay_fun

--配置数据
local game_id -- 游戏id

--流程数据变量
local game_status -- 游戏状态
local bet_score --押注分数

--用户数据
local robot_uid -- 机器人数据
local banker_uid -- 庄家uid
local players = {} -- 玩家列表

---------------------发送消息----------------------
--发送已准备
local function send_ready( ... )
	api_send_msg("GetReadyNtf", {
		uid = robot_uid, 
		seatid = players[robot_uid].seatid
	})
end

--发送叫庄
local function send_askbanker( ... )
	api_send_msg("GetMaster", {
		uid = robot_uid, 
		result = math.random(0,1)
	})
end

--发送叫分
local function send_askrate( ... )
	local score = {1, 2, 3, 5}
	api_send_msg("SetRate", {
		uid = robot_uid, 
		rate = score[math.random(1,4)]
	})
end

--发送开牌
local function send_opencard( ... )
	api_send_msg("ConfirmCards", {
		uid = robot_uid
	})
end

---------------------接收消息----------------------
--桌子初始化
function server_msg.TableInfo(msg)
	--数据赋值
	for k,p in pairs(msg.players) do
		players[p.uid] = p
	end
	bet_score = msg.score
end

--坐下位置
function server_msg.SitdownNtf(msg)
	--判断数据赋值
	players[msg.uid].seatid = msg.seatid
end

--已准备
function server_msg.GetReadyNtf(msg)
	--数据赋值
	players[msg.uid].ready = 1
end

--开始游戏
function server_msg.GameStart(msg)
end

--离开桌子
function server_msg.LeaveTableNtf(msg)
	--清除数据
	for uid,p in pairs(players) do
		if p.uid == msg.uid then
			players[p.uid] = nil
		end
	end
end

--叫庄（显示选择按钮）
function server_msg.AskMaster(msg)
	--延迟发送叫庄
	api_register_delay_fun(math.random(1,3),send_askbanker)
end

--设置庄
function server_msg.SetMaster(msg)
	--数据赋值
	banker_uid = msg.uid
end

--叫庄
function server_msg.GetMaster(msg)
end

--开始叫分
function server_msg.AskRate(msg)
	--延迟发送叫分
	if banker_uid ~= robot_uid then
		api_register_delay_fun(math.random(1,3),send_askrate)
	end
end

--设置分
function server_msg.SetRate(msg)
end

--增加牌
function server_msg.AddCard(msg)
end

--显示牌
function server_msg.ShowCard(msg)
end

--游戏结算
function server_msg.GameResult(msg)
end

--游戏总结算
function server_msg.GameEnd(msg)
end

--用户上线
function server_msg.UserOnline(msg)
end

--用户离线
function server_msg.UserOffline(msg)
end

--已开牌
function server_msg.ConfirmCards(msg)
end

--每小局开始
function server_msg.StartRound(msg)
end

--接收其他人进入
function server_msg.EnterTable(msg)
	--数据赋值
	players[msg.uid] = msg
end

--解散房间
function server_msg.PushDissolveTable(msg)
end

--开牌阶段（显示两个按钮）
function server_msg.AskConfirmCards(msg)
	--延迟发送开牌
	api_register_delay_fun(math.random(1,3),send_opencard)
end

--恢复界面
function server_msg.NiuNiuResume(msg)
	--延迟发送准备
	api_register_delay_fun(math.random(1,3),send_ready)
end

--游戏消息
function server_msg.ChatNtf(msg)
end

--机器人初始化
function ai_mgr.init(api, uid, gameid)
	--api函数
	api_leave = api.leave
	api_send_msg = api.send_msg
	api_register_delay_fun = api.register_delay_fun

	--配置数据
	robot_uid = uid
	game_id = gameid
end

--机器人收到消息
function ai_mgr.dispatch(name, msg)
	--函数
	local fun = server_msg[name]
	if fun then
		fun(msg)
	else
		LOG_DEBUG("no matching function deal server msg[%s] !!!!!!!!!!!", tostring(name))
	end
end

--清除机器人
function ai_mgr.free()
	--清空机器人数据
	players = nil
end

return ai_mgr