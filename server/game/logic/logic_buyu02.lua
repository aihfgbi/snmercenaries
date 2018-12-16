local skynet = require "skynet"
local timesp = require "timesp"
local timer = require "timer"

cfgFish = require "fish_conf"
local cfgPath = require "fish_path_conf"

local fishingGrounds = require "fishingGrounds01"

local this = {}
local players
local code
local handlerId = 0
local fishID = 0
local fishListByID = {}
local fishinfoList = {}

local fishTypeByGroup = {}
local fishPathByGroup = {}
local fishCount = {}

local tinsert = table.insert
local tindexof = table.indexof
local timerHandlers = {}
local helper = {}
local scenes
local scenescnt
local sceneid

local send_to_all
local send_except
local free_table
local api_game_start
local report_gold
local hasStart
local endtime --游戏解散的时间点，没有开启游戏而解散
local stoptime --游戏正常的结束时间
local baselist
local active
local jiesanEndTime --申请解散结束的流程
local isUseGold --是否金币模式
local gameid
local pay
local price
local times --开房模式的游戏时长，10分钟为单位
local bossid
local basetype --开房模式1表示1、2、3倍，2表示4、5、6倍
local mastertype --1表示抢庄，2表示轮庄，3表示无庄
local master
local nextmastertime
local kickback
local earn,cost

local seats = {} -- seatid => uid
--游戏配置
local max_player
local min_gold
local api_join_robot
local kick_time = {}
local jqr_list = {}
local api_kick
local test_gold
local add_robot

local function kick(p, reason)
	api_kick(p, reason)

	if p.seatid and seats[p.seatid] then
		seats[p.seatid] = nil
	end
end

--获取机器人
local function check_join_robot()
	local t = {[1000]=20,[10000]=30,[100000]=50}
	if table.len(players) >= math.floor(max_player-1) then
	    return
	end
	local now_time = os.time()
	if not time_join_robot then
	    time_join_robot = now_time + math.random(5,10)
	end
	if now_time >= time_join_robot then
		time_join_robot = nil 
		local gold
		if min_gold < 1 then 
			gold = math.random(900000,1200000)
		else
		 	gold = math.random(min_gold*5, (t[min_gold] or 30)*min_gold)
		end
		api_join_robot("buyu02", gold)
	end
end

--踢掉机器人
local function kick_robot()
	local now_time = os.time()
	for uid,p in pairs(players) do
		if p.isrobot then
  			if not kick_time[uid] then
  		  		kick_time[uid] = now_time + 60*math.random(3,10)
  			end
  			if now_time >= kick_time[uid] or (p.gold <= 100) then
  		  		kick_time[uid] = nil
					kick(p,1008)
  			end
		end
	end
end

local function updateHandler()
	local nowTime = skynet.now()
	for k,v in pairs(timerHandlers) do
		if v and nowTime - v.startTime >= v.duration then
			v.handler(table.unpack(v.params))
			v.times = v.times + 1
			if v.loop > 0 and v.times >= v.loop then
				timerHandlers[k] = nil
			else
				v.startTime = nowTime
			end
		end
	end
end

--区别于timer:此处实现的timer是可以暂停的。
local function SetTimer(duration, loop, handler, ...)
	assert(handler)
	duration = duration * 100
	handlerId = handlerId + 1
	local info = {
					startTime = skynet.now(),
					duration = duration, 
					loop = loop,
					handler = handler,
					params = table.pack(...),
					times = 0,
				}
	timerHandlers[handlerId] = info
	return handlerId, info
end

local function ClearTimer(id)
	-- body
	if not id then return end
	timerHandlers[id] = nil
end
local function ClearAllTimer()
	-- body
	for k,v in pairs(timerHandlers) do
		timerHandlers[k] = nil
	end
	handlerId = 0
end

-- ms为单位
local function getFishPathTime(path)
	if not path then return 0 end
	local t = 0
	for _,pathid in pairs(path) do
		if pathid and cfgPath[pathid] then
			t = t + cfgPath[pathid].time * cfgPath[pathid].loop
		end
	end
	return t*1000
end

local function destroyFish(fish)
	if not fish or not fish.id then return end
	if fishListByID[fish.id] then
		-- LOG_DEBUG("destroyFish:"..fish.id..",type="..fish.type)
		fishinfoList[fish.id] = nil
		fishListByID[fish.id] = nil
		if fish.type then
			if fish.type == bossid then
				fishingGrounds.BossDie(bossid)
			end
			if fish.group then
				fishCount[fish.group] = fishCount[fish.group] - 1
			end
			fishCount.total = fishCount.total - 1
		end
	end
end

