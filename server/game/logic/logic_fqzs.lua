local ctrl = require "fqzs_slwh_ctrl"

local this = {}
local players = {}
local isUseGold --是否金币模式
local played_times
local total_times
local open_times --开牌次数(大于10次不做控制)
local test_gold
--local score
local rule_score
local code
local endtime
local owner
local gameid
local paytype
local config
local tinsert = table.insert
local tindexof = table.indexof
local tclear = table.clear
local mrandom = math.random
local tremove = table.remove
local os_time = os.time
local master
local pour_message={} --本把押注
local last_pour_message={} --上一把押注
local win_message={} --押注所得
local banker_users = {} --庄家等待列表
local tpourname = {} --押注名字
local banker = {} --庄家
local xutou = {}
local tSort = {} --排名
local total_pour = {[1] = 0,[2] = 0,[3] = 0,[4] = 0,[5] = 0,[6] = 0,[7] = 0,[8] = 0,[9] = 0,[10] = 0,[11] = 0} --总投注
local banker_payments = 0 --庄家盈亏
local tHistory = {1,5,9,12,28,16,9}
local player
local game_id = 10002
local minbanker = 100000000
local game_status --游戏状态，0表示还在等人开始中,1表示准备开始阶段,2是发牌阶段,3抢庄阶段，4设置庄家阶段
local randomresult = {} --随机落点
local randomtype = 0 --落点属性
local nflag = 0
local runtime = 0
local next_time = 0
local total_bet = 0 --用户总押注
local qiaodan = true
local danshuai = true
local nNumber = 1
local next_status_time --切换到下个状态的时间
local status_time={[1]=10,[2]={13,20},[3]=5}
local BetOrNot = {}
local Free_Out = {}
local Free_In = {}
local Free = {}

--设定一个权重值，按照模型上的概率设定
--按顺序一次为  金鲨、兔子、猴子、通吃、熊猫、狮子、鲨鱼、老鹰、孔雀、通赔、鸽子、燕子
local  weight={[1]=1,[2]=3,[3]=3,[4]=1,[5]=3,[6]=3,[7]=1,[8]=3,[9]=3,[10]=1,[11]=3,[12]=3}
local tJordan = {[1] = {9,0},[2] = {10,4},[3] = {6,4},[4] = {0,0},[5] = {5,4},[6] = {11,4},[7] = {9,0},[8] = {8,3},[9] = {1,3},[10] = {0,0},[11] = {2,3},[12] = {7,3}}
local tRate = {10,10,2,2,10,10,8,14,100,8,14}
-- 下注金额
local poreqian = {[0] = 1000,[1]=10000,[2]=100000,[3]=1000000,[4]=5000000,[5]=10000000}
local godv = {10000000,5000000,1000000,100000,10000,1000}
local We1less = {[10000000]=5,[5000000]=4,[1000000]=3,[100000]=2,[10000]=1,[1000] = 0}
local tFour = {
{id = {23,24,25,26},random = 8},{id = {24,25,26,27},random = 8},{id = {25,26,27,28},random = 8},{id = {26,27,28,1},random = 3},
{id = {27,28,1,2},random = 3},{id = {28,1,2,3},random = 3},{id = {1,2,3,4},random = 3},{id = {2,3,4,5},random = 8},
{id = {3,4,5,6},random = 8},{id = {4,5,6,7},random = 8},{id = {9,10,11,12},random = 5},{id = {10,11,12,13},random = 5},
{id = {11,12,13,14},random = 5},{id = {12,13,14,15},random = 3},{id = {13,14,15,16},random = 2},{id = {14,15,16,17},random = 2},
{id = {15,16,17,18},random = 3},{id = {16,17,18,19},random = 5},{id = {17,18,19,20},random = 5},{id = {18,19,20,21},random = 5},
}
local tTime = {{time = 3,random= 60},{time = 4,random= 30},{time = 5,random= 10}}
local tSpecial= {{number = 1 ,random = 980},{number = 2 ,random = 5},{number = 3 ,random = 10},{number = 4 ,random = 5}}
local tMultiple = {[1] = 8,[2] = 8,[3] = 2,[4] = 2,[5] = 8,[6] = 8,[7] = 6,[8] = 12,[9] = 24,[10] = 6,	[11] = 12}

--随机落点概率
local tLand = {
	{id = {1},random = 2,nId = 1},{id = {2,3,4},random = 20,nId = 2},{id = {5,6,7},random = 10,nId = 3},{id = {8},random = 1,nId = 4},
	{id = {9,10,11},random = 10,nId = 5},{id = {12,13,14},random = 7,nId = 6},{id = {15},random = 2,nId = 7},{id = {16,17,18},random = 7,nId = 8},
	{id = {19,20,21},random = 10,nId = 9},{id = {22},random = 1,nId = 10},{id = {26,27,28},random = 20,nId = 11},{id = {23,24,25},random = 10,nId = 12},
}

