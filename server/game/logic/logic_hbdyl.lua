local this = {}
local players,config,code,gameid

local tinsert = table.insert

local automodel=0       --辨识是否是自动模式   0   不是自动模式  1  是自动模式
local send_to_all       --发送给所有客户端
local free_table        --闲置
local api_game_start    --游戏开始的方法
local api_game_end      --游戏结束
local pour_money=120   --每一注的下注金额
--local pour_status       --下注状态  0 1 2都可以下注  0可以改变线数和底注 1只可以改变线数 2只可以改变底注 3不能下注   
local pour_gold         --下注金额
local currentwin=0 		--这一局赢的钱
local wingold={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}       --赢得的数量
local wintotal=0        --总共赢得的数量
local game_status       --游戏状态   1 下注阶段  2开始（转动）及显示结果 3免费阶段
local isUseGold         --金币模式 

local p1={}             --替代当前玩家p
local api_call_ctrl
local  hadadd=false 	--用来判别游戏结算金币是否已经添加到用户数据

local next_status_time=0
local showcards={}
local win_type={}
local win_number={}
local win_order={}  --结果中奖顺序   0表示从左到右中奖 1表示从右到左中奖
local win_double={} --奖励翻倍	翻倍为2   不翻倍为1
local compare_double=1
local current_comparegold=0

local lock_pourmoney=900
local one_two=0   --用来表示比被时候第几次点击  第一次是指选择半倍还是一倍  第二次是翻拍的时候

local randomtime=0      --当前有多少次免费机会，出现钻石的情况下随机出来的
local jackpot=0         --彩金奖池的比率数值

local goldpool=10000000

local let_win=false      --接受服务器信息  是否让用户中彩金

local isStart=false      --判断游戏是否开始
local total=0            --所有概率的和

--定义图片顺序 猫头鹰1，狐狸2，蝴蝶3，兰花4，红花5，九6，十7，十一8，十二9，十三10，A11，黑豹12，月亮13
local numberdata={
	{1,2},{1,2},{2,3},{3,3},{3,3},{4,2},{5,3},{5,3},{6,3},{7,3},{7,3},{8,2},{9,2},
}
local numberChance={[1]=4,[2]=16,[3]=32,[4]=40,[5]=40,[6]=40,[7]=20,[8]=30,[9]=45,[10]=25,[11]=10,[12]=1,[13]=1}
local numberToRate={    --每种类型对应的奖金比率
	[1]={2,25,125,750},
	[2]={2,25,125,750},
	[3]={0,20,100,500},
	[4]={0,15,75,250},
	[5]={0,15,75,250},
	[6]={2,5,25,100},
	[7]={0,5,25,100},
	[8]={0,5,25,100},
	[9]={0,5,30,125},
	[10]={0,10,40,150},
	[11]={0,10,40,150},
	[12]={10,250,2500,10000},
	[13]={2,5,20,500},
}

local parType={    --对应序号需要检查的位置
	[1]={[1]={1,2},[2]={2,2},[3]={3,2},[4]={4,2},[5]={5,2}},
	[2]={[1]={1,1},[2]={2,1},[3]={3,1},[4]={4,1},[5]={5,1}},
	[3]={[1]={1,3},[2]={2,3},[3]={3,3},[4]={4,3},[5]={5,3}},
	[4]={[1]={1,1},[2]={2,2},[3]={3,3},[4]={4,2},[5]={5,1}},
	[5]={[1]={1,3},[2]={2,2},[3]={3,1},[4]={4,2},[5]={5,3}},
	[6]={[1]={1,2},[2]={2,1},[3]={3,1},[4]={4,1},[5]={5,2}},
	[7]={[1]={1,2},[2]={2,3},[3]={3,3},[4]={4,3},[5]={5,2}},
	[8]={[1]={1,1},[2]={2,1},[3]={3,2},[4]={4,3},[5]={5,3}},
	[9]={[1]={1,3},[2]={2,3},[3]={3,2},[4]={4,1},[5]={5,1}},
	[10]={[1]={1,2},[2]={2,3},[3]={3,2},[4]={4,1},[5]={5,2}},
	[11]={[1]={1,1},[2]={2,1},[3]={3,2},[4]={4,3},[5]={5,2}},
	[12]={[1]={1,1},[2]={2,2},[3]={3,2},[4]={4,2},[5]={5,1}},
	[13]={[1]={1,3},[2]={2,2},[3]={3,2},[4]={4,2},[5]={5,3}},
	[14]={[1]={1,1},[2]={2,2},[3]={3,1},[4]={4,2},[5]={5,1}},
	[15]={[1]={1,3},[2]={2,2},[3]={3,3},[4]={4,2},[5]={5,3}},
}

