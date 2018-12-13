local this = {}
local skynet = require "skynet"
local players,config,code,gameid

local tinsert = table.insert

local automodel=0       --辨识是否是自动模式   0   不是自动模式  1  是自动模式
local send_to_all       --发送给所有客户端
local free_table        --闲置
local api_game_start    --游戏开始的方法
local api_game_end      --游戏结束
local api_kick 			--踢人
local pour_money=100   --每一注的下注金额
local pour_number =1    --总共下注的数目
local current_pourmoney  --當前局下注的總金額 即pour_money*pour_number
local pour_status       --下注状态  0 1 2都可以下注  0可以改变线数和底注 1只可以改变线数 2只可以改变底注 3不能下注   
local pour_gold         --下注金额
local wingold =0        --赢得的数量
local wintotal=0        --总共赢得的数量
local game_status       --游戏状态   1 下注阶段  2开始（转动）及显示结果 
local isUseGold         --金币模式 
local randomnumber={}   --隨機數，即當前遊戲顯示畫面

local p1={}             --替代当前玩家p
local api_call_ctrl

local next_status_time=0
local win_type={}
local win_number={}
local total=0          --各种水果的概率综合

local lock_pournumber=9
local lock_pourmoney,lock_pourmoneydown=500,100

local re_count=0   		--重新循环的次数
local kickback,sysearn = 0,0
local sysearn_rate=0.1     --单个玩家的赢钱数目不可以超过sysearn的10%,即0.1

local randomtime=0      --当前有多少次免费机会，出现钻石的情况下随机出来的
local jackpot=0         --彩金奖池的比率数值,一局之内只能有一种结果

local goldpool=10000000

local let_win=false      --接受服务器信息  是否让用户中彩金
local had_win=false          --控制器控制中奖是否已经中了
local win_count=5            --如果控制器控制已经中了，在5次后had_win会变为false
local isStart=false      --判断游戏是否开始
local  mathrandom={}	 --如果出现777的随机数字就把数据收集起来

local addrandom={}
local report_gold
local all_cost,all_earn=0,0

local isTiyan  = false     --体验模式
local test_gold     --体验模式玩家赋初值

local leave_cd_time=20       --玩家离线踢人时间
local leave_time 		     --玩家离线时间

local receive_nowgold		 --服務器發送的數據：在控制器狀態下現在用戶已經贏取的金幣
local receive_count   		 --接收到的服務器發送的數據
local receive_type    	     --接收到的输赢的信息  1表示输，2表示赢
local receive_maxgold		 --接收到的数据赢取或输钱的限制金钱
local receive_rate	         --接收到服务器关于输赢的概率 当receive——type为1 当前为100   表示一定会输 

--定义水果顺序 荔枝1，桔子2，芒果3，西瓜4，苹果5，樱桃6，葡萄7，香蕉8，菠萝9，铃铛10，七七七11，BAR12，钻石13，宝箱14

local numberChance={[1]=50,[2]=50,[3]=45,[4]=45,[5]=40,[6]=40,[7]=30,[8]=30,[9]=25,[10]=25,[11]=10,[12]=40,[13]=2,[14]=1}
local numberToRate={    --每种类型对应的奖金比率
	[1]={50,200,2000},
	[2]={20,50,300},
	[3]={15,25,250},
	[4]={10,20,200},
	[5]={8,20,150},
	[6]={6,20,100},
	[7]={5,40,90},
	[8]={6,30,80},
	[9]={5,15,75},
	[10]={8,35,85},
	[11]={1000,3000,5000},
	[12]={5,100,900,6000},
	[14]={10,30,50}
}

