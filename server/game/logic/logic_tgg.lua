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
local pour_rate = 1     --玩家下注倍率
--local pour_status       --下注状态  0 1 2都可以下注  0可以改变线数和底注 1只可以改变线数 2只可以改变底注 3不能下注   
local pour_gold         --下注金额
local currentwin=0
local wingold={}      --赢得的数量，用于在第三列显示金币结果
local win_gold={0,0,0}     --用来存储转换过后的wingold
local wintotal=0        --总共赢得的数量
local game_status       --游戏状态   1 下注阶段  2开始（转动）及显示结果 3免费阶段
local isUseGold         --金币模式 
local win_biggold,win_smallgold   	--赢取彩金池的金币数量
local p1={}             --替代当前玩家p
local api_call_ctrl,api_kick   --api_call_ctrl 向控制层发送消息  api_kick  踢人

local next_status_time=0
local showcards={}
local win_type={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}   --中间用来判断的，并不用于最终发送
local WinType={}     --最终用于发送显示的
local win_number={}  --基数每一列的重复数据
local win_per_count={}	 --每种的长度
local count_qiu=0    --金球的个数
local countqiu = 0   --默认情况下需要发送给客户端中几个球的音效种类的数据
local wintype_X      --金球的位置
local addrate=0  --用来计算因为免费次数而增加的倍率
local win_order={}  --结果中奖顺序   0表示从左到右中奖 1表示从右到左中奖
-- local image_change={0,0,0,0,0}	--图片显示的时候如果每列有两个金发会变化

local CJ_BIG_ADD = {min = 500, max = 1000} --大彩金每秒增加
local CJ_SMALL_Add = {min = 100, max = 500} --小彩金每秒增加

local lock_pourmoney,lock_pourmoneydown=600000,5000    --下注金额上限和下限
local re_count=0        --不满足控制要求的情况下重新生成结果的控制次数 当前最多20次

local randomtime=0      --当前有多少次免费机会，出现钻石的情况下随机出来的
local addrandom =0     --用来记录增加的随机次数  如果不符合几率  则被减掉
local current_addrate=0   --当前免费次数累加的倍率
local jackpot=60        --彩金奖池的比率数值
-- local biggoldpool,smallgoldpool=10000000,1000000   --默认初始状态下奖金池的数据

local let_win=false          --接受服务器信息  是否让用户中彩金
local receive_nowgold 		 --服務器發送的數據：在控制器狀態下現在用戶已經贏取的金幣
local receive_count   		 --接收到的服務器發送的數據
local receive_type   	     --接收到的输赢的信息  1表示输，2表示赢
local receive_maxgold		 --接收到的数据赢取或输钱的限制金钱
local receive_rate	         --接收到服务器关于输赢的概率 当receive——win为1 当前为100   表示一定会输 
							 --当receive——win为2 当前为100  表示一定会赢
local isStart=false      --判断游戏是否开始
local total=0            --所有概率的和

local isTiyan  = false     --体验模式
local test_gold     --体验模式玩家赋初值

local kickback,sysearn = 0,0         --系统控制的抽水比率
local sysearn_rate=0.1     --单个玩家的赢钱数目不可以超过sysearn的10%,即0.1

local report_gold        --向后台汇报数据
local cost,earn = 0,0    --下注的金额和赢取的金额

local leave_cd_time=20     --玩家离线踢人时间
local leave_time 		   --玩家离线时间
local current_pourmoney    --当局下注

-- local havematch = false   --表示第三列是否含有百搭图案
-- local matchnumber      --表示百搭的位置

local freetime={}   --免费次数阶梯
local gold_rate={1,2,3,5,10,20,30,60,120}
local pri_gold = 5000  --1倍的金币数额

local TimeCD = 1   --每一局之间的时间间隔

local had_win=false          --控制器控制中奖是否已经中了
local win_count=5            --如果控制器控制已经中了，在5次后had_win会变为false
--定义水果顺序 J1，Q2，K3，A4，啤酒5，鸡尾酒6，耳机7，CD8，JUMP9，金球10，
local numberChance={[1]=40,[2]=40,[3]=30,[4]=30,[5]=25,[6]=20,[7]=15,[8]=10,[9]=5,[10]=40 or 5}
local numberToRate={    --每种类型对应的奖金比率
	[1]={10,20,100},
	[2]={10,20,100},
	[3]={15,30,125},
	[4]={15,30,125},
	[5]={30,100,200},
	[6]={40,100,250},
	[7]={50,150,300},
	[8]={75,150,400},
}
local numbermatch={{1,9},{2,9},{3,9},{4,9},{5,9},{6,9},{7,9},{8,9},{9},{10}}	--可以匹配成功的数值
local numberlock={3,3,3,3,3,3,3,3,0,5}	--最低匹配数量

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

