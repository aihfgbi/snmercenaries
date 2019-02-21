local skynet = require "skynet"
local nodename = skynet.getenv("nodename")
local robot_name_store = require "robot_name"
local crypt = require "skynet.crypt"
local json = require "cjson"

local CMD = {}
local robot_list = {} --使用中的机器人
local count = 0 --机器人数量统计

local robot_names = {}
local headimgs = {}
local _redisWatch
local _redis
--机器人使用逻辑，第一次从redis里面直接把空闲机器人取完，
--自己管理在线和不在线机器人，然后再空闲机器人不够10个的时候，
--就再向管理端请求10个新的机器人去回来，如此循环
local GET_NEW_NUM = 10 --m每次请求新机器人的数量
local freeIdList = {} --空闲机器人的ID

--[[
    @desc: 检测空闲机器人是否还足够，不够就跟管理端要新的
    author:{author}
    time:2019-02-21 24:47:34
    --@isReset: 是否要重置机器人0否，1是，比如服务器重启，会发送一次这个消息
    @return:
]]
local function checkFreeRobot(isReset)
    if table.len(freeIdList) <= GET_NEW_NUM then
        local data = {
            num = GET_NEW_NUM,
            reset = isReset,
            sendTime = os.time()
        }
        pcall(skynet.send, _redisWatch, "lua", "pushMsg", "robot.severGetNewRobot", data)
    end
end

--[[
    @desc: 读取空闲ID列表
    author:{author}
    time:2019-02-21 24:12:51
    @return:
]]
local function getFreeIdList()
    while true do
        local ok, a = pcall(skynet.call, _redis, "lua", "execute", "LPOP", "LEISURE-ROBOT-ID")
        if ok and a then
            a = tonumber(a)
            if a then
                table.insert(freeIdList, 1, a)
            end
        else
            break
        end
    end
    skynet.fork(checkFreeRobot, false)
    luadump(freeIdList, "机器人ID列表")
end

--[[
    @desc: 获取机器人加入游戏
    author:{author}
    time:2019-02-21 24:21:52
    --@type:游戏名字，用于判断调用哪个ai_xxx.lua
	--@gold:金币数量
	--@gameid:游戏id
	--@gamenode:节点名字
	--@gamerobot: 节点地址
    @return:
]]
function CMD.get_robot(type, gold, gameid, gamenode, gamerobot)
    --redis取一个新的机器人
	local uid = table.remove(freeIdList)
	local robot = skynet.newservice("robot")
    robot_list[uid] = {
        uid = uid,
        agnode = nodename,
        agaddr = robot,
        isrobot = true
    }
    -- 用获取的uid获取用户信息
    local userinfo, bankinfo, ok, data
    ok, data = pcall(skynet.call, _redis, "lua", "execute", "hget", "USER-INFO", uid)
    if ok then
        -- 转换用户数据
        ok, userinfo = pcall(json.decode, data)
        if ok then
            luadump(userinfo, "取得的用户信息")
            robot_list[uid].sex = math.floor(userinfo.sex)
            robot_list[uid].nickname = userinfo.nickName
            robot_list[uid].headimg = userinfo.headImg
            -- 获取用户金币和银行信息
            ok, data = pcall(skynet.call, _redis, "lua", "execute", "hget", "USER-ACCOUNT_INFO", uid .. "#1001")
            if ok then
                -- 转换用户金币数据
                ok, bankinfo = pcall(json.decode, data)
                if ok then
                    robot_list[uid].gold = math.floor(bankinfo.aNum)
                else
                    robot_list[uid].gold = gold
                end
            end
        end
        
        skynet.call(robot, "lua", "init", type, gameid, gamenode, gamerobot, skynet.self(), uid, robot_list[uid].gold)
        count = count + 1
        LOG_DEBUG("game[%d] get_robot[%d], gold[%d]", gameid, uid, robot_list[uid].gold)
        return robot_list[uid]
    end
end

--[[
    @desc: 保存机器人的金币变化
    author:{author}
    time:2019-02-21 01:31:59
    --@uid: 
    @return:
]]
function CMD.saveGoldChange(uid)
    local ok, data = pcall(skynet.call, _redis, "lua", "execute", "hget", "USER-ACCOUNT_INFO", uid .. "#1001")
    if ok then
        -- 转换用户金币数据
        local bankinfo = json.decode(data)
        if bankinfo and bankinfo ~= "" then
            bankinfo.aNum = robot_list[uid].gold
            bankinfo.lastChangeTime = os.time()
            ok =
                pcall(
                skynet.call,
                _redis,
                "lua",
                "execute",
                "hset",
                "USER-ACCOUNT_INFO",
                uid .. "#1001",
                json.encode(bankinfo)
            )
            if ok then
                LOG_DEBUG("修改数据成功")
            end
        end
    end
end

--[[
    @desc: 释放机器人，把金币变化更新到redis
    author:{author}
    time:2019-02-21 01:26:21
    --@uid: 
    @return:
]]
function CMD.free_robot(uid)
    if uid and robot_list[uid] then
        CMD.saveGoldChange(uid) --保存金币变化
        table.insert(freeIdList, 1, uid) --把释放的ID放回到空闲列表
        count = count - 1
        robot_list[uid] = nil
    end
end

function CMD.adminGiveNewRobot(data)
    luadump(data,"收到了反馈信息")
    skynet.fork(getFreeIdList)
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(_, _, command, ...)
                local f = CMD[command]
                skynet.ret(skynet.pack(f(...)))
            end
        )

		_redis = skynet.uniqueservice("redispool")
		skynet.call(_redis, "lua", "start")
        _redisWatch = skynet.newservice("rediswatch")
        LOG_DEBUG("=-=-="..skynet.address(_redisWatch))
        local ok = pcall(skynet.send, _redisWatch, "lua", "initrobNode", nodename, skynet.self())
        if not ok then
            LOG_DEBUG("注册函数失败")
        end

		skynet.fork(checkFreeRobot, true)

        collectgarbage("collect")
        collectgarbage("collect")
        collectgarbage("collect")
    end
)