local parType={    --对应序号需要检查的位置
	[1]={[1]={1,2},[2]={2,2},[3]={3,2},[4]={4,2},[5]={5,2}},
	[2]={[1]={1,3},[2]={2,3},[3]={3,3},[4]={4,3},[5]={5,3}},
	[3]={[1]={1,1},[2]={2,1},[3]={3,1},[4]={4,1},[5]={5,1}},
	[4]={[1]={1,3},[2]={2,2},[3]={3,1},[4]={4,2},[5]={5,3}},
	[5]={[1]={1,1},[2]={2,2},[3]={3,3},[4]={4,2},[5]={5,1}},
	[6]={[1]={1,2},[2]={2,3},[3]={3,3},[4]={4,3},[5]={5,2}},
	[7]={[1]={1,2},[2]={2,1},[3]={3,1},[4]={4,1},[5]={5,2}},
	[8]={[1]={1,3},[2]={2,3},[3]={3,2},[4]={4,1},[5]={5,1}},
	[9]={[1]={1,1},[2]={2,1},[3]={3,2},[4]={4,3},[5]={5,3}}
}

function this.free()
	isStart=false
	win_type={}
	win_number={}
	pour_money=100
	pour_number=1
	let_win=false
end

local function reportgold()
	if (all_cost > 0 or all_earn > 0) and (not isTiyan) then
		----LOG_DEBUG("上报数据:all_cost="..all_cost..",all_earn="..all_earn)
		report_gold(all_cost, all_earn)
		all_cost ,all_earn = 0,0
	end
end

function this.ReceiveMessage(msg)
	-- if goldpool~=msg then
	-- LOG_WARNING("接收roomctrl信息")
	-- PRINT_T(msg)
	-- print(type(msg))
	if type(msg) == "number" then
		goldpool=msg
		local msg1={}
		msg1.goldpool=msg
		send_to_all("game.GoldPool",msg1)
	elseif type(msg) == "table" then
		local msg1={}
		msg1.robot=msg
		send_to_all("game.ShowMessage",msg1)
		-- PRINT_T(msg1)
	else
		local msg1={}
		msg1.sendmessage=msg
		send_to_all("game.SendMessage",msg1)
	end
end

function this.join(p)    --玩家加入房间的判断
	p1=p
	if p.ctrlinfo and p.ctrlinfo.ctrlnowgold then
		receive_nowgold=p.ctrlinfo.ctrlnowgold
		-- LOG_DEBUG("receive_nowgold="..receive_nowgold)	
	end
	for i,v in ipairs(numberChance) do
		total=total+numberChance[i]
	end
	if isTiyan then 
		p.gold = test_gold
	end
	return p.gold>=0
end

-- 发送房间信息
function this.get_tableinfo(p)
	local msg = {}
	local list = {}
	local cur_status = game_status
	for uid,v in pairs(players) do
		tinsert(list, { uid = v.uid, 
						nickname=v.nickname,
						seatid=v.seatid or 0,
						ready=v.ready or 0,
						online=v.online or 1,
						score=v.score or 0,
						sex = v.sex or 1,
						headimg=v.headimg or nil,
						gold=v.gold,
						params={goldpool}})
	end
	msg.owner = owner  
	msg.endtime =  0 or endtime
	msg.gameid = gameid
	msg.times = total_times 
	msg.playedtimes = played_times 
	msg.score = rule_score
	msg.paytype = paytype
	msg.code = code
	msg.players = list
	msg.isGoldGame=isUseGold or 0
	return msg
end

local function RandomGold()
	wingold=0
	mathrandom={}
	jackpot=0
	addrandom={}
	local boxline_number=0
	local box_number={}      --如果中奖类型为宝箱，则需要知道哪几条是宝箱
	for i=1,pour_number do 
		if win_type[i]>=1 and win_type[i] <=10  then
			wingold=wingold+numberToRate[win_type[i]][win_number[i]-2] 
		elseif win_type[i]==11 then
			local mathrandomX=0			
			mathrandomX=numberToRate[win_type[i]][win_number[i]-2] +math.random(1,numberToRate[win_type[i]][win_number[i]-2])
			tinsert(mathrandom,mathrandomX)
			wingold=wingold+mathrandomX
		elseif win_type[i]==12 then
			 wingold=wingold+numberToRate[win_type[i]][win_number[i]-1] 
		elseif win_type[i]==13 then 
			local randomtime1=0
			if win_number[i]==3 then
				-- randomtime1=math.random(1,1)
				randomtime1=math.random(1,5)
			elseif win_number[i]==4 then
				-- randomtime1=math.random(1,1)
				randomtime1=math.random(6,10)
			elseif win_number[i]==5 then
				-- randomtime1=math.random(1,1)
				randomtime1=math.random(11,20)
			end
			win_number[i]=randomtime1
			tinsert(addrandom,addrandom1)
			randomtime=randomtime+randomtime1
		elseif win_type[i]==14 then 
			if win_number[i]==5 then
				boxline_number=boxline_number+1
			end
			if boxline_number>=3 then
				if boxline_number>=5 then    --最大上限线数是5
					boxline_number=5
				end
				win_number[i]=boxline_number
				local jackpotX=numberToRate[win_type[i]][win_number[i]-2]
				had_win = true 
				win_count = 5 
				jackpot=jackpotX
			else
				win_type[i]=0
				win_number[i]=0
			end			
		end
	end
