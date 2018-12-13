-- 财神到
local this = {}
local players,config,code,gameid
local skynet = require "skynet"
local tinsert = table.insert

local automodel=0       --辨识是否是自动模式   0   不是自动模式  1  是自动模式
local send_to_all       --发送给所有客户端
local free_table        --闲置
local api_game_start    --游戏开始的方法
local api_game_end      --游戏结束
local pour_money=9000   --每一注的下注金额
--local pour_status       --下注状态  0 1 2都可以下注  0可以改变线数和底注 1只可以改变线数 2只可以改变底注 3不能下注   
local pour_gold         --下注金额
local currentwin=0
local wingold={0,0,0,0,0,0,0,0,0}      --赢得的数量
local wintotal=0        --总共赢得的数量
local game_status       --游戏状态   1 下注阶段  2开始（转动）及显示结果 3免费阶段
local isUseGold         --金币模式 
local win_biggold,win_smallgold   	--赢取彩金池的金币数量
local p1={}             --替代当前玩家p
local api_call_ctrl,api_kick   --api_call_ctrl 向控制层发送消息  api_kick  踢人

local next_status_time=0
local showcards={}
local win_type={}
local win_number={0,0,0,0,0,0,0,0,0}
local win_order={}  --结果中奖顺序   0表示从左到右中奖 1表示从右到左中奖
local image_change={0,0,0,0,0}	--图片显示的时候如果每列有两个金发会变化

local CJ_BIG_ADD = {min = 500, max = 1000} --大彩金每秒增加
local CJ_SMALL_Add = {min = 100, max = 500} --小彩金每秒增加

local lock_pourmoney,lock_pourmoneydown=45000,9000    --下注金额上限和下限
local re_count=0        --不满足控制要求的情况下重新生成结果的控制次数 当前最多20次

local randomtime=0      --当前有多少次免费机会，出现钻石的情况下随机出来的
local addrandom ={}     --用来记录增加的随机次数  如果不符合几率  则被减掉
local jackpot=60        --彩金奖池的比率数值

local biggoldpool,smallgoldpool=10000000,1000000   --默认初始状态下奖金池的数据

local let_win=false          --接受服务器信息  是否让用户中彩金
local receive_nowgold 		 --服務器發送的數據：在控制器狀態下現在用戶已經贏取的金幣
local receive_count   		 --接收到的服務器發送的數據
local receive_type   	     --接收到的输赢的信息  1表示输，2表示赢
local receive_maxgold		 --接收到的数据赢取或输钱的限制金钱
local receive_rate	         --接收到服务器关于输赢的概率 当receive——win为1 当前为100   表示一定会输 
							 --当receive——win为2 当前为100  表示一定会赢
local isStart=false      --判断游戏是否开始
local total=0            --所有概率的和

local kickback,sysearn = 0,0         --系统控制的抽水比率
local sysearn_rate=0.1     --单个玩家的赢钱数目不可以超过sysearn的10%,即0.1

local report_gold        --向后台汇报数据
local cost,earn = 0,0    --下注的金额和赢取的金额

local isTiyan  = false     --体验模式
local test_gold     --体验模式玩家赋初值

local leave_cd_time=20     --玩家离线踢人时间
local leave_time 		   --玩家离线时间
local current_pourmoney    --当局下注

local had_win=false          --控制器控制中奖是否已经中了
local win_count=5            --如果控制器控制已经中了，在5次后had_win会变为false
--定义水果顺序 铜钱1，鞭炮2，玉3，鼓4，女孩5，儿童6，银财神7，金财神8，银发9，金发10，狮子11，

local numberChance={[1]=40,[2]=40,[3]=30,[4]=30,[5]=25,[6]=20,[7]=15,[8]=10,[9]=5,[10]=5,[11]=1}
local numberToRate={    --每种类型对应的奖金比率
	[1]={2,5,20,50},
	[2]={3,10,40,100},
	[3]={5,15,60,150},
	[4]={7,20,100,250},
	[5]={10,30,160,400},
	[6]={15,40,200,500},
	[7]={20,80,400,1000},
	[8]={50,200,1000,2500},
	[9]={0,0,5000,5000},
	[10]={0,0,5000,5000},
	[11]={10,20,50},
}
local numbermatch={{1,9,10},{2,9,10},{3,9,10},{4,9,10},{5,9,10},{6,9,10},{7,9,10},{8,9,10},{9,10},{10},{11}}	--可以匹配成功的数值
local numberlock={3,3,3,3,3,3,3,3,5,5,3}	--最低匹配数量