local function createFish(f, award)
	if not f or not f.type then return end
	-- if f.type ~= 0 and not cfgFish[f.type] then return end

	-- {type = type, id = fishID, delay = delay or 0, parent = parent, 
	-- path = path, pos = pos, rot = rot, time = time, pathOperation = operation, pathParams = parameter}
	local fish = {type=f.type, id=f.id, parent = f.parent}
	local cfg
	if f.type ~= 0 then
		cfg = cfgFish[f.type]
		fish.group = cfg.group
		fish.gold = cfg.gold
		fish.weight = cfg.weight
		if cfg.weight > 0 then
			fish.chance = 1/cfg.weight
		else
			fish.chance = 0
		end
		fishCount[fish.group] = fishCount[fish.group] or 0
		fishCount[fish.group] = fishCount[fish.group] + 1
		fishCount.total = (fishCount.total or 0) + 1
	end
	fishListByID[fish.id] = fish
	local time = f.time or getFishPathTime(f.path) or 0
	if time == 0 then time = 20*60*1000 end --每条鱼的存在时间最长是20分钟
	time = time / 1000 --从ms变成秒
	-- LOG_DEBUG(f.id.."删除时间:"..time..",type="..f.type)
	fish.timerid = helper.SetTimeout(time, destroyFish, fish)
end

local function report_gold_info()
	if not isUseGold or test_gold then return end --体验房不上报
	while true do 
		if cost > 0 or earn > 0 then
			-- CMD.report(addr, gameid, usercost, userearn)
			--LOG_DEBUG("上报数据:cost="..cost..",earn="..earn)
			report_gold(cost, earn)
			cost = 0
			earn = 0
		end
		skynet.sleep(5*100)
	end
end

