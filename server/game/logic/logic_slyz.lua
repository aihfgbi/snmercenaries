local this = {}
local skynet = require "skynet"
local players

local played_times
local total_times
--local score
local rule_score
local code
local endtime
local owner
local gameid
local paytype
local config
local tinsert = table.insert
local tremove = table.remove
local tsort=table.sort
local seats
local hasstart
local histroy
local BASE_SCORE = 1     -- 基础分
local show_cards={}
local cards_type={}
local card_rate={}
local pour_money=100
local win_gold=0
local game_status =0
local Cards={}   --最终发给客户端的牌
--local CardsIndex={}  --对随机牌的数字进行记录（未转化之前的）
local isUseGold  --记录玩家游戏模式

local card_history={}
local typenumber={}
local goldpool=10000000
local api_kick
local re_count=0

local kickback,sysearn = 0,0
local sysearn_rate=0.1     --单个玩家的赢钱数目不可以超过sysearn的10%,即0.1

local lock_pourmoney,lock_pourmoneydown=1000,100
local let_win=false          --控制器控制中彩金
local had_win=false          --控制器控制中奖是否已经中了
local win_count=5            --如果控制器控制已经中了，在5次后had_win会变为false
local receive_nowgold 		 --服務器發送的數據：在控制器狀態下現在用戶已經贏取的金幣
local receive_count   		 --接收到的服務器發送的數據
local receive_type    	     --接收到的输赢的信息  1表示输，2表示赢
local receive_maxgold		 --接收到的数据赢取或输钱的限制金钱
local receive_rate	         --接收到服务器关于输赢的概率 当receive——type为1 当前为100   表示一定会输 

local isStart=false
local report_gold
local all_cost,all_earn=0,0

local isTiyan  = false     --体验模式
local test_gold     --体验模式玩家赋初值

local leave_cd_time=20     --玩家离线踢人时间
local leave_time 		   --玩家离线时间

local current_pourmoney    --当局下注

--[[
gamestatus     last_time     desc
    0                        下注
	1              2       游戏开始
    2              1       游戏结束
]]

local next_status_time=0 --切换到下个状态的时间

--测试用 延长状态时间
local DUBUG_TIME = 0

------------------------------------
local send_to_all
local free_table
local api_game_start
local api_game_end
local api_call_ctrl
local win_weight_sum=0  --或将概率总和

------------------------------------

local static_cards = {
	101,102,103,104,105,106,107,108,109,110,111,112,113,	  --方
	201,202,203,204,205,206,207,208,209,210,211,212,213,	  --梅
	301,302,303,304,305,306,307,308,309,310,311,312,313,	  --红
	401,402,403,404,405,406,407,408,409,410,411,412,413,      --黑
}

-- local cards = {}

--牌型对应的倍率
local cardtype_2_rate = {
	[0] = 0,               --杂牌，不得奖
	[1] = 2,			 --10以上的对子    2倍
	[2] = 5,             --两对            5倍
	[3] = 10,            --三条           10倍
	[4] = 15,            --顺子           15倍
	[5] = 20,            --同花           20倍
	[6] = 50,            --葫芦           50倍
	[7] = 100,           --四条          100倍
	[8] = 500,			 --同花顺        500倍
	[9] = 1000,			 --皇家同花顺   1000倍
}

local win_probability={
	[0] = 9500,          --杂牌，不得将
	[1] = 300,			 --10以上的对子    
	[2] = 100,           --两对            
	[3] = 40,            --三条           
	[4] = 30,            --顺子           
	[5] = 13,            --同花         
	[6] = 7,             --葫芦       
	[7] = 6,             --四条   
	[8] = 3,			 --同花顺     
	[9] = 1,			 --皇家同花顺  
}

math.randomseed(os.time())
local function typecount(typenumber,cards_type)   --这个typenumber只是取了typenumber.type
	for i,v in ipairs(cards_type) do 
		if v~=0 then
			typenumber[v]=1+typenumber[v]
		end
	end
	return typenumber
end

