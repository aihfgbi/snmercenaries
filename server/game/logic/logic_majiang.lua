require "majiang_const_define"
local cluster = require "skynet.cluster"

local mj_deal = require "majiang_deal"
local mj_build = require "mj_build_cards"
local skynet = require "skynet"

local mj_cfg = {
    mj_specrule_cfg = require "mj_specrule_conf",
    mj_baserule_cfg = require "mj_baserule_conf",
    mj_rate_cfg = require "mj_rate_conf",
    room_conf = require "room_conf",
}

local osapi = {
    os_time = os.time,
    tinsert = table.insert,
    tremove = table.remove,
    tindexof = table.indexof,
    tarrcopy = table.arraycopy,
    tsort = table.sort,
}

local table_game


local _kickback      --全局控制概率
local _ctrlcost = 0
local _ctrlearn = 0

local mj_logic = {}
local client = {}
local status_func = {}           --状态执行函数
local _has_robot

local _players
local _players_sit = {           --已经坐下的玩家
    --[seatid] = p
}
local _table_gameids = {}          --开房模式中麻将gameid
local _tapi
local _game_cfg
local _gameid
local _pay_type
local _has_start
local _max_times                --最大游戏局数
local _played_times  = 0            --已玩局数
local _owner                    --房主
local _end_time
local _isUseGold                --是否是金币模式
local _isMatch                  --是否是金币模式
local _isTaste                  --是否体验模式
local KICK_TIMEOUT = 20         --金币模式准备超时 秒
local _rule_type                --麻将的规则玩法
local _table_index

local WAIT_DEAL = 1           --等待客户端请求发牌协议超时时间
local _deal_tiles_time          --超时发牌的时间点
local _request_deal = {}    --请求发牌的玩家，这个功能现在并没有用到

local _bit_to_play_type = {     --二进制位数对应玩法
    "qiangganghu",
    "pengpenghu",
    "qidui",
    "hunyise",
    "qingyise",
    "gangshangkaihua",
    "shisanyao",
    "tiandihu",
    "longqidui",
}
local _play_type_info = {               --创建房间时的玩法信息
    -- shifter_type = 1,               1白板做鬼 2翻鬼 3双鬼
    -- horse_type = 0,                 0 无马 2,4,6,8分别表示 2,4,6,8马   
    
    -- qiangganghu = 0,
    -- pengpenghu = 0,
    -- qidui = 0,
    -- hunyise = 0,
    -- qingyise = 0,
    -- gangshangkaihua = 0,
    -- shisanyao = 0,
    -- tiandihu = 0,
    -- longqidui = 0,               
}             

local FREE_TIMEOUT = 1
local free_table_timeout     --当房间没有玩家后2秒解散
 
local _re_ready_count = 0        --每局结束后关闭结算界面的玩家数当所有玩家都关闭时 则不等时间 直接开始先游戏

local time_join_robot           --机器人加入时间

local _builded_tiles
local _win_tiles                --组牌后能胡的牌\
--[[
    {[uid] = {cards}}
]]
--local _prior_player              --由系统指定提高胜率的玩家信息

------------------房间解散数据
local DISSOLVE_TIME = 60                        --解散超时
local DISSOLVE_CD = 3 * 60                      --解散冷却时间
local dissolve_table                            --是否解散
local consent_dissolve_players = {}             --已同意解散房间的玩家
local refuse_dissolve_players = {}              --已拒绝解散房间的玩家
local dissolve_timeout                          --解散超时
local next_dissolve_time = 0                    --下次可解散的时间
------------------------------

local SHIFTER1
local SHIFTER2
--local _base_rule                --基础规则
local _start_time               --开始时间
local _game_status = 0          --游戏状态
local _base_score            --底分
--local _origin_wall                  --按顺序排列的牌
local _wall = {}                         --洗过后的牌
local _dices                        --骰子信息
local _drow_reverse                 --是否杠后摸牌
local _drow_reverse_uid = 0         --杠后摸牌玩家uid
local _qianggang_info               --抢碰杠信息 {player,tile}
local _qiangminggang_info           --抢明杠信息 {player,tile}
local _horse                        --抓马规则
local _horse_tiles                  --马牌

local _opt_seatid                   --操作的座位
local _last_winners                     --上局的赢家
local _last_losers                      --上局的输家
local _lose_seatid                      --点炮的座位号

local _last_horse_tiles                 --上局抓码牌
local _last_hit_tiles                       --上局中码的牌
local _banker_seatid                      --庄位
local _last_banker_seatid                     --上局的庄位
local _last_discard_tile                        --最新打出的牌
local _last_discard_seatid                      --上次出牌的玩家
local _win_type                             --赢的类型 点炮、自摸
local _win_card
local _last_timer_start
local _discard_cnt                     --出牌记数
local _qishouhu                           --是否可以起手胡

local _fengpai                          --是否带风
--local _claim_players                                --可以吃碰杠的玩家信息
local _table_end = 0                            --整局游戏是否结束
local _auto_out_max = 2                   --自动出牌最大次数 超过之后设为托管
local _claim_players_new = {
    -- [1] = {
    --     seatid = number,
    --     opttype = number,
    --     cards = {}
    -- }
}
local _current_scores = {               --分数信息
 --   {seatid = 1, end_score = 1, horse_score = 1, gang_score = 1},
}   

local _claim_cache_data                 --缓存的玩家吃碰杠信息 用于断线重连        

local _gm_next_card = {              --下一张想要拿到的牌 测试用       
 --   [uid] = card
}

--基本规则
local base_rule_cfg         --基础规则配表
local spec_rule_cfg         --胡牌规则配表
local CAN_PENG              --是否可以碰
local CAN_GANG              --是否可以杠
local CAN_CHI               --是否可以吃
local CAN_DIAN              --是否可以点炮

local _last_peng_card --记录当前碰的牌，用于碰牌过圈的规则
local _liuju_num = 14        --最后剩几张牌流局，每杠一次加2
local _can_dian_player --用于记录可以点炮玩家的座位号
local _is_game_end --用于记录一炮多响的时候是否已经有人点了胡，好跳转状态

local function fill_table_gameids()
    for k, v in pairs(mj_cfg.room_conf) do
        if v.type == "table" and v.majiang then
            table.mergeByAppend(_table_gameids, v.majiang)
        end
    end
end

--[[
    @desc: 调用userdata里面的加减金币更新用户的金币
    author:{author}
    time:2019-01-29 22:50:41
    --@uid:
	--@num: 
    @return:
]]
local function update_gold(uid, num)
    local p = _players[uid]
    if not p then return end
    local opt = "goldChange"
    if not _isTaste then
        local ok, result = pcall(p.call_userdata, p, opt, math.abs(num), _gameid)
        if not ok then
            LOG_ERROR("player[%d] %s faild. num[%d], result[%s]", p.uid, opt, math.abs(num), tostring(result))
            return
        end
    end
    
    p.gold = p.gold + num
    p.gold_change = p.gold_change + num
    if _isTaste then return end
    if p.ctrlinfo and p.ctrlinfo.ctrltype then
        p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + num
    --    p.ctrlgold = p.ctrlgold - math.abs(num)
    end
    --记录收益
    if _has_robot and not p.isrobot then
        if num > 0 then
            _ctrlearn = _ctrlearn + num
        else
            _ctrlcost = _ctrlcost + math.abs(num)
        end
        _tapi.report_gold(_ctrlcost, _ctrlearn)
        _ctrlcost = 0
        _ctrlearn = 0
    end
end

local function deal_gold(changed)
    local total_win = 0
    local total_lose = 0
    for k,v in pairs(changed) do
        for uid, num in pairs(v) do
            if k == "win" then
                total_win = total_win + num
            elseif k == "lose" then
                total_lose = total_lose + num
            end
        end
    end

    --当总输赢不一样的时候做的容错处理
    if total_win > total_lose then
        total_win = total_lose
        local len = table.len(changed.win)
        for uid, _ in pairs(changed.win) do
            changed.win[uid] = math.floor(total_win / len)
        end
    elseif total_win < total_lose then
        total_lose = total_win
        local len = table.len(changed.lose)
        local per_lose = math.ceil(total_lose / len)
        total_lose = 0
        for uid, num in pairs(changed.lose) do
            if num >= per_lose then
                changed.lose[uid] = per_lose
            end
            total_lose = total_lose + changed.lose[uid]
        end
        len = table.len(changed.win)
        local per_win = math.floor(total_lose / len)
        for uid, _ in pairs(changed.win) do
            changed.win[uid] = per_win
        end
    end

    for k,v in pairs(changed) do
        for uid, num in pairs(v) do
            if k == "win" then
                update_gold(uid, num)
            elseif k == "lose" then
                update_gold(uid, 0-num)
            end
        end
    end
end

-- local function robot_replace(p)
--     --申请机器人接管
--     local robot = _tapi.get_robot("majiang")
--     robot.online = 1
--     local init_info = {
--         uid = p.uid,
--         seatid = p.seatid,
--         tiles = p.tiles,
--         hold = p.hold_tiles,
--     }
   
--     local ok, result = pcall(cluster.send, robot.agnode, robot.agaddr, "send_to_client", robot.uid, "server.init_replace_robot", init_info)
--     if ok then
--         p.replace_robot = robot
--     else
--         LOG_ERROR("send_msg error:"..tostring(result))
--         LOG_ERROR("name:"..name..",node:"..tostring(self.agnode)..",addr="..tostring(self.agaddr))
--     end
-- end

-- local function destroy_replace_robot(p)
--     --销毁接管robot
--     local robot = p.replace_robot
--     if robot then
--         local ok, result = pcall(cluster.send, robot.agnode, robot.agaddr, "send_to_client", robot.uid, "exit", {})
--         if not ok then
--             LOG_ERROR("send_msg error:"..tostring(result))
--             LOG_ERROR("name:"..name..",node:"..tostring(self.agnode)..",addr="..tostring(self.agaddr))
--         end
--         p.replace_robot = nil
--     end
-- end

--是否托管
local function is_trusteeship(p)
    return p.trusteeship and p.trusteeship > 0
end

--玩家托管 state 1托管 0取消托管
local function player_trusteeship(p, state)
--    LOG_WARNING("player[%d] trusteeship[%d]", p.uid, state)
    p.trusteeship = state
    if state == 1 then
        -- if _isUseGold then
        --     robot_replace(p)
        -- end
    elseif state == 0 then
        p.auto_out_cnt = 0
        -- if _isUseGold then
        --     destroy_replace_robot(p)
        -- end
    end
    -- _tapi.send_to_all("game.LandTrusteeship", {uid = p.uid, state = state})
end

local function set_play_type_info()
    --在开房模式下info是客户端传过来的参数 为一个长度为3的数组 [1]为鬼牌选择(1白板做鬼 2翻鬼 3双鬼) [2]马牌选择(0 无马)
    --[3]玩法选择(二进制表示 从第一位到第九位分别表示抢杠胡 碰碰胡 七对 混一色 清一色 杠上开花 十三幺 天地胡 龙七对) 
    local info = _rule_type or {}
--    PRINT_T(_table_gameids, _gameid)
    if osapi.tindexof(_table_gameids, _gameid) then
        if info[1] and info[1] >= 1 and info[1] <= 3 then
            _play_type_info.shifter_type = info[1]
        else
            _play_type_info.shifter_type = 1
        end

        if info[2] and info[2] >= 0 and info[2] <= 8 and (info[2] % 2 == 0) then
            _play_type_info.horse_type = info[2]
        else
            _play_type_info.horse_type = 0
        end

        --检查某一位是否置1了
        local function is_bit_set(num, bit)
            return (num & (1 << bit)) > 0
        end

        if info[3] then
            local num = info[3]
            for i=1, #_bit_to_play_type do
                if is_bit_set(num, i) then
                    _play_type_info[_bit_to_play_type[i]] = 1
                end
            end
        end
        
    else
        --TODO
        _play_type_info.shifter_type = 0
        _play_type_info.horse_type = 0
        for _, v in ipairs(_bit_to_play_type) do
            _play_type_info[v] = 1
        end
    end
end

local function init_base_rule()
    base_rule_cfg = assert(mj_cfg.mj_baserule_cfg[_game_cfg.init_params.base_rule])
    CAN_PENG = base_rule_cfg.peng == 1
    CAN_GANG = base_rule_cfg.gang == 1
    CAN_CHI  = base_rule_cfg.chi  == 1
    CAN_DIAN = base_rule_cfg.dian == 1
    _fengpai = base_rule_cfg.fengpai and base_rule_cfg.fengpai > 0
 --   _horse = base_rule_cfg.horse or 0
    
end

local function init_mj_deal(conf)
    spec_rule_cfg = assert(mj_cfg.mj_specrule_cfg[conf.init_params.special_rule])
    local rate_cfg = assert(mj_cfg.mj_rate_cfg[conf.init_params.rate_rule])
    mj_deal.set_rule_data(spec_rule_cfg, rate_cfg)
end

--状态切换
--@param:status 要切换到的状态
--@param:last_time 持续时间
local function change_game_status( status, last_time )
    if status then
        _game_status = status
    else
        _game_status = _game_status + 1
    end
    assert(_game_status <= MJ_STATUS.MAX_STATUS)
    _last_timer_start = skynet.now()
end

--检查当前状态
local function check_status( status )
    return _game_status == status
end

-- local function init_origin_wall( ... )
--  --   _origin_wall, _builded_tiles = mj_build.build_mj_card(SHIFTER1, 1)
--     -- _origin_wall = _origin_wall or {}

--     -- for _,v in pairs(MJ_TILE) do
--     --     for tile,_ in pairs(v) do
--     --         for i=1, 4 do
--     --             table.insert(_origin_wall, tile)
--     --         end
--     --     end
--     -- end
-- end

