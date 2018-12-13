local land_deal = require "land_deal"
local os_time = os.time

local this = {}
local players

local played_times
local total_times
local score
local code
local endtime
local owner
local gameid
local paytype
local config
local gametype
local tinsert = table.insert
local tremove = table.remove
local tindexof = table.indexof
local seats
local hasstart
local master         -- 地主uid
local histroy

--游戏状态，
--0表示还在等人开始中,
--1发牌阶段,
--2抢地主阶段,
--3确定地主发底牌，
--4本局游戏结束判断阶段
--5本局游戏结束
--200整局游戏结束
local game_status 

local next_status_time --切换到下个状态的时间

------------------------------------
local send_to_all
local free_table
local api_game_start
------------------------------------

local TIME_MASTER = 20 --叫地主时间
local TIME_OUTCARD = 20 --出牌时间
local TIME_GAME_END = 10

local first_uid --首叫玩家
local current_uid --当前玩家
local masterscore --地主叫分
local first_master --第一个叫地主玩家
local pre_player --前一个出牌的玩家id
local master_cards --地主三张底牌

--一轮出牌信息
local turn_winer --胜利玩家
local turn_count --出牌数目
local turn_type --出牌类型
local turn_cards --出牌数据


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

local cards = {}

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
---------------------------------------  for test  ---------------------------------------
--     cards = {}
--     tt = {103, 104, 105, 106,
--           203, 204, 205, 206,
--           303, 304, 305, 306,
--           403, 404, 405, 406,}
--     static_cards = {
--     101, 102, 107, 108, 109, 110, 111, 112, 113,
-- --   14,  15,   7,   8,   9,  10,  11,  12,  13 
--     201, 202, 207, 208, 209, 210, 211, 212, 213,
--     301, 302, 307, 308, 309, 310, 311, 312, 313,
--     401, 402, 407, 408, 409, 410, 411, 412, 413,
--     514, 515
-- --   16,  17
-- }
--     local tmp = {
--         1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
--         14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26,
--         27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38
--     }
--     local index
--     for i = 38, 1, -1 do
--         index = tremove(tmp, math.random(i))
--         tinsert(cards, static_cards[index])
--     end

--     for i=1,#tt do
--         tinsert(cards, tt[i])
--     end
------------------------------------------------------------------------------------------
end

--发牌
local function add_cards(count)
    local list, cardid
    for uid, p in pairs(players) do
        if p and p.ready == 1 and p.seatid and p.seatid > 0 then
            p.cards = p.cards or {}
            list = {}
            for i = 1, count do
                cardid = tremove(cards)
                tinsert(list, cardid)
                tinsert(p.cards, cardid)
            end
            for u, v in pairs(players) do
                if u == uid then
                    v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = count, cards = list })
                else
                    v:send_msg("game.AddCard", { uid = uid, seatid = p.seatid, count = count })
                end
            end
        end
    end
end