local function minrate()
	local min_rate=cardtype_2_rate[1]
	for _,v in pairs(cardtype_2_rate) do
		if v ~= 0 then 
			min_rate=math.min(min_rate,v)
		end
	end
	return min_rate
end

local function CheckWin()    --检测是否符合要求
	currentwin = win_gold                        --currentwin是指当前这一局赢得金币
	current_pourmoney= pour_money                --current_pourmoney是指这一局押注金额
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
		iswin = win_count <= 0
	end
	return iswin
end

local function reportgold()
	if (all_cost > 0 or all_earn > 0) and (not isTiyan) then
		----LOG_DEBUG("上报数据:all_cost="..all_cost..",all_earn="..all_earn)
		report_gold(all_cost, all_earn)
		all_cost ,all_earn = 0,0
	end
end

local function gameresult(p)
	card_rate={}
	local current_win_gold=0
	local current_poolgold=0
	for i,v in ipairs(cards_type) do 
		if cards_type[i]==0 then
			card_rate[i]=0
		else
			card_rate[i]=cardtype_2_rate[cards_type[i]]
			current_win_gold=current_win_gold+pour_money*card_rate[i]
			-- LOG_DEBUG("cards_type:"..cards_type[i])
			if cards_type[i]==7 then 
				current_poolgold=current_poolgold+api_call_ctrl("ReceiveMessage",p.uid,3, 5)
			elseif cards_type[i]==8 then 
				current_poolgold=current_poolgold+api_call_ctrl("ReceiveMessage",p.uid,3, 10)
			elseif cards_type[i]==9 then 
				current_poolgold=current_poolgold+api_call_ctrl("ReceiveMessage",p.uid,3, 80)
			end
		end
	end

	win_gold=current_win_gold

	if current_poolgold>0 then 
		win_gold=win_gold+current_poolgold
	end
	local checkresult=CheckWin()

	if isTiyan then 
		checkresult = true
	end

	if checkresult==false and re_count<10 then
		re_count=re_count+1
		shuffle(p)
	else
		if receive_nowgold then
			receive_nowgold=receive_nowgold-current_pourmoney+currentwin
			-- LOG_DEBUG("receive_nowgold="..receive_nowgold)
		end
		p:send_msg("game.CardSLYZ",Cards)	
		local cardtype={}
		cardtype.cardtype=cards_type
		local cardrate={}
		cardrate.cardrate=card_rate

		if win_gold>0 then
			
			if not isTiyan then
				api_call_ctrl("ReceiveMessage",p.uid,2, win_gold)
				all_earn=all_earn+win_gold
				p:call_userdata("add_gold", win_gold, 10003)
			end	
			--p:call_userdata("add_win", gameid, 1001)
			p.gold=p.gold+win_gold
		end

		local  msg={}
		msg.cardType=cardtype
		msg.cardRate=cardrate
		msg.winGold=win_gold
		msg.ownerGold=p.gold
		p:send_msg("game.ResultSLYZ",msg)

		api_call_ctrl("ReceiveMessage",p.uid,1,pour_money)
		typenumber.type=typecount(typenumber.type,cards_type)
		isStart=false
		game_status=0
		api_game_end()
	end	
end

function this.ReceiveMessage(msg)

	if goldpool~=msg then
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