local function checkHit(p, base, fish, id, shootid)
	-- p:send_msg("game.Hit", {id=id, shootid=shootid, result=1})
	local cfg = cfgFish[fish.type]
	if not cfg then return end
	local chance = fish.chance or 0
	local goldadd = 0
	local params
	local isDie = false

	if kickback and not p.isrobot then
		cost = cost + base
	end

	if cfg.effects then
		local group
		if cfg.effects[1] == "boom" then
			local weight = 0
			params = {}
			for id,f in pairs(fishListByID) do
				if f and f.type > 0 and f.group and f.weight then
					group = tostring(f.group)
					if tindexof(cfg.effects, group) then
						weight = f.weight + weight
						tinsert(params, id)
					end
				end
			end
			chance = 1/weight
			-- LOG_DEBUG("chance="..tostring(chance)..",weight="..tostring(weight)..",goldadd="..tostring(goldadd)
		elseif cfg.effects[1] == "ice" then
			chance = 1
		elseif cfg.effects[1] == "boss" then
			fish.gold = math.random(tonumber(cfg.effects[2]), tonumber(cfg.effects[3]))
			chance = 1/fish.gold
			params = {fish.gold}
			goldadd = (fish.gold or 1) * base
		elseif cfg.effects[1] == "master" then
			chance = 1/cfg.weight
			goldadd = (fish.gold or 1) * base
		elseif cfg.effects[1] == "zhangyu" then
			chance = 1/cfg.weight
		-- effects={"jiguang", "10","20"}}
			goldadd = (fish.gold or 1) * base
		elseif cfg.effects[1] == "jiguang" then
			chance = 1/cfg.weight
			fish.user_gold = fish.user_gold or 0
			fish.user_gold = fish.user_gold + base
		elseif cfg.effects[1] == "zuantou" then
			chance = 1/cfg.weight
			fish.user_gold = fish.user_gold or 0
			fish.user_gold = fish.user_gold + base
		end
	else
		goldadd = (fish.gold or 1) * base
	end

	-- chance = 1
	if kickback and isUseGold and not test_gold then
		chance = chance * kickback
	end

	-- ctrltype		控制类型(1:输,2：赢)
	-- ctrlrate		控制概率(1~100)
	-- ctrlmaxgold		控制最大输赢
	-- ctrlnowgold		记录当前输赢

	--判断个人控制
	if isUseGold and p.ctrlinfo and p.ctrlinfo.ctrltype and not test_gold then
		--超过金币
		if p.ctrlinfo.ctrltype == 1 then
			--控制玩家输
			if fish.type <= 1007 then
			elseif p.ctrlinfo.ctrlnowgold - goldadd + base >= p.ctrlinfo.ctrlmaxgold then
				chance = 1
			else
				local win_rate = math.max(1, (100 - p.ctrlinfo.ctrlrate) / 2)
				chance = chance * win_rate / 50
			end
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + base --子弹打中的消费
		elseif p.ctrlinfo.ctrltype == 2 then
			--控制玩家赢
			if fish.type <= 1007 then
			elseif p.ctrlinfo.ctrlnowgold + goldadd - base >= p.ctrlinfo.ctrlmaxgold then
				chance = 0
			else
				local win_rate = p.ctrlinfo.ctrlrate + (100 - p.ctrlinfo.ctrlrate) / 2
				chance = chance * win_rate / 50
			end
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold - base --子弹打中的消费
		end
		-- LOG_DEBUG("当前，ctrlnowgold="..p.ctrlinfo.ctrlnowgold..",base="..base..",ctrltype="..p.ctrlinfo.ctrltype)
	end
	-- chance = 2

	--判断是否打死
	if math.random() < chance then
		--判断中奖类型
		if cfg.effects then
			if cfg.effects[1] == "boom" then
				destroyFish(fish)
				for i,id in ipairs(params) do
					destroyFish(fishListByID[id])
				end
				tinsert(params, base)
			elseif cfg.effects[1] == "ice" then
				destroyFish(fish)
				params = {}
				local cf
				for id,f in pairs(fishListByID) do
					cf = cfgFish[f.type]
					if not (cf and cf.effects and cf.effects[1] == "boss") then
						helper.PauseByID(f.timerid, 10)
						tinsert(params, id)
					end
				end
				tinsert(params, 10*1000)
			elseif cfg.effects[1] == "boss" then
				-- LOG_DEBUG("击中BOSS，BOSS不死亡，奖励金币:"..goldadd..",fish.gold="..fish.gold)
			elseif cfg.effects[1] == "master" then
				destroyFish(fish)
				if mastertype and mastertype == 1 then
					master = p
					send_to_all("game.SetMaster", {uid=master.uid})
				end
			elseif cfg.effects[1] == "zhangyu" then
				destroyFish(fish)
			elseif cfg.effects[1] == "jiguang" then
				p.skill = cfg
				p.canAdd = fish.user_gold
				fish.user_gold = nil
				p.skillbase = base
				destroyFish(fish)
			elseif cfg.effects[1] == "zuantou" then
				p.skill = cfg
				p.canAdd = fish.user_gold
				fish.user_gold = nil
				p.skillbase = base

				p.canAdd = 100000

				destroyFish(fish)
			end
		else
			destroyFish(fish)
		end

		--当前控制金币赋值
		if isUseGold and p.ctrlinfo and p.ctrlinfo.ctrltype then
			if p.ctrlinfo.ctrltype == 1 then--输
				p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold - goldadd
			elseif p.ctrlinfo.ctrltype == 2 then--赢
				p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + goldadd
			end
		end

		if isUseGold then
			p.gold = p.gold + goldadd
			if kickback and not p.isrobot then
				earn = earn + goldadd
			end
		elseif goldadd > 0 then
			local goldchanage = 0
			if not master or p.uid == master.uid then
				-- 如果是庄家赢了
				for uid,u in pairs(players) do
					if u and u.uid ~= p.uid and u.ready == 1 then
						-- 闲家扣钱
						u.gold = u.gold - goldadd
						goldchanage = goldchanage + goldadd
						send_to_all("game.UpdateGoldInGame", {uid=uid,goldadd=-goldadd,gold=u.gold})
					end
				end
				-- 庄家加钱
				p.gold = p.gold + goldchanage
				goldadd = goldchanage
			else
				-- 闲家赢了
				-- 庄家扣钱
				master.gold = master.gold - goldadd
				send_to_all("game.UpdateGoldInGame", {uid=master.uid,goldadd=-goldadd,gold=master.gold})

				-- 闲家加钱
				p.gold = p.gold + goldadd
			end
		end

		if goldadd == 0 then
			goldadd = -1
		end
		send_to_all("game.FishDie", {id=fish.id, uid=p.uid, fishgold=goldadd, gold=p.gold, score=p.score, params = params})
	else
		-- 没击中鱼
		if not isUseGold then
			-- 开房模式
			if not master or p.uid == master.uid then
				-- 如果是庄家没击中鱼
				local goldchanage = 0
				for uid,u in pairs(players) do
					if u and u.uid ~= p.uid and u.ready == 1 then
						-- 闲家加钱
						u.gold = u.gold + base
						goldchanage = goldchanage + base
						send_to_all("game.UpdateGoldInGame", {uid=uid,goldadd=base,gold=u.gold})
					end
				end
				-- 庄家扣钱
				p.gold = p.gold - goldchanage
				send_to_all("game.UpdateGoldInGame", {uid=p.uid,goldadd=-goldchanage,gold=p.gold})
			else
				-- 闲家没有击中鱼
				-- 庄家加钱
				master.gold = master.gold + base
				send_to_all("game.UpdateGoldInGame", {uid=master.uid,goldadd=base,gold=master.gold})
				-- 闲家扣钱
				p.gold = p.gold - base
				send_to_all("game.UpdateGoldInGame", {uid=p.uid,goldadd=-base,gold=p.gold})
			end
		end
	end
end

function helper.SetTimeout(duration, handler, ...)
	-- duration单位是秒
	-- LOG_DEBUG("---------------SetTimeout")
	if duration == 0 then
		handler(...)
		return
	end
	return SetTimer(duration, 1, handler, ...)
end

function helper.SetFormFinishTime(time)
	-- helper.SetTimeout(time, setCanFinish)
end

function helper.ClearTimer(id)
	ClearTimer(id)
end

function helper.PauseAll(time)
	-- body
	for k,v in pairs(timerHandlers) do
		if v and v.startTime then
			v.startTime = v.startTime + time * 100
		end
	end
