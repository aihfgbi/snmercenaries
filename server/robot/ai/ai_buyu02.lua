local skynet = require "skynet"
local timesp = require "timesp"
local all_game_conf = require "game_conf"
local cfgFish = require "fish_conf"
local cfgPath = require "fish_path_conf"

local ai_mgr = {}
local server_msg = {}
local cur_fish = {}
local timerHandlers = {}
local robot_api
local robot_info
local handlerId = 0
local bullets = 0
local shoot_time
local nBase
local game_conf
local nBegin_gold
local jordan = true
local Preference
local nFishId
local mrandom = math.random
local fucktime = 0
math.randomseed(timesp.time());

local function send_to_server(name, msg)
	-- LOG_DEBUG("send_to_server [%s]", name)
	robot_api.send_msg(name, msg)
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
local function SetTimer(duration,handler, ...)
	assert(handler)
	duration = duration * 100  
	handlerId = handlerId + 1
	local info = {
					startTime = skynet.now(),
					duration = duration, 
					loop = 1,
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

--换弹
-- local function shell(bases)
	-- --LOG_WARNING(os.time())
-- 	send_to_server("FishChangeBase", {uid=robot_info.uid, base=bases})
-- end

--我中弹了
local function hit(bullets,nFishId)
	send_to_server("Hit", {shootid=bullets,id=nFishId})
end

function keyof(hashtable, value)
    for k, v in pairs(hashtable) do
        if k == value then return true end
    end
    return nil
end

--我好想射点什么
local function shooting()
	if next(cur_fish) then 
		local tFishId = {}
		for k,v in pairs(cur_fish) do
			if v.weight >= 1 then
				table.insert(tFishId,v)
			end
		end
		if next(tFishId) then
			table.sort(tFishId,function (a,b) return a.weight>b.weight end)
			if tFishId[Preference] or keyof(cur_fish,nFishId) then
				local nfish
				if keyof(cur_fish,nFishId) then
					nfish = nFishId
				else
					nfish = tFishId[Preference].id
				end
				if not cur_fish[nfish].effects then
					for k,v in pairs(tFishId) do
						if v.effects and mrandom(100)<70 then
							if v.effects[1] == "boss" or v.effects[1] == "master" then
								nfish = v.id
								if mrandom(1,100) <= 30 then
									fucktime = mrandom(2*60,4*60) * 1000
								end
								break
							end
						end
						if v.effects and mrandom(100)<50 then
							if v.effects[1] == "boom" or v.effects[1] == "ice" then
								nfish = v.id
								if mrandom(1,100) <= 30 then
									fucktime = mrandom(2*60,4*60) * 1000
								end
								break
							end
						end
					end
				end
				nFishId = nfish
				nBase = nBase or 10
				bullets = bullets + 1
				send_to_server("Shoot", {type=1,id=bullets,base=nBase,params={9999*1000, nFishId*1000}})
				SetTimer(mrandom(1,2),hit,bullets,nFishId)
			end
		end
	end
end

local function change(nflag)
	nBegin_gold = robot_info.gold
	local t = game_conf.init_params.base
	for k,v in ipairs(t) do
		if v == nBase then
			if nflag then
				if k ~= table.len(t) then
					nBase= t[k+1]
					break
				end
			else
				if k ~= 1 then
					nBase = t[k-1]
					break
				end
			end
		end
	end
	send_to_server("FishChangeBase", {uid=robot_info.uid, base=nBase})
end


local function destroyFish(fish)
	if not fish or not fish.id then return end
	if fishListByID[fish.id] then
		-- LOG_DEBUG("destroyFish:"..fish.id..",type="..fish.type)
		fishinfoList[fish.id] = nil
		fishListByID[fish.id] = nil
		if fish.type then
			if fish.group then
				fishCount[fish.group] = fishCount[fish.group] - 1
			end
			fishCount.total = fishCount.total - 1
		end
	end
end

--减鱼
local function jianyu(fish)
	if not fish or not fish.id then return end
	if cur_fish[fish.id] then
		-- --LOG_WARNING(fish.id)
		cur_fish[fish.id] = nil
		ClearTimer(fish.id)
		--LOG_WARNING("减少"..fish.id)
	end
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

--加鱼
local function jiayu(f)
	if jordan then
		Preference = mrandom(1,10)
		local t = game_conf.init_params.base
		nBase = t[mrandom(4,5)]
		for _,v in ipairs(t) do
			if v <= nBase then
				send_to_server("FishChangeBase", {uid=robot_info.uid, base=v})
			end
		end
		jordan = false
	end
	local fish = {type=f.type, id=f.id, parent = f.parent}
	if f.type ~= 0 then
		fish.weight = cfgFish[f.type].weight
		fish.effects = cfgFish[f.type].effects
	end
	cur_fish[fish.id] = fish
	-- --LOG_WARNING("加鱼"..fish.id)
	--减鱼
	local time = f.time or getFishPathTime(f.path) or 0
	if time == 0 then time = 20*60*1000 end --每条鱼的存在时间最长是20分钟
	time = time / 1000 --从ms变成秒
	SetTimer(time,jianyu,fish)
end

function server_msg.AddFish(msg)
	local serverTime = timesp.time() --单位是毫秒
	for _,v in pairs(msg.fishes)do
		local delay = v.addtime + v.delay - serverTime
		if not v.time then v.time = getFishPathTime(v.path) end
		if v.type ~= 0 then
			if delay > 0 then
				SetTimer((delay/1000)+mrandom(3,7),jiayu,v)
			else
				v.time = v.time + delay
				jiayu(v)
			end
		end
	end
end

function server_msg.FishDie(msg)
	if not msg or not msg.id then return end
	if cur_fish[msg.id] then
		cur_fish[msg.id] = nil
		ClearTimer(msg.id)
		if msg.uid == robot_info.uid then
			robot_info.gold = msg.gold
			--LOG_WARNING("啊，我死了！")
		end
	end
end

function server_msg.Shoot(msg)
	-- --LOG_WARNING(msg.gold.."~~~~~~~~~~~"..robot_info.gold)
	if msg.id == robot_info.uid then
		robot_info.gold = msg.gold
	end
end

function ai_mgr.init(api, uid, gameid, gold)
	robot_api = api
	robot_info = robot_info or {}
	robot_info.uid = uid
	robot_info.gold = gold
	nBegin_gold = gold
	game_conf = all_game_conf[gameid]
	LOG_DEBUG("robot uid[%d]", robot_info.uid)
	LOG_DEBUG("robot gold[%d]", robot_info.gold)
end

function ai_mgr.dispatch(name, msg)
	local f = server_msg[name]
	if name == "AddFish" then --加鱼
		f(msg)
	elseif name == "FishDie" then --死鱼
		f(msg)
	elseif name == "Shoot" then --打鱼
		f(msg)
	end
end

function ai_mgr.free()
	robot_info = nil
end


function ai_mgr.update()
	updateHandler()
	local now_time = timesp.time()
	if not shoot_time then
		if fucktime > 0 then
			shoot_time = now_time + 150
			fucktime = fucktime - 150
		else
			shoot_time = now_time + 200
		end
	end
	if now_time >= shoot_time then
		shoot_time = nil
		shooting()
	end
	if ((nBegin_gold - robot_info.gold)/nBegin_gold) >= 0.2 then
		change()
	elseif ((nBegin_gold - robot_info.gold)/nBegin_gold) <= -0.2 then
		change(true)
	end
end

return ai_mgr

