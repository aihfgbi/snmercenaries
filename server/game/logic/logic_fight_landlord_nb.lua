--宁波斗地主
-- Created by IntelliJ IDEA.
-- User: jordan
-- time: 2017/11/22
-- Time: 10:39
-- To change this template use File | Settings | File Templates.
--
--注意user_cards和used_cards不要使用错了
local nbUtil = require "fight_landlord_nb_util"
local cardsHelp = require "play_cards_helper"
local build_cards_nb = require "build_cards_nb"
local skynet = require "skynet"
local os_time = os.time
local nflag
local tParams = {}
local this = {}
local isUseGold --是否金币模式
local isMatch --是否比赛模式
local test_gold
--组合过的牌
local combined_cards = {
    -- hands = {}, --手牌
    -- bottom = {} --底牌
}
--房间信息
local seats = {} --座位,数组,[1,4] -> [p...]，前台也需要在[1,4]
local leave_seats = {} --离开用户，当前牌局结束清除该用户
local owner --房主
local endtime --结束时间
local gameid --gameid
local total_times --游戏最多次数
local played_times = 0 --当前游戏局数
local rule_score
local score
local paytype --支付方式
local code
local nMinGold

local histroy --历史记录
local players --所有用户,不需要手动维护
local config --启动配置
local init_params --启动配置参数
local game_status --游戏状态 ，0未开始，1开始，2叫分，5显示地主牌，3出牌，4当前牌局结束,8总牌局结束
local next_status_time --下一个状态执行时间
local cards --洗牌后的牌

local user_cards --用户初始牌,数组,注意长度为6
local used_cards = {} --已出的所有牌
local dipai --八张底牌

local first_master_card --第一次的明牌id,第二次由上次地主开始
local master --抢分后设置的地主：结束之后不要立即清除，下局由他开始叫分
local pre_play_user --上一次出牌人

local rate_pre_player --上一次叫分人
local rate_max = 0 --最大叫分
local rate_max_player --最大叫分人
local rate_count = 0 --叫分次数

local per_gold --暂定每一局1

local users_score = {} --记录用户每局输赢信息

--时间间隔
local time_ask_rate = 10
local time_show_master_cards = 5
local time_paly_card = 15
local time_game_end = 10
local time_game_stop = 10
local time_tuoguan = 1
--金币模式准备超时 秒
local KICK_TIMEOUT = 20
------------------------------------
local tinsert = table.insert
local tremove = table.remove
local tindexof = table.indexof
local tconcat = table.concat
------------------------------------
local kickback
local ctrlcost = 0
local ctrlearn = 0
------------------------------------
local send_to_all
local free_table
local api_game_start
local api_game_end
local api_report_gold
------------------------------------

--------解散相关数据 by zhuzonghe
local consent_dissolve_players = {}             --已同意解散房间的玩家
local refuse_dissolve_players = {}              --已拒绝解散房间的玩家
local dissolve_timeout                          --解散超时
local next_dissolve_time = 0                    --下次可解散的时间
local DISSOLVE_TIME = 60                        --解散超时
local DISSOLVE_CD = 5                      --解散冷却时间
local dissolve_table                            --是否解散

-- 机器人数据
local time_join_robot
local tWhoplay = {}
local jqr_list = {}
-----------------------------------------------------------机器人相关-----------------------------------------
local function check_join_robot()
	if table.len(players) >= config.max_player then
		return
	end
	local now_time = skynet.now()
	if not time_join_robot then
		if table.len(jqr_list) == 0 then
			time_join_robot = now_time + math.random(50,100)
		else
			time_join_robot = now_time + math.random(100,200)
		end
	end
	if now_time >= time_join_robot then
		time_join_robot = nil
		local gold = math.random(nMinGold, nMinGold*10)
		if test_gold then
			gold = 1000000
		end
		api_join_robot("fight_landlord_nb", gold)
	end
end

-- 初始化位置,数组
local function initSeats()
	for i = 1, 4 do
		seats[i] = 0
	end
end

--检查座位是否已满;true ->未满
local function checkSeatsFull()
	local c = 0
	for k, v in pairs(players) do
		c = c + 1
	end
	return c < 4 or false
end

--检查是否可以开始游戏;ture -> 可以开始
local function checkAllReady()
	local ps_count = 0
	for uid, p in pairs(players) do
		if p.ready == 0 or not p.ready then
			return false
		end
		ps_count = ps_count + 1
	end
	return ps_count == 4 or false
end

--检查重新开始
local function checkRestart()
	local ps_count = 0
	for uid, p in pairs(players) do
		if not p.ready2 or p.ready2 ~= 1 then
			return false
		elseif p.ready2 == 1 then
			ps_count = ps_count + 1
		end
	end
	return ps_count == 4 or false
end

--获取下一次叫的分
local function getScore(score)
	local s = {}
	for i = 1, 3 do
		if score < i then
			table.insert(s, i)
		end
	end
	return s
end


--获取叫分人
local function getUserRate()
	local asktime = time_ask_rate
	if not rate_pre_player then
		--注意第一把游戏这时候master还没有值
		::jordan::
		if not master then
			local seatid = first_master_card % 4 + 1
			local p = seats[seatid]
			rate_pre_player = p
			send_to_all("game.AskRate", { time = asktime, seatid = p.seatid, opt = rate_max })
		else
			if not table.keyof(players, master) then 
				master = nil
				goto jordan 
			end
			rate_pre_player = master
			send_to_all("game.AskRate", { time = asktime, seatid = master.seatid, opt = rate_max })
		end
	else
		local p = seats[rate_pre_player.seatid % 4 + 1]
		rate_pre_player = p
		send_to_all("game.AskRate", { time = asktime, seatid = p.seatid, opt = rate_max })
	end
	next_status_time = os.time() + asktime
end

--获取叫分人,不发送消息,不设置数据,提供断线重连
local function getRateUser()
	local p
	if not rate_pre_player then --第一次叫分人
		if not master then
			local seatid = first_master_card % 4 + 1
			p = seats[seatid]
		else
			p = master
		end
	else --上次叫分人
		p = rate_pre_player
	end
	return p
end

--检查必须抢地主
local function check_must_be_master(p)
	local uCards = user_cards[p.seatid]
	local count = 0
	if not uCards then return end
	for i = 1, #uCards do
		if uCards[i] > 500 then
			count = count + 1
		end
	end
	return count >= 2
end

--设置地主
local function set_master(p, score)
	local asktime = 20
	master = p
	p.rate = score
	p.master_count = p.master_count or 0
	p.master_count = p.master_count + 1
	send_to_all("game.SetMaster", { uid = p.uid, score = score })
	send_to_all("game.ShowCard", { uid = p.uid, seatid = -1, cards = user_cards[5] }) -- -1表示量地主牌，和最后量牌区分！！
	send_to_all("game.AddCard", { uid = p.uid, seatid = p.seatid, count = 8, cards = user_cards[5] })
	for i = 1, #user_cards[5] do
		table.insert(user_cards[p.seatid], user_cards[5][i]) --地主牌给玩家
	end
	game_status = 5
	next_status_time = os.time() + time_show_master_cards
end

local function first_ask_play()
	local p, asktime = master, time_paly_card + 5
	send_to_all("game.AskPlayCard", { seatid = p.seatid, time = asktime, cardtype = 0, cards = {}, avatarCards = {} })
	game_status = 3
	if p.trusteeship and p.trusteeship == 1 then
		next_status_time = os.time() + time_tuoguan
	else
		next_status_time = os.time() + asktime
	end