local parType={    --对应序号需要检查的位置
	[1]={[1]={1,2},[2]={2,2},[3]={3,2},[4]={4,2},[5]={5,2}},
	[2]={[1]={1,1},[2]={2,1},[3]={3,1},[4]={4,1},[5]={5,1}},
	[3]={[1]={1,3},[2]={2,3},[3]={3,3},[4]={4,3},[5]={5,3}},
	[4]={[1]={1,1},[2]={2,2},[3]={3,3},[4]={4,2},[5]={5,1}},
	[5]={[1]={1,3},[2]={2,2},[3]={3,1},[4]={4,2},[5]={5,3}},
	[6]={[1]={1,1},[2]={2,1},[3]={3,2},[4]={4,1},[5]={5,1}},
	[7]={[1]={1,3},[2]={2,3},[3]={3,2},[4]={4,3},[5]={5,3}},
	[8]={[1]={1,2},[2]={2,1},[3]={3,1},[4]={4,1},[5]={5,2}},
	[9]={[1]={1,2},[2]={2,3},[3]={3,3},[4]={4,3},[5]={5,2}}
}

function this.free()
	isStart=false
	let_win=false
end

local function reportgold()
	if (cost > 0 or earn > 0) and (not isTiyan) then
		-- CMD.report(addr, gameid, usercost, userearn)
		report_gold(cost, earn)
		cost, earn=0,0
	end
end

local function info_cai_gold(count)
	--发送消息
	local msg = {}
	if count then
		--起始数据
		msg.biggold = biggoldpool - math.random(CJ_BIG_ADD.min, CJ_BIG_ADD.max)
		msg.smallgold = smallgoldpool - math.random(CJ_BIG_ADD.min, CJ_BIG_ADD.max)
		send_to_all("game.CaiJinChangeNtf",msg)
	end

	--真实数据
	msg.biggold = biggoldpool
	msg.smallgold = smallgoldpool
	send_to_all("game.CaiJinChangeNtf",msg)
end

function this.ReceiveMessage(msg)
	if msg=="true" then
		let_win=true
	elseif msg=="false" then
		let_win=false
	elseif biggoldpool~=msg[1] or smallgoldpool~=msg[2] then
		biggoldpool,smallgoldpool=msg[1],msg[2]
		info_cai_gold()
	else
		local msg1={}
		msg1.sendmessage=msg
		send_to_all("game.SendMessage",msg1)
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

function this.join(p)    --玩家加入房间的判断
	p1=p
	if p.ctrlinfo then
		receive_nowgold=p.ctrlinfo.ctrlnowgold
		-- LOG_DEBUG("receive_nowgold="..receive_nowgold)	
	end
	biggoldpool,smallgoldpool=api_call_ctrl("ReceiveMessage",uid,3,0)
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
						params={biggoldpool,smallgoldpool}})
	end
	msg.owner = owner  
	msg.endtime =  0 or endtime
	msg.gameid = gameid
	msg.times = total_times 
	msg.playedtimes = 0 
	msg.score = 3
	msg.paytype = paytype
	msg.code = code
	msg.players = list
	msg.isGoldGame=isUseGold or 0
	return msg
end

local function sendresult(p)
	local msg={}	
	msg.showcards=showcards
	msg.wintype=win_type
	msg.winnumber=win_number
	msg.winorder=win_order
	msg.wingold=wingold
	msg.randomtime=randomtime
	msg.wintotal=wintotal
	msg.owngold=p.gold
	msg.imagechange=image_change
	msg.winbig= win_biggold
	msg.winsmall= win_smallgold
	-- local random_caijin=math.random(1,2)
	-- if random_caijin == 1 then
	-- 	msg.winbig= 100
	-- 	msg.winsmall= 0
	-- else
	-- 	msg.winbig= 0
	-- 	msg.winsmall= 100
	-- end

	p:send_msg("game.GameResultCSD", msg)
	--PRINT_T(msg)
end

local function minrate()
	local min_rate=numberToRate[1][1]
	for _,v in pairs(numberToRate) do
		for _,v1 in pairs(v) do 
			if v1 ~= 0 then 
				min_rate=math.min(min_rate,v1)
			end
		end
	end
	return min_rate
end