------------------------------------
local send_to_all
local send_except
local api_game_start
local api_game_end
local api_join_robot
local api_kick
local api_report_gold
------------------------------------
math.randomseed(os_time());

-- 机器人数据
local jqr_list = {}
local kick_time = {}
-- local jqr_pour = 10000
------------------------------------------------------------机器人控制-----------------------------------------------------
--获取机器人
local function check_join_robot()
	if table.len(jqr_list) >= 20 then
		return
	end
	if os_time() >= next_time then
		next_time = os_time() + 10
		local gold = math.random(minbanker, minbanker*10)
		api_join_robot("fqzs", gold)
	end
end

--机器人押注
-- local function jqr_total_bet(pourobject,pourmoney)
local function jqr_total_bet()
	for uid,p in pairs(jqr_list) do
		local msg = {}
		msg.object = mrandom(11)
		if mrandom(1,100)>=99 then
			msg.money = 2
		else
			msg.money = mrandom(0,1)
		end
		if p.send_msg then
			p:send_msg("server.jqr_yz",msg)
		end
	end
end

--踢掉机器人
local function kick_robot()
	local now_time = os.time()
	for uid,p in pairs(jqr_list) do
		if uid == master then
			return
		end
		if not kick_time[uid] then
			kick_time[uid] = now_time + 60*math.random(5,10)
		end
		if now_time >= kick_time[uid] or (p.gold <= 100000) then
			kick_time[uid] = nil
			jqr_list[uid] = nil
			p.leave =  true
		end
	end
end
-----------------------------------------------------------其他逻辑部分---------------------------------------------

local function probability(a,b)
	-- body
	local x = math.random(1,b)
	if x <= a then
		return true
	else
		return false
	end
end

-- 第一次随机落点
local function randomland(tTheone,nJing)
	local tJing = table.arraycopy(tTheone)
	if not nJing and master ~= nil then
		tremove(tJing, 9)
	elseif nJing == 1 then
		tremove(tJing, 4)
		tremove(tJing, 8)
	elseif nJing == 2 then
		tremove(tJing, 1)
		tremove(tJing, 3)
		tremove(tJing, 7)
	end
	table.random(tJing)
	local sum = 0
	for _,v in pairs(tJing) do
		sum = sum + v.random
	end
	for _,v in pairs(tJing) do
		if probability(v.random,sum) then
			if nJing == 2  or nJing == 3 then
				return v.id
			else
				return v.id[math.random(table.len(v.id))]
			end
		else
			sum = sum - v.random
		end
	end
end

-- 打手枪玩法
local function dashouqiang(tResult)
	local nTime = 0
	local sum = 0
	for _,v in pairs(tTime) do
		sum = sum + v.random
	end
	for k,v in pairs(tTime) do
		if probability(v.random,sum) then
			nTime = v.time
			break
		else
			sum = sum - v.random
		end
	end
	for i = 1 ,nTime do
		tinsert(tResult,randomland(tLand,1))
	end
end

local function histroy_annimal(randomX)
	-- body
	if table.len(tHistory) >= 7 then
		tremove(tHistory,1)
	end
	tinsert(tHistory,randomX)
end

-- 确保表中的值唯一
local function unique(t)
		local check = {}
		local n = {}
		for k, v in pairs(t) do
				if not check[v] then
						n[k] = v
						check[v] = true
				end
		end
		return n
end


-- 判断各个落点的正负
local function result_plus_minus(message)
	local t1 = {{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12}}
	local t3 = {} --押注正负
	local t4 = {} --庄家赢
	local t5 = {} --庄家输
	local total = 0
	for _,v in pairs(message) do
		total = total + v
	end
	for k,result in pairs(t1) do
		for _,v in pairs(result) do
			local t2 = {}
			for m,n in pairs(message) do
				t2[m] = t2[m] or 0
			-- 动物种类判断
				if tJordan[v][1] == m then
					if v == 1 then
						t2[m] = 100 * n
					else
						t2[m] = t2[m] + tMultiple[m] * n
					end
				end
				-- 飞禽走兽判断
				if tJordan[v][2] == m then
					t2[m] = t2[m] + tMultiple[m] * n
				end
			end
			local x = 0
			for _,d in pairs(t2) do
				x = x + d
			end
			t3[k] = x
		end
	end
	t3[4] = total
	t3[10] = 0
	for k in pairs(t3) do
		t3[k] = t3[k] - total
	end
	for k,v in pairs(t3) do
		if v > 0 then
			t4[k] = v
		else
			t5[k] = v
		end
	end
	return t4,t5
end