end
-- 秒为单位
function helper.PauseByID(id, time)
	-- body
	local timer = timerHandlers[id]
	if timer and timer.startTime then
		timer.startTime = timer.startTime + time * 100
	end
end

function helper.AddFish(fishes, award, rightnow)
	local delay
	if rightnow then
		delay = 0
	else
		-- 三秒后再出鱼，用于消除网络延迟带来的鱼不同步问题，客户端也是三秒后出鱼
		delay = 3
	end
	local addtime = timesp.time() --单位是毫秒
	local fish
	local shortFishes = {}  --用于拆分协议，防止一条协议数据量太大超过TCP的一个MTU长度
	for k,f in pairs(fishes) do
		-- LOG_DEBUG("准备增加类型:"..f.type)
		-- LOG_DEBUG("delay="..f.delay)
		-- 三秒后再出鱼，用于消除网络延迟带来的鱼不同步问题，客户端也是三秒后出鱼
		f.addtime = addtime
		f.delay = (f.delay or 0) + delay * 1000
		fishinfoList[f.id] = f
		helper.SetTimeout(f.delay/1000, createFish, f, award)
		
		tinsert(shortFishes, f)
		if #shortFishes > 10 then
			send_to_all("game.AddFish", {fishes = shortFishes})
			shortFishes = {}
		end
	end

	if #shortFishes > 0 then
		send_to_all("game.AddFish", {fishes = shortFishes})
	end
	-- LOG_DEBUG("加鱼")
end

function helper.MakeFish(type, delay, parent, path, pos, rot, time, operation, parameter)
	fishID = fishID + 1
	if operation == "+" then
		operation = 1
	elseif operation == "-" then
		operation = 2
	elseif operation == "*" then
		operation = 3
	elseif operation == "/" then
		operation = 4
	else
		operation = nil
	end
	
	if parent then parent = parent.id end
	if time then time = time * 1000 end
	if delay then delay = delay * 1000 end
	-- delay和time的单位是ms
	-- if time then
		-- LOG_DEBUG("id="..fishID..",time="..time)
	-- end
	return {type = type, id = fishID, delay = delay or 0, parent = parent, 
	path = path, pos = pos, rot = rot, time = time, pathOperation = operation, pathParams = parameter}
end

function helper.LockShoot()
	LOG_DEBUG("LockShoot!")
end

function helper.UnlockShoot()
	LOG_DEBUG("UnlockShoot!")
end

function helper.GetFishTypeByGroup(group)
	return fishTypeByGroup[group] or {}
end

function helper.GetFishPathByGroup(group)
	return fishPathByGroup[group] or {}
end

function helper.GetFishCountByGroup(group)
	return fishCount[group] or 0
end

-- message BossNotify {
--     required int32 status = 1; //1表示BOSS出现了，//2表示BOSS结束了
--     required int32 bossid = 2; //boss的id
--     repeated int32 params = 3; //额外需要的参数
-- }

function helper.EnterBossScene(id)
	send_to_all("game.BossNotify", {status=1, bossid=id})
end

function helper.ExitBossScene()
	send_to_all("game.BossNotify", {status=2, bossid=bossid})
end

function helper.FishFormStart()
end

function helper.FishFormStop()
end

function helper.GetPathTime(path)
	return getFishPathTime({path})
end

function helper.GetPlayerCount()
	local cnt = 0
	for uid,p in pairs(players) do
		if p and p.seatid and p.seatid > 0 then
			cnt = cnt + 1
		end
	end
	return cnt
end

function helper.FormWillStart()
	LOG_DEBUG("fish form will start")
	ClearAllTimer()
	fishListByID = {}
	fishinfoList = {}
	fishCount = {}
	send_to_all("game.FishFormWillStart", {})
end

local function clearDissolve()
	jiesanEndTime = 0
	for i=1,6 do
		p = seats[i]
		if p and p.jiesan then
			p.jiesan = nil
		end
	end
end

local function checkCanDissolve()
	for i=1,6 do
		p = seats[i]
		if p and not p.jiesan then
			return
		end
	end

	-- 3秒以后结束游戏
	clearDissolve()
	stoptime = os.time() + 1
end

local function chanage_scene()
	local index = 1
	while true do
		skynet.sleep(30*100) --两分钟切换一个场景

		index = index + 1
		if index > scenescnt then
			index = 1
		end
		sceneid = scenes[index]
		-- if index <= scenescnt then
		-- 	sceneid = scenes[index]
		-- else
		-- 	scenes = {}
		-- 	local x,t
		-- 	for i=1,scenescnt do
		-- 		x = math.random(scenescnt)
		-- 		scenes[x] = scenes[x] or x
		-- 		scenes[i] = scenes[i] or i
		-- 		t = scenes[i]
		-- 		scenes[i] = scenes[x]
		-- 		scenes[x] = t
		-- 	end
		-- 	index = 1
		-- 	sceneid = scenes[index]
		-- end

		send_to_all("game.ChanageSceneNtf", {id=sceneid})
	end