local function CheckWin()    --检测是否符合要求
	current_pourmoney=pour_money
	local randomX
	randomX=math.random(1,100)
	if  receive_rate and randomX <= receive_rate then	
		if receive_count and receive_count > 0 then
			if (receive_type == 1 and currentwin <= current_pourmoney) or (receive_type == 2 and currentwin > current_pourmoney ) then
				-- receive_nowgold=receive_nowgold-current_pourmoney+currentwin
				receive_count = receive_count - 1	
				return		
			else
				api_call_ctrl("ReceiveMessage",p1.uid,4,0)
				LOG_DEBUG("不符合单局控制")
				return false
			end
		else
			local winresult=false
			if (receive_type == 1 and currentwin <= current_pourmoney) or (receive_type == 2 and currentwin > current_pourmoney ) then
				winresult=true			
			end
			if receive_maxgold >= receive_nowgold and winresult then 
				LOG_DEBUG("符合单局控制,receive_nowgold="..receive_nowgold)	
				return 
			else
				api_call_ctrl("ReceiveMessage",p1.uid,4,0)
				if receive_maxgold - receive_nowgold < pour_money*minrate() then
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

local function RandomGold()
	currentwin=0
	addrandom={}
	win_biggold,win_smallgold=0,0
	local pourOne=pour_money/9
	for i=1,#win_type do 
		if win_type[i]>=1 and win_type[i] <=10  then
			if win_number[i]<=5 then
				wingold[i]=numberToRate[win_type[i]][win_number[i]-2]*pourOne
				currentwin=currentwin+numberToRate[win_type[i]][win_number[i]-2]*pourOne
				if win_type[i]==10 then
					local win_biggoldpool,win_smallgoldpool=0,0
					if randomtime==0 then 
						win_biggoldpool,win_smallgoldpool=api_call_ctrl("ReceiveMessage",p1.uid,3,{big=0,small=jackpot})
						win_biggold=win_biggold+win_smallgoldpool
						currentwin=currentwin+win_smallgoldpool
					elseif randomtime>0 then
						win_biggoldpool,win_smallgoldpool=api_call_ctrl("ReceiveMessage",p1.uid,3,{big=jackpot,small=0})
						win_biggold=win_biggold+win_biggoldpool
						currentwin=currentwin+win_biggoldpool
					end
				end
			else
				wingold[i]=numberToRate[win_type[i]][4]*pourOne
				currentwin=currentwin+numberToRate[win_type[i]][4]*pourOne
			end
		elseif win_type[i]==11 then
			local addrandomX=0
			if win_number[i]<=5 then
				addrandomX=numberToRate[win_type[i]][win_number[i]-2]
			else
				addrandomX=numberToRate[win_type[i]][3]
			end	
			randomtime=randomtime+addrandomX
			if randomtime>50 then 
				addrandomX=addrandomX-(randomtime-50)
				randomtime=50
			end
			tinsert(addrandom,addrandomX)
		end
	end
end

local function result()
	RandomGold()

	local checkresult = CheckWin()

	if isTiyan then 
		checkresult = true
	end

	if checkresult == false and re_count<10 then
		if #addrandom >0 then
			for i=1,#addrandom do 
				randomtime=randomtime-addrandom[i]
			end
		end
		re_count=re_count+1
		random()
	else
		if randomtime>0 then 
			wintotal=wintotal+currentwin
		else
			wintotal=currentwin
		end
		if receive_nowgold then
			if randomtime > 0 then 
				receive_nowgold=receive_nowgold+currentwin
			else
				receive_nowgold=receive_nowgold-current_pourmoney+currentwin
			end
			-- LOG_DEBUG("receive_nowgold="..receive_nowgold)
		end	
		if currentwin>0 then
			
			if not isTiyan then
				api_call_ctrl("ReceiveMessage",p1.uid,2,currentwin)
				p1:call_userdata("add_gold", currentwin, 10001)
				earn=earn+currentwin
			end
			--p1:call_userdata("add_win", gameid, 1001)
			p1.gold=p1.gold+currentwin
			
		end
		sendresult(p1)	
		next_status_time=os.time()+2
	end	
end

-- local function round(number)
-- 	local random=math.random()
-- 	random=math.floor(random+0.5)
-- 	return (number+random)*2
-- end

