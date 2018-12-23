--定义变量
local ai_mgr = {}
local server_msg = {}

--api函数
local api_leave
local api_send_msg
local api_register_delay_fun

--配置数据
local game_id -- 游戏id
local game_type -- 游戏类型

--流程数据变量
local game_status -- 游戏状态
local bet_times_now = 0 -- 当前押注次数
local bet_times_total = 0 -- 总押注次数

--用户数据
local robot = {} -- 机器人数据
local total_bet -- 总押注
local banker_uid -- 庄家uid
local banker_gold -- 庄家金币
local banker_list -- 庄家列表

-- 筹码金币
local pos_num = {4, 3, 3, 3, 6} --位置个数
local bet_max_rate = {10, 1, 1, 1, 1} --押注最大比例

--筹码金币
local chip_gold = {
	{1000, 10000, 100000, 500000, 1000000, 5000000},
	{1000, 10000, 100000, 500000, 1000000, 5000000},
	{1000, 10000, 100000, 500000, 1000000, 5000000},
	{1000, 10000, 100000, 500000, 1000000, 5000000},
	{1000, 10000, 100000, 500000, 1000000, 5000000}
}

--游戏流程
local status_name = {
    {"waiting","bet","open","result"},
    {"waiting","bet","open","result"},
    {"waiting","send","bet","open","result"},
    {"waiting","bet","open","result"},
    {"waiting","bet","open","result"}
}

--进入房间
function server_msg.EnterTable(msg)

end

--快速加入
function server_msg.QuickJoinResonpse(msg)

end

--恢复房间
function server_msg.BRResume(msg)
	total_bet = 0
	robot.total_bet = 0
	robot.gold = msg.gold --用户金币
	for k,val in pairs(msg.infos) do
		--总押注赋值
		if val.bets then
			for i=1,#val.bets / 2 do
				total_bet = total_bet + val.bets[i * 2 - 1] * val.bets[i * 2]
			end
		end

		--用户押注赋值
		if val.selfbets then
			for i=1,#val.selfbets / 2 do
				robot.total_bet = robot.total_bet + val.selfbets[i * 2 - 1] * val.selfbets[i * 2]
			end
		end
	end

	--状态赋值
	game_status = msg.status --当前状态
	if status_name[game_type][msg.status] == "bet" then
		--数据赋值
		bet_times_now = 0
		bet_times_total = msg.time
	end
end

--用户押注
function server_msg.BRBetRep(msg)
	--数据赋值
	robot.total_bet = robot.total_bet + msg.betgold
end

--游戏开牌
function server_msg.ShowCard(msg)
end

--设置庄
function server_msg.SetMaster(msg)
	--数据赋值
	banker_uid = msg.uid
	if banker_list then
		for uid,p in pairs(banker_list) do
			if p.uid == banker_uid then
				banker_gold = p.gold
				break
			end
		end
	end
end

--游戏状态
function server_msg.BRStatusNtf(msg)
	--判断数据赋值
	if status_name[game_type][msg.status] == "waiting" then
		bet_total = 0
		robot.total_bet = 0

		--发送下庄
		if robot.isupbanker then
			if math.random() < 0.1 then
				api_send_msg("AskMaster",{time = 1, seatid = 1, opt = 0})
			end
		end
	elseif status_name[game_type][msg.status] == "bet" then
		--数据赋值
		bet_times_now = 0
		bet_times_total = msg.time
	end

	--判断是否上下庄
	if not robot.isupbanker then
		if math.random() < 0.2 and robot.gold >= 10000000 then
			--发送上庄
			api_send_msg("AskMaster", {time = 1, seatid = 1, opt = 1})
		end
	end
end

--游戏押注（每秒下发）
function server_msg.BRBetNtf(msg)
	--数据赋值
	bet_times_now = bet_times_now + 1

	--总押注赋值
	total_bet = 0
	robot.total_bet = 0
	for k,val in pairs(msg.infos) do
		--总押注赋值
		if val.bets then
			for i=1,#val.bets / 2 do
				total_bet = total_bet + val.bets[i * 2 - 1] * val.bets[i * 2]
			end
		end

		--用户押注赋值
		if val.selfbets then
			for i=1,#val.selfbets / 2 do
				robot.total_bet = robot.total_bet + val.selfbets[i * 2 - 1] * val.selfbets[i * 2]
			end
		end
	end
	
	--判断发送押注(最后一秒不押注)
	if bet_times_now < bet_times_total - 3 then
		if math.random() < 0.8  and banker_uid ~= robot.uid then
			local bet_num = math.floor(math.random() * 5) + 2
			for i=1,bet_num do
				local bet_gold
				local bet_gold_rate = math.random()
				local bet_pos = math.floor(math.random() * pos_num[game_type]) + 1
				if bet_gold_rate < 0.5 then
					bet_gold = chip_gold[game_type][1]
				elseif bet_gold_rate < 0.8 then
					bet_gold = chip_gold[game_type][2]
				elseif bet_gold_rate < 0.95 then
					bet_gold = chip_gold[game_type][3]
				elseif bet_gold_rate < 0.98 then
					bet_gold = chip_gold[game_type][4]
				else
					bet_gold = chip_gold[game_type][5]
				end
				
				--判断庄家金币不足
				if banker_gold and banker_gold >= bet_max_rate[game_type] * (total_bet + bet_gold) then
					--判断机器人金币不足
					if robot.gold >= bet_max_rate[game_type] * (robot.total_bet + bet_gold) then
						--发送押注消息
						api_send_msg("BRBetReq", {pos = bet_pos, gold = bet_gold})
					end
				end
			end
		end
	end
end

--游戏结算
function server_msg.BRResult(msg)
	robot.gold = msg.gold --用户金币
	banker_gold = msg.mgold -- 庄家金币
end

--离开房间
function server_msg.resLeaveTable(msg)

end

--显示庄家列表
function server_msg.BRMasterList(msg)
	--庄家列表赋值
	robot.isupbanker = false
	banker_list = msg.players
	for key,p in pairs(banker_list) do
		if p.uid == robot.uid then
			robot.isupbanker = true
			break
		end
	end
end

--显示玩家列表
function server_msg.BRUserList(msg)

end

--机器人初始化
function ai_mgr.init(api, uid, gameid)
	--api函数
	api_leave = api.leave
	api_send_msg = api.send_msg
	api_register_delay_fun = api.register_delay_fun

	--配置数据
	robot.uid = uid
	game_id = gameid
	game_type = game_id - 5001 -- 游戏类型
	game_type = game_type%100
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
	robot = nil
end

return ai_mgr