--金权
--2018年01月22日
--阿拉斗牛

--游戏说明
--[[
	游戏种类：
	【1】抢庄
	【2】轮庄
	【3】固定庄
	【4】金币场（抢庄）
]]
local deal = require "douniu_deal"
local ctrl = require "br_gamectrl"
local this = {}

--用户数据
local seats --位置
local players --用户列表
local master_uid --庄uid
local owner_uid --房主uid
local histroy --历史记录
local basic_score --基础分
local min_play_gold --最小分数 
local is_goldmode --是否是金币模式
local is_tastemode --是否体验模式
local KICK_TIMEOUT = 20 -- 超时时间（金币模式）
local open_times --开牌次数(大于10次不做控制)

--解散数据
local dissolve_type --解散类型(1:发起解散,2:更新解散,3:解散成功,4:解散失败)
local agree_players = {}             --已同意玩家
local disagree_players = {}          --已拒绝玩家
local dissolve_timeout               --解散超时 
local dissolve_cdtime                --解散冷却时间
local DISSOLVE_TIME = 60             --解散超时
local DISSOLVE_CD = 5                --解散冷却时间                       

--游戏配置数据
local code
local game_id --游戏id
local game_type --游戏类型
local game_config --游戏配置
local pay_type --付费类型

--游戏数据
local cards -- 牌
local next_time --next时间
local has_start --是否开始
local has_goldstart --是否开始
local game_status --游戏状态
local status_name --状态名称
local status_time --状态时间
local bet_score --押注分数
local now_round --当前轮数
local total_round --总轮数
local end_time --结束时间
local is_add_jqr -- 是否加了机器人
local user_totalbet
local user_totalwin

--所有牌
local total_cards = {
	101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113,	  --方
	201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213,	  --梅
	301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313,	  --红
	401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413       --黑
}

--牌型倍率
local cardtype_rate = {
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 16, 18, 20, 25
}

--[[status_name
	【start】准备开始(金币场等待玩家准备)
	【send】发牌（发送前4张）
	【getmaster】抢庄
	【bet】闲家加倍
	【sendlast】发牌（发送最后1张）
	【open】开牌
	【result】结算
]]

--------------------本地函数-----------------------

local otime = os.time
local tinsert = table.insert
local tremove = table.remove
local tindexof = table.indexof
local mrandom = math.random
local api_report_gold
local api_join_robot
local api_free_table
local api_game_start
local api_game_end
local send_to_all
local api_kick

--------------------数据赋值-----------------------
--table赋值
local function ass_table(tb)
	local now_tb = {}
	for k,v in pairs(tb) do
		now_tb[k] = v
	end
	return now_tb
end

-- 洗牌
local function ass_shuffle()
    cards = {}
    local index
    local tmp = {}
    for i=1,#total_cards do
    	tmp[i] = i
    end
    for i = #total_cards, 1, -1 do
        index = tremove(tmp, mrandom(i))
        tinsert(cards, total_cards[index])
    end
end

-- 部分牌重洗
local function ass_shuffle_part()
    local index
    local now_cards = {}
    local tmp = {}
    for i=1,#cards do
    	tmp[i] = i
    end
    for i = #cards, 1, -1 do
        index = tremove(tmp, mrandom(i))
        tinsert(now_cards, cards[index])
    end
    return now_cards
end

-- 历史记录初始化
local function ass_history_info()
	histroy = {}
	histroy.code = code
	histroy.time = otime()
	histroy.owner = owner_uid
	histroy.times = total_round
	histroy.gameid = game_id
end

-- 历史记录结束
local function ass_history_end()
	--历史记录数据赋值
	local infos = {}
	histroy.endtime = otime()
	histroy.players = histroy.players or {}
	for uid,p in pairs(players) do
		if p.ready == 1 and p.seatid > 0 then
			local info = {
				tongsha = p.tongsha or 0,
				tongpei = p.tongpei or 0, 
				niuniu = p.niuniu or 0,
			 	wuniu = p.wuniu or 0, 
			 	shengli = p.shengli or 0,
			 	score = p.score or 0,
			 	uid = p.uid,
			 	nickname = p.nickname
			}
			tinsert(histroy.players, info)
			tinsert(infos, info)
		end
	end
end

-- 金币改变
local function ass_goldchange(p,gold)
	-- local ok = true, result
	local ok = true
	if is_tastemode then
		p.gold = p.gold + gold
		if p.gold < 0 then
			ok = false
		end
		return ok
	end
	if gold > 0 then
		--增加金币
		p:call_userdata("add_gold", gold, game_id)
	elseif gold < 0 then
		-- --减少金币
		if gold + p.gold >= 0 then
			p:call_userdata("sub_gold", -gold, game_id)
		else
			ok = false
		end
	end

	--判断处理
	if ok then
		--数据赋值
		if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 1 then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold - gold
		elseif p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 2 then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + gold
		end
		p.gold = p.gold + gold
	end

	return ok