-- local function checktype(current_cards)
-- 	local caretype = 0
-- 	local number={}
-- 	local Type={}
-- 	for k,v in pairs(current_cards) do 
-- 		tinsert(number,v%13)
-- 		tinsert(Type,math.floor(v/13))
-- 	end
-- 	table.sort(number)
-- 	table.sort(Type)
-- 	local a,b={},{}
-- 	if #number == #(Type) then 
-- 		for i=2,#number do 
-- 			if number[i]==number[i-1] then 
-- 				tinsert(a,'A')
-- 			else
-- 				tinsert(a,'B')
-- 			end
-- 			if Type[i]==Type[i-1] then 
-- 				tinsert(b,'A')
-- 			else
-- 				tinsert(b,'B')
-- 			end
-- 		end
-- 	end
-- 	table.concat(a)
-- 	table.concat(b)
-- 	if a == 'BAAA' or a == 'AAAB' then
-- 		caretype  = 7  --四条
-- 	elseif a == 'AABA' or a == 'ABAA' then
-- 		caretype  = 6  --葫芦
-- 	elseif a == 'AABB' or a == 'BBAA' or a == 'BAAB' then
-- 		caretype  = 3  --三条
-- 	elseif a == 'ABAB' or a == 'BABA' or a == 'ABBA' then
-- 		caretype  = 2  --两对
-- 	elseif a == 'ABBB' or a == 'BABB' or a == 'BBAB' or a == 'BBBA' then
-- 		for k,v in pairs(a) do 
-- 			if v == 'A' then
-- 				if number[k] <=1 or numer[k] >= 10 then
-- 					caretype  = 1  --一对
-- 					break
-- 				end
-- 			end
-- 		end 	
-- 	elseif a == 'BBBB'  then
-- 		if number[5] - number[1] ==4 or ( number[2] == 1 and number[3] == 10) then 
-- 			if b == 'AAAA' then 
-- 				if  number[2] == 1 and number[3] == 10 then 
-- 					caretype  = 9  --皇家同花顺
-- 				elseif number[5] - number[1] ==4 then 
-- 					caretype  = 8 --同花顺
-- 				end
-- 			else
-- 				caretype  = 4 --顺子
-- 			end
-- 		else
-- 			if b == 'AAAA' then 
-- 				caretype = 5 --同花
-- 			else
-- 				caretype  = 0 --什么都不是
-- 			end
-- 		end
-- 	end
-- 	return caretype
-- end

local  function checkcardtype1(current_cards)
	local k1,k2,k3,k4,k5=-1,-1,-1,-1,-1     --用-1而不是用0是为了防止出现K  
	local number1,number2,number3 ,number4,number5=0,0,0,0,0
	k1=current_cards[1]%13
	for i,v in ipairs(current_cards) do
		if current_cards[i]%13==k1 then
			number1=number1+1
		else
			if k2==-1 then 
				k2=current_cards[i]%13
				number2=number2+1
			elseif current_cards[i]%13==k2 then
				number2=number2+1
			else
				if k3==-1 then
					k3=current_cards[i]%13
					number3=number3+1
				elseif current_cards[i]%13 ==k3 then
						number3=number3+1
				else 
					if k4==-1 then
						k4=current_cards[i]%13
						number4=number4+1
					elseif current_cards[i]%13==k4 then
						number4=number4+1
					elseif k5==-1 then
						k5=current_cards[i]%13
						number5=number5+1
					end
				end				
			end
		end
	end
	if number1==4  or  number2==4 then   --四条
		return 7
	elseif (number1==3 and number2==2) or (number1==2 and number2==3) then  --葫芦
		return 6
	elseif (number1==3 and number2==1 and number3==1) or  --三条
		(number1==1 and number2==3 and number3==1) or 
		(number1==1 and number2==1 and number3==3) then

		return 3
	elseif (number1==2 and number2==2 and number3==1) or   --两个对子
		(number1==2 and number2==1 and number3==2) or 
		(number1==1 and number2==2 and number3==2) then

		return 2
	elseif (number1==2 and number2==1 and number3==1 and number4==1 and (k1>=10 or k1<=1))   --大于10的对子
		or (number1==1 and number2==2 and number3==1 and number4==1 and (k2>=10 or k2<=1)) 
		or (number1==1 and number2==1 and number3==2 and number4==1 and (k3>=10 or k3<=1)) 
		or (number1==1 and number2==1 and number3==1 and number4==2 and (k4>=10 or k4<=1)) then
		
		return 1
	else 
		local tablesort={k1,k2,k3,k4,k5}
		tsort(tablesort)                 --排序过牌面  如果是顺子 那么k1=0 k5=12 k2=9  或者k5>=5 并且k1=k5-4
		if ((tablesort[5]==tablesort[1]+4) and tablesort[5]>=5) or                   --或者k2=1 k1=0 k5=12 k3=10
			((tablesort[5]==tablesort[2]+3) and tablesort[1]==0 and tablesort[5]==12) or 
			((tablesort[5]==tablesort[3]+2) and tablesort[1]==0 and tablesort[2]==1 and tablesort[5]==12) then

			return 4
		else 
			return 0
		end
	end
