local skynet = require "skynet"
local USE_DEBUG = skynet.getenv "use_debug"
local ctrl = require "fqzs_slwh_ctrl"
-------------------森林舞会逻辑部分--------------
local this = {}
local players = {}
local isUseGold --是否金币模式
local played_times
local total_times
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
local player
local game_id = 10006
local open_times --开牌次数(大于10次不做控制)
local test_gold
local field_level

local pour_message={} --本把押注
local last_pour_message={} --上一把押注
local win_message={} --押注所得
local xutou = {} --是否续投
local tPour_Rate --押注倍率
local tColorMsg = {}
local tColor--颜色的位置（红、绿、黄）
local total_pour = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0} --总投注
local tHistory = {{type=1,result={1,1,13}},{type=2,result={2,2,13}},{type=3,result={3,3,13}},{type=4,result={4,4,14}},{type=1,result={5,5,15}}} --历史押注
local game_status --游戏状态，0表示押注阶段,1表示开奖阶段
local next_status_time --切换到下个状态的时间
local status_time={[1]=20,[2]={20,25}}
local randomresult = {} --随机落点
local randomtype = 0 --落点属性
local runtime = 0
local nPool = 0 --彩金池
local nAll_Pour = 0
--次数限制
local jordan = true
--倍率区间(狮子50—25 熊猫*23—12  猴子*13—7 兔子*8—4)
local tRate = {{25,50},{12,23},{7,13},{4,8}}
--玩法种类
local tSpecial= {{number = 1 ,random = 980},{number = 2 ,random = 5},{number = 3 ,random = 10},{number = 4 ,random = 5}}
--发手枪次数概率
local tTime = {{time = 3,random= 60},{time = 4,random= 30},{time = 5,random= 10}}
--庄和闲倍率
local tZhx = {2,8,2}
--颜色的数量
local tColorCount = {
		{11,7,6},{7,11,6},{10,8,6},{8,10,6},{6,11,7},{11,6,7},
		{9,8,7},{8,9,7},{6,10,8},{10,6,8},{9,7,8},{7,9,8},
		{7,8,9},{8,7,9},{6,8,10},{8,6,10},{7,6,11},{6,7,11}
}
--动物的倍率
local tAnimalMulity = {
{colorcount=6,mulity={46,23,13,8}},{colorcount=7,mulity={40,20,11,7}},{colorcount=8,mulity={35,17,10,6}},
{colorcount=9,mulity={31,15,8,5}},{colorcount=10,mulity={28,14,8,5}},{colorcount=11,mulity={25,12,7,4}}
}
--动物的位置（狮子、熊猫、猴子、兔子）
local tAnimal = {{4,11,16,23},{8,12,20,24},{1,3,6,10,14,18,22},{2,5,7,9,13,15,17,19,21}}
local tRegulation = {} --调教play
------------------------------------
local send_to_all
local send_except
local api_game_start
local api_game_end
local api_join_robot
local api_kick
local api_report_gold
------------------------------------
-- 机器人数据
local jqr_list = {}
local kick_time = {}
local next_time = 0
------------------------------------------------------------机器人控制-----------------------------------------------------
--获取机器人
local function check_join_robot()
	local mingold = 10000
	if table.len(jqr_list) >= 20 then
		return
	end
	if os_time() >= next_time then
		next_time = os_time() + 10
		local gold = math.random(mingold, mingold*10)
		api_join_robot("slwh", gold)
	end
end

--机器人押注
-- local function jqr_total_bet(pourobject,pourmoney)
local function jqr_total_bet()
	local t = {100,500,1000,5000,10000}
	if test_gold then field_level = 10000 end
	for uid,p in pairs(jqr_list) do
		local msg = {}
		msg.object = mrandom(15)
		if mrandom(1,100)>=99 then
			msg.money = t[3] * (field_level/100)
		else
			msg.money = t[mrandom(1,2)] * (field_level/100)
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
		if not kick_time[uid] then
			kick_time[uid] = now_time + 60*math.random(5,10)
		end
		if now_time >= kick_time[uid] or (p.gold <= 100) then
			kick_time[uid] = nil
			jqr_list[uid] = nil
			p.leave = true
		end
	end