function this.ReceiveMessage(msg)
	local msg1={}
	msg1.sendmessage=msg
	send_to_all("game.SendMessage",msg1)
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
	for i,v in pairs(numberChance) do
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
						gold=v.gold})
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
	msg.wintype=WinType
	-- msg.winnumber=win_number
	-- msg.winorder=win_order
	msg.wingold=win_gold
	msg.randomtime=randomtime
	msg.wintotal=wintotal
	msg.owngold=p.gold
	msg.countboll=countqiu
	-- msg.goldrate = 0

	p:send_msg("game.ResultTGG", msg)
	-- PRINT_T(msg)
	LOG_WARNING("游戏结果发送完毕")
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
				-- LOG_DEBUG("符合单局控制,receive_nowgold="..receive_nowgold)	
				return 
			else
				api_call_ctrl("ReceiveMessage",p1.uid,4,0)
				if receive_maxgold - receive_nowgold < 100*pour_rate*minrate() then
					receive_type=receive_type%2+1   --实现类型1->2,2->1的转换
					let_win = false
				end
				return false
			end
		end
	end
	randomX=math.random(1,100000)
	local min_number = math.min(kickback*50000,100000)   --全局控制必须符合要求
	if randomX <= min_number then 
		if (min_number > 50000 and currentwin > current_pourmoney and currentwin <= sysearn*sysearn_rate ) or (min_number < 50000 and currentwin <= current_pourmoney) then 			
			
			return 
		elseif min_number == 50000 and currentwin <= sysearn*sysearn_rate then   --不需要控制
			return
		else
			LOG_WARNING("不符合要求")
			return false
		end		
	end
	if sysearn > 0 and currentwin <= sysearn*sysearn_rate then
		return   --默认返回空  不做处理
	else
		return false
	end
end
local function addfree(count_qiu,addrandomX)
	-- body
	-- PRINT_T(freetime)
	if table.len(freetime) == 0 then 
		freetime[count_qiu]={addrate,addrandomX}
		return
	else
		for k,v in pairs(freetime) do
			if count_qiu == k then
				v[2]=v[2]+addrandomX
				freetime[k]={v[1],v[2]}
				PRINT_T(freetime)
				return 
			end
		end
		-- table.insert(freetime,{addrate,addrandomX})
		random()
	end
end
local function RandomGold()
	currentwin=0
	addrandom=0
	local base_gold=100
	for i=1,table.len(win_per_count) do 
		-- PRINT_T(wingold)
		for k,v in pairs(wingold) do     --检出wingold可能有的三个位置对应表的数据
			local rate=0
			local currentwinnumber = win_per_count[v]   --每一个单独的{order,0}
			local currentrate=numberToRate[currentwinnumber[1]][currentwinnumber[2]-2]
			local doublerate=1
			for j = 1, currentwinnumber[2] do    --每一列的个数相乘为总共的组成种类
				doublerate = doublerate * win_number[j][v]
			end
			rate = rate + currentrate*doublerate    --统计这个位置所有的倍率
			win_gold[v] = base_gold * rate * ( pour_rate + current_addrate )   --倍率乘法：(下注倍率+增加的倍率)*对应种类的倍率
			if v ~= nil then
				WinType[k].gold = win_gold[v]
			end
		end
	end
	-- PRINT_T(WinType)
	-- PRINT_T(win_gold)
	for k,v in pairs(win_gold) do
		currentwin = currentwin + v
	end
	if count_qiu >= 5 then
		tinsert(WinType,1,{type=wintype_X,gold=0})
		local addrandomX=12
		if randomtime + addrandomX >50 then 
			addrandomX=50 - randomtime
		end

		-- LOG_WARNING("last randomtime:"..randomtime)
		if count_qiu == 5 then
			addrate=1
		elseif count_qiu == 6 then
			addrate=2
		elseif count_qiu >= 7 then
			count_qiu = 7
			addrate=3
		end	
		addfree(count_qiu,addrandomX)	
		addrandom = addrandomX
		if randomtime == 0 then
			countqiu=count_qiu - 4   --确保发送过的数字是1 2 3 而不是5 6 7 
		end
		randomtime=randomtime+addrandomX	
	end
end

