local niuniu_deal = require "hundred_niuniu_deal"

local played_times
local total_times
local score
local code
local endtime
local owner
local gameid
local paytype
local seats
local hasstart
local master

----------------------------------- unuse
local this = {}
local config
local init_params

local players
local cards = {} --洗牌后的牌
local dice = 0 --骰子点数
local masterlist = {} --抢庄数组，默认第一个为庄

local tinsert = table.insert
local tremove = table.remove
local tindexof = table.indexof
local tconcat = table.concat
local game_status = -1 --游戏状态：0开始游戏，1准备阶段，2下注阶段，3摇骰子，4发牌，5亮牌，6结算

local histroy

local robot_bet_times = 0 --机器人当前下注次数
local robot_bet_maxtimes = 10 --机器人下注次数
local next_status_time = -1 --切换到下个状态的时间
local game_start_time --游戏开始时间
local bet_time = 5 --允许下注时间 10*1 +5
local shuffle_time = 0 --骰子动画时间
local addcards_time = 15 --发牌时间
local showcards_time = 15 --亮牌时间
local calculate_cards_time = 5 --结算时间

local bet_count = 0 --当前总下注数目
local bet_max = 0 --每局最多下注数目
local unit = 10000 --单位
local user_bet_table = {} --用户下注列表
local current_cards --当前牌局的牌

------------------------------------
local send_to_all
local free_table
------------------------------------

local static_cards = {
    101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113,
    201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213,
    301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313,
    401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413,
    501, 502
}

--牌型对应的倍率
local cardtype_2_rate = {
    [1] = 1, -- 1-10 牛1-牛10
    [2] = 2,
    [3] = 3,
    [4] = 4,
    [5] = 5,
    [6] = 6,
    [7] = 7,
    [8] = 8,
    [9] = 9,
    [10] = 10,
    [20] = 17, -- 四花
    [30] = 18, -- 五花
    [40] = 20, -- 炸弹
    [50] = 25, -- 小牛
}

-- 检测用户金钱
local function check_user_gold(p)
    local p_gold = p.gold
    local min = init_params.room_min_gold * unit
    if min > p_gold then
        tremove(players, p.uid)
        return false
    end
    return true
end

-- 检测用户金钱
local function check_users_gold()
    for uid, p in pairs(players) do
        if not check_user_gold(p) then
            p:send_msg("cmd?", {uid=uid, msg = '金钱不够'})
        end
    end
end

--@test->ok
--记录用户下注信息
local user_bet_table = {}
local function record_bet(p, msg)
    local ubt = user_bet_table[p.uid]
    local temp = {}
    if ubt == nil then
        temp[msg.seatid] = msg.bet_num
        user_bet_table[p.uid] = temp
        ubt = temp
    end
    if nil == ubt[msg.seatid] then
        ubt[msg.seatid] = msg.bet_num
    else
        ubt[msg.seatid] = msg.bet_num + ubt[msg.seatid]
    end
end

--检测庄家
local function check_master()
    local p = masterlist[1]
    if p.gold < init_params.min_master_gold * unit then --切换庄
        tremove(players, uid)
        --cmd?通知下庄

        --cmd?通知上庄
    end
end

--ai操作下注
local function dorobot_bet()
    for uid, p in pairs(players) do
        if p.isrobot == 1 then
            local t_test = 99
            p.gold = p.gold - t_test
            local msg = { seatid = 1, bet_num = t_test } --需要构造数据
            record_bet(p, msg)
            --cmd?
        end
    end
end

--ai下注
local function robot_bet()
    if robot_bet_maxtimes >= robot_bet_times then
        robot_bet_times = robot_bet_times + 1 --默认机器人下注10次，一秒一次
        next_status_time = os.time() + 1
        dorobot_bet()
    end
    if robot_bet_maxtimes < robot_bet_times then
        next_status_time = os.time() + bet_time --余下五秒钟空白
        game_status = 3
    end
end

-- 洗牌
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

--摇骰子
local function shakeDice()
    dice = 1
    --"cmd?发送骰子数据
    game_status = 4
    next_status_time = os.time() + shuffle_time
end

-- 发牌
local function add_cards()
    --4个闲，一个庄
    local list = {}
    local dice = shakeDice()
    for i = 1, 5 do
        local t = {}
        for j = 1, 5 do
            local cardid = tremove(cards)
            tinsert(t, cardid)
        end
        local ismaster = false
        if dice == i then
            ismaster = true
        end
        list[i] = { ismaster = ismaster, seatid = i, cards = t }
    end
    current_cards = list
    send_to_all("game.ShowCard", { list }) --cmd?
    game_status = 5
    next_status_time = os.time() + addcards_time
end