end

--设置赔率
local function setUserRate(p, msg)
	if msg.rate > rate_max then
		rate_max = msg.rate
		rate_max_player = p
	end
	rate_count = rate_count + 1
	if p.trusteeship and p.trusteeship == 1 then
		send_to_all("game.SetRate", { uid = p.uid, rate = 0 })
	else
		send_to_all("game.SetRate", { uid = p.uid, rate = msg.rate })
	end
	p.rate = msg.rate --我始终感觉这种操作很危险,重新开始需要恢复
	if (msg.rate == 3 and isUseGold) or (msg.rate == 5 and score == 5) or (msg.rate == 3 and score == 3) then
		set_master(p, msg.rate)
	elseif rate_count == 4 then
		rate_max_player = rate_max_player or rate_pre_player
		rate_max = rate_max > 0 and rate_max or 1
		set_master(rate_max_player, rate_max)
	else
		getUserRate()
	end
end

--------------------------------------
math.randomseed(os.time());
--检查玩家是否在游戏中
local function check_player_in_game( p )
    if p and p.seatid and p.seatid > 0 and p.ready and p.ready > 0 then
        return true
    end
    LOG_DEBUG("player[%d] is not in game", p.uid or -1)
end
--返回值  0不控制 1玩家 2机器人
local function get_winner_by_kickback( ... )
    if not kickback or kickback == 1 then
        return
    end

    local rate = math.random(1 , 100000)
    if kickback < 1 then
        if rate < 100000 * (1 - kickback) then
            return 2
        else
         --   LOG_DEBUG("全局控制本局不起效")
            return 0
        end
    else
        if rate < 100000 * (kickback - 1) then
            return 1
        else
            LOG_DEBUG("全局控制本局不起效")
            return 0
        end
    end
end

local function random_winner( wtype)
    local user_pool = {}
    local robot_pool = {}
    for uid,p in pairs(players) do
        if p.seatid and p.seatid > 0 then
            if p.isrobot then
                tinsert(robot_pool, uid)
            else
                tinsert(user_pool, uid)
            end
        end
    end
    
    if wtype == 1 then
        return user_pool[math.random(#user_pool)]
    else
        return robot_pool[math.random(#user_pool)]
    end
end

--根据控制器数据对玩家进行排序
local function order_player_by_ctrldata()
	local win_player = {}
	local lose_player = {}
	local result = {}
	local drop_uid = {}

	local function deal_order(t, u)
		if not next(t) then
			if u.ctrlinfo.ctrlcount then
				tinsert(t, {uid=u.uid, level=u.ctrlinfo.ctrllevel, count=u.ctrlinfo.ctrlcount, rate=u.ctrlinfo.ctrlrate})
			else
				tinsert(t, {uid=u.uid, level=u.ctrlinfo.ctrllevel, count=0, rate=u.ctrlinfo.ctrlrate})
			end
		else
			local len = #t
			for i=1, #t do
				if u.ctrlinfo.ctrllevel > t[i].level then
					tinsert(t,i,{uid=u.uid, level=u.ctrlinfo.ctrllevel, count=u.ctrlinfo.ctrlcount, rate=u.ctrlinfo.ctrlrate})
					break
				elseif u.ctrlinfo.ctrllevel == t[i].level then
					if u.ctrlinfo.ctrlcount then
						if t[i].count>0 then
							LOG_ERROR("运营人员的锅~")
							--level 与 count都有就不控制了
							tinsert(drop_uid, u.uid)
							tinsert(drop_uid, t[i].uid)
						else
							tinsert(t, i, {uid=u.uid, level=u.ctrlinfo.ctrllevel, count=u.ctrlinfo.ctrlcount, rate=u.ctrlinfo.ctrlrate})
						end
					else
						if t[i].count==0 then
							if u.ctrlinfo.ctrlrate > t[i].rate then
								tinsert(t, i, {uid=u.uid, level=u.ctrlinfo.ctrllevel, count=u.ctrlinfo.ctrlcount, rate=u.ctrlinfo.ctrlrate})
								break
							elseif u.ctrlinfo.ctrlrate ==  t[i].rate then
							--level 与 rate都相等的不控制了
								tinsert(drop_uid, u.uid)
								tinsert(drop_uid, t[i].uid)
								break
							end
						end
					end
				end
			end
			if len == #t then
				tinsert(t, {uid=u.uid, level=u.ctrlinfo.ctrllevel, count=u.ctrlinfo.ctrlcount, rate=u.ctrlinfo.ctrlrate})
			end
		end
	end

	for uid, p in pairs(players) do
		if p.ctrlinfo and p.ctrlinfo.ctrltype then
			if p.ctrlinfo.ctrltype == 1 then
				deal_order(lose_player, p)
			elseif p.ctrlinfo.ctrltype == 2 then
				deal_order(win_player, p)
			end
		end
	end
	for i=#win_player, 1, -1 do
		if tindexof(drop_uid, win_player[i].uid) then
			tremove(win_player, i)
		end
	end

	for i=#lose_player, 1, -1 do
		if tindexof(drop_uid, lose_player[i].uid) then
			tremove(lose_player, i)
		end
	end
   
	table.clear(drop_uid)
	for _,v in ipairs(win_player) do
		tinsert(result, v.uid)
	end

	local function is_in_t(t, id)
		for _,v in ipairs(t) do
			if v.uid == id then
				return true
			end
		end
	end
   
	for uid,p in pairs(players) do
		if not tindexof(result, uid) and not is_in_t(lose_player, uid) then
			tinsert(drop_uid, uid)
		end
	end

	--打乱drop
	local temp_drop = {}
	local len = #drop_uid 
	--没有玩家被控制
	if len == config.max_player then
		--全是玩家的情况下不需要全局控制
		if table.len(jqr_list)>0 then
			local winner_type = get_winner_by_kickback()
			if winner_type > 0 then
				local ctrl_winner = random_winner(winner_type)
				table.removebyvalue(drop_uid, ctrl_winner)
				len = len - 1
				tinsert(result, ctrl_winner)
			end
		end
	end

	for i=1,len do
		j = math.random(1, i)
		if i ~= j then
			temp_drop[i] = temp_drop[j]
		end
		temp_drop[j] = drop_uid[i]
	end
  
	table.mergeByAppend(result, temp_drop)
	for i=#lose_player, 1, -1 do
		tinsert(result, lose_player[i].uid)
	end

	return result
end

local function add_combined_cards()
	combined_cards.hands, combined_cards.bottom = build_cards_nb.build_land_cards(isUseGold)
	--获取第一次的明牌
	if not master then
		first_master_card = math.random(100)
	end
	local mingCard
	user_cards = {
		[1] = {},
		[2] = {},
		[3] = {},
		[4] = {},
		[5] = {}
	}
	local cnt = 1
	local orderd_uids = order_player_by_ctrldata()
	luadump(orderd_uids,"orderd_uids")
	for _,uid in ipairs(orderd_uids) do
		assert(cnt < 5)
		local p = players[uid]
		if check_player_in_game(p) then
			user_cards[p.seatid] = tremove(combined_cards.hands, 1)
			cnt = cnt + 1
			for u, v in pairs(players) do
				if u == uid then
					v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = 25, cards = user_cards[v.seatid] })
				else
					v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = 25 })
				end
			end
		end
	end
	--底牌赋值
	dipai = user_cards[5]
	for i = 1, 8 do
		table.insert(dipai, combined_cards.bottom[i])
	end
	luadump(user_cards,"user_cards")
