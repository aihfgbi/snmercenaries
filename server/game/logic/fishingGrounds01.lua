local ctrl
local fishCtrl = {}
local GetFishTypeByGroup
local SetTimeout
-- local ClearAllTimer
local GetFishCountByGroup
local GetFishPathByGroup
local MakeFish
local AddFish
local GetPathTime
local SetFormFinishTime
local CheckHasType
local GetPlayerCount
local FormWillStart
local GetRoomPlayerCount
local AddAwardFish
local GetPoolGold
local EnterBossScene
local ExitBossScene
local this = {}
local refTime = 8*60 --固定的刷鱼潮时间
-- local refCount = 80 --鱼数目上限，达到该值，触发刷鱼潮
local waitTime = 1 --刷鱼阵之前需要等待的时间
local bossTime = 40--5*60 --BOSS出场时间
local refreshing
local addFish
local bossid
local mastertype
local this = {}
local cfgFish = cfgFish
local fishListAll={  --刷鱼鱼类列表
	group10={1001,1002,1003,1004,1005,1006,1007,},
	group20={1008,1009,1010,1011,1013,1021,},
	group30={1014,1015,1016,1017,},
	group40={1018,1019,1020,1024,1025,},
	group60={1027,1028,1029,1030,},
	group61={5001,5002,5003,},
	-- group100={3002,3003,3004,3005}, --道具
	group100={3007,3007,3007}
}

local cfg_time_rand={}  --刷新间隔
cfg_time_rand[10]={rmin=1,rmax=2}
cfg_time_rand[20]={rmin=1,rmax=3}
cfg_time_rand[30]={rmin=5,rmax=5}--保证刷新
cfg_time_rand[40]={rmin=40,rmax=60}--t1+t2
cfg_time_rand[60]={rmin=160,rmax=240}--t1+t2
cfg_time_rand[61]={rmin=3,rmax=5}--t1+t2
cfg_time_rand[100]={rmin=1,rmax=2}--道具

local cfg_count_limit={}  --数量限制
cfg_count_limit[10]={lmax=36,lmin=11,n=3} -->=lmax不刷，<lmax and >lmin的时候刷1，<lmin的时候刷n
cfg_count_limit[20]={lmax=13,lmin=3,n=1}
cfg_count_limit[30]={lmax=3,lmin=0,n=1}
cfg_count_limit[40]={lmax=1,lmin=0,n=1} 
cfg_count_limit[60]={lmax=1,lmin=0,n=1}
cfg_count_limit[61]={lmax=1,lmin=0,n=1}--t1+t2
cfg_count_limit[100]={lmax=1,lmin=0,n=1} 

local fish_group = {}
fish_group[10] = {pos=40,time={60,150},count={3,7}} --time单位ms
fish_group[20] = {pos=70,time={200,350},count={1,2}}

local sp_path = {}
sp_path[4001] = {60000,60001,60002}
sp_path[4002] = {60003,60004,60005,60006}
sp_path[4003] = {60007}

sp_path[5001] = {70001,70002}
sp_path[5002] = {70003,70004}
sp_path[5003] = {70005,70006}


local form_list = {
-- 6,
------------测试↑↓正式----------------
		1,--左右来往
		2,--旋转螺旋
		--3,--远处过来
		4,--双层包
		5,--半圈包
		--6,--全鱼展示
		7,--4方缺角方阵
		8,--4角小丑中蝙蝠/火焰蓝鲸
		9,--固定螺旋
		-- 11,--一网打尽
		-- 12,--电鳗
		13,--回旋
	}