-- local function randomLine(currentline)
-- 	local let_win_number=math.random(3,5)
-- 	if pour_number==3 then
-- 		if currentline==1 then 
-- 			return {14,14,14}
-- 		else
-- 			return {round(6),round(6),round(6)}
-- 		end
-- 	elseif pour_number==4 then
-- 		if currentline==1 then
-- 			return {14,14,14}
-- 		else 
-- 			if let_win_number==3 then
-- 				if currentline==3 then
-- 					return {14,14,math.random(12)}
-- 				else
-- 					return {round(6),round(6),round(6)}
-- 				end
-- 			else
-- 				return {round(6),round(6),round(6)}
-- 			end
-- 		end
-- 	elseif pour_number>=5 then
-- 		if currentline==1 then
-- 			return {14,14,14}
-- 		else 
-- 			if let_win_number==3 then
-- 				if currentline==3 then 
-- 					return {14,14,math.random(1,12)}
-- 				else 
-- 					return {round(6),round(6),round(6)}
--  				end
--  			elseif let_win_number==4 then
--  				if currentline==2 or currentline==4 then
--  					return {math.random(14),round(6),math.random(14)}
--  				else
--  					return {math.random(14),math.random(14),math.random(14)}
--  				end
--  			else
--  				return {round(6),round(6),round(6)}
--  			end
--  		end
--  	end
-- end

-- 玩家游戏外造成的金币增减，需要通知到游戏内，进行金币的增减
function this.add_gold(p, gold, reason)
	LOG_DEBUG("用户充值")
	p.gold = p.gold + gold
	if p.gold < 0 then
		p.gold = 0
	end
	p:send_msg("game.UpdateGoldInGame", {uid=p.uid,goldadd=gold,gold=p.gold})
end

local function CheckWinType(currentLine,order)
	local x=0
	local currentnumber=currentLine[1] 
	for _,v in pairs(currentLine) do
		local ishave=false
		for _,v1 in pairs(numbermatch[currentnumber]) do
			if v1==v then
				x=x+1
				ishave=true
				break				
			end
		end
		if ishave==false then
			break
		end
	end
	if x<numberlock[currentnumber] then
		return 0,0,0
	elseif x>=numberlock[currentnumber] then
		return currentnumber,x,order
	end
end

local function disorder(currentLine)
	local x={}
	for _,v in pairs(currentLine) do
		tinsert(x,1,v)
	end
	return x
end

local function random_wincaijin(line,col,row)
	-- body
	local current_pos=parType[line]
	if current_pos[col][2] == row then
		return 	true
	else
		return false
	end
end

function random(p)
	--开始随机
	--将随机结果和分支都发送到客户端
	local let_win_line 
	if let_win == true then 
		let_win_line=math.random(1,9)
	end
	local randomnumber={} 	
	image_change={0,0,0,0,0}
	for i=1,5 do    --出五组随机数
		local randomnumberX={}
		for j=1,3 do           --每组随机数有3个
			local k=math.random(1,total)
			local sum=0
			for m,v in ipairs(numberChance) do      --对随机出来的数字进行查找 
				sum=sum+v
				if sum>=k then
					local current_fruit=m
					if let_win == true and let_win_line then 						
						local let_pos = random_wincaijin(let_win_line,i,j)
						if let_pos == true then 
							current_fruit=10  --可以中彩金的情况下将这个位置上的图标变为金发10
						end	
					end
					randomnumberX[j]=current_fruit				
					break
				end
			end
		end
		----[[		每列如果出现两个金色的发 会把另外的那个也变为金色的发
		local count_fa=0
		local number_x=0
		for k,v in pairs(randomnumberX) do
			if v==10 then 
				count_fa=count_fa+1
			end
		end
		if count_fa==2 then
			image_change[i]=1
		else
			image_change[i]=0
		end
		--]]
		local rondoml={}

		-- if let_win==true then
		-- 	if pour_number>=3 then
		-- 		randomnumberX=randomLine(i)
		-- 	end
		-- end

		rondoml.randomL=randomnumberX
		tinsert(randomnumber,rondoml)
	end

	win_type={0,0,0,0,0,0,0,0,0}     --重新判断结果时需要将以前数据清空，避免减线数据长度不变
	win_number={0,0,0,0,0,0,0,0,0}
	win_order={0,0,0,0,0,0,0,0,0}
	wingold={0,0,0,0,0,0,0,0,0}
	showcards={}

	local win_typex=randomnumber[1].randomL[1]
	local win_numberx=0
	for k,v in pairs(randomnumber) do 
		for _,v1 in pairs(v.randomL) do
			tinsert(showcards,v1)
			if v1==win_typex then
				win_numberx=win_numberx+1
			end
		end
	end

	if win_numberx==15 then 
		win_type={win_typex}
		win_number={win_numberx}
		win_order={0}
		wingold={0}
	else
		for i=1,9 do
			local t=parType[i]
			local currentLine={}
			for j=1,5 do
				tinsert(currentLine,randomnumber[t[j][1]].randomL[t[j][2]])
			end
			win_type[i],win_number[i],win_order[i]= CheckWinType(currentLine,0)
			if win_number[i]==0 then
				currentLine=disorder(currentLine)
				win_type[i],win_number[i],win_order[i]= CheckWinType(currentLine,1)
			end
			-- LOG_DEBUG("let_win:"..tostring(let_win)) 
			if let_win == false and win_type[i] == 10 then   --在非控制状态下 禁止中彩金
				-- LOG_ERROR("let_win:"..tostring(let_win).."  win_type:"..win_type[i])
				random(p)
			elseif let_win == true and win_type[i] == 10 then 
				had_win = true 
				win_count = 5 
			end 
		end
	end
	result()