end

local function mathfloor( number )
	return math.floor(number/13)
end

local function checkcardtype(cardgroup)
	
	local current_cards=cardgroup

	local cardtypem=-1
	tsort(current_cards)   --进行排序
	if current_cards[5]%13==0 and                --	皇家同花顺
		current_cards[2]==(current_cards[5]-3) and 
		mathfloor(current_cards[1])==(mathfloor(current_cards[5])-1) and 
		current_cards[1]%13==1 then

		cardtypem=9
	elseif ( (current_cards[5]%13 ==0 and mathfloor(current_cards[5])==mathfloor(current_cards[1])+1) and current_cards[1] ==(current_cards[5]-4) )or    --同花顺
		 ( (mathfloor(current_cards[5])==mathfloor(current_cards[1]) and current_cards[5]%13>=5 ) and current_cards[1] ==(current_cards[5]-4) )then

		cardtypem=8
	elseif (mathfloor(current_cards[1])==mathfloor(current_cards[5])) and current_cards[1]%13~=0 and current_cards[5]%13>5  or 
		(mathfloor(current_cards[5])==mathfloor(current_cards[1])+1 and current_cards[5]%13==0) and 
		current_cards[1]~=(current_cards[5]-4) then                        --同花

		cardtypem=5
	else
		cardtypem=checkcardtype1(current_cards) 
	end

	return cardtypem

end