end

------------------------------------------------------------------------------------------------

function this.free()
	
end

function this.set_kickback(kb, sysearn)
	if isUseGold then
		-- kickback是一个>0的数值，1表示不抽水也不放水，自然概率
		-- 例如0.98表示玩家的每次下注行为都抽水0.02
		-- 如果需要转化成0-100的数值，那么就是kickback*50，且大于100的时候取100
		-- LOG_DEBUG("收到kickback:"..kb)
		kickback = kb
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
	if not active then return end
	if isUseGold and add_robot then
		if all_robot() then
			for _,v in pairs(players) do
				kick(v,1008)
			end
		end
		check_join_robot()
		kick_robot()
	end

	updateHandler()
	local now = os.time()
	if hasStart and not isUseGold and master then
		-- 开房模式下
		if mastertype == 2 and now >= nextmastertime then
			-- 轮庄需要换庄
			local index = master.seatid
			local p
			for i=1,6 do
				index = index + 1
				if index > 6 then
					index = 1
				end
				p = seats[index]
				if p and p.seatid and p.seatid > 0 and p.ready and p.ready == 1 then
					master = p
					send_to_all("game.SetMaster", {uid=master.uid})
					nextmastertime = now + 30
					break
				end
			end
		end
	end

	if not hasStart then
		if now > endtime then
			active = false
			free_table(nil, 1001)
		end
	elseif stoptime then
		
		if now > stoptime then
			active = false
			this.dissolve_table()
		end
		if jiesanEndTime and jiesanEndTime > 0 and now > jiesanEndTime then
			-- 如果超时，那么一定是解散了，因为超时默认是解散，1秒后直接结束游戏
			-- LOG_DEBUG("请求解散超时，解散!")
			stoptime = now
			clearDissolve()
		end
	end
end

local function checkSeatsFull()
	local c = 0
	for _,v in pairs(players) do
		c = c + 1
	end
	return c >= max_player
end

function this.join(p)
	if isUseGold then
		if p.isrobot then
			jqr_list[p.uid] = p
		end
		for i=1,6 do
			if not seats[i] then
				p.seatid = i
				seats[i] = p.uid
				break
			end
		end
		-- p:call_userdata("add_gold", 100000000, 1001)
		-- p:call_userdata()
		if p.seatid then
			p.ready = 1
			p.score = 0
			if test_gold then
				p.gold = test_gold
			end
			p.joinGold = p.gold
			LOG_DEBUG(p.uid.." gold="..p.joinGold..",hongbao="..(p.hongbao or 0))
			return true
		end
	else
		p.seatid = 0
		p.ready = 0
		p.score = 0
		p.gold = 0
		return true
	end
end

local function checkCanStart()
	if hasStart then return end
	local p
	local cnt = 0
	local list = {}
	for i=1,6 do
		p = seats[i]
		if p and p.seatid and p.seatid > 0 and p.ready and p.ready == 1 then
			cnt = cnt + 1
			tinsert(list, p)
		end
	end
	if cnt > 1 then
		hasStart = true
		api_game_start()
		stoptime = stoptime * 60 + os.time()
		-- stoptime = os.time()+10
		send_to_all("game.GameStart", {endtime=stoptime})
		if mastertype == 1 then
			LOG_DEBUG("抢庄模式")
			master = list[math.random(cnt)]
		elseif mastertype == 2 then
			LOG_DEBUG("轮庄模式")
			for i=1,6 do
				p = seats[i]
				if p and p.seatid and p.seatid > 0 and p.ready and p.ready == 1 then
					master = p
					break
				end
			end
			-- 30秒轮一次
			nextmastertime = os.time() + 30
		else
			LOG_DEBUG("无庄模式")
			master = nil
		end
		send_to_all("game.SetMaster", {uid=master.uid})
	end
end

local function clearSkill(p)
	if p and p.skill then
		p.skill = nil
		p.canAdd = nil
	end
end

function this.sitdown(p, seatid)
	if isUseGold then
		-- 金币模式不坐下
		return
	end
	if seatid > 0 and seatid < 7 then
		if not seats[seatid] then
			if p.seatid and p.seatid ~= 0 then
				-- 如果已经准备了，那么不允许换位置了
				if p.ready == 1 then return end
				seats[p.seatid] = nil
			end
			seats[seatid] = p
			p.seatid = seatid
			return true
			-- send_to_all("game.SitdownNtf", {uid=p.uid, seatid=p.seatid})
		end
	end
end

function this.standup(p, seatid)
	if isUseGold then
		-- 金币模式不坐下
		return
	end
	if seatid > 0 and seatid < 7 then
		seats[seatid] = nil
		p.seatid = 0
		return true
	end
end