end

local function minrate()
	local min_rate=numberToRate[1][1]
	for _,v in pairs(numberToRate) do
		for _,v1 in pairs(v) do 
			min_rate=math.min(min_rate,v1)
		end
	end
	return min_rate
end

local function check_hadwin(receive_win)
	-- body
	local iswin
	if receive_win and not had_win then
		iswin = true
	elseif receive_win and had_win then
		win_count = win_count - 1
		if win_count <= 0 then 
			win_count = 0
		end
		iswin = win_count <= 0   --如果win——count小于等于0 iswin 返回true
	end
	return iswin
end

local function CheckWin()    --检测是否符合要求
	currentwin = wingold
	local randomX
	-- if not receive_type or not receive_rate then       --如果没有局部控制  则使用全局控制
	-- 	randomX=math.random(1,100000)
	-- 	local min_number = math.min(kickback*50000,100000)   --全局控制必须符合要求
	-- 	-- LOG_WARNING("randomX:"..randomX.." min_number:"..min_number)
	-- 	if randomX <= min_number then 
	-- 		if (min_number > 50000 and currentwin > current_pourmoney) or (min_number < 50000 and currentwin <= current_pourmoney) then 			
	-- 			return 
	-- 		elseif min_number == 50000 then   --不需要控制
	-- 			return
	-- 		else
	-- 			return false
	-- 		end		
	-- 	end
	-- end
	randomX=math.random(1,100)
	if  receive_rate and randomX <= receive_rate then	
		if receive_count and receive_count > 0 then
			if (receive_type == 1 and currentwin <= current_pourmoney) or (receive_type == 2 and currentwin > current_pourmoney ) then
				-- receive_nowgold=receive_nowgold-current_pourmoney+currentwin
				receive_count = receive_count - 1	
				return		
			else
				api_call_ctrl("ReceiveMessage",p1.uid,4,0)
				-- LOG_DEBUG("不符合单局控制")
				return false
			end
		else
			local winresult=false
			if (receive_type == 1 and currentwin <= current_pourmoney) or (receive_type == 2 and currentwin > current_pourmoney ) then
				winresult=true			
			end
			if receive_maxgold >= receive_nowgold and winresult then 
				-- LOG_DEBUG("符合单局控制,receive_nowgold="..receive_nowgold)	
				return 
			else
				api_call_ctrl("ReceiveMessage",p1.uid,4,0)
				if receive_maxgold - receive_nowgold < pour_money*pour_number*minrate() then
					receive_type=receive_type%2+1   --实现类型1->2,2->1的转换
					let_win = false
				end
				return false
			end
		end
	end
	randomX=math.random(1,100000)
	local min_number = math.min(kickback*50000,100000)   --全局控制必须符合要求
	-- LOG_WARNING("randomX:"..randomX.." min_number:"..min_number)
	if randomX <= min_number then 
		if (min_number > 50000 and currentwin > current_pourmoney and currentwin <= sysearn*sysearn_rate ) or (min_number < 50000 and currentwin <= current_pourmoney) then 			
			return 
		elseif min_number == 50000 and currentwin <= sysearn*sysearn_rate then   --不需要控制
			return
		else
			return false
		end		
	end
	if sysearn > 0 and currentwin <= sysearn*sysearn_rate then
		return   --默认返回空  不做处理
	else
		return false
	end
end