local function result()
	RandomGold()

	local checkresult = CheckWin()
	if isTiyan then 
		checkresult = true
	end

	if checkresult == false and re_count<10 then
		if addrandom > 0 then
			PRINT_T(freetime)
			LOG_WARNING("addrate:"..addrate)
			for k,v in pairs(freetime) do
				if v[1] == addrate then
					v[2]=v[2]-addrandom
					if v[2]==0 then
						freetime[k] = nil
					else
						freetime[k]={v[1],v[2]}
					end
					break 
				end
			end
			randomtime=randomtime-addrandom
		end
		re_count=re_count+1
		random()
	else
		-- LOG_WARNING("randomtime:"..randomtime)
		if randomtime > 0 then 
			wintotal=wintotal+currentwin
		else
			wintotal=currentwin
		end
		-- wintotal=currentwin
		if receive_nowgold then
			if randomtime > 0 then 
				receive_nowgold=receive_nowgold+currentwin
			else
				receive_nowgold=receive_nowgold-current_pourmoney+currentwin
			end
			-- LOG_DEBUG("receive_nowgold="..receive_nowgold)
		end	
		if currentwin>0 then
			api_call_ctrl("ReceiveMessage",p1.uid,2,currentwin)
			if not isTiyan then
				earn=earn+currentwin
				p1:call_userdata("add_gold", currentwin, 10001)
			end
			--p1:call_userdata("add_win", gameid, 1001)
			p1.gold=p1.gold+currentwin
			
		end
		sendresult(p1)	
		next_status_time=os.time() + TimeCD
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

local function CheckWinType(currentLine,order)
	local currentnumber=currentLine[1][order]
	-- LOG_DEBUG("currentnumber:"..currentnumber)
	if order > 1 then
		for k,v in pairs(currentLine[1]) do 
			if v == currentnumber and k < order and win_number[1][k] then
				win_number[1][k] = win_number[1][k] + 1
				win_type[order]=1
				-- PRINT_T(wingold)
				-- PRINT_T(WinType)
				for k1,v1 in pairs(wingold) do
					if v1 == k then 
						WinType[k1].type[order] = 1
						break
					end
				end
				return
			end
		end		
	end

	local count=1	
	win_number[1][order]=1
	
	local wintype={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}   --每一行第一个元素匹配位置列表
	if numbermatch[currentnumber] and currentnumber <= 8  then
		
		for i=2,5 do
			local current_repeat = 0
			local ishave=false
			local first_repeated --第一个重复的对象 用于记录位置
			for j=1,3 do
				for k,v in pairs(numbermatch[currentnumber]) do 
					if v == currentLine[i][j] then 
						current_repeat = current_repeat + 1
						-- if current_repeat == 1 then
						-- 	first_repeated = j
						-- end
						ishave = true
						wintype[3*(i-1)+j]=1

						break
					end
				end
			end
			if ishave == false then 
				break
			end
			if i == 3 then
				if current_repeat >=1 then
					tinsert(wingold,order)
					-- wingold[order] = order
					-- table.insert(wingold[order],order)   --表示需要展示金币的那一列金币的情况
					-- if havematch == false then 
					-- 	table.insert(wingold[first_repeated],order)   --表示需要展示金币的那一列金币的情况
					-- elseif matchnumber then
					-- 	table.insert(wingold[matchnumber],order) 
					-- end
				end
			end						
			win_number[i][order]=current_repeat
			count = count + 1   --检测到当前列有才能增加
		end
	end
	-- LOG_DEBUG("currentnumber:"..currentnumber)
	-- LOG_WARNING(order .."数量："..count.."  限制数量："..numberlock[currentnumber])
	if count>=numberlock[currentnumber] and currentnumber <= 8 then
		wintype[order] = 1
		-- WinType[order]={type=wintype,gold=0}
		tinsert(WinType,{type=wintype,gold=0})
		-- LOG_WARNING("满足数量要求"..count)
		for k,v in pairs(wintype) do
			win_type[k] = win_type[k] + v
		end
		-- win_type[order]=1
		win_per_count[order]={currentnumber,count}  --用于表示第一列第几个元素的图标以及这一次他的长度
		-- PRINT_T(win_per_count)
	else
		for k,v in pairs(win_number) do
			if v[order] then
				win_number[k][order]=nil
			end
		end
		for k,v in pairs(wingold) do
			if type(v) == "table" then
				for k1,v1 in pairs(v) do 
					if v1 == order then
						wingold[k][k1]=nil
					end
				end
			else
				if v == order then
					-- wingold[k] =nil
					table.remove(wingold,k)
				end
			end
		end
	end
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