function this.dispatch(p, name, msg)
	if name == "SitdownNtf" then
		if isUseGold then return end
		if msg and players[p.uid] then
			if msg.seatid > 0 and msg.seatid < 7 then
				if not seats[msg.seatid] then
					if p.seatid and p.seatid ~= 0 then
						-- 如果已经准备了，那么不允许换位置了
						if p.ready == 1 then return end
						seats[p.seatid] = nil
					end

					if not isUseGold then
						if not p.hasCost and pay == 1 then
							-- 房卡模式，AA支付，还未付费需要先付费
							if p.call_userdata("sub_money", price[1], 1001) then
								p.hasCost = true
							else
								return "game.SitdownNtf", {uid=p.uid, seatid=-1}
							end
						end
					end

					seats[msg.seatid] = p
					p.seatid = msg.seatid
					send_to_all("game.SitdownNtf", {uid=p.uid, seatid=p.seatid})
				end
			end
		end
	elseif name == "GetReadyNtf" then
		if isUseGold then return end
		if msg and p then
			if p.ready == 0 and p.seatid > 0 then
				p.ready = 1
				send_to_all("game.GetReadyNtf", {uid=p.uid, seatid=p.seatid})
				checkCanStart()
			end
		end

	elseif name == "DissolveTable" then
		if isUseGold then return end
		if not msg.opt then return end
		if msg.opt == 1 then
			if jiesanEndTime and jiesanEndTime > 0 then return end
			if not hasStart then return end
			local now = os.time()
			if p.lastJieSanTime and now - p.lastJieSanTime < 2.5 * 60 then return end 
	-- 		message DissolveTable{
	--     required int32 opt = 1;   //1解散 2同意 3拒绝 4询问解散
	-- }	
	-- 		message PushDissolveTable{
	--     optional int32 result = 1;   //1解散 2解散成功 3解散失败 4冷却中
	--     repeated int32 consent_uid = 2;
	--     repeated int32 refuse_uid = 3;
	--     optional int32 remaintime = 4;
	-- }
			p.lastJieSanTime = now
			jiesanEndTime = now + 10 --1分钟
			p.jiesan = true
			send_to_all("game.PushDissolveTable", {result = 1, consentUid = {p.uid}, remaintime = jiesanEndTime})
			jiesanEndTime = jiesanEndTime + 1

			for i=1,6 do
				v = seats[i]
				if v and v.online == 0 then
					v.jiesan = true
					send_to_all("game.PushDissolveTable", {result = 3, consentUid = {v.uid}})
				end
			end
			checkCanDissolve()
		else
			if not jiesanEndTime or jiesanEndTime == 0 then return end
			if msg.opt == 3 then
				clearDissolve()
				send_to_all("game.PushDissolveTable", {result = 2, consentUid = {p.uid}})
			elseif msg.opt == 2 then
				p.jiesan = true
				send_to_all("game.PushDissolveTable", {result = 3, consentUid = {p.uid}})
				checkCanDissolve()
			end
		end
	elseif name == "FishChangeBase" then
-- 		message FishChangeBase {
--     required int32 uid = 1;
--     required int32 base = 2;
-- }
		if msg and msg.base then
			if tindexof(baselist, msg.base) then
				p.base = msg.base
				send_to_all("game.FishChangeBase", {uid=p.uid, base=msg.base})
			end
		end
	elseif name == "Shoot" then
		if not hasStart then return end
		if not msg or not msg.id or not msg.base or not msg.params then return end
		p.bullets = p.bullets or {}
		local now = timesp.time()
		if p.bullets[msg.id] then
			return
		end

		-- 判断base合法性
		if not tindexof(baselist, msg.base) then
			-- luadump(baselist)
			-- LOG_DEBUG("炮台不合法")
			return
		end
		
		if msg.base > p.gold and isUseGold then
			-- 房卡模式不需要扣费
			return
		end

		p.btime = p.btime or 150
		p.bulletCnt = p.bulletCnt or 0
		if p.lastShootTime then
			if now - p.lastShootTime > 10000 then
				-- 超过10秒重新来过
				p.lastShootTime = now - 150
			end
			p.btime = (p.btime + now - p.lastShootTime)/2
			if p.btime < 130 then
				p.warncnt = p.warncnt or 0
				p.warncnt = p.warncnt + 1
				if p.warncnt > 10 then
					LOG_DEBUG(p.uid.."可能用加速器了")
					-- 踢人，告诉给运维
					return
				end
			end
		end
		if p.bulletCnt > 100 then
			LOG_DEBUG(p.uid.."子弹太多了")
			return
		end
		if isUseGold then
			p.gold = p.gold - msg.base
		end
		p.bullets[msg.id] = msg.base
		p.lastShootTime = now
		p.bulletCnt = p.bulletCnt + 1
		send_to_all("game.Shoot", {type=msg.type,id=msg.id,base=msg.base,gold=p.gold,uid=p.uid,params={msg.params[1], msg.params[2]}})
	elseif name == "Hit" then
		if not hasStart then return end
		if not msg or not msg.id or not msg.shootid then return end
		if not p.bullets or not p.bullets[msg.shootid] then
			-- return "game.Hit", {id=msg.id, shootid=msg.shootid, result=1}
			return
		end
		
		local base = p.bullets[msg.shootid]
		p.bullets[msg.shootid] = nil
		p.bulletCnt = p.bulletCnt or 0
		p.bulletCnt = p.bulletCnt - 1

		if not fishListByID or not fishListByID[msg.id] then
			if isUseGold then
				p.gold = p.gold + base
			end
			return "game.Hit", {id=msg.id, shootid=msg.shootid, result=2, gold=p.gold}
		end
		local fish = fishListByID[msg.id]
		if not fish.type or fish.type == 0 then
			if isUseGold then
				p.gold = p.gold + base
			end
			return "game.Hit", {id=msg.id, shootid=msg.shootid, result=2, gold=p.gold}
		end

		checkHit(p, base, fish, msg.id, msg.shootid)
	elseif name == "FishUseSkill" then