--控制
local function game_ctrl()
	local tP = {}
	local t = {}
	if next(players) == nil then return end
	for uid,p in pairs(players) do
		if p.ctrlinfo and p.ctrlinfo.ctrltype and next(pour_message[uid]) then
			tinsert(tP,{uid=uid,ctrlinfo=p.ctrlinfo})
		end
	end
	table.sort(tP,function (a,b) return a.ctrlinfo.ctrllevel>b.ctrlinfo.ctrllevel end)
	for i=1,#tP do
		local now_player = tP[i].ctrlinfo
		if now_player.ctrlcount or probability(now_player.ctrlrate,100) then
			local tWin,tLose = result_plus_minus(pour_message[tP[i].uid])
			local t1 = {[1]=tLose,[2]=tWin}
			for k,v in pairs(t1[now_player.ctrltype]) do
				if math.abs(v) <= (now_player.ctrlmaxgold-now_player.ctrlnowgold) then
					for _,n in pairs(tLand) do
						if n.nId == k then
							table.insert(t,n.id[math.random(#n.id)])
						end
					end
					return t
				end
			end
		end
	end
end

-- 随机落点~
local  function game_random()   --随机一个结果发送给客户端
	local sum = 0
	for _,v in pairs(tSpecial) do
		sum = sum + v.random
	end
	for k,v in pairs(tSpecial) do
		if probability(v.random,sum) then
			nNumber = v.number
			break
		else
			sum = sum - v.random
		end
	end

	if nNumber == 1 then
		next_status_time=os_time() + status_time[2][1]
	else
		next_status_time=os_time() + status_time[2][2]
	end
	local tResult = {}
	-- 随机落点
	local randomX=randomland(tLand)
	histroy_annimal(randomX)
	tinsert(tResult,randomX)
	if (randomX == 8 or randomX == 22) then
		nNumber = 1
	end
	if nNumber == 2 then --打手枪玩法
		dashouqiang(tResult)
	elseif nNumber == 3 then --大三元玩法
		table.join(tResult,randomland(tLand,2))
	elseif nNumber == 4 then --大四喜玩法
		table.join(tResult,randomland(tFour,3))
	end
	return tResult,nNumber
end


-- 排序押注玩家列表
local function sort_win()
	tSort = {}
	for uid,v in pairs(win_message) do
		if next(v) then
			local nSorce = 0
			for _,n in pairs(v) do
				nSorce = nSorce + n
			end
			tinsert(tSort,{uid=uid,username = tpourname[uid],win=nSorce})
		end
	end
	table.sort(tSort,function(a,b)  return tonumber(a.win) > tonumber(b.win) end)
	return {tSort[1],tSort[2],tSort[3],tSort[4],tSort[5]}
end

local function pour_win(result,uid)
	for _,v in pairs(result) do
		for m,n in pairs(pour_message[uid]) do
			local win_uid = win_message[uid][m] or 0
		-- 动物种类判断
			if tJordan[v][1] == m then
				if v == 1 then
					win_uid = 100 * n
				else
					win_uid = win_uid + tMultiple[m] * n
				end
			end
			-- 飞禽走兽判断
			if tJordan[v][2] == m then
				win_uid = win_uid + tMultiple[m] * n
			end
			win_message[uid][m] = win_uid
		end
	end
	--PRINT_T(win_message)
end

-- 发钱
local function faqian()
	-- 庄家计算
	local sum_out = 0
	for _,v in pairs(win_message) do
		for _,n in pairs(v) do
			sum_out = sum_out + n
		end
	end
	-- 庄家所得
	banker_payments = total_bet - sum_out
	-- 发钱
	for uid,p in pairs(players) do
		local msg = {}
		--发钱发钱
		if uid == master then
			if banker_payments > 0 then
				if not test_gold then
					p:call_userdata("add_gold", banker_payments, game_id)
					p:call_userdata("add_win", game_id, 1001)
				end
			elseif banker_payments < 0 and not test_gold then
				p:call_userdata("sub_gold", -banker_payments, game_id)
			end
			if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 1 and not p.isrobot then
				p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold - banker_payments
			elseif p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 2 and not p.isrobot then
				p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + banker_payments
			end
			p.gold = p.gold + banker_payments
			msg.WinGold = banker_payments or 0
		else
			if Free_In[uid] > 0 and not test_gold then
				p:call_userdata("add_gold", Free_In[uid], game_id)
			end
			p.gold = p.gold + Free_In[uid]
			msg.WinGold = Free[uid] or 0
		end
		pour_message[uid]={}   --清空下注信息
		msg.BetNot = BetOrNot[uid] or 0
		p:send_msg("game.WinGoldFQZS",msg)
	end
end

-- 玩家盈利计算
local function game_result(result,type,p)
	--下注信息为空直接返回
	local uid = p.uid
	if next(pour_message[uid])==nil then
		BetOrNot[uid] = 0
		return
	else
		BetOrNot[uid] = 1
	end
	if uid ~= master then
		if table.keyof(result,10) then
			for k,v in pairs(pour_message[uid]) do
				win_message[uid][k]=tMultiple[k]*v
			end
		elseif table.keyof(result,4) then
			win_message[uid] =nil
		else
			pour_win(result,uid)
		end
		--PRINT_T(win_message)
		for _,v in pairs(pour_message[uid]) do
			Free_Out[uid] = Free_Out[uid] + v --闲家押注金额
		end
		if win_message[uid] ~= nil then
			for _,v in pairs(win_message[uid]) do
				Free_In[uid] = Free_In[uid] + v --闲家返还金额
			end
			Free[uid] =  Free_In[uid] - Free_Out[uid] --闲家尽利润
		else
			Free[uid] = - Free_Out[uid] --闲家尽利润
		end
		--数据赋值
		if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 1 then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold - Free[uid]
		elseif p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 2 then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + Free[uid]
		end
		if Free[uid] > 0 then
			if not test_gold then
				players[uid]:call_userdata("add_win", game_id, 1001)
			end
		end
	end
end

--人工落点
-- function Artificial(tPosOrNeg)
-- 	local t = {}
-- 	for _,v in pairs(tPosOrNeg) do
-- 		for _,d in pairs(tLand) do
-- 			if d.nId == v then
-- 				table.insert(t,d)
-- 			end
-- 		end
-- 	end
-- 	table.random(t)
-- 	local sum = 0
-- 	for _,v in pairs(t) do
-- 		sum = sum + v.random
-- 	end
-- 	for _,v in pairs(t) do
-- 		if probability(v.random,sum) then
-- 			table.random(v.id)
-- 			return v.id[1]
-- 		else
-- 			sum = sum - v.random
-- 		end
-- 	end
-- end

-- 结果赋值
local function ass_result()
	randomresult,randomtype = game_random()
	--落点动物类型
	local tAnnimal_type = {}
	for k,v in pairs(randomresult) do
		local sumX=1
		for m,w in pairs(weight) do
			sumX = sumX + w
			if v < sumX then
				tinsert(tAnnimal_type,m)
				break
			end
		end
	end
	local result_unique = unique(tAnnimal_type) -- 确保表中的值唯一
	-- 计算每个人的盈亏
	for uid, p in pairs(players) do
		-- 初始化数据
		win_message[uid] = {}
		tpourname[uid] = p.nickname
		Free[uid] = 0
		Free_In[uid] = 0
		Free_Out[uid] = 0
		-- 玩家盈利计算
		game_result(result_unique,randomtype,p)
	end
end

local function report_to_all(tPour,tWin)
	local totalwin = 0
	local totalbet = 0
	for uid,p in pairs(players) do
		if not p.isrobot then
			tWin[uid] = tWin[uid] or 0
			totalwin = totalwin + tWin[uid]
			tPour[uid] = tPour[uid] or 0
			totalbet = totalbet + tPour[uid]
		end
	end
	api_report_gold(totalwin, totalbet)
end

-- 游戏开始，随机落点和玩法
local function game_start()
--PRINT_T(pour_message)
	if game_status==0 then
		--数据赋值
		open_times = 0
		-- 阶段赋值
		game_status = 1
		-- 结果赋值
		::is_return::
		ass_result()
		local tPour,tWin = {},{}
		for uid,pour in pairs(pour_message) do
			for _,v in pairs(pour) do
				tPour[uid] = tPour[uid] or 0
				tPour[uid] = tPour[uid] + v
			end
		end
		for uid,win in pairs(win_message) do
			for _,v in pairs(win) do
				tWin[uid] = tWin[uid] or 0
				tWin[uid] = tWin[uid] + v
			end
		end
		--判断是否开拍
		if not ctrl.check_open(open_times, tPour, tWin) and (not test_gold) then
			open_times = open_times + 1
			goto is_return
		end
		--上报总
		if not test_gold then
			report_to_all(tPour,tWin)
		end
		-- 发钱
		faqian()
		local msg = {}
		msg.Result = randomresult
		msg.Type = randomtype
		msg.tSort = sort_win()
		if master == nil then
			msg.nickname = "骨天乐"
		else
			msg.nickname = players[master].nickname
		end
		msg.bankerpay = banker_payments
		send_to_all("game.ResultFQZS", msg)
	end
end


--发送用户状态
local function send_status()
	local msg = {}
	msg.status = game_status
	msg.time = next_status_time
	-- 发送消息
	send_to_all("game.BRStatusNtf", msg)
end


--游戏初始化
local function game_info()
	for uid,p in pairs(players) do
		win_message[uid] = {}
		pour_message[uid] = {}
		xutou[uid] = true
		if p.leave and p.uid ~= master then
			if table.keyof(banker_users,p.uid) then
				table.removebyvalue(banker_users, p.uid)
			end
			api_kick(p,1003)
		end
	end
	total_pour = {[1] = 0,[2] = 0,[3] = 0,[4] = 0,[5] = 0,[6] = 0,[7] = 0,[8] = 0,[9] = 0,[10] = 0,[11] = 0}
	tclear(randomresult)
	randomtype = 0
	tclear(Free_Out)
	tclear(Free_In)
	tclear(Free)
	tclear(tpourname)
	tclear(BetOrNot)
	tclear(tSort)
	game_status = 0
	total_bet = 0
	banker_payments = 0
	next_status_time=os_time() + status_time[1]
end

-- 机器人抢庄
local function robot_qz()
	if next(jqr_list) then
		for uid,p in pairs(jqr_list) do
			if (master ~= uid) and (not table.keyof(banker_users,uid)) and (p.gold >= minbanker) then
				p:send_msg("server.jqr_qz", {})
				break
			end
		end
	end
end

function keyof(hashtable, value)
    for k, v in pairs(hashtable) do
        if k == value then return true end
    end
    return nil
end

-- 检测预庄玩家金币
local function check_bankeruser_gold()
	if table.len(banker_users) ~= 0 then
		if keyof(players,banker_users[1]) then
			if players[banker_users[1]].gold < minbanker then
				-- LOG_WARNING("钱不够")
				players[banker_users[1]]:send_msg("game.UpDownMasterFQZS",{opt = 3})
				table.removebyvalue(banker_users, banker_users[1])
				return check_bankeruser_gold()
			end
		else
			table.removebyvalue(banker_users, banker_users[1])
		end
	end
end

--发送庄家信息
local function send_master(p,opt)
	local msg = {}
	-- msg.opt = opt
	if master == nil then
		msg.mastername = "骨天乐"
		msg.gold = 999999999
		msg.uid = -1
	else
		msg.mastername = players[master].nickname
		msg.gold =players[master].gold
		msg.uid = master
	end
	if table.len(banker_users) == 0 then
		msg.waitnumber = -1
	else
		msg.waitnumber = table.len(banker_users)
	end
	--发送消息
	send_except("game.UpDownMasterFQZS",msg,p.uid)
	msg.opt = opt
	p:send_msg("game.UpDownMasterFQZS",msg)
end

-- 回合结束，决定庄家
local function WhoIsBanker()
	-- 机器人抢庄
	if table.len(banker_users) < 5 then
		robot_qz()
	end
	--一局结束，判断庄家连庄上限
	if master ~= nil then
		banker[master] = banker[master] + 1
		if ((banker[master] or 10) >= 10) or ((players[master].gold or 0) < minbanker) then
			banker = {}
			send_master(players[master],2)
			master = nil
		end
	end
	-- 判断是否有人排队，如若无人，机器人抢庄
	if master == nil then
		check_bankeruser_gold()
		if table.len(banker_users) ~= 0 then
			master = banker_users[1]
			banker[banker_users[1]] = 0
			table.removebyvalue(banker_users, banker_users[1])
		end
	end
end

--下局游戏
local function Next_game()
	if game_status == 2 then
		if banker[master] == -1 then
			master = nil
		end
		--判断庄家
		WhoIsBanker()
		--初始化
		game_info()
		local msg={}
		if master == nil then
			msg.mastername = "骨天乐"
			msg.gold = 999999999
			msg.lianzhuangshu = 0
			msg.uid = -1
		else
			msg.mastername = players[master].nickname
			msg.gold = players[master].gold
			msg.lianzhuangshu = banker[master]
			msg.uid = master
		end
		if table.len(banker_users) == 0 then
			msg.waitnumber = -1
		else
			msg.waitnumber = table.len(banker_users)
		end
		send_to_all("game.UpDownMasterFQZS",msg)
		local msg = {}
		msg.status = 2
		msg.time = next_status_time
		-- 发送消息
		send_to_all("game.BRStatusNtf", msg)
	end
end


local function send_bet() --发送下注消息
	-- 定时器
	if os_time() - runtime >= 1 then
		--机器人押注
		jqr_total_bet()
		runtime = os_time()
		local msg = {}
		msg.infos = {
		{bets = total_pour,selfbets={}}
		}
		-- PRINT_T(msg)
		send_to_all("game.BRBetNtf",msg)
	end
end


function this.update()   --更新状态
	if config.add_robot and isUseGold then
		check_join_robot()
		kick_robot()
	end
	if next_status_time and next_status_time > 0 then
		if game_status == 0 then --下注阶段
			if qiaodan then
				api_game_start()
				qiaodan = false
				danshuai = true
			end
			send_bet()
			if master == nil then
				check_bankeruser_gold()
				if table.len(banker_users) ~= 0 then
					master = banker_users[1]
					banker[banker_users[1]] = 0
					table.removebyvalue(banker_users, banker_users[1])
				else
					-- 机器人抢庄
					robot_qz()
				end
			end
			if (os_time() >= math.floor(next_status_time - 5)) and (nflag == 0) then
				nflag = 1
				send_status()
			end
			-- 20秒后就开始了
			if os_time() >= next_status_time then
				nflag = 0
				game_start()
			end
		elseif game_status == 1 then
				-- 开始阶段
			if os_time() >= next_status_time then
				game_status = 2
				next_status_time=os_time() + status_time[3]
			end
		elseif game_status == 2 then
			if danshuai then
				api_game_end()
				danshuai = false
				qiaodan = true
			end
			if (os_time() >= math.floor(next_status_time - 1)) and (nflag == 0) then
				nflag = 1
				local msg = {}
				msg.status = 1
				msg.time = next_status_time
				-- 发送消息
				send_to_all("game.BRStatusNtf", msg)
			end
			if os_time() >= next_status_time then
				-- 下一轮
				nflag = 0
				Next_game()
			end
		end
	end
end

--检查座位是否已满;true ->未满
local function checkSeatsFull()
	local c = 0
	for _,v in pairs(players) do
		c = c + 1
	end
	return c >= 100
end

function this.join(p)
	if checkSeatsFull() then
		return false
	end
	if p.isrobot then
		jqr_list[p.uid] = p
	end
	pour_message[p.uid] = pour_message[p.uid] or {}
	win_message[p.uid] = win_message[p.uid] or {}
	BetOrNot[p.uid] = 0
	xutou[p.uid] = true
	p.leave = false
	if test_gold and not p.isrobot then
		p.gold = test_gold
	end
	return true
end


local function send_goldchange(p,gold)
	local ok = true
	-- 减少金币
	if gold + p.gold >= 0 then
		if not test_gold then
			p:call_userdata("sub_gold", -gold, game_id)
		end
	else
		ok = false
	end
	--判断处理
	if ok then
		p.gold = p.gold + gold
	end
	return ok
end

local function ass_userbet(p,pourobject,pourmoney)
	-- body
	local uid = p.uid
	local ishave = {}   --标记是否已经存入这个类型  如果有  改为1
		----PRINT_T(pour_message[uid])
	if (table.len(pour_message[uid]) == 0) then
		-- LOG_DEBUG("第一次下注")
		pour_message[uid][pourobject]=poreqian[pourmoney]
	else
	--不是第一次下注需要判断是在已经下注对象上加注还是新选择目标下注
		for k,v in pairs(pour_message[uid]) do   --对下注对象进行遍历  查看是否对该对象下注
			if k == pourobject then
				ishave[k] = 1        --如果已下注对象有名字和当前对象名字相同  标记状态为1
				pour_message[uid][k] = v + poreqian[pourmoney]    --增加其中的数量
				break
			end
		end
	end
	if ishave[pourobject] == nil then    --检查状态   如果为0 表示不存在  需要重新添加对象
		pour_message[uid][pourobject]=poreqian[pourmoney]
	end
	-- LOG_DEBUG("成功下注")
	last_pour_message[uid] = table.deepcopy(pour_message[uid])
	-- 玩家投注
	total_pour[pourobject] = total_pour[pourobject] or 0
	total_pour[pourobject] = total_pour[pourobject] + poreqian[pourmoney]
	-- --PRINT_T(pour_message)
	total_bet = total_bet + poreqian[pourmoney]
end

--收到信息，发送协议
local function send_userbet(p,pourobject,pourmoney,nIndex)
	local msg = {}
	msg.pos = pourobject
	if nIndex == 1 then
		msg.betgold = - 1
	elseif nIndex == 2 then
		msg.betgold = - 2
	else
		msg.betgold = pourmoney
	end
	msg.gold = p.gold
	--发送消息
	p:send_msg("game.BRBetRep",msg)
 end

local function goldchange(p,pourobject,pourmoney)
	if send_goldchange(p, - poreqian[pourmoney]) then
		--用户押注赋值
		ass_userbet(p,pourobject,pourmoney)
		-- 发送消息
		send_userbet(p,pourobject,pourmoney)
	else
		-- LOG_DEBUG("玩家金币不足")
		send_userbet(p,pourobject,pourmoney,2)
	end
end

-- 拆分上把押注
-- local function anatomy(p,pourobject,pourmoney)
-- 	local b = assert(pourmoney,"pourmoney不存在")
-- 	for _,v in pairs(godv) do
-- 		local a = math.floor(b/v)
-- 		if a > 0 then
-- 			b = b - v*a
-- 			for i = 1,a do
-- 				goldchange(p,pourobject,We1less[v])
-- 			end
-- 		end
-- 	end
-- end

local function Continued_sum(p,pourmoney)
	local uid = p.uid
	if send_goldchange(p, - pourmoney) then
		local msg = {}
		local continueds = {}
		--用户押注赋值
		pour_message[uid] = table.deepcopy(last_pour_message[uid])
		-- 玩家投注
		for k,v in pairs(pour_message[uid]) do
			total_pour[k] = total_pour[k] or 0
			total_pour[k] = total_pour[k] + v
			tinsert(continueds,{pourobject = k,pourmoney = v})
		end
		total_bet = total_bet + pourmoney
		-- 发送消息
		if xutou[p.uid] then
			xutou[uid] = false
			msg.continueds = continueds
			p:send_msg("game.ContinuedFQZS",msg)
		else
			-- LOG_WARNING("你已经续投过了")
		end
	else
		-- LOG_DEBUG("玩家金币不足")
		p:send_msg("game.ContinuedFQZS",{continueds = {{pourobject = 0,pourmoney = -1}}})
	end
end


-- 续押
local function Continued_bet(p)
	-- 下注阶段
	local uid = p.uid
	if uid == master then
		-- LOG_WARNING("庄家不能押注")
		return
	end
	if game_status == 0 and next(pour_message[uid]) == nil then
		if last_pour_message[uid] ~= nil then
			local sum = 0
			for _,v in pairs(last_pour_message[uid]) do
				sum = sum + v
			end
			if p.gold < sum then
				-- LOG_WARNING("并没有这么多钱")
				p:send_msg("game.ContinuedFQZS",{continueds = {{pourobject = 0,pourmoney = -2}}})
				return
			end
			for pourobject,pourmoney in pairs(last_pour_message[uid]) do
				if math.floor(players[master].gold/tRate[pourobject]) < total_pour[pourobject] + pourmoney then
					p:send_msg("game.ContinuedFQZS",{continueds = {{pourobject = 0,pourmoney = -1}}})
					-- LOG_WARNING("押注金额过多")
					return
				end
			end
			Continued_sum(p,sum)
		else
			p:send_msg("game.ContinuedFQZS",{continueds = {{pourobject = 0,pourmoney = -3}}})
			-- LOG_WARNING("上把没有押注")
		end
	end
end

function this.dispatch(p, name, msg)
	local uid = p.uid
	if name=="PourFQZS" then
		if (game_status==0) and (uid ~= master) then               --下注方式只有11中     旋转结果有12种
			-- LOG_DEBUG("下注阶段")
			if poreqian[msg.pourmoney] > p.gold then
				-- LOG_DEBUG("玩家金币不足")
				send_userbet(p,msg.pourobject,msg.pourmoney,2)
				return
			end
				--判断庄家金币不足
			if master ~= nil then
				if math.floor((players[master].gold or 100000000)/tRate[msg.pourobject]) < total_pour[msg.pourobject] + poreqian[msg.pourmoney] then
					send_userbet(p,msg.pourobject,msg.pourmoney,1)
					-- LOG_WARNING("押注金额过多")
					return
				end
			end
			goldchange(p,msg.pourobject,msg.pourmoney)
			return
		end
	elseif name=="UpDownMasterFQZS" then
		if msg.opt == 2 then --下庄
			if uid == master then
				if game_status ~= 0 then
					banker[master] = -1
					send_master(p,msg.opt) --发送庄家信息
					return
				end
				master = nil
				check_bankeruser_gold()
				if table.len(banker_users) ~= 0 then
					master = banker_users[1]
					banker[banker_users[1]] = 0
					table.removebyvalue(banker_users, banker_users[1])
				else
					-- 机器人抢庄
					robot_qz()
				end
			elseif tindexof(banker_users,uid) then
				-- 在庄家列表中，删除
				table.removebyvalue(banker_users, uid)
			else
				-- LOG_WARNING("不是庄家也不在队列~")
			end
		elseif msg.opt == 1 then --上庄
			if tindexof(banker_users, uid) and (uid == master) then
				-- LOG_WARNING("已经在庄家列表了")
				--在庄阶段不能抢庄
				return
			end
			if p.gold < minbanker then
				--钱不够1亿
				-- LOG_WARNING(uid.."钱不够")
				p:send_msg("game.UpDownMasterFQZS",{opt = 3})
				return
			end
			if next(pour_message[uid]) ~= nil then
				-- LOG_WARNING("已经押注了不能上庄")
				return
			end
			tinsert(banker_users,uid)
			if table.len(banker_users) == 1 and master == nil then
				master = banker_users[1]
				banker[banker_users[1]] = 0
				table.removebyvalue(banker_users, banker_users[1])
			end
		end
		send_master(p,msg.opt) --发送庄家信息
	elseif name=="ContinuedFQZS" then
		Continued_bet(p)
	end
end

function this.resume(p,nOnline)
	p.leave = false
	pour_message[p.uid] = pour_message[p.uid] or {}
	win_message[p.uid] = win_message[p.uid] or {}
	--清除数据
	if table.keyof(banker_users,p.uid) then
		table.removebyvalue(banker_users, p.uid)
	end
	last_pour_message[p.uid] = nil
	local msg1={}
	if master == nil then
		msg1.mastername = "骨天乐"
		msg1.gold = 999999999
		msg1.uid = -1
	else
		msg1.mastername = players[master].nickname
		msg1.gold = players[master].gold
		msg1.uid = master
	end
	msg1.lianzhuangshu = banker[master]
	msg1.waitnumber = table.len(banker_users)
	if tindexof(banker_users,p.uid) or (master == p.uid) then
		msg1.opt = 1
	else
		msg1.opt = 2
	end
	p:send_msg("game.UpDownMasterFQZS",msg1)
	p:send_msg("game.HistoryFQZS", {history = tHistory})
	-- 恢复游戏
	local msg = {}
	if nOnline then
		msg.status = game_status
	else
		msg.status = -1
	end
	if last_pour_message[p.uid] ~= nil then
		for i = 1,11 do
			if last_pour_message[p.uid][i] == nil then
				last_pour_message[p.uid][i] = 0
			end
		end
		msg.pourmessage  = {PourGold=last_pour_message[p.uid]}
	end
	msg.Result = randomresult
	msg.tSort = sort_win()
	if master == nil then
		msg.nickname = "骨天乐"
	else
		msg.nickname = players[master].nickname
	end
	msg.bankerpay = banker_payments
	msg.WinGold = Free[p.uid] or 0
	msg.BetNot = BetOrNot[p.uid] or 0
	p:send_msg("game.ResumeFQZS", msg)
end

-- 解散房间
function this.free()

end

--离线调用
function this.offline(p)
	if p.uid ~= master then
		p.leave = true
	end
end

-- 离开房间
function this.leave_game(p)
	--数据赋值
	if p.uid ~= master and (game_status ~= 0 or next(pour_message[p.uid]) == nil) then
		if table.keyof(banker_users,p.uid) then
			table.removebyvalue(banker_users, p.uid)
		end
		last_pour_message[p.uid] = nil
		return true
	else
		return false
	end
end

-- 玩家游戏外造成的金币增减，需要通知到游戏内，进行金币的增减
function this.add_gold(p, gold, reason)
	p.gold = p.gold + gold
	if p.gold < 0 then
		p.gold = 0
	end
	p:send_msg("game.UpdateGoldInGame", {uid=p.uid,goldadd=gold,gold=p.gold})
end

function this.set_kickback(kb)
	ctrl.set_kickback(kb)
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
		gold=tonumber(v.gold) or 0,
		sex = v.sex or 1})
	end
	msg.owner = owner  or 1
	msg.endtime =  0 or endtime
	msg.gameid = gameid
	msg.times = total_times
	msg.playedtimes = played_times
	msg.score = rule_score
	msg.paytype = paytype
	msg.code = code
	msg.players = list
	msg.isGoldGame = isUseGold or 0
	 --   luadump(msg)
	-- p:send_msg("game.TableInfo", msg)
	return msg
end

function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid,usegold ,_, params, kb)
	seats = {}
	players = ps
	isUseGold = usegold
	config = m_conf
	test_gold = m_conf.test_gold
	played_times = 0
	total_times = m_times
	rule_score = m_score
	code = m_code
	endtime = os_time() + m_conf.wait_time
	owner = 0
	gameid = m_gameid
	paytype = m_pay
	gametype = config.init_params
	game_status = 0
	next_status_time=os_time()+status_time[1]
	send_except = api.send_except
	send_to_all = api.send_to_all
	free_table = api.free_table
	api_game_start = api.game_start
	api_game_end = api.game_end
	api_join_robot = api.join_robot
	api_report_gold = api.report_gold
	api_kick = api.kick
	if gametype == 3 then
		-- 固定庄是房间创建者
		master = uid
	end
	--控制器初始化
	ctrl.init(players,kb)

	histroy = {}
	histroy.owner = uid
	histroy.time = os_time()
	histroy.code = code
	histroy.times = total_times
	histroy.gameid = gameid
--  luadump(histroy)
	check_join_robot()
	WhoIsBanker()
end

return this