--随机第一个叫地主玩家
local function get_first_master()
    master = 0
    masterscore = 0
    local uidlist = {}
    for uid, p in pairs(players) do
        if p and p.ready == 1 and p.seatid and p.seatid > 0 then
            tinsert(uidlist, uid)
        end
    end
    first_uid = uidlist[math.random(#uidlist)]
    LOG_DEBUG("=======  first master uid:"..first_uid)
    return first_uid
end

--开始游戏
local function new_game()
    for uid, p in pairs(players) do
        if p.seatid and p.seatid > 0 and p.beready then
            p.ready = 1
        end
    end
    game_status = 101
    send_to_all("game.StartRound", { round = played_times + 1, total = total_times })
    game_status = 1
    shuffle() --洗牌
    for uid, p in pairs(players) do
        if p.ready == 1 then
            p.cards = nil
        end
    end
    add_cards(17) --发17张牌
    for uid, p in pairs(players) do
        p.can_master = true --能否叫/抢地主
    end
    current_uid = get_first_master()
    if gametype == 1 then
        --抢地主
        local current_player = players[first_uid]
        LOG_DEBUG("===== send AskMaster to [%d]", first_uid)
        current_player:send_msg("game.AskMaster", { time = TIME_MASTER, seatid = players[first_uid].seatid, opt = 1 })
     --   send_to_all("game.AskMaster", { time = TIME_MASTER, seatid = players[first_uid].seatid, opt = 1 })
    elseif gametype == 2 then
        --叫分
        send_to_all("game.AskRate", { time = TIME_MASTER, seatid = players[first_uid].seatid, opt = 0 })
    end
    game_status = 2
    next_status_time = os_time() + TIME_MASTER
end

--开始游戏
local function game_start()
    if hasstart then return end
    hasstart = true
    played_times = 0
    api_game_start()
    
    send_to_all("game.GameStart", {})
    new_game()
end

--检查是否开始游戏
local function check_start()
    if hasstart then return end
    LOG_DEBUG("检查游戏是否能开始")
    local readyCount = 0
    for uid, p in pairs(players) do
        if p.seatid and p.seatid > 0 and p.ready == 1 then
            readyCount = readyCount + 1
        end
    end
    LOG_DEBUG("准备的玩家个数:" .. readyCount)
    if readyCount >= config.min_player and readyCount <= config.max_player then
        game_start()
    end
end

--下一个抢地主玩家
local function get_next_master(seatid)
    local nextseatid = seatid + 1
    if nextseatid > config.max_player then
        nextseatid = 1
    end
    -- while true do
    --     if seats[nextseatid].can_master == true then
    --         break
    --     else
    --         nextseatid = nextseatid + 1
    --         if nextseatid > config.max_player then
    --             nextseatid = 1
    --         end
    --         if nextseatid == seatid then break end
    --     end
    -- end
    while true do
    	if seats[nextseatid].can_master then
            break
        end
    	if not seats[nextseatid].can_master then
        	if nextseatid == seatid or (first_master and first_master == nextseatid) then break end
    		nextseatid = (nextseatid + 1) <= config.max_player and (nextseatid + 1) or 1
    	end
    end

    if nextseatid == seatid or (master > 0 and players[master].seatid == nextseatid) then
        return 0
    else
        return nextseatid
    end
end

--下一个操作玩家
local function get_next_player(seatid)
    local nextseatid = seatid + 1
    if nextseatid > config.max_player then
        nextseatid = 1
    end
    return seats[nextseatid].uid
end

--确定了庄家
local function set_master()
    first_uid = nil

    LOG_DEBUG(master .. "叫到了庄")
    send_to_all("game.SetMaster", { uid = master, score = masterscore })
end

--发底牌
local function add_master_cards()
    local p = players[master]
    local list = {}
    local cardid
    for i = 1, 3 do
        cardid = tremove(cards)
        tinsert(list, cardid)
        tinsert(p.cards, cardid)
    end
    master_cards = list
    send_to_all("game.AddCard", { uid = p.uid, seatid = p.seatid, count = 3, cards = list })
end

--开始出牌了
local function start_play()
    current_uid = master
    turn_winer = master
    turn_count = 0
    turn_type = 0
    turn_cards = {}

    for uid, p in pairs(players) do
        p.outcount = 0 --出牌数目
        p.bombcount = 0 --炸弹数目
    end

    game_status = 3
    next_status_time = os_time() + TIME_OUTCARD

    send_to_all("game.AskPlayCard", { seatid = players[current_uid].seatid, time = TIME_OUTCARD, cardtype = 0, cards = {} })
end

--检查抢地主是否完成
local function check_master()
    if masterscore > 0 and master > 0 then
        --设置地主
        set_master()
        --发底牌
        add_master_cards()
        --开始
        start_play()
    else
        --没人抢地主
        new_game()
    end
end

--不叫
local function giveup_master()
    game_status = 102
    local p = players[current_uid]
    if p then
        p.can_master = false
        if gametype == 1 then
            send_to_all("game.GetMaster", { result = 0, uid = p.uid })
        else
            send_to_all("game.SetRate", { rate = 0, uid = p.uid })
        end
        local next_ask_master = get_next_master(p.seatid)

        if next_ask_master ~= 0 then
        	current_uid = seats[next_ask_master].uid
            local cur_player = players[current_uid]
            game_status = 2
            next_status_time = os_time() + TIME_MASTER
            if gametype == 1 then
            	LOG_DEBUG("===== send AskMaster to [%d]", current_uid)
            	cur_player:send_msg("game.AskMaster", { time = TIME_MASTER, seatid = next_ask_master, opt = (masterscore == 0 and 1 or 2) })
            --    send_to_all("game.AskMaster", { time = TIME_MASTER, seatid = next_ask_master, opt = (masterscore == 0 and 1 or 2) })
            else
                send_to_all("game.AskRate", { time = TIME_MASTER, seatid = next_ask_master, opt = masterscore })
            end
        else
            check_master()
        end
    end
end

--不出
local function pass_card(uid)
    game_status = 3
    if turn_type == 0 then
        LOG_DEBUG("赢家不能pass")
        return
    end
    local p = players[uid]
    current_uid = get_next_player(p.seatid)
    if current_uid == turn_winer then
        turn_count = 0
        turn_type = 0
        turn_cards = {}
    end
    
    next_status_time = os_time() + TIME_OUTCARD
    LOG_DEBUG("==========  [%d] pass", uid)
    send_to_all("game.PlayCard", { uid = uid, cards = {} })

    send_to_all("game.AskPlayCard", { seatid = players[current_uid].seatid, time = TIME_OUTCARD, cardtype = turn_type, cards = turn_cards })
end

--游戏结束
local function game_end()
    game_status = 4
    --春天判断and反春判断(-1:反春 0:常规 1:春天)
    local chun = 1
    if turn_winer == master then
        for uid, p in pairs(players) do
            if uid ~= master and p.outcount > 0 then
                chun = 0
                break
            end
        end
    else
        chun = 0
        if players[master].outcount == 1 then
            chun = -1
        end
    end

    --炸弹数目
    local bombcount = 0
    for uid, p in pairs(players) do
        bombcount = bombcount + p.bombcount
        p.total_bomb = p.total_bomb + p.bombcount
    end

    --玩家积分
    for uid, p in pairs(players) do
        if p.seatid and p.seatid > 0 and p.ready == 1 then
            local add_score = 0
            if uid == master then
                if turn_winer == master then
                    add_score = 2
                    p.win_count = p.win_count + 1
                else
                    add_score = -2
                    p.lose_count = p.lose_count + 1
                end
            else
                if turn_winer == master then
                    add_score = -1
                    p.lose_count = p.lose_count + 1
                else
                    add_score = 1
                    p.win_count = p.win_count + 1
                end
            end
            add_score = add_score * score * masterscore
            if chun ~= 0 then
                add_score = add_score * 2
            end
            if bombcount > 0 then
                if bombcount > 3 then
                    add_score = add_score * math.floor(2^3)
                else
                    add_score = add_score * math.floor(2^bombcount)
                end
            end
            p.add_score = add_score
            p.max_score = (p.add_score or 0) > p.max_score and p.add_score or p.max_score
        end
    end
  
    local info = {}
    local cds = {}
    for uid, p in pairs(players) do
        if p.seatid and p.seatid > 0 and p.ready == 1 then
            p.score = p.score + p.add_score
            tinsert(info, p.uid)
            tinsert(info, #p.cards)
            tinsert(info, p.bombcount)
            tinsert(info, p.add_score)
            tinsert(info, p.score)
            p.add_score = 0
            for i, cardid in ipairs(p.cards) do
                tinsert(cds, cardid)
            end
        end
    end
    send_to_all("game.GameResult", { master = master, count = 3, infos = info, cards = cds })

    histroy.recording = histroy.recording or {}
    -- tinsert(histroy.recording, {master=master, count=3, round = played_times+1, infos=info, cards=cds})
    master_cards = nil
    game_status = 5
    next_status_time = os_time() + TIME_GAME_END
    played_times = played_times + 1
end

local function is_teammate()
    if master and master > 0 and (current_uid == master or (pre_player and pre_player == master)) then
        return false
    end
    return true
end

--出牌
local function out_card(p, outcards, client_card_type, is_auto)
    game_status = 104
    if #p.cards < #outcards then
        LOG_DEBUG("手牌不足")
        return
    end
    LOG_DEBUG("is_auto:"..tostring(is_auto) or 111)
    local cardtype = land_deal.getCardType(outcards)
    
    if not is_auto and (not client_card_type or client_card_type ~= cardtype or cardtype == land_deal.CT_ERROR) then 
        LOG_DEBUG("player[%d] out card faild clienttype[%d] servertype[%d]", p.uid, client_card_type or -1, cardtype or -1)
        --将game_status重新设回3否则客户端若发了一个错误牌型后服务器将不再接受playcard协议
    --    game_status = 3
        return 
    end
    --对比扑克
    if turn_count ~= 0 then
        if land_deal.compareCard(turn_cards, outcards, turn_count) == false then 
            LOG_DEBUG("player[%d] out card faild illegal outcards", p.uid)
            return 
        end
    end

    --删除扑克
    if land_deal.removeCards(outcards, p.cards) == false then 
        LOG_DEBUG("removeCards error")
        return 
    end

    --设置变量
    turn_winer = p.uid
    turn_count = #outcards
    turn_type = cardtype
    turn_cards = outcards 
    p.outcount = p.outcount + 1
    if cardtype == land_deal.CT_BOMB_CARD or cardtype == land_deal.CT_MISSILE_CARD then
        p.bombcount = p.bombcount + 1
    end
    if #p.cards ~= 0 then
        if cardtype ~= land_deal.CT_MISSILE_CARD then
            current_uid = get_next_player(p.seatid)
        else
            turn_count = 0
            turn_type = 0
            turn_cards = {}
        end
    else
        current_uid = 0
    end
    -- PRINT_T(outcards, "out:"..p.uid)
--    -- PRINT_T(p.cards)
    pre_player = p.uid
    LOG_DEBUG("send to all player [%d] play card", p.uid)
    send_to_all("game.PlayCard", { uid = p.uid, cards = outcards, cardtype = cardtype })
    --结束判断
    if current_uid == 0 then
        game_end()
    else
        game_status = 3
        next_status_time = os_time() + TIME_OUTCARD
        send_to_all("game.AskPlayCard", { seatid = players[current_uid].seatid, time = TIME_OUTCARD, cardtype = turn_type, cards = turn_cards })
    end
end

--超时代打
local function auto_out()
    game_status = 103
    local p = players[current_uid]

    --农民需要考虑队友
    local teammate = is_teammate()

    local outcards = land_deal.searchCards(p.cards, turn_cards, teammate)
  
 --   -- PRINT_T(outcards, current_uid)
    if #outcards > 0 then
        out_card(p, outcards, nil, 1)
    else
        pass_card(current_uid)
    end
--    -- PRINT_T(p.cards, "remain cards")
end

local function game_stop()
    game_status = 200
    LOG_DEBUG("游戏结束了！！！")

    histroy.endtime = os_time()
    histroy.players = histroy.players or {}
    local info
    local infos = {}
    for uid, p in pairs(players) do
        if p.ready == 1 and p.seatid and p.seatid > 0 then
            info = {
                uid = p.uid,
                nickname = p.nickname,
                wincount = p.win_count ,
                losecount = p.lose_count,
                totalscore = p.score,
                maxscore = p.max_score,
                bombcount = p.total_bomb,
            }
            tinsert(histroy.players, info)
            tinsert(infos, info)
        end
    end

    send_to_all("game.GameLandlordEnd", { round = total_times, infos = infos })
 --   send_to_all("game.NiuNiuHistroy", { list = histroy.recording })

    free_table(histroy, 1002)
end

function this.free()
    for seatid, v in pairs(seats) do
        seats[seatid] = nil
    end

    free_table = nil
    send_to_all = nil
    histroy = nil
    static_cards = nil
    cards = nil

    for uid, p in pairs(players) do
        for k, v in pairs(p) do
            p[k] = nil
        end
    end
end

function this.update()
    if not hasstart and endtime then
        if os_time() >= endtime then
            free_table(histroy, 2001)
            return
        end
    end

    if hasstart and next_status_time and next_status_time > 0 then
        if game_status == 2 then
            -- 抢地主阶段
            if os_time() >= next_status_time then
                giveup_master()
            end
        elseif game_status == 3 then
            -- 出牌阶段
            if os_time() >= next_status_time then
                --代打
                auto_out()
            end
        elseif game_status == 5 then
            if os_time() >= next_status_time then
                if played_times >= total_times then
                    game_stop()
                else
                    new_game()
                end
            end
        end
    end
end

function this.join(p)
    p.ready = 0
    p.score = 0
    p.can_master = true
    p.outcount = 0
--    p.bombcount = 0
    p.total_bomb = 0      --炸弹总数
    p.win_count = 0       --胜局数
    p.lose_count = 0      --败局数
    p.max_score = 0        --最高得分
    return true
end

function this.dispatch(p, name, msg)
    LOG_DEBUG(p.uid .. ":" .. name)
    if name == "SitdownNtf" then
        -- msg.seatid
        local seatid = tonumber(msg.seatid)
        if seatid and not seats[seatid] and seatid > 0 and seatid <= config.max_player then
            if p.seatid and p.seatid > 0 and hasstart then
                -- 已经坐下，且已经开局不能换座位
                LOG_DEBUG("已经坐下，且已经开局不能换座位:" .. p.uid)
                return
            end
         --   PRINT_T(p)
            if p.seatid and p.seatid > 0 then
                seats[p.seatid] = nil
            elseif paytype == 1 then
                -- 需要扣费
                local price = tonumber(config.price[1])

                if not price then
                    LOG_ERROR("it must be have price")
                    return "game.SitdownNtf", { uid = p.uid, seatid = -1 }
                end

                -- local ok, result = pcall(p.call_userdata, p, "sub_gold", p.uid, price, 2001)
                -- if not ok or not result then
                --     LOG_ERROR("sub gold faild")
                --     return "game.SitdownNtf", { uid = p.uid, seatid = -1 }
                -- end
                LOG_DEBUG("player[%d] sitdown and sub_gold[%d]", p.uid, price)
                p.hascost = true
            end
            seats[seatid] = p
            p.seatid = seatid
            p.ready = 0
            if not owner then
                owner = p.uid
            end

            if hasstart then
                p.beready = true
                -- p.ready = 1 --游戏开始之后，玩家坐下就准备了
            end
            LOG_DEBUG("sit down success")
        
            send_to_all("game.SitdownNtf", 
                {uid = p.uid,
                seatid = seatid,
                nickname = p.nickname, 
                headimg = "null", --sex = p.sex or 1
                })
        end
    elseif name == "GetReadyNtf" then
        if hasstart then return end --游戏开始之后，玩家坐下就准备了
        if not p.ready or p.ready == 0 then
            if p.seatid and p.seatid > 0 then
                p.ready = 1
                send_to_all("game.GetReadyNtf", { uid = p.uid, seatid = p.seatid })
                check_start()
            end
        end
    elseif name == "GetMaster" then
        if game_status == 2 and hasstart and (p.can_master or first_master) and p.seatid and p.seatid > 0 and p.ready == 1 and gametype == 1 then
            if msg.result == 1 or msg.result == 0 then
                game_status = 102
                --叫地主
                if msg.result ~= 0 then
                    master = p.uid
                    masterscore = (masterscore == 0 and 1 or masterscore * 2)
                    if not first_master then
                    	first_master = p.seatid
                    end
                    p.apply_master = true
                end
                p.can_master = false
              
                send_to_all("game.GetMaster", { result = msg.result, uid = p.uid })
                local next_ask_master = get_next_master(p.seatid)
                if next_ask_master ~= 0 then
                    local cur_player = seats[next_ask_master]
                    current_uid = cur_player.uid
                    game_status = 2
                    next_status_time = os_time() + TIME_MASTER
                   -- send_to_all("game.AskMaster", { time = TIME_MASTER, seatid = next_ask_master, opt = (masterscore == 0 and 1 or 2) })
                    LOG_DEBUG("===== send AskMaster to [%d]", current_uid)
                    cur_player:send_msg("game.AskMaster", {time = TIME_MASTER, seatid = next_ask_master, opt = (masterscore == 0 and 1 or 2) })
                else
                    check_master()
                end
            end
        end
    elseif name == "SetRate" then
        if game_status == 2 and hasstart and p.can_master and p.seatid and 
          p.seatid > 0 and p.ready == 1 and gametype == 2 and p.uid == current_uid then
            if msg.rate > 3 or msg.rate < 0 or (msg.rate <= masterscore and masterscore > 0 and msg.rate > 0) then return end
            game_status = 102
            p.can_master = false

            LOG_DEBUG(p.uid .. "叫分:" .. msg.rate)
            -- if msg.rate > masterscore then
            --     masterscore = msg.rate
            --     master = p.uid
            -- end
            masterscore = msg.rate
            master = p.uid
            p.rate_score = msg.rate
            send_to_all("game.SetRate", { rate = msg.rate, uid = p.uid })

            if masterscore == 3 then
                check_master()
            else
                local next_ask_master = get_next_master(p.seatid)
                if next_ask_master ~= 0 then
                    current_uid = seats[next_ask_master].uid
                    game_status = 2
                    next_status_time = os_time() + TIME_MASTER
                    send_to_all("game.AskRate", { time = TIME_MASTER, seatid = next_ask_master, opt = masterscore })
                else
                    check_master()
                end
            end
        end
    elseif name == "PlayCard" then
    	LOG_DEBUG("============  client play card")
        if (game_status == 3 or game_status == 104) and hasstart and p.seatid and p.seatid > 0 and p.ready == 1 then
            if p.uid == current_uid then
                game_status = 103
--                PRINT_T(msg)
                if msg.cards and #msg.cards > 0 then
                    out_card(p, msg.cards, msg.cardtype)
                else
                    pass_card(p.uid)
                end
            else
                LOG_DEBUG("[%d]playcard faild, current_uid[%d]", p.uid, current_uid)
            end
        else
            LOG_DEBUG("[%d]playcard faild, game_status[%d], hasstart[%s], p.seatid[%d], p.ready[%d]", 
                p.uid, game_status, tostring(hasstart) or "false", p.seatid or -1, p.ready or -1)
        end
    end
end

-- 发送房间信息
function this.get_tableinfo(p)
    local msg = {}
    local list = {}
    for uid, v in pairs(players) do
        tinsert(list, {
            uid = v.uid,
            nickname = v.nickname,
            sex = 1,
            seatid = v.seatid or 0,
            ready = v.ready or 0,
            online = v.online or 1,
            score = v.score or 0
        })
    end
    msg.owner = owner
    msg.endtime = endtime
    msg.gameid = gameid
    msg.times = total_times
    msg.playedtimes = played_times
    msg.score = score
    msg.paytype = paytype
    msg.code = code
    msg.players = list
--    luadump(msg)
    -- p:send_msg("game.TableInfo", msg)
    return msg
end

function this.resume(p)
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
                    (gametype == 1) and (p.apply_master and 1 or 0) or (p.rate_score or 0)})
            end
        end
    else
        tinsert(rate, {uid = master or 0, score = masterscore or 0})
    end

    local ucards = {
        uid = turn_winer or 0,
        cards = turn_cards,
        avatarCards = {},
        cardtype = turn_type
    }
    
    -- local rate = {
    --     maxuid = master or 0,
    --     maxscore = masterscore or 0,
    -- }

    msg.curruid = current_uid or 0
    msg.pcards = pcards
    msg.ucards = ucards
    msg.status = cur_status   
    msg.rate = rate
    msg.mastercards = master_cards or {}
    msg.time = (next_status_time and next_status_time - now_time > 0) and next_status_time - now_time or 0 
 --   PRINT_T(msg)
    p:send_msg("game.GameLandResume", msg)
    send_to_all("game.UserOnline", { uid = p.uid })
end

-- 尝试离开游戏，如果能离开，返回true，并且调用该函数的地方继续处理离开逻辑
function this.leave_game(p)
    if not hasstart or not p.ready or p.ready == 0 then
        if p.hascost and paytype == 1 then
            p.hascost = nil
            local price = tonumber(config.price[1]) or 0
            p:call_userdata("add_gold", p.uid, price, 1003)
            LOG_DEBUG("player[%d] leave table restore money[%d]", p.uid, price)
        end
        seats[p.seatid] = nil
        return true
    end
    return false
end

function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid)
    seats = {}
    players = ps
    config = m_conf
    played_times = 0
    total_times = m_times
    score = m_score
    code = m_code
    endtime = os_time() + m_conf.wait_time
    owner = uid
    gameid = m_gameid
    paytype = m_pay
    hasstart = false
    gametype = config.init_params
    game_status = 0

    send_to_all = api.send_to_all
    free_table = api.free_table
    api_game_start = api.game_start

    histroy = {}
    histroy.owner = uid
    histroy.time = os_time()
    histroy.code = code
    histroy.times = total_times
    histroy.gameid = gameid
end

return this