local this = {}
local send_to_all
local goldpool=10000000          --奖池金额
local goldpool_limit=10000000      --奖池金额限制（可以中大奖）
local last_goldpool=10000000       --之前的奖金池数量
local playerinfo={}
local all_cost=0
local all_earn=0
local percentage=100    --抽成金额限制
local gameid=10003
-- local hadwin=1   --用hadwin记录信息是否送大奖  0表示未发送  1表示已经发送
local isneedsend=false
local tinsert = table.insert
local tremove = table.remove
local histroy_namenumber=10
local card_history={}
local robot_name= require "robot_name"   --調用機器人暱稱庫中的名字

local canremove =false  --用来记录是否能移除记录   只有在上一个有调用奖池时才会生效
local last_uid	  --记录上次中奖的人的id
local win_goldpool    		--赢取奖池的金币
local removehistory         --最新的一条被移除的记录
local currenttime           --限制最多1秒以内可以恢复数据，否则就被删除
local poolrate={{0.05,7},{0.1,8},{0.8,9}}   	--奖池扣奖比例

local histroy_goldpool={}
-- local histroy_goldpool={{time="2018-01-3023:59:58",nickname="大魔王",type=7,gold=500000}}
math.randomseed(os.time())
local function SendMessage(msg)
	send_to_all("ReceiveMessage",msg,gameid)
end

local function requestnickname()
	local randomnumber=math.random(#robot_name)
	if #robot_name[randomnumber] >7 then
		robot_name[randomnumber]=string.sub(robot_name[randomnumber],1,7)
	end
	return robot_name[randomnumber]
	-- body
end
function this.update()
	if currenttime and os.time()>currenttime then
		currenttime=nil
		canremove=false
	end
	
	if all_cost >= percentage then
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
		-- hadwin=0
		-- isneedsend=true
		local rate=math.random(#poolrate)
		local sub_pool=math.floor(goldpool*poolrate[rate][1])
		goldpool=goldpool-sub_pool
		tinsert(histroy_goldpool,1,{time=os.date("%Y-%m-%d%H:%M:%S"),nickname=requestnickname(),type=poolrate[rate][2],gold=sub_pool})  --按时间依次往前插入
		SendMessage(goldpool)
	end

	-- if hadwin==1 and isneedsend == true then 
	-- 	isneedsend=false
	-- 	SendMessage("false")
	-- end
end

function this.init(t,api,ps,ftable,ttable)
	send_to_all=api.call_all_table
	players=ps
end

function this.ReceiveMessage(uid,status,gold)    --status  玩家金币状态 1表示 玩家下注的金币  
	--LOG_WARNING("接收到服务器发送的数据："..gold)         --2 表示玩家赢取的金币数量（不包含彩金池的数量）
	if playerinfo.uid ==nil then                          --3 表示彩金池数据变动
		playerinfo.uid={cost=0,earn=0}                    --4 表示获取中奖信息   5表示玩家历史好牌信息
	end  												  --6表示取消之前的请求数据(彩金)

	if status==1 then
		playerinfo.uid.cost=gold +playerinfo.uid.cost
		all_cost=all_cost+gold
	elseif status==2 then
		playerinfo.uid.earn=gold +playerinfo.uid.earn
		all_earn=all_earn+gold
	elseif status==3 then
		-- if gold>0 then
		-- 	hadwin=1
		-- end
		win_goldpool = goldpool*0.01*gold

		local Type=0
		if gold==5 then
			Type=7
		elseif gold==10 then
			Type=8
		elseif gold==80 then
			Type=9
		end
		
		goldpool=goldpool-win_goldpool
		all_earn=all_earn+win_goldpool
		playerinfo.uid.earn=win_goldpool +playerinfo.uid.earn
		--SendMessage(goldpool)
		if win_goldpool<=0 then
			win_goldpool=nil
		else
			canremove=false
			currenttime=os.time()+1
			last_uid=uid
			tinsert(histroy_goldpool,1,{time=os.date("%Y-%m-%d%H:%M:%S"),nickname=players[uid].nickname,type=Type,gold=win_goldpool})  --按时间依次往前插入
		end

		return win_goldpool or goldpool
	elseif status==4 then
		local new_history=table.arraycopy(histroy_goldpool,1,histroy_namenumber)
		return new_history
	elseif status==5 then
		--LOG_WARNING("请求玩家历史好牌信息")
		ishave=false
		--PRINT_T(gold)
		local send_message
		for i,v in pairs(card_history) do 
			if card_history[i].uid== uid then 
				ishave=true
				local t=gold.type
				local count_zero=0
				for i,v in ipairs(t) do   --检测发送过来的数据是不是全为0
					if v==0 then 
						count_zero=count_zero+1
					end
				end
				if count_zero~=9 then    --如果不为0，就替换掉原有的数据 
					card_history[i]=gold
				end
				send_message= card_history[i]
				break
			end
		end
		if ishave==false then
			card_history[uid]=gold
			send_message= gold
		end
		return send_message
	elseif status==6 then
		-- hadwin=0
		for i=1,#histroy_goldpool do 
			if histroy_goldpool[i].nickname==players[uid].name then
				goldpool=goldpool+histroy_goldpool[i].gold
				all_earn=all_earn-histroy_goldpool[i].gold
				playerinfo.uid.earn=playerinfo.uid.earn -histroy_goldpool[i].gold
				tremove(histroy_goldpool,i)
				break
			end
		end
	end
end

return this