end

--注意牌值
--A -> *14
--2 -> *16
--小王 -> 521
--大王 -> 522
-- local static_cards = {
-- 	114, 116, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113,
-- 	214, 216, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213,
-- 	314, 316, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313,
-- 	414, 416, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413,
-- 	521, 522,
-- 	114, 116, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113,
-- 	214, 216, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213,
-- 	314, 316, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313,
-- 	414, 416, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413,
-- 	521, 522
-- }

-- -- 洗牌
-- local function shuffle()
-- 	cards = {}
-- 	local tmp = {
-- 		1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
-- 		14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26,
-- 		27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
-- 		40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52,
-- 		53, 54,
-- 		55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67,
-- 		68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
-- 		81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93,
-- 		94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106,
-- 		107, 108
-- 	}
-- 	local index
-- 	for i = 108, 1, -1 do
-- 		--测试发牌
-- 		index = tremove(tmp, math.random(i))
-- 		--        index = tremove(tmp, 1) --不洗牌
-- 		tinsert(cards, static_cards[index])
-- 	end
-- end

-- --发牌
-- local function add_cards()
-- 	shuffle()
-- 	--获取第一次的明牌
-- 	if not master then
-- 		first_master_card = math.random(100)
-- 	end
-- 	local mingCard
-- 	user_cards = {
-- 		[1] = {},
-- 		[2] = {},
-- 		[3] = {},
-- 		[4] = {},
-- 		[5] = {}
-- 	}
-- 	for j = 1, 100, 1 do
-- 		local index = j % 4 + 1
-- 		local t = user_cards[index]
-- 		table.insert(t, cards[j])
-- 		if first_master_card == j then
-- 			mingCard = cards[j]
-- 			user_cards[6] = { first_master_card, mingCard }
-- 		end
-- 	end
-- 	for uid, p in pairs(players) do
-- 		for u, v in pairs(players) do
-- 			if u == uid then
-- 				v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = 25, cards = user_cards[v.seatid] })
-- 			else
-- 				v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = 25 })
-- 			end
-- 		end
-- 	end

-- 	--底牌赋值
-- 	dipai = user_cards[5]
-- 	for i = 101, 108, 1 do
-- 		table.insert(dipai, cards[i])
-- 	end
-- end

