local land_deal = require "land_deal"
local land_build_cards = require "land_build_cards"
local cluster = require "skynet.cluster"
local skynet = require "skynet"
local os_time = os.time
local tinsert = table.insert
local tremove = table.remove
local tindexof = table.indexof

local player_cards = {}
local storage_flag = true
local cards_storage = {
    -- ["asdf"] = {1,1,2,3,3,1},
    -- ["sefs"] = {3,3,1,2,1,3},
    -- ["werw"] = {2,2,3,1,2,2}
}
local total_test_times = 0

local classic_landlord = {}
--客户端协议
local client = {}
--任务函数
local task = {}

--组合过的牌
local combined_cards = {
    -- hands = {}, --手牌
    -- bottom = {} --底牌
}

local gameid
local players
--游戏配置
local game_config
--游戏局数
local max_times = 0
--已玩局数
local played_times = 0
--基础倍率
local base_multi
--封顶炸弹数
local max_bomb
--全局控制概率
local kickback
local ctrlcost = 0
local ctrlearn = 0

--付费类型 1AA扣费 2房主扣费
local pay_type
--桌位号
local table_index
--房主
local owner
--当前玩家
local current_uid 
--是否金币模式
local isUseGold 
--是否比赛模式
local isMatch
--是否体验房
local isTaste

local seats = {
--	seatid = uid
}
--是否在游戏中
local has_start
--地主uid
local master
--最高叫分
local master_score = 0
--房间等待时间
local end_time
--第一个抢地主的座位id
local first_master_seatid
--随机到的第一个抢地主的玩家uid
local first_random_master
--是否在还可以抢地主
local is_mastering
local master_cards --地主三张底牌
local history

--每局结束后关闭结算界面的玩家数 当所有玩家都关闭时 则不等时间 直接开始先游戏
local re_ready_count = 0
--自动出牌最大次数 超过之后设为托管
local auto_out_max = 2
--托管后延迟出牌时间 秒
local TRUSTEESHIP_DELAY_TIME = 0
--解散超时
local DISSOLVE_TIME = 60
--解散冷却时间
local DISSOLVE_CD = 3 * 60
--是否解散
local dissolve_table
--没有人时超时解散
local no_one_free
--机器人加入时间
local time_join_robot
local has_robot

--当前出牌信息
local turn_info = {
	count = 1,		
	winner = 2,
	ctype = 3,
	cards = {}
}

--已同意解散房间的玩家
local consent_dissolve_players = {}
--已拒绝解散房间的玩家
local refuse_dissolve_players = {}
--解散超时 
local dissolve_timeout
--下次可解散的时间
local next_dissolve_time = 0

--游戏状态，
--0表示还在等人开始中,
--1发牌阶段,
--2抢地主阶段,
--3确定地主发底牌，
--4本局游戏结束判断阶段
--5本局游戏结束
--200整局游戏结束
local game_status
--切换到下个状态的时间(秒)
local next_status_time

----------------- table 层接口 --------------------
local table_api
---------------------------------------------------

--叫地主时间(秒)
local TIME_MASTER = 10
--出牌时间 
local TIME_OUTCARD = 15
--一局结束中间等待时间
local TIME_GAME_END = 10
--金币模式准备超时 秒
local KICK_TIMEOUT = 20

local cards = {}

--扑克数据
local static_cards = {
    101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113,
--   14,  15,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13 
    201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213,
    301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313,
    401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413,
    514, 515
--   16,  17
}

--洗牌
local function shuffle()
    discards = {}
    cards = {}
    local tmp = {
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
        14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26,
        27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
        40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52,
        53, 54
    }
    local index
    for i = 54, 1, -1 do
        index = tremove(tmp, math.random(i))
        tinsert(cards, static_cards[index])
    end
end

--检查玩家是否在游戏中
local function check_player_in_game( p )
    if p and p.seatid and p.seatid > 0 and p.ready and p.ready > 0 then
        return true
    end
    LOG_DEBUG("player[%d] is not in game", p.uid or -1)
end

local function free_table(reason)
    local total_info = {total = played_times, players = {},score = {}} 
    for uid, p in pairs(players or {}) do
        if check_player_in_game(p) then
            tinsert(total_info.players, p.nickname)
            tinsert(total_info.score, p.score)
        end
    end
    
    -- LOG_WARNING("free_table")
    -- LOG_WARNING(debug.traceback())
--    --PRINT_T(total_info)
    table_api.free_table(total_info, reason)
end

local function check_join_robot()

    if table.len(players) >= game_config.max_player then
        return
    end
    local ready_cnt = 0
    for k,v in pairs(players) do
        if v.ready and v.ready > 0 then
            ready_cnt = ready_cnt + 1
        end
    end
    --没有人准备则不加机器人
    if ready_cnt == 0 then
        return 
    end
    local now_time = skynet.now()
    if not time_join_robot then
        time_join_robot = now_time + math.random(50,100)
    elseif time_join_robot == 0 then
        time_join_robot = now_time + math.random(100,200)
    end
   
    if now_time >= time_join_robot then
        time_join_robot = 0 
        local gold = math.random(game_config.init_params.min_gold, game_config.init_params.min_gold*10)
        LOG_WARNING("min_gold %d  gold %d", game_config.init_params.min_gold, gold)
        table_api.join_robot("classic_landlord", gold)
    end
end

-- --发牌
-- local function add_cards(count)
--     local list, cardid
--     for uid, p in pairs(players) do
--         if check_player_in_game(p) then
--             p.cards = p.cards or {}
--             list = {}
--             for i = 1, count do
--                 cardid = tremove(cards)
--                 tinsert(list, cardid)
--                 tinsert(p.cards, cardid)
--             end
--             for u, v in pairs(players) do
--                 if u == uid then
--                     v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = count, cards = list })
--                 else
--                     v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = count })
--                 end
--             end
--         end
--     end
-- end

