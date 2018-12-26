local skynet = require "skynet"
local cluster = require "skynet.cluster"
local json = require "cjson"
local dbs_count = skynet.getenv "dbs_count"
local nodename = skynet.getenv "nodename"
local room_conf = require "room_conf"
dbs_count = tonumber(dbs_count)

local CMD = {}
local api = {}
local logic
local code
local players = {} --uid==>player
local count
local config
local manager
local pay
local creater
local gameid
local game_times

local redis
local infodata
local isusegold
local haslock
local hasstart
local histroy
local record
local score
local robotmanager
local gmmanager
local ismatch

local tinsert = table.insert

local function get_robotmanager()
    if not robotmanager then
        local ok, addr = pcall(cluster.query, "robot", "manager")
        if ok and addr then
            robotmanager = addr
        end
    end
    return robotmanager
end

local function call_datamanager(uid, func, ...)
    local index = uid % dbs_count
    -- index = index + 1
    local node = "dbs" .. index
    local ok, id = pcall(cluster.query, node, "manager")
    assert(ok, id)
    if ok and id then
        return cluster.call(node, id, func, ...)
    end
end

local function decode_data(data)
    return skynet.unpack(data)
end

local function encode_data(info)
    return skynet.packstring(info)
end

local function tick_tick()
    while true do
        if logic then
            logic.update()
        -- LOG_DEBUG("tick_tick")
        end
        skynet.sleep(10)
    end
end

local function send_msg(self, name, msg)
    if self.online ~= 1 or self.isrobot then
        return
    end
    --LOG_DEBUG("---===send msg:"..name..","..self.uid)
    local ok, result = pcall(cluster.send, self.agnode, self.agaddr, "send_to_client", self.uid, name, msg)
    if not ok then
        LOG_ERROR("send_msg error:" .. tostring(result))
        LOG_ERROR("name:" .. name .. ",node:" .. tostring(self.agnode) .. ",addr=" .. tostring(self.agaddr))
    end
    if hasstart and record and histroy and histroy[self.uid] then
        local list = histroy[self.uid]
        tinsert(list, {time = os.time(), name = name, msg = msg})
    end
    --给接管的机器人发消息
    if self.replace_robot then
        send_msg(self.replace_robot, name, msg)
    end
end

local function call_userdata(self, func, ...)
    if self.datnode and self.dataddr then
        return cluster.call(self.datnode, self.dataddr, func, self.uid, ...)
    end
end

-- 离开桌子
-- 通知userdata
-- 通知其他人用户离开
-- 删除players里面的用户信息
-- 清理p
-- 如果是金币模式，且是最后一个玩家，需要释放桌子
local function leave(p, reason, win, sid)
    if not p or not p.uid then
        return
    end
    if not players or not players[p.uid] then
        return
    end
    -- reason = reason or 1
    if isusegold and not p.isrobot then
        skynet.call(manager, "lua", "kick", p.uid, gameid, win)
    end
    LOG_DEBUG(p.uid .. "离开桌子," .. tostring(reason))
    p:call_userdata("leave_game")
    if config.max_player < 9 then
        -- 如果是百人场，那么不需要通知给其他人
        api.send_to_all("game.resLeaveTable", {uid = p.uid, seatid = sid, result = reason})
    else
        p:send_msg("game.resLeaveTable", {uid = p.uid, seatid = sid, result = reason})
    end
    if p.isrobot then
        p:send_msg("exit")
    end
    -- pcall(skynet.send, redis, "lua", "execute", "del", "tableinfo->"..tostring(p.uid))

    players[p.uid] = nil
    p.call_userdata = nil
    p.send_msg = nil
    count = count - 1
    if isusegold then
        if count < 1 then
            api.free_table(nil, 1002)
        else
            if haslock then
                skynet.call(manager, "lua", "unlock_table", gameid, skynet.self())
            end
        end
    end
end