end

--结算赋值
local function ass_result()
	--数据赋值
	user_totalbet = 0
	user_totalwin = 0
	local is_pass = true
	local is_tongsha = true
	local is_tongpei = true
	local m_player = players[master_uid]
	m_player.wingold = 0
	m_player.cardtype = deal.getType(m_player.cards)
	for uid,p in pairs(players) do
		if uid ~= m_player.uid and p.ready == 1 then
			p.wingold = 0
			p.cardtype = deal.getType(p.cards)
			if deal.compare(p.cards,m_player.cards) == 1 then
				p.wingold = p.rate * cardtype_rate[math.max(1,p.cardtype)] * basic_score
				is_tongsha = false
			else
				p.wingold = -p.rate * cardtype_rate[math.max(1,m_player.cardtype)] * basic_score
				is_tongpei = false
			end
			m_player.wingold = m_player.wingold - p.wingold
			if is_goldmode then
				if p.gold + p.wingold < 0 then
					is_pass = false
					break
				end
			end

			--系统赢钱赋值
			if is_goldmode and not p.isrobot then
				if p.wingold > 0 then
					user_totalwin = user_totalwin + p.wingold
				else
					user_totalbet = user_totalbet - p.wingold
				end
			end
		end
	end
	if is_goldmode then
		if m_player.gold + m_player.wingold < 0 then
			is_pass = false
		else
			--数据赋值
			if not m_player.isrobot then
				if m_player.wingold > 0 then
					user_totalwin = user_totalwin + m_player.wingold
				else
					user_totalbet = user_totalbet - m_player.wingold
				end
				players[m_player.uid].wingold = m_player.wingold
				players[m_player.uid].totalbet = 0
			end

			--判断是否开牌
			if not ctrl.check_open(open_times, user_totalbet, user_totalwin) then
				is_pass = false
			end

			--次数赋值
			open_times = open_times + 1
		end
	end

	--判断赋值
	if is_pass then
		--玩家赋值
		for uid,p in pairs(players) do
			if uid ~= m_player.uid and p.ready == 1 then
				if is_goldmode then
					ass_goldchange(p, p.wingold)
				else
					p.score = p.score + p.wingold
				end
				if p.wingold > 0 then
					p.shengli = p.shengli + 1
				end
				if p.cardtype == 10 then
					p.niuniu = p.niuniu + 1
				end
				if p.cardtype == 0 then
					p.wuniu = p.wuniu + 1
				end
			end
		end

		--庄家赋值
		if is_goldmode then
			ass_goldchange(m_player,m_player.wingold)
		else
			m_player.score = m_player.score + m_player.wingold
		end
		if m_player.wingold > 0 then
			m_player.shengli = m_player.shengli + 1
		end
		if m_player.cardtype == 10 then
			m_player.niuniu = m_player.niuniu + 1
		end
		if m_player.cardtype == 0 then
			m_player.wuniu = m_player.wuniu + 1
		end
		if is_tongsha then
			m_player.tongsha = m_player.tongsha + 1
		end
		if is_tongpei then
			m_player.tongpei = m_player.tongpei + 1
		end
	end
	return is_pass
end

--增加牌
local function ass_addcard(num)
	local old_cards = ass_table(cards)
	for uid,p in pairs(players) do
		if p and p.ready == 1 and p.seatid > 0 then
			for i=1,num do
				if num == 1 then
					p.cards[5] = tremove(cards,1)
				else
					tinsert(p.cards, tremove(cards,1))
				end
			end
		end
	end

	--结算赋值
	if num == 1 and not ass_result() then
		--重新发牌
		cards = ass_table(old_cards)

		--部分洗牌
		cards = ass_shuffle_part()
		
		--重新增加牌
		ass_addcard(num)
	end
end