--返回值  0不控制 1玩家 2机器人
local function get_winner_by_kickback( ... )
    if isTaste then return 0 end
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
            tinsert(t, {uid=u.uid, level=u.ctrllevel, rate=u.ctrlrate})
        else
            local len = #t
            for i=1, #t do
                if u.ctrllevel > t[i].level then
                    tinsert(t, i, {uid=u.uid, level=u.ctrllevel, rate=u.ctrlrate})
                    break
                elseif u.ctrllevel == t[i].level then
                    if u.ctrlrate > t[i].rate then
                        tinsert(t, i, {uid=u.uid, level=u.ctrllevel, rate=u.ctrlrate})
                        break
                    elseif u.ctrlrate ==  t[i].rate then
                    --level 与 rate都相等的不控制了
                        tinsert(drop_uid, u.uid)
                        tinsert(drop_uid, t[i].uid)
                        break
                    end
                end
            end
            if len == #t then
                tinsert(t, {uid=u.uid, level=u.ctrllevel, rate=u.ctrlrate})
            end
        end
                
    end
    if not isTaste then
        for uid, p in pairs(players) do
            if p.ctrltype then
                if p.ctrltype == 1 then
                    deal_order(lose_player, p)
                elseif p.ctrltype == 2 then
                    deal_order(win_player, p)
                end
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
    for i,v in ipairs(win_player) do
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
    if len == game_config.max_player then
        --全是玩家的情况下不需要全局控制
        if has_robot then
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
    local cnt = 1
    -- local prior_uid
    -- local prior_cnt

    local orderd_uids = order_player_by_ctrldata()

    -- --胜率控制
    -- for uid, p in pairs(players) do
    --     if p.ctrl_cnt and p.ctrl_cnt > 50 then
    --         if not prior_uid then
    --             prior_uid = uid
    --             prior_cnt = p.ctrl_cnt
    --         else
    --             if p.ctrl_cnt > prior_cnt then
    --                 prior_uid = uid
    --                 prior_cnt = p.ctrl_cnt
    --             elseif p.ctrl_cnt == prior_cnt then
    --                 if math.random(100) <= 50 then
    --                     prior_uid = uid
    --                     prior_cnt = p.ctrl_cnt
    --                 end
    --             end
    --         end
    --     end
    -- end

    local tmp_cards = {}


    for _,uid in ipairs(orderd_uids) do
        assert(cnt < 4)
        local p = players[uid]
        if check_player_in_game(p) then
            p.cards = nil
            p.cards = tremove(combined_cards.hands, 1)
            cnt = cnt + 1
            for u, v in pairs(players) do
                if u == uid then
                    v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = 17, cards = p.cards })
                else
                    v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = 17 })
                end
            end
         --   --PRINT_T(p.cards)
        end
    end
    -- for uid, p in pairs(players) do
        
    --     if check_player_in_game(p) then
    --         p.cards = nil
    --         if prior_uid and prior_uid == uid then
    --             p.cards = tremove(combined_cards.hands, 1)
    --         else
    --             p.cards = tremove(combined_cards.hands)
    --         end
            
    --         cnt = cnt + 1
    --         for u, v in pairs(players) do
    --             if u == uid then
    --                 v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = 17, cards = p.cards })
    --             else
    --                 v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = 17 })
    --             end
    --         end
    --      --   --PRINT_T(p.cards)
    --     end
    -- end 
end

local function get_next_player(seatid)
	local nextseatid = seatid + 1
    if nextseatid > game_config.max_player then
        nextseatid = 1
    end
    return seats[nextseatid]
end

--春天判断 1春天 或反春
local function check_spring()
	if turn_info.winner == master then
		for uid, p in pairs(players) do
			if uid ~= master and p.outcount > 0 then
				return 
			end
		end
		return 1
	else
		if players[master].outcount == 1 then
            return 2
        end 
	end
	return 
end

local function get_total_bomb()
	local b = 0
	for _, p in pairs(players) do
		b = b + (p.bombcount or 0)
		p.total_bomb = p.total_bomb + (p.bombcount or 0)     -- 统计自己出的炸弹 客户端显示用
	end
	return b
end

local function kick_player(p, reason, win)
    seats[p.seatid] = nil
    p.seatid = nil
    table_api.kick(p, reason or 1005, win)
end

local function kick_all_player( ... )
    for k, v in pairs(players) do
        kick_player(v, 1010)
    end
end

local function excute_gold(uid, num)
    local p = players[uid]
    if not p then return end
    local opt = num > 0 and "add_gold" or "sub_gold"
--    LOG_WARNING("uid[%d] cmd[%s] num[%d]", uid, opt, num)
    p.gold = p.gold + num
    p.gold_change = (p.gold_change or 0) + num
    if p.gold < 0 then p.gold = 0 end
    --体验房数据不记录
    if isTaste then return end

    if not p.isrobot then
        local ok, result = pcall(p.call_userdata, p, opt, math.abs(num), gameid)
        if not ok then
            LOG_ERROR("player[%d] %s faild. num[%d], result[%s]", p.uid, opt, math.abs(num), tostring(result))
        end
    end 

    if has_robot and not p.isrobot then
        if num > 0 then
            ctrlearn = ctrlearn + num
        else
            ctrlcost = ctrlcost + math.abs(num)
        end
    end
end