end

----------------------------------逻辑部分----------------------------------
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

--该阶段可以出现的所有落点情况
local function WhereAmI(msg)
	for k,v in pairs(tAnimal) do
		for m,n in pairs(v) do
			tAnimal[k][m]=n+msg.result[2]-msg.result[1]
			if tAnimal[k][m]>24 then
				tAnimal[k][m] = tAnimal[k][m]-24
			end
			if tAnimal[k][m] == 0 then
				tAnimal[k][m]=24
			end
		end
	end
	local t = {}
	for k,v in pairs(tAnimal)do
		for _,n in pairs(v) do
			t[n]=k*10
		end
	end
	local tt = {}
	for i=1,24 do
		tinsert(tt,(t[i]+tColorMsg[i]))
	end
	tt = unique(tt)
	local t = {}
	for k,v in pairs(tt) do
		local a,b=v%10,math.floor(v/10)
		local c = 3*(b-1)+a
		t[k] = c
	end
	return t
end

local function pos_update()
	-- body
	local tHowColor = table.deepcopy(tColorCount[mrandom(1,18)])
	local tPosition = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24}
	local ttt = {1,2,3}
	--颜色位置
	local t1 = {}
	for k,v in pairs(tHowColor) do
		for i=1,v do
			table.random(tPosition)
			t1[k] = t1[k] or {}
			table.insert(t1[k],table.remove(tPosition,1))
		end
	end
	for _,v in pairs(t1)do
		table.sort(v)
	end
	--动物赔率
	local t2 = {}
	local t3 = {}
	for k,v in pairs(tHowColor) do
		for m,n in pairs(tAnimalMulity) do
			if n.colorcount == v then
				t2[k] = table.deepcopy(n.mulity)
			end
		end
	end
	for k,v in pairs(ttt) do
		for i=v,12,3 do
			t3[i]=t2[k][math.floor((i-1)/3)+1]
		end
	end
	table.join(t3,tZhx)
	return t1,t3
end

local function probability(a,b)
	-- body
	local x = math.random(1,b)
	if x <= a then
		return true
	else
		return false
	end
end