-- 亮牌
local function showcards()
    game_status = 6
    next_status_time = os.time() + showcards_time
end

--@test
-- 结算
local function calculate()
    local temp_master
    for index, v in ipairs(current_cards) do
        if v.ismaster == true then
            temp_master = v.cards
            break
        end
    end
    local temp_cal = {}
    for index, v in ipairs(current_cards) do
        if not v.ismaster then
            local result, calMaster, calClient = niuniu_deal.doCompare(temp_master, v.cards)
            temp_cal[v.seatid] = { result, calMaster, calClient }
        end
    end
    local masterWin = 0
    for uid, seats_bet in pairs(user_bet_table) do
        for seatid, bet_num in pairs(seats_bet) do
            local isWin = temp_cal[seatid][0]
            local temp_user_count = 0
            local masterType = temp_cal[seatid][2][1]
            local clientType = temp_cal[seatid][3][1]
            if isWin then --庄赢
                temp_user_count = temp_user_count - (cardtype_2_rate[masterType] or 1) * bet_num
            else
                temp_user_count = temp_user_count + (cardtype_2_rate[clientType] or 1) * bet_num
            end
            masterWin = masterWin - temp_user_count
        end
        --cmd?用户信息
    end
    --cmd?庄信息
end

--初始化
function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid)
    played_times = 0
    total_times = m_times
    score = m_score
    code = m_code
    gameid = m_gameid
    paytype = m_pay

    ---------------------------------
    hasstart = false
    math.randomseed(os.time());
    players = ps
    config = m_conf
    init_params = config.init_params
    bet_max = init_params.per_max_gold * init_params.unit
    game_status = 0

    send_to_all = api.send_to_all
    free_table = api.free_table

    histroy = {}
    histroy.owner = uid
    histroy.time = os.time()
    histroy.code = code
    histroy.times = total_times
    histroy.gameid = gameid
end

--接收客户端消息,player,cmd,msg
function this.dispatch(p, name, msg)
    if not hasstart then
        return
    end
    if game_status == 2 then --下注
        if name == "cmd?" then
            if bet_max < bet_count + msg.bet_num then
                --cmd?下注已满
                return
            end
            if msg.bet_num <= p.gold then
                --cmd?金钱不够
                return
            end
            if bet_max > bet_count + msg.bet_num and msg.bet_num <= p.gold then
                bet_count = bet_count + msg.bet_num
                p.gold = p.gold - msg.bet_num
                record_bet(p, msg)
                --cmd?下注成功
            end
        end
    end
    if name == "cmd?" then --抢庄
        for i = 1, #masterlist do
            if masterlist[i].uid == p.uid then
                --cmd?您已经抢庄
                return
            end
        end
        if init_params.min_master_gold <= p.gold then
            --cmd?金钱不够
            return
        end
        masterlist[#masterlist + 1] = p
        --cmd?加入抢庄列表
    end
    --机器人随机离开进入,cmd?coding?
    if name == "cmd?" then --离开
        for i = 1, #masterlist do
            if masterlist[i].uid == p.uid then
                --cmd?用户离开
                tremove(masterlist, i)
                break
            end
        end
    end
end

function this.join(p)
    if #players > config.max_player then
        --cmd?房间已满
        return
    end
    if check_user_gold(p) then
        players[p.uid] = p
    else
        --cmd?金钱不够
    end
end

function this.game_end()
    game_status = 0
end

function this.game_stop()
end

function this.leave_game(p)
end


function this.game_start()
    --准备游戏
    game_status = 1
    --接收用户命令
    hasstart = true
    next_status_time = os.time()
    check_users_gold()
    check_master()
    shuffle()
    game_status = 2
    --    --开始下注
    --    bet()
    --    --开始游戏
    --    --初始化机器人
    --    robotCount = config.robotCount
    --    --开始洗牌
    --    shuffle()
    --    --摇骰子
    --    shakeDice()
    --    --开始发牌
    --    add_cards()
    --    --结算
end

function this.update()
    if not hasstart then
        this.game_start()
    end
    --重新开始游戏
    if game_status == 0 then
        if os.time() > next_status_time then
            this.game_start()
        end
    end
    --下注
    if game_status == 2 then
        if os.time() > next_status_time then
            robot_bet()
        end
    end
    --摇骰子
    if game_status == 3 then
        if os.time() > next_status_time then
            shakeDice()
        end
    end
    --发牌
    if game_status == 4 then
        if os.time() > next_status_time then
            add_cards()
        end
    end
    --亮牌
    if game_status == 5 then
        if os.time() > next_status_time then
            showcards()
        end
    end
    --结算
    if game_status == 6 then
        if os.time() > next_status_time then
            calculate()
        end
    end
end

return this