math.randomseed(os.time())

function this.free()
	isStart=false
	win_type={}
	win_number={}
	win_order={}
	win_double={}
	pour_money=9
	let_win=false
end

function this.ReceiveMessage(msg)
	if msg=="true" then
		let_win=true
	elseif msg=="false" then
		let_win=false
	elseif goldpool~=msg then
		goldpool=msg
		local msg1={}
		msg1.goldpool=msg
		send_to_all("game.GoldPool",msg1)
	else
		local msg1={}
		msg1.sendmessage=msg
		send_to_all("game.SendMessage",msg1)
	end
end

function this.join(p)    --玩家加入房间的判断
	for i,v in ipairs(numberChance) do
		total=total+numberChance[i]
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
    --luadump(msg)

	return msg
end

local function RandomGold()
	wingold={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	currentwin=0
	for i=1,#win_type do 
		if win_type[i]>=1 and win_type[i] <=12  then
			if win_number[i]<=5 then
				wingold[i]=math.floor(numberToRate[win_type[i]][win_number[i]-1]*win_double[i]*pour_money/15)
				currentwin=currentwin+numberToRate[win_type[i]][win_number[i]-1]*win_double[i] 
			end
		elseif win_type[i]==13 then
			if win_number[i]<=5 then
				wingold[i]=math.floor(numberToRate[win_type[i]][win_number[i]-1]*win_double[i]*3*pour_money/15)
				currentwin=currentwin+numberToRate[win_type[i]][win_number[i]-1]*win_double[i]*3
				randomtime=15 
			end	
		end
	end
end

local function result()
	RandomGold()
	currentwin=currentwin*pour_money/15
	if currentwin>0 then
		api_call_ctrl("ReceiveMessage",p1.uid,2,currentwin)
	end
	if jackpot~=0 then
		local win_goldpool=api_call_ctrl("ReceiveMessage",p1.uid,3,jackpot)
		currentwin=currentwin+win_goldpool
		jackpot=0
	end

	if randomtime>0 then 
		wintotal=wintotal+currentwin
	else
		wintotal=currentwin
	end

	p1.gold=p1.gold+currentwin
	p1:call_userdata("add_gold", currentwin, 10001)
	if currentwin>0 then
		p1:call_userdata("add_win", gameid, 1001)
	end

	local msg={}	
	msg.showcards=showcards
	msg.wintype=win_type
	msg.winnumber=win_number
	msg.winorder=win_order
	msg.wingold=wingold
	msg.randomtime= randomtime 
	msg.wintotal=math.floor( wintotal )
	msg.owngold=math.floor(p1.gold)
	p1:send_msg("game.GameResultCSD", msg)
	
	--PRINT_T(msg)
	next_status_time=os.time()+2
end


-- 玩家游戏外造成的金币增减，需要通知到游戏内，进行金币的增减
function this.add_gold(p, gold, reason)
	LOG_WARNING("用户充值")
	p.gold = p.gold + gold
	if p.gold < 0 then
		p.gold = 0
	end
	p:send_msg("game.UpdateGoldInGame", {uid=p.uid,goldadd=gold,gold=p.gold})
end


local function random(p)
	win_type={}     --重新判断结果时需要将以前数据清空，避免减线数据长度不变
	win_number={}
	win_order={}
	win_double={}
	showcards={}
	current_comparegold=0
	local randomnumber={} 	
	
	for i=1,5 do    --出五组随机数
		local randomnumberX={}
		for j=1,3 do           --每组随机数有3个
			local k=math.random(1,total)
			local sum=0
			for m,v in ipairs(numberChance) do      --对随机出来的数字进行查找 
				sum=sum+v
				if sum>=k then
					randomnumberX[j]=m		
					break
				end
			end
		end

		local rondoml={}

		if let_win==true then
			if pour_number>=3 then
				randomnumberX=randomLine(i)
			end
		end

		rondoml.randomL=randomnumberX
		tinsert(randomnumber,rondoml)

	end

	--LOG_DEBUG("pour_number"..pour_number)

	for k,v in pairs(randomnumber) do 
		for _,v1 in pairs(v.randomL) do
			tinsert(showcards,v1)
		end
	end

	for i=1,15 do
		local t=parType[i]
		local currentLine={}
		win_double[i]=1
		for j=1,5 do
			tinsert(currentLine,randomnumber[t[j][1]].randomL[t[j][2]])
			if currentLine[j]==13 then 
				win_order[i]=1
			else
				win_order[i]=0
			end
		end
		local type=numberdata[currentLine[1]][1]
		local smallcount=numberdata[currentLine[1]][2]
		local a,b=0,0
		--PRINT_T(currentLine)

		if currentLine[1]==1 or currentLine[1]==2 then
			a,b=1,2
		elseif currentLine[1]==3 then
			a,b=3,3
		elseif currentLine[1]==4 or currentLine[1]==5 then
			a,b=4,5
		elseif currentLine[1]==6 then
			a,b=6,6
		elseif currentLine[1]==7 or currentLine[1]==8 then
			a,b=7,8
		elseif currentLine[1]==9 then
			a,b=9,9
		elseif currentLine[1]==10 or currentLine[1]==11 then
			a,b=10,11
		elseif currentLine[1]==12 then
			a,b=12,12
		end
		--LOG_WARNING("a="..a,"b="..b,"首个数字"..currentLine[1])

		if (currentLine[2]==a or currentLine[2]==b or currentLine[2]==12) and
			(currentLine[3]~=a and currentLine[3]~=b and currentLine[3]~=12) then
			if currentLine[2]==12 and currentLine[1]~=12 then
				win_double[i]=2
			end
			win_type[i]=currentLine[1]
			win_number[i]=2
		elseif (currentLine[2]==a or currentLine[2]==b or currentLine[2]==12) and
			(currentLine[3]==a or currentLine[3]==b or currentLine[3]==12) and
			(currentLine[4]~=a and currentLine[4]~=b and currentLine[4]~=12) then
			if currentLine[2]==12 or currentLine[3]==12 and currentLine[1]~=12 then
				win_double[i]=2
			end
			win_type[i]=currentLine[1]
			win_number[i]=3
		elseif (currentLine[2]==a or currentLine[2]==b or currentLine[2]==12) and
			(currentLine[3]==a or currentLine[3]==b or currentLine[3]==12) and
			(currentLine[4]==a or currentLine[4]==b or currentLine[4]==12) and
			(currentLine[5]~=a and currentLine[5]~=b and currentLine[5]~=12) then
			if currentLine[2]==12 or currentLine[3]==12 or currentLine[4]==12 and currentLine[1]~=12 then
				win_double[i]=2
			end
			win_type[i]=currentLine[1]
			win_number[i]=4
		elseif (currentLine[2]==a or currentLine[2]==b or currentLine[2]==12) and
			(currentLine[3]==a or currentLine[3]==b or currentLine[3]==12) and
			(currentLine[4]==a or currentLine[4]==b or currentLine[4]==12) and
			(currentLine[5]==a or currentLine[5]==b or currentLine[5]==12) then
			if currentLine[2]==12 or currentLine[3]==12 or currentLine[4]==12 or currentLine[5]==12 and currentLine[1]~=12 then
				win_double[i]=2
			end
			win_type[i]=currentLine[1]
			win_number[i]=5
		end

		if currentLine[1]==13 then 
			a=13
		end
		if (currentLine[2]==a ) and (currentLine[3]~=a) then

			win_type[i]=currentLine[1]
			win_number[i]=2
		elseif (currentLine[2]==a ) and (currentLine[3]==a ) and
			(currentLine[4]~=a ) then

			win_type[i]=currentLine[1]
			win_number[i]=3
		elseif (currentLine[2]==a ) and (currentLine[3]==a ) and
			(currentLine[4]==a ) and (currentLine[5]~=a ) then

			win_type[i]=currentLine[1]
			win_number[i]=4
		elseif (currentLine[2]==a ) and (currentLine[3]==a ) and
			(currentLine[4]==a ) and (currentLine[5]==a ) then

			win_type[i]=currentLine[1]
			win_number[i]=5
		else
			win_type[i]=0
			win_number[i]=0
		end

		if win_type[i]==0 and win_order[i]==1 then 
			if currentLine[5]==1 or currentLine[5]==2 then
				a,b=1,2
			elseif currentLine[5]==3 then
				a,b=3,3
			elseif currentLine[5]==4 or currentLine[5]==5 then
				a,b=4,5
			elseif currentLine[5]==6 then
				a,b=6,6
			elseif currentLine[5]==7 or currentLine[5]==8 then
				a,b=7,8
			elseif currentLine[5]==9 then
				a,b=9,9
			elseif currentLine[5]==10 or currentLine[5]==11 then
				a,b=10,11
			elseif currentLine[5]==12 then
				a,b=12,12
			end

			if (currentLine[4]==a or currentLine[4]==b or currentLine[4]==12) and
				(currentLine[3]~=a and currentLine[3]~=b and currentLine[3]~=12) then
				if currentLine[4]==12 and currentLine[5]~=12 then
					win_double[i]=2
				end
				win_type[i]=a
				win_number[i]=2
			elseif (currentLine[4]==a or currentLine[4]==b or currentLine[4]==12) and
				(currentLine[3]==a or currentLine[3]==b or currentLine[3]==12) and
				(currentLine[2]~=a and currentLine[2]~=b and currentLine[2]~=12) then
				if currentLine[4]==12 or currentLine[3]==12 and currentLine[5]~=12 then
					win_double[i]=2
				end
				win_type[i]=a
				win_number[i]=3
			elseif (currentLine[2]==a or currentLine[2]==b or currentLine[2]==12) and
				(currentLine[3]==a or currentLine[3]==b or currentLine[3]==12) and
				(currentLine[4]==a or currentLine[4]==b or currentLine[4]==12) and
				(currentLine[1]~=a and currentLine[1]~=b and currentLine[1]~=12) then
				if currentLine[2]==12 or currentLine[3]==12 or currentLine[4]==12 and currentLine[5]~=12 then
					win_double[i]=2
				end
				win_type[i]=a
				win_number[i]=4
			elseif (currentLine[2]==a or currentLine[2]==b or currentLine[2]==12) and
				(currentLine[3]==a or currentLine[3]==b or currentLine[3]==12) and
				(currentLine[4]==a or currentLine[4]==b or currentLine[4]==12) and
				(currentLine[1]==a or currentLine[1]==b or currentLine[1]==12) then
				if currentLine[2]==12 or currentLine[3]==12 or currentLine[4]==12 or currentLine[1]==12 and currentLine[5]~=12 then
					win_double[i]=2
				end
				win_type[i]=a
				win_number[i]=5
			end
			if currentLine[5]==13 then 
				a=13
			end
			if (currentLine[4]==a ) and (currentLine[3]~=a) then

				win_type[i]=a
				win_number[i]=2
			elseif (currentLine[4]==a ) and (currentLine[3]==a ) and
				(currentLine[2]~=a ) then

				win_type[i]=a
				win_number[i]=3
			elseif (currentLine[2]==a ) and (currentLine[3]==a ) and
				(currentLine[4]==a ) and (currentLine[1]~=a ) then

				win_type[i]=a
				win_number[i]=4
			elseif (currentLine[2]==a ) and (currentLine[3]==a ) and
				(currentLine[4]==a ) and (currentLine[1]==a ) then

				win_type[i]=a
				win_number[i]=5
				win_type[i]=0
				win_number[i]=0
			end
		end	

		if win_number[i]==2 and win_type[1]~=1 and win_type[1]~=2 and   --判断是否是有2的情况
			win_type[1]~=6 and win_type[1]~=12 and win_type[1]~=13 then
			win_type[i]=0
			win_number[i]=0
		end
	end
	result()
end


local function game_start(p)
	--PRINT_T(players)
	local msg={}
	msg.goldpool=goldpool
	p:send_msg("game.GoldPool",msg)
	--PRINT_T(msg)
	if game_status==1 then --如果处于下注状态就改变为开始状态
		if lock_pourmoney>=pour_money then
			if randomtime>0 or p.gold>=pour_money then
				game_status=2
				api_game_start()          --取消在此位置的断线，把断线功能提前
				isStart=true
				--LOG_DEBUG("开始随机数字")
				if randomtime<=0 then
					--LOG_DEBUG("扣金币之前的金币数量"..p.gold)
					p.gold=p.gold-pour_money
					api_call_ctrl("ReceiveMessage",p1.uid,1, pour_money)
				    --LOG_WARNING("发送奖金池数据变动金额请求")
					p:call_userdata("sub_gold", pour_money, 10001)
					--LOG_DEBUG("扣金币之后的金币数量"..p.gold)
				end
				random(p)
			else
				p:send_msg("game.PourCSD",{pourmoney=pour_money})		
			end	
		else
			LOG_ERROR("客户端发送数据信息异常")
			return 
		end
	end   
end


function this.update()    --更新游戏时间  0.1s刷新一次
	
	if next_status_time and os.time()>next_status_time then
		if game_status==2 then   --开始状态切换到发送结果状态
			next_status_time=nil
			game_status=1	
			if randomtime>0 then
				--LOG_DEBUG("randomtime"..randomtime)
				randomtime=randomtime-1
				game_start(p1)
			else				
				isStart=false
				api_game_end()			
			end						
		end
	end
end

local static_cards = {
	101,102,103,104,105,106,107,108,109,110,111,112,113,	  --方
	201,202,203,204,205,206,207,208,209,210,211,212,213,	  --梅
	301,302,303,304,305,306,307,308,309,310,311,312,313,	  --红
	401,402,403,404,405,406,407,408,409,410,411,412,413,      --黑
}

local function CompareScore()

	if current_comparegold==0 then 
		if wintotal>0 then
			current_comparegold=wintotal
		else
			current_comparegold=currentwin
		end
	end
	if randomtime==0 and current_comparegold>0 then		
		local show_cards={}
		local current_win_gold
		if one_two==1 then
			current_win_gold=current_comparegold*compare_double/2
			local tmp = {1,2,3,4,5,6,7,8,9,10,11,12,13,
						14,15,16,17,18,19,20,21,22,23,24,25,26,
						27,28,29,30,31,32,33,34,35,36,37,38,39,
						40,41,42,43,44,45,46,47,48,49,50,51,52}

			local tmp1={1,2,3,4,5,6,7,8,9,10,11,12,13}
			for i=13,9,-1 do
				local index=tremove(tmp1,math.random(i))
				tinsert(show_cards,index)
			end

			local x=math.random(10)
			local let_win=(x==5)
			table.sort(show_cards)
			if show_cards[4]==1 then
				local c= tremove(show_cards)
				tinsert(show_cards,1,c)
				local d= tremove(show_cards)
				tinsert(show_cards,1,d)
			elseif show_cards[5]==0 then 
				local c= tremove(show_cards)
				tinsert(show_cards,1,c)
			end
			if let_win==true then 
				local c= tremove(show_cards,4)
				tinsert(show_cards,c)
				current_comparegold=current_comparegold+current_win_gold
				p1.gold=p1.gold+current_win_gold
				p1:call_userdata("add_gold", current_win_gold, 10001)
			else
				local c= tremove(show_cards,5)
				tinsert(show_cards,3,c)
				current_comparegold=current_comparegold-current_win_gold
				p1.gold=p1.gold-current_win_gold
				p1:call_userdata("sub_gold", current_win_gold, 10001)
			end

			local XI={math.random(3),math.random(3),math.random(3),math.random(3),math.random(3)}
			for i,v in pairs(show_cards) do
				show_cards[i]=v+13*XI[i]
				show_cards[i]=static_cards[show_cards[i]]
			end
		end
		if let_win==false then 
			current_win_gold=0
		end
		local msg={}
		if one_two== 1 then 
			msg.cards={show_cards[1]}
			msg.wongold=0
			msg.gold=0
			msg.owngold=0
		elseif one_two== 1 then
			msg.cards={show_cards[2],show_cards[3],show_cards[4],show_cards[5]}
			msg.wongold=current_win_gold
			msg.gold=current_comparegold
			msg.owngold=p1.gold
		end
		p:send_msg("game.CompareScoreResult",msg)

	end
	-- body
end

function this.dispatch(p, name, msg)
	p1=p
	if name=="PourCSD" then 
		if game_status==1  then   --玩家未点击开始
			pour_money=msg.pourmoney
			if lock_pourmoney>=pour_money then
				if p.gold>=pour_money then
					game_start(p)			
				else
					p:send_msg("game.PourCSD",msg)
				end	
			else
				error("客户端发送数据信息异常")
				return
			end	
		end
	elseif name == "CompareScore" then
		--LOG_DEBUG("请求离开")
		compare_double=msg.times1
		one_two=msg.times2
		CompareScore()
	end
end

function this.resume(p)
	-- 恢复游戏
	-- 状态
	if isStart==true then
		local msg={}	
		msg.showcards=showcards
		msg.wintype=win_type
		msg.winnumber=win_number
		msg.winorder=win_order
		msg.wingold=wingold
		msg.randomtime=randomtime
		msg.wintotal=wintotal
		msg.owngold=p.gold
		p:send_msg("game.GameResultCSD", msg)
	end

end

-- 尝试离开游戏，如果能离开，返回true，并且调用该函数的地方继续处理离开逻辑
function this.leave_game(p)
	if game_status ==1 then   --只要不是处于下注阶段都可以离开
		if randomtime<=0 then
			pour_money=9
			wingold={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
			wintotal=0
			win_type={}
			win_number={}
			win_order={}
			win_double={}
			return true  
		else
			return false
		end  
	-- else
	-- 	return false
	end
end

function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid, usegold)
	players = ps          --玩家
	config = m_conf       --设置信息
	--PRINT_T("config"..config)
	code = m_code         --指令类型
	gameid = m_gameid     --名称id
	game_status=1         --游戏可以进入下注阶段
	isUseGold=usegold

	lock_pourmoney=config.init_params.lock_pourmoney
	pour_money=config.init_params.pour_money

	endtime = os.time() + m_conf.wait_time
	owner = uid
	--LOG_DEBUG("uid"..uid)
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

	goldpool=api_call_ctrl("ReceiveMessage",uid,3,0)
	--LOG_DEBUG("goldpool="..goldpool)

end

return this