function shuffle(p)
	Cards={}
	show_cards={}
	cards_type={}
	local let_win_line 
	if let_win == true then 
		let_win_line = math.random(1,5)     --从1到5 五条中选出一条中彩金
	end
	-- LOG_DEBUG("cards_type:"..#cards_type)
	local tmp = {1,2,3,4,5,6,7,8,9,10,11,12,13,
				14,15,16,17,18,19,20,21,22,23,24,25,26,
				27,28,29,30,31,32,33,34,35,36,37,38,39,
				40,41,42,43,44,45,46,47,48,49,50,51,52}
	local get_card_number={}
	for i=1,5 do  --需要循环5次  每次五张
		get_card_number={}
		local current_win_propablity=math.random(1,win_weight_sum)
		local k=0
		local let_win_type=-1
		for j,v in pairs(win_probability) do     --初始化的时候直接计算概率总和
			k=k+v
			if k>=current_win_propablity then
				let_win_type=j
				-- let_win_type=7
				break
			end
		end
		-- LOG_DEBUG("let_win:"..tostring(let_win)) 
		if let_win == false and let_win_type >= 7 then
			-- LOG_ERROR("let_win:"..tostring(let_win).."  let_win_type:"..let_win_type) 
			-- LOG_DEBUG("重来")
			-- shuffle(p)
			let_win_type = math.random(0,6)
		end
		if let_win==true and let_win_line and let_win_line == i then
			local x=math.random(10)
			if x==10 then
				let_win_type=9
			elseif x<=6 then
				let_win_type=7
			else
				let_win_type=8
			end			
			let_win=false
			-- had_win = true
			-- win_count = 5
		end
		local cards = {}
		if let_win_type==9 then
			local x=math.random(0,3)
			get_card_number={10+x*13,11+x*13,12+x*13,13+x*13,1+x*13}
		elseif let_win_type==8 then
			local x=math.random(0,3)
			-- local y=math.random(3,9)
			local y=math.random(1,9)  --顺子从1开始
			get_card_number={y+x*13,y+1+x*13,y+2+x*13,y+3+x*13,y+4+x*13}
		elseif let_win_type==7 then
			local x=math.random(1,13)
			local y=math.random(1,13)
			local m=math.random(0,3)
			while y==x do
				y=math.random(1,13)
				if y~=x then
					break
				end
			end
			get_card_number={x,x+1*13,x+2*13,x+3*13,y+m*13}
		elseif let_win_type==6 then
			local x=math.random(1,13)
			local y=math.random(1,13)
			local m={}
			local t_n={0,1,2,3}
			local t_m= table.arraycopy(t_n)
			local n={}
			for x1=1,3 do
				m[x1]=tremove(t_n, math.random(#t_n))
			end

			for x1=1,2 do
				n[x1]=tremove(t_m, math.random(#t_m))
			end
			while y==x do
				y=math.random(1,13)
				if y~=x then
					break
				end
			end
			get_card_number={x+m[1]*13,x+m[2]*13,x+m[3]*13,y+n[1]*13,y+n[2]*13}
		elseif let_win_type==5 then
			local x=math.random(0,3)
			local t_n={1,2,3,4,5,6,7,8,9,10,11,12,13}
			local t_1= table.arraycopy(t_n)
			local n={}

			for x1=1,5 do
				n[x1]=tremove(t_1, math.random(#t_1))
			end
			tsort(n)
			while n[1]==n[5]-4 or (n[1]==1 and n[2]==10) do
				t_1= table.arraycopy(t_n)
				for i=1,5 do
					n[i]=tremove(t_1, math.random(#t_1))
				end
				tsort(n)
			end
			get_card_number={n[1]+x*13,n[2]+x*13,n[3]+x*13,n[4]+x*13,n[5]+x*13}
		elseif let_win_type==4 then 	
			-- local x=math.random(3,10)
			local x=math.random(1,10)    --顺子从1开始
			local n={}
			for x1=1,5 do
				n[x1]=math.random(0,3)
			end 
			if n[1]==n[2]==n[3]==n[4]==n[5] then 
				if n[1]==3 then
					n[2]=3-math.random(1,3)
				else   
					n[2]=3-n[1]
				end 
			end
			if x==10 then
				get_card_number={x+n[1]*13,x+1+n[2]*13,x+2+n[3]*13,x+3+n[4]*13,1+n[5]*13}
			else
				get_card_number={x+n[1]*13,x+1+n[2]*13,x+2+n[3]*13,x+3+n[4]*13,x+4+n[5]*13}
			end  
		elseif let_win_type==3  then
			local t_n={1,2,3,4,5,6,7,8,9,10,11,12,13} 
			local t_m={0,1,2,3}
			local m={}
			local n={}
			local n1=math.random(0,3)  
			local n2=math.random(0,3)  
			for x1=1,3 do
				m[x1]= tremove(t_n, math.random(#t_n))
				n[x1]=tremove(t_m, math.random(#t_m))
			end
			get_card_number={m[1]+n[1]*13,m[1]+n[2]*13,m[1]+n[3]*13,m[2]+n1*13,m[3]+n2*13}
		elseif let_win_type==2 then
			local t_n={1,2,3,4,5,6,7,8,9,10,11,12,13} 
			local t_m={0,1,2,3}
			local t_m1={0,1,2,3}
			local m={}
			local n={}
			local o={}
			local n1=math.random(0,3)   
			for x1=1,3 do
				m[x1]= tremove(t_n, math.random(#t_n))
				n[x1]=tremove(t_m, math.random(#t_m))
				o[x1]=tremove(t_m1, math.random(#t_m1))
			end
			get_card_number={m[1]+n[1]*13,m[1]+n[2]*13,m[2]+o[1]*13,m[2]+o[2]*13,m[3]+n1*13}
		elseif let_win_type==1 then
			local t_n={1,10,11,12,13} 
			local t_m={0,1,2,3}
			local t_o={2,3,4,5,6,7,8,9}
			local n1=math.random(0,3)  
			local n2=math.random(0,3)  
			local n3=math.random(0,3) 
			local m=0
			local n={}
			local o={}
			m=t_n[math.random(#t_n)]				 
			for x1=1,3 do
				n[x1]= tremove(t_m, math.random(#t_m))
				o[x1]= tremove(t_o, math.random(#t_o))
			end 
			get_card_number={m+n[1]*13,m+n[2]*13,o[1]+n1*13,o[2]+n2*13,o[3]+n3*13}
		elseif let_win_type==0 then
			local t= table.arraycopy(tmp)
			local index
			for x1=52,48,-1 do
				index = tremove(t, math.random(x1))
				tinsert(get_card_number, index)
			end
			local currenttype= checkcardtype(get_card_number)
			while currenttype~=0 do 
				get_card_number={}
				t= table.arraycopy(tmp)
				for x1=52,48,-1 do
					index = tremove(t, math.random(x1))
					tinsert(get_card_number, index)
				end
				currenttype= checkcardtype(get_card_number)
			end
			-- local t_n={1,2,3,4,5,6,7,8,9,10,11,12,13} 						
			-- local t_m={0,1,2,3,math.random(0,3)}
			-- for i=#t_n,#t_n-4,-1 do
			-- 	local index = tremove(t_n, math.random(i))
			-- 	tinsert(get_card_number, index)
			-- end
			-- table.sort(get_card_number)
			-- while (get_card_number[1] == get_card_number[5] - 4) or (get_card_number[2] == 1 and get_card_number[3] == 10) do
			-- 	t_n={1,2,3,4,5,6,7,8,9,10,11,12,13} 						
			-- 	t_m={0,1,2,3,math.random(0,3)}
			-- 	for i=#t_n,#t_n-4,-1 do
			-- 		local index = tremove(t, math.random(i))
			-- 		tinsert(get_card_number, index)
			-- 	end
			-- 	table.sort(get_card_number)
			-- end
			-- get_card_number={get_card_number[1]+13*t_m[1],get_card_number[2]+13*t_m[2],get_card_number[3]+13*t_m[3],get_card_number[4]+13*t_m[4],get_card_number[5]+13*t_m[5]}
		end
		local t1= table.arraycopy(get_card_number)
		for x1=5,1,-1 do
			index = tremove(t1, math.random(x1))
			tinsert(cards, static_cards[index])
		end

		local msg1={}
		msg1.card=cards
		show_cards[i]=msg1
		cards_type[i]=checkcardtype(get_card_number)
		if let_win == true and card_type[i] >= 7 then 
			had_win = true
			win_count = 5
		end
		--LOG_DEBUG("let_type:"..let_win_type.."  type:"..cards_type[i])
	end
	Cards.cardH=show_cards
	gameresult(p)	
end

function this.add_gold(p, gold, reason)
	LOG_DEBUG("用户充值")
	p.gold = p.gold + gold
	if p.gold < 0 then
		p.gold = 0
	end
	p:send_msg("game.UpdateGoldInGame", {uid=p.uid,goldadd=gold,gold=p.gold})
end

local function game_start(p)	
	api_game_start()
	isStart=true
	re_count=0
	shuffle(p)
end

function this.free()

	isStart=false  
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

function this.offline(p)
	leave_time=os.time()+leave_cd_time
end

function this.update()
	if leave_time and os.time()> leave_time then
		reportgold()
		api_kick(p1,1003)
	end
end

function this.join(p)   --加入游戏
	p1=p
	if p.ctrlinfo and p.ctrlinfo.ctrlnowgold then
		receive_nowgold=p.ctrlinfo.ctrlnowgold
		-- LOG_DEBUG("receive_nowgold="..receive_nowgold)	
	end
	for i,v in pairs(win_probability) do     --初始化的时候直接计算概率总和
		win_weight_sum=win_weight_sum+v
	end
	if isTiyan then 
		p.gold = test_gold
	end
	goldpool=api_call_ctrl("ReceiveMessage",uid,3,0)
	typenumber=api_call_ctrl("ReceiveMessage",p.uid,5,{uid=p.uid,type={[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0}})
	return p.gold>=0
end

function this.dispatch(p, name, msg)
	if name=="GameStartSLYZ" then
		if game_status==0 then
			if lock_pourmoney >= msg.pourgold and msg.pourgold >= lock_pourmoneydown then
				if p.gold>= msg.pourgold*5 then
					game_status=1
					pour_money=msg.pourgold
					if not isTiyan then 
						all_cost=all_cost+pour_money*5
						api_call_ctrl("ReceiveMessage",p.uid,1, pour_money*5)
						p:call_userdata("sub_gold", pour_money*5, 10003)
					end
					p.gold=p.gold-pour_money*5
					if p.ctrlinfo then
						receive_type = p.ctrlinfo.ctrltype
						receive_rate = p.ctrlinfo.ctrlrate
						receive_maxgold = p.ctrlinfo.ctrlmaxgold
						receive_count = p.ctrlinfo.ctrlcount
						-- let_win = p.ctrlinfo.ctrlcaijin > 1  --ctrlcaijin	控制彩金(1:不能中，2：可以中)
						let_win = check_hadwin(p.ctrlinfo.ctrlcaijin > 1) 
						if not receive_nowgold then 
							receive_nowgold = p.ctrlinfo.ctrlnowgold
							-- LOG_DEBUG("receive_nowgold="..receive_nowgold)	
						end
					end
					game_start(p)
				else
					if not isTiyan then
						p:send_msg("game.GameStartSLYZ", msg)
					end
				end
			else
				api_kick(p,1004)
				LOG_ERROR("客户端数据异常")
			end
		end
	elseif name=="HistoryMessageSLYZ"  then
		p:send_msg("game.HistoryMessageSLYZ", typenumber)
	elseif name=="WinGoldPoolHistory"  then
		local msg={}
		msg.history=api_call_ctrl("ReceiveMessage",p.uid,4,0)
		p:send_msg("game.WinGoldPoolHistory", msg)
	end
end

-- 发送房间信息
function this.get_tableinfo(p)   --发送房间信息
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
						gold=v.gold,
						params={goldpool}})
	end
	msg.owner = owner
	msg.endtime = hasstart and 0 or endtime
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

function this.resume(p)
	-- 恢复游戏
	-- 状态
	if leave_time then leave_time=nil end
	local msg = {}
	local cur_status = game_status

	msg.status = cur_status
	if cur_status==0 then 
		msg.pourgold=pour_money

	else
		msg.pourgold=100
	end
	p:send_msg("game.ResumeSLYZ", msg)
	if isStart==true then
		if cur_status==1  then
			p:send_msg("game.CardSLYZ",{cardH=show_cards})

			local cardtype={}
			cardtype.cardtype=cards_type
			local cardrate={}
			cardrate.cardrate=card_rate
			local  msg={}
			msg.cardType=cardtype
			msg.cardRate=cardrate
			msg.winGold=win_gold
			msg.ownerGold=p.gold
			p:send_msg("game.ResultSLYZ",msg)
		end
	end
end

-- 尝试离开游戏，如果能离开，返回true，并且调用该函数的地方继续处理离开逻辑
function this.leave_game(p)
	-- if game_status==0 then
	-- 	api_call_ctrl("ReceiveMessage",p.uid,5,typenumber)
	-- 	reportgold()
	-- 	return true
	-- else
	-- 	return false
	-- end
	return true 
end

local function report_gold_info()
	while true and (not isTiyan) do
		reportgold()
		skynet.sleep(5*100)
	end
end

function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid, usegold, _, params, kb)
	seats = {}
	players = ps
	config = m_conf
	played_times = 0
	total_times = m_times
	rule_score = m_score
	code = m_code
	endtime = os.time() + m_conf.wait_time
	next_status_time=os.time()
	owner = 0
	gameid = m_gameid
	paytype = m_pay
	hasstart = false
	gametype = config.init_params
	game_status = 0
	isUseGold=usegold
	kickback=kb
	if kickback then
		all_cost = 0
		all_earn = 0
		skynet.fork(report_gold_info)
	end

	if config.test_gold then
		isTiyan = true
		test_gold = config.test_gold
	end

	lock_pourmoney=config.init_params.lock_pourmoney
	pour_money=config.init_params.pour_money

	send_to_all = api.send_to_all
	free_table = api.free_table
	api_game_start = api.game_start
	api_game_end=api.game_end
	api_call_ctrl=api.call_ctrl
	api_kick=api.kick
	report_gold=api.report_gold
end

return this