function random()
	win_type={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}     --重新判断结果时需要将以前数据清空，避免减线数据长度不变
	win_number={{},{},{},{},{}}
	wingold={}
	showcards={}
	win_per_count={}
	WinType={} 
	win_gold={}
	countqiu = 0
	if randomtime <= 0 then
		wintotal = 0
	end
	-- matchnumber = nil
	-- havematch = false
	--开始随机
	--将随机结果和分支都发送到客户端
	local let_win_line 
	-- if let_win == true then 
	-- 	let_win_line=math.random(1,9)
	-- end
	local randomnumber={} 
	count_qiu=0	
	wintype_X={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	for i=1,5 do    --出五组随机数
		local randomnumberX={}
		for j=1,3 do           --每组随机数有3个
			local k=math.random(1,total)
			local sum=0
			for m,v in pairs(numberChance) do      --对随机出来的数字进行查找 
				sum=sum+v
				if sum>=k then
					local current_fruit=m
					randomnumberX[j]=current_fruit
					if 	current_fruit == 10 then
						count_qiu = count_qiu + 1
						wintype_X[3*(i-1)+j]=1
					end			
					break
				end
			end
		end
		tinsert(randomnumber,randomnumberX)
	end
	if count_qiu < 5 then
		wintype_X = nil
	end
	for k,v in pairs(randomnumber) do 
		for _,v1 in pairs(v) do
			tinsert(showcards,v1)
		end
	end
	-- for k,v in pairs(randomnumber[3]) do   --检测百搭  用于结果显示
	-- 	if v == 9 then    --等于百搭
	-- 		havematch = true
	-- 		matchnumber = k
	-- 		break
	-- 	end
	-- end
	for i=1,3 do
		CheckWinType(randomnumber,i)
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
				if randomtime > 0 then 
					randomtime=randomtime-1
					local current_free=0       --当前免费属于哪个阶段
					for k,v in pairs(freetime) do
						if v[2] > 0 then 
							v[2] = v[2] - 1
							current_addrate = current_addrate + v[1]
							if current_addrate >= (k - 4) * 50 then   --限制最大倍率
								current_addrate = (k - 4) * 50
							end
							freetime[k]={v[1],v[2]}
							if v[2] == 0 then
								current_free = k
							end
						end
						break
					end					
					if current_free > 0 then
						freetime[current_free]=nil
					end
					p:send_msg("game.PourTGG",{pourrate=current_addrate,pourmoney=0})
				else
					current_addrate = 0
					p.gold=p.gold-pour_money
					if not isTiyan then 
						cost=cost+pour_money
						p:call_userdata("sub_gold", pour_money, 10001)
					end
					api_call_ctrl("ReceiveMessage",p.uid,1, pour_money)
					p:send_msg("game.PourTGG",{pourrate=current_addrate,pourmoney=pour_money})
				end
				return true		
			else
				if not isTiyan then
					p:send_msg("game.PourTGG",{pourrate=pour_rate,pourmoney=-1})
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
		p:send_msg("game.PourTGG",{pourrate=pour_rate,pournumber=-2})
		return false
	end
end

local function game_start(p)
	local check=checkgold(p)
	if check == true then 
		game_status=2
		api_game_start()          
		isStart=true
		-- if randomtime<=0 then
		-- 	current_addrate = 0
		-- 	p.gold=p.gold-pour_money
		-- 	if not isTiyan then 
		-- 		cost=cost+pour_money
		-- 		p:call_userdata("sub_gold", pour_money, 10001)
		-- 	end
		-- 	api_call_ctrl("ReceiveMessage",p.uid,1, pour_money)
		-- end

		re_count=0
		random()
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
	-- PRINT_T(msg)
	-- LOG_WARNING("pour_money:"..pour_money.."  msg.pourmoney:"..msg.pourmoney)
	if name=="PourTGG" then 
		local haverate=false
		for k,v in pairs(gold_rate) do
			if v == msg.pourrate and msg.pourmoney == pri_gold*v  then
				haverate = true
				break
			end
		end
		if (randomtime>0 and pour_money~=msg.pourmoney) or haverate == false then
			api_kick(p,1004)
			return
		end
		if p.ctrlinfo then
			receive_type = p.ctrlinfo.ctrltype
			receive_rate = p.ctrlinfo.ctrlrate
			receive_maxgold = p.ctrlinfo.ctrlmaxgold
			receive_count = p.ctrlinfo.ctrlcount
			let_win = check_hadwin(p.ctrlinfo.ctrlcaijin > 1)  --ctrlcaijin	控制彩金(1:不能中，2：可以中)				
			if not receive_nowgold then 
				receive_nowgold = p.ctrlinfo.ctrlnowgold
				-- LOG_DEBUG("receive_nowgold="..receive_nowgold)	
			end
		end
		pour_money=msg.pourmoney
		pour_rate=msg.pourrate
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
	p:send_msg("game.ResumeTGG",{state=game_status})
	if isStart==true then
		sendresult(p)
	end
	-- info_cai_gold(0)  	--发送奖池数据
end

-- 尝试离开游戏，如果能离开，返回true，并且调用该函数的地方继续处理离开逻辑
function this.leave_game(p)
	if isStart == true then
		api_game_end()
		isStart=false
	end
	return true
end

function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid, usegold, _, params, kb)
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