--获取用户总得分
local function get_user_scores(uid)
	local t = { cur_socre = 0, score = 0, bomb_count = 0, remain_cards = {} }
	if not users_score or #users_score == 0 then
		return t
	end
	local uid_scors = users_score[#users_score].uid_scores
	for m, n in pairs(uid_scors) do
		if uid == n.uid then
			return n
		end
	end
	return t
end

--获取用户得分最高的一次
local function get_biggest_scores(uid)
	local b = { cur_socre = 0, bomb_count = 0 }
	for i = 1, #users_score do --总局数
		local uid_scors = users_score[i].uid_scores
		for m, n in pairs(uid_scors) do
			if uid == n.uid then
				b = n
				break
			end
		end
	end
	return b
end

local function free_this_table(reason)
	local total_info = {total = played_times, players = {},score = {}}
	if not isMatch then
		for uid, p in pairs(players) do
			if p.ready == 1 and p.seatid and p.seatid > 0 then
				local totalscore = get_user_scores(p.uid).score
				tinsert(total_info.players, p.nickname)
				tinsert(total_info.score, totalscore)
			end
		end
	end
	free_table(total_info, reason)
end

--设置用户每局得分
local function set_user_scores(gold, isMasterWin)
	local uid_score = {}
	for i = 1, #seats do
		local p = seats[i]
		local scores = get_user_scores(p.uid)
		local uscores = scores.score
		local temp_score = {}
		if isMasterWin then --地主赢
			if p.uid == master.uid then
				temp_score.cur_socre = 3 * gold
				temp_score.score = uscores + 3 * gold
			else
				temp_score.cur_socre = -gold
				temp_score.score = uscores - gold
			end
		else
			if p.uid == master.uid then
				temp_score.cur_socre = -3 * gold
				temp_score.score = uscores - 3 * gold
			else
				temp_score.cur_socre = gold
				temp_score.score = uscores + gold
			end
		end
    if temp_score.cur_socre > 0 then
        ctrlearn = ctrlearn + temp_score.cur_socre
    else
        ctrlcost = ctrlcost + math.abs(temp_score.cur_socre)
    end
		local t = {}
		t.uid = p.uid
		t.cur_socre = temp_score.cur_socre
		t.score = temp_score.score
		t.bomb_count = p.bomb_count or 0
		t.remain_cards = user_cards[i]
		table.insert(uid_score, t)
	end
	--这里可以设置用户金币消息?
	table.insert(users_score, {
		master = master.uid,
		rate_max = rate_max,
		uid_scores = uid_score
	})
end

local function changegold(p,gold)
	if gold > 0 then
		--增加金币
		if not test_gold then
			p:call_userdata("add_gold", gold, gameid)
			p:call_userdata("add_win", gameid, 1001)
		end
	elseif gold < 0 then
		-- 减少金币
		if not test_gold then
			p:call_userdata("sub_gold", -gold, gameid)
		end
	end
	if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 1 and not p.isrobot then
		p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold - gold
	elseif p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 2 and not p.isrobot then
		p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + gold
	end
	--判断处理
	p.gold = p.gold + gold
end

local function goldchange(njordan,uid_score)
	local t = {1,6,11,16}
	local a = 0 --地主实得
	local b = 0 --农民实得
	local nIndex
	if njordan == 1 then
		b = math.floor(players[master.uid].gold/3)
		a = - (b * 3)
		for _,v in pairs(t) do
			if uid_score[v] == master.uid then
				uid_score[v+3] = a
				changegold(players[uid_score[v]],a)
			else
				uid_score[v+3] =b
				changegold(players[uid_score[v]],b)
			end
		end
	elseif njordan == 2 then
		for _,v in pairs(t) do
			if uid_score[v] == master.uid then
				nIndex = v
			else
				if uid_score[v+3] < 0 and uid_score[v+3] + players[uid_score[v]].gold < 0 then
					uid_score[v+3] = - players[uid_score[v]].gold
					a = a + players[uid_score[v]].gold
				else
					a = a + math.abs(uid_score[v+3])
				end
				changegold(players[uid_score[v]],uid_score[v+3])
			end
		end
		uid_score[nIndex + 3] = a
		changegold(players[master.uid],a)
	end
end

--当前游戏结束:
local function broadcast_win(is_spring)
	local uid_cards = {}
	local uid_score = {}
	local end_rst = {index = played_times, players = {}, score = {}}
	local goldfield = {}
	local njordan = 0
	for i = 1, #seats do
		local p = seats[i]
		local uscores = get_user_scores(p.uid)
		if uscores.cur_socre < 0 and p.gold + uscores.cur_socre < 0 then
			if p.uid == master.uid then
				njordan = 1 --地主钱不够
			else
				njordan = 2 --地主钱不够
			end
		end
		local t_cards = user_cards[i]
		table.insert(uid_score, p.uid) --uid
		table.insert(uid_score, #t_cards) --剩余牌数量
		table.insert(uid_score, p.bomb_count or 0) --出牌炸弹数量
		table.insert(uid_score, uscores.cur_socre) --当局积分胜负
		table.insert(uid_score, uscores.score) --总积分胜负
		p.score = uscores.score --设置用户分数
		tinsert(end_rst.players, p.nickname)
		tinsert(end_rst.score, uscores.cur_socre)
		if njordan == 0 then
			changegold(p,uscores.cur_socre)
		end
	end
	if isUseGold and njordan ~= 0 then
		goldchange(njordan,uid_score)
	end
	local result = {
		master = master.uid,
		count = 4,
		infos = uid_score,
		cards = {}, --按照当前文档是不需要的
		spring = is_spring
	}
	for k, v in pairs(players) do
		send_to_all("game.ShowCard", { uid = v.uid, seatid = v.seatid, cards = user_cards[v.seatid] })
	end
	send_to_all("game.GameResult", result)
	-- if is_spring == 1 then
	--     send_to_all("game.GameResult", { master = master.uid, count = 0, spring = 1 })
	-- end
	api_game_end(end_rst)
end

--记录炸弹数据
local function do_bomb_count(type, p)
	if type == nbUtil.ZHADAN or type == nbUtil.WANGZHA then
		p.bomb_count = p.bomb_count and p.bomb_count + 1 or 1
	end
end

--获取炸弹总数
local function get_bomb_count()
	-- local total = 0
	-- for k, v in pairs(players) do
	-- 	local c = v.bomb_count or 0
	-- 	total = total + c
	-- end
	-- if score == -1 then
	-- 	return total
	-- end

	-- return total > score and score or total
	return 0
end

--判断是否是春天，翻倍但在封顶限制内
--p 最先出牌的人
local function is_spring(p)
	if p.uid == master.uid then --地主赢
		for k, v in pairs(players) do
			local docard_times = v.docard_times or 0
			if v.uid ~= p.uid and docard_times > 0 then
				return false
			end
		end
		return true
	else
		return master.docard_times == 1
	end
end

--设置用户输赢局数
local function set_user_win_count(isMasterWin)
	for k, v in pairs(players) do
		if isMasterWin then
			if master.uid == v.uid then
				v.win_count = v.win_count and v.win_count + 1 or 1
			else
				v.lose_count = v.lose_count and v.lose_count + 1 or 1
			end
		else
			if master.uid == v.uid then
				v.lose_count = v.lose_count and v.lose_count + 1 or 1
			else
				v.win_count = v.win_count and v.win_count + 1 or 1
			end
		end
	end
end

--统计春天
local function spring_count(p, spring)
	if spring == 1 then
		local isMasterWin = p.uid == master.uid
		for k, v in pairs(players) do
			if isMasterWin and v.uid == master.uid then --地主赢
				local msc = master.spring_count or 0
				master.spring_count = msc + 1
			end
			if not isMasterWin and v.uid ~= master.uid then
				local csc = v.spring_count or 0
				v.spring_count = csc + 1
			end
		end
	end
end

--结算
local function calculate(p)
	local bomb_count = get_bomb_count()
	local is_spring = is_spring(p) and 1 or 0
	local double_counts = bomb_count + is_spring
	if score ~= -1 then --不限制翻倍
		double_counts = double_counts > score and score or double_counts
	end
	local gold = rate_max * per_gold * (2 ^ double_counts)
	if p.uid == master.uid then
		set_user_scores(gold, true)
		set_user_win_count(true)
	else
		set_user_scores(gold, false)
		set_user_win_count(false)
	end
	spring_count(p, is_spring)
	broadcast_win(is_spring)
	if p.isrobot then
		if p.gold < nMinGold then
			api_kick(p, 1006)
		end
	end
end

--获取当前出牌用户
local function get_play_user()
	if nil == pre_play_user then --由地主开始出牌
		return master
	else
		local seatid = pre_play_user.seatid
		return seats[seatid % 4 + 1]
	end
end

--获取最后一个人出的牌，除开过的牌,p是当前操作人
local function get_last_player(p)
	if used_cards and #used_cards > 0 then
		local t = used_cards[#used_cards]
		local p1 = get_play_user(p)
		if p1.uid == t[6] then
			return false --是自己
		else
			return t
		end
	end
	return false --首次出牌
end

--判断是否是托管
--通知下一个出牌人,p是当前操作人 p = player
local function notify_to_paly(p)
	pre_play_user = p
	--千万注意顺序
	local type, cards, avatarCards = 0, {}, {}
	local last_u_cards = get_last_player(p)
	if last_u_cards then
		type = last_u_cards[1]
		cards = last_u_cards[2]
		avatarCards = last_u_cards[3]
	end
	p = get_play_user()
	local asktime = time_paly_card
	if p.trusteeship and p.trusteeship == 1 then
		LOG_DEBUG("trusteeship trusteeship to play!" .. p.uid)
		send_to_all("game.AskPlayCard", { seatid = p.seatid, time = asktime, cardtype = type, cards = cards, avatarCards = avatarCards })
		next_status_time = os.time() + time_tuoguan
	else
		send_to_all("game.AskPlayCard", { seatid = p.seatid, time = asktime, cardtype = type, cards = cards, avatarCards = avatarCards })
		next_status_time = os.time() + asktime
	end
end

--从自己的牌中删除已经出的牌
--p -> player
--cards 封装好的数据结构，包含6个长度的数组
local function do_delete_cards(p, cards)
	local cur_cards = user_cards[p.seatid]
	local nor_cards = cards[2] --普通牌
	local cha_cards = cards[3] --王牌
	if nor_cards then
		for j = 1, #nor_cards do
			for i = 1, #cur_cards do
				if cur_cards[i] == nor_cards[j] then
					table.remove(cur_cards, i)
					break
				end
			end
		end
	end
	if cha_cards then
		for j = 1, #cha_cards do
			for i = 1, #cur_cards do
				if j % 2 == 1 and cur_cards[i] == cha_cards[j] then
					table.remove(cur_cards, i)
					break
				end
			end
		end
	end
end

--用户:检查当前操作是否有操作牌
--cards
local function check_pass_to_play(cards)
	if #cards[2] == 0 and #cards[3] == 0 then
		return true
	end
	return false
end

--用户离开
local function do_clear_player(p)
	LOG_DEBUG("do_clear_player----->")
	--luadump(p)
	if seats and p.seatid then
		seats[p.seatid] = 0
	end
	if p == master then
		master = nil
	end
	p.seatid = nil
	p.ready = 0
	send_to_all("game.LeaveTableNtf", { uid = p.uid })
end

--清除待离开用户:房卡模式
local function check_leave_player()
	if not leave_seats and played_times == total_times then
		for k, v in pairs(leave_seats) do
			do_clear_player(v)
		end
	end
end

local function game_stop()
	game_status = 8
	next_status_time = os.time() + time_game_stop
	LOG_INFO("game_stop-------->")
	histroy.endtime = os.time()
	histroy.players = histroy.players or {}
	local info
	local infos = {}
	for uid, p in pairs(players) do
		if p.ready == 1 and p.seatid and p.seatid > 0 then
			local totalscore = get_user_scores(p.uid).score
			local biggestscore = get_biggest_scores(p.uid) --获取用户赢得最多的一局
			info = {
				uid = p.uid,
				nickname = p.nickname,
				wincount = p.win_count or 0,
				losecount = p.lose_count or 0,
				totalscore = totalscore or 0,
				maxscore = biggestscore.cur_socre or 0,
				bombcount = biggestscore.bomb_count or 0,
				springcount = p.spring_count or 0,
				mastercount = p.master_count or 0,
			}
			tinsert(histroy.players, info)
			tinsert(infos, info)
		end
	end
	--luadump(infos)
	--发送总牌局结束消息
	send_to_all("game.GameLandlordEnd", { round = played_times, infos = infos })
	--发送历史牌局消息??
	--    send_to_all("game.NiuNiuHistroy", {list = histroy.recording})
	if isUseGold then
		p.kick_timeout = os_time() + KICK_TIMEOUT
	else
		check_leave_player()
	end
end

--检测总牌局是否结束
local function check_to_end()
	if played_times == total_times or dissolve_table then
		game_stop()
	end
end


--用户：检测当前牌局结束
local function check_to_win(p)
	if not user_cards[p.seatid] or #user_cards[p.seatid] == 0 then
		if isUseGold then
			game_status = 0
			nflag = false
			table.clear(tParams)
			for uid, p in pairs(players) do
				if p.seatid and p.seatid > 0 then
					if p.isrobot and p.win_count and p.win_count > 5 then
					-- if p.isrobot then
						api_kick(p, 1007)
					else
						p.kick_timeout = os_time() + KICK_TIMEOUT
						--金币模式每局开始需要重新准备，所以在游戏开始后清掉准备状态
						p.ready = 0
					end
				end
			end
			elseif isMatch then
			free_this_table(1002)
		else
			game_status = 4
			next_status_time = os_time() + time_game_end
			check_to_end()
		end
	for k, v in pairs(players) do
		v.trusteeship = 0 --默认取消托管
	end
		calculate(p)
		return true
	end
	return false
end

--统一出牌函数:
-- -- 现在不出牌，那么在出牌记录中不保存
-- -- 在这里对空做了处理
-- -- 这里还需要做必出判断?
--max 最大牌值
--leng 组合牌行最大长度334455 -> 3
--uid
--cards = { [1] = msg.cardtype, [2] = msg.cards, [3] = msg.avatarCards }
local function do_play_cards(max, leng, uid, cards)
	local p = players[uid]
	local i_type, i_cards, i_avatar = cards[1], cards[2], cards[3]
	cards[1] = i_type
	cards[2] = i_cards or {}
	cards[3] = i_avatar or {}
	cards[4] = max
	cards[5] = leng
	cards[6] = uid
	if not check_pass_to_play(cards) then --不是过,插入出牌记录
		table.insert(used_cards, cards)
		p.docard_times = p.docard_times and p.docard_times + 1 or 1
		table.clear(tWhoplay)
	end
	table.insert(tWhoplay,p.uid)
	send_to_all("game.PlayCard", { uid = p.uid, cards = cards[2], avatarCards = cards[3], cardtype = cards[1] })
	do_bomb_count(i_type, p)
	do_delete_cards(p, cards)
	if not check_to_win(p) then
		notify_to_paly(p)
	end
end


--允许出牌：统一出牌函数,test
local function do_play_cards_test(p, msg)
	do_play_cards(0, 0, p.uid, { 1, msg.cards, msg.avatarCards })
end

--获取必须出牌人
local function get_must_player()
	if #used_cards == 0 or nil == used_cards then
		return master
	end
	local last_playerid = used_cards[#used_cards][6]
	local p = get_play_user()
	if p.uid == last_playerid then
		return p
	end
	return nil
end

--用户出牌：检查 ->出牌
--p ->player
--msg
local function check_cards_to_play(p, msg)
	if get_play_user().uid == p.uid then
		local cards = {
			msg.cardtype or 1,
			msg.cards or {},
			msg.avatarCards or {}
		}
		local flag, max, leng = nbUtil.check(cards, user_cards[p.seatid], used_cards, p.uid)
		if flag then
			do_play_cards(max, leng, p.uid, cards)
		else
			if p == master then
				local error_cards = cardsHelp.error_deal(user_cards[p.seatid],p)
				do_play_cards(error_cards.max, error_cards.len, p.uid, {[1]=error_cards.len,[2]=error_cards.cards,[3]={}})
			else
				do_play_cards(0, 0, p.uid, {[1]=0,[2]={},[3]={},[4]=0,[5]=0,[6]=p.uid})
			end
		end
	else
		LOG_ERROR("error: it't your turn !--->")
	end
end

--超时出牌
local function do_cancel_to_play(p, palycards)
	if palycards then
		local max, avatarCards, type, tCards = palycards.max, palycards.avatarCards, palycards.type, palycards.cards
		local msg = {}
		msg.uid = p.uid
		msg.cardtype = type
		msg.cards = tCards
		msg.avatarCards = avatarCards or {}
		check_cards_to_play(p, msg)
	else
		local msg = {}
		msg.uid = p.uid
		msg.cardtype = 0
		msg.cards = {}
		msg.avatarCards = {}
		check_cards_to_play(p, msg)
	end
end

--自动出牌2次，默认托管
local function check_to_auto(p)
	if not p.isrobot then
		p.trusteeship_count = p.trusteeship_count and p.trusteeship_count + 1 or 1
	end
	if p.trusteeship_count > 1 then
		if p.trusteeship ~= 1 then
			p.trusteeship = 1
			send_to_all("game.LandTrusteeship", { uid = p.uid, state = 1 })
		end
	end
end

function PlayOrNot()
	local x = table.indexof(tWhoplay,master.uid)
	if (x == 1) or (not x) then
		return true
	else
		return false
	end
end

--用户:出牌超时,一手牌必须出,默认最小的一张,其他不要
function this.cancel_to_play()
	--    LOG_DEBUG("cancel_to_play---------->")
	local p = get_must_player()
	if not p then
		p = get_play_user()
		check_to_auto(p)
		local pre_cards = used_cards[#used_cards]
		local palycards
		if p == master then
			palycards = cardsHelp.press_cards(user_cards, pre_cards,master,p,players)
		else
			if PlayOrNot() then
				palycards = cardsHelp.press_cards(user_cards, pre_cards,master,p,players)
			end
		end
		do_cancel_to_play(p, palycards)
	else --必出,随机出大小不确定
		check_to_auto(p)
		local card = user_cards[p.seatid]
		local palycards = cardsHelp.get_cards(user_cards,master,p)
		do_cancel_to_play(p, palycards)
	end
end

--用户:托管
local function check_mandate(p)
end

--用户:掉线
local function check_user_lost(p)
end

--用户:听牌
local function check_ready_hand(p)
end

local function report_gold_info()
    if not isUseGold then return end
    while true do 
        if ctrlcost > 0 or ctrlearn > 0 then
            -- CMD.report(addr, gameid, usercost, userearn)
            --LOG_DEBUG("上报数据:cost="..ctrlcost..",earn="..ctrlearn)
            api_report_gold(ctrlcost, ctrlearn)
            ctrlcost = 0
            ctrlearn = 0
        end
        skynet.sleep(5*100)
    end
end

--初始化
function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid,usegold,matchid,params, kb)
	math.randomseed(os.time(), "进入房间成功!");
	isUseGold = usegold
	isMatch = matchid
	players = ps
	config = m_conf
	test_gold = m_conf.test_gold
	init_params = config.init_params
	game_status = 0
	initSeats() --数组
	owner = uid
	gameid = m_gameid
	total_times = m_times
	code = m_code
	paytype = m_pay
	rule_score = m_score
	if not isUseGold then
		endtime = os.time() + m_conf.wait_time
	end
	per_gold = init_params.base_score or 1
	nMinGold = m_conf.min_gold or 0
	if isUseGold then
		score = -1
	else
		score = m_score --炸弹翻倍限制 (无限)-1, 4, 6, 8
	end

	send_to_all = api.send_to_all
	free_table = api.free_table
	api_game_start = api.game_start
	api_game_end = api.game_end
	api_kick = api.kick
	api_join_robot = api.join_robot
	api_report_gold = api.report_gold
	histroy = {}
	histroy.owner = uid
	histroy.time = os.time()
	histroy.code = m_code
	histroy.times = total_times
	histroy.gameid = gameid

	--初始化数据
   if usegold and kb then
       LOG_DEBUG("set kickback[%s]", tostring(kb))
       kickback = kb
       ctrlcost = 0
       ctrlearn = 0
       skynet.fork(report_gold_info)
   end
end

--aa返还扣费
local function uesr_uncost(p)
	if p.hascost then
		if paytype == 1 then
			local price = tonumber(config.price[1])
			local ok, result = pcall(p.call_userdata, p, "add_gold", price, 1003)
			if ok and result then
				p.hascost = nil
				return true
			end
			LOG_DEBUG("user uncost error-->")
		 --   --luadump(p)
		end
	else
		LOG_DEBUG("uesr_uncost error ,p hascost is false," .. " paytye:" .. paytype)
	--    --luadump(p)
	end
end

--aa制扣费
local function uesr_cost(p)
	if p.hascost then
		return true
	end
	if paytype == 1 then
		-- local price = tonumber(config.price[1])
		-- if total_times == tonumber(config.times[2]) then
		--     price = tonumber(config.price[2])
		-- end
		-- local ok, result = pcall(p.call_userdata, p, "sub_gold", price, 1001)
		-- if ok and result then
		--     p.hascost = true
		--     return true
		-- end
		return true
	elseif paytype == 2 then
		return true
	end
	LOG_DEBUG("user cost error-->")
end

--离线调用
function this.offline(p)
	if dissolve_timeout then
		if not tindexof(consent_dissolve_players, p.uid) and not tindexof(refuse_dissolve_players, p.uid)  then
			tinsert(consent_dissolve_players, p.uid)
			send_to_all("game.PushDissolveTable", { consentUid = consent_dissolve_players,
														refuseUid = refuse_dissolve_players,
											
														remaintime = remaintime})
		end
	end
end


-- 发送房间信息
function this.get_tableinfo(p)
	local msg = {}
	local list = {}
	for uid, v in pairs(players) do
		tParams[uid] = tParams[uid] or {}
		if not tParams[uid][1] then
			tParams[uid][1] = 0
		end
		if game_status == 0 then
			tParams[uid][2] = v.kick_timeout or os_time() + KICK_TIMEOUT
		end
		tinsert(list, {
			uid = v.uid,
			nickname = v.nickname,
			sex = v.sex or 1,
			seatid = v.seatid or 0,
			ready = v.ready or 0,
			online = v.online or 1,
			score = v.score or 0,
			gold = v.gold or 0,
			trusteeship = v.trusteeship or 0,
			headimg = v.headimg or "",
			params = tParams[uid] or {}
		})
	end
	msg.owner = owner
	msg.endtime = endtime or 0
	msg.gameid = gameid
	msg.times = total_times
	msg.playedtimes = played_times
	if isUseGold then
		msg.score = -1
	else
		msg.score = score
	end
	msg.paytype = paytype
	msg.code = code
	msg.players = list
	msg.isGoldGame = isUseGold or 0
	-- p:send_msg("game.TableInfo", msg)
	return msg
end

--金币模式自动坐下
local function auto_sitdown(p)
	if p.seatid and p.seatid > 0 then
		LOG_WARNING("player[%d] is already sitdown seatid[%d]", p.uid, p.seatid)
		return
	end
	for i=1,4 do
		if seats[i] == 0 then
			seats[i] = p
			p.seatid = i
			p.ready = 0
			if not owner then
				owner = p.uid
			end
			LOG_DEBUG("auto sit down success"..p.uid)
			p.kick_timeout = os_time() + KICK_TIMEOUT
			send_to_all("game.SitdownNtf", { uid = p.uid, seatid = i, nickname = p.nickname, headimg = p.headimg or "" })
			break
		end
	end
	assert(p.seatid and p.seatid > 0, "not enough seatid")
end

-- 检查进入金币
local function checkjoin(p)
	if p.gold < nMinGold then
		LOG_WARNING("金币不够")
		return false
	end
	return true
end

--必须返回
function this.join(p)
	if not checkSeatsFull() then
		return false
	end
	if isUseGold then
		if not checkjoin(p) then
			return false
		end
		if p.isrobot then
			jqr_list[p.uid] = p
		end
		if test_gold and not p.isrobot then
			p.gold = test_gold
		end
	end
	return true
end

function this.game_end()
end

--只要游戏未开始都允许离开
--开房模式整个牌局结束允许离开
--单局模式，当前牌局结束允许离开
function this.leave_game(p)
	LOG_DEBUG("--->leave_game,game status is:" .. game_status)
	if game_status == 0 then
		do_clear_player(p)
		-- uesr_uncost(p)
		return true
	end
	leave_seats[p.uid] = p
	return false
end

--获取上一次最后出的牌用于恢复现场,要不起不算出牌
local function getLastCards(p)
	local msg = {}
	if used_cards and #used_cards > 0 then
		local last = used_cards[#used_cards]
		msg.uid = last[6]
		msg.cards = last[2]
		msg.avatarCards = last[3]
		msg.cardtype = last[1]
		return msg
	end
	--说明该p出牌
	msg.uid = p.uid
	msg.cards = {}
	msg.avatarCards = {}
	msg.cardtype = 0
	return msg
end

--断线重连调用
--应该每一种状态都需要恢复
function this.resume(p, is_resume)
	if not is_resume and isUseGold then
		auto_sitdown(p)
	end
	-- 恢复游戏
	-- 状态 2,3|叫分，出牌
	-- 当前状态剩余时间
	-- 玩家的牌
	LOG_DEBUG("--->start resume game_status:" .. game_status .. " uid:" .. p.uid)
	local msg = {}
	if (game_status == 2) or (game_status == 1) then
		LOG_DEBUG("--->start resume game_status:" .. game_status .. " uid:" .. p.uid)
		LOG_DEBUG("--->gameid:" .. gameid)
		msg.status = game_status
		msg.time = next_status_time - os.time()
		local currp = getRateUser() --当前叫分人
		msg.curruid = currp.uid

		local info = {}
		for uid, v in pairs(players) do
			local cards = user_cards[v.seatid] or {}
			if p.uid == uid then
				tinsert(info, { uid = uid, cards = cards, count = #cards })
			else
				tinsert(info, { uid = uid, cards = {}, count = #cards })
			end
		end
		msg.pcards = info --恢复牌

		local rate = {}
		for k, v in pairs(players) do
			if v.rate then
				table.insert(rate, { uid = v.uid, score = v.rate })
			end
		end
		msg.rate = rate

		--luadump(msg)
		p:send_msg("game.GameLandResume", msg)
		-- send_to_all("game.UserOnline", { uid = p.uid })
	elseif game_status == 3 then
		LOG_DEBUG("--->start resume game_status:" .. game_status .. "uid:" .. p.uid)
		LOG_DEBUG("--->gameid:" .. gameid)
		msg.status = game_status
		msg.time = next_status_time - os.time()
		if pre_play_user then
			msg.curruid = seats[pre_play_user.seatid % 4 + 1].uid
		else
			msg.curruid = master.uid
		end
		local info = {}
		for uid, v in pairs(players) do
			local cards = user_cards[v.seatid] or {}
			if p.uid == uid then
				tinsert(info, { uid = uid, cards = cards, count = #cards })
			else
				tinsert(info, { uid = uid, cards = {}, count = #cards })
			end
		end
		msg.pcards = info
		local lastCards = getLastCards(p)
		msg.ucards = { lastCards }

		local rate = {}
		--        for k, v in pairs(players) do
		--            if v.rate then
		local bomb_count = get_bomb_count()
		table.insert(rate, { uid = master.uid, score = rate_max })
		table.insert(rate, { uid = -1, score = bomb_count })
		--            end
		--        end
		msg.rate = rate

		--luadump(msg)
		p:send_msg("game.GameLandResume", msg)
		-- send_to_all("game.UserOnline", { uid = p.uid })
	elseif  game_status == 5 then
		LOG_DEBUG("--->start resume game_status:" .. game_status .. "uid:" .. p.uid)
		LOG_DEBUG("--->gameid:" .. gameid)
		msg.status = game_status
		msg.time = next_status_time - os.time()
		msg.curruid = -1
		local info = {}
		for uid, v in pairs(players) do
			local cards = user_cards[v.seatid] or {}
			if p.uid == uid then
				tinsert(info, { uid = uid, cards = cards, count = #cards })
			else
				tinsert(info, { uid = uid, cards = {}, count = #cards })
			end
		end
		msg.pcards = info
		local rate = {}
		local bomb_count = get_bomb_count()
		table.insert(rate, { uid = master.uid, score = rate_max })
		table.insert(rate, { uid = -1, score = bomb_count })
		msg.rate = rate
		p:send_msg("game.GameLandResume", msg)
	end
	--解散房间的信息
	if dissolve_timeout then
		p:send_msg("game.PushDissolveTable", { consentUid = consent_dissolve_players,
													refuseUid = refuse_dissolve_players,
													remaintime = dissolve_timeout - os_time()})
	end
end

--清掉准备状态
local function clear_ready_status()
	for uid, p in pairs(players) do
		p.ready = 0
	end
end

function this.game_start()
	played_times = played_times + 1
	send_to_all("game.GameStart", {})
	send_to_all("game.StartRound", { round = played_times, total = total_times })
	game_status = 1
	next_status_time = os.time() + 1
	-- add_cards()
	add_combined_cards()
	api_game_start()
	if isUseGold then
		clear_ready_status()
	end
end

function this.free()
	for seatid, v in pairs(seats) do
		seats[seatid] = nil
	end
	seats = nil
	leave_seats = nil
	static_cards = nil
	cards = nil
	user_cards = nil
	used_cards = nil
	dipai = nil

	free_table = nil
	send_to_all = nil
	api_game_start = nil
	histroy = nil

	for uid, p in pairs(players) do
		for k, v in pairs(p) do
			p[k] = nil
		end
	end
end

local function game_restart()
	--检测用户是否离开，金钱等等
	rate_pre_player = nil
	rate_max = 0
	rate_max_player = nil
	rate_count = 0

	used_cards = {}

	pre_play_user = nil
	played_times = played_times + 1

	--清空用户上局数据
	for k, v in pairs(players) do
		v.rate = nil --当局叫分数
		v.bomb_count = 0 --当局炸弹数目
		v.ready2 = 0 --牌局结束是否点击再来一局
		v.docard_times = 0 --当局出牌次数，过不算
		v.trusteeship = 0 --默认取消托管
		v.trusteeship_count = 0 --清除默认出牌次数
	end

	api_game_start()
	send_to_all("game.GameStart", {})
	send_to_all("game.StartRound", { round = played_times, total = total_times })
	game_status = 1
	next_status_time = os.time() + 1
	-- add_cards()
	add_combined_cards()
	if isUseGold then
		clear_ready_status()
	end
end

local function reset_dissolve_data( faild )
	dissolve_timeout = nil
	if faild then
		next_dissolve_time = os_time() + DISSOLVE_CD
	end
	table.clear(consent_dissolve_players)
	table.clear(refuse_dissolve_players)
end

local function dissolve_table_success()
	reset_dissolve_data()
	send_to_all("game.PushDissolveTable", {result = 2})
	game_status = 4
	dissolve_table = true
	check_to_end()

	local users = {}
	local scores = {}
	for uid, p in pairs(players) do
	    if check_player_in_game(p) then
	        tinsert(users, p.nickname)
	        tinsert(scores, 0)
	    end
	end

	local rst = {index = played_times + 1, players = users, score = scores}
	api_game_end(rst)
end

local function dissolve_table_faild()
	reset_dissolve_data(1)
	send_to_all("game.PushDissolveTable", {result = 3})
end

local function get_player_num()
	if not players then return 0 end
	local count = 0

	for k,v in pairs(players) do
		if v.ready and v.ready == 1 then
			count = count + 1
		end
	end
	return count
end

--检查房间的解散状态
local function check_dissolve_table()
	if dissolve_timeout then
		if #consent_dissolve_players >= get_player_num() or os_time() >= dissolve_timeout then
			dissolve_table_success()
		end

		if #refuse_dissolve_players > 0 then
			dissolve_table_faild()
		end
	end
end

--有人提出/同意解散房间
local function consent_dissolve_table(p)
	local remaintime
	local now_time = os_time()
	if not next(consent_dissolve_players) then
		dissolve_timeout = now_time + DISSOLVE_TIME
		remaintime = DISSOLVE_TIME
		for uid, player in pairs(players) do
      if check_player_in_game(player) then
        if not player.online or player.online == 0 then
            tinsert(consent_dissolve_players, uid)
        end
      end
     end
	 --   next_dissolve_time = now_time + DISSOLVE_CD
	end
	if not tindexof(consent_dissolve_players, p.uid) then
		tinsert(consent_dissolve_players, p.uid)
		send_to_all("game.PushDissolveTable", { consentUid = consent_dissolve_players,
													refuseUid = refuse_dissolve_players,
													remaintime = remaintime})
	end
end

--拒绝解散
local function refuse_dissolve_table(p)
	if dissolve_timeout and not tindexof(refuse_dissolve_players, p.uid) then
		tinsert(refuse_dissolve_players, p.uid)
		send_to_all("game.PushDissolveTable", { consentUid = consent_dissolve_players,
													refuseUid = refuse_dissolve_players,
													remaintime = remaintime})
	end
end

local function client_dissolve_table_msg(p, msg)
	if p and p.seatid and p.seatid > 0 and p.ready and p.ready == 1 then
		local now_time = os_time()
		if now_time < next_dissolve_time then
			p:send_msg("game.PushDissolveTable", {result = 4, remaintime = next_dissolve_time-now_time})
			return
		end
		if msg.opt == 1 then
			consent_dissolve_table(p)
		elseif msg.opt == 2 then
			consent_dissolve_table(p) --同意
		elseif msg.opt == 3 then
			refuse_dissolve_table(p) --拒绝
		end
	end
end

--踢掉超时未准备的玩家
local function kick_player(p)
	seats[p.seatid] = 0
	p.seatid = nil
	api_kick(p, 1005)
end

local function check_kick_players()
	local now_time = os_time()
	for uid, p in pairs(players) do
		if (not p.ready or p.ready == 0) and p.kick_timeout and now_time > p.kick_timeout then
			kick_player(p)
		end
	end
end

--游戏外部强制解散
function this.dissolve_table()
	if game_status == 0 then
		free_this_table(1001)
	else
		dissolve_table_success()
	end

end


--是否全是机器人
local function all_robot()
	for k, v in pairs(players) do
		if not v.isrobot then
			return false
		end
	end
	return true
end

function this.update()
	if game_status ~= 0 then
		check_dissolve_table()
	elseif isUseGold then
		check_kick_players()
		if nflag and config.add_robot then
			check_join_robot()
		end
		if all_robot() then
			for _,v in pairs(players) do
				kick_player(v)
			end
		end
	end
	if endtime and game_status == 0 and os.time() > endtime then --超时未开始直接清除房间
		-- for k, v in pairs(players) do --返还所有玩家的钱
		--     uesr_uncost(v)
		-- end
		free_this_table(1001)
	elseif game_status == 1 and os.time() > next_status_time then --开始游戏状态
		game_status = 2
		getUserRate()
	elseif game_status == 2 and os.time() > next_status_time then --超时取消叫分
		setUserRate(rate_pre_player, { rate = 0 })
	elseif game_status == 5 and os.time() > next_status_time then --显示地主牌
		first_ask_play()
	elseif game_status == 3 and os.time() > next_status_time then --出牌超时
		this.cancel_to_play()
	elseif game_status == 4 and os.time() > next_status_time then --给出结算时间
		if checkAllReady() then game_restart() end
	elseif game_status == 8 and (os.time() > next_status_time or dissolve_table) then --给出结算时间
		free_this_table(1002)
	end
end

function this.sitdown(p,seatid)
	if isUseGold then
		LOG_WARNING("gold module can not sitdown")
		return
	end
	local seatid = tonumber(seatid)

	if not seatid or seatid < 1 or seatid > config.max_player then
		LOG_ERROR("player[%d] sit down faild", p.uid)
		return
	end

	if p.seatid and p.seatid > 0 then
		seats[p.seatid] = nil
		p.ready = 0
	end

	seats[seatid] = p
	p.seatid = seatid

	if not owner then
		owner = p.uid
	end
	return true
end

function this.standup(p,seatid)
	if isUseGold then
		LOG_WARNING("gold module can not sitdown")
		return
	end
	local seatid = tonumber(seatid)

	if not seatid or seatid < 1 or seatid > config.max_player then
		LOG_WARNING("player[%d] sit down faild", p.uid)
		return
	end

	if not p.seatid or p.seatid ~= seatid then
		LOG_WARNING("player not in seat[%d]", seatid)
		return false
	end
	seats[p.seatid] = nil
	p.seatid = nil
	return true
end

function this.add_gold(p, gold, reason)
	p.gold = p.gold + gold
	if p.gold < 0 then
		p.gold = 0
	end
	send_to_all("game.UpdateGoldInGame", {uid=p.uid,goldadd=gold,gold=p.gold})
end

--接收客户端消息,player,cmd,msg
function this.dispatch(p, name, msg)
	--解散
	if name == "DissolveTable" then
		if game_status == 0 then
			if p.uid == owner then
				free_this_table(1001)
			end
		else
			client_dissolve_table_msg(p, msg)
		end
	end
	if game_status == 0 then
		if name == "SitdownNtf" then --坐下
			if isUseGold then
				LOG_WARNING("gold module can not sitdown")
				return
			end
			local seatid = tonumber(msg.seatid)
			if seatid > 0 and p.seatid == 0 and seats[seatid] == 0 then
				if uesr_cost(p) then
					seats[seatid] = p
					p.seatid = seatid
					p.ready = 0
					send_to_all("game.SitdownNtf", { uid = p.uid, seatid = seatid, nickname = p.nickname, headimg = "null" })
				else
					return "game.SitdownNtf", { uid = p.uid, seatid = -2 } --扣费失败
				end
			elseif seatid > 0 and p.seatid ~= 0 and seats[seatid] == 0 then
				if uesr_cost(p) then
					seats[p.seatid] = 0
					seats[seatid] = p
					p.seatid = seatid
					p.ready = 0
					send_to_all("game.SitdownNtf", { uid = p.uid, seatid = seatid, nickname = p.nickname, headimg = "null" })
				else
					return "game.SitdownNtf", { uid = p.uid, seatid = -2 } --扣费失败
				end
			end
		elseif name == "GetReadyNtf" or name == "StartNextGame" then --准备
			if not p.ready or p.ready == 0 then
				if p.seatid and p.seatid > 0 then
					if isUseGold then
						if checkjoin(p) then
							p.kick_timeout = nil
						else
							p:send_msg("game.GetReadyNtf", {uid = p.uid,seatid = -1})
							kick_player(p)
							LOG_WARNING("钱不够")
							return
						end
					end
					p.ready = 1
					nflag = true
					send_to_all("game.GetReadyNtf", { uid = p.uid, seatid = p.seatid })
					-- if checkAllReady() then this.game_start() end
					if checkAllReady() then game_restart() end
				end
			end
		end
	end
	if game_status == 2 then --叫分
		if name == "SetRate" then
			setUserRate(p, msg)
		elseif name == "LandTrusteeship" then
			p.trusteeship = msg.state
			if msg.state == 1 then
				next_status_time = os.time() + time_tuoguan
				send_to_all("game.LandTrusteeship", msg)
			else
				send_to_all("game.LandTrusteeship", msg)
			end
		end
	end
	if game_status == 3 then
		if name == "PlayCard" then --出牌
			if p.isrobot then
				this.cancel_to_play()
			else
				check_cards_to_play(p, msg)
			end
		elseif name == "LandTrusteeship" then
			p.trusteeship = msg.state
			if msg.state == 1 then
				next_status_time = os.time() + time_tuoguan
				send_to_all("game.LandTrusteeship", msg)
			else
				p.trusteeship_count = 0
				send_to_all("game.LandTrusteeship", msg)
			end
		end
	end
	if game_status == 4 then
		if name == "StartNextGame" then --准备
			p.ready2 = 1
			send_to_all("game.GetReadyNtf", { uid = p.uid, seatid = p.seatid })
			if checkRestart() then game_restart() end
		end
	end
	if name == "ChangeGroud" then --换地图
		-- p.params = {msg.desktop}
		tParams[p.uid][1] = msg.desktop or 1
	end
end

--设置概率
function this.set_kickback(kb,sysearn)
	if isUseGold then
		-- kickback是一个>0的数值，1表示不抽水也不放水，自然概率
		-- 例如0.98表示玩家的每次下注行为都抽水0.02
		-- 如果需要转化成0-100的数值，那么就是kickback*50，且大于100的时候取100
		-- LOG_DEBUG("收到kickback:"..kb)
		kickback = kb
	end
end

return this