-- 		message FishUseSkill {
--     required int32 type = 1; //触发的鱼的技能id
--     required int32 uid = 2;
--     repeated int32 params = 3; //触发参数
-- }	
		if p.skill and msg.type == p.skill.type then
			-- timer.setTimeout(, kick, p, 1003)
			if p.skill.effects[1] == "jiguang" then
			elseif p.skill.effects[1] == "zuantou" then
				timer.setTimeout(5, clearSkill, p)
			end
			send_to_all("game.FishUseSkill", {type=msg.type, uid=p.uid, params=msg.params})
		else
			return "game.FishUseSkill", {type=msg.type, uid=-1}
		end
	elseif name == "FishSkillNtf" then
		if p.skill and p.canAdd then
			if p.skill.effects[1] == "jiguang" then
				p.skill = nil
				if msg.params then
					local f,cfg
					local goldadd = 0
					for _,id in pairs(msg.params) do
						f = fishListByID[id]
						if f then
							cfg = cfgFish[f.type]
							if cfg and not cfg.effects then
								goldadd = p.skillbase * cfg.gold
								if p.canAdd >= goldadd then
									p.canAdd = p.canAdd - goldadd
									destroyFish(f)
									send_to_all("game.FishDie", {id=id, uid=p.uid, fishgold=goldadd, gold=p.gold, score=p.score})
								end
							end
						end
					end
				end
				p.canAdd = nil
			elseif p.skill.effects[1] == "zuantou" then
				if msg.params then
					local f,cfg
					local goldadd = 0
					for _,id in pairs(msg.params) do
						f = fishListByID[id]
						if f then
							cfg = cfgFish[f.type]
							if cfg and not cfg.effects then
								goldadd = p.skillbase * cfg.gold
								if p.canAdd >= goldadd then
									p.canAdd = p.canAdd - goldadd
									destroyFish(f)
									send_to_all("game.FishDie", {id=id, uid=p.uid, fishgold=goldadd, gold=p.gold, score=p.score})
								end
							end
						end
					end
				end
			end
		end
	end
end

-- 发送房间信息
function this.get_tableinfo(p)
	local msg = {}
	local list = {}
	for uid,v in pairs(players) do
		tinsert(list, { uid = v.uid, 
						nickname=v.nickname,
						seatid=v.seatid or 0,
						ready=v.ready or 0,
						online=v.online or 1,
						score=v.score or 0,
						sex = v.sex or 1,
						gold = v.gold,
						headimg = v.headimg,
						money = v.hongbao or 0,
						params = {v.base or baselist[1]}})
	end
	msg.owner = 1
	-- LOG_DEBUG("hasStart ===== "..tostring(hasStart))
	if hasStart then
		msg.endtime = stoptime or 0
		msg.playedtimes = 1
	else
		msg.endtime = endtime
		msg.playedtimes = 0
	end
	msg.gameid = 1000
	msg.times = 0
	msg.score = basetype or 0
	msg.paytype = pay
	msg.code = code
	msg.players = list
	msg.isGoldGame = isUseGold or 0
	-- if mastertype then
	msg.extradata = {mastertype or 0, sceneid or 0}
	-- end
	-- luadump(msg)
	-- p:send_msg("game.TableInfo", msg)
	return msg
end

-- gold为int类型，可能为负值
-- 1001 充值
function this.updateGold(uid, gold, reason)

end

function this.resume(p, isreconnect)
	if p then
		if p.kicktimer then
			timer.clearTimer(p.kicktimer)
		end
		if hasStart and master then
			p:send_msg("game.SetMaster", {uid=master.uid})
		end
	end
end

function this.dissolve_table()
	-- {total=1, players={"张三","李四"}, score={-10,10}}
	-- times
	if isUseGold then return end
	if hasStart then
		local ps = {}
		local score = {}
		for uid,p in pairs(players) do
			if p and p.seatid and p.seatid > 0 and p.ready and p.ready == 1 then
				tinsert(ps, p.nickname or "--")
				tinsert(score, p.gold)
			end
		end
		free_table({total = times, players = ps, score = score}, 1002)
	else
		free_table(nil, 1001)
	end