-- 历史落点
local function histroy_annimal(Result,nNumber)
	-- body
	if table.len(tHistory) >= 7 then
		tremove(tHistory,1)
	end
	local t = {}
	t.type = nNumber
	t.result = table.deepcopy(Result)
	tinsert(tHistory,t)
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
	local t1 = {1,2,3,4,5,6,7,8,9,10,11,12}
	local t2 = {}
	local t3 = {}
	for i=1,nTime do
		tinsert(t2,table.remove(t1,mrandom(1,#t1)))
	end
	for k,v in pairs(t2) do
		local nAin = math.floor((v-1)/3)+1
		local nCol = v%3
		if nCol == 0 then nCol = 3 end
		t3[1+(k-1)*2]=tAnimal[nAin][mrandom(#tAnimal[nAin])]
		for j,d in pairs(tColorMsg) do
			if d == nCol then
				t3[2+(k-1)*2]=j
				break
			end
		end
	end
	table.join(tResult,t3)
	return tResult
end

--彩金
local function ColorGold()
	--彩金池玩法
	for uid,pour in pairs(pour_message) do
		for k,v in pairs(pour) do
			nPool = nPool + v
		end
	end
	nPool = math.floor(nPool/10) --彩金池
	local nColorAnimal = math.random(1,12)
	for uid,pour in pairs(pour_message) do
		if pour[nColorAnimal] then
			nAll_Pour = nAll_Pour + pour[nColorAnimal]
		end
	end
	return nColorAnimal
end

-- 随机落点~
local  function game_random()   --随机一个结果发送给客户端
	-- 正常玩法
	local sum = 0
	local nNumber
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
	local tResult = {}
	-- 随机落点
	local randomX,randomY,randomZ = mrandom(1,24),mrandom(1,24),mrandom(13,15)
	tinsert(tResult,randomX)
	tinsert(tResult,randomY)
	tinsert(tResult,randomZ)
	if nNumber == 1 then
		local nColorAnimal = ColorGold()
		tinsert(tResult,nColorAnimal)
	end
	if nNumber == 4 then --打手枪玩法
		tResult = dashouqiang(tResult)
	end
	return tResult,nNumber
end

--发送全局下注消息
local function send_global_bet()
	-- 定时器
	if os_time() - runtime >= 2 then
				--机器人押注
		jqr_total_bet()
		runtime = os_time()
		local msg = {}
		msg.bets = total_pour
		send_to_all("game.SecondSLWH",msg)
	end
end


local function faqian(tPour)
	--押注金额
	for uid,p in pairs(players) do
		local sum = tPour[uid] or 0
		--加钱
		if not test_gold then
			p:call_userdata("add_gold", win_message[uid], game_id)
		end
		p.gold=p.gold + win_message[uid]
		if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 1 and not p.isrobot then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold - math.abs(win_message[uid]-sum)
		elseif p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 2 and not p.isrobot then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + math.abs(win_message[uid]-sum)
		end
		pour_message[uid]={}   --清空下注信息
		local msg = {}
		msg.type = randomtype
		msg.result = randomresult
		msg.huode = win_message[uid]
		msg.xiazhu = sum
		p:send_msg("game.ResultSLWH", msg)
	end
end

-- 玩家盈利计算
local function game_result(result,type,p)
	--tPour_Rate
	local uid = p.uid
	local real_result={}
	local x,y,z
	for i=1,4 do
		if table.indexof(tAnimal[i],result[1]) then
			x=i
		end
	end
	for i=1,3 do
		if table.indexof(tColor[i],result[2]) then
			y=i
		end
	end
	z = 3*(x-1)+y
	local t = {z,result[3]} --落点真实信息
	if type == 1 then
		if pour_message[uid][result[4]] then
			--彩金计算
			local nPoolWin = math.floor((pour_message[uid][result[4]]/nAll_Pour)*nPool)
			win_message[uid] = win_message[uid] + nPoolWin
		end
		real_result = table.deepcopy(t)
	else
		if type == 2 then
			local t1={{1,2,3},{4,5,6},{7,8,9},{10,11,12}}
			table.join(t,t1[x])
		elseif type == 3 then
			for i=1,4 do
				tinsert(t,3*(i-1)+y)
			end
		elseif type == 4 then
			for k=4,#result,2 do
				local a,b,c
				for i=1,4 do
					if table.indexof(tAnimal[i],result[k]) then
						a=i
					end
				end
				for i=1,3 do
					if table.indexof(tColor[i],result[k+1]) then
						b=i
					end
				end
				c = 3*(a-1)+b
				tinsert(t,c)
			end
		end
		real_result = unique(t)
	end
	--输赢计算
	if next(real_result) then
		for _,v in pairs(real_result) do
			if pour_message[uid][v] then
				win_message[uid] = win_message[uid] + pour_message[uid][v]*tPour_Rate[v]
			end
		end
	end
end
--[[
-- 判断各个落点的正负
local function result_plus_minus(message)
	local t1 = {{1,2,3,4,5,6,7,8,9,10,11,12},{13,14,15}}
	local t3 = {} --赢的表
	local total = {}
	local nPour = 0
	for k,v in pairs(message) do
		nPour=nPour+v
	end
	for i=1,12 do
		if message[i] then
			total[1] = total[1] or 0
			total[1] = total[1]+message[i]
		end
	end
	for i=13,15 do
		if message[i] then
			total[2] = total[2] or 0
			total[2] = total[2]+message[i]
		end
	end
	for m,n in pairs(t1)do
		for _,j in pairs(n) do
			for _,v in pairs(message) do
				if message[j] then
					t3[m] = t3[m] or {}
					t3[m][j] = v*(tPour_Rate[j]-1)
				end
			end
		end
	end
	local tAll_Pour = {}
	for _,v in pairs(t1[1]) do
		for uid,pour in pairs(pour_message) do
			if pour[v] then
				tAll_Pour[v] = tAll_Pour[v] or 0
				tAll_Pour[v] = tAll_Pour[v] + pour[v]
			end
		end
	end
	for i=1,12 do
		if message[i] then
			t3[3] = t3[3] or {}
			t3[3][i] = math.floor((message[i]/tAll_Pour[i])*nPool)
		end
	end
	local jordan = {}
	for i=1,12 do
		for j=13,15 do
			for l=1,12 do
				if not t3[1][i] then t3[1][i] = 0 end
				if not t3[2][j] then t3[2][j] = 0 end
				if not t3[3][l] then t3[3][l] = 0 end
				jordan[i.."+"..j.."+"..l]=t3[1][i]+t3[2][j]+t3[3][l]
			end
		end
	end
	for k,v in pairs(jordan) do
		jordan[k] = jordan[k] - nPour
	end
	return jordan
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
			local tWinOrLose = result_plus_minus(pour_message[tP[i].uid])
			local collocation
			for k,v in pairs(tWinOrLose) do
				if (now_player.ctrltype == 1 and v<0 and math.abs(v) <= (now_player.ctrlmaxgold-now_player.ctrlnowgold)) or
					(now_player.ctrltype == 2 and v>0 and math.abs(v) <= (now_player.ctrlmaxgold-now_player.ctrlnowgold)) then
					collocation = k
					break
				end
			end
			local result = collocation:split("+")
			for i=1,#result do
				result[i]=tonumber(result[i])
			end
			local nAin = math.floor((result[1]-1)/3)+1
			local nCol = result[1]%3
			if nCol == 0 then nCol = 3 end
			t[1]=tAnimal[nAin][mrandom(#tAnimal[nAin])]
			for j,d in pairs(tColorMsg) do
				if d == nCol then
					t[2]=j
					break
				end
			end
			t[3],t[4]=result[2],result[3]
			return t
		end
	end
end
]]--
--游戏阶段和剩余时间
local function game_time()
	local msg = {}
	msg.status = game_status
	msg.time = next_status_time - os_time()
	-- 发送消息
	send_to_all("game.StatusSLWH", msg)
end

-- 结果赋值
local function ass_result()
	if next(tRegulation) then
		randomresult,randomtype = tRegulation.result,tRegulation.type
		tclear(tRegulation)
	else
		randomresult,randomtype = game_random()
	end
	-- 计算每个人的盈亏
	for uid, p in pairs(players) do
		if next(pour_message[uid]) then
			last_pour_message[uid] = table.deepcopy(pour_message[uid])
		end
		-- 初始化数据
		win_message[uid] = 0
		-- 玩家盈利计算
		game_result(randomresult,randomtype,p)
		-- 发送结算协议
	end
end

local function report_to_all(tPour)
	local totalwin = 0
	local totalbet = 0
	for uid,p in pairs(players) do
		if not p.isrobot then
			totalwin = totalwin + win_message[uid]
			tPour[uid] = tPour[uid] or 0
			totalbet = totalbet + tPour[uid]
		end
	end
	api_report_gold(totalbet, totalwin)
end

-- 游戏开始，随机落点和玩法
local function game_start()
	if game_status==0 then
		--数据赋值
		open_times = 0
		-- 阶段赋值
		game_status = 1
		-- 结果赋值
		::is_return::
		ass_result()
		local tPour = {}
		for uid,pour in pairs(pour_message) do
			for _,v in pairs(pour) do
				tPour[uid] = tPour[uid] or 0
				tPour[uid] = tPour[uid] + v
			end
		end
		--判断是否开拍
		if not ctrl.check_open(open_times, tPour, win_message) and (not test_gold) then
			open_times = open_times + 1
			goto is_return
		end
		-- 阶段时间
		if randomtype == 4 then
			next_status_time=os_time() + status_time[2][2]
		else
			next_status_time=os_time() + status_time[2][1]
		end
		--历史记录
		histroy_annimal(randomresult,randomtype)
		--游戏阶段和剩余时间
		game_time()
		--上报总
		if not test_gold then
			report_to_all(tPour)
		end
		-- 发钱
		faqian(tPour)
	end
end

--押注成功，记录数据
local function ass_userbet(p,pourobject,pourmoney)
	local uid = p.uid
	local ishave = {}   --标记是否已经存入这个类型  如果有  改为1
	if (table.len(pour_message[uid]) == 0) then
		pour_message[uid][pourobject]=pourmoney
	else
	--不是第一次下注需要判断是在已经下注对象上加注还是新选择目标下注
		for k,v in pairs(pour_message[uid]) do   --对下注对象进行遍历  查看是否对该对象下注
			if k == pourobject then
				ishave[k] = 1        --如果已下注对象有名字和当前对象名字相同  标记状态为1
				pour_message[uid][k] = v + pourmoney    --增加其中的数量
				break
			end
		end
	end
	if ishave[pourobject] == nil then    --检查状态   如果为0 表示不存在  需要重新添加对象
		pour_message[uid][pourobject]=pourmoney
	end
	-- last_pour_message[uid] = table.deepcopy(pour_message[uid])
	-- 玩家投注
	total_pour[pourobject] = total_pour[pourobject] or 0
	total_pour[pourobject] = total_pour[pourobject] + pourmoney
end

--押注金币检测
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
		p:send_msg("game.BRBetRep", {pos=0,betgold=0,gold =p.gold})
	end
	return ok
end

--收到信息，发送协议
local function send_userbet(p,pourobject,pourmoney,nIndex)
	local msg = {}
	msg.pourobject = pourobject
	msg.pourmoney = pourmoney
	msg.type = nIndex
	--发送消息
	p:send_msg("game.PourSLWH",msg)
 end

local function goldchange(p,pourobject,pourmoney)
	if send_goldchange(p,-pourmoney) then
		--用户押注赋值
		ass_userbet(p,pourobject,pourmoney)
		-- 发送消息
		send_userbet(p,pourobject,pourmoney,1)
	else
		-- LOG_DEBUG("玩家金币不足")
		send_userbet(p,pourobject,pourmoney,2)
	end
end

-- 续押
local function Continued_bet(p)
	local uid = p.uid
	if game_status == 0 then
		local msg = {}
		if last_pour_message[uid] ~= nil then
			local sum = 0
			for _,v in pairs(last_pour_message[uid]) do
				sum = sum + v
			end
			if xutou[uid] then --是否续投过
				if send_goldchange(p,-sum) then
					local t = {}
					--用户押注赋值
					pour_message[uid] = table.deepcopy(last_pour_message[uid])
					-- 玩家投注
					for k,v in pairs(pour_message[uid]) do
						total_pour[k] = total_pour[k] or 0
						total_pour[k] = total_pour[k] + v
						tinsert(t,{pourobject = k,pourmoney = v})
					end
					msg.continueds = t
					msg.type = 1
					p:send_msg("game.ContinuedSLWH",msg)
					-- LOG_WARNING(uid.."续投成功~")
					xutou[uid] = false
				else
					msg.type = 4
					p:send_msg("game.ContinuedSLWH",msg)
					-- LOG_DEBUG("玩家金币不足")
				end
			else
				msg.type = 2
				p:send_msg("game.ContinuedSLWH",msg)
				-- LOG_WARNING("你已经续投过了")
			end
		else
			msg.type = 3
			p:send_msg("game.ContinuedSLWH",msg)
			-- LOG_WARNING("上把没有押注")
		end
	end
end

--取消押注
local function Cancel_bet(p)
	-- body
	local msg = {}
	if next(pour_message[p.uid]) or not pour_message[p.uid] then
		for k,v in pairs(pour_message[p.uid]) do
			total_pour[k]=total_pour[k]-v
			if not test_gold then
				p:call_userdata("add_gold",v, game_id)
			end
			p.gold = p.gold + v
			p:send_msg("game.BRBetRep", {pos=0,betgold=0,gold =p.gold})
		end
		pour_message[p.uid] = {}
		xutou[p.uid] = true
		msg.type=1
	else
		msg.type=2
	end
	p:send_msg("game.CancelSLWH",msg)
end

--检查座位是否已满;true ->未满
local function checkSeatsFull()
	local c = 0
	for _,v in pairs(players) do
		c = c + 1
	end
	return c >= 100
end

--游戏初始化
local function game_info()
	for uid,p in pairs(players) do
		win_message[uid] = 0
		pour_message[uid] = {}
		xutou[uid] = true
		p:send_msg("game.BRBetRep", {pos=0,betgold=0,gold =p.gold})
		if p.leave then
			api_kick(p,1003)
		end
	end
	total_pour = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}
	tclear(randomresult)
	tclear(tPour_Rate)
	tclear(tColorMsg)
	randomtype = 0
	game_status = 0
	nAll_Pour = 0
	nPool = 0
	next_status_time=os_time() + status_time[1]
end

--下局游戏
local function Next_game()
	if game_status == 1 then
		--初始化
		game_info()
		--游戏阶段和剩余时间
		game_time()
	end
end

--调教play
local function Regulation_play(msg)
	if msg and game_status == 0 then
		tclear(tRegulation)
		local t = {}
		local t1 = {}
		local nAin = math.floor((msg.result[1]-1)/3)+1
		local nCol = msg.result[1]%3
		if nCol == 0 then nCol = 3 end
		t[1]=tAnimal[nAin][mrandom(#tAnimal[nAin])]
		for j,d in pairs(tColorMsg) do
			if d == nCol then
				t[2]=j
				break
			end
		end
		tinsert(t,msg.result[2])
		if msg.type == 1 then
			tinsert(t,msg.result[3])
		end
		if msg.type == 4 then 
			for i=4,#msg.result do
				if msg.result[i] > 12 then 
					LOG_WARNING("客户端别乱发东西！！！"..msg.result[i])
					return 
				end
				local nAin = math.floor((msg.result[i]-1)/3)+1
				local nCol = msg.result[i]%3
				if nCol == 0 then nCol = 3 end
				t1[1+(i-4)*2]=tAnimal[nAin][mrandom(#tAnimal[nAin])]
				for j,d in pairs(tColorMsg) do
					if d == nCol then
						t1[2+(i-4)*2]=j
						break
					end
				end
			end
		end
		table.join(t,t1)
		tRegulation.type= msg.type
		tRegulation.result = table.deepcopy(t)
	end
end

-- 计时器
function this.update()   --更新状态
	if config.add_robot and isUseGold then
		check_join_robot()
		kick_robot()
	end
	if next_status_time and next_status_time > 0 then
		if game_status == 0 then --下注阶段
			if jordan then
				api_game_start() --游戏开始
				--发送倍率
				-- random_rate()
				tColor,tPour_Rate = pos_update()
				for k,v in pairs(tColor) do
					for _,n in pairs(v) do
						tColorMsg[n]=k
					end
				end
				local msg = {}
				msg.rates = tPour_Rate
				msg.color = tColorMsg
				send_to_all("game.BetRateSLWH",msg)
				jordan = false
			end
			send_global_bet() --发送全局下注消息
			-- 进入开奖阶段
			if os_time() >= next_status_time then
				--游戏开始
				game_start()
			end
		elseif game_status == 1 then
			if not jordan then
				api_game_end() --游戏结束
				jordan = true
			end
			-- 进入下一局游戏
			if os_time() >= next_status_time then
				Next_game()
			end
		end
	end
end

-- 进入房间
function this.join(p)
	if checkSeatsFull() then
		return false
	end
	if p.isrobot then
		jqr_list[p.uid] = p
	end
	pour_message[p.uid] = pour_message[p.uid] or {}
	win_message[p.uid] = win_message[p.uid] or 0
	xutou[p.uid] = true
	p.leave = false
	if test_gold and not p.isrobot then
		p.gold = test_gold
	end
	return true
end

--接受客户端消息
function this.dispatch(p, name, msg)
	local uid = p.uid
	if (game_status==0) then
		if name=="PourSLWH" then  --下注阶段
			-- 判断玩家金币足不足
			goldchange(p,msg.pourobject,msg.pourmoney)
		elseif name=="ContinuedSLWH" then  --续投
			Continued_bet(p)
		elseif name=="CancelSLWH" then  --取消
			Cancel_bet(p)
		elseif name=="ResultSLWH" then --调控
			if USE_DEBUG == "0" then
				Regulation_play(msg)
			end
		end
	end
end

--断线重连
function this.resume(p,nOnline)
	p.leave = false
	pour_message[p.uid] = pour_message[p.uid] or {}
	win_message[p.uid] = win_message[p.uid] or 0
	--发送倍率
	local msg = {}
	msg.rates = tPour_Rate
	msg.color = tColorMsg
	p:send_msg("game.BetRateSLWH",msg)  
	--发送游戏阶段
	local msg = {}
	msg.status = game_status
	msg.time = next_status_time - os_time()
	-- 发送消息
	p:send_msg("game.StatusSLWH", msg)
	--发送历史落点
	p:send_msg("game.HistorySLWH", {History = tHistory})
	-- 恢复游戏
	local sum = 0
	if last_pour_message[p.uid] ~= nil then
		for i = 1,15 do
			if last_pour_message[p.uid][i] == nil then
				last_pour_message[p.uid][i] = 0
			end
		end
		for k,v in pairs(last_pour_message[p.uid]) do
			sum = sum + v
		end
	end
	local msg = {}
	if nOnline then
		msg.status = game_status
	else
		msg.status = -1
	end
	msg.pourmessage  = {pourGold=last_pour_message[p.uid]}
	msg.result = randomresult
	msg.huode = win_message[p.uid] or 0
	msg.xiazhu = sum or 0
	p:send_msg("game.ResumeSLWH", msg)
end

-- 离开房间
function this.leave_game(p)
	--数据赋值
	if next(pour_message[p.uid]) == nil then
		last_pour_message[p.uid] = nil
	end
	return true
end

-- 解散房间
function this.free()

end

--控制器
function this.set_kickback(kb,sysearn)
	ctrl.set_kickback(kb,sysearn)
end

-- 玩家游戏外造成的金币增减，需要通知到游戏内，进行金币的增减
function this.add_gold(p, gold, reason)
	p.gold = p.gold + gold
	p:send_msg("game.BRBetRep", {pos=0,betgold=0,gold =p.gold})
	if p.gold < 0 then
		p.gold = 0
	end
	p:send_msg("game.UpdateGoldInGame", {uid=p.uid,goldadd=gold,gold=p.gold})
end

-- 发送房间信息
function this.get_tableinfo(p)
	local msg = {}
	local list = {}
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
	return msg
end

--离线调用
function this.offline(p)
	p.leave = true
end

--房间初始化
function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid,usegold, _, params, kb)
	seats = {}
	players = ps
	isUseGold = usegold
	config = m_conf
	field_level = m_conf.min_gold or 0
	played_times = 0
	total_times = m_times
	rule_score = m_score
	code = m_code
	endtime = os_time() + m_conf.wait_time
	owner = 0
	gameid = m_gameid
	paytype = m_pay
	gametype = config.init_params
	test_gold = config.test_gold
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
	-- check_join_robot()
end

return this