local function robot_replace(p)
    --申请机器人接管
    local robot = table_api.get_robot("classic_landlord")
    robot.online = 1
    local init_info = {
        uid = p.uid,
        seatid = p.seatid,
        master = master,
        cards = p.cards,
        other = {}
    }
    for uid, player in pairs(players) do
        if uid ~= p.uid and player.ready and player.ready > 0 then
            tinsert(init_info.other, {uid=uid, seatid=player.seatid, cardnum=#player.cards})
        end
    end
   
    local ok, result = pcall(cluster.send, robot.agnode, robot.agaddr, "send_to_client", robot.uid, "server.init_replace_robot", init_info)
    if ok then
        p.replace_robot = robot
    else
        LOG_ERROR("send_msg error:"..tostring(result))
        LOG_ERROR("name:"..name..",node:"..tostring(self.agnode)..",addr="..tostring(self.agaddr))
    end
end

local function destroy_replace_robot(p)
    --销毁接管robot
    local robot = p.replace_robot
    if robot then
        local ok, result = pcall(cluster.send, robot.agnode, robot.agaddr, "send_to_client", robot.uid, "exit", {})
        if not ok then
            LOG_ERROR("send_msg error:"..tostring(result))
            LOG_ERROR("name:"..name..",node:"..tostring(self.agnode)..",addr="..tostring(self.agaddr))
        end
        p.replace_robot = nil
    end
end

-- --检查游戏结束时的任务
-- local function check_game_end_task()
--     task.add_friend()
-- end

--玩家托管 state 1托管 0取消托管
local function player_trusteeship(p, state)
    LOG_DEBUG("player[%d] trusteeship[%d]", p.uid, state)
    p.trusteeship = state
    if state == 1 then
        if isUseGold then
            robot_replace(p)
        end
    elseif state == 0 then
        p.auto_out_cnt = 0
        if isUseGold then
            destroy_replace_robot(p)
        end
    end
    table_api.send_to_all("game.LandTrusteeship", {uid = p.uid, state = state})
end

local function add_win(p)
    if isUseGold and not isTaste then
        p:call_userdata("add_win", gameid, 1001)
    end
end

-- local function deal_end(spring, bomb, master_win)
--     LOG_DEBUG("!!! game end masterwin[%s]", tostring(master_win))
-- 	local result = {info = {}, cards = {}}
--     local end_rst = {players = {}, score = {}}
--     spring = spring and 1 or 0
-- 	for uid, p in pairs(players) do
-- 		if check_player_in_game(p) then
-- 			local add_score = 0
-- 			if master_win then
-- 				if uid == master then
--                     if spring then p.spring_cnt = (p.spring_cnt or 0) + 1 end
-- 					add_score = 2
--                     p.win_count = p.win_count + 1
--                     p.round_win = 1
--                     add_win(p)
-- 				else
-- 					add_score = -1
--                     p.lose_count = p.lose_count + 1
-- 				end
-- 			else
-- 				if uid == master then
-- 					add_score = -2
-- 					p.lose_count = p.lose_count + 1
-- 				else
--                     if spring then p.spring_cnt = (p.spring_cnt or 0) + 1 end
-- 					add_score = 1
--                     p.win_count = p.win_count + 1
--                     p.round_win = 1
--                     add_win(p)
-- 				end
-- 			end
            
--             local bomb_multi = (spring + bomb > max_bomb) and max_bomb or (spring + bomb)
-- 			add_score = add_score * base_multi * master_score * (2^(bomb_multi))

-- 			p.add_score = add_score
--             p.max_score = (p.add_score or 0) > p.max_score and p.add_score or p.max_score
--             if isUseGold then
--                 if add_score ~= 0 then
--                     excute_gold(p, add_score)
--                 end
--                 p.score = p.gold
--             else
--                 p.score = p.score + p.add_score
--             end
            
--             tinsert(result.info, p.uid)
--             tinsert(result.info, #p.cards)
--             tinsert(result.info, p.bombcount)
--             tinsert(result.info, p.add_score)
--             tinsert(result.info, p.score)
--             result.cards = table.arraycopy(p.cards)

--             tinsert(end_rst.players, p.nickname)
--             tinsert(end_rst.score, p.add_score)

--             p.add_score = 0
-- 		end
-- 	end
   
-- 	return result, end_rst
-- end

local function deal_end(spring, bomb, master_win)
    LOG_DEBUG("!!! game end masterwin[%s]", tostring(master_win))
    local result = {info = {}, cards = {}}
    local end_rst = {players = {}, score = {}}
    local winners = {}
    local losers = {}
    spring = spring and 1 or 0
--    --PRINT_T(players)
--    --PRINT_T(spring)
    for uid, p in pairs(players) do
        if check_player_in_game(p) then
            local add_score = 0
            if master_win then
                if uid == master then
                    if spring > 0 then p.spring_cnt = (p.spring_cnt or 0) + 1 end
                    add_score = 2
                    p.win_count = p.win_count + 1
                    p.round_win = 1
                    add_win(p)
                else
                    add_score = -1
                    p.lose_count = p.lose_count + 1
                end
            else
                if uid == master then
                    add_score = -2
                    p.lose_count = p.lose_count + 1
                else
                    if spring > 0 then p.spring_cnt = (p.spring_cnt or 0) + 1 end
                    add_score = 1
                    p.win_count = p.win_count + 1
                    p.round_win = 1
                    add_win(p)
                end
            end
            
            local bomb_multi = (spring + bomb > max_bomb) and max_bomb or (spring + bomb)
            add_score = add_score * base_multi * master_score * (2^(bomb_multi))
            p.max_score = (add_score or 0) > p.max_score and add_score or p.max_score
            if true then
                if add_score > 0 then
                     winners[uid] = p.gold >= add_score and add_score or p.gold
                else
                    add_score = math.abs(add_score)
                    losers[uid] = add_score >= p.gold and p.gold or add_score
                end
            end
            p.add_score = add_score
        end
    end
    -- --PRINT_T(winners)
    -- --PRINT_T(losers)
    if true then
        local total_win = 0
        local total_lose = 0
        for uid,num in pairs(winners) do
            total_win = total_win + num
        end
        for uid,num in pairs(losers) do
            total_lose = total_lose + num
        end
        if total_win > total_lose then
            total_win = total_lose
            local len = table.len(winners)
            local per_win = math.floor(total_win/len)
            for uid,num in pairs(winners) do
                if num >= per_win then
                    winners[uid] = per_win
                end
                
            end
        elseif total_win < total_lose then
            total_lose = total_win
            local len = table.len(losers)
            local per_lose = math.ceil(total_lose / len)
            total_lose = 0
            for uid, num in pairs(losers) do
                if num >= per_lose then
                    losers[uid] = per_lose
                end
                total_lose = total_lose + losers[uid]
            end
            len = table.len(winners)
            local per_win = math.floor(total_lose/len)
            for uid,num in pairs(winners) do
                winners[uid] = per_win
            end
        end
        if isUseGold then
            for uid, num in pairs(winners) do
                excute_gold(uid, num)
            end
            for uid, num in pairs(losers) do
                excute_gold(uid, 0-num)
            end
        end
        
    end
    
    for uid,num in pairs(losers) do
        winners[uid] = 0-num
    end
    --PRINT_T(winners)
    for uid, num in pairs(winners) do
        local p = players[uid]
        if isUseGold then
            p.score = p.gold
        else
            p.score = p.score + num
        end
        local add_score = num
        tinsert(result.info, p.uid)
        tinsert(result.info, #p.cards)
        tinsert(result.info, p.bombcount)
        tinsert(result.info, add_score)
        tinsert(result.info, p.score)
        table.join(result.cards, p.cards)

        tinsert(end_rst.players, p.nickname)
        tinsert(end_rst.score, add_score)
        p.add_score = 0
    end
  
    return result, end_rst
end

local function game_end(master_win)
	game_status = 501

	local spring = check_spring()
	local bomb_count = get_total_bomb()
	local result, end_rst = deal_end(spring, bomb_count, master_win)
    --PRINT_T(result)
    --PRINT_T(end_rst)
	table_api.send_to_all("game.GameResult", { master = master, count = 3, infos = result.info, cards = result.cards, spring = spring})
	histroy.recording = histroy.recording or {}
    if isUseGold then
        game_status = 0
        has_start = false
        
        for uid, p in pairs(players) do
            if p.seatid and p.seatid > 0 then
                if p.isrobot then
                    if p.win_count > 5 or p.gold < game_config.init_params.min_gold then
                    --    table_api.kick(p, 1007)
                        kick_player(p, 1007)
                    end
                else
                    p.kick_timeout = os_time() + KICK_TIMEOUT
                    --金币模式每局开始需要重新准备，所以在游戏开始后清掉准备状态
                    p.ready = 0
                end
                if isMatch and p.seatid then
                    kick_player(p, 1009, p.win_count > 0)
                end 
            end
        end
        if isMatch then
            free_table(1002)
        end
    elseif isMatch then
        for uid, p in pairs(players) do
            if p.seatid and p.seatid > 0 then
                kick_player(p, 1009, p.win_count > 0)
            end
        end
        free_table(1002)
    else
        next_status_time = os_time() + TIME_GAME_END
        played_times = played_times + 1
        local rst = {index = played_times, players = end_rst.players, score = end_rst.score}
       
        table_api.game_end(rst)
    end
    --清楚托管状态
    for uid, p in pairs(players) do
        player_trusteeship(p, 0)
    end

 --   check_game_end_task()
    has_robot = nil
    game_status = 5
    
end

--是否队友
local function is_teammate()
    if master and master > 0 and (current_uid == master or (turn_info.winner and turn_info.winner == master)) then
        return false
    end
    return true
end

--是否托管
local function is_trusteeship(p)
    return p.trusteeship and p.trusteeship > 0
end

local function write_to_file()
    if not next(player_cards) then return end
    local ss = ""
    for _, t in ipairs(player_cards) do
        local winid = t[555]
        t[555] = nil
        for k,v in pairs(t) do
            local str = string.format("[%s]=[%s]", tostring(k), table.concat(v, ","))
            ss = ss..str.."\n"
        end
        ss = ss..string.format("master is [%s] winner is [%s]", tostring(master), tostring(winid)).."\n"
        ss = ss.."--------------------------------------------------------------------------------------\n"
    end
    local file = io.open("20180314.txt", "a")
    if not file then
        LOG_ERROR("open file error")
    else
        file:write(ss)
        file:close()
        table.clear(player_cards)
      --  assert(false)
    end
end

local function out_card( p, outcards, client_type, is_auto )
	if #p.cards < #outcards then
		LOG_ERROR("illegal opt! user[%d] cards num[%d] less than outcards num[%d]. is_auto[%s]", 
			p.uid, #p.cards, #outcards, tostring(is_auto))
		return
	end

	local card_type = land_deal.getCardType(outcards)
	if not is_auto and (not client_type or client_type ~= card_type or card_type == land_deal.CT_ERROR) then
		LOG_DEBUG("player[%d] out card faild clienttype[%d] servertype[%d]", 
			p.uid, client_card_type or -1, cardtype or -1)
		return 
	end

	--对比扑克
    if turn_info.count > 0 then
        if land_deal.compareCard(turn_info.cards, outcards, turn_info.count) == false then 
            LOG_DEBUG("player[%d] out card faild illegal outcards", p.uid)
            return 
        end
    end

    --删除扑克
    if not land_deal.removeCards(outcards, p.cards) then 
        LOG_WARNING("removeCards error")
        return 
    end
    p.outcount = p.outcount + 1
    turn_info.winner = p.uid
    if card_type == land_deal.CT_BOMB_CARD or card_type == land_deal.CT_MISSILE_CARD then
        p.bombcount = p.bombcount + 1
    end
    table_api.send_to_all("game.PlayCard", { uid = p.uid, cards = outcards, cardtype = card_type })
    if #p.cards == 0 then
--        LOG_WARNING("game_end winner is %s", p.nickname)
    	game_end(p.uid == master)
    else
    	-- if card_type ~= land_deal.CT_MISSILE_CARD then
    	-- 	current_uid = get_next_player(p.seatid)
    	-- 	turn_info.count = #outcards
		   --  turn_info.cards = outcards
		   --  turn_info.ctype = card_type
    	-- else
    	-- 	turn_info.count = 0
		   --  turn_info.cards = {}
		   --  turn_info.ctype = 0
    	-- end
        current_uid = get_next_player(p.seatid)
        turn_info.count = #outcards
        turn_info.cards = outcards
        turn_info.ctype = card_type
    	next_status_time = os_time() + TIME_OUTCARD
        LOG_DEBUG("======   ask player[%d] to play card", current_uid)
--        --PRINT_T(turn_info)
        local cur_player = players[current_uid]
    	table_api.send_to_all("game.AskPlayCard", { 
    				seatid = cur_player.seatid, 
    				time = is_trusteeship(cur_player) and TRUSTEESHIP_DELAY_TIME or TIME_OUTCARD, 
    				cardtype = turn_info.ctype, 
    				cards = turn_info.cards })
    end 
end

local function pass_card(uid)
	if turn_info.ctype == 0 then
        LOG_DEBUG("赢家不能pass")
        return
    end
    local p = players[uid]
    current_uid = get_next_player(p.seatid)
    LOG_DEBUG("=========  current_uid[%d], turn_winer[%d]", current_uid, turn_info.winner)
    if current_uid == turn_info.winner then
        turn_info.count = 0
        turn_info.ctype = 0
        turn_info.cards = {}
    end
    p = players[current_uid]
    next_status_time = os_time() + TIME_OUTCARD
    LOG_DEBUG("==========  [%d] pass", uid)
    table_api.send_to_all("game.PlayCard", { uid = uid, cards = {} })

    table_api.send_to_all("game.AskPlayCard", 
    	{seatid = p.seatid, 
    	time = is_trusteeship(p) and TRUSTEESHIP_DELAY_TIME or TIME_OUTCARD, 
    	cardtype = turn_info.ctype, 
    	cards = turn_info.cards})
end

--超时代打
local function auto_out()
--    game_status = 103
    local p = players[current_uid]

    --农民需要考虑队友
    local teammate = is_teammate()

    local outcards = land_deal.searchCards(p.cards, turn_info.cards, teammate)
  
 --   -- --PRINT_T(outcards, current_uid)
    if #outcards > 0 then
        out_card(p, outcards, nil, 1)
    else
        pass_card(current_uid)
    end
    if not p.isrobot then
        p.auto_out_cnt = p.auto_out_cnt + 1
    end
    
--    LOG_WARNING("p.auto_out_cnt[%d]", p.auto_out_cnt)
    if p.auto_out_cnt >= auto_out_max and not is_trusteeship(p) then
        player_trusteeship(p, 1)
    end
--    -- --PRINT_T(p.cards, "remain cards")
end

local function set_master()
	LOG_DEBUG(master .. "叫到了庄")
    players[master].master_cnt = (players[master].master_cnt or 0) + 1
    table_api.send_to_all("game.SetMaster", { uid = master, score = master_score })
end

--发底牌
local function add_master_cards()
    local p = players[master]
    local list = {}
    local cardid
    -- for i = 1, 3 do
    --     cardid = tremove(cards)
    --     tinsert(list, cardid)
    --     tinsert(p.cards, cardid)
    -- end

    for i = 1, 3 do
        cardid = combined_cards.bottom[i]
        tinsert(list, cardid)
        tinsert(p.cards, cardid)
    end
    master_cards = list
    table_api.send_to_all("game.AddCard", { uid = p.uid, seatid = p.seatid, count = 3, cards = list })
end

--开始出牌了
local function start_play()
    current_uid = master
    turn_info.winner = master
    turn_info.count = 0
    turn_info.ctype = 0
    turn_info.cards = {}

    for uid, p in pairs(players) do
        p.outcount = 0 --出牌数目
        p.bombcount = 0 --炸弹数目
    end

    game_status = 3
    next_status_time = os_time() + TIME_OUTCARD + 5

    table_api.send_to_all("game.AskPlayCard", { seatid = players[current_uid].seatid, time = TIME_OUTCARD + 5, cardtype = 0, cards = {} })
end

--随机第一个叫地主玩家
local function get_first_master()
    first_random_master = nil
    master = 0
    master_score = 0
    local uidlist = {}
    for uid, p in pairs(players) do
        if check_player_in_game(p) then
            tinsert(uidlist, uid)
        end
    end
    local first_uid = uidlist[math.random(#uidlist)]
    LOG_DEBUG("=======  first master uid:"..first_uid)
    first_random_master = first_uid
    return first_uid
end

--开始游戏
local function new_game()
    table_api.send_to_all("game.StartRound", { round = played_times + 1, total = max_times })
	game_status = 1
    is_mastering = true
    first_master_seatid = nil
    re_ready_count = 0
    
--    shuffle() --洗牌
    combined_cards.hands, combined_cards.bottom = land_build_cards.build_land_cards(isUseGold)

    for uid, p in pairs(players) do
        if p.ready == 1 then
            p.cards = nil
            p.round_win = 0
            p.gold_change = 0
            if p.isrobot and not has_robot then
                has_robot = true
            end
        end
     --   player_trusteeship(p, 0)
    end
 --   add_cards(17) --发17张牌
    add_combined_cards()
    for uid, p in pairs(players) do
        p.can_master = true --能否叫/抢地主
        p.re_ready = 0
        p.auto_out_cnt = 0
    end
    current_uid = get_first_master()
    if game_config.init_params.master_type == 1 then
        --抢地主
        local current_player = players[current_uid]
        LOG_DEBUG("===== send AskMaster to [%d]", current_uid)
        table_api.send_to_all("game.AskMaster", { time = TIME_MASTER, seatid = players[current_uid].seatid, opt = 1 })
     --   table_api.send_to_all("game.AskMaster", { time = TIME_MASTER, seatid = players[first_uid].seatid, opt = 1 })
    elseif game_config.init_params.master_type == 2 then
        --叫分
        table_api.send_to_all("game.AskRate", { time = TIME_MASTER, seatid = players[current_uid].seatid, opt = 0 })
    end
	game_status = 2
    
    next_status_time = os_time() + TIME_MASTER
end

local function check_master()
    LOG_DEBUG("check_master master_score[%d], master[%d]", master_score or -1, master or -1)
    if no_master == 2 and (master_score<= 0 or master <= 0) then
        master_score = 1
        master = first_random_master
        no_master = 0
    end
	if master_score > 0 and master > 0 then
        --设置地主
        set_master()
        --发底牌
        add_master_cards()
--         if test_cards_storage then
-- --            --PRINT_T(players)
--             for uid, p in pairs(players) do
--                 LOG_WARNING("%s cards[%s]", p.nickname, table.concat(p.cards, ","))
--             end
--        --     skynet.sleep(500)
--         end
        --开始
        start_play()
    else
        --没人抢地主
        no_master = (no_master or 0) + 1
        new_game()
    end
end

local function get_next_master( seatid )
    if not is_mastering then
        return
    end
    local nextseatid = seatid + 1
    if nextseatid > game_config.max_player then
        nextseatid = 1
    end
   
    local user = players[seats[nextseatid]]
    if user.can_master then
        return nextseatid
    else
        if user.uid == master or master == 0 then
            return
        end
        if nextseatid == first_master_seatid then
            is_mastering = false
            return nextseatid
        end
        return get_next_master( nextseatid )
    end

    -- while true do

    --  if seats[nextseatid].can_master then
    --         break
    --     end
    --  if not seats[nextseatid].can_master then
    --      if nextseatid == seatid or (first_master and first_master == nextseatid) then break end
    --      nextseatid = (nextseatid + 1) <= game_config.max_player and (nextseatid + 1) or 1
    --  end
    -- end

    -- if nextseatid == seatid or (master > 0 and players[master].seatid == nextseatid) then
    --     return 0
    -- else
    --     return nextseatid
    -- end
end

--放弃叫地主
local function giveup_master()
	local p = players[current_uid]
	if not p then
		return
	end

	p.can_master = false
    if game_config.init_params.master_type == 1 then
        table_api.send_to_all("game.GetMaster", { result = 0, uid = p.uid })
    else
        table_api.send_to_all("game.SetRate", { rate = 0, uid = p.uid })
    end
    local next_ask_master = get_next_master(p.seatid)

    if next_ask_master then
    	current_uid = seats[next_ask_master]
        local cur_player = players[current_uid]
        
        next_status_time = os_time() + TIME_MASTER
        if game_config.init_params.master_type == 1 then
        	LOG_DEBUG("===== send AskMaster to [%d]", current_uid)
        	table_api.send_to_all("game.AskMaster", { time = TIME_MASTER, seatid = next_ask_master, opt = (master_score == 0 and 1 or 2) })
        --    table_api.send_to_all("game.AskMaster", { time = TIME_MASTER, seatid = next_ask_master, opt = (masterscore == 0 and 1 or 2) })
        else
            table_api.send_to_all("game.AskRate", { time = TIME_MASTER, seatid = next_ask_master, opt = master_score })
        end
    else
        check_master()
    end
end

--开始游戏
local function game_start()
    if hasstart then return end
    has_start = true
    played_times = 0
    table_api.game_start()
    
    table_api.send_to_all("game.GameStart", {})
    new_game()
end

local function check_start()
	if has_start then return end
    LOG_DEBUG("检查游戏是否能开始")
    local readyCount = 0
    for uid, p in pairs(players) do
        if check_player_in_game(p) then
            readyCount = readyCount + 1
        end
    end
    LOG_DEBUG("准备的玩家个数:" .. readyCount)
    if readyCount >= game_config.min_player and readyCount <= game_config.max_player then
        game_start()
    end
end



local function game_stop()
    game_status = 200
    LOG_DEBUG("游戏结束了！！！")

    -- histroy.endtime = os_time()
    -- histroy.players = histroy.players or {}
    --PRINT_T(players)
    local info
    local infos = {}
    for uid, p in pairs(players) do
        if check_player_in_game(p) then
            info = {
                uid = p.uid,
                nickname = p.nickname,
                wincount = p.win_count ,
                losecount = p.lose_count,
                totalscore = p.score,
                maxscore = p.max_score,
                bombcount = p.total_bomb,
                springcount = p.spring_cnt or 0,
                mastercount = p.master_cnt or 0,
            }
            
            tinsert(infos, info)
        end
    end
    --PRINT_T(infos)
    table_api.send_to_all("game.GameLandlordEnd", { round = played_times, infos = infos })
    free_table(1002)
end

local function check_start_or_stop()
    if played_times >= max_times or dissolve_table then
        game_stop()
    else
        new_game()
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
    table_api.send_to_all("game.PushDissolveTable", {result = 2})
    game_status = 5
    local users = {}
    local scores = {}
    for uid, p in pairs(players) do
        if check_player_in_game(p) then
            tinsert(users, p.nickname)
            tinsert(scores, 0)
        end
    end

    local rst = {index = played_times + 1, players = users, score = scores}
    table_api.game_end(rst)
    
    dissolve_table = true
end

local function dissolve_table_faild()
    reset_dissolve_data(1)
    table_api.send_to_all("game.PushDissolveTable", {result = 3})
end

--检查房间的解散状态
local function check_dissolve_table()
    if dissolve_timeout then
        if #consent_dissolve_players >= game_config.max_player or os_time() >= dissolve_timeout then
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
    local push_client
    if not next(consent_dissolve_players) then
        dissolve_timeout = now_time + DISSOLVE_TIME
        remaintime = DISSOLVE_TIME
        push_client = true
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
        push_client = true
    end

    for uid, player in pairs(players) do
        if check_player_in_game(player) then
            if not player.online or player.online == 0 then
                if not tindexof(consent_dissolve_players, player.uid) and not tindexof(refuse_dissolve_players, player.uid) then
                    tinsert(consent_dissolve_players, uid)
                    push_client = true
                end
            end
        end
    end

    if push_client then
        table_api.send_to_all("game.PushDissolveTable", { result = 1,
                                                    consentUid = consent_dissolve_players, 
                                                    refuseUid = refuse_dissolve_players,
                                                    remaintime = remaintime})
    end
end

--拒绝解散
local function refuse_dissolve_table(p)
    if dissolve_timeout and not tindexof(refuse_dissolve_players, p.uid) then
        tinsert(refuse_dissolve_players, p.uid)
        table_api.send_to_all("game.PushDissolveTable", { consentUid = consent_dissolve_players, 
                                                    refuseUid = refuse_dissolve_players,
                                                    remaintime = remaintime})
    end
end

--金币场入场条件
local function gold_check(p)
    return p.gold >= game_config.init_params.min_gold
end

--金币模式自动坐下
local function auto_sitdown(p)
    if p.seatid and p.seatid > 0 then
        LOG_WARNING("player[%d] is already sitdown seatid[%d]", p.uid, p.seatid)
        return
    end
    for i=1,game_config.max_player do
        if not seats[i] then
            seats[i] = p.uid
            p.seatid = i
            if not owner then
                owner = p.uid
            end
            LOG_DEBUG("auto sit down success")
            p.kick_timeout = os_time() + KICK_TIMEOUT
            table_api.send_to_all("game.SitdownNtf", { uid = p.uid, seatid = i, nickname = p.nickname, headimg = p.headimg or "" })
            break
        end
    end
    assert(p.seatid and p.seatid > 0, "not enough seatid")
end

--踢掉超时未准备的玩家
local function check_kick_players()
    local now_time = os_time()
    for uid, p in pairs(players) do
        if (not p.ready or p.ready == 0) and p.kick_timeout and now_time > p.kick_timeout then
            kick_player(p)
        end
    end
end

--更换桌面背景
function client.ChangeGroud(p, msg)
    p.params = {msg.desktop}
end

function client.SitdownNtf( p, msg )
    if isUseGold then
        LOG_WARNING("gold module can not sitdown")
        return 
    end
	local seatid = tonumber(msg.seatid)
    
    if has_start then
        LOG_DEBUG("game is start. cannot change seat")
        return 
    end

	if not seatid or seatid < 1 or seatid > game_config.max_player or seats[seatid] then
		LOG_ERROR("player[%d] sit down faild", p.uid)
		return
	end
	
	--AA制坐下就扣费
	-- if not p.hascost and pay_type == 1 then
	-- 	local cost = game_config.price[pay_type]
	-- 	if not cost then
	-- 		LOG_ERROR("it must be have price")
 --            return "game.SitdownNtf", { uid = p.uid, seatid = -1 }
	-- 	end
	-- 	local ok, result = pcall(p.call_userdata, p, "sub_gold", cost, gameid)
 --        if not ok or not result then
 --            LOG_ERROR("sub gold faild")
 --            return "game.SitdownNtf", { uid = p.uid, seatid = -1 }
 --        end
 --        LOG_DEBUG("player[%d] sitdown and sub_gold[%d]", p.uid, cost)
 --        p.hascost = true
	-- end

    if p.seatid and p.seatid > 0 then
        seats[p.seatid] = nil
        p.ready = 0
    end
	--注意顺序 扣钱之后才能坐下
	seats[seatid] = p.uid
    p.seatid = seatid

	if not owner then
		owner = p.uid
	end
    return true
 --   --PRINT_T(p)
--	LOG_DEBUG("sit down success")
 --   table_api.send_to_all("game.SitdownNtf", { uid = p.uid, seatid = seatid, nickname = p.nickname, headimg = p.headimg or "" })
end

function client.GetReadyNtf( p, msg )
	--游戏开始之后，玩家坐下就准备了
--    --PRINT_T(has_start)
--    --PRINT_T(p)
	if has_start then return end 
    if not p.ready or p.ready == 0 then
        if p.seatid and p.seatid > 0 then
            if isUseGold then
                if not gold_check(p) then
                    LOG_WARNING("player[%d] ready faild,not enough gold", p.uid)
                    return 
                end
                p.kick_timeout = nil
            end
            p.ready = 1
            LOG_DEBUG("player[%d] get ready", p.uid)
            table_api.send_to_all("game.GetReadyNtf", { uid = p.uid, seatid = p.seatid })
            check_start()
        end
    end
end

--叫地主
function client.GetMaster( p, msg )
    LOG_DEBUG("gametype[%d], status[%d], has_start[%s], seatid[%d], ready[%d], can_master[%s], uid[%d], first_master[%d], curruid[%d]",
        game_config.init_params.master_type, game_status, tostring(has_start), p.seatid or -1, p.ready or -1, tostring(can_master), p.uid, first_master_seatid or -1, current_uid or -1)
	if game_config.init_params.master_type ~= 1 or game_status ~= 2 or not has_start or 
	   not p.seatid or not p.ready or p.ready == 0 or (not p.can_master and p.seatid ~= first_master_seatid) or p.uid ~= current_uid then
	    LOG_ERROR("player[%d] get master faild", p.uid)
	    return 
	end

	if msg.result > 0 then
		master = p.uid
        master_score = (master_score == 0 and 1 or master_score * 2)
        if not first_master_seatid  then
            first_master_seatid = p.seatid
        end
	end
--	game_status = 102
	p.can_master = false
	table_api.send_to_all("game.GetMaster", { result = msg.result, uid = p.uid })

	local next_ask_master = get_next_master(p.seatid)
    LOG_DEBUG("cur seatid[%d] next[%d]", p.seatid, next_ask_master or -1)
	if next_ask_master then
	--	game_status = 2
		current_uid = seats[next_ask_master]
		local userinfo = players[current_uid]
		next_status_time = os_time() + TIME_MASTER
		LOG_DEBUG("===== send AskMaster to [%d]", current_uid)
		local opt 
		if master then opt = 1 else opt = 2 end
        table_api.send_to_all("game.AskMaster", {time = TIME_MASTER, seatid = next_ask_master, opt = opt})
	else
		check_master()
	end
end

--叫分
function client.SetRate( p, msg )
	if game_config.init_params.master_type ~= 2 or game_status ~= 2 or not has_start or 
	   not p.seatid or not p.ready or p.ready == 0 or not p.can_master or p.uid ~= current_uid then
	    LOG_ERROR("player[%d] get master faild", p.uid)
	    return 
	end

	if msg.rate > 3 or msg.rate < 0 or (master_score > 0 and msg.rate <= master_score) then
		LOG_ERROR("player[%d] get master faild msg.rate[%s] master_score[%s]", p.uid, tostring(msg.rate), tostring(master_score))
	    return 
	end
--	game_status = 102
	p.can_master = false

	if msg.rate > master_score then
        master_score = msg.rate
        master = p.uid
    end
    table_api.send_to_all("game.SetRate", { rate = msg.rate, uid = p.uid })

    if master_score == 3 then
        check_master()
    else
        local next_ask_master = get_next_master(p.seatid)
        if next_ask_master then
            current_uid = seats[next_ask_master]
        --    game_status = 2
            next_status_time = os_time() + TIME_MASTER
            table_api.send_to_all("game.AskRate", { time = TIME_MASTER, seatid = next_ask_master, opt = master_score })
        else
            check_master()
        end
    end
end

function client.PlayCard( p, msg )
	if game_status ~= 3 or not has_start or not p.seatid or p.seatid < 1 or not p.ready or p.ready ==0 then
		LOG_ERROR("illegal msg from player[%d]", p.uid)
		return 
	end

	if p.uid ~= current_uid then
		LOG_DEBUG("[%d]playcard faild, current_uid[%d]", p.uid, current_uid)
		return
	end
--	game_status = 103
--    LOG_WARNING("%s PlayCard", p.nickname)
	if msg.cards and #msg.cards > 0 then
		out_card(p, msg.cards, msg.cardtype)
	-- elseif p.isrobot then
	-- 	auto_out()
	else
        pass_card(p.uid)
    end
end

function client.StartNextGame(p)
    if not has_start or game_status ~= 5 then return end
    if check_player_in_game(p) and p.re_ready and p.re_ready == 0 then
        p.re_ready = 1
        re_ready_count = re_ready_count + 1
        table_api.send_to_all("game.GetReadyNtf", { uid = p.uid, seatid = p.seatid })
        if re_ready_count == 3 then
            check_start_or_stop()
        end
    end
end

function client.LandTrusteeship(p, msg)
    if check_player_in_game(p) then
        if not is_trusteeship(p) or (p.trusteeship ~= msg.state) then
            player_trusteeship(p, msg.state)
        end 
    end
end

function client.DissolveTable( p,msg )
    --游戏开始后需要所有玩家同意才可以解散
    if has_start then
        if check_player_in_game(p) then
            local now_time = os_time()
            if now_time < next_dissolve_time then
                p:send_msg("game.PushDissolveTable", {result = 4, remaintime = next_dissolve_time-now_time})
                return
            end
            if msg.opt == 1 then
                consent_dissolve_table(p)
            elseif msg.opt == 2 then
                refuse_dissolve_table(p)  
            end
        end
    else
        --游戏没开始只能房主解散
        if p.uid == owner then
            free_table(1001)
        end
    end
end

local function report_gold_info()
    if not isUseGold then return end
    while true do 
        if ctrlcost > 0 or ctrlearn > 0 then
            -- CMD.report(addr, gameid, usercost, userearn)
            --LOG_DEBUG("上报数据:cost="..ctrlcost..",earn="..ctrlearn)
            table_api.report_gold(ctrlcost, ctrlearn)
            ctrlcost = 0
            ctrlearn = 0
        end
        skynet.sleep(5*100)
    end
end

-- ---------------------------------- task 函数 ---------------------------
-- function task.add_friend()
--     for uid, p in pairs(players) do
--         if not p.isrobot and p.round_win and p.round_win > 0 then
--             local ok, result = pcall(p.call_userdata, p, "task_add_friend", "add_friend", nil, 1)
--             if not ok then
--                 LOG_WARNING("exec task_add_friend faild")
--             end
--         end
--     end
-- end

local function send_sitdown(p)
    auto_sitdown(p)
end

--是否全是机器人
local function all_robot()
    if not next(players) then return false end
    for k, v in pairs(players) do
        if not v.isrobot then
            return false
        end
    end

    return true
end


function classic_landlord.set_kickback( kb )
    if isUseGold and not isTaste then
        LOG_DEBUG("set kickback[%s]", tostring(kb))
        kickback = kb
    end
end

function classic_landlord.sitdown(p, seatid)
    if isUseGold then
        LOG_WARNING("gold module can not sitdown")
        return 
    end
    local seatid = tonumber(seatid)
    
    if has_start then
        LOG_DEBUG("game is start. cannot change seat")
        return 
    end

    if not seatid or seatid < 1 or seatid > game_config.max_player then
        LOG_ERROR("player[%d] sit down faild", p.uid)
        return
    end

    if p.seatid and p.seatid > 0 then
        seats[p.seatid] = nil
        p.ready = 0
    end
   
    seats[seatid] = p.uid
    p.seatid = seatid

    if not owner then
        owner = p.uid
    end
    return true
end

function classic_landlord.standup(p, seatid)
    if isUseGold then
        LOG_WARNING("gold module can not sitdown")
        return 
    end
    local seatid = tonumber(seatid)
    
    if has_start then
        LOG_WARNING("game is start. cannot change seat")
        return 
    end

    if not seatid or seatid < 1 or seatid > game_config.max_player then
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

function classic_landlord.add_gold(p, gold, reason)
    p.gold = p.gold + gold
    if p.gold < 0 then
        p.gold = 0
    end
    table_api.send_to_all("game.UpdateGoldInGame", { uid = p.uid, goldadd = gold, gold = p.gold })
end

--游戏外部强制解散
function classic_landlord.dissolve_table()

    if has_start then
        dissolve_table_success()
    else
        free_table(1001)
    end
end

function classic_landlord.free(p)
	seats = nil
	turn_info = nil
	master_cards = nil
	histroy = nil
	game_config = nil
	players = nil
	cards = nil
end

function classic_landlord.join(p)
    --体验房
    if isTaste then
        if not has_start then
            p.gold = game_config.test_gold
        end
    end
    --金币场入场条件
    if isUseGold then
        if not game_config.init_params.min_gold then
            LOG_ERROR("lack min_gold in game[%d] conf", gameid)
            return 
        end
        if not gold_check(p) then
            LOG_WARNING("not enough gold to join game[%d] need[%d] cur gold[%d]", gameid, game_config.init_params.min_gold, p.gold)
            return 
        end
    --    LOG_WARNING("player[%d] join game gold[%d]", p.uid, p.gold)
    end

	p.total_bomb = 0      --炸弹总数
    p.win_count = 0       --胜局数
    p.lose_count = 0      --败局数
    p.max_score = 0        --最高得分
    -- if isUseGold then
    --     auto_sitdown(p)
    -- end
    -------------------------------- 测试用 -------------------------
    -- LOG_WARNING("add gold for test")
    -- p:call_userdata("add_gold", p.uid, 10000000, gameid)
    -----------------------------------------------------------------
    return true
end

function classic_landlord.update(p)
    --当桌子没有人时解散
    if all_robot() then
        -- if not no_one_free then
        --     no_one_free = os_time() + 2
        -- elseif os_time() > no_one_free then
        --     LOG_DEBUG("there is nobody in table, free it!")
        --     free_table(1001)
        -- end
        kick_all_player()
        return
    end
	local now_time = os_time()
	if end_time and now_time > end_time and not has_start then
		free_table(1001)
		return
	end

    if has_start then
        check_dissolve_table()
    else
        if game_config.add_robot then
            check_join_robot()
        end
        if isUseGold then 
--            --PRINT_T(players)
            check_kick_players()
        end
    end

	if has_start and next_status_time and next_status_time > 0 then
		--抢地主阶段
		if game_status == 2 then
			if now_time >= next_status_time then
				giveup_master()
			end
		--出牌阶段
		elseif game_status == 3 then
			-- 出牌阶段
            local p = players[current_uid]
            if is_trusteeship(p) and not isUseGold then
                if not p.trusteeship_timeout then
                    p.trusteeship_timeout = now_time + TRUSTEESHIP_DELAY_TIME
                elseif now_time > p.trusteeship_timeout then
                    p.trusteeship_timeout = nil
                    auto_out()
                end
            else
                if now_time >= next_status_time then
                    --代打
                    auto_out()
                end
            end
		--本局结束
		elseif game_status == 5 then
            if played_times >= max_times or dissolve_table then
                game_stop()
            elseif now_time >= next_status_time then
                new_game()
            end
		end
    end
end

--状态恢复
function classic_landlord.resume(p, is_resume)
    if not is_resume and isUseGold then
        send_sitdown(p)
        return
    end
	local msg = {}
    local info = {}
    local pcards = {}
    
    local cur_status = game_status
    local now_time = os_time()
    
    for uid, v in pairs(players) do
        local count = 0
        if v.cards then 
            count = #v.cards
        end
        if p.uid == uid or cur_status == 4 or cur_status == 5 then
            tinsert(pcards, {uid = uid, cards = v.cards or {}, count = count})
        else    
            tinsert(pcards, {uid = uid, cards = {}, count = count})
        end
    end

    local rate = {}
    if game_status == 2 then
        for uid, v in pairs(players) do
            if not v.can_master then
                tinsert(rate, {uid = uid, score = 
                    (game_config.init_params.master_type == 1) and (p.apply_master and 1 or 0) or (p.rate_score or 0)})
            end
        end
    else
        tinsert(rate, {uid = master or 0, score = master_score or 0})
        tinsert(rate, {uid = -1, score = get_total_bomb()})
    end

    local ucards = {{
        uid = turn_info.winner or 0,
        cards = turn_info.cards,
        avatarCards = {},
        cardtype = turn_info.ctype}
    }

    msg.curruid = current_uid or 0
    msg.pcards = pcards
    msg.ucards = ucards
    msg.status = cur_status   
    msg.rate = rate
    msg.mastercards = master_cards or {}
    msg.time = (next_status_time and next_status_time - now_time > 0) and next_status_time - now_time or 0 
 --   --PRINT_T(msg)
    p:send_msg("game.GameLandResume", msg)
--    table_api.send_to_all("game.UserOnline", { uid = p.uid })
    if is_trusteeship(p) then
        player_trusteeship(p, 0)
    end

    --解散房间的信息
    if dissolve_timeout then
        p:send_msg("game.PushDissolveTable", { consentUid = consent_dissolve_players, 
                                                    refuseUid = refuse_dissolve_players,
                                                    remaintime = dissolve_timeout - os_time()})
    end
end

function classic_landlord.leave_game(p)
    if isUseGold then
        if not has_start then
            seats[p.seatid] = nil
            return true
        end
    else
        if not has_start or not p.ready or p.ready == 0 then
            -- if p.hascost and paytype == 1 then
            --     p.hascost = nil
            --     local price = tonumber(game_config.price[1]) or 0
            --     p:call_userdata("add_gold", price, gameid)
            --     LOG_DEBUG("player[%d] leave table restore money[%d]", p.uid, price)
            -- end
            if p.seatid then 
                seats[p.seatid] = nil

            end
            return true
        end
    end
	
    return false
end

function classic_landlord.get_tableinfo(p)
	local msg = {}
    local list = {}
    for uid, v in pairs(players) do
        if game_status == 0 then
            v.params = v.params or {}
            v.params[1] = v.params[1] or 0
            v.params[2] = v.kick_timeout or (os_time() + KICK_TIMEOUT)
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
            params = v.params or {}
        })
    end

    msg.owner = owner
    msg.endtime = end_time or 0
    msg.gameid = gameid
    msg.times = max_times
    msg.playedtimes = played_times + 1
    msg.score = max_bomb
    msg.paytype = pay_type
    msg.code = table_index
    msg.players = list
    msg.isGoldGame = isUseGold or 0
    msg.extradata = {0, base_multi, isTaste and 1 or 0}
    if isUseGold then
        msg.extradata[1] = game_config.init_params.min_gold
    end
    -- p:send_msg("game.TableInfo", msg)
    return msg
end

function classic_landlord.dispatch( p, name, msg )
	if not client[name] then
		LOG_ERROR("illegal protocol[%s]", name)
		return 
	else
        LOG_DEBUG("receive protocol[%s] from client", name)
		return client[name](p, msg)
	end
end

function classic_landlord.init( ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid, usegold, matchid, params, kb )

    
	players = ps
    table_api = api
	game_config = m_conf
	max_times = m_times
	max_bomb = m_score
    if usegold then max_bomb = 3 end
	pay_type = m_pay
	table_index = m_code
	owner = uid
    
    if not usegold then
        end_time = game_config.wait_time + os_time()
    end
	
    isUseGold = usegold
    isMatch = matchid
    if game_config.test_gold and game_config.test_gold > 0 then
        isTaste = true
    end

    if isUseGold and kb and not isTaste then
        LOG_DEBUG("set kickback[%s]", tostring(kb))
        kickback = kb
        ctrlcost = 0
        ctrlearn = 0
        skynet.fork(report_gold_info)
    end

	gameid = m_gameid
    
    base_multi = game_config.init_params.base_score or 1
	histroy = {}
    histroy.owner = uid
    histroy.time = os_time()
    histroy.code = table_index
    histroy.times = max_times
    histroy.gameid = m_gameid
    game_status = 0
end

return classic_landlord