--获取支付的钱
local function get_price()
    if isusegold then
        return
    end
    local tmp_conf
    local price_mode
    tmp_conf = config.times
    price_mode = game_times

    local index
    for i, v in ipairs(tmp_conf) do
        if v == price_mode then
            index = i
            break
        end
    end
    if not index then
        LOG_ERROR("get_price error gameid[%d] game_times[%d] paytype[%d]", gameid, price_mode, pay)
        return 0
    end
    return tonumber(config.price[index + (pay - 1) * (#tmp_conf)])
end

--开房模式查询gameid
function CMD.query_gameid()
    return gameid
end

-- local function kick(self)
-- 	self:send_msg()
-- end

-- 1006 房间已满
-- 1008 加入房间失败
function CMD.init(conf, gid, times, sc, paytype, co, p, mgr, usegold, matchid, params, kickback)
    LOG_DEBUG("init game:logic_" .. conf.logic)
    code = co
    score = sc
    config = conf
    logic = require("logic_" .. conf.logic)
    count = 0
    players = {}
    manager = mgr
    pay = paytype
    creater = p.uid
    createname = p.nickname
    gameid = gid
    isusegold = usegold
    haslock = nil
    hasstart = false
    record = conf.record
    ismatch = matchid
    game_times = times
    if not isusegold then
        -- 开房模式下需要有录像功能
        histroy = {}
    end

    logic.init(players, api, conf, times, score, paytype, code, gameid, p.uid, usegold, matchid, params, kickback)

    if not usegold then
        -- 如果是开房模式，需要将房间保存到玩家的房间列表上
        -- 将数据保存到redis
        local time = os.time()
        -- luadump({time,time+config.wait_time,paytype,times,score,gameid,code})
        infodata = encode_data({time, time + config.wait_time, paytype, times, score, gameid, code, params})
        LOG_DEBUG("开房模式，保存房间")
        skynet.send(redis, "lua", "execute", "RPUSH", "tablelist->" .. p.uid, infodata)
    end
    -- return CMD.join(p)
end

function CMD.join(p)
    -- 返回nil表示成功
    if not logic then
        return 101
    end

    if count >= config.max_player then
        return 1006
    end

    p.send_msg = send_msg
    p.call_userdata = call_userdata
    local result = logic.join(p)
    if result then
        -- "user.QuickJoinResonpse", {result=0}
        p.seatid = p.seatid or 0
        p.ready = p.ready or 0
        p.online = 1 --0不在线，1在线
        p.score = p.score or 0
        players[p.uid] = p
        count = count + 1

        if isusegold then
            if count >= config.max_player then
                haslock = true
                skynet.call(manager, "lua", "lock_table", gameid, skynet.self())
            end
        else
            if p.uid == creater then
                p.hasCost = true
            end
        end

        -- if hasstart then
        -- pcall(skynet.send, redis, "lua", "execute", "set", "tableinfo->"..tostring(p.uid), nodename..":"..skynet.self())
        -- end

        -- 给客户端发送加入成功的协议
        p:send_msg("hall.resQuickJoinGame", {result = 1, gameid = gameid, ismatch = ismatch or -1})

        local msg = logic.get_tableinfo(p)
        if msg then
            p:send_msg("game.resTableInfo", msg)
        end
        api.send_except(
            "game.resEnterTable",
            {
                info = {
                    uid = p.uid,
                    nickname = p.nickName,
                    sex = p.sex or 1,
                    seatid = p.seatid or 0,
                    ready = p.ready or 0,
                    online = p.online or 1,
                    score = p.score or 0,
                    gold = p.gold or 0,
                    headimg = p.headimg or "",
                    trusteeship = p.trusteeship or 0,
                    ip = p.ip or ""
                }
            },
            p.uid
        )
        logic.resume(p)
    else
        return 1008
    end
end

function CMD.dispatch(uid, name, msg)
    local p = players[uid]

    if name == "reqChat" then --聊天
        if (p.chattime or 0) > os.time() then
            LOG_DEBUG("player[%d] chat faild. in cd time", p.uid)
            return
        end
        p.chattime = os.time() + 2
        if p then
            api.send_to_all("game.resChat", {type = msg.type, to = msg.to, msg = msg.msg, uid = uid, seatid = p.seatid})
        end
    elseif name == "reqResume" then --恢复场景
        if p then
            if config.max_player < 9 then
                -- 如果是百人场，那么不需要通知给其他人
                api.send_to_all("game.UserOnline", {uid = p.uid})
            end

            p.online = 1
            if isusegold then
                skynet.call(manager, "lua", "online", p.uid)
            end

            if msg.type and msg.type == 1 then --等于1的时候就发桌子信息
                local tinfo = logic.get_tableinfo(p)
                if tinfo then
                    p:send_msg("game.resTableInfo", tinfo)
                end
            end
            logic.resume(p, 1)--任何情况都发恢复信息
        --	skynet.send(manager, "lua", "resume", p.uid, gameid)
        end
    elseif name == "reqLeaveTable" then
        if p then
            LOG_DEBUG(uid .. "请求离开")
            local sid = p.seatid
            if logic.leave_game(p) then
                -- 必须要fork，因为如果是金币模式最后一个人离开的话，服务会exit，会导致没有回调从而引起agent上面调用函数失败
                if not isusegold and pay == 1 and p.hasCost and not p.isrobot and creater ~= p.uid then
                    -- 如果玩家站起来了，已经扣掉的钱需要归还
                    -- 如果是房主，钱依然不归还
                    -- call_datamanager(p.uid, "add_money", creater, price, 1003)
                    local price = get_price()
                    if price then
                        p:call_userdata("add_money", price, 1003)
                    end
                    p.hasCost = nil
                end
                skynet.fork(leave, p, nil, sid)
                return
            end
            return "game.resLeaveTable", {uid = p.uid, result = 1000}
        end
    elseif name == "reqSitDown" then
        if p and msg and msg.seatid then
            if not isusegold then
                -- 非金币模式
                if logic.sitdown(p, msg.seatid) then
                    if not p.hasCost and pay == 1 then
                        -- AA付费
                        local price = get_price()

                        if p:call_userdata("sub_money", price, 1001) then
                            p.hasCost = true
                        else
                            -- 扣费失败，重新站起来
                            logic.standup(p, msg.seatid)
                            return "game.resSitDown", {uid = p.uid, seatid = -1}
                        end
                    end
                    if config.max_player < 9 then
                        -- 如果是百人场，那么不需要通知给其他人
                        api.send_to_all("game.resSitDown", {uid = p.uid, seatid = msg.seatid})
                    else
                        p:send_msg("game.resSitDown", {uid = p.uid, seatid = msg.seatid})
                    end
                else
                    return "game.resSitDown", {uid = p.uid, seatid = -2}
                end
            end
        end
    elseif name == "UserSpeakNtf" then
        -- -- 		message UserSpeakNtf {
        -- --     required int32 uid = 1;
        -- --     required string voiceid = 2;
        -- -- }

        -- if p and msg and msg.voiceid and p.seatid and p.seatid > 0 then
        --     -- 必须是坐下的才能说话
        --     if (p.chattime or 0) > os.time() then
        --         LOG_DEBUG("player[%d] speak faild. in cd time", p.uid)
        --         return
        --     end
        --     p.chattime = os.time() + 1
        --     api.send_to_all("game.UserSpeakNtf", {uid = p.uid, voiceid = msg.voiceid})
        -- end
    else
        if p then
            return logic.dispatch(p, name, msg)
        end
    end
end

function CMD.offline(uid)
    -- luadump(players)
    local p = players[uid]
    if p then
        LOG_DEBUG("用户离线:" .. uid)
        p.online = 0
        if isusegold then
            -- 金币模式需要通知ctrl用户离线了，避免群发消息的时候浪费
            skynet.call(manager, "lua", "offline", p.uid)
        end
        api.send_to_all("game.UserOffline", {uid = uid})
        if logic.offline then
            logic.offline(p)
        end
        return false
    else
        -- 如果玩家不在此桌子内，直接返回离开成功
        return true
    end
end

-- 检测玩家是否在房间中
function CMD.check_player(uid, agnode, agaddr, datnode, dataddr)
    if players and players[uid] then
        -- luadump(players)
        players[uid].agaddr = agaddr
        players[uid].agnode = agnode
        players[uid].datnode = datnode
        players[uid].dataddr = dataddr
        return gameid
    end
end

function CMD.dissolve_table(uid)
    if logic and uid == creater and not isusegold then
        skynet.fork(logic.dissolve_table)
        return 0
    end
    return 1003
end

function CMD.call_table(name, ...)
    if logic then
        local f = logic[name]
        if f then
            return f(...)
        end
    end
end

-- 1001 充值获得
-- 1002 GM
-- 1003 从银行获取
function CMD.add_gold(uid, gold, reason)
    if logic and players and players[uid] then
        logic.add_gold(players[uid], gold, reason)
    end
end

function CMD.set_kickback(kickback, sysearn)
    if logic and isusegold then
        logic.set_kickback(kickback, sysearn)
    end
end

function CMD.player_start_ctrl(uid, ctrlinfo)
    if isusegold then
        LOG_DEBUG("start ctrl player[%s]", tostring(uid))
        if players and players[uid] then
            players[uid].ctrlinfo = ctrlinfo
        else
            LOG_WARNING("player[%s] not in game[%s]", tostring(uid), tostring(gameid))
        end
    end
end

function CMD.player_stop_ctrl(uid)
    if isusegold then
        LOG_DEBUG("stop ctrl player[%s]", tostring(uid))
        if players and players[uid] then
            players[uid].ctrlinfo = nil
        else
            LOG_WARNING("player[%s] not in game[%s]", tostring(uid), tostring(gameid))
        end
    end
end

-----------------------------------------------------------------------------------------
function api.get_robot(type, gold)
    get_robotmanager()
    if robotmanager then
        local ok,
            robot =
            pcall(cluster.call, "robot", robotmanager, "get_robot", type, gold or 0, gameid, nodename, skynet.self())
        if ok and robot then
            return robot
        else
            robotmanager = nil
        end
    end
end

function api.join_robot(type, gold)
    local robot = api.get_robot(type, gold)
    if robot then
        if CMD.join(robot) then
            -- 有返回值表示加入房间失败
            pcall(cluster.call, robot.agnode, robot.agaddr, "send_to_client", robot.uid, "exit")
        end
    end
end

--[[
    @desc: 发送给所有玩家
    author:{author}
    time:2018-07-10 11:04:29
    --@name:
	--@msg: 
    @return:
]]
function api.send_to_all(name, msg)
    for uid, p in pairs(players) do
        p:send_msg(name, msg)
    end
end

--[[
    @desc: 发送给除了某个ID的其他玩家
    author:{author}
    time:2018-07-10 11:04:40
    --@name:
	--@msg:
	--@except_uid: 
    @return:
]]
function api.send_except(name, msg, except_uid)
    for uid, p in pairs(players) do
        if uid ~= except_uid then
            p:send_msg(name, msg)
        end
    end
end

function api.game_start()
    hasstart = true
    for uid, p in pairs(players) do
        -- pcall(skynet.send, redis, "lua", "execute", "set", "tableinfo->"..tostring(uid), nodename..":"..skynet.self())
        if histroy then
            histroy[uid] = {}
            local msg = logic.get_tableinfo(p)
            tinsert(histroy[uid], msg or {})
        end
    end
end

function api.game_end(result)
    LOG_DEBUG("game end:record=" .. tostring(record))
    hasstart = false
    luadump(result)
    if result and histroy then
        local data
        local now = os.time()
        if not record then
            now = 0
        end --如果不需要录像，那么是没有hash的
        for uid, p in pairs(players) do
            histroy.players = histroy.players or {}
            histroy.players[uid] = histroy.players[uid] or {}
            histroy.players[uid][result.index] = {hash = now, players = result.players, scores = result.score}

            if record then
                data = histroy[uid]
                data = json.encode(data)
                LOG_DEBUG("写入录像文件:" .. p.uid .. ",size=" .. tostring(#data) .. ",now=" .. now)
                pcall(skynet.send, redis, "lua", "execute", "set", "record->" .. uid .. ":" .. now, data)
            end
        end
    end

    -- {index=1(time=10*60), players={"张三","李四"}, score={-10,10}}
end

-- 踢出用户，注意如果是桌子可以解散的时候，不用依次踢掉每个玩家，free_table接口包含踢出的功能
-- 1003 用户不在线，新的一把开始了，将不在线的踢出
-- 1004 用户作弊
-- 1005 用户长时间未准备，踢出用户(例如金币场，30秒不准备踢出用户)
-- 1006 机器人钱不够了
-- 1007 机器人赢得次数够了
-- 1008 机器人在房间中时间过长
-- 1009 比赛场一局游戏结束正常踢出
function api.kick(p, reason, win)
    leave(p, reason, win)
end

function api.call_ctrl(name, ...)
    if isusegold then
        return skynet.call(manager, "lua", "call_ctrl", name, ...)
    end
end

function api.report_gold(cost, earn)
    if isusegold then
        skynet.call(manager, "lua", "report", skynet.self(), gameid, cost, earn)
    end
end

-- reason 1001表示解散，1002表示游戏完成了
function api.free_table(m_histroy, reason)
    -- luadump(m_histroy)
    if infodata and creater then
        -- 删除房间信息数据
        LOG_DEBUG("删除房间信息了")
        pcall(skynet.send, redis, "lua", "execute", "LREM", "tablelist->" .. creater, 0, infodata)
    end
    local price = get_price()
    for uid, p in pairs(players) do
        if p.online == 1 then
            p:send_msg("game.resLeaveTable", {uid = uid, result = reason or 1001})
        end
        if not isusegold and reason == 1001 and pay == 1 and p.hasCost and price and p.uid ~= creater then
            -- 如果不是金币模式，且是游戏没有开局就解散，且是AA支付，切用户已经付钱
            -- 房主不在这里归还
            call_datamanager(p.uid, "add_money", p.uid, price, 1003)
        end
        --robot在LeaveTableNtf中已经销毁
        if not p.isrobot then
            local ok, result = pcall(p.call_userdata, p, "leave_game")
            if not ok then
                LOG_ERROR(p.uid .. "通知userdata离开游戏失败:" .. tostring(result))
            end
        end
        -- p:call_userdata("leave_game")
        if isusegold and not p.isrobot then
            skynet.call(manager, "lua", "kick", p.uid, gameid)
        end
        if p.isrobot then
            p:send_msg("exit")
        end
        -- {total=1, players={"张三","李四"}, score={-10,10}}
        if histroy and m_histroy then
            local info = {}
            info.code = code
            info.gameid = gameid
            info.time = os.time() --结束时间
            info.score = score --底分
            info.owner = createname --房主
            info.times = m_histroy.total --总局数
            info.players = m_histroy.players --玩家信息
            info.scores = m_histroy.score --玩家的分数加减
            if histroy.players and histroy.players[uid] then
                info.hash = histroy.players[uid] --玩家录像的详细信息  {hash=now,players=result.players,scores=result.score}
            end
            -- LOG_DEBUG("============================histroy===========================:"..uid)
            -- luadump(info)
            -- LOG_DEBUG("==============================================================")
            local ok, data = pcall(encode_data, info)
            if ok and data then
                local ok, len = pcall(skynet.call, redis, "lua", "execute", "RPUSH", "histroy->" .. uid, data)
                len = tonumber(len)
                LOG_DEBUG(uid .. "历史记录长度:" .. len)
                if len and len > 50 then
                    for i = 51, len do
                        pcall(skynet.send, redis, "lua", "execute", "LPOP", "histroy->" .. uid)
                    end
                end
            end
        end

        -- pcall(skynet.send, redis, "lua", "execute", "del", "tableinfo->"..tostring(uid))
    end

    logic.free()
    for uid, p in pairs(players) do
        p.send_msg = nil
        p.call_userdata = nil
        players[uid] = nil
    end

    if not isusegold then
        if reason == 1001 then
            local price = get_price()
            if price then
                -- 如果桌子解散了，需要将费用还给房主
                call_datamanager(creater, "add_money", creater, price, 1003)
            end
        end
        skynet.call(manager, "lua", "free", code)
    else
        skynet.call(manager, "lua", "free_table", gameid, skynet.self())
    end

    skynet.fork(skynet.exit)
end

-----------------------------------------------------------------------------------------

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(_, _, command, ...)
                -- LOG_DEBUG("需要执行:"..command)
                local f = CMD[command]
                skynet.ret(skynet.pack(f(...)))
            end
        )
        skynet.fork(tick_tick)

        redis = skynet.uniqueservice("redispool")

        collectgarbage("collect")
        collectgarbage("collect")
        collectgarbage("collect")
    end
)