local parameter_list = { --parameter_list[math.random(#parameter_list)]
			{1,1,1},
			{-1,1,1},
			{1,-1,1},
			{-1,-1,1},
		}

local function createOneWithParent(path, fishes, fishType, group)
	local cfg = fish_group[group]
	local time = 0
	local cnt = math.random(cfg.count[1], cfg.count[2])
	local parent
	local fish
	local t = GetPathTime(path)/1000
	local params = parameter_list[math.random(#parameter_list)]

	local posY,posZ

	for i=1,cnt do
		posY = math.random(cfg.pos*2) - cfg.pos
		posZ = math.random(cfg.pos*2) - cfg.pos
		parent = MakeFish(0, 0, nil, nil, {0, posY, posZ}, nil, t + time)
		fish = MakeFish(fishType, time, parent, {path}, nil, nil,nil,"*",params)
		table.insert(fishes, parent)
		table.insert(fishes, fish)
		time = time + math.random(cfg.time[1], cfg.time[2])/1000
	end
end

local function createOneOnly(path, fishes, fishType)
	local params = parameter_list[math.random(#parameter_list)]
	if type(path) == "number" then
		path = {path}
	end
	table.insert(fishes, MakeFish(fishType, 0, nil, path, nil, nil, nil, "*", params))
end


local function createFish(group, isBig)
	-- local players = GetPlayerCount() --玩家个数
	local T = math.random(cfg_time_rand[group].rmin,cfg_time_rand[group].rmax) --时间
	local limitMax
	local limitMin
	-- if players > 2 then
	limitMax = cfg_count_limit[group].lmax  --不刷上限
	limitMin = cfg_count_limit[group].lmin   --立刻刷N条
	-- else
	-- 	limitMax = cfg_count_limit[group].lmax*0.8  --不刷上限
	-- 	limitMin = cfg_count_limit[group].lmin*0.5   --立刻刷N条
	-- end
	local N = cfg_count_limit[group].n --立即补充
	local count = GetFishCountByGroup(group)
	local fishList = fishListAll["group"..group]
	local pathList = GetFishPathByGroup(group)
	table.random(pathList)
	local pathIndex = 1

	if 	count >= limitMax then
		-- 不刷
		SetTimeout(T, createFish, group, isBig)
	elseif count >= limitMin then
		-- 刷一个单位
		pathIndex = pathIndex + 1
		if pathIndex > #pathList then pathIndex = 1 end
		local path = pathList[pathIndex]
		local fishType = fishList[math.random(#fishList)]
		local fishes = {}
		if isBig then
			if sp_path[fishType] then
				path = sp_path[fishType]
			end
			createOneOnly(path, fishes, fishType)
		else
			createOneWithParent(path, fishes, fishType, group)
		end
		AddFish(fishes)
		SetTimeout(T, createFish, group, isBig)
	else
		-- 刷N个单位
		-- 大鱼不刷这里
		local time
		local fishes = {}
		for i=1,N do
			pathIndex = pathIndex + 1
			if pathIndex > #pathList then pathIndex = 1 end
			local path = pathList[pathIndex]
			local fishType = fishList[math.random(#fishList)]
			if isBig then
				createOneOnly(path, fishes, fishType)
			else
				createOneWithParent(path, fishes, fishType, group)
			end
		end
		-- LOG_DEBUG("刷了N条:"..group..",isBig="..tostring(isBig))
		AddFish(fishes)
		SetTimeout(T, createFish, group, isBig)
	end
end

local function stopForm()
	-- body
	SetTimeout(1,addFish)
end

local function fishForm1() --左右来往
	local fishes = {}

	for i=0,50 do
		local fish
        
        if i == 1 or i == 2 or i == 3 or i == 5 or i == 6 or i == 7 or i == 11 or i == 12 or i == 13 or i == 15 or i == 16 or i == 17 or i == 21 or i == 22 or i == 23 or i == 25 or i == 26 or i == 27 or i == 31 or i == 32 or i == 33 or i == 35 or i == 36 or i == 37 or i == 41 or i == 42 or i == 43 or i == 45 or i == 46 or i == 47  then
            fish = MakeFish(1003,i,nil,{5001})
        elseif i == 9 or i == 19 or i == 29 or i == 39 or i == 49  then
            fish = MakeFish(3005,i,nil,{5001})
        else
            fish = MakeFish(1006,i,nil,{5001})
        end 
		table.insert(fishes, fish)
	end

table.insert(fishes, MakeFish(1015,0,nil,{5002}))
table.insert(fishes, MakeFish(1016,5,nil,{5002}))
table.insert(fishes, MakeFish(1017,11,nil,{5002}))
table.insert(fishes, MakeFish(1018,19,nil,{5002}))
table.insert(fishes, MakeFish(1014,26,nil,{5005}))
table.insert(fishes, MakeFish(1020,35,nil,{5005}))

table.insert(fishes, MakeFish(1015,0,nil,{5003}))
table.insert(fishes, MakeFish(1016,5,nil,{5003}))
table.insert(fishes, MakeFish(1017,11,nil,{5003}))
table.insert(fishes, MakeFish(1018,19,nil,{5003}))
table.insert(fishes, MakeFish(1014,26,nil,{5006}))
table.insert(fishes, MakeFish(1020,35,nil,{5006}))

	for i=0,50 do
		local fish
        if i == 1 or i == 2 or i == 3 or i == 5 or i == 6 or i == 7 or i == 11 or i == 12 or i == 13 or i == 15 or i == 16 or i == 17 or i == 21 or i == 22 or i == 23 or i == 25 or i == 26 or i == 27 or i == 31 or i == 32 or i == 33 or i == 35 or i == 36 or i == 37 or i == 41 or i == 42 or i == 43 or i == 45 or i == 46 or i == 47  then
            fish = MakeFish(1003,i,nil,{5004})
        elseif i == 9 or i == 19 or i == 29 or i == 39 or i == 49  then
            fish = MakeFish(3005,i,nil,{5004})
        else
           fish = MakeFish(1006,i,nil,{5004})
        end
		table.insert(fishes, fish)
	end

	AddFish(fishes)
	SetFormFinishTime(50)
	SetTimeout(65,addFish)
end

local function fishForm14() --双层左右来往(升级测试版）
	local fishes = {}

	for i=0,50 do
		local fish
        if i == 1 or i == 11 or i == 21 or i == 31 or i == 41 or i == 49 then
        	fish = MakeFish(3005,i,nil,{5001})
        	table.insert(fishes, fish)
        	fish = MakeFish(3005,i,nil,{5001},nil,nil,nil,"+",{0,-220,0})
			table.insert(fishes, fish)
        else
        	fish = MakeFish(1003,i,nil,{5001}) 
			table.insert(fishes, fish)
        	fish = MakeFish(1003,i,nil,{5001},nil,nil,nil,"+",{0,-220,0})
			table.insert(fishes, fish)
		end
	end
	table.insert(fishes, MakeFish(1018,0,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1020,5,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1025,10,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1016,15,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1015,17,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1017,21,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1015,25,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1016,29,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1025,33,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1020,37,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1018,42,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	for i=0,50 do
		local fish 
        if i == 1 or i == 11 or i == 21 or i == 31 or i == 41 or i == 49 then
        	fish = MakeFish(3005,i,nil,{5004},nil,nil,nil,"+",{0,30,0})
        	table.insert(fishes, fish)
            fish = MakeFish(3005,i,nil,{5004},nil,nil,nil,"+",{0,190,0})
			table.insert(fishes, fish)
        else
        	fish = MakeFish(1006,i,nil,{5004},nil,nil,nil,"+",{0,30,0})
	        table.insert(fishes, fish)
	        fish = MakeFish(1006,i,nil,{5004},nil,nil,nil,"+",{0,190,0})
			table.insert(fishes, fish)
		end
	end

	AddFish(fishes)
	SetFormFinishTime(50)
	SetTimeout(65,addFish)
end
local function fishForm15() --两条大鱼(测试版）
	local fishes = {}
--往上八层
	table.insert(fishes, MakeFish(1001,3.5,nil,{5001},nil,nil,nil,"+",{0,10,0}))
	table.insert(fishes, MakeFish(1001,4,nil,{5001},nil,nil,nil,"+",{0,10,0}))
	table.insert(fishes, MakeFish(1002,5,nil,{5001},nil,nil,nil,"+",{0,10,0}))
	table.insert(fishes, MakeFish(1002,6,nil,{5001},nil,nil,nil,"+",{0,10,0}))
	table.insert(fishes, MakeFish(1001,27.5,nil,{5001},nil,nil,nil,"+",{0,10,0}))
	table.insert(fishes, MakeFish(1001,28,nil,{5001},nil,nil,nil,"+",{0,10,0}))
	table.insert(fishes, MakeFish(1002,29,nil,{5001},nil,nil,nil,"+",{0,10,0}))
	table.insert(fishes, MakeFish(1002,30,nil,{5001},nil,nil,nil,"+",{0,10,0}))
	--往上七层
	table.insert(fishes, MakeFish(1002,5,nil,{5001},nil,nil,nil,"+",{0,-10,0}))
	table.insert(fishes, MakeFish(1002,6,nil,{5001},nil,nil,nil,"+",{0,-10,0}))
	table.insert(fishes, MakeFish(1002,7,nil,{5001},nil,nil,nil,"+",{0,-10,0}))
	table.insert(fishes, MakeFish(1002,8,nil,{5001},nil,nil,nil,"+",{0,-10,0}))
	table.insert(fishes, MakeFish(1002,29,nil,{5001},nil,nil,nil,"+",{0,-10,0}))
	table.insert(fishes, MakeFish(1002,30,nil,{5001},nil,nil,nil,"+",{0,-10,0}))
	table.insert(fishes, MakeFish(1002,31,nil,{5001},nil,nil,nil,"+",{0,-10,0}))
	table.insert(fishes, MakeFish(1002,32,nil,{5001},nil,nil,nil,"+",{0,-10,0}))
	--往上六层
	table.insert(fishes, MakeFish(1001,2.7,nil,{5001},nil,nil,nil,"+",{0,-20,0}))
	table.insert(fishes, MakeFish(1001,4,nil,{5001},nil,nil,nil,"+",{0,-20,0}))
	table.insert(fishes, MakeFish(1001,26.7,nil,{5001},nil,nil,nil,"+",{0,-20,0}))
	table.insert(fishes, MakeFish(1001,28,nil,{5001},nil,nil,nil,"+",{0,-20,0}))
	--往上五层
	table.insert(fishes, MakeFish(3005,5,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(3005,6,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(1002,7,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(1002,8,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(1002,9,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(1002,10,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(1002,21,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(3005,29,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(3005,30,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(1002,31,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(1002,32,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(1002,33,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(1002,34,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	table.insert(fishes, MakeFish(1002,45,nil,{5001},nil,nil,nil,"+",{0,-30,0}))
	--往上四层
	table.insert(fishes, MakeFish(1001,1.8,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1001,4,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,5,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,6,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,7,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,8,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,9,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,10,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,11,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,12,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,20,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,21,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1001,25.8,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1001,28,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,29,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,30,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,31,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,32,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,33,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,34,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,35,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,36,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,44,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	table.insert(fishes, MakeFish(1002,45,nil,{5001},nil,nil,nil,"+",{0,-50,0}))
	--往上三层
	table.insert(fishes, MakeFish(1002,5,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,6,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,7,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,8,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,9,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,10,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,11,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,12,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,13,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,14,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,19,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,20,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,29,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,30,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,31,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,32,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,33,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,34,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,35,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,36,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,37,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,38,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,43,nil,{5001},nil,nil,nil,"+",{0,-70,0}))
	table.insert(fishes, MakeFish(1002,44,nil,{5001},nil,nil,nil,"+",{0,-70,0}))

	--往上二层
	table.insert(fishes, MakeFish(1001,1,nil,{5001},nil,nil,nil,"+",{0,-80,0}))
	table.insert(fishes, MakeFish(1001,4,nil,{5001},nil,nil,nil,"+",{0,-80,0}))
	table.insert(fishes, MakeFish(1001,25,nil,{5001},nil,nil,nil,"+",{0,-80,0}))
	table.insert(fishes, MakeFish(1001,28,nil,{5001},nil,nil,nil,"+",{0,-80,0}))
	--往上一层
	table.insert(fishes, MakeFish(1002,15,nil,{5001},nil,nil,nil,"+",{0,-90,0}))
	table.insert(fishes, MakeFish(1002,16,nil,{5001},nil,nil,nil,"+",{0,-90,0}))
	table.insert(fishes, MakeFish(1002,18,nil,{5001},nil,nil,nil,"+",{0,-90,0}))
	table.insert(fishes, MakeFish(1002,19,nil,{5001},nil,nil,nil,"+",{0,-90,0}))
	table.insert(fishes, MakeFish(1002,39,nil,{5001},nil,nil,nil,"+",{0,-90,0}))
	table.insert(fishes, MakeFish(1002,40,nil,{5001},nil,nil,nil,"+",{0,-90,0}))
	table.insert(fishes, MakeFish(1002,42,nil,{5001},nil,nil,nil,"+",{0,-90,0}))
	table.insert(fishes, MakeFish(1002,43,nil,{5001},nil,nil,nil,"+",{0,-90,0}))

	--中间线
	table.insert(fishes, MakeFish(1001,0,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1013,2,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1001,4,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1016,6,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1015,7.8,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1016,12,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1002,15,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1002,16,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1002,17,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1002,18,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1002,19,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1001,24,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1013,26,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1001,28,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1016,30,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1015,31.8,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1016,36,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1002,39,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1002,40,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1002,41,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1002,42,nil,{5001},nil,nil,nil,"+",{0,-110,0}))
	table.insert(fishes, MakeFish(1002,43,nil,{5001},nil,nil,nil,"+",{0,-110,0}))

	--往下一层
	table.insert(fishes, MakeFish(1002,15,nil,{5001},nil,nil,nil,"+",{0,-130,0}))
	table.insert(fishes, MakeFish(1002,16,nil,{5001},nil,nil,nil,"+",{0,-130,0}))
	table.insert(fishes, MakeFish(1002,18,nil,{5001},nil,nil,nil,"+",{0,-130,0}))
	table.insert(fishes, MakeFish(1002,19,nil,{5001},nil,nil,nil,"+",{0,-130,0}))
	table.insert(fishes, MakeFish(1002,39,nil,{5001},nil,nil,nil,"+",{0,-130,0}))
	table.insert(fishes, MakeFish(1002,40,nil,{5001},nil,nil,nil,"+",{0,-130,0}))
	table.insert(fishes, MakeFish(1002,42,nil,{5001},nil,nil,nil,"+",{0,-130,0}))
	table.insert(fishes, MakeFish(1002,43,nil,{5001},nil,nil,nil,"+",{0,-130,0}))
	--往下二层
	table.insert(fishes, MakeFish(1001,1,nil,{5001},nil,nil,nil,"+",{0,-140,0}))
	table.insert(fishes, MakeFish(1001,4,nil,{5001},nil,nil,nil,"+",{0,-140,0}))
	table.insert(fishes, MakeFish(1001,25,nil,{5001},nil,nil,nil,"+",{0,-140,0}))
	table.insert(fishes, MakeFish(1001,28,nil,{5001},nil,nil,nil,"+",{0,-140,0}))
	--往下三层
	table.insert(fishes, MakeFish(1002,5,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,6,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,7,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,8,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,9,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,10,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,11,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,12,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,13,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,14,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,19,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,20,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,29,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,30,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,31,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,32,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,33,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,34,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,35,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,36,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,37,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,38,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,43,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	table.insert(fishes, MakeFish(1002,44,nil,{5001},nil,nil,nil,"+",{0,-150,0}))
	--往下四层
	table.insert(fishes, MakeFish(1001,1.8,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1001,4,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,5,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,6,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,7,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,8,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,9,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,10,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,11,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,12,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,20,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,21,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1001,25.8,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1001,28,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,29,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,30,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,31,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,32,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,33,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,34,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,35,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,36,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,44,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	table.insert(fishes, MakeFish(1002,45,nil,{5001},nil,nil,nil,"+",{0,-170,0}))
	--往下五层
	table.insert(fishes, MakeFish(3005,5,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(3005,6,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(1002,7,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(1002,8,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(1002,9,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(1002,10,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(1002,21,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(3005,29,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(3005,30,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(1002,31,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(1002,32,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(1002,33,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(1002,34,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	table.insert(fishes, MakeFish(1002,45,nil,{5001},nil,nil,nil,"+",{0,-190,0}))
	--往下六层
	table.insert(fishes, MakeFish(1001,2.7,nil,{5001},nil,nil,nil,"+",{0,-200,0}))
	table.insert(fishes, MakeFish(1001,4,nil,{5001},nil,nil,nil,"+",{0,-200,0}))
	table.insert(fishes, MakeFish(1001,26.7,nil,{5001},nil,nil,nil,"+",{0,-200,0}))
	table.insert(fishes, MakeFish(1001,28,nil,{5001},nil,nil,nil,"+",{0,-200,0}))
	--往下七层
	table.insert(fishes, MakeFish(1002,5,nil,{5001},nil,nil,nil,"+",{0,-210,0}))
	table.insert(fishes, MakeFish(1002,6,nil,{5001},nil,nil,nil,"+",{0,-210,0}))
	table.insert(fishes, MakeFish(1002,7,nil,{5001},nil,nil,nil,"+",{0,-210,0}))
	table.insert(fishes, MakeFish(1002,8,nil,{5001},nil,nil,nil,"+",{0,-210,0}))
	table.insert(fishes, MakeFish(1002,29,nil,{5001},nil,nil,nil,"+",{0,-210,0}))
	table.insert(fishes, MakeFish(1002,30,nil,{5001},nil,nil,nil,"+",{0,-210,0}))
	table.insert(fishes, MakeFish(1002,31,nil,{5001},nil,nil,nil,"+",{0,-210,0}))
	table.insert(fishes, MakeFish(1002,32,nil,{5001},nil,nil,nil,"+",{0,-210,0}))
	--往下八层
	table.insert(fishes, MakeFish(1001,3.5,nil,{5001},nil,nil,nil,"+",{0,-230,0}))
	table.insert(fishes, MakeFish(1001,4,nil,{5001},nil,nil,nil,"+",{0,-230,0}))
	table.insert(fishes, MakeFish(1002,5,nil,{5001},nil,nil,nil,"+",{0,-230,0}))
	table.insert(fishes, MakeFish(1002,6,nil,{5001},nil,nil,nil,"+",{0,-230,0}))
	table.insert(fishes, MakeFish(1002,27,nil,{5001},nil,nil,nil,"+",{0,-230,0}))
	table.insert(fishes, MakeFish(1002,28,nil,{5001},nil,nil,nil,"+",{0,-230,0}))
	table.insert(fishes, MakeFish(1002,29,nil,{5001},nil,nil,nil,"+",{0,-230,0}))
	table.insert(fishes, MakeFish(1002,30,nil,{5001},nil,nil,nil,"+",{0,-230,0}))

	AddFish(fishes)
	SetFormFinishTime(50)
	SetTimeout(60,addFish)
end


local function fishForm2() --滚筒从左到右
	-- body
	local fishes = {}
	table.insert(fishes, MakeFish(1004,0,nil,{5119}))
	table.insert(fishes, MakeFish(1001,0,nil,{5123}))
	table.insert(fishes, MakeFish(1002,0,nil,{5127}))
	table.insert(fishes, MakeFish(1006,0,nil,{5131}))
	table.insert(fishes, MakeFish(1001,1.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,1.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,2.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,2.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,2.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,2.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,3.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,3.75,nil,{5131}))
	table.insert(fishes, MakeFish(1004,5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,6.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,6.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,7.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,7.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,7.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,7.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,8.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,8.75,nil,{5131}))

	table.insert(fishes, MakeFish(1018,0,nil,{5135}))

	table.insert(fishes, MakeFish(3005,10,nil,{5119}))
	table.insert(fishes, MakeFish(3005,10,nil,{5123}))
	table.insert(fishes, MakeFish(3005,10,nil,{5127}))
	table.insert(fishes, MakeFish(3005,10,nil,{5131}))
	table.insert(fishes, MakeFish(1001,11.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,11.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,12.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,12.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,12.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,12.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,13.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,13.75,nil,{5131}))
	table.insert(fishes, MakeFish(1004,15,nil,{5119}))
	table.insert(fishes, MakeFish(1001,15,nil,{5123}))
	table.insert(fishes, MakeFish(1002,15,nil,{5127}))
	table.insert(fishes, MakeFish(1006,15,nil,{5131}))
	table.insert(fishes, MakeFish(1001,16.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,16.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,17.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,17.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,17.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,17.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,18.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,18.75,nil,{5131}))

	table.insert(fishes, MakeFish(1025,15,nil,{5135}))

	table.insert(fishes, MakeFish(1004,20,nil,{5119}))
	table.insert(fishes, MakeFish(1001,20,nil,{5123}))
	table.insert(fishes, MakeFish(1002,20,nil,{5127}))
	table.insert(fishes, MakeFish(1006,20,nil,{5131}))
	table.insert(fishes, MakeFish(1001,21.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,21.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,22.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,22.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,22.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,22.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,23.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,23.75,nil,{5131}))
	table.insert(fishes, MakeFish(1004,25,nil,{5119}))
	table.insert(fishes, MakeFish(1001,25,nil,{5123}))
	table.insert(fishes, MakeFish(1002,25,nil,{5127}))
	table.insert(fishes, MakeFish(1006,25,nil,{5131}))
	table.insert(fishes, MakeFish(1001,26.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,26.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,27.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,27.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,27.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,27.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,28.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,28.75,nil,{5131}))

	table.insert(fishes, MakeFish(1024,30,nil,{5135}))

	table.insert(fishes, MakeFish(3005,30,nil,{5119}))
	table.insert(fishes, MakeFish(3005,30,nil,{5123}))
	table.insert(fishes, MakeFish(3005,30,nil,{5127}))
	table.insert(fishes, MakeFish(3005,30,nil,{5131}))
	table.insert(fishes, MakeFish(1001,31.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,31.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,32.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,32.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,32.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,32.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,33.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,33.75,nil,{5131}))
	table.insert(fishes, MakeFish(1004,35,nil,{5119}))
	table.insert(fishes, MakeFish(1001,35,nil,{5123}))
	table.insert(fishes, MakeFish(1002,35,nil,{5127}))
	table.insert(fishes, MakeFish(1006,35,nil,{5131}))
	table.insert(fishes, MakeFish(1001,36.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,36.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,37.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,37.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,37.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,37.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,38.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,38.75,nil,{5131}))

	table.insert(fishes, MakeFish(1020,45,nil,{5135}))

	table.insert(fishes, MakeFish(1004,40,nil,{5119}))
	table.insert(fishes, MakeFish(1001,40,nil,{5123}))
	table.insert(fishes, MakeFish(1002,40,nil,{5127}))
	table.insert(fishes, MakeFish(1006,40,nil,{5131}))
	table.insert(fishes, MakeFish(1001,41.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,41.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,42.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,42.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,42.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,42.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,43.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,43.75,nil,{5131}))
	table.insert(fishes, MakeFish(1004,45,nil,{5119}))
	table.insert(fishes, MakeFish(1001,45,nil,{5123}))
	table.insert(fishes, MakeFish(1002,45,nil,{5127}))
	table.insert(fishes, MakeFish(1006,45,nil,{5131}))
	table.insert(fishes, MakeFish(1001,46.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,46.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,47.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,47.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,47.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,47.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,48.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,48.75,nil,{5131}))
	table.insert(fishes, MakeFish(1004,50,nil,{5119}))
	table.insert(fishes, MakeFish(1001,50,nil,{5123}))
	table.insert(fishes, MakeFish(1002,50,nil,{5127}))
	table.insert(fishes, MakeFish(1006,50,nil,{5131}))
	table.insert(fishes, MakeFish(1001,51.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,51.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,52.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,52.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,52.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,52.5,nil,{5131}))
	table.insert(fishes, MakeFish(1001,53.75,nil,{5123}))
	table.insert(fishes, MakeFish(1006,53.75,nil,{5131}))
	table.insert(fishes, MakeFish(1004,55,nil,{5119}))
	table.insert(fishes, MakeFish(1001,55,nil,{5123}))
	table.insert(fishes, MakeFish(1002,55,nil,{5127}))
	table.insert(fishes, MakeFish(1006,55,nil,{5131}))
	table.insert(fishes, MakeFish(1001,56.25,nil,{5123}))
	table.insert(fishes, MakeFish(1006,56.25,nil,{5131}))
	table.insert(fishes, MakeFish(1004,57.5,nil,{5119}))
	table.insert(fishes, MakeFish(1001,57.5,nil,{5123}))
	table.insert(fishes, MakeFish(1002,57.5,nil,{5127}))
	table.insert(fishes, MakeFish(1006,57.5,nil,{5131}))

	AddFish(fishes)
	SetFormFinishTime(56)
	SetTimeout(89, stopForm)
end

local function fishForm3() --交错阵型
	-- MakeFish(type, delay, parent, path, pos, rot, lifeTime)
	local fishes = {}
	local p = MakeFish(0,0,nil,nil,{0,-150,300}, {0,0,0},30.5)
	table.insert(fishes, p)
	table.insert(fishes, MakeFish(1001,0,p,{5201}))
	table.insert(fishes, MakeFish(1001,0,p,{5202}))
	table.insert(fishes, MakeFish(1001,0,p,{5203}))
	table.insert(fishes, MakeFish(1001,0,p,{5204}))
	table.insert(fishes, MakeFish(1001,0,p,{5205}))
	table.insert(fishes, MakeFish(1001,0,p,{5206}))
	table.insert(fishes, MakeFish(1001,0,p,{5207}))
	table.insert(fishes, MakeFish(1001,0,p,{5208}))
	table.insert(fishes, MakeFish(1001,0,p,{5209}))
	table.insert(fishes, MakeFish(1001,0,p,{5210}))
	AddFish(fishes)
	SetTimeout(27, stopForm)
end

local function fishForm4() --双层小鱼包大鱼
	-- MakeFish(type, delay, parent, path, pos, rot, lifeTime)
	local fishes = {}
	for i=0,50 do		
    	local fish
    	if i == 4 or i == 9 or i == 14 or i == 19 or i == 24 or i == 29 or i == 34 or i == 39 or i == 44 or i == 49 then 
     		fish = MakeFish(3005,i,nil,{5301})
			table.insert(fishes, fish)
    	else
        	fish = MakeFish(1002,i,nil,{5301})
			table.insert(fishes, fish)
			fish = MakeFish(1005,i+0.5,nil,{5302})
			table.insert(fishes, fish)
     	end
	end

	table.insert(fishes, MakeFish(1015,0,p,{5303}))
	table.insert(fishes, MakeFish(1015,4,p,{5306}))
	table.insert(fishes, MakeFish(1015,4,p,{5307}))
	table.insert(fishes, MakeFish(1015,8,p,{5303}))
	table.insert(fishes, MakeFish(1016,13,p,{5303}))
	table.insert(fishes, MakeFish(1017,18,p,{5308}))
	table.insert(fishes, MakeFish(1018,26,p,{5308}))
	table.insert(fishes, MakeFish(1014,33,p,{5308}))
    for i=0,50 do																						
		local fish
        if i == 4 or i == 9 or i == 14 or i == 19 or i == 24 or i == 29 or i == 34 or i == 39 or i == 44 or i == 49 then 
          fish = MakeFish(3005,i,nil,{5304})
          table.insert(fishes, fish)
      else
		  fish = MakeFish(1005,i+0.5,nil,{5304})
		  table.insert(fishes, fish)
		  fish = MakeFish(1002,i,nil,{5305})
        end
		  table.insert(fishes, fish)
	end

	AddFish(fishes)
	SetFormFinishTime(56)
	SetTimeout(65, stopForm)
end

local function fishForm5() --半圈包围大鱼
	-- MakeFish(type, delay, parent, path, pos, rot, lifeTime)
	local fishes = {}
	for i=0,50 do
		local fish
        if i == 1 or i == 9 or i == 19 or i == 29 or i == 39 or i == 49 then
        	fish = MakeFish(3005,i,nil,{5401})
        else
			fish = MakeFish(1011,i,nil,{5401})
        end
		table.insert(fishes, fish)
    end

	table.insert(fishes, MakeFish(1020,0,p,{5403,5404,5405}))
	table.insert(fishes, MakeFish(1020,0,p,{5406,5407,5408}))
    
    for i=0,50 do
	    local fish
        if i == 1 or i == 9 or i == 19 or i == 29 or i == 39 or i == 49 then
          fish = MakeFish(3005,i,nil,{5402})
        else
	      fish = MakeFish(1011,i,nil,{5402})
        end
	    table.insert(fishes, fish)
	end

	AddFish(fishes)
	SetFormFinishTime(56)
	SetTimeout(65, stopForm)
end
 
-- local function fishForm6()
-- 	local fishes = {}
-- 	-- MakeFish(type, delay, parent, path, pos, rot, lifeTime)
-- 	table.insert(fishes, MakeFish(1001,0,nil,{1}))
-- 	table.insert(fishes, MakeFish(1002,3,nil,{2}))
-- 	table.insert(fishes, MakeFish(1003,6,nil,{3}))
-- 	table.insert(fishes, MakeFish(1004,0,nil,{4}))
-- 	table.insert(fishes, MakeFish(1005,3,nil,{5}))
-- 	table.insert(fishes, MakeFish(1006,6,nil,{6}))
-- 	table.insert(fishes, MakeFish(1007,9,nil,{7}))
-- 	table.insert(fishes, MakeFish(1008,12,nil,{8}))
-- 	table.insert(fishes, MakeFish(1009,15,nil,{9}))
-- 	table.insert(fishes, MakeFish(1010,0,nil,{10}))
-- 	table.insert(fishes, MakeFish(1011,3,nil,{11}))
-- 	table.insert(fishes, MakeFish(1012,6,nil,{12}))
-- 	table.insert(fishes, MakeFish(1013,9,nil,{13}))
-- 	table.insert(fishes, MakeFish(1014,12,nil,{14}))
-- 	table.insert(fishes, MakeFish(1015,15,nil,{15}))
-- 	table.insert(fishes, MakeFish(1016,0,nil,{16}))
-- 	table.insert(fishes, MakeFish(1017,4,nil,{17}))
-- 	table.insert(fishes, MakeFish(1018,8,nil,{18}))
-- 	table.insert(fishes, MakeFish(1019,12,nil,{19}))
-- 	table.insert(fishes, MakeFish(1020,16,nil,{20}))
-- 	table.insert(fishes, MakeFish(1021,18,nil,{21}))
-- 	table.insert(fishes, MakeFish(1022,20,nil,{22}))
-- 	table.insert(fishes, MakeFish(1023,22,nil,{23}))
-- 	table.insert(fishes, MakeFish(1024,24,nil,{24}))
-- 	table.insert(fishes, MakeFish(1025,26,nil,{25}))
-- 	table.insert(fishes, MakeFish(1026,28,nil,{26}))
-- 	table.insert(fishes, MakeFish(1027,30,nil,{27}))
-- 	table.insert(fishes, MakeFish(1028,32,nil,{28}))
-- 	table.insert(fishes, MakeFish(1029,34,nil,{29}))
-- 	table.insert(fishes, MakeFish(1030,36,nil,{30}))
-- 	table.insert(fishes, MakeFish(1031,38,nil,{31}))
-- 	table.insert(fishes, MakeFish(1032,40,nil,{32}))
-- 	table.insert(fishes, MakeFish(1033,42,nil,{33}))
-- 	AddFish(fishes)

-- 	SetTimeout(50, stopForm)
-- end

local function fishForm7() --4方缺角方阵
	local fishes = {}

	table.insert(fishes, MakeFish(1016,1.0,nil,{5708}))
	table.insert(fishes, MakeFish(1020,8.0,nil,{5708}))
	table.insert(fishes, MakeFish(1016,1.0,nil,{5709}))
	table.insert(fishes, MakeFish(1020,8.0,nil,{5709}))

	table.insert(fishes, MakeFish(1005,3.4,nil,{5701}))
	table.insert(fishes, MakeFish(1005,5.1,nil,{5701}))
	table.insert(fishes, MakeFish(1005,6.8,nil,{5701}))
	table.insert(fishes, MakeFish(1004,8.5,nil,{5701}))
	table.insert(fishes, MakeFish(1005,10.2,nil,{5701}))
	table.insert(fishes, MakeFish(1005,11.9,nil,{5701}))
	table.insert(fishes, MakeFish(1005,13.6,nil,{5701}))

	table.insert(fishes, MakeFish(1005,1.7,nil,{5702}))
	table.insert(fishes, MakeFish(1005,3.4,nil,{5702}))
	table.insert(fishes, MakeFish(1004,5.1,nil,{5702}))
	table.insert(fishes, MakeFish(1005,6.8,nil,{5702}))
	table.insert(fishes, MakeFish(3005,8.5,nil,{5702}))
	table.insert(fishes, MakeFish(1005,10.2,nil,{5702}))
	table.insert(fishes, MakeFish(1004,11.9,nil,{5702}))
	table.insert(fishes, MakeFish(1005,13.6,nil,{5702}))
	table.insert(fishes, MakeFish(1005,15.3,nil,{5702}))

	table.insert(fishes, MakeFish(1005,0,nil,{5703}))
	table.insert(fishes, MakeFish(1005,1.7,nil,{5703}))
	table.insert(fishes, MakeFish(1004,3.4,nil,{5703}))
	table.insert(fishes, MakeFish(1005,5.1,nil,{5703}))
	table.insert(fishes, MakeFish(1005,6.8,nil,{5703}))
	table.insert(fishes, MakeFish(1005,8.5,nil,{5703}))
	table.insert(fishes, MakeFish(1004,10.2,nil,{5703}))
	table.insert(fishes, MakeFish(1005,11.9,nil,{5703}))
	table.insert(fishes, MakeFish(1005,13.6,nil,{5703}))
	table.insert(fishes, MakeFish(1005,15.3,nil,{5703}))
	table.insert(fishes, MakeFish(3005,17,nil,{5703}))
	table.insert(fishes, MakeFish(1005,0,nil,{5704}))
	table.insert(fishes, MakeFish(1005,1.7,nil,{5704}))
	table.insert(fishes, MakeFish(1005,3.4,nil,{5704}))
	table.insert(fishes, MakeFish(1004,5.1,nil,{5704}))
	table.insert(fishes, MakeFish(1005,6.8,nil,{5704}))
	table.insert(fishes, MakeFish(1005,8.5,nil,{5704}))
	table.insert(fishes, MakeFish(1005,10.2,nil,{5704}))
	table.insert(fishes, MakeFish(1004,11.9,nil,{5704}))
	table.insert(fishes, MakeFish(1005,13.6,nil,{5704}))
	table.insert(fishes, MakeFish(1005,15.3,nil,{5704}))
	table.insert(fishes, MakeFish(1005,17,nil,{5704}))
	table.insert(fishes, MakeFish(3005,0,nil,{5705}))
	table.insert(fishes, MakeFish(1005,1.7,nil,{5705}))
	table.insert(fishes, MakeFish(1005,3.4,nil,{5705}))
	table.insert(fishes, MakeFish(1005,5.1,nil,{5705}))
	table.insert(fishes, MakeFish(1004,6.8,nil,{5705}))
	table.insert(fishes, MakeFish(1005,8.5,nil,{5705}))
	table.insert(fishes, MakeFish(1005,10.2,nil,{5705}))
	table.insert(fishes, MakeFish(1005,11.9,nil,{5705}))
	table.insert(fishes, MakeFish(1004,13.6,nil,{5705}))
	table.insert(fishes, MakeFish(1005,15.3,nil,{5705}))
	table.insert(fishes, MakeFish(1005,17,nil,{5705}))

	table.insert(fishes, MakeFish(1005,1.7,nil,{5706}))
	table.insert(fishes, MakeFish(1005,3.4,nil,{5706}))
	table.insert(fishes, MakeFish(1005,5.1,nil,{5706}))
	table.insert(fishes, MakeFish(1004,6.8,nil,{5706}))
	table.insert(fishes, MakeFish(3005,8.5,nil,{5706}))
	table.insert(fishes, MakeFish(1004,10.2,nil,{5706}))
	table.insert(fishes, MakeFish(1005,11.9,nil,{5706}))
	table.insert(fishes, MakeFish(1005,13.6,nil,{5706}))
	table.insert(fishes, MakeFish(1005,15.3,nil,{5706}))

	table.insert(fishes, MakeFish(1005,3.4,nil,{5707}))
	table.insert(fishes, MakeFish(1005,5.1,nil,{5707}))
	table.insert(fishes, MakeFish(1005,6.8,nil,{5707}))
	table.insert(fishes, MakeFish(1004,8.5,nil,{5707}))
	table.insert(fishes, MakeFish(1005,10.2,nil,{5707}))
	table.insert(fishes, MakeFish(1005,11.9,nil,{5707}))
	table.insert(fishes, MakeFish(1005,13.6,nil,{5707}))

	AddFish(fishes)
	SetFormFinishTime(16)
	SetTimeout(40, stopForm)
end


local function fishForm8() --4角小丑中蝙蝠
	local fishes = {}
	table.insert(fishes, MakeFish(1008,0,nil,{5801}))
	table.insert(fishes, MakeFish(1008,2.5,nil,{5801}))
	table.insert(fishes, MakeFish(1011,5,nil,{5801}))
	table.insert(fishes, MakeFish(1008,7.5,nil,{5801}))
	table.insert(fishes, MakeFish(1008,10,nil,{5801}))
	table.insert(fishes, MakeFish(1011,12.5,nil,{5801}))
	table.insert(fishes, MakeFish(3005,15,nil,{5801}))
	table.insert(fishes, MakeFish(1008,17.5,nil,{5801}))
	table.insert(fishes, MakeFish(1008,20,nil,{5801}))
	table.insert(fishes, MakeFish(1011,22.5,nil,{5801}))
	table.insert(fishes, MakeFish(1008,25,nil,{5801}))
	table.insert(fishes, MakeFish(1008,27.5,nil,{5801}))
	table.insert(fishes, MakeFish(1011,30,nil,{5801}))

	table.insert(fishes, MakeFish(1008,0,nil,{5802}))
	table.insert(fishes, MakeFish(1008,2.5,nil,{5802}))
	table.insert(fishes, MakeFish(1011,5,nil,{5802}))
	table.insert(fishes, MakeFish(1008,7.5,nil,{5802}))
	table.insert(fishes, MakeFish(1008,10,nil,{5802}))
	table.insert(fishes, MakeFish(1011,12.5,nil,{5802}))
	table.insert(fishes, MakeFish(3005,15,nil,{5802}))
	table.insert(fishes, MakeFish(1008,17.5,nil,{5802}))
	table.insert(fishes, MakeFish(1008,20,nil,{5802}))
	table.insert(fishes, MakeFish(1011,22.5,nil,{5802}))
	table.insert(fishes, MakeFish(1008,25,nil,{5802}))
	table.insert(fishes, MakeFish(1008,27.5,nil,{5802}))
	table.insert(fishes, MakeFish(1011,30,nil,{5802}))

	table.insert(fishes, MakeFish(1008,0,nil,{5803}))
	table.insert(fishes, MakeFish(1008,2.5,nil,{5803}))
	table.insert(fishes, MakeFish(1011,5,nil,{5803}))
	table.insert(fishes, MakeFish(1008,7.5,nil,{5803}))
	table.insert(fishes, MakeFish(1008,10,nil,{5803}))
	table.insert(fishes, MakeFish(1011,12.5,nil,{5803}))
	table.insert(fishes, MakeFish(3005,15,nil,{5803}))
	table.insert(fishes, MakeFish(1008,17.5,nil,{5803}))
	table.insert(fishes, MakeFish(1008,20,nil,{5803}))
	table.insert(fishes, MakeFish(1011,22.5,nil,{5803}))
	table.insert(fishes, MakeFish(1008,25,nil,{5803}))
	table.insert(fishes, MakeFish(1008,27.5,nil,{5803}))
	table.insert(fishes, MakeFish(1011,30,nil,{5803}))

	table.insert(fishes, MakeFish(1008,0,nil,{5804}))
	table.insert(fishes, MakeFish(1008,2.5,nil,{5804}))
	table.insert(fishes, MakeFish(1011,5,nil,{5804}))
	table.insert(fishes, MakeFish(1008,7.5,nil,{5804}))
	table.insert(fishes, MakeFish(1008,10,nil,{5804}))
	table.insert(fishes, MakeFish(1011,12.5,nil,{5804}))
	table.insert(fishes, MakeFish(3005,15,nil,{5804}))
	table.insert(fishes, MakeFish(1008,17.5,nil,{5804}))
	table.insert(fishes, MakeFish(1008,20,nil,{5804}))
	table.insert(fishes, MakeFish(1011,22.5,nil,{5804}))
	table.insert(fishes, MakeFish(1008,25,nil,{5804}))
	table.insert(fishes, MakeFish(1008,27.5,nil,{5804}))
	table.insert(fishes, MakeFish(1011,30,nil,{5804}))

	table.insert(fishes, MakeFish(1018,0,nil,{5805}))
	table.insert(fishes, MakeFish(1020,10,nil,{5805}))
	table.insert(fishes, MakeFish(1018,20,nil,{5805}))

	AddFish(fishes)
	SetFormFinishTime(31)
	SetTimeout(50, stopForm)
end

local function fishForm9() --固定螺旋
	local fishes = {}
	table.insert(fishes, MakeFish(1001,0,nil,{5901}))
	table.insert(fishes, MakeFish(1001,1.5,nil,{5902}))
	table.insert(fishes, MakeFish(1001,3,nil,{5903}))
	table.insert(fishes, MakeFish(1006,4.5,nil,{5904}))
	table.insert(fishes, MakeFish(1001,6,nil,{5905}))
	table.insert(fishes, MakeFish(1001,7.5,nil,{5906}))
	table.insert(fishes, MakeFish(1001,9,nil,{5907}))
	table.insert(fishes, MakeFish(1006,10.5,nil,{5908}))
	table.insert(fishes, MakeFish(1001,12,nil,{5909}))
	table.insert(fishes, MakeFish(1001,13.5,nil,{5910}))
	table.insert(fishes, MakeFish(1001,15,nil,{5911}))
	table.insert(fishes, MakeFish(3005,16.5,nil,{5912}))
	table.insert(fishes, MakeFish(1001,18,nil,{5913}))
	table.insert(fishes, MakeFish(1001,19.5,nil,{5914}))
	table.insert(fishes, MakeFish(1001,21,nil,{5915}))
	table.insert(fishes, MakeFish(1006,22.5,nil,{5916}))
	table.insert(fishes, MakeFish(1001,24,nil,{5901}))
	table.insert(fishes, MakeFish(1001,25.5,nil,{5902}))
	table.insert(fishes, MakeFish(1001,27,nil,{5903}))
	table.insert(fishes, MakeFish(1006,28.5,nil,{5904}))
	table.insert(fishes, MakeFish(1001,30,nil,{5905}))
	table.insert(fishes, MakeFish(1001,31.5,nil,{5906}))
	table.insert(fishes, MakeFish(1001,33,nil,{5907}))
	table.insert(fishes, MakeFish(1006,34.5,nil,{5908}))
	table.insert(fishes, MakeFish(1001,36,nil,{5901}))

	table.insert(fishes, MakeFish(1006,0,nil,{5909}))
	table.insert(fishes, MakeFish(1006,1.5,nil,{5910}))
	table.insert(fishes, MakeFish(1006,3,nil,{5911}))
	table.insert(fishes, MakeFish(1001,4.5,nil,{5912}))
	table.insert(fishes, MakeFish(1006,6,nil,{5913}))
	table.insert(fishes, MakeFish(1006,7.5,nil,{5914}))
	table.insert(fishes, MakeFish(1006,9,nil,{5915}))
	table.insert(fishes, MakeFish(1001,10.5,nil,{5916}))
	table.insert(fishes, MakeFish(1006,12,nil,{5901}))
	table.insert(fishes, MakeFish(1006,13.5,nil,{5902}))
	table.insert(fishes, MakeFish(1006,15,nil,{5903}))
	table.insert(fishes, MakeFish(3005,16.5,nil,{5904}))
	table.insert(fishes, MakeFish(1006,18,nil,{5905}))
	table.insert(fishes, MakeFish(1006,19.5,nil,{5906}))
	table.insert(fishes, MakeFish(1006,21,nil,{5907}))
	table.insert(fishes, MakeFish(1001,22.5,nil,{5908}))
	table.insert(fishes, MakeFish(1006,24,nil,{5909}))
	table.insert(fishes, MakeFish(1006,25.5,nil,{5910}))
	table.insert(fishes, MakeFish(1006,27,nil,{5911}))
	table.insert(fishes, MakeFish(1001,28.5,nil,{5912}))
	table.insert(fishes, MakeFish(1006,30,nil,{5913}))
	table.insert(fishes, MakeFish(1006,31.5,nil,{5914}))
	table.insert(fishes, MakeFish(1006,33,nil,{5915}))
	table.insert(fishes, MakeFish(1001,34.5,nil,{5916}))
	table.insert(fishes, MakeFish(1006,36,nil,{5909}))

	table.insert(fishes, MakeFish(1020,6,nil,{5917}))
	table.insert(fishes, MakeFish(1020,18,nil,{5917}))
	table.insert(fishes, MakeFish(1020,30,nil,{5917}))

	AddFish(fishes)
	SetFormFinishTime(37)
	SetTimeout(50, stopForm)
end



local function fishForm11()
	--驾立测试一网打尽
	local fishes = {}
	-- MakeFish(type, delay, parent, path, pos, rot, lifeTime)
 table.insert(fishes, MakeFish(2004,0,nil,{11101}))	
 table.insert(fishes, MakeFish(2005,0,nil,{11102}))	
 table.insert(fishes, MakeFish(2006,0,nil,{11103}))	
 table.insert(fishes, MakeFish(2008,0,nil,{11104}))	
 table.insert(fishes, MakeFish(2009,0,nil,{11105}))	
 table.insert(fishes, MakeFish(2010,0,nil,{11106}))	
 table.insert(fishes, MakeFish(2012,0,nil,{11107}))	
 table.insert(fishes, MakeFish(2014,0,nil,{11208}))	
 table.insert(fishes, MakeFish(2016,0,nil,{11209}))	

	AddFish(fishes)
	SetTimeout(200, stopForm)
end

local function fishForm13() --回旋鱼潮
	local fishes = {}
	-- MakeFish(type, delay, parent, path, pos, rot, lifeTime)
	-- local p = MakeFish(0,0,nil,{5003,5001,5002},nil,nil)
	-- table.insert(fishes, p)
	table.insert(fishes, MakeFish(1016,0,nil,{6218,6208,6238,6228}))
	table.insert(fishes, MakeFish(1016,2.5,nil,{6218,6208,6238,6228}))
	table.insert(fishes, MakeFish(1016,5,nil,{6218,6208,6238,6228}))
	table.insert(fishes, MakeFish(1016,7.5,nil,{6218,6208,6238,6228}))
	table.insert(fishes, MakeFish(1016,0,nil,{6219,6209,6239,6229}))
	table.insert(fishes, MakeFish(1016,2.5,nil,{6219,6209,6239,6229}))
	table.insert(fishes, MakeFish(1016,5,nil,{6219,6209,6239,6229}))
	table.insert(fishes, MakeFish(1016,7.5,nil,{6219,6209,6239,6229}))

	table.insert(fishes, MakeFish(1011,0,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,0.5,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,1,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,1.5,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,2,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,2.5,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,3,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(3005,3.5,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,4,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,4.5,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,5,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,5.5,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,6,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,6.5,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,7,nil,{6211,6201,6231,6221}))
	table.insert(fishes, MakeFish(1011,7.5,nil,{6211,6201,6231,6221}))

	table.insert(fishes, MakeFish(1008,0,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,0.5,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,1,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,1.5,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,2,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,2.5,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,3,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,3.5,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,4,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,4.5,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,5,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,5.5,nil,{6212,6202,6232,6222}))
	table.insert(fishes, MakeFish(1008,6,nil,{6212,6202,6232,6222}))

	table.insert(fishes, MakeFish(1008,0,nil,{6213,6203,6233,6223}))
	table.insert(fishes, MakeFish(1008,0.5,nil,{6213,6203,6233,6223}))
	table.insert(fishes, MakeFish(1008,1,nil,{6213,6203,6233,6223}))
	table.insert(fishes, MakeFish(1008,1.5,nil,{6213,6203,6233,6223}))
	table.insert(fishes, MakeFish(1008,2,nil,{6213,6203,6233,6223}))
	table.insert(fishes, MakeFish(1008,2.5,nil,{6213,6203,6233,6223}))
	table.insert(fishes, MakeFish(1008,3,nil,{6213,6203,6233,6223}))
	table.insert(fishes, MakeFish(1008,3.5,nil,{6213,6203,6233,6223}))
	table.insert(fishes, MakeFish(1008,4,nil,{6213,6203,6233,6223}))

	table.insert(fishes, MakeFish(1008,0,nil,{6214,6204,6234,6224}))
	table.insert(fishes, MakeFish(1008,0.5,nil,{6214,6204,6234,6224}))
	table.insert(fishes, MakeFish(1008,1,nil,{6214,6204,6234,6224}))
	table.insert(fishes, MakeFish(1008,1.5,nil,{6214,6204,6234,6224}))
	table.insert(fishes, MakeFish(1008,2,nil,{6214,6204,6234,6224}))

	table.insert(fishes, MakeFish(1008,0,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,0.5,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,1,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,1.5,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,2,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,2.5,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,3,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,3.5,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,4,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,4.5,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,5,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,5.5,nil,{6215,6205,6235,6225}))
	table.insert(fishes, MakeFish(1008,6,nil,{6215,6205,6235,6225}))

	table.insert(fishes, MakeFish(1008,0,nil,{6216,6206,6236,6226}))
	table.insert(fishes, MakeFish(1008,0.5,nil,{6216,6206,6236,6226}))
	table.insert(fishes, MakeFish(1008,1,nil,{6216,6206,6236,6226}))
	table.insert(fishes, MakeFish(1008,1.5,nil,{6216,6206,6236,6226}))
	table.insert(fishes, MakeFish(1008,2,nil,{6216,6206,6236,6226}))
	table.insert(fishes, MakeFish(1008,2.5,nil,{6216,6206,6236,6226}))
	table.insert(fishes, MakeFish(1008,3,nil,{6216,6206,6236,6226}))
	table.insert(fishes, MakeFish(1008,3.5,nil,{6216,6206,6236,6226}))
	table.insert(fishes, MakeFish(1008,4,nil,{6216,6206,6236,6226}))

	table.insert(fishes, MakeFish(1008,0,nil,{6217,6207,6237,6227}))
	table.insert(fishes, MakeFish(1008,0.5,nil,{6217,6207,6237,6227}))
	table.insert(fishes, MakeFish(1008,1,nil,{6217,6207,6237,6227}))
	table.insert(fishes, MakeFish(1008,1.5,nil,{6217,6207,6237,6227}))
	table.insert(fishes, MakeFish(1008,2,nil,{6217,6207,6237,6227}))

	AddFish(fishes)
	SetFormFinishTime(10)
	SetTimeout(65, stopForm)
end

local usedFormList

local FishFormList = {
	fishForm1,--左右来往
	fishForm2,--旋转螺旋
	fishForm3,--远处过来
	fishForm4,--双层包
	fishForm5,--半圈包
	fishForm6,--全鱼展示
	fishForm7,--4方缺角方阵
	fishForm8,--4角小丑中蝙蝠/火焰蓝鲸
	fishForm9,--固定螺旋
	fishForm10,--无
	fishForm11,--一网打尽
	fishForm12,--电鳗
	fishForm13,--回旋
}

local function relashFishGroup()
	-- local list = {
	-- fishForm11,
	-- }
	
	local list = {}
	for i=1,#form_list do
		table.insert(list, FishFormList[form_list[i]])
	end

	local list2 = {}
	for i,v in ipairs(list) do
		if not table.indexof(usedFormList, v) then
			--如果使用过的list里面不存在v
			table.insert(list2, v)
		end
	end

	--从未使用过的鱼阵数组里面随机出一个鱼阵
	local form = list2[math.random(#list2)]

	--将即将要刷新的鱼阵放入已经使用过的list里面(放入队列末尾)，标记为已经使用
	table.insert(usedFormList, form)
	if #usedFormList > 4 then
		--如果已经使用过的鱼阵list长度超过4，那么删除队列中的第一个元素
		table.remove(usedFormList, 1)
	end

	form()
	-- SetTimeout(1, form)
end


local function reflashFishHandler()
	if refreshing then return end
	refreshing = true
	--这里做惊吓处理

	FormWillStart()

	SetTimeout(waitTime, relashFishGroup)
end

local bossCount
local function addBoss()
	local cfg = cfgFish[bossid]
	if cfg then
		if cfg.effects and cfg.effects[1] == "zhangyu" then
			bossCount = 8
			EnterBossScene(bossid)
			local fishes = {}
			-- (type, delay, parent, path, pos, rot, time, operation, parameter)
			table.insert(fishes, MakeFish(bossid,0,nil,nil,nil,nil,cfg.effects[4]))
			table.insert(fishes, MakeFish(bossid,0,nil,nil,nil,nil,cfg.effects[4]))
			table.insert(fishes, MakeFish(bossid,0,nil,nil,nil,nil,cfg.effects[4]))
			table.insert(fishes, MakeFish(bossid,0,nil,nil,nil,nil,cfg.effects[4]))
			table.insert(fishes, MakeFish(bossid,0,nil,nil,nil,nil,cfg.effects[4]))
			table.insert(fishes, MakeFish(bossid,0,nil,nil,nil,nil,cfg.effects[4]))
			table.insert(fishes, MakeFish(bossid,0,nil,nil,nil,nil,cfg.effects[4]))
			table.insert(fishes, MakeFish(bossid,0,nil,nil,nil,nil,cfg.effects[4]))
			AddFish(fishes)
			-- SetTimeout
		else
			bossCount = nil

			AddFish({MakeFish(bossid, 0, nil, sp_path[bossid])})
		end
		SetTimeout(bossTime, addBoss)
	end
end

local function addMaster()
	local count = GetFishCountByGroup(200)
	LOG_DEBUG("200 count="..count)
	if count < 1 then
		local list = GetFishPathByGroup(41)
		if list and #list > 0 then
			local path = list[math.random(#list)]
			AddFish({MakeFish(8001, 0, nil, {path})})
		end
	end
	SetTimeout(5, addMaster)
end

local function testFish()
	local parent = MakeFish(5004, 0, nil, nil, nil, nil, 20)
	-- local fish = MakeFish(5004, 0, parent, {1019}, nil, nil,nil,"*",{1,1,1})  --parameter_list[math.random(#parameter_list)]
	AddFish({parent})

	-- local parent = MakeFish(0, 0, nil, nil, nil, nil, 14)
	-- local fish = MakeFish(3003, 0, parent, {1020}, nil, nil,nil,"*",{1,1,1})  --parameter_list[math.random(#parameter_list)]
	-- AddFish({parent, fish})

	-- AddFish({MakeFish(4001, 0, nil, {60000,60001,60002})})
		
	SetTimeout(22, testFish)
end

function addFish()
	-- body
	refreshing = nil
	
	-- SetTimeout(10, testFish)
	if bossid then
		local cfg = cfgFish[bossid]
		if cfg then
			if cfg.effects and cfg.effects[1] == "zhangyu" then
				SetTimeout(10, addBoss)
			else
				SetTimeout(60, addBoss)
			end
		end
	end

	if mastertype and mastertype == 1 then
		SetTimeout(10, addMaster)
	end

	-- for k,v in pairs(fishCtrl) do
	-- 	v()
	-- end
	createFish(10)
	createFish(20)
	createFish(30, true)
	createFish(40, true)
	createFish(60, true)
	createFish(100, true)
	SetTimeout(2,createFish,61, true)
	-- fishForm7()
	-- SetTimeout(refTime, reflashFishHandler)
	-- CreatFish(1001,nil,nil,{5002})
	-- fishForm2()
end

function this.BossDie(id)
	if id and bossCount and bossid == id then
		bossCount = bossCount - 1
		if bossCount < 1 then
			ExitBossScene()
		end
	end
end

function this.SetCtrl(c, boss, mt)
	-- body
	mastertype = mt
	ctrl = c
	SetTimeout = ctrl.SetTimeout                    --(duration, handler, ...)duration:时间间隔，handler:待执行函数，...：待执行函数的参数
	GetFishTypeByGroup = ctrl.GetFishTypeByGroup 	--根据group取到该group下的所有的鱼type的一个数组。
	GetFishCountByGroup = ctrl.GetFishCountByGroup	--根据group取到当前场景中该group的所有的鱼的数量
	GetFishPathByGroup = ctrl.GetFishPathByGroup    --根据group获得鱼路径
	MakeFish = ctrl.MakeFish                        --生成一个鱼/父级  MakeFish(type, delay, parent, path, pos, rot, time(没有就取path的时间), operation, parameter)  operation："+-*/" parameter：{x,y,z}
	AddFish = ctrl.AddFish                          --将鱼/父级的生成指令发送出去AddFish({p,p,f,f,p,p,f})
	GetPathTime = ctrl.GetPathTime                  --根据路径获得路径所需时间
	SetFormFinishTime = ctrl.SetFormFinishTime      --设置鱼阵刷鱼的结束时间，SetFormFinishTime(time)
	CheckHasType = ctrl.CheckHasType                --检查是否包含某type的鱼存在
	GetPlayerCount = ctrl.GetPlayerCount            --获得玩家个数
	FormWillStart = ctrl.FormWillStart              --通知逻辑，鱼阵即将开始
	GetRoomPlayerCount = ctrl.GetRoomPlayerCount	--共享同个场次池的玩家个数
	AddAwardFish = ctrl.AddAwardFish                --增加奖励鱼AddAwardFish(fishes, rate)--函数里面的makefish时间必须＞0
	GetPoolGold = ctrl.GetPoolGold  
	EnterBossScene = ctrl.EnterBossScene
	ExitBossScene = ctrl.ExitBossScene

	bossid = boss
end

function this.Start()
	-- body

	-- CreatFish(3001,)
	usedFormList = {}
	addFish()
end
function this.Destroy()
	-- body
end

function this.Update(time)
	-- body
end
return this