local function double_shifter(tmp)
    if tmp < 40 then
        if (tmp + 1)%10 ~= 0 then
            return tmp + 1
        else
            return math.floor(tmp/10)*10 + 1
        end
    else
        if tmp + 2 <= 47 or (tmp + 2 <= 55 and tmp > 47) then
            return tmp + 2
        elseif tmp == 55 then
            return 41
        else
            return 51
        end
    end
end

local function random_shifter()
    local tmp_card
    local card_type = math.random(3*9)
    if base_rule_cfg.fengpai > 0 then
        card_type = math.random(3*9+7)
    end

    if card_type <= 9 then
        tmp_card = 10 + card_type
    elseif card_type <= 18 then
        tmp_card = 20 + card_type - 9
    elseif card_type <= 27 then
        tmp_card = 30 + card_type - 18 
    elseif card_type <= 31 then
        tmp_card = 40 + ((card_type - 27) * 2) - 1
    else
        tmp_card = 50 + ((card_type - 31) * 2) - 1
    end
    return tmp_card
end

local function confirm_shifter()
    if _play_type_info and _play_type_info.shifter_type then
        if _play_type_info.shifter_type == 1 then
            SHIFTER1 = 55       --白板做鬼
        elseif _play_type_info.shifter_type == 2 then
            SHIFTER1 = random_shifter()
        elseif _play_type_info.shifter_type == 3 then
            local tmp_card = random_shifter()
            SHIFTER1 = double_shifter(tmp_card)
            SHIFTER2 = double_shifter(SHIFTER1)
        end
    end
    SHIFTER1 = SHIFTER1 or 0
    LOG_DEBUG("shifter1[%s] shifter2[%s]", tostring(SHIFTER1), tostring(SHIFTER2))

    mj_deal.set_deal_shifter(SHIFTER1, SHIFTER2)
end

--洗牌
local function build_wall()
    local origin_wall
    origin_wall, _builded_tiles = mj_build.build_mj_card(SHIFTER1, SHIFTER2, _fengpai)
--    PRINT_T(_builded_tiles)
    local len = #origin_wall
    -- luadump(origin_wall,"origin_wall")
    _wall = {}
    for i=1,len do
        local j = math.random(1, i)
        if i ~= j then
            _wall[i] = _wall[j]
        end

        _wall[j] = origin_wall[i]
    end
    -- luadump(_wall,"_wall")
-----------------------------test---------------------------
    -- -- 1号出5筒 2号吃 3号碰 4号胡
    -- local test_wall = { 19,19,19,19,19,
    --                     11,11,12,12,14,14,15,15,17,17,18,18,19,    --4号
    --                     11,11,12,12,14,14,15,15,17,17,18,18,19,    --3号
    --                     11,11,12,12,14,14,15,15,17,17,18,18,19,    --2号
    --                     11,11,12,12,14,14,15,15,17,17,18,18,19,}    --1号
    -- for i=1,#test_wall do
    --     osapi.tinsert(_wall, test_wall[i])
    -- end
------------------------------------------------------------
    
end

local function check_seat(seatid)
    if not seatid or seatid < 1 or seatid > _game_cfg.max_player then
        LOG_ERROR("illegal seatid[%s]!", tostring(seatid))
        return
    end
    if _players_sit[seatid] then
        LOG_ERROR("There is someone[%d] on the seat[%d]", _players_sit[seatid].uid, seatid)
        return
    end
    if _has_start then
        LOG_ERROR("game is start. cannot change seat")
        return 
    end

    return true
end

local function cost_money( p )
    --AA制坐下就扣费
    if not p.hascost and _pay_type == 1 then
        local cost = _game_cfg.price[_pay_type]
        if not cost then
            LOG_ERROR("it must be have price")
            return "game.resSitDown", { uid = p.uid, seatid = -1 }
        end
        -- local ok, result = pcall(p.call_userdata, p, "sub_gold", p.uid, cost, 2001)
  --       if not ok or not result then
  --           LOG_ERROR("sub gold faild")
  --           return "game.SitdownNtf", { uid = p.uid, seatid = -1 }
  --       end
        LOG_DEBUG("player[%d] sitdown and sub_gold[%d]", p.uid, cost)
        p.hascost = true
    end
    return true
end

--分局数据
local function init_round_data()
    for k,p in pairs(_players_sit) do
        p.end_score = 0
        p.horse_score = 0
        p.gang_score = 0
        p.win_fan = {}

        p.re_ready = 0

        p.tiles = nil
        p.hold_tiles = nil
        p.discards = nil

        p.last_draw_tile = nil
        p.qianggang_seatid = nil
        p.gangbaoquanbao_seatid = nil
        p.auto_out_cnt = 0
        p.gold_change = 0
        p.chipengRecord = {0,0,0,0} --吃碰每个人的次数记录
        p.noPeng = 0 --不能碰的牌
        p.noDeal = 0 --不能出的牌
    end

    _last_discard_seatid = nil
    _last_discard_tile = nil
    _discard_cnt = 0
    _qishouhu = true
    _qianggang_info = nil
    _qiangminggang_info = nil

    _last_hit_tiles = nil
 --   _prior_player = nil
    _builded_tiles = nil
 --   _origin_wall = nil
    _win_tiles = nil
    for k,v in pairs(_wall) do
        _wall[k] = nil
    end
    _dices = nil
    _last_game_start = nil
    _win_card = nil
    _win_type = nil
    _re_ready_count = 0
    _opt_seatid = nil
    _last_winners = nil
    _last_losers = nil
    _is_game_end = false
--    LOG_WARNING("init_round_data")
end

local function init_scores( ... )
    _current_scores = {}
    for i=1,#_players_sit do
        osapi.tinsert(_current_scores, {
            seatid = i,
            end_score = 0,
            gang_score = 0,
            horse_score = 0,
            genzhuang_score = 0,
            lianzhuang_score = 0,
        })
    end
end

local function init_player_info(p)
--    LOG_WARNING("init_player_info [%d]", p.uid)

    p.an_gang = 0
    p.ming_gang = 0
    p.peng_gang = 0

    p.fire = 0
    p.score = 0
    p.tiles = nil
    p.hold_tiles = nil
end

local function set_drow_reverse(id)
    _drow_reverse = true
    _drow_reverse_uid = id
end

local function clear_drow_reverse()
    _drow_reverse = nil
    _drow_reverse_uid = 0
end

local function clear_claim_players()
    for i,_ in ipairs(_claim_players_new) do
        _claim_players_new[i] = nil
    end
end

local function check_start()
    if _has_start then return end
  
    if table.len(_players_sit) ~= _game_cfg.max_player then return end
 --   LOG_DEBUG("检查游戏是否能开始")
   
    for _, p in pairs(_players_sit) do
        if p.ready ~= 1 then
            return
        end
    end

    return true
end

local function get_next_seatid(seatid)
    return (seatid + 1) <= _game_cfg.max_player and (seatid + 1) or 1
end

--获取庄位 随机庄
local function get_banker_seatid()
    -- if not _last_banker_seatid then
    --     return assert(_players[_owner].seatid)
    -- end
    -- if _last_winners and _last_winners[1] and _last_winners[1] == _last_banker_seatid then
    --     return _last_banker_seatid
    -- end

    -- return get_next_seatid(_last_banker_seatid)
    local randnum = RAND_NUM(1,100)
    if randnum <= 25 then
        return 1
    elseif randnum <= 50 then
        return 2
    elseif randnum <= 75 then
        return 3
    elseif randnum <= 100 then
        return 4
    end
end

--下一个操作的玩家座位号
local function get_next_opter()
    if not _opt_seatid then
        return _banker_seatid
    end
    return get_next_seatid(_opt_seatid)
end

--丢骰子
local function random_dices()
    _dices = {}
    for i=1,2 do
        osapi.tinsert(_dices, math.random(6))
    end
end

--统计癞子数量
local function cal_shifter_cnt( tiles )
    local cnt = 0
    for _,v in ipairs(tiles) do
        if v == SHIFTER1 or v == SHIFTER2 then
            cnt = cnt + 1
        end
    end
    return cnt
end

--检查明杠
local function check_light_gang(p)
    if not p or not p.hold_tiles then return end

    local kong
    for _,v in ipairs(p.hold_tiles) do
        if v.opttype == OPT_TYPE.PENG then
            if p.last_draw_tile == v.cards[1] then
                kong = kong or {}
                table.insert(kong, p.last_draw_tile)
                break
            end
        end
    end
    return kong
end

local function draw_tile(reverse)
    local total_tile_num = #_wall
    LOG_DEBUG("牌堆剩余数量:"..total_tile_num..",流局牌数量:".._liuju_num)
    if total_tile_num <= _liuju_num then --达到流局牌数量
        return
    end
    if _opt_seatid then
        local player = _players_sit[_opt_seatid] 
        local num = 0
        if player.ctrlinfo and next(player.ctrlinfo) then
            --赢
            if player.ctrlinfo.ctrltype == 2 then
                if player.ctrlinfo.ctrlrate >= 90 then
                    num = math.random(60,70)
                elseif player.ctrlinfo.ctrlrate >= 75 then
                    num = math.random(40,50)
                elseif player.ctrlinfo.ctrlrate >= 60 then
                    num = math.random(30, 40)
                else
                    num = math.random(5, 30)
                end
            end
        end
        -- if player.ctrl_cnt and player.ctrl_cnt > 50 then
        --     if player.ctrl_cnt >= 90 then
        --         num = math.random(60,70)
        --     elseif player.ctrl_cnt >= 75 then
        --         num = math.random(40,50)
        --     elseif player.ctrl_cnt >= 60 then
        --         num = math.random(30, 40)
        --     else
        --         num = math.random(5, 30)
        --     end
        -- end
--        LOG_WARNING("random num[%d] total_tile_num[%d]", num, total_tile_num)
        if num > 0 and total_tile_num <= num then
            for _,tile in ipairs(_win_tiles[player.uid]) do
                local index = osapi.tindexof(_wall, tile)
                table.removebyvalue(_win_tiles[player.uid], tile)
                if index then 
                    return osapi.tremove(_wall, index)
                end
            end
        end
    end
    
    if reverse then
        return osapi.tremove(_wall, 1)
    else
        return osapi.tremove(_wall)
    end
end

--移除马牌
local function remove_horse_tiles()
    _horse_tiles = {}
    _horse = _play_type_info.horse_type or 0
    local grap_cnt = 0
    if _horse and _horse > 0 then
        if _horse < 10 then
            grap_cnt = _horse 
        else
            grap_cnt = 1
        end

        for i=1, grap_cnt do
            osapi.tinsert(_horse_tiles, draw_tile(1))
        end
    end
--    PRINT_T(_horse_tiles)
end

