local this = {}
local send_to_all
local goldpool=10000000          --奖池金额
local goldpool_limit=10000000      --奖池金额限制（可以中大奖）
local last_goldpool=10000000       --之前的奖金池数量
local playerinfo={}
local all_cost=0
local all_earn=0
local percentage=100    --抽成金额限制
local gameid=10001
-- local hadwin=1   --用hadwin记录信息是否送大奖  0表示未发送  1表示已经发送
local isneedsend=false
local goldpoolchange={}
local tinsert = table.insert
local poolrate={0.1,0.3,0.5}   	--奖池中奖抽的比例

local robot_name_store = require "robot_name"
local skynet = require "skynet"
local robot_names = {}
local headimgs = {}
local robot_list={}
local uid_index = 0   --初始化时机器人的id
local mingold,maxgold=1000000,2000000   --初始机器人给的金币数额
local add_gold_robot={5000,10000,20000,50000}  --给机器人添加的金币
local fps=1*60*100   --切换机器人的时间
local fps1=15*100     --机器人金币增加的时间

math.randomseed(os.time())

local function SendMessage(msg)
	--LOG_WARNING("发送给所有玩家")
	-- LOG_WARNING("players:"..#players)
	send_to_all("ReceiveMessage",msg,gameid)
end

local function init_names()
	table.clear(robot_names)
	table.join(robot_names, robot_name_store)
end

local function init_headimgs()
	for i=1, 15000 do
		table.insert(headimgs, i)
	end
end

local function get_robot_headimp()
	if #headimgs == 0 then
		init_headimgs()
	end
	local index = math.random(#headimgs)
	local headimgcnt = table.remove(headimgs, index)
	local imgurl
	if headimgcnt <= 5000 then
		imgurl = "http://wximg.ld68.com/touxiang/1%20("..headimgcnt..").jpg"
	elseif headimgcnt <= 10000 then
		imgurl = "http://wximg.ld68.com/touxiang3/a"..headimgcnt..".jpg"
	else
		imgurl = "http://wximg.ld68.com/touxiang2/a"..(headimgcnt-10000)..".jpg"
	end
	return imgurl
end

local function get_robot_name()
	if #robot_names == 0 then
		init_names()
	end
	local index = math.random(#robot_names)
	return table.remove(robot_names, index)
end

local function add_robot()
	local robot={}
	robot.nickname=get_robot_name()
	robot.headimg=get_robot_headimp()
	robot.gold=math.random(mingold,maxgold)
	robot.addgold=0
	return robot
end

local function changerobot()
	while true do 
		LOG_WARNING("改变机器人")
		skynet.sleep(fps)
		local remove_number=math.random(1,uid_index)
		local remove_name = robot_list[remove_number].nickname
		robot_list[remove_number]=add_robot()
		table.insert(robot_names,remove_name)
		SendMessage(robot_list)
	end
end

local function addgold_robot()
	while true do
		--LOG_WARNING("增加机器人金币")
		skynet.sleep(fps1)
		for k,v in pairs(robot_list) do
			-- PRINT_T(v)
			v.addgold=add_gold_robot[math.random(#add_gold_robot)]
			-- LOG_WARNING("v.addgold"..v.addgold)
			v.gold=v.gold+v.addgold
		end
		SendMessage(robot_list)		
	end
end

local function pre_robot()   --初始的机器人
	if #robot_list < 4 then
		for i=1,4-#robot_list do
			uid_index = uid_index + 1  
			robot_list[uid_index]=add_robot()
		end
		SendMessage(robot_list)
		-- skynet.timeout(fps1, addgold_robot)
		-- skynet.timeout(fps, changerobot)
		addgold_robot()
		changerobot()
		--LOG_WARNING("创建机器人数据")
	end
end

function this.update()
	if all_cost >= percentage then
		--LOG_WARNING("可以抽成")
		local current_sub=math.floor(all_cost/percentage)
		goldpool=goldpool+ current_sub*percentage*0.1
		all_cost=all_cost-current_sub*percentage
		last_goldpool=goldpool
		SendMessage(goldpool)
	end

	if goldpool~=last_goldpool then
		last_goldpool=goldpool
		SendMessage(goldpool)
	end

	if goldpool>= goldpool_limit*1.5 then
		-- SendMessage("true")
		-- --LOG_WARNING("发送可以中奖")
		-- hadwin=0
		-- isneedsend=true
		local rate=math.random(#poolrate)
		goldpool=math.floor(goldpool-goldpool*poolrate[rate])
		SendMessage(goldpool)
	end

end

function this.init(t,api,ps,ftable,ttable)
	-- LOG_WARNING("初始化成功")
	-- ctrl.init(type,api,players,free_table,total_tables)
	send_to_all=api.call_all_table
	players=ps
end

function this.ReceiveMessage(uid,status,gold)    --status  玩家金币状态 1表示 玩家下注的金币  2表示玩家赢取的金币数量（不包含彩金池的数量）3表示彩金池数据变动
	-- LOG_WARNING("接收到服务器发送的数据："..gold.."status:"..status)         --4表示恢复数据  5表示请求机器人显示信息
	if playerinfo.uid ==nil then
		playerinfo.uid={cost=0,earn=0}
	end

	if status==1 then
		playerinfo.uid.cost=gold +playerinfo.uid.cost
		all_cost=all_cost+gold
	elseif status==2 then
		playerinfo.uid.earn=gold +playerinfo.uid.earn
		all_earn=all_earn+gold
	elseif status==3 then
		local win_goldpool=0
		if gold>0 then
			-- hadwin=1
			win_goldpool = goldpool*0.01*gold	
			goldpool=goldpool-win_goldpool
			all_earn=all_earn+win_goldpool
			playerinfo.uid.earn=win_goldpool +playerinfo.uid.earn	
			tinsert(goldpoolchange,1,{nickname=players[uid].nickname,wingold= win_goldpool})
		end
		
		if win_goldpool<=0 then
			win_goldpool=nil
		end
		return win_goldpool or goldpool
	elseif status==4 then 
		for i=1,#goldpoolchange do 
			if nickname==goldpoolchange[i].nickname then
				goldpool=goldpool+goldpoolchange[i].wingold
				all_earn=all_earn-goldpoolchange[i].wingold
				playerinfo.uid.earn=playerinfo.uid.earn-goldpoolchange[i].wingold
				tremove(goldpoolchange,i)
				break
			end
		end
	elseif status == 5 then
		if #robot_list < 4 then
			pre_robot()
			-- PRINT_T(robot_list)
		end
		SendMessage(robot_list)
		-- LOG_WARNING("请求机器人信息成功")
	end
end

return this