--随机庄赋值
local function ass_randommaster()
	local total = {}
	local asked = {}
	for uid,p in pairs(players) do
		if p.ask_master and p.ask_master == 1 then
			tinsert(asked, uid)
		end
		if p.seatid > 0 and p.ready > 0 then
			tinsert(total, uid)
		end
	end
	if #asked > 0 then
		return asked[math.random(#asked)]
	else
		return total[math.random(#total)]
	end
end

--轮庄赋值
local function ass_lunmaster(now_uid)
	local now_index
	local total = {}
	for id,p in pairs(seats) do
		if p then
			tinsert(total, p.uid)
			if now_uid == p.uid then
				now_index = #total
			end
		end
	end
	
	--判断返回
	if now_index then
		now_index = now_index + 1
		if now_index > #total then
			now_index = 1
		end
		return total[now_index]
	else
		return total[1]
	end
end

--设置庄
local function ass_setmaster()
	if not master_uid then
		if game_type == 1 or game_type == 4 then
			master_uid = ass_randommaster()
		elseif game_type == 2 then
			if owner_uid then
				master_uid = owner_uid
			else
				master_uid = ass_lunmaster(master_uid)
			end
		elseif game_type == 3 then
			master_uid = owner_uid
		end
	else
		if game_type == 2 then
			master_uid = ass_lunmaster(master_uid)
		end
	end
end

-- 坐下玩家个数赋值
local function ass_seatplayer_num()
	local sum = 0
	for uid,p in pairs(players) do
		if p.seatid > 0 then
			sum = sum + 1
		end
	end
	return sum
end

-- 机器人个数
local function ass_robot_num()
	local sum = 0
	for uid,p in pairs(players) do
		if p.isrobot then
			sum = sum + 1
		end
	end
	return sum
end

--玩家准备个数
local function ass_readyplayer_num()
	local sum = 0
	for uid,p in pairs(players) do
		if not p.isrobot and p.ready == 1 then
			sum = sum + 1
		end
	end
	return sum
end

--------------------发送消息-----------------------
--发送恢复游戏
local function send_resume(p)
	local msg = {}
	local info = {}
	for uid, v in pairs(players) do
		local card_num = 0
		if v.cards then 
			card_num = #v.cards
		end
		if p.uid == uid or status_name[game_status] == "open" or status_name[game_status] == "result" then
			tinsert(
				info,
				{
					uid = uid,
					cards = v.cards or {},
					count = card_num
				}
			)
		else
			tinsert(
				info,
				{
					uid = uid,
					cards = {},
					count = card_num
				}
			)
		end
	end
	msg.info = info
	msg.status = game_status
	if next_time and next_time - otime() > 0 then
		msg.time = next_time - otime()
	else
		msg.time = 0 
	end
	if master_uid then
		msg.masteruid = master_uid
	end
	
	p:send_msg("game.NiuNiuResume", msg)
end

--发送坐下
local function send_sit_down(p)
	local msg = {}
	msg.uid = p.uid
	msg.seatid = p.seatid
	msg.nickname = p.nickname
	msg.headimg = p.headimg or ""
	
	send_to_all("game.SitdownNtf", msg)
end

--发送准备
local function send_ready(p)
	local msg = {}
	msg.uid = p.uid
	msg.seatid = p.seatid

	send_to_all("game.GetReadyNtf", msg)
end

--发送开始（每小局）
local function send_startround()
	local msg = {}
	msg.round = now_round
	msg.total = total_round

	send_to_all("game.StartRound", msg)
end

--发送增加牌
local function send_addcard(num)
	for uid,p in pairs(players) do
		for u,v in pairs(players) do
			if v and v.ready == 1 and v.seatid > 0 then
				if uid == u then
					p:send_msg("game.AddCard", {uid = u, count = num, seatid = v.seatid, cards = v.cards})
				else
					p:send_msg("game.AddCard", {uid = u, count = num, seatid = v.seatid})
				end
			end
		end
	end
end

--发送叫庄
local function send_askmaster()
	local msg = {}
	msg.time = status_time[game_status]

	send_to_all("game.AskMaster", msg)
end

--发送设置庄
local function send_setmaster()
	local msg = {}
	msg.uid = master_uid

	send_to_all("game.SetMaster", msg)
end

--发送开始叫分
local function send_askrate()
	local msg = {}
	msg.master = master_uid
	msg.time = status_time[game_status]
	
	send_to_all("game.AskRate", msg)
end

--发送设置倍率
local function send_setrate()
	for uid,p in pairs(players) do
		if not p.rate and p.seatid > 0 and p.ready == 1 then
			p.rate = 1
			send_to_all("game.SetRate", {rate = p.rate, uid = p.uid})
		end
	end
end

--发送结算
local function send_result()
	local msg = {}
	local info = {}
	local player_num = 0
	local result_cards = {}
	for uid,p in pairs(players) do
		if p.seatid > 0 and p.ready == 1 then
			--结果赋值
			tinsert(info, p.uid)
			tinsert(info, p.wingold)
			if is_goldmode then
				tinsert(info, p.gold)
			else
				tinsert(info, p.score)
			end
			
			--牌赋值
			for i,cardid in ipairs(p.cards) do
				tinsert(result_cards, cardid)
			end

			--个数赋值
			player_num = player_num + 1
		end
	end
	msg.infos = info
	msg.master = master_uid
	msg.count = player_num
	msg.cards = result_cards

	--发送消息
	send_to_all("game.GameResult", msg)

	--历史记录复制
	histroy.recording = histroy.recording or {}
	tinsert(histroy.recording, { 
		master = master_uid, 
		count = player_num, 
		round = now_round, 
		infos = info, 
		cards = result_cards
	})
end

-- 发送总结算
local function send_end()
	local msg = {}
	local infos = {}
	for uid,p in pairs(players) do
		if p.ready == 1 and p.seatid and p.seatid > 0 then
			local info = {
				tongsha = p.tongsha,
				tongpei = p.tongpei,
				niuniu = p.niuniu,
				wuniu = p.wuniu,
				shengli = p.shengli,
				score = p.score,
				uid = p.uid,
				nickname = p.nickname
			}
			tinsert(infos, info)
		end
	end
	msg.infos = infos
	msg.round = total_round

	--发送消息
	send_to_all("game.GameEnd", msg)
end

--发送解散房间
local function send_dissolvetable(p, opt)
	local is_start_ds

	--判断显示
	if dissolve_cdtime then
		return
	end

	--判断显示
    if p.seatid > 0 and p.ready == 1 then
    	--定义变量
    	local msg = {}

    	--判断赋值
    	if not dissolve_timeout then
    		is_start_ds = true
    		dissolve_type = 1
    		agree_players = {}
			disagree_players = {}
			msg.remaintime = DISSOLVE_TIME
    		dissolve_timeout = otime() + DISSOLVE_TIME
    	else
    		dissolve_type = 2
    	end
    	msg.result = dissolve_type

    	--数据赋值
    	if opt == 1 then
    		tinsert(agree_players, p.uid)
    	else
    		tinsert(disagree_players, p.uid)

    		--缩短倒计时
    		dissolve_timeout = math.min(otime() + 3, dissolve_timeout)
    	end
    	
    	--判断赋值
    	if is_start_ds then
    		--默认离线玩家同意解散
    		for uid,player in pairs(players) do
    			if player.online == 0 then
    				tinsert(agree_players, player.uid)
    			end
    		end
    	end

    	msg.consentUid = agree_players
        msg.refuseUid = disagree_players
    	
    	--发送消息
    	send_to_all("game.PushDissolveTable",msg)
    end
end
--------------------机器人-------------------------
--增加机器人
local function add_jqr()
	if not is_add_jqr  and game_config.add_robot then
		local gold_rate = {10, 30, 50, 70, 100, 300, 600}
		local rate_num = math.random(6)
		local jqr_gold = min_play_gold * math.random(gold_rate[rate_num],gold_rate[rate_num + 1])
		jqr_gold = jqr_gold + math.random(math.floor(min_play_gold/100)) * 100
		is_add_jqr = true
		
		--增加机器人
		pcall(api_join_robot,"douniu",jqr_gold)
	end
end

-- 检测清除机器人
local function check_kick_jqr(p)
	local is_over = true
	for uid,player in pairs(players) do
		if uid ~= p.uid then
			if not p.isrobot then
				is_over = false;
			end
		end
	end

	--判断清除机器人
	if is_over then
		for uid,p in pairs(players) do
			if p.isrobot then
				api_kick(p, 1008)
			end
		end
	end
end

--------------------流程控制-----------------------
--游戏开始
local function game_info()
	if has_start then
		return
	end

	--数据赋值
	now_round = 1
	game_status = 0
	has_start = true
	next_time = otime()

	--固定庄模式重新赋值庄
	if game_type == 3 then
		if players[owner_uid] and players[owner_uid].ready == 0 then
			owner_uid = ass_randommaster()
		end
	end
end

--游戏结束
local function game_stop(reason)
	if game_status > 0 then
		--结束历史记录赋值
		ass_history_end()

		--增加战绩数据
		local fret = {}
		local players_name = {}
		local players_score = {}
		local players_score1 = {}
		for uid,p in pairs(players) do
			if p.ready == 1 then
				tinsert(players_name,p.nickname)
				tinsert(players_score,p.score)
				tinsert(players_score1,0)
			end
		end
		fret.total = math.min(total_round,now_round)
		fret.players = players_name
		fret.score = players_score

		--数据赋值
		if now_round <= total_round then
			local rst = {}
			rst.score = players_score1
			rst.players = players_name
			rst.index = now_round
			
			--调用结束api
			api_game_end(rst)
		end
		
		--结束函数
		send_end() -- 发送总结算
		api_free_table(fret, reason) --结束游戏

		--发送历史记录
		send_to_all("game.NiuNiuHistroy", {list = histroy.recording})
	else
		--结束历史记录赋值
		ass_history_end()
		api_free_table(nil, reason) --解散房间
	end
	
	--数据清空
	has_start = false
	for uid,p in pairs(players) do
		p.ready = 0
	end
end

--检查游戏开始
local function check_start()
	if has_start then
		return
	end
	local seat_num = 0
	local ready_num = 0
	for uid,p in pairs(players) do
		if p.seatid and p.seatid > 0 then
			if p.ready == 1 then
				ready_num = ready_num + 1
			end
			seat_num = seat_num + 1
		end
	end
	if ready_num >= 2 and ready_num == seat_num then
		game_info()
	end
end

--金币检查开始
local function check_goldstart()
	local jqr_num
	if not is_goldmode then
		return
	end
	if not has_start then
		local player_num = 0
		for uid,p in pairs(players) do
			player_num = player_num + 1
		end
		if player_num > 1 then
			game_info()
		else
			jqr_num = 1
		end
	else
		if not has_goldstart and not next_time then
			local ready_num = 0
			local ready_robot_num = 0
			for uid,p in pairs(players) do
				if p.ready == 1 then
					ready_num = ready_num + 1
					if p.isrobot then
						ready_robot_num = ready_robot_num + 1
					end
				end
			end
			if ready_num > 1 then
				next_time = otime()
			else
				if ready_num - ready_robot_num > 0 then
					-- 增加机器人
					jqr_num = 1
				end
			end
		end
	end

	-- 增加机器人
	if jqr_num then
		add_jqr()
	end	
end

--检测踢人
local function check_kick_players()
    local now_time = otime()
    for uid, p in pairs(players) do
        if p.ready == 0 and p.kick_timeout and now_time > p.kick_timeout then
            seats[p.seatid] = nil
		    p.seatid = nil
		    api_kick(p, 1005)
        end
    end
end

--检测释放房间
local function check_free_table()
	local now_player_num = 0
	for uid, p in pairs(players) do
		if not p.isrobot then
			now_player_num = now_player_num + 1
		end
	end

	--判断
	if now_player_num == 0 then
		--清除所有机器人
		for uid, p in pairs(players) do
			 api_kick(p, 1005)
		end

		--释放房间
		api_free_table()
	end
end

--解散房间
local function check_dissolve_table()
	if dissolve_timeout then
	 	--定义变量
    	local msg = {}

	 	--判断数据赋值
	 	dissolve_type = nil
	 	local player_num = 0
	 	for uid,p in pairs(players) do
	 		if p.ready == 1 then
	 			player_num = player_num + 1
	 		end
	 	end
	 	if #agree_players >= player_num then
	 		dissolve_type = 3
	 	else
	 		if otime() >= dissolve_timeout or  #disagree_players + #agree_players >= player_num then
	 			dissolve_type = 4
	 		end
	 	end

	 	--判断发送消息
	 	if dissolve_type then
	 		msg.result = dissolve_type
	 		send_to_all("game.PushDissolveTable",msg)

	 		--数据清空
	 		dissolve_timeout = nil

	 		--判断显示
	 		if dissolve_type == 3 then
	 			game_stop(1002) -- 游戏结束
	 		else
	 			--开始冷却
	 			dissolve_cdtime = otime() + DISSOLVE_CD
	 		end
	 	end
    end

    --冷却赋值
    if dissolve_cdtime then
    	if otime() > dissolve_cdtime then
    		dissolve_cdtime = nil
    	end
    end
end

--准备开始
local function game_start()
	local msg = {}
	is_add_jqr = nil
	msg.endtime = status_time[game_status]
	local now_player_num = 0
	for uid,p in pairs(players) do
		--清空数据
		p.rate = nil
		p.cards = {}
		p.confirm = nil
		p.ask_master = nil

		--可以做一个离线踢人处理(金币场)
		if p.online == 0 and is_goldmode then
			p.ready = 0
			seats[p.seatid] = nil
		    p.seatid = nil
			api_kick(p,1003)
		end

		--判断在线人数
		if p.ready == 1 then
			now_player_num = now_player_num + 1
		else
			if p.nextready and p.nextready == 1 then
				p.ready = 1
			end
		end
	end

	--判断添加机器人
	if is_goldmode then
		local robot_num = ass_robot_num()
		local player_seat_num = ass_seatplayer_num()
		if robot_num < 1 and player_seat_num < 5 then
			--增加机器人
			add_jqr()
		else
			if robot_num == player_seat_num then
				--删除所有机器人
				for uid,p in pairs(players) do
					seats[p.seatid] = nil
		    		p.seatid = nil
					api_kick(p,1008)
				end
			else
				local readyplayer_num = ass_readyplayer_num()
				if readyplayer_num > 0 and robot_num == 1 and player_seat_num < 4 then
					if math.random() < 0.5 then
						--增加机器人
						add_jqr()
					end
				end
			end
		end
	end
	
	--发送游戏开始
	send_to_all("game.GameStart", msg)
end

--发牌（发送前4张）
local function game_send()
	--判断返回
	if is_goldmode then
		local now_readynum = 0
		for uid,p in pairs(players) do
			if p.ready == 1 then
				now_readynum = now_readynum + 1
			end
		end
		
		--判断返回
		if now_readynum < 2 then
			return 0
		end
	end

	--数据清空
	if game_type ~= 2 then
		master_uid = nil
	end
	for uid,p in pairs(players) do
		p.rate = nil
		p.cards = {}
		p.confirm = nil
		p.ask_master = nil

		--判断是否有新加入
		if not is_goldmode then
			if p.seatid > 0 and p.ready == 0 then
				p.ready = 1
			end
		end
	end
	has_goldstart = true

	--调用开始api
	api_game_start()

	--洗牌
	ass_shuffle()

	--发送开始（每小局）
	send_startround()

	--增加牌赋值
	ass_addcard(4)

	--发送前四张牌
	send_addcard(4)

	--返回成功
	return 1
end

--抢庄
local function game_getmaster()
	--发送抢庄
	send_askmaster()
end

--闲家加倍
local function game_bet()
	--设置庄
	ass_setmaster()

	--发送设置庄
	send_setmaster()

	--发送开始叫分
	send_askrate()
end

--发牌（发送最后1张）
local function game_sendlast()
	--发送设置倍率
	send_setrate()
	
	--数据赋值i
	if is_goldmode then
		open_times = 0
	end

	--增加牌赋值
	ass_addcard(1)

	--发送前四张牌
	send_addcard(1)

	--上报总
	if is_goldmode and not is_tastemode then
		--LOG_DEBUG("上报数据:cost="..user_totalbet..",earn="..user_totalwin)
		api_report_gold(user_totalbet, user_totalwin)
	end

	--询问牌型选择
	send_to_all("game.AskConfirmCards", {time = status_time[game_status]})
end

--开牌
local function game_open()
	--发送开牌
	for uid,p in pairs(players) do
		if p.seatid and p.seatid > 0 and p.ready == 1 then
			p.add_score = 0
			send_to_all("game.ShowCard", {uid = p.uid, seatid = p.seatid, cards = p.cards})
		end
	end
end

--结算
local function game_result()
	--发送结算
	send_result()

	--判断删除机器人
	if is_goldmode then
		for uid,p in pairs(players) do
			if p.isrobot then
				p.nowtimes = p.nowtimes + 1
				if p.nowtimes >= p.playtimes then
					seats[p.seatid] = nil
		   			p.seatid = nil
					api_kick(p,1008)
				end
			else
				if p.wingold and p.wingold > 0 and not is_tastemode then
					p:call_userdata("add_win", game_id, 1001);
				end
			end
		end

		--调用结束api
		api_game_end()
	else
		--增加战绩数据
		local rst = {}
		local players_name = {}
		local players_score = {}
		for uid,p in pairs(players) do
			if p.ready == 1 then
				tinsert(players_name,p.nickname)
				tinsert(players_score,p.wingold)
			end
		end
		rst.score = players_score
		rst.players = players_name
		rst.index = now_round
		
		--调用结束api
		api_game_end(rst)

		--调用开始api
		if now_round <= total_round then
			api_game_start()
		end
	end
end

--------------------系统调用---------------------
--金币变化
function this.add_gold(p, gold, reason)
	p.gold = p.gold + gold
    if p.gold < 0 then
        p.gold = 0
    end
    send_to_all("game.UpdateGoldInGame", { uid = p.uid, goldadd = gold, gold = p.gold })
end

--坐下
function this.sitdown(p, seatid)
	if is_goldmode then
		LOG_WARNING("gold module can not sitdown")
		return
	end
    local seatid = tonumber(seatid)
    if seatid and not seats[seatid] and seatid > 0 and seatid <= game_config.max_player then
		if p.seatid and p.seatid > 0 and has_start then
			--已坐下，且已开局
			LOG_DEBUG("已坐下，且已开局不能换座位："..p.uid)
			return
		end
		if p.seatid > 0  then
			seats[p.seatid] = nil
		end
    	p.ready = 0
    	p.seatid = seatid
		seats[seatid] = p
    	if not owner_uid then
	        owner_uid = p.uid
	    end
    	return true
    end
end

--起立
function this.standup(p, seatid)
    if seatid and seats[seatid] and seatid > 0 and seatid <= game_config.max_player then
    	p.ready = 0
    	p.seatid = 0
		seats[seatid] = nil
    	return true
    end
end

--游戏解散
function this.dissolve_table()
	if game_status == 0 then
		api_free_table(nil, 1001)
	else
		game_stop(1001)
	end 
end

--关闭房间
function this.free()
	--清空桌位
	for seatid,v in pairs(seats) do
		seats[seatid] = nil
	end
end

--数据更新100毫秒
function this.update()
    --金币场检测（踢人）
	if is_goldmode then
		--检测踢人
		check_kick_players()

		--检测开始游戏
		check_goldstart()

		--检测释放房间 
		check_free_table()
	end

	--时间到了（解散）
	if not is_goldmode and not has_start and end_time then
		if otime() >= end_time then
			api_free_table(nil, 1001)
			return
		end
	end

	--检测解散房间
	if game_status ~= 0 then
		check_dissolve_table()
	end

	--判断结束
	if not has_start or not next_time then
		return
	end

	--游戏状态
	if otime() >= next_time then
		--数据赋值
		next_time = nil
		game_status = game_status + 1
		if not is_goldmode then
			if game_status > #status_name then
				game_status = 2
				now_round = now_round + 1
			end

			--判断结束
			if now_round > total_round then
				game_stop(1002) --游戏结束
				return
			end
		else
			if game_status > #status_name then
				game_status = 1
				has_goldstart = false

				--判断玩家金币不足处理
				for uid,p in pairs(players) do
					if p.gold < min_play_gold then
						p.ready = 0
						p.nextready = nil
		            	p.kick_timeout = otime() + KICK_TIMEOUT

		            	--发送消息
		            	send_to_all("game.GetReadyNtf", {uid = p.uid, seatid = 0})
					end
				end
			end
		end

		--是否继续
		local is_next = 1
		
		--判断显示
		if status_name[game_status] == "start" then
			game_start() --准备开始
		elseif status_name[game_status] == "send" then
			is_next = game_send() --发牌（发送前4张）
		elseif status_name[game_status] == "getmaster" then
			game_getmaster() --抢庄
		elseif status_name[game_status] == "bet" then
			game_bet() --闲家加倍
		elseif status_name[game_status] == "sendlast" then
			game_sendlast() --发牌（发送最后1张）
		elseif status_name[game_status] == "open" then
			game_open() --开牌
		elseif status_name[game_status] == "result" then
			game_result() --结算	
		end

		--时间数据
		if is_next == 1 and game_status > 0 then
			if status_name[game_status] == "open" then
				next_time = otime() + math.floor(ass_seatplayer_num() * 0.5 + status_time[game_status])
			else
				next_time = otime() + status_time[game_status]
			end
		else
			game_status = game_status - 1
		end
	end
end

--接收消息
function this.dispatch(p, name, msg)
	if name == "GetReadyNtf" then
		if has_start and not is_goldmode then 
			return 
		end
		if is_goldmode then
			if p.gold < min_play_gold then
				send_to_all("game.GetReadyNtf", {uid = p.uid, seatid = 0})
			else
				if p.ready == 0 and not p.nextready then
					if has_goldstart then
						--数据赋值
						p.nextready = 1
						p.kick_timeout = nil

						--发送准备
						local msg = {}
						msg.uid = p.uid
						msg.seatid = p.seatid
						p:send_msg("game.GetReadyNtf", msg)
					else
						p.ready = 1
						p.kick_timeout = nil

						--发送准备
		            	send_ready(p)
					end
				end
			end
		else
			if p.ready == 0 then
				if p.seatid > 0 then
					--数据赋值
					p.ready = 1
					
		            --发送准备
		            send_ready(p)

		            --检查游戏开始
					check_start()
				end
			end
		end
	elseif name == "GetMaster" then
		if status_name[game_status] ~= "getmaster" or not has_start then
			return
		end
		if p.ask_master or p.seatid == 0 or p.ready == 0 then
			return
		end

		--发送消息
		p.ask_master = msg.result
		send_to_all("game.GetMaster", {result = p.ask_master, uid = p.uid})

		--判断是否结束
		local done = true
		for uid,p in pairs(players) do
			if p.seatid > 0 and p.ready == 1 then
				if not p.ask_master then
					done = false
					break
				end
			end
		end
		if done then
			next_time = otime()
		end
	elseif name == "SetRate" then
		if status_name[game_status] ~= "bet" or not has_start then
			return
		end
		if p.rate or p.seatid == 0 or p.ready == 0 or p.uid == master_uid then
			return
		end

		--发送消息
		p.rate = msg.rate
		send_to_all("game.SetRate", {rate = p.rate, uid = p.uid})

		--判断是否结束
		local done = true
		for uid,p in pairs(players) do
			if p.seatid > 0 and p.ready == 1 then
				if not p.rate and p.uid ~= master_uid then
					done = false
					break
				end
			end
		end
		if done then
			next_time = otime()
		end
	elseif name == "ConfirmCards" then
		if status_name[game_status] ~= "sendlast" or not has_start then
			return
		end
		if p.confirm or p.seatid == 0 or p.ready == 0 then
			return
		end

		--发送消息
		p.confirm = true
		send_to_all("game.ConfirmCards", {uid = p.uid})

		--判断是否结束
		local done = true
		for uid,p in pairs(players) do
			if p.seatid > 0 and p.ready == 1 then
				if not p.confirm then
					done = false
					break
				end
			end
		end
		if done then
			next_time = otime()
		end
	elseif name == "DissolveTable" then
		if game_status == 0 then
			if p.uid == owner_uid then
				api_free_table(nil, 1001)
			end
		else
			send_dissolvetable(p, msg.opt)
		end
	end
end

-- 初始化桌子
function this.get_tableinfo(p)
	--桌子初始化
	-- send_table_info(p)
	local msg = {}
	local list = {}
	for uid,v in pairs(players) do
		tinsert(
			list, 
			{
				uid = v.uid, 
				nickname = v.nickname,
				seatid = v.seatid or 0,
				ready = v.ready or 0 ,
				online = v.online or 1,
				gold = v.gold or 0,
				score = v.score or 0,
				headimg = v.headimg or "",
				sex = v.sex or 1
			}
		)
	end
	if is_goldmode then
		msg.code = basic_score
	else
		msg.code = code
	end
	msg.players = list
	msg.gameid = game_id
	msg.owner = owner_uid
	msg.score = bet_score
	msg.paytype = pay_type
	msg.times = total_round
	msg.playedtimes = now_round
	msg.isGoldGame = is_goldmode or 0
	msg.endtime = has_start and 0 or end_time - otime()
	
	return msg
end

-- 离开游戏
function this.leave_game(p)
	if not has_start or p.ready == 0 then
		if p.seatid ~= 0 then
			--数据清空
			seats[p.seatid] = nil
			p.seatid = 0
		end
		check_kick_jqr(p)
		return true
	else
		if is_goldmode then
			if status_name[game_status] == "result" or status_name[game_status] == "start" then
				if p.seatid ~= 0 then
					--数据清空
					seats[p.seatid] = nil
					p.seatid = 0
				end
				check_kick_jqr(p)
				return true
			end
		end
	end
end

--恢复游戏
function this.resume(p, is_resume)
	--发送恢复房间
	send_resume(p)
	
	--金币模式自动坐下
	if not is_resume and is_goldmode then
		--判断是否已经坐下
		if p.seatid and p.seatid > 0 then
	        LOG_WARNING("player[%d] is already sitdown seatid[%d]", p.uid, p.seatid)
	        return
	    end
	    for i=1,game_config.max_player do
	        if not seats[i] then
	            seats[i] = p
	            p.seatid = i
	            p.kick_timeout = otime() + KICK_TIMEOUT
	            	            --金币模式自动坐下
	            send_sit_down(p)
	            break
	        end
	    end
	end
end

--加入房间
function this.join(p)
	if is_tastemode then
		p.gold = game_config.test_gold
	end
	--判断赋值
	p.online = 1
	p.totalbet = 0
	if not p.join or is_goldmode then
		p.ready = 0
		p.score = 0
		p.seatid = 0
		p.join = true
		p.tongsha = 0
		p.tongpei = 0
		p.niuniu = 0
		p.wuniu = 0
		p.shengli = 0
	end
	if p.isrobot then
		p.nowtimes = 0
		p.playtimes = math.random(5,10)
	end
	return true
end

--设置概率
function this.set_kickback(kb, sys)
	ctrl.set_kickback(kb, sys)
end

--初始化
function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid, usegold, _, params, kb)
	-- 数据赋值
	players = ps
	code = m_code
	owner_uid = uid
	pay_type = m_pay
	game_id = m_gameid
	game_config = m_conf
	total_round = m_times
	bet_score = m_score
	game_type = game_config.init_params
	end_time = otime() + game_config.wait_time

	--函数赋值
	api_kick = api.kick
	api_game_end = api.game_end
	send_to_all = api.send_to_all
	api_free_table = api.free_table
	api_game_start = api.game_start
	api_join_robot = api.join_robot
	api_report_gold = api.report_gold

	--数据初始化
	seats = {}
	now_round = 0
	game_status = 0
	has_start = false
	has_goldstart = false
	is_goldmode = usegold
	if game_config.test_gold and game_config.test_gold > 0 then
		is_tastemode = true
	end
	if game_type == 2 or game_type == 3 then
		status_name = {"start", "send", "bet", "sendlast", "open", "result"}
		status_time = {3, 1, 4, 3, 2.5, 4}
	else
		status_name = {"start", "send", "getmaster", "bet", "sendlast", "open", "result"}
		status_time = {3, 1, 4, 4, 3, 2.5, 4}
	end
	if is_goldmode then
		bet_score = 5
		game_type = 4
		basic_score = game_config.init_params
		min_play_gold = game_config.min_gold

		--控制器初始化
		ctrl.init(players,kb,is_tastemode)
	else
		basic_score = 1
	end

	--开始事件赋值
	room_start_time = otime()

	--历史记录初始化
	ass_history_info()
end

return this