end

-- 尝试离开游戏，如果能离开，返回true，并且调用该函数的地方继续处理离开逻辑
function this.leave_game(p)
	if hasStart and p.seatid and p.seatid > 0 and p.ready and p.ready == 1 and not isUseGold then
		return false
	end
	if p.seatid and p.seatid > 0 then
		seats[p.seatid] = nil
		if isUseGold then
			-- 金币结算
			if p.bullets then
				-- 返还飞行中的子弹
				p.bulletCnt = 0
				for id,base in pairs(p.bullets) do
					p.gold = p.gold + base
				end
				LOG_DEBUG(p.uid.." leave:gold="..p.gold..",joinGold="..p.joinGold)
				if not test_gold then
					if p.gold > p.joinGold then
						p:call_userdata("add_gold", p.gold-p.joinGold, gameid)
					elseif p.gold < p.joinGold then
						p:call_userdata("sub_gold", p.joinGold-p.gold, gameid)
					end
				end
				p.bullets = nil
			end
		else
			-- if pay == 1 and p.hasCost then
			-- 	-- 如果已经付费了，需要将扣除的钱还给玩家
			-- end
		end
	end
	return true
end

function this.offline(p)
	if p and p.bullets then
		-- 返还飞行中的子弹
		if isUseGold then
			for id,base in pairs(p.bullets) do
				p.gold = p.gold + base
			end
			if not test_gold then
				if p.gold > p.joinGold then
					p:call_userdata("add_gold", p.gold-p.joinGold, gameid)
				elseif p.gold < p.joinGold then
					p:call_userdata("sub_gold", p.joinGold-p.gold, gameid)
				end
			end
			p.joinGold = p.gold
			-- 金币模式，一段时间后需要踢出用户
			p.kicktimer = timer.setTimeout(1*60, kick, p, 1003)
		end

		p.bulletCnt = 0
		p.bullets = nil
	end
end

-- 玩家游戏外造成的金币增减，需要通知到游戏内，进行金币的增减
function this.add_gold(p, gold, reason)
	if not isUseGold or test_gold then return end
	p.gold = p.gold + gold
	if p.gold < 0 then
		p.gold = 0
	end
	p.joinGold = p.joinGold + gold
	send_to_all("game.UpdateGoldInGame", {uid=p.uid,goldadd=gold,gold=p.gold})
end

--初始化游戏
function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid, usegold, _, params, kb)
	players = ps
	code = m_code
	isUseGold = usegold
	gameid = m_gameid
	pay = m_pay
	price = m_conf.price
	max_player = m_conf.max_player
	min_gold = m_conf.min_gold or 0
	kickback = kb
	test_gold = m_conf.test_gold
	add_robot = m_conf.add_robot
	if kickback then
		cost = 0
		earn = 0
		skynet.fork(report_gold_info)
	end
	if params then
		mastertype = params[1] or 3
	else
		mastertype = 3
	end
	master = nil
	assert(price and price[1] and price[2],"开房模式价格配置错误:"..m_gameid)

	for id,path in pairs(cfgPath) do
		if path.group then
			fishPathByGroup[path.group] = fishPathByGroup[path.group] or {}
			tinsert(fishPathByGroup[path.group], id)
		end
	end

	for id,fish in pairs(cfgFish) do
		if fish.group then
			fishTypeByGroup[fish.group] = fishTypeByGroup[fish.group] or {}
			tinsert(fishTypeByGroup[fish.group], id)
		end
	end

	send_to_all = api.send_to_all
	send_except = api.send_except
	free_table = api.free_table
	api_game_start = api.game_start
	report_gold = api.report_gold
	api_kick = api.kick
	api_join_robot = api.join_robot

	hasStart = false
	active = true
	endtime = m_conf.wait_time + os.time()
	times = m_times
	stoptime = m_times --1分钟为单位
	basetype = m_score
	baselist = m_conf.init_params.base
	bossid = m_conf.init_params.boss
	scenescnt = m_conf.init_params.scenescnt

	if scenescnt then
		-- 如果有场景切换
		scenes = {}
		local x,t
		for i=1,scenescnt do
			x = math.random(scenescnt)
			scenes[x] = scenes[x] or x
			scenes[i] = scenes[i] or i
			t = scenes[i]
			scenes[i] = scenes[x]
			scenes[x] = t
		end
		luadump(scenes)
		sceneid = scenes[1]
		skynet.fork(chanage_scene)
	end

	fishingGrounds.SetCtrl(helper, bossid, mastertype)
	LOG_DEBUG("开启捕鱼游戏:"..tostring(isUseGold))
	fishingGrounds.Start()

	if isUseGold then
		hasStart = true
		api_game_start()
		stoptime = nil
	else
		if basetype == 1 then
			baselist = {1,2,3}
		else
			baselist = {4,5,6}
		end
	end
end

return this