--返回值  0不控制 1玩家 2机器人 这里需要做修改，不应该是抽水率来控制，应该改成库存控制，并且手动控制优先
local function get_winner_by_kickback( ... )
    if _isTaste then return 0 end
    if not _kickback or _kickback == 1 then
        return
    end

    local rate = math.random(1 ,100000)
    if _kickback < 1 then
        if rate < 100000 * (1 - _kickback) then
            return 2
        else
         --   LOG_DEBUG("全局控制本局不起效")
            return 0
        end
    else
        if rate < 100000 * (_kickback - 1) then
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
    for seatid,p in pairs(_players_sit) do
        if p.isrobot then
            osapi.tinsert(robot_pool,seatid)
        else
            osapi.tinsert(user_pool, seatid)
        end
    end
    
    if wtype == 1 then
        return user_pool[math.random(#user_pool)]
    else
        return robot_pool[math.random(#robot_pool)]
    end
end

local function set_order_card_num()
    local order_card_num = 6
    local someone_ctrled
    for _,p in pairs(_players_sit) do --这是单人控制
        if not _isTaste then
            if p.ctrlinfo and next(p.ctrlinfo) then
                local ctrlgold = (p.ctrlinfo.ctrlmaxgold or 10) - (p.ctrlinfo.ctrlnowgold or 0)
                if p.ctrlinfo.ctrltype  and ctrlgold and ctrlgold > 0 then 
                    if p.ctrlinfo.ctrltype == 2 then
                        if p.ctrlinfo.ctrlrate >= 100 then
                            order_card_num = 13
                        elseif p.ctrlinfo.ctrlrate >= 90 then
                            order_card_num = math.random(12, 13)
                        elseif p.ctrlinfo.ctrlrate >= 75 then
                            order_card_num = math.random(10, 12)
                        elseif p.ctrlinfo.ctrlrate >= 60 then
                            order_card_num = math.random(8, 10)
                        else
                            order_card_num = math.random(6, 8)
                        end
                    end
                end
                
               someone_ctrled = true
            end 
        end
        
        p.order_card_num = order_card_num
    end
    

    if someone_ctrled then return end --单人控制高于库存控制，如果单人控制了库存控制不生效
   
    if _has_robot then --这里应该是改成库存控制，需要有每个人每天赢钱多少，库存等数据来进行判断（20191.27）
        local winner_type = get_winner_by_kickback()
        if winner_type > 0 then
            local ctrl_winner = random_winner(winner_type)
            _players_sit[ctrl_winner].order_card_num = math.random(8, 12)
        end
    end
end

--发牌
local function deal_tiles()
    for _,p in pairs(_players_sit) do
        p.tiles = nil
    end
   
    --经过胜率排序后的players
 --   local players_orderd = {}
    local function dispatch_card_by_prior_rate(p)
        local cards = osapi.tremove(_builded_tiles)
        local p_tiles = mj_build.random_non_replacement(cards, p.order_card_num)--从造好的牌型里面去随机order_card_num张牌出来，默认6张

        for i=1, 13-#p_tiles do --从牌堆里面补齐13张
            osapi.tinsert(p_tiles, osapi.tremove(_wall))
        end
        _win_tiles = _win_tiles or {}
        _win_tiles[p.uid] = cards --剩余没有随机到的牌放进数组
        return p_tiles
    end

    set_order_card_num() --根据控制设置需要的牌张数，最大13，表示胜率100

    for k,v in ipairs(_players_sit) do
        v.tiles = dispatch_card_by_prior_rate(v)

        osapi.tsort(v.tiles)
        LOG_DEBUG("[%d] tiles[%s]", v.uid, table.concat( v.tiles, ","))
--        PRINT_T(v.tiles)
        v:send_msg(
            "game.resMJDealCard",
            {
                cards = v.tiles,
                banker = _banker_seatid,
                cardnum = #_wall,
                dices = _dices,
                shifter = {SHIFTER1, SHIFTER2}
            }
        )

    end
    
    --将胡牌所需的其他牌随机插入牌堆
    for uid, tiles in pairs(_win_tiles) do
        for _,tile in ipairs(tiles) do
            osapi.tinsert(_wall, math.random(#_wall), tile)
        end
    end

    table.clear(_request_deal)
    --_deal_tiles_time = 0
end

local function set_windetail_winfan(info)
    local win_detail = {}
    local win_fan = {}
    local flag 
    for k,v in pairs(info) do
        if k == HU_TYPE.PINGHU then
            flag = true
        elseif k == HU_TYPE.QINGYISE and _play_type_info.qingyise then
            flag = true
        elseif k == HU_TYPE.PENGPENGHU and _play_type_info.pengpenghu then
            flag = true
        elseif k == HU_TYPE.QIDUI and _play_type_info.qidui then
            flag = true
        elseif k == HU_TYPE.QINGQIDUI and (_play_type_info.qingyise or _play_type_info.qidui) then
            flag = true
        elseif k == HU_TYPE.HUNYISE and _play_type_info.hunyise then
            flag = true
        elseif k == HU_TYPE.HUNDUIDUI and (_play_type_info.hunyise or _play_type_info.pengpenghu) then
            flag = true
        elseif k == HU_TYPE.LONGQIDUI and _play_type_info.longqidui then
            flag = true
        elseif (k == HU_TYPE.TIANHU or k == HU_TYPE.DIHU) and _play_type_info.tiandihu then
            flag = true
        elseif k == HU_TYPE.SHISANYAO and _play_type_info.shisanyao then
            flag = true
        elseif k == HU_TYPE.SHIBALUOHAN or k == HU_TYPE.WUGUIJIABEI or k == HU_TYPE.ZIYIYE then
            flag = true
        end
        if not flag then
            v = 1
        end
        osapi.tinsert(win_detail, k)
        osapi.tinsert(win_fan, v)
        flag = false
    end
    return win_detail, win_fan
end


--连庄
local function check_lianzhuang()
    for seatid,p in ipairs(_players_sit) do
        if _last_banker_seatid and seatid == _banker_seatid and seatid == _last_banker_seatid then
            p.lianzhuang_cnt = (p.lianzhuang_cnt or 0) + 1
            --连庄封顶
            p.lianzhuang_cnt = p.lianzhuang_cnt <= 3 and p.lianzhuang_cnt or 3
        else
            p.lianzhuang_cnt = 0
        end
        -- LOG_DEBUG("[%d] lianzhuang_cnt [%d]", p.uid, p.lianzhuang_cnt)
    end
end

--要求玩家打牌
local function ask_player_discard(p)
    _opt_seatid = p.seatid

    _last_timer_start = skynet.now()
 
    p:send_msg("game.resMJNotifyPlayerOpt", {seatid = _opt_seatid,timeout = TIME.OPT_TIME/100,opts = {{opttype=OPT_TYPE.DISCARD}}})
    _tapi.send_except("game.resMJNotifyPlayerOpt", {seatid=_opt_seatid, timeout=TIME.OPT_TIME/100, opts={}}, p.uid)
    
    --  LOG_DEBUG("ask_player_discard=".._opt_seatid..",id="..p.uid)
    change_game_status(MJ_STATUS.WAITING_PLAYER)
end

--获取两个玩家的距离
local function distance_between(a, b)
    return (b + _game_cfg.max_player - a) % _game_cfg.max_player
end

local function order_claims_players(ps)
    _claim_players_new = {}

    local function f(t, num_t, len)
        if len < 1 then
            return 1
        end

        if num_t.opttype > t[len].opttype then
            return f(t, num_t, len-1)
        elseif num_t.opttype == t[len].opttype then
            local num_dis = distance_between(4, num_t.seatid)
            local t_dis = distance_between(4, t[len].seatid)
            if num_dis > t_dis then
                return len + 1
            else
                return f(t, num_t, len - 1)
            end
        else
            return len + 1
        end
    end
    
    for seatid, data in pairs(ps) do
        for i,v in ipairs(data) do
            if #_claim_players_new > 0 then
                local index = f(_claim_players_new, {opttype=v.opttype, seatid=seatid}, #_claim_players_new)
                osapi.tinsert(_claim_players_new,index, {seatid=seatid, opttype=v.opttype, cards = v.cards})
            else
                osapi.tinsert(_claim_players_new, {seatid = seatid, opttype = v.opttype, cards = v.cards})
            end
        end
    end
 --   PRINT_T(_claim_players_new)
end

--摸牌
local function player_drow()
    _opt_seatid = _opt_seatid or get_next_seatid(_last_discard_seatid)
    local p = _players_sit[_opt_seatid]
    local tile
    --测试用
    if _gm_next_card[p.uid] then
        tile = _gm_next_card[p.uid]
        _gm_next_card[p.uid] = nil
    else
        tile = draw_tile(_drow_reverse)
    end
    --摸牌类型 正常摸牌还是杠后补牌
    local draw_type = _drow_reverse and OPT_TYPE.DRAW_REVERSE or OPT_TYPE.DRAW
    LOG_DEBUG("player_drow player[%d] seatid[%d] tile[%s]", p.uid, _opt_seatid, tostring(tile)) 
    if not tile then
        _win_type = WIN_TYPE.NOWINERS
        change_game_status(MJ_STATUS.GAME_END)
        return
    end
    
    p.last_draw_tile = tile
    --摸牌成功清除不能出牌和不能碰牌
    p.noPeng = 0
    p.noDeal = 0

    p:send_msg("game.resMJDrawCard", {card = tile, cardnum = #_wall,seatid = p.seatid})
    _tapi.send_except("game.resMJDrawCard", {cardnum = #_wall,seatid = p.seatid}, p.uid)
    _tapi.send_to_all("game.resMJNotifyPlayerOpt", {seatid = p.seatid,timeout = TIME.OPT_TIME/100,opts = {{opttype=OPT_TYPE.DISCARD}}})
    
    --自摸检测
    if mj_deal.check_win_all(p.tiles, tile) then
        local claims = {}
        LOG_DEBUG("player[%d] can zimo", p.seatid)
        claims[p.seatid] = claims[p.seatid] or {}
        local opts = {opttype = OPT_TYPE.WIN, cards = {tile}}
        osapi.tinsert(claims[p.seatid], opts)
        if next(claims) then
            order_claims_players(claims)
        end
        change_game_status(MJ_STATUS.WAITING_CLAIM)
    else
        change_game_status()
    end
end

--随机出一个赢家
-- local function random_gamewinner( ... )
--     for seatid, p in pairs(_players_sit) do
--         p.ctrlinfo = nil
--         if not p.isrobot then
--             p.ctrlinfo = p.ctrlinfo or {}
--             p.ctrlinfo.ctrlrate = 100
--             p.ctrlinfo.ctrltype = 2
--             return 
--         end
--     end
--     local index = math.random(4)
--     for seatid, p in pairs(_players_sit) do
--         if seatid == index then
--             p.ctrlinfo = p.ctrlinfo or {}
--             if p.isrobot then
--                 p.ctrlinfo.ctrlrate = 100
--                 p:send_msg("robot.winner_robot")
--             else
--                 p.ctrlinfo.ctrlrate = 95
--             end
--             p.ctrlinfo.ctrltype = 2
--         --    LOG_WARNING("winner [%d]", p.uid)
--             break
--         end
--     end
-- end

--[[
    @desc: 检测是否有机器人
    author:{author}
    time:2019-01-01 20:20:49
    @return:
]]
local function has_robot()
    if _isUseGold then
        for _,p in pairs(_players_sit) do
            if p.isrobot then
                _has_robot = true
                break
            end
        end
    end
end

local function new_game()
    -- TODO clear round info
    _liuju_num = 14
    init_scores()
    -- confirm_shifter()
    build_wall()
    has_robot()
    
    _banker_seatid = get_banker_seatid()
--    LOG_WARNING("banker seatid [%d]", _banker_seatid)
    check_lianzhuang()
    _last_banker_seatid = _banker_seatid
    _opt_seatid = get_next_opter()
    random_dices()
--    _genzhuang = true
    -- _tapi.send_to_all("game.StartRound", { round = _played_times + 1, total = _max_times })
    --测试用
    -- if _isUseGold then
    --     random_gamewinner()
    -- end
--    deal_tiles()
    -- remove_horse_tiles()
    -- local win_tiles_num = 0
    -- for k,v in pairs(_win_tiles) do
    --     win_tiles_num = win_tiles_num + #v
    -- end
    local msg = {
        banker = _banker_seatid,
        leftCard = #_wall,
        dices = _dices,
        shifter = {SHIFTER1, SHIFTER2},
    }

    _deal_tiles_time = osapi.os_time() + WAIT_DEAL
end

-----------------------------------------------------------

--返回暗杠
local function get_an_gang(p)
    local an_gang = {}
    if not p.hold_tiles then
        return  an_gang
    else
        for _,v in pairs(p.hold_tiles) do
            if v.opttype == OPT_TYPE.BLACK_GANG then
                osapi.tinsert(an_gang, v.cards[1])
            end
        end
    end
    
    return an_gang
end

--检查手中是否有这张牌 有则返回位置
local function has_tile(t, tile)
    if type(tile) == "table" then
        local i = 1
        local result
        for k,v in ipairs(t) do
            if v == tile[i] then
                result = result or {}
                result[i] = k
                i = i + 1
            end
        end
        return result
    else
        for k,v in pairs(t) do
            if v == tile then
                return k
            end
        end
    end 
end

local function insert_last_draw_tile(p)
    if p.last_draw_tile then
        if #p.tiles == 0 or p.last_draw_tile >= p.tiles[#p.tiles] then
            osapi.tinsert(p.tiles, p.last_draw_tile)
        else
            for i=1,#p.tiles do
                if p.last_draw_tile <= p.tiles[i] then
                    osapi.tinsert(p.tiles, i, p.last_draw_tile)
                    break
                end
            end
        end
    end
    p.last_draw_tile = nil
end

--[[
    @desc: 暗杠分数
    author:{author}
    time:2019-02-08 17:50:13
    --@p: 
    @return:
]]
local function set_an_gang_score(p)
    local score_change = 0
    if _isUseGold then
        score_change = base_rule_cfg.an_gang * _base_score
    end

    _players_sit[p.seatid].gang_score = _players_sit[p.seatid].gang_score + score_change * (_game_cfg.max_player - 1)
    for k,v in pairs(_players_sit) do
        if v.seatid ~= p.seatid then
            v.gang_score = v.gang_score - score_change
        end
    end
    LOG_DEBUG("anganglose==".._players_sit[lose_seatid].gang_score)
    LOG_DEBUG("angangwin==".._players_sit[p.seatid].gang_score)
end

--[[
    @desc: 明杠分数
    author:{author}
    time:2019-02-08 17:49:05
    --@p:
	--@lose_seatid: 
    @return:
]]
local function set_ming_gang_score(p, lose_seatid)
    local score_change = 0
    if _isUseGold then
        score_change = base_rule_cfg.ming_gang * _base_score
    end
    _players_sit[p.seatid].gang_score = _players_sit[p.seatid].gang_score + score_change
    _players_sit[lose_seatid].gang_score = _players_sit[lose_seatid].gang_score - score_change
    LOG_DEBUG("minglose==".._players_sit[lose_seatid].gang_score)
    LOG_DEBUG("mingwin==".._players_sit[p.seatid].gang_score)
end

--[[
    @desc: 补杠分数，碰的谁的牌谁给钱，由于跟明杠一样逻辑，直接调用，留这个函数预防修改规则
    author:{author}
    time:2019-02-08 17:47:05
    --@p:
	--@lose_seatid: 
    @return:
]]
local function set_peng_gang_score(p,lose_seatid)
    set_ming_gang_score(p, lose_seatid)
end



--[[
    @desc: 找出最大的数字
    author:{author}
    time:2019-01-28 23:30:53
    @return:
]]
local function get_max_num(list)
    if type(list) ~= "table" then
       return 0
    end
    local mnum = 0
    for k,v in pairs(list) do
        if v > mnum then
            mnum = v
        end
    end
    return mnum
end

--[[
    @desc: 吃碰杠移动手牌的函数
    author:{author}
    time:2018-12-31 21:58:27
    --@p: 玩家
	--@tiles: 操作的牌
	--@cnt: 操作的数量
	--@opttype: 操作的类型
    @return:
]]
local function player_move_tiles_to_hold(p, tiles, cnt, opttype)
    -- LOG_DEBUG("player move tiles to hold opttype = %s, cnt =%s", tostring(opttype), tostring(cnt))
    if not p or not tiles then 
        LOG_DEBUG("no player or no tiles p = %s", tostring(p))
        return 
    end

    -- if tiles[#tiles] ~= _last_discard_tile then 
        -- LOG_DEBUG("tiles last tile :%s is not equal to last discard tile:%s", tostring(tiles[#tiles]), _last_discard_tile)
        -- return end
    --记录手里是否有那张牌，用来判断臭吃规则
    local hasTilePos
    if opttype == OPT_TYPE.CHI then
        hasTilePos = has_tile(p.tiles,_last_discard_tile)
        if hasTilePos then
            LOG_DEBUG("手里有吃的牌=="..hasTilePos)
        end
    end

    if #tiles == 1 then
        for i=1,cnt-2 do
            osapi.tinsert(tiles, _last_discard_tile)
        end
    else
        local pos = has_tile(tiles, _last_discard_tile)
        if not pos then
            LOG_WARNING("player move tiles to hold error no pos 1111")
            return
        end
        osapi.tremove(tiles, pos)
    end
    
    local pos = has_tile(p.tiles, tiles)
   
    if not pos or #pos ~= cnt-1 then 
        LOG_WARNING("player move tiles to hold error no pos 2222")
        return 
    end

    local cards = {}
    for i=1,cnt-1 do
        local t = osapi.tremove(p.tiles, pos[i]-i+1)
        osapi.tinsert(cards, t)
    end

    local last_p = _players_sit[_last_discard_seatid]
    if not last_p then
        LOG_WARNING("no _last_discard_ player")
        return
    end

    if last_p.discards[#last_p.discards] ~= _last_discard_tile then
        LOG_WARNING("last discard player's last discard tile:%s, _last_discard_tile:%s", tostring(last_p.discards[#last_p.discards]), tostring(_last_discard_tile))
        return
    end

    osapi.tremove(last_p.discards)
    osapi.tinsert(cards, _last_discard_tile)

    p.hold_tiles = p.hold_tiles or {}
    osapi.tinsert(p.hold_tiles, {cards       = cards,
                                opttype     = opttype,
                                fromSeatid = _last_discard_seatid})
   
    if opttype == OPT_TYPE.LIGHT_GANG then
        p.ming_gang = p.ming_gang + 1
    elseif opttype == OPT_TYPE.PENG_GANG then
        p.peng_gang = p.peng_gang + 1
    elseif opttype == OPT_TYPE.BLACK_GANG then
        p.an_gang = p.an_gang + 1

    end

    --记录吃碰次数
    p.chipengRecord[_last_discard_seatid] = p.chipengRecord[_last_discard_seatid] + 1
    --找出当前最大的吃碰次数
    local maxCpnum = get_max_num(p.chipengRecord)

    _tapi.send_to_all(
        "game.resMJPlayerOpt",
        {
            opts = {opttype = opttype,cards = cards},
            fromSeatid = _last_discard_seatid,
            toSeatid = p.seatid,
            areaid = TILE_AREA.HOLD,
            optcard = _last_discard_tile,
            handnum = #p.tiles,
            cpnum = maxCpnum
        }
    )

    if opttype == OPT_TYPE.CHI and hasTilePos then --操作成功记录不能出的牌
        p.noDeal = _last_discard_tile
    end

    return true
end



--出牌
local function discard(p, tile)
    if not p or not p.tiles then 
        LOG_DEBUG("player discard not player or not tiles")
        return 
    end
    assert(p.seatid == _opt_seatid, "player[%d] seatid not equal cur opt seatid")

    if not tile then
        tile = p.last_draw_tile or p.tiles[#p.tiles]
    end

    if tile == p.last_draw_tile then
        p.last_draw_tile = nil
    else
        local pos = has_tile(p.tiles, tile)
        if not pos then 
            luadump(p.tiles,"位置:"..p.seatid)
            LOG_DEBUG("player[%d] discard[%s] error pos is nil", p.uid, tostring(tile))
            return 
        end

        -- LOG_DEBUG("player[%d] discard tile[%s]", p.uid, TILE[tile])
        osapi.tremove(p.tiles, pos)
        insert_last_draw_tile(p)
    end
    clear_drow_reverse()
    p.discards = p.discards or {}
    osapi.tinsert(p.discards, tile)

    -- if _genzhuang and _last_discard_tile and _last_discard_tile ~= tile then
    --     _genzhuang = false
    -- end
    _last_discard_tile = tile
    _last_discard_seatid = p.seatid
    local msg = {
        opts = {opttype = OPT_TYPE.DISCARD,cards = {tile}},
        fromSeatid = p.seatid,
        toSeatid = p.seatid,
        areaid = TILE_AREA.DISCARD,
        optcard = tile,
        handnum = #p.tiles
    }

--    PRINT_T(msg)
    _tapi.send_to_all("game.resMJPlayerOpt", msg)

    _discard_cnt = _discard_cnt + 1
    -- if _genzhuang and _discard_cnt > 4 then
    --     _genzhuang = false
    -- end
    if _qishouhu and _discard_cnt >= 4 then
        _qishouhu = false
    end
    _opt_seatid = get_next_seatid(_opt_seatid)
    -- LOG_DEBUG("player[%d] seatid[%d] discard[%d]", p.uid, p.seatid, tile)
    p.minggang_seatid = nil
    change_game_status()
end

--暗杠
local function player_an_gang(p, tile)
    if not p or p.seatid ~= _opt_seatid then
        LOG_DEBUG("not p or p.seatid[%d] ~= _opt_seatid[%d]", p.seatid or -1, _opt_seatid or -1)
        return 
    end
    --癞子不能吃碰杠
    -- if (SHIFTER1 and tile == SHIFTER1) or (SHIFTER2 and tile == SHIFTER2) then
    --     LOG_WARNING("an gang faild [%d] is shifter.", tile)
    --     return 
    -- end
    local tiles_cnt = 4
    if p.last_draw_tile == tile then
        tiles_cnt = 3
        p.last_draw_tile = nil
    end
    LOG_DEBUG("tile[%d]", tile)
    local n = 0
    for i,v in ipairs(p.tiles) do
        if v == tile then
            n = n + 1
            if n == tiles_cnt then
                for j=1,tiles_cnt do
                    osapi.tremove(p.tiles, i-tiles_cnt+1)
                end
                break
            end
        end
    end
   
    if n ~= tiles_cnt then 
        LOG_DEBUG("player[%d] angang faild n[%d], tiles_cnt[%d]", p.uid, n, tiles_cnt)
        return 
    end

    local cards = {tile, tile, tile, tile}

    p.hold_tiles = p.hold_tiles or {}
    osapi.tinsert(
        p.hold_tiles,
        {
            cards = cards,
            opttype = OPT_TYPE.BLACK_GANG,
            fromSeatid = p.seatid
        }
    )

    _tapi.send_to_all(
        "game.resMJPlayerOpt",
        {
            opts = {opttype = OPT_TYPE.BLACK_GANG,cards = cards},
            fromSeatid = p.seatid,
            toSeatid = p.seatid,
            areaid = TILE_AREA.HOLD,
            handnum = #p.tiles,
            optcard = tile
        }
    )
    
    insert_last_draw_tile(p)

    p.an_gang = p.an_gang + 1
    _liuju_num = _liuju_num + 2

    LOG_DEBUG("player[%d] an gang card[%d]", p.uid, tile)
    set_drow_reverse(p.uid)
    set_an_gang_score(p)
    change_game_status(MJ_STATUS.PLAYER_OPT)
end

--抢杠胡
local function check_qiangganghu(p, tile)
--    if base_rule_cfg.qiangganghu and base_rule_cfg.qiangganghu > 0 then
    if _play_type_info.qiangganghu then
        LOG_DEBUG("qiangganghu")
        local claims = {}
        local opts
        for k, player in pairs(_players_sit) do
            if player.uid ~= p.uid then
                if mj_deal.check_win_one(player.tiles, tile) then
                    LOG_DEBUG("player[%d] can qiangganghu", player.uid)
                    claims[player.seatid] = claims[player.seatid] or {}
                    opts   = {opttype  = OPT_TYPE.QIANG_GANG_WIN, cards = {tile}}
                    osapi.tinsert(claims[k], opts)
                end
            end
        end
        if next(claims) then
            order_claims_players(claims)
        end
    end
end

--抢明杠
local function check_qiangminggang(p, tile)
--    if base_rule_cfg.qiangminggang and base_rule_cfg.qiangminggang > 0 then
    if _play_type_info.qiangganghu then
        if not p or not tile then 
            LOG_DEBUG("no player or no tiles p = %s, tiles = %s", tostring(p), tostring(tiles))
            return 
        end
    --    LOG_WARNING("qiangminggang")
        local claims = {}
        local opts
        for k, player in pairs(_players_sit) do
            if player.uid ~= p.uid then
                if mj_deal.check_win_one(player.tiles, tile) then
                    LOG_DEBUG("player[%d] can qiangganghu", player.uid)
                    claims[player.seatid] = claims[player.seatid] or {}
                    opts   = {opttype  = OPT_TYPE.QIANG_GANG_WIN, cards = {tile}}
                    osapi.tinsert(claims[k], opts)
                end
            end
        end
        if next(claims) then
            order_claims_players(claims)
            return true
        end
    end
end

--玩家操作补(碰)杠，要等待枪杠信息，如果没有人抢才算杠成功
local function player_peng_gang(p, t)
    if not p or p.seatid ~= _opt_seatid or not p.hold_tiles then 
        LOG_DEBUG("not p or p.seatid[%d] ~= _opt_seatid[%d]", p.seatid or -1, _opt_seatid or -1)
        return 
    end

    -- --癞子不能吃碰杠
    -- if (SHIFTER1 and t == SHIFTER1) or (SHIFTER2 and t == SHIFTER2) then
    --     LOG_WARNING("an gang faild [%d] is shifter.", t)
    --     return 
    -- end

    for i,v in ipairs(p.hold_tiles) do
        if v.opttype == OPT_TYPE.PENG and v.cards[1] == t then
            if p.last_draw_tile ~= t then
                local pos = has_tile(p.tiles, t)
                if not pos then return end
            end
        end
    end
--    LOG_WARNING("player[%s] peng gang", p.nickname)
    _qianggang_info = nil
    _qianggang_info = {player = p, tile = t}
    check_qiangganghu(p, t)
    change_game_status(MJ_STATUS.WAITING_CLAIM)
end

local function peng_gang()
    local p, t = _qianggang_info.player, _qianggang_info.tile
    _qianggang_info = nil
    for i,v in ipairs(p.hold_tiles) do
        if v.opttype == OPT_TYPE.PENG and v.cards[1] == t then
            if p.last_draw_tile == t then
                p.last_draw_tile = nil
            else
                local pos = has_tile(p.tiles, t)
                if not pos then return end
                osapi.tremove(p.tiles, pos)
            end

            v.opttype = OPT_TYPE.PENG_GANG
            osapi.tinsert(v.cards, t)

            --碰的时候已经记录了不用再次记录次数
            --找出当前最大的吃碰次数
            local maxCpnum = get_max_num(p.chipengRecord)
            
            _tapi.send_to_all(
                "game.resMJPlayerOpt",
                {
                    opts = {opttype = OPT_TYPE.PENG_GANG,cards = v.cards},
                    fromSeatid = v.fromSeatid,
                    toSeatid = p.seatid,
                    areaid = TILE_AREA.HOLD,
                    handnum = #p.tiles,
                    optcard = t,
                    cpnum = maxCpnum
                }
            )

            
            insert_last_draw_tile(p)

            -- if check_win_kong(t) then
            --     _game_status = GAME_STATUS.GAME_END
            -- else
            p.peng_gang = p.peng_gang + 1
            _liuju_num = _liuju_num + 2
            set_peng_gang_score(p,v.fromSeatid)
            --_game_status = GAME_STATUS.PLAYER_OPT
            set_drow_reverse(p.uid)
            change_game_status(MJ_STATUS.PLAYER_OPT)
            --end
            break
        end
    end
end


--吃
local function player_chi(p, tiles)
    if not p or p.seatid ~= _last_discard_seatid %4 + 1 then 
        LOG_DEBUG("player chow is not next of opt seat seatid:%s opt seatid = %s ", tostring(p.seatid), tostring(_last_discard_seatid))
        return 
    end
    if player_move_tiles_to_hold(p, tiles, 3, OPT_TYPE.CHI) then

        ask_player_discard(p)
    end
end

--碰
local function player_peng(p, tile)
    if player_move_tiles_to_hold(p, {tile}, 3, OPT_TYPE.PENG) then

        ask_player_discard(p)
    end
end

--明杠
local function player_ming_gang( p, tile )
    if player_move_tiles_to_hold(p, {tile}, 4, OPT_TYPE.LIGHT_GANG) then
        _opt_seatid = p.seatid
        p.ming_gang = p.ming_gang + 1
        p.minggang_seatid = _last_discard_seatid
        _liuju_num = _liuju_num + 2
        set_ming_gang_score(p, _last_discard_seatid)
        set_drow_reverse(p.uid)
        change_game_status(MJ_STATUS.PLAYER_OPT)
        -- check_win_kong(tile)                 --明杠不能抢杠胡
    end   
end

--自摸
local function player_win_all(p, qianggangtile)
    if (not qianggangtile and not check_status(MJ_STATUS.WAITING_PLAYER)) or (qianggangtile and not check_status(MJ_STATUS.WAITING_CLAIM_PLAYER)) then 
        LOG_WARNING("status error cur status[%d] need status[%d]", _game_status, MJ_STATUS.WAITING_PLAYER)
        return 
    end
    local win_tile = qianggangtile or p.last_draw_tile
    if not mj_deal.check_win_all(p.tiles, win_tile) then 
        LOG_DEBUG("server check win all faild! player[%d]", p.uid)
        return 
    end
  --  杠爆全包
    if p.minggang_seatid then
        LOG_WARNING("gangbaoquanbao_seatid")
        p.gangbaoquanbao_seatid = p.minggang_seatid
    end
    --抢杠全包
    if _qianggang_info then
        p.qianggang_seatid = _qianggang_info.player.seatid
    end
    if _qiangminggang_info then
        p.qianggang_seatid = _qiangminggang_info.player.seatid
    end 
    
    if base_rule_cfg.qianggangquanbao and base_rule_cfg.qianggangquanbao > 0 and _qianggang_info then
        p.qianggang_seatid = _qianggang_info.player.seatid
    end
    --天胡的判断
    local qishouhu_info
    if _qishouhu then
        if p.seatid == _banker_seatid then
            qishouhu_info = {tianhu = 1}
        end
    end
    local gangkaihua = (_drow_reverse_uid == p.uid)
    local detail_info = mj_deal.get_win_details(p.tiles, p.hold_tiles, win_tile, qishouhu_info) 
--    PRINT_T(detail_info)
    local win_detail, win_fan = set_windetail_winfan(detail_info)
    -- PRINT_T(detail_info)
    -- PRINT_T(win_detail)
    -- PRINT_T(win_fan)

    -- p.win = p.win + 1

    p.win_detail = win_detail
    p.win_fan = win_fan
    if gangkaihua then
        _win_type = WIN_TYPE.GANGSHANGKAIHUA
    elseif qianggangtile then
        _win_type = WIN_TYPE.GANG
    else
        _win_type = WIN_TYPE.OWN
    end
    
    _win_card = win_tile
    _lose_seatid = p.seatid
    --把赢的牌插入到赢的人手里
    osapi.tinsert(p.tiles,_win_card)
    table.clear(_last_winners)
    _last_winners = {p.seatid}
    _last_losers = {}
    for i,user in ipairs(_players_sit) do
        if i ~= p.seatid then
            user.win_fan = win_fan
            osapi.tinsert(_last_losers, i)
        end
    end
    --需要广播胡牌成功
    local msg = {
        opts = {
            opttype = OPT_TYPE.WIN,
            cards = {_win_card}
        },
        fromSeatid = p.seatid,
        toSeatid = p.seatid,
        handnum = #p.tiles,
        optcard = _win_card
    }
    _tapi.send_to_all("game.resMJPlayerOpt", msg)

    change_game_status(MJ_STATUS.GAME_END)
end

--点炮胡,需要测试一炮多响
function players_win(p)
    _is_game_end = true
    --地和判断
    local qishouhu_info
    if _qishouhu then
        if _last_discard_seatid == _banker_seatid then
            qishouhu_info = {dihu = 1}
        end
    end
    local detail_info = mj_deal.get_win_details(p.tiles, p.hold_tiles, _last_discard_tile,qishouhu_info)
    local win_detail, win_fan = set_windetail_winfan(detail_info)
    _last_winners = _last_winners or {}
    osapi.tinsert(_last_winners, p.seatid)
    p.win_detail = win_detail
    p.win_fan = win_fan

    local loser_tile = _last_discard_tile
    local loser = _players_sit[_last_discard_seatid]

    loser.fire = loser.fire + 1
    
    _last_losers = {_last_discard_seatid}
    _lose_seatid = _last_discard_seatid
    _win_type = WIN_TYPE.OTHER
    _win_card = loser_tile

    --把赢的牌插入到赢的人手里
    osapi.tinsert(p.tiles,_win_card)
    --一炮多响判断
    local pos = osapi.tindexof(_can_dian_player,p.seatid)
    if pos then
        osapi.tremove(_can_dian_player,pos)
    end
    --需要广播胡牌成功
    local msg = {
        opts = {
            opttype = OPT_TYPE.WIN,
            cards = {_win_card}
        },
        fromSeatid = _last_discard_seatid,
        toSeatid = p.seatid,
        handnum = #p.tiles,
        optcard = _win_card
    }
    _tapi.send_to_all("game.resMJPlayerOpt", msg)
    --如果胡牌的人都选择完了，改变状态
    if #_can_dian_player == 0 then
        change_game_status(MJ_STATUS.GAME_END)
    end
end

--询问玩家吃碰杠
local function ask_player_claim(seatid, info)
    local time = TIME.CLAIM_TIME
    -- if _opt_time_out > 0 then
    --     time = _opt_time_out
    -- end
    local timeout = time/100
    local p = _players_sit[seatid]
    p.info = info

    -- LOG_DEBUG("ask player[%s] claim seatid[%d]", p.nickname, seatid)
--    PRINT_T(info)
    local msg = {
        seatid  = seatid,
        timeout = timeout,
        opts    = info
    }
    _claim_cache_data = {seatid = seatid, opts = table.deepcopy(info)}
   luadump(msg,"询问玩家吃碰杠")
    p:send_msg("game.resMJNotifyPlayerOpt", msg)

    --通知其他玩家更新倒计时
    _tapi.send_except("game.resMJNotifyPlayerOpt", {seatid=-1, timeout=timeout, opts={}}, p.uid)
    --------------
end

local function tick_claim_player()
    local data = osapi.tremove(_claim_players_new, 1)
    _opt_seatid = data.seatid

    local info = {}
    osapi.tinsert(info, {opttype=data.opttype, cards=data.cards})
    for i=1,#_claim_players_new do
        if _claim_players_new[1].seatid == _opt_seatid then
            data = osapi.tremove(_claim_players_new, 1)
            osapi.tinsert(info, {opttype=data.opttype, cards=data.cards})
        else
            break
        end
    end
    ask_player_claim(_opt_seatid, info)
end

--按照玩家吃碰杠胡的优先级将玩家排序
local function insert_claim_player_in_order(p)
    _claim_players = _claim_players or {}
    local n = 1
    for i,v in ipairs(_claim_players) do
        n = i
        if p.order > v.order then
            --先按照优先级顺序排序
            break
        elseif p.order == v.order then
            distance_p = distance_between(_last_discard_seatid,p.seatid)
            distance_v = distance_between(_last_discard_seatid,v.seatid)
            if distance_p < distance_v then
                --再按照离打牌人的位置距离远近排序
                break
            end
        end
        n = n + 1
    end
    
    osapi.tinsert(_claim_players, n, p)
    -- table.sort(_claim_players, function(info1, info2)
 --     return info1.order > info2.order
 --    end)
end

--如果玩家选择了比自己最高优先级低的操作则重新排序
local function rerange_claim_players(claim_info, i)
    if not claim_info or not claim_info.opttype then return end
    local order = 0
    local opttype = claim_info.opttype
    if opttype < OPT_TYPE.PENG then
        order = ORDER.CHI
    elseif opttype < OPT_TYPE.WIN then
        order = ORDER.PENG
    elseif opttype == OPT_TYPE.WIN then
        order = ORDER.WIN
    end
    if order == claim_info.order then return end

    claim_info.order = order            --如果玩家选择了优先级低的操作， 他的优先级降低为低级的优先级
    osapi.tremove(_claim_players, i)
    insert_claim_player_in_order(claim_info)
end

--自动出牌
local function auto_discard()
    -- LOG_DEBUG("auto_discard cur_opt")
    assert(_opt_seatid)
    local p = _players_sit[_opt_seatid]
    -- LOG_DEBUG("auto_discard cur player[%d] seatid[%d]", p.uid, _opt_seatid)
    if not p.isrobot then
        p.auto_out_cnt = p.auto_out_cnt + 1
    end
    discard(p, p.last_draw_tile)
    if p.auto_out_cnt >= _auto_out_max and not is_trusteeship(p) then
        player_trusteeship(p, 1)
    end
end

--设置玩家吃碰杠胡的最高优先级
local function get_claim_player_order(info)
    local order = 0
    for i,v in ipairs(info) do
        if v.opttype == OPT_TYPE.CHI and order < ORDER.CHI then
            order = ORDER.CHI
        elseif v.opttype > OPT_TYPE.CHI and v.opttype < OPT_TYPE.WIN and order < ORDER.PENG then
            order = ORDER.PENG
        elseif v.opttype == OPT_TYPE.WIN and order < ORDER.WIN then
            order = ORDER.WIN
        end
    end

    return order
end

local function player_claim_give_up(seatid)
    -- local claim, i = find_claim_info(seatid)
    -- if not claim then return end

    -- if claim.order == ORDER_WIN then
    --     local p = _players_sit[seatid]
    --     p.no_win = true                     --弃胡要等下次摸牌才可以赢
    -- end

    -- table.remove(_claim_players, i)
    _opt_seatid = nil
    local p = _players_sit[seatid]
    p:send_msg("game.resMJPlayerOpt", { opts = {opttype = OPT_TYPE.PASS}})
    if _last_peng_card then --碰牌过圈规则
        p.noPeng = _last_peng_card
        _last_peng_card = nil
    end
    --一炮多响判断
    local pos = osapi.tindexof(_can_dian_player,seatid)
    if pos then
        osapi.tremove(_can_dian_player,pos)
        --如果胡牌的人都选择完了，改变状态,这里必须经过删的动作才能判断是否游戏结束，否则会有问题
        if #_can_dian_player == 0 then
            change_game_status(MJ_STATUS.GAME_END)
            return
        end
    end
    change_game_status(MJ_STATUS.WAITING_CLAIM)
end

--是否有人可以吃碰杠刚才打出的牌
function check_player_claim(now)
    ----just for now
 --   change_game_status(MJ_STATUS.PLAYER_OPT)
    -------------
    local claims = {}
    local opts
    _can_dian_player = nil
    _can_dian_player = {}
    for k,p in pairs(_players_sit) do
        if k ~= _last_discard_seatid then
            if CAN_DIAN and mj_deal.check_win_one(p.tiles, _last_discard_tile) then
                LOG_DEBUG("PLAYER : %s win one, last discard tile %s", tostring(p.uid), tostring(_last_discard_tile))
                claims[k] = claims[k] or {}
                opts   = {opttype  = OPT_TYPE.WIN, cards = {_last_discard_tile}}
                osapi.tinsert(claims[k], opts)
                osapi.tinsert(_can_dian_player,p.seatid)
            end

            if CAN_GANG and mj_deal.check_kong(p.tiles, _last_discard_tile) then
                claims[k] = claims[k] or {}
                opts = {opttype=OPT_TYPE.LIGHT_GANG, cards={_last_discard_tile}}
                osapi.tinsert(claims[k], opts)
            end

            if CAN_PENG and mj_deal.check_pung(p.tiles, _last_discard_tile) then
                claims[k] = claims[k] or {}
                opts = {opttype=OPT_TYPE.PENG, cards={_last_discard_tile}}
                osapi.tinsert(claims[k], opts)
                --记录不能碰的牌，过圈规则
                _last_peng_card = _last_discard_tile
            end
            
            if CAN_CHI and p.seatid == (_last_discard_seatid % _game_cfg.max_player + 1) then
                local chows = mj_deal.check_chow(p.tiles, _last_discard_tile)
                if chows and #chows > 0 then
                     claims[k] = claims[k] or {}
                     opts = {opttype=OPT_TYPE.CHI, cards=chows}
                     osapi.tinsert(claims[k], opts)
                end
            end
        end
    end
    if next(claims) then
        order_claims_players(claims)
    end
end

local function add_win(p)
    if _isUseGold and not _isTaste then
        p:call_userdata("add_win", _gameid, 1001)
    end
end

local function set_end_scores()
  
    local function cal_fan(t)
        local f = 0
        for _,v in ipairs(t) do
            f = f + v
        end
        if f == 0 then
            return 1
        end
        return f
    end

    --获取跟自己有吃碰3次关系的人
    local function get_chipeng_seats(p)
        local seatlist = {0,0,0,0}
        --检测自己吃碰其他人的
        for k,v in pairs(p.chipengRecord) do
            if k ~= p.seatid and v >= 3 then
                seatlist[k] = 1
            end
        end
        --检测自己的上家有没有吃碰自己3次
        local s1 = (p.seatid - 1 == 0) and 4 or (p.seatid - 1)
        local record = _players_sit[s1].chipengRecord
        if record[p.seatid] >= 3 then
            seatlist[s1] = 1
        end
        --检查自己的下家有没有吃碰自己3次
        s1 = (p.seatid + 1 == 5) and 1 or (p.seatid + 1)
        record = _players_sit[s1].chipengRecord
        if record[p.seatid] >= 3 then
            seatlist[s1] = 1
        end

        return seatlist
    end

    luadump(base_rule_cfg,"base_rule_cfg==")
    LOG_DEBUG("_base_score=".._base_score)
    --自摸:闲家自摸，所有闲家输底分*2，庄家输底分*3，庄家自摸所有闲家输底分*3
    if _win_type == WIN_TYPE.OWN or _win_type == WIN_TYPE.GANGSHANGKAIHUA then
        local widx = _last_winners[1]
        
        local fan = cal_fan(_players_sit[widx].win_fan) --赢家获得的总番数
        local winScore = 0
        --输赢分数
        luadump(_players_sit[widx].win_detail,"赢家获得的类型")
        luadump(_players_sit[widx].win_fan,"赢家获得的总番数")
        LOG_DEBUG("fan="..fan)

        -- 查看赢家和其他人的吃碰3次关系
        local seatlist = get_chipeng_seats(_players_sit[widx])
        luadump(seatlist,"自摸吃碰关系".._players_sit[widx].uid)
        --先检测是否有人可以包全场,分数乘以2，bu包杠分，没关系的人不用给分
        local cpcount = 0 --记录是否有人包分
        for k,v in pairs(seatlist) do
            if k ~= widx and v == 1 then
                cpcount = cpcount + 1
            end
        end
        
        if widx == _banker_seatid then --庄家赢了
            winScore = (base_rule_cfg.win_own + 1) * _base_score * fan --如果是庄家赢了
            for k,v in pairs(seatlist) do
                if k ~= widx then
                    if v == 1 then
                        local tmpScore = winScore * 2 * (_game_cfg.max_player - 1)
                        _players_sit[k].end_score = _players_sit[k].end_score - tmpScore
                        _players_sit[widx].end_score = _players_sit[widx].end_score + tmpScore
                    end
                end
            end

            if cpcount == 0 then --没有人包分，正常计算分数
                for k,v in pairs(_players_sit) do
                    if k ~= widx then
                        v.end_score = v.end_score - winScore
                        _players_sit[widx].end_score = _players_sit[widx].end_score + winScore
                    end
                end
            end
        else --闲家赢了
            local bankerAdd = 0
            for k,v in pairs(_players_sit) do
                if k ~= widx then
                    bankerAdd = (k == _banker_seatid and 1 or 0)
                    winScore = (base_rule_cfg.win_own + bankerAdd) * _base_score * fan
                    if cpcount > 0 and seatlist[k] == 1 then --有人包分
                        local tmpScore = winScore * 2 * (_game_cfg.max_player - 1)
                        v.end_score = v.end_score - tmpScore
                        _players_sit[widx].end_score = _players_sit[widx].end_score + tmpScore
                    elseif cpcount == 0 then --正常算分
                        v.end_score = v.end_score - winScore
                        _players_sit[widx].end_score = _players_sit[widx].end_score + winScore
                    end
                end
            end
        end
    elseif _win_type == WIN_TYPE.OTHER or _win_type == WIN_TYPE.GANG then --放炮
        -- 闲家点炮给闲家底分*3，闲家点炮给庄家底分*4，庄家点炮给闲家底分*4
        -- 如果点炮的人跟接炮的人有吃碰关系，输赢的分*2，同时其他跟接炮人有吃碰关系的都要给分
        local lose_score = 0
        local bankerAdd = 0
        for _,seatid in ipairs(_last_winners) do
            local winner = _players_sit[seatid]
            local fan = cal_fan(winner.win_fan)
            luadump(winner.win_detail,"放炮赢家获得的类型")
            luadump(winner.win_fan,"放炮赢家获得的总番数")
            LOG_DEBUG("放炮fan="..fan)
            bankerAdd = (seatid == _banker_seatid and 1 or 0)
            local tmpEndScore = (base_rule_cfg.win_other + bankerAdd) * _base_score * fan
            
            --获取跟赢家有吃碰关系的人的座位
            local seatlist = get_chipeng_seats(winner)
            luadump(seatlist,"点炮吃碰关系"..winner.uid)
            --其他跟赢家有3次关系的人也要输分给赢家
            for k,v in pairs(seatlist) do 
                if k ~= _last_losers[1] and v == 1 and k ~= seatid then
                    _players_sit[seatid].end_score = _players_sit[seatid].end_score + tmpEndScore
                    _players_sit[k].end_score = _players_sit[k].end_score - tmpEndScore
                end
            end
            --如果点炮的人跟赢家有吃碰3次关系，分数*2
            if seatlist[_last_losers[1]] == 1 then 
                tmpEndScore = tmpEndScore * 2
            end

            _players_sit[seatid].end_score = _players_sit[seatid].end_score + tmpEndScore
            lose_score = lose_score - tmpEndScore
        end
        _players_sit[_last_losers[1]].end_score = lose_score
    end

--     if _win_type == WIN_TYPE.OWN or _win_type == WIN_TYPE.GANG or _win_type == WIN_TYPE.GANGSHANGKAIHUA then
-- --        LOG_WARNING("set own win score")
--         local winner = _players_sit[_last_winners[1]]
--         add_win(winner)
--         --无鬼加倍
--         local shifter_cnt = cal_shifter_cnt(winner.tiles)
--         local fan = cal_fan(winner.win_fan) 
--         -- local wuguifan = 1
--         -- --只有平胡下才有无鬼加倍
--         -- if base_rule_cfg.wuguijiabei > 0 and _play_type_info.shifter_type > 0 and shifter_cnt == 0 then
--         --     wuguifan = 2
--         -- end
--         local gangshangkaihua = 0
--         if _win_type == WIN_TYPE.GANGSHANGKAIHUA and _play_type_info.gangshangkaihua then
--             gangshangkaihua = 2
--         end
-- --        LOG_WARNING("gangshangkaihua[%d], fan[%d]", gangshangkaihua, fan)
--         local win_score = (base_rule_cfg.win_own + gangshangkaihua + fan)* _base_score
        
--         if _current_scores[winner.seatid].horse_score < 0 then
--             win_score = win_score * math.abs(_current_scores[winner.seatid].horse_score)
--         else
--             win_score = win_score + _current_scores[winner.seatid].horse_score
--         end
-- --        PRINT_T(winner)
--         _current_scores[winner.seatid].end_score = (_game_cfg.max_player - 1) * win_score
--         local lose_score = 0
--         --策划说金币不要全包了
--         if not _isUseGold and winner.gangbaoquanbao_seatid then
--             _current_scores[winner.gangbaoquanbao_seatid].end_score = lose_score - _current_scores[winner.seatid].end_score
--         elseif not _isUseGold and winner.qianggang_seatid then
--             _current_scores[winner.qianggang_seatid].end_score = lose_score - _current_scores[winner.seatid].end_score
--         else
--             for _,seatid in ipairs(_last_losers) do
--                 _current_scores[seatid].end_score = lose_score - win_score
--             end
--         end
--     end
  
--     if _win_type == WIN_TYPE.OTHER then
--         local lose_score = 0
--         for _,seatid in ipairs(_last_winners) do
--             local winner = _players_sit[seatid]
--             local shifter_cnt = cal_shifter_cnt(winner.tiles)
--          --   local wuguifan = (base_rule_cfg.wuguijiabei > 0 and shifter_cnt == 0) and 2 or 1
--             local fan = cal_fan(winner.win_fan) 
--             _current_scores[seatid].end_score = base_rule_cfg.win_other * _base_score * fan 
--             lose_score = lose_score - base_rule_cfg.win_other * _base_score * fan 
--             add_win(winner)
--         end

--         _current_scores[_last_losers[1]].end_score = lose_score
--     end
end

local function set_horse_scores()
    if not next(_horse_tiles) then
        return 
    end
    --是否抓到马牌
    local function grap_horse_tile(tile, seatid)
        local tmp_seatid
        if tile < 40 then
            tmp_seatid = tile%10%4
        else
            tmp_seatid = (tile%10+1)/2
        end
        return seatid%4 == tmp_seatid%4
    end
    local function tile_2_score(tile)
        if tile < 40 then
            return tile%10
        elseif tile < 50 then
            return (tile%10+1)/2
        else
            return (tile%10+1)/2 + 4
        end
    end
    _last_hit_tiles = _last_hit_tiles or {}
    local seatid = _last_winners[1]
    local winner = _players_sit[seatid]
    --抓马分 为负数表示翻倍爆炸马
    local horse_score = 0
    if _horse < 10 then
        local base_horse = (base_rule_cfg.base_horse and base_rule_cfg.base_horse > 0) and _base_score or 1
        for _,tile in ipairs(_horse_tiles) do
            if grap_horse_tile(tile, seatid) then
                horse_score = horse_score + base_horse
                osapi.tinsert(_last_hit_tiles, tile)
            end
        end
    --加分爆炸马
    elseif _horse == 21 then
        if grap_horse_tile(_horse_tiles[1], seatid) then
            horse_score = horse_score + tile_2_score(_horse_tiles[1])
            osapi.tinsert(_last_hit_tiles, horse_tiles[1])
        end
    --翻倍爆炸马
    elseif _horse == 22 then
        if grap_horse_tile(_horse_tiles[1], seatid) then
            horse_score = tile_2_score(_horse_tiles[1]) * (-1)
            osapi.tinsert(_last_hit_tiles, horse_tiles[1])
        end
    end
    _current_scores[seatid].horse_score = horse_score

end

--抓码
-- local function get_bonus_tiles()
--     -- local hit_cnt_offset = 0
--     -- if #_last_winners == 1 then
--     --     local p = _players_sit[_last_winners[1]]
--     --     if check_shifter_tile(p.tiles) and p.last_draw_tile ~= SHIFTER_NUM then
--     --         hit_cnt_offset = _hit_offset
--     --     end
--     -- end
--      local bonus_tiles = {}
--     -- for i=1,_bonus_cnt+hit_cnt_offset do
--     --     table.insert(bonus_tiles, draw_hit_tile())
--     -- end

--     return bonus_tiles
-- end


local function excute_gold()
    -- local gold_changed = {win={},lose={}}
    -- for _, v in pairs(_current_scores) do
    --     local p = assert(_players_sit[v.seatid])   
    --     local score = v.end_score + v.genzhuang_score + v.lianzhuang_score
    --     if score > 0 then
    --         gold_changed.win[p.uid] = p.gold >= score and score or p.gold
    --     else
    --         gold_changed.lose[p.uid] = math.abs(score) >= p.gold and p.gold or math.abs(score)
    --     end
    -- end
    -- deal_gold(gold_changed)
    for k,v in pairs(_players_sit) do
        local change = v.end_score + v.gang_score
        
    end
end

local function game_end()
    _last_horse_tiles = nil
    LOG_DEBUG("game end win_type %s",tostring(_win_type))
    if _win_type == WIN_TYPE.OWN or _win_type == WIN_TYPE.OTHER 
    or _win_type == WIN_TYPE.GANG or _win_type == WIN_TYPE.GANGSHANGKAIHUA then
    --    _last_horse_tiles = get_bonus_tiles()
        --set_horse_scores()--抓马算法
        set_end_scores()
    end

    if _isUseGold then
        excute_gold()
    end
    --录像用
    local end_rst = {players = {}, score = {}}
    local resinfo = {}

    for i,v in ipairs(_current_scores) do
        local player = _players_sit[i]
        local info = {}
        info.seatid = player.seatid
        info.handcards = player.tiles
        info.opts = {}
        for k,cc in ipairs(player.hold_tiles or {}) do
            info.opts[k] = {opttype = cc.opttype,cards = cc.cards}
        end
        info.windetail = player.win_detail or {}
        info.winfan = player.win_fan or {}
        info.nickname = player.nickname
        info.uid = player.uid
        info.headimg = player.headimg
        info.winscore = player.end_score + player.gang_score
        info.gangscore = player.gang_score
        info.gold = player.gold

        -- osapi.tinsert(end_rst.players, _players_sit[v.seatid].nickname)
        -- local score = v.end_score + v.genzhuang_score + v.gang_score
        -- osapi.tinsert(end_rst.score, score)
        osapi.tinsert(resinfo,info)
    end
    local msg = {
        reslist = resinfo,
        winType = _win_type,
        wincard = _win_card,
        loseSeatid = _win_type == WIN_TYPE.OTHER and _lose_seatid or 0,
        horseTile = _horse_tiles,
        hitTiles = _last_hit_tiles or {},
        bankerSeatid = _banker_seatid
    }
    -- PRINT_T(msg)
    _tapi.send_to_all("game.resMJResult", msg)
    
    _current_scores = nil
    _has_robot = nil

    _played_times = _played_times + 1
    -- if _table_end > 0 then
    --     logic.table_end()
    -- end
    return end_rst
end

--检查是否整局游戏结束
local function check_game_stop()
    return _table_end == 1 or _played_times >= _max_times
end

--检查玩家是否在游戏中
local function check_player_in_game( p )
    if p and p.seatid and _players_sit[p.seatid] then
        return true
    end
    LOG_DEBUG("player[%d] is not in game", p.uid or -1)
end

local function reset_dissolve_data( faild )
    dissolve_timeout = nil
    if faild then
        next_dissolve_time = osapi.os_time() + DISSOLVE_CD
    end
    table.clear(consent_dissolve_players) 
    table.clear(refuse_dissolve_players)
end

local function dissolve_table_success()
    reset_dissolve_data()
    _tapi.send_to_all("game.PushDissolveTable", {result = 2})

    local users = {}
    local scores = {}
    for _, p in pairs(_players_sit) do
        table.insert(users, p.nickname)
        table.insert(scores, 0)
    end
    _tapi.game_end({index = _played_times + 1, players = users, score = scores})

    change_game_status(MJ_STATUS.GAME_STOP)
    dissolve_table = true
end

local function dissolve_table_faild()
    reset_dissolve_data(1)
    _tapi.send_to_all("game.PushDissolveTable", {result = 3})
end

--检查房间的解散状态
local function check_dissolve_table()
    if dissolve_timeout then
        if #consent_dissolve_players >= _game_cfg.max_player or osapi.os_time() >= dissolve_timeout then
            dissolve_table_success()
        end

        if #refuse_dissolve_players > 0 then
            dissolve_table_faild()
        end
    end
end

--拒绝解散
local function refuse_dissolve_table(p)
    if dissolve_timeout and not osapi.tindexof(refuse_dissolve_players, p.uid) then
        osapi.tinsert(refuse_dissolve_players, p.uid)
        _tapi.send_to_all("game.PushDissolveTable", { consentUid = consent_dissolve_players, 
                                                    refuseUid = refuse_dissolve_players,
                                                    remaintime = remaintime})
    end
end

--有人提出/同意解散房间
local function consent_dissolve_table(p)
    local remaintime
    local now_time = osapi.os_time()
    local push_client
    if not next(consent_dissolve_players) then
        dissolve_timeout = now_time + DISSOLVE_TIME
        remaintime = DISSOLVE_TIME
        osapi.tinsert(consent_dissolve_players, p.uid)
        for uid, player in pairs(_players) do
            if check_player_in_game(player) then
                if not player.online or player.online == 0 then
                    if not osapi.tindexof(consent_dissolve_players, player.uid) and not osapi.tindexof(refuse_dissolve_players, player.uid) then
                        osapi.tinsert(consent_dissolve_players, player.uid)
                    end
                end
            end
        end
        push_client = true
     --   next_dissolve_time = now_time + DISSOLVE_CD
    end

    if not osapi.tindexof(consent_dissolve_players, p.uid) then
        osapi.tinsert(consent_dissolve_players, p.uid)
        push_client = true
    end

    

    if push_client then
        LOG_DEBUG("push dissolve table")
        _tapi.send_to_all("game.PushDissolveTable", {   result = 1,
                                                        consentUid = consent_dissolve_players, 
                                                        refuseUid = refuse_dissolve_players,
                                                        remaintime = remaintime})
    end
end

local function free_table(reason)
    local total_info = {total = _played_times, players = {},score = {}} 
    if not _isMatch then
        for uid, p in pairs(_players_sit) do
            osapi.tinsert(total_info.players, p.nickname)
            osapi.tinsert(total_info.score, p.score or 0)
        end
    end

    _tapi.free_table(total_info, reason)
end

-------------------------------------状态处理函数-----------------------------
local function deal_waiting_start()--会在update里面一直执行直到可以开始
--    LOG_DEBUG("deal_waiting_start")
    if check_start() then
        _has_start = true
     --   _played_times = 0
        _tapi.send_to_all("game.resGameStart", {})
        _tapi.game_start()
        change_game_status()
    end
end

local function deal_before_start()
    LOG_DEBUG("deal_before_start")
    init_round_data()
    new_game()
    change_game_status()
end

local function deal_after_start()
    --不知道用来做什么的 暂时留下
--    LOG_DEBUG("deal_after_start ostime:%d, dealtime:%d", osapi.os_time(), _deal_tiles_time)
--    LOG_WARNING("#_request_deal[%d] osapi.os_time[%d] _deal_tiles_time[%d]", #_request_deal, osapi.os_time(), _deal_tiles_time)
    if #_request_deal >= 4 or osapi.os_time() >= _deal_tiles_time then
        deal_tiles()
        change_game_status()
    end
    
end

local function deal_player_opt()
    LOG_DEBUG("deal_player_opt")
    player_drow()
end

local function deal_waiting_player(now)
    local p = _players_sit[_opt_seatid]
    if is_trusteeship(p) then
        if p.last_draw_tile and mj_deal.check_win_all(p.tiles, p.last_draw_tile) then 
            client.reqMJPlayerOpt( p, {opts={opttype=OPT_TYPE.WIN,cards={}}} )
        else
            if not _discard_cnt or _discard_cnt == 0 then
                if now - _last_timer_start < 300 then
                    return
                end
            else
                _last_timer_start = 0
            end
        end
    end
--    LOG_DEBUG("deal_waiting_player now[%s] _last_timer_start[%s]", tostring(now), tostring(_last_timer_start))
    if now - _last_timer_start < TIME.OPT_TIME then return end
    auto_discard()
 --   change_game_status()
end

local function deal_check_claim()
    LOG_DEBUG("deal_check_claim")
    check_player_claim()
    change_game_status()
end

local function deal_waiting_claim()
--    LOG_DEBUG("deal_waiting_claim")
    if #_claim_players_new > 0 then
        tick_claim_player()
        change_game_status()
    elseif _qianggang_info then
        peng_gang()
    elseif _qiangminggang_info then
        player_ming_gang( _qiangminggang_info.player, _qiangminggang_info.tile )
        _qiangminggang_info = nil
    else
    --    check_genzhuang()
        change_game_status(MJ_STATUS.PLAYER_OPT)
    end
end

local function deal_waiting_claim_player()
 --   LOG_DEBUG("deal_waiting_claim_player")
    local p = _players_sit[_opt_seatid]
    if is_trusteeship(p) then
        if _claim_cache_data and _claim_cache_data.seatid == p.seatid then
            for _, v in ipairs(_claim_cache_data.opts) do
                if v.opttype == OPT_TYPE.WIN or v.opttype == OPT_TYPE.QIANG_GANG_WIN then
                    client.reqMJPlayerOpt( p, {opts={opttype=v.opttype, cards={}}} )
                    return
                end
            end
        end
        _last_timer_start = 0
    end
    if skynet.now() > _last_timer_start + TIME.CLAIM_TIME then
        _claim_cache_data = nil
        player_claim_give_up(_opt_seatid)
    end
    
end

local function deal_game_end()
    LOG_DEBUG("deal_game_end")
    --清楚托管状态
    for uid, p in pairs(_players) do
        player_trusteeship(p, 0)
    end
    local end_rst = game_end()
    LOG_DEBUG("deal_game_end end table_end[%s]", tostring(_table_end))
    
    if _isUseGold then
        _has_start = false
        for seatid, p in pairs(_players_sit) do
            p.kick_timeout = osapi.os_time() + KICK_TIMEOUT
            p.ready = 0
            init_player_info(p)
        end
        init_round_data()
        change_game_status(MJ_STATUS.WAITING_START)
    elseif _isMatch then
        free_table(1002)
    else
        _tapi.game_end({index = _played_times, players = end_rst.players, score = end_rst.score})
        if check_game_stop() then
            change_game_status(MJ_STATUS.GAME_STOP)
        else
            change_game_status()
        end
    end 
end

local function deal_game_rest_waiting()
 --   LOG_DEBUG("deal_game_rest_waiting")
    if _re_ready_count >= 4 or skynet.now() >= _last_timer_start + TIME.SETTLE_TIME then
        change_game_status()
    end
end

local function deal_game_rest()
    LOG_DEBUG("deal_game_rest")
    change_game_status(MJ_STATUS.BEFORE_START)
end

local function deal_game_stop()
    LOG_DEBUG("deal_game_stop")
    local infos = {}
    for seatid, p in pairs(_players_sit) do
        local info = {
            uid = p.uid,
            nickname = p.nickname,
            minggang = p.ming_gang + p.peng_gang,
            angang = p.an_gang,
            score = p.score or 0
        }
        osapi.tinsert(infos, info)
    end
    -- PRINT_T(_played_times)
--    PRINT_T(infos)
    _tapi.send_to_all("game.MJGameStop", {round = _played_times, infos = infos})
    free_table(1002)
end

local function deal_check_qianggang( ... )
    -- body
end

local function kick_player(p)
    _players_sit[p.seatid] = nil
    p.seatid = nil
    _tapi.kick(p, 1005)
end

local function kick_all_player()
    for k, v in pairs(_players or {}) do
        kick_player(v, 1010)
    end
end

--踢掉超时未准备的玩家
local function check_kick_players()
    local now_time = osapi.os_time()
    for seatid, p in pairs(_players_sit) do
        if (not p.ready or p.ready == 0) and p.kick_timeout and now_time > p.kick_timeout then
            kick_player(p)
        end
    end
end

--金币模式自动坐下
local function auto_sitdown(p)
    if p.seatid and p.seatid > 0 then
        LOG_WARNING("player[%d] is already sitdown seatid[%d]", p.uid, p.seatid)
        return
    end
    for i=1,_game_cfg.max_player do
        if not _players_sit[i] then
            _players_sit[i] = p
            p.seatid = i
            init_player_info(p)
            if not owner then
                owner = p.uid
            end
            LOG_DEBUG("auto sit down success")
            p.kick_timeout = osapi.os_time() + KICK_TIMEOUT
            --這裏發送了坐下是因为需要让机器人收到命令并进行准备
            _tapi.send_to_all("game.resSitDown", { uid = p.uid, seatid = i, nickname = p.nickname, headimg = p.headimg or "" })
            break
        end
    end
    assert(p.seatid and p.seatid > 0, "not enough seatid")
end

--是否全是机器人
local function all_robot()
    for k, v in pairs(_players) do
        if not v.isrobot then
            return false
        end
    end
    return true
end

local function check_join_robot()
    if table.len(_players) >= _game_cfg.max_player then
        return
    end

    local ready_cnt = 0
    for k,v in pairs(_players) do
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
        time_join_robot =0
        local gold = math.random(_game_cfg.init_params.min_gold, _game_cfg.init_params.min_gold*10)
        LOG_DEBUG("add_majing robot gold[%d]", gold)
        _tapi.join_robot("majiang", gold)
    end
end

-- local function report_gold_info()
--     if not _isUseGold then return end
--     while true do 
--         if _ctrlcost > 0 or _ctrlearn > 0 then
--             -- CMD.report(addr, gameid, usercost, userearn)
--             _tapi.report_gold(_ctrlcost, _ctrlearn)
--             _ctrlcost = 0
--             _ctrlearn = 0
--         end
--         skynet.sleep(5*100)
--     end
-- end

--金币场入场条件
local function gold_check(p)
    return p.gold >= _game_cfg.init_params.min_gold
end

function client.LandTrusteeship(p, msg)
--    LOG_WARNING("LandTrusteeship")
    if check_player_in_game(p) then
        if not is_trusteeship(p) or (p.trusteeship ~= msg.state) then
            player_trusteeship(p, msg.state)
        end 
    end
end

-- function client.SitdownNtf( p, msg )
--     if _isUseGold then
--         LOG_WARNING("gold module can not sitdown")
--         return 
--     end
--     local seatid = tonumber(msg.seatid)
--     if not check_seat(seatid) then
--         return
--     end
    
--     if p.seatid and p.seatid > 0 then
--         _players_sit[p.seatid] = nil
--     end
    
--     _players_sit[seatid] = p
--     p.seatid = seatid
--     init_player_info(p)
--     LOG_DEBUG("player[%s] sit down success seatid[%d]", p.nickname, seatid)
--   --  _tapi.send_to_all("game.SitdownNtf", { uid = p.uid, seatid = seatid, nickname = p.nickname, headimg = p.headimg or "" })
-- end

function client.reqReady( p, msg )
    
    if _has_start then return end 
    if not p.ready or p.ready == 0 then
        if p.seatid and p.seatid > 0 then
            p.ready = 1
            if _isUseGold then
                if not gold_check(p) then
                    LOG_WARNING("player[%d] ready faild,not enough gold", p.uid)
                    return 
                end
                p.kick_timeout = nil
            end
            LOG_DEBUG("player[%d] get ready", p.uid)
            _tapi.send_to_all("game.resReady", { uid = p.uid, seatid = p.seatid, result = 1 })
            return
        end
    end
    p:send_msg("game.resReady", { uid = p.uid, seatid = -1, result = 1 })
end

--[[
    @desc: 玩家操作
    author:{author}
    time:2019-01-27 21:54:28
    --@p:
	--@msg: 
    @return:
]]
function client.reqMJPlayerOpt( p, msg )
    LOG_DEBUG("player[%d] opt[%d]", p.uid, msg.opts.opttype)
    local opttype = msg.opts.opttype
    local cards = msg.opts.cards

    if opttype ~= OPT_TYPE.PASS and opttype ~= OPT_TYPE.WIN and (not cards or #cards <= 0) then
        LOG_DEBUG("illegal opt[%s] from player[%d]", tostring(opttype), p.uid)
        return
    end
    local seatid = p.seatid
    if seatid ~= _opt_seatid then
        if not _opt_seatid then 
            LOG_WARNING("game status [%d] uid[%d] isrobot[%s]", _game_status, p.uid, tostring(p.isrobot))
        else
            LOG_DEBUG("not player[%d] seatid[%d] round, cur opt seatid[%d]", p.uid, seatid, _opt_seatid)
        end
        return 
    end
    local function check_opt(t, opt)
        for _,v in ipairs(t) do
            if v.opttype == opt then
                return true
            end
        end
        return false
    end

    if check_status(MJ_STATUS.WAITING_CLAIM_PLAYER) then --等待玩家操作的情况下
        _claim_cache_data = nil
        if opttype ~= OPT_TYPE.PASS and not check_opt(p.info, opttype) then
            LOG_DEBUG("illegal opt[%s] from player[%d]", tostring(opttype), p.uid)
            return
        end
        if opttype == OPT_TYPE.PASS then
            player_claim_give_up(p.seatid)
        elseif opttype == OPT_TYPE.WIN then --点炮
            -- clear_claim_players()
            -- if _qianggang_info then
            --     player_win_all(p)
            -- else
            --     players_win(p)
            -- end
            players_win(p)
        elseif opttype == OPT_TYPE.QIANG_GANG_WIN then
            clear_claim_players()
            player_win_all(p, msg.opts.cards[1])
        elseif opttype == OPT_TYPE.CHI then
            clear_claim_players()
            player_chi(p, cards)
            _qishouhu = false
        elseif opttype == OPT_TYPE.PENG then
            if p.noPeng == cards[1] then --弃碰过圈规则
                p:send_msg("game.resMJPlayerOpt", { result = 2 })
                return
            end
            clear_claim_players()
            player_peng(p, cards[1])
            _qishouhu = false
        elseif opttype == OPT_TYPE.LIGHT_GANG then
            clear_claim_players()
            _qishouhu = false
            if check_qiangminggang(p, cards[1]) then
                _qiangminggang_info = {player = p, tile = cards[1]}
                change_game_status(MJ_STATUS.WAITING_CLAIM)
            else
                player_ming_gang(p, cards[1])
            end
        end
    end

    if check_status(MJ_STATUS.WAITING_PLAYER) then --等待玩家出牌的情况下
        if opttype == OPT_TYPE.DISCARD then
            if p.noDeal == cards[1] then --臭吃规则
                p:send_msg("game.resMJPlayerOpt", { result = 1 })
                return
            end
            discard(p, cards[1])
        elseif opttype == OPT_TYPE.BLACK_GANG then
        --    PRINT_T(cards)
            player_an_gang(p, cards[1])
            _qishouhu = false
        elseif opttype == OPT_TYPE.PENG_GANG then
            player_peng_gang(p, cards[1])
        elseif opttype == OPT_TYPE.WIN then --自摸
            player_win_all(p)
        end
    end
end

function client.DissolveTable( p,msg )
    --游戏开始后需要所有玩家同意才可以解散
    --游戏没开始不能解散
    if _has_start then
        if check_player_in_game(p) then
            local now_time = osapi.os_time()
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
    -- else
    --     --游戏没开始只能房主解散
    --     if p.uid == _owner then
    --         free_table(1001)
    --     end
    end
end

function client.StartNextGame(p)
    if not _has_start or check_status(MJ_STATUS.GAME_STOP) then return end
    if check_player_in_game(p) and p.re_ready and p.re_ready == 0 then
        p.re_ready = 1
        _re_ready_count = _re_ready_count + 1
        _tapi.send_to_all("game.resReady", { uid = p.uid, seatid = p.seatid, result = 1})
    end
end

function client.MJGMSetNextCard(p, msg)
    LOG_DEBUG("client cheat card:"..msg.card)
    local t = {42,44,46,48,49,52,54,56,57,58,59}
    if msg.card%10 == 0 or math.floor(msg.card/10) < 1 or math.floor(msg.card/10) > 5 or table.indexof(t, msg.card) then
        LOG_WARNING("illegal card[%d]", msg.card)
        return 
    end
    _gm_next_card[p.uid] = msg.card
end

--这个功能没有使用，用于客户端发牌动画完成后发消息给服务器，服务器再进行发牌20190208
function client.MJRequestDealTiles(p, msg)
    if not osapi.tindexof(_request_deal, p.uid) then
        osapi.tinsert(_request_deal, p.uid)
    end
end

---------------------------------------------------------------------------------------------

function mj_logic.set_kickback( kb )
    if _isUseGold and not _isTaste then
        _kickback = kb
    end
end

--游戏外部强制解散
function mj_logic.dissolve_table()

    if _has_start then
        dissolve_table_success()
    else
        free_table(1001)
    end
end

--[[
    @desc: 外部更新遊戲內部的金幣变化
    author:{author}
    time:2019-01-02 21:04:30
    --@p:
	--@gold:
	--@reason: 
    @return:
]]
function mj_logic.update_gold( p, gold, reason )
    p.gold = p.gold + gold
    if p.gold < 0 then
        p.gold = 0
    end
    _tapi.send_to_all("game.resUpdateGoldInGame", { uid = p.uid, goldadd = gold, gold = p.gold })
end

function mj_logic.sitdown( p, seatid )
    if _isUseGold then
        LOG_WARNING("gold module can not sitdown")
        return 
    end
    local seatid = tonumber(seatid)
    if not check_seat(seatid) then
        return
    end
    
    if p.seatid and p.seatid > 0 then
        _players_sit[p.seatid] = nil
    end
    
    _players_sit[seatid] = p
    p.seatid = seatid
    init_player_info(p)
    LOG_DEBUG("player[%d] sit down success", p.uid)
    return true
 --   _tapi.send_to_all("game.SitdownNtf", { uid = p.uid, seatid = seatid, nickname = p.nickname, headimg = p.headimg or "" })
end

function mj_logic.standup( p, seatid )
    if _isUseGold then
        LOG_WARNING("gold module can not sitdown")
        return 
    end
    local seatid = tonumber(seatid)
    if not check_seat(seatid) then
        return
    end

    if not p.seatid or p.seatid ~= seatid then
        LOG_WARNING("player not in seat[%d]", seatid)
        return false
    end
    
    _players_sit[seatid] = nil
    p.seatid = nil
    return true
end

function mj_logic.free(p)
    LOG_DEBUG("free mj table data")
    _players_sit = nil
    _tapi = nil
    _game_cfg = nil
    consent_dissolve_players = nil
    refuse_dissolve_players = nil
    _wall = nil
    _claim_players_new = nil
    _game_status = nil
end

function mj_logic.join(p)
    LOG_DEBUG("player[%d] join table", p.uid)
    if _isTaste then
        if not _has_start then
            p.gold = _game_cfg.test_gold
        end
    end
    if _isUseGold then
        if not _game_cfg.init_params.min_gold then
            LOG_ERROR("lack min_gold in game[%d] conf", gameid)
            return 
        end
        if not gold_check(p) then
            LOG_WARNING("player[%d] not enough gold to join game[%d] need[%d] cur gold[%d]", p.uid, _gameid, _game_cfg.init_params.min_gold, p.gold)
            return 
        end
    end
    return true
end

--状态恢复
function mj_logic.resume(p, is_resume)
    
    local time, curuid, tile
    local tiles = {}
    if check_status(MJ_STATUS.WAITING_PLAYER) then
        time = math.floor((_last_timer_start + TIME.OPT_TIME - skynet.now()) / 100)
    end
    if check_status(MJ_STATUS.WAITING_CLAIM_PLAYER) then
        time = math.floor((_last_timer_start + TIME.CLAIM_TIME - skynet.now()) / 100)
    end
    local curplayer
    if _opt_seatid then
        curplayer = _players_sit[_opt_seatid]
        if curplayer.uid == p.uid then
            tile = p.last_draw_tile
        else
            tile = curplayer.last_draw_tile and -1 or nil
        end
        curuid = curplayer.uid
    end
--    PRINT_T(_players_sit)
    for seatid, player in pairs(_players_sit) do
        local info = {}
        info.uid = tonumber(player.uid)
        info.tilenum = player.tiles and #player.tiles or 0
        if _game_status >= MJ_STATUS.GAME_END or p.uid == player.uid then
            info.handcards = player.tiles
        end
        info.handcards = info.handcards or {}
        info.opts = player.hold_tiles or {}
        info.desk = player.discards or {}
        -- for k,v in ipairs(player.hold_tiles or {}) do
        --     info.opts[k] = {opttype = v.opttype,cards = v.cards}
        -- end
        info.seatid = seatid
        info.cpnum = get_max_num(player.chipengRecord)
        osapi.tinsert(tiles, info)
    end
    --在询问玩家吃碰杠阶段时 出牌人的seatId,和一些操作和卡牌信息
    local seatid
    local myopts
    if check_status(MJ_STATUS.WAITING_CLAIM_PLAYER) and curuid == p.uid then
        seatid = _claim_cache_data.seatid
        myopts = _claim_cache_data.opts
    end
    local msg = {
        status = _game_status,
        time = time,
        curseatid = curplayer and curplayer.seatid or -1,
        tiles = tiles,
        tile = tile,
        seatid = seatid or 1,
        myopts = myopts or {},
        banker = _banker_seatid or 0,
        leftCard = #_wall,
        shifter = {},
        dices = _dices,
    }
    -- luadump(msg.tiles,"game.resMJResume===")
    if _game_status >= 3 then --发牌结束后才发送恢复信息
        p:send_msg("game.resMJResume", msg)
    end
    
--    _tapi.send_to_all("game.UserOnline", { uid = p.uid })

    if is_trusteeship(p) then
        player_trusteeship(p, 0)
    end

    --解散房间的信息
    -- if dissolve_timeout then
    --     p:send_msg("game.PushDissolveTable", { consentUid = consent_dissolve_players, 
    --                                                 refuseUid = refuse_dissolve_players,
    --                                                 remaintime = dissolve_timeout - osapi.os_time()})
    -- end
end

function mj_logic.offline(p)
    -- 离线默认同意解散
    if dissolve_timeout and check_player_in_game(p) then
        if not osapi.tindexof(consent_dissolve_players, p.uid) and not osapi.tindexof(refuse_dissolve_players, p.uid) then
            osapi.tinsert(consent_dissolve_players, p.uid)
            _tapi.send_to_all("game.PushDissolveTable", {   result = 1,
                                                        consentUid = consent_dissolve_players, 
                                                        refuseUid = refuse_dissolve_players,
                                                        remaintime = remaintime})
        end 
    end
end

function mj_logic.leave_game(p)
    if _isUseGold then
        if not _has_start then
            _players_sit[p.seatid] = nil
            return true
        end
    else
        if not _has_start or not p.ready or p.ready == 0 then
            -- if p.hascost and _pay_type == 1 then
            --     p.hascost = nil
            --     local price = tonumber(_game_cfg.price[1]) or 0
            --     p:call_userdata("add_gold", p.uid, price, _gameid)
            --     LOG_DEBUG("player[%d] leave table restore money[%d]", p.uid, price)
            -- end
            if p.seatid then
                _players_sit[p.seatid] = nil
            end
            return true
        end
    end
    
    return false
end

function mj_logic.get_tableinfo(p)
    auto_sitdown(p)--调用自动坐下
	local msg = {}
    local list = {}
    for uid, v in pairs(_players) do
        osapi.tinsert(list, {
            uid = tonumber(v.uid),
            nickname = v.nickname,
            sex = v.sex or 1,
            seatid = v.seatid or 0,
            ready = v.ready or 0,
            online = v.online or 1,
            score = v.score or 0,
            gold = v.gold or 0,
            headimg = v.headimg or "",
            trusteeship = v.trusteeship or 0,
            ip = "192.168.3.5"--v.ip or "",
        })
    end
    msg.owner = _owner
    msg.endtime = _end_time or 0
    msg.gameid,msg.modelid = CHANGE_GAMEID(1,_gameid) 
    msg.times = _max_times
    msg.playedtimes = (_played_times or 0) + 1
    msg.score = _base_score
    msg.paytype = _pay_type
    msg.roomid = _table_index
    msg.players = list
    msg.isGoldGame = _isUseGold or 0
    msg.status = _game_status
    msg.maxplayer = _game_cfg.max_player
    if _isUseGold then
        msg.extradata = {0,0,0,_game_cfg.init_params.base_score, _game_cfg.init_params.min_gold, _isTaste and 1 or 0}
    else
        msg.extradata = _rule_type
    end
    
    -- p:send_msg("game.TableInfo", msg)
    return msg
end

function mj_logic.dispatch( p, name, msg )
	if not client[name] then
		LOG_ERROR("illegal protocol[%s]", name)
		return 
	else
        LOG_DEBUG("receive protocol[%s] from client", name)
		return client[name](p, msg)
	end
end

function mj_logic.update(p)
    if all_robot() then
        -- if not free_table_timeout then
        --     free_table_timeout = osapi.os_time() + FREE_TIMEOUT
        -- elseif osapi.os_time() >= free_table_timeout then
        --     free_table(1001)
        -- end
        kick_all_player()
        return 
    end

    if not _game_status then return end

    if _end_time and osapi.os_time() > _end_time and not _has_start then
        free_table(1001)
        return
    end

    if _has_start then
        check_dissolve_table()
    else
        if _game_cfg.add_robot then
            check_join_robot()
        end
        if _isUseGold then 
            check_kick_players()
        end
    end
    local now = skynet.now()
    if status_func[_game_status] then
        status_func[_game_status](now)
    end
end

local function check_status_functions()
    for _,id in pairs(MJ_STATUS) do
        if _ == "MAX_STATUS" then break end
        assert(status_func[id], "status["..id.."] has no deal function!")
    end
end

status_func = {
    [MJ_STATUS.WAITING_START] = deal_waiting_start,          --等待开始
    [MJ_STATUS.BEFORE_START] = deal_before_start,           --正式开始前
    [MJ_STATUS.AFTER_START] = deal_after_start,
    [MJ_STATUS.PLAYER_OPT] = deal_player_opt,
    [MJ_STATUS.WAITING_PLAYER] = deal_waiting_player,
    [MJ_STATUS.CHECK_CLAIM] = deal_check_claim,
    [MJ_STATUS.WAITING_CLAIM] = deal_waiting_claim,
    [MJ_STATUS.WAITING_CLAIM_PLAYER] = deal_waiting_claim_player,
    [MJ_STATUS.GAME_END] = deal_game_end,
    [MJ_STATUS.GAME_REST_WAITING] = deal_game_rest_waiting,
    [MJ_STATUS.GAME_REST] = deal_game_rest,
    [MJ_STATUS.GAME_STOP] = deal_game_stop,
    [MJ_STATUS.CHECK_QIANGGANG] = deal_check_qianggang,
}

function mj_logic.init( ps, api, m_conf, m_times, m_score, m_pay,
     m_code, m_gameid, uid, usegold, matchid, mjinfo, kb )
    fill_table_gameids()
    _players = ps
    _tapi = api
    --     send_to_all = api.send_to_all,
    --     free_table = api.free_table,
    --     game_start = api.game_start,
    --     kick = api.kick,
    --     game_end = api.game_end
    _rule_type = mjinfo
    
    _game_cfg = m_conf 
    _gameid = m_gameid
    set_play_type_info() 
    _pay_type = m_pay
    _max_times = m_times
    _table_index = m_code
    if not _isUseGold then
        _end_time = _game_cfg.wait_time + osapi.os_time()
    end

    _isUseGold = usegold
    _isMatch = matchid
    if _game_cfg.test_gold and _game_cfg.test_gold > 0 then
        _isTaste = true
    end

    if usegold and kb and not _isTaste then
--        LOG_WARNING("set kickback[%s]", tostring(kb))
        _kickback = kb
        _ctrlcost = 0
        _ctrlearn = 0
        -- skynet.fork(report_gold_info)
    end
    
    
    init_base_rule()
    if _isUseGold then
        _base_score = _game_cfg.init_params.base_score
    else
        _base_score = (m_score and m_score > 0) and m_score or 1
    end
    init_mj_deal(m_conf)
--    init_special_rule()
    change_game_status(MJ_STATUS.WAITING_START)
    _owner = uid
    check_status_functions()
--    init_origin_wall()
--测试---------------------------------------------------------
    -- local tt = {
    --     {11,14,17,22,25,28,33,36,39,41, 43, 45, 47, 51, 53, 55},
    --     {11,14,17,32,35,38,23,26,29,41, 43, 45, 47, 51, 53, 55},
    --     {21,24,27,32,35,38,13,16,19,41, 43, 45, 47, 51, 53, 55},
    --     {21,24,27,12,15,18,33,36,39,41, 43, 45, 47, 51, 53, 55},
    --     {31,34,37,12,15,18,23,26,29,41, 43, 45, 47, 51, 53, 55},
    --     {31,34,37,22,25,28,13,16,19,41, 43, 45, 47, 51, 53, 55},
    -- }

    -- for i=1,1000 do
    -- local idx = math.random( 1,#tt )
    -- local ttlist = table.arraycopy(tt[idx])
    -- local hu = {}
    -- for i=1,3 do
    --     idx = math.random( 1,#ttlist )
    --     hu[#hu+1] = table.remove( ttlist,idx )
    -- end

    -- for k,v in pairs(hu) do
    --     if mj_deal.check_win_one(ttlist, v) then
    --         -- LOG_DEBUG("可以和")
    --     else
    --         LOG_DEBUG("不可以和")
    --     end
    -- end
    -- end

end

return mj_logic