local function result()
	RandomGold()
	wingold=wingold*pour_money
	if wingold>0 then
		api_call_ctrl("ReceiveMessage",p1.uid,2,wingold)
	end
	-- jackpot[1]=0.1
	if jackpot~=0 then
		-- for i=1,#jackpot do 
		local win_goldpool=api_call_ctrl("ReceiveMessage",p1.uid,3,jackpot)
		wingold=wingold+win_goldpool
		-- end
	end

	local checkresult=CheckWin() 	--发送游戏结果之前需要复检查看是否满足需求

	if isTiyan then 
		checkresult = true
	end

	if checkresult==false and re_count<20 then 
		if jackpot>0 then 
			-- for i=1,#jackpot do 
			api_call_ctrl("ReceiveMessage",p1.uid,4,0)
			-- end
		end
		if #addrandom>0 then 
			for i=1,#addrandom do 
				randomtime=randomtime-addrandom[i]
			end
		end
		re_count=re_count+1
		--LOG_DEBUG("re_count="..re_count)
		random(p1)
	else
		-- LOG_WARNING("wingold:"..wingold.." gold:"..p1.gold)
		
		if receive_nowgold then 
			if randomtime > 0 then 
				receive_nowgold=receive_nowgold+currentwin
			else
				receive_nowgold=receive_nowgold-current_pourmoney+currentwin
			end
			-- LOG_DEBUG("receive_nowgold="..receive_nowgold)
		end		
		if wingold>0 then
			p1.gold=p1.gold+wingold
			if not isTiyan then 
				p1:call_userdata("add_gold", wingold, 10001)
				all_earn=all_earn+wingold
			end			
			--p1:call_userdata("add_win", gameid, 1001)
		end
		wintotal=wintotal+wingold
		-- LOG_WARNING(wintotal)
		if #mathrandom>0 then
			local msg={}
			for i=1,#mathrandom do			
				msg.randomresult=mathrandom[i]
				p1:send_msg("game.RandomResultJXLW",msg)
			end
		end

		local msg={}      --發送遊戲顯示畫面
		msg.randomH=randomnumber 
		p1:send_msg("game.RandomJXLW",msg)

		winMessage={}
		--[[
			win_type[#win_type] = 14  
			win_number[#win_number] = 3
		--]]
		winMessage.winType=win_type
		winMessage.winNumber=win_number
		winMessage.winGold={wingold}

		msg={}           --將msg置空防止數據混亂   
		msg.totalWin=wintotal           --發送遊戲結果信息
		msg.winmessage=winMessage
		msg.ownergold=p1.gold
		-- LOG_WARNING("wingold:"..wingold.." gold:"..p1.gold)
		p1:send_msg("game.GameOverJXLW", msg) 
		-- LOG_WARNING(os.date("%Y-%m-%d %H:%M:%S").."  "..p1.uid.."游戏结果发送完毕")  
		next_status_time=os.time()+2
	end

end

local function round(number)
	local random=math.random()
	random=math.floor(random+0.5)
	return (number+random)*2
end

local function randomLine(let_win_number,currentline)	
	if pour_number==3 then
		if currentline==1 then 
			return {14,14,14}
		else
			return {round(6),round(6),round(6)}
		end
	elseif pour_number==4 then
		if currentline==1 then
			return {14,14,14}
		else 
			if let_win_number==3 then
				if currentline==3 then
					return {14,14,math.random(12)}
				else
					return {round(6),round(6),round(6)}
				end
			else
				return {round(6),round(6),round(6)}
			end
		end
	elseif pour_number>=5 then
		if currentline==1 then
			return {14,14,14}
		else 
			if let_win_number==3 then
				if currentline==3 then 
					return {14,14,math.random(1,12)}
				else 
					return {round(6),round(6),round(6)}
 				end
 			elseif let_win_number==4 then
 				if currentline==2 or currentline==4 then
 					return {math.random(14),round(6),math.random(14)}
 				else
 					return {math.random(14),math.random(14),math.random(14)}
 				end
 			else
 				return {round(6),round(6),round(6)}
 			end
 		end
 	end
end

-- 玩家游戏外造成的金币增减，需要通知到游戏内，进行金币的增减
function this.add_gold(p, gold, reason)
	LOG_DEBUG("用户充值")
	p.gold = p.gold + gold
	if p.gold < 0 then
		p.gold = 0
	end
	p:send_msg("game.UpdateGoldInGame", {uid=p.uid,goldadd=gold,gold=p.gold})
end

function random(p)
	randomnumber={}
	local let_win_number 
	if let_win  == true then
		let_win_number=math.random(3,5)
	end
	for i=1,5 do    --出五组随机数
		local randomnumberX={}
		for j=1,3 do           --每组随机数有3个
			local k=math.random(1,total)
			local sum=0
			for m,v in ipairs(numberChance) do      --对随机出来的数字进行查找 
				sum=sum+numberChance[m]
				if sum>=k then
					if randomtime>0 then          --禁止在免费的时候再次出现免费
						if m==13 and i==1 then
							m=math.random(1,12)
						end
					end
					randomnumberX[j]=m			
					break
				end
			end
		end
		local rondoml={}
		if let_win == true and let_win_number then 
			rondoml.randomL=randomLine(let_win_number,i)
		else
			rondoml.randomL=randomnumberX
		end
		tinsert(randomnumber,rondoml)
	end

	win_type={}     --重新判断结果时需要将以前数据清空，避免减线数据长度不变
	win_number={}
	for i=1,pour_number do
		local t=parType[i]
		if (randomnumber[t[1][1]].randomL[t[1][2]]==12 and randomnumber[t[2][1]].randomL[t[2][2]]==12) and
			(randomnumber[t[1][1]].randomL[t[1][2]]~=randomnumber[t[3][1]].randomL[t[3][2]] ) then

			win_type[i]=randomnumber[t[1][1]].randomL[t[1][2]]
			win_number[i]=2
		elseif (randomnumber[t[1][1]].randomL[t[1][2]]==randomnumber[t[2][1]].randomL[t[2][2]] or randomnumber[t[2][1]].randomL[t[2][2]]==12) and
			(randomnumber[t[1][1]].randomL[t[1][2]]==randomnumber[t[3][1]].randomL[t[3][2]] or randomnumber[t[3][1]].randomL[t[3][2]]==12) and
			(randomnumber[t[1][1]].randomL[t[1][2]]~=randomnumber[t[4][1]].randomL[t[4][2]] and randomnumber[t[4][1]].randomL[t[4][2]]~=12) then

			win_type[i]=randomnumber[t[1][1]].randomL[t[1][2]]
			win_number[i]=3
		elseif (randomnumber[t[1][1]].randomL[t[1][2]]==randomnumber[t[2][1]].randomL[t[2][2]] or randomnumber[t[2][1]].randomL[t[2][2]]==12) and
			(randomnumber[t[1][1]].randomL[t[1][2]]==randomnumber[t[3][1]].randomL[t[3][2]] or randomnumber[t[3][1]].randomL[t[3][2]]==12) and
			(randomnumber[t[1][1]].randomL[t[1][2]]==randomnumber[t[4][1]].randomL[t[4][2]] or randomnumber[t[4][1]].randomL[t[4][2]]==12)  and
		   (randomnumber[t[1][1]].randomL[t[1][2]]~=randomnumber[t[5][1]].randomL[t[5][2]] and randomnumber[t[5][1]].randomL[t[5][2]]~=12) then

			win_type[i]=randomnumber[t[1][1]].randomL[t[1][2]]
			win_number[i]=4
		elseif (randomnumber[t[1][1]].randomL[t[1][2]]==randomnumber[t[2][1]].randomL[t[2][2]] or randomnumber[t[2][1]].randomL[t[2][2]]==12) and
			(randomnumber[t[1][1]].randomL[t[1][2]]==randomnumber[t[3][1]].randomL[t[3][2]] or randomnumber[t[3][1]].randomL[t[3][2]]==12) and
			(randomnumber[t[1][1]].randomL[t[1][2]]==randomnumber[t[4][1]].randomL[t[4][2]] or randomnumber[t[4][1]].randomL[t[4][2]]==12)  and
		   (randomnumber[t[1][1]].randomL[t[1][2]]==randomnumber[t[5][1]].randomL[t[5][2]] or randomnumber[t[5][1]].randomL[t[5][2]]==12) then

			win_type[i]=randomnumber[t[1][1]].randomL[t[1][2]]
			win_number[i]=5
		else 
			win_type[i]=0  
			win_number[i]=0 
		end
		
		if win_type[i]==14 and win_number[i]~=5 then
			win_type[i] = 0  
			win_number[i] = 0

		end
		-- LOG_DEBUG("let_win:"..tostring(let_win)) 
		if let_win == false and win_type[i] == 14 then   --在非控制状态下 禁止中彩金
			-- LOG_ERROR("let_win:"..tostring(let_win).."  win_type:"..win_type[i])
			random(p)
		end
	end
	result()
end

local function checkgold(p)
	if lock_pourmoney>=pour_money  and lock_pournumber>=pour_number and pour_money>0 and pour_number>=1 then
		current_pourmoney=pour_money*pour_number
		if p.gold >= current_pourmoney or randomtime > 0 then
			if p.ctrlinfo then
				receive_type =p.ctrlinfo.ctrltype
				receive_rate=p.ctrlinfo.ctrlrate
				receive_maxgold=p.ctrlinfo.ctrlmaxgold
				receive_count=p.ctrlinfo.ctrlcount
				-- let_win = p.ctrlinfo.ctrlcaijin > 1  --ctrlcaijin	控制彩金(1:不能中，2：可以中)
				let_win = check_hadwin(p.ctrlinfo.ctrlcaijin > 1)  --ctrlcaijin	控制彩金(1:不能中，2：可以中)				
				if receive_nowgold == nil and p.ctrlinfo.ctrlnowgold then 
					receive_nowgold = p.ctrlinfo.ctrlnowgold
					-- LOG_DEBUG("receive_nowgold="..receive_nowgold)	
				end
				-- LOG_DEBUG("receive_type="..receive_type.."  receive_rate="..receive_rate)
			end
			p:send_msg("game.PourJXLW",{pournumber=pour_number,pourmoney=pour_money})
			return true
		else
			if not isTiyan then
				p:send_msg("game.PourJXLW",{pournumber=0,pourmoney=0})
			end
			return false	
		end	
	else
		error("客户端发送数据信息异常")
		api_kick(p,1004)
		return false
	end	
end

local function game_start(p)
	-- local msg={}
	-- msg.goldpool=goldpool
	-- p:send_msg("game.GoldPool",msg)
	if game_status==1 then --如果处于下注状态就改变为开始状态
		local checkresult = checkgold(p)
		if checkresult == true then  
			game_status=2
			api_game_start()   
			isStart=true
			if randomtime<=0 then
				p.gold=p.gold-current_pourmoney	
				
				if not isTiyan then
					all_cost=all_cost+current_pourmoney	 
					p:call_userdata("sub_gold", current_pourmoney, 10001)
				end					
			elseif randomtime>0 then
				randomtime=randomtime - 1
			end
			re_count=0
			random(p)
		end
	end   
end

function this.set_kickback(kb,systemearn)
	-- kickback是一个>0的数值，1表示不抽水也不放水，自然概率
	-- 例如0.98表示玩家的每次下注行为都抽水0.02
	-- 如果需要转化成0-100的数值，那么就是kickback*50，且大于100的时候取100
	-- LOG_DEBUG("收到kickback:"..kb)
	--systemearn 单个玩家的赢钱数目不可以超过sysearn的10%。单控不守影响。当sysearn<0的时候，玩家不能赢钱。
	kickback = kb
	if systemearn then
		sysearn = systemearn  
	end
	-- LOG_WARNING("sysearn"..sysearn) 
end

function this.update()    --更新游戏时间  0.1s刷新一次
	
	if leave_time and os.time()> leave_time then
		reportgold()
		api_kick(p1,1003)
	end
	if next_status_time and os.time()>next_status_time then
		if game_status==2 then   --开始状态切换到发送结果状态
			next_status_time=nil
			game_status=1	
			if randomtime>0 then
				
				game_start(p1)
			else
				api_call_ctrl("ReceiveMessage",p1.uid,1, current_pourmoney)				
				api_game_end()
				isStart=false	
			end						
		end
	end
end


function this.dispatch(p, name, msg)
	-- LOG_WARNING("name"..name)
	-- PRINT_T(msg)
	if name=="PourJXLW" then 
		if game_status==1 and randomtime == 0  then   --玩家未点击开始
			pour_number= msg.pournumber
			pour_money=msg.pourmoney
			checkgold(p)
		end
	elseif name=="GameStart"  then 
		if game_status==1 and randomtime == 0 then
			game_start(p)
			return
		end
	end
end

function this.offline(p)
	leave_time=os.time()+leave_cd_time
end

function this.resume(p)
	--显示机器人信息
	api_call_ctrl("ReceiveMessage",uid,5,0)  --调用机器人信息
	-- 恢复游戏
	-- 状态
	if leave_time  then
		leave_time=nil
	end
	local msg={}
	local winMessage={}
	local pourMessage={}
	local cur_status=game_status
	if isStart==true then
		if cur_status==1 then              --处于下注阶段    需要返回的信息有下注的内容和总共赢得的金币数量
			pourMessage.pournumber=pour_number
			pourMessage.pourmoney=pour_money
			pourMessage.winTotal=wintotal
			winMessage=nil

		elseif cur_status==2 then          --处于获取结果阶段    需要返回的信息有获取的方式和总共赢得的金币数量
			winMessage.winType=win_type
			winMessage.winNumber=win_number
			winMessage.winGold=wingold
			winMessage.winTotal=wintotal
			pourMessage=nil
			local msg={}
			msg.totalWin=wintotal
			msg.winmessage=winMessage
			msg.ownergold=p1.gold
			p:send_msg("game.GameOverJXLW", msg)
		end
		if randomtime>0 then
			cur_status=4
		end					
	else
		pourMessage.pournumber=1
		pourMessage.pourmoney=100
		pourMessage.winTotal=0
		winMessage=nil	
		cur_status=1
	end
	msg.state=cur_status
	msg.winmessage=winMessage
	msg.pourmessage=pourMessage
	msg.ownergold=p.gold
	p:send_msg("game.ResumeJXLW", msg)
end

-- 尝试离开游戏，如果能离开，返回true，并且调用该函数的地方继续处理离开逻辑
function this.leave_game(p)
	-- if game_status ==1 then   --只要不是处于下注阶段都可以离开
	-- 	if randomtime<=0 then
	-- 		reportgold()
	-- 		return true  
	-- 	else
	-- 		return false
	-- 	end  
	-- end
	if isStart==true then
		api_game_end()
	end
	if randomtime > 0 then 
		rendomtime =0
	end
	return true 
end

local function report_gold_info()
	while true and (not isTiyan) do 
		reportgold()
		skynet.sleep(5*100)
	end
end

function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid, usegold, _, params, kb)
	players = ps          --玩家
	config = m_conf       --设置信息
	code = m_code         --指令类型
	gameid = m_gameid     --名称id
	game_status=1         --游戏可以进入下注阶段
	isUseGold=usegold

	if config.test_gold then
		isTiyan = true
		test_gold = config.test_gold
	end

	lock_pourmoney=config.init_params.lock_pourmoney
	lock_pournumber=config.init_params.lock_pournumber
	pour_number=config.init_params.pour_number
	pour_money=config.init_params.pour_money
	-- LOG_WARNING("pour_number:"..pour_number.."pour_money"..pour_money)
	kickback=kb

	if kickback then
		all_cost = 0
		all_earn = 0
		skynet.fork(report_gold_info)
	end

	endtime = os.time() + m_conf.wait_time
	owner = uid
	gameid = m_gameid
	rule_score = 3
	paytype = m_pay
	gametype = config.init_params
	played_times = 0
	total_times = m_times

	send_to_all = api.send_to_all
	free_table = api.free_table
	api_game_start = api.game_start
	api_game_end=api.game_end
	api_call_ctrl=api.call_ctrl
	api_kick=api.kick
	report_gold=api.report_gold

	goldpool=api_call_ctrl("ReceiveMessage",uid,3,0)
	
	-- LOG_WARNING("请求机器人信息")
end

return this