end

local function report_gold_info()
	while true and (not isTiyan) do
		reportgold()
		skynet.sleep(5*100)
	end
end

local function checkgold(p)
	if game_status==1  then   --玩家未点击开始			
		if lock_pourmoney>=pour_money  then
			if (p.gold>=pour_money and pour_money>= lock_pourmoneydown) or randomtime>0 then
				p:send_msg("game.PourCSD",{pourmoney=pour_money})
				return true		
			else
				if not isTiyan then
					p:send_msg("game.PourCSD",{pourmoney=-1})
					LOG_DEBUG("用户金币不够或用户未押注")
				end
				return false	
			end	
		else
			error("客户端发送数据信息异常")
			api_kick(p,1004)
			return false
		end	
	elseif game_status>=2 then 
		p:send_msg("game.PourCSD",{pournumber=-2})
		return false
	end
end

local function game_start(p)
	local check=checkgold(p)
	if check == true then 
		game_status=2
		api_game_start()          
		isStart=true
		if randomtime<=0 then
			p.gold=p.gold-pour_money
			if not isTiyan then 
				cost=cost+pour_money
				api_call_ctrl("ReceiveMessage",p.uid,1, pour_money)
				p:call_userdata("sub_gold", pour_money, 10001)
			end
		elseif randomtime >0 then
			randomtime=randomtime-1
		end

		re_count=0
		random(p)
	end 
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
			api_game_end()
			isStart=false							
		end
	end
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

function this.dispatch(p, name, msg)
	if name=="PourCSD" then 
		if randomtime>0 and pour_money~=msg.pourmoney then
			api_kick(p,1004)
			return
		end
		if p.ctrlinfo then
			receive_type = p.ctrlinfo.ctrltype
			receive_rate = p.ctrlinfo.ctrlrate
			receive_maxgold = p.ctrlinfo.ctrlmaxgold
			receive_count = p.ctrlinfo.ctrlcount
			-- let_win = p.ctrlinfo.ctrlcaijin > 1  --ctrlcaijin	控制彩金(1:不能中，2：可以中)
			let_win = check_hadwin(p.ctrlinfo.ctrlcaijin > 1)  --ctrlcaijin	控制彩金(1:不能中，2：可以中)				
			if not receive_nowgold then 
				receive_nowgold = p.ctrlinfo.ctrlnowgold
				-- LOG_DEBUG("receive_nowgold="..receive_nowgold)	
			end
		end
		pour_money=msg.pourmoney
		game_start(p)
	end
end

function this.offline(p)
	leave_time=os.time()+leave_cd_time
end

function this.resume(p)
	-- 恢复游戏
	-- 状态
	if leave_time then leave_time=nil end
	if isStart==true then
		sendresult(p)
	end
	info_cai_gold(0)  	--发送奖池数据
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
	if isStart == true then
		api_game_end()
	end
	return true
end

function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid, usegold, _, params, kb)
	luadump(api,"api======")
	players = ps          --玩家
	config = m_conf       --设置信息
	code = m_code         --指令类型
	gameid = m_gameid     --名称id
	game_status=1         --游戏可以进入下注阶段
	isUseGold=usegold
	kickback=kb
	if kickback then
		cost,earn = 0,0
		skynet.fork(report_gold_info)
	end 

	if config.test_gold then
		isTiyan = true
		test_gold = config.test_gold
	end

	lock_pourmoney,lock_pourmoneydown=config.init_params.lock_pourmoney,config.init_params.pour_money
	pour_money=config.init_params.pour_money

	endtime = os.time() + m_conf.wait_time
	owner = uid
	gameid = m_gameid
	paytype = m_pay
	gametype = config.init_params
	total_times = m_times

	send_to_all = api.send_to_all
	free_table = api.free_table
	api_game_start = api.game_start
	api_game_end=api.game_end
	api_call_ctrl=api.call_ctrl
	api_kick=api.kick
	report_gold=api.report_gold

end

return this
