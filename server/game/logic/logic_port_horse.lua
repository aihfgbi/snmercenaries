local ctrl = require "fqzs_slwh_ctrl"
-------------------港式跑马逻辑部分--------------
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
local game_id = 10007
local game_status --游戏状态，0表示押注阶段,1表示开奖阶段
local next_status_time --切换到下个状态的时间
local status_time={[1]=30,[2]={50,25}}
local pour_message={} --本把押注
local last_pour_message={} --上一把押注
local restore_message = {}
local win_message={} --押注所得
-- local xutou = {} --是否续投
local fuyuan = {} --是否能复原
local tPour_Rate
local test_gold

--次数限制
local jordan = true
--玩法种类
local tSpecial= {{number=1,random=980},{number=2,random=10},{number=3,random=10}}
--随机落点
local randomresult = {} 
--随机生成的跑道
local tRunway = {} 
--落点属性
local randomtype = 0 

local total_pour = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0} --总投注
local tHistory = {{type=1,result={1,2,1000}},{type=2,result={2,3,500}},{type=3,result={3,4,250}},
{type=1,result={4,5,175}},{type=1,result={5,6,80}}} --历史押注

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
local runtime = 0
------------------------------------------------------------机器人控制-----------------------------------------------------
--获取机器人
local function check_join_robot()
	local mingold = 10000
	if table.len(jqr_list) >= 0 then
		return
	end
	if os_time() >= next_time then
		next_time = os_time() + 10
		local gold = math.random(mingold, mingold*10)
		api_join_robot("port_horse", gold)
	end
end

--机器人押注
-- local function jqr_total_bet(pourobject,pourmoney)
local function jqr_total_bet()
	for uid,p in pairs(jqr_list) do
		local msg = {}
		msg.object = mrandom(15)
		if mrandom(1,100)>=80 then
			msg.money = 10
		else
			msg.money = 1
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

local function probability(a,b)
	-- body
	local x = math.random(1,b)
	if x <= a then
		return true
	else
		return false
	end
end

local function History_bet(p)
	--发送历史落点
	p:send_msg("game.HistoryHORSE", {History = tHistory})
end

-- 历史落点

local function histroy_annimal(nJieguo)
	-- body
	if table.len(tHistory) >= 5 then
		tremove(tHistory,1)
	end
	local t = {}
	t.type = randomtype
	t.result = {randomresult[1],randomresult[2],tPour_Rate[nJieguo]}
	tinsert(tHistory,t)
end

--游戏阶段和剩余时间
local function game_time()
	local msg = {}
	msg.status = game_status
	msg.time = next_status_time - os_time()
	-- 发送消息
	send_to_all("game.StatusHORSE", msg)
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
		send_to_all("game.SecondHORSE",msg)
	end
end

local function faqian(tPour)
	--押注金额
	for uid,p in pairs(players) do
		--加钱
		if not test_gold then
			p:call_userdata("add_gold", win_message[uid], game_id)
		end
		p.gold=p.gold + win_message[uid]
		if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 1 and not p.isrobot then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold - math.abs(win_message[uid]-tPour[uid])
		elseif p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 2 and not p.isrobot then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + math.abs(win_message[uid]-tPour[uid])
		end
		local msg = {}
		msg.type = randomtype
		msg.result = tRunway
		msg.huode = win_message[uid]
		msg.xiazhu = pour_message[uid] or {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}
		msg.totalpour = total_pour
		PRINT_T(msg)
		p:send_msg("game.ResultHORSE", msg)
		pour_message[uid]={[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}   --清空下注信息
	end
end

-- 玩家盈利计算
local function game_result(nJieguo,p)
	local uid = p.uid
	if randomtype == 1 then
		if pour_message[uid][nJieguo] then
			win_message[uid] = pour_message[uid][nJieguo]*tPour_Rate[nJieguo]*100
		end
	end
end

-- 随机落点~
local  function game_random()   --随机一个结果发送给客户端
	-- 正常玩法
	local nNumber
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
	-- 跑马名次
	--生成跑道数据
	local t = {}
	local firstX = 1400
	local first = 2400
	local secondX = 100
	local second = 300
	-- local t1 = {1,2,3,4,5,6}
	-- table.random(t1)
	local t2 = {1,2,3,4,5,6}
	table.random(t2)
	--第一到第二组数据
	for _,v in ipairs(t2) do
		firstX = mrandom(firstX+100,first)
		first = first + 100
		second = mrandom(secondX,second - 10)
		secondX = secondX - 10
		t[1] = t[1] or {}
		t[2] = t[2] or {}
		t[1][v] = firstX
		t[2][v] = second
	end
	-- PRINT_T(t3)
	local t4 = {}
	local mid_x = 90
	local mid_y = 120
	for _,v in ipairs(t2) do
		mid_y = mrandom(mid_x,mid_y-6)
		mid_x = mid_x - 6
		t4[v] = {}
		t4[v].min = math.ceil((mid_y-20)/5)
		t4[v].max = (math.floor(mid_y/5) > 20 and 20) or math.floor(mid_y/5)
		t4[v].sum = mid_y
	end
	for _,v in pairs(t2) do
		for i=3,7 do
			t[i] = t[i] or {}
			local speed = mrandom(t4[v].min,t4[v].max)
			t4[v].sum = t4[v].sum - speed
			t[i][v] = speed
		end
	end
	for _,v in pairs(t2) do
		t[8] = t[8] or {}
		t[8][v] = t4[v].sum
	end
	--合并数据
	local t3 = {}
	table.join(t3,t2)
	for _,v in ipairs(t) do
		table.join(t3,v)
	end
	return t2,nNumber,t3
end

-- 结果赋值
local function ass_result()
	randomresult,randomtype,tRunway = game_random()
	--前两名的号码
	local real_result={randomresult[1],randomresult[2]}
	--排序
	table.sort(real_result)
	--结果对应的押注码
	local tSum = {0,5,9,12,14}
	local nJieguo = tSum[real_result[1]] + real_result[2] - real_result[1]
	--历史记录
	histroy_annimal(nJieguo)
	-- 计算每个人的盈亏
	for uid, p in pairs(players) do
		local sum = 0
		for _,v in pairs(pour_message[uid]) do
			sum = sum + v
		end
		if sum > 0 then
			last_pour_message[uid] = table.deepcopy(pour_message[uid])
		end
		-- 初始化数据
		win_message[uid] = 0
		-- 玩家盈利计算
		game_result(nJieguo,p)
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
		next_status_time=os_time() + status_time[2][1]
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
	-- 玩家个人押注数据
	pour_message[p.uid][pourobject] = pour_message[p.uid][pourobject] or 0
	pour_message[p.uid][pourobject] = pour_message[p.uid][pourobject] + pourmoney
	-- 全局投注数据
	total_pour[pourobject] = total_pour[pourobject] or 0
	total_pour[pourobject] = total_pour[pourobject] + pourmoney
end

--押注金币检测
local function send_goldchange(p,gold)
	local ok = true
	gold = gold * 100
	-- 减少金币
	if gold + p.gold >= 0 then
		if not test_gold then
			p:call_userdata("sub_gold", -gold, game_id)
		end
		p.gold = p.gold + gold
	else
		ok = false
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
	p:send_msg("game.PourHORSE",msg)
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
	if game_status ~= 0 then
		--不在押注阶段返回
		return
	end
	local msg = {}
	--是否续投过
	-- if xutou[uid] then 
		-- 押注金额
	local sum = 0
	if last_pour_message[uid] ~= nil then
		for _,v in pairs(last_pour_message[uid]) do
			sum = sum + v
		end
		if sum <= 0 then
			msg.type = 3
			p:send_msg("game.ContinuedHORSE",msg)
			-- LOG_WARNING(uid.."上把没有押注")
			return
		end
	else
		msg.type = 3
		p:send_msg("game.ContinuedHORSE",msg)
		-- LOG_WARNING(uid.."上把没有押注")
		return
	end
	-- 判断钱
	if send_goldchange(p,-sum) then
		--用户押注赋值
		for k,v in pairs(last_pour_message[uid]) do
			pour_message[uid][k] = pour_message[uid][k] + v
		end
		-- 玩家投注
		local t = {}
		for k,v in pairs(last_pour_message[uid]) do
			total_pour[k] = total_pour[k] or 0
			total_pour[k] = total_pour[k] + v
			tinsert(t,{pourobject = k,pourmoney = v})
		end
		msg.continueds = t
		msg.type = 1
		p:send_msg("game.ContinuedHORSE",msg)
		-- LOG_WARNING(uid.."续投成功~"..sum)
		-- xutou[uid] = false
	else
		msg.type = 4
		p:send_msg("game.ContinuedHORSE",msg)
		-- LOG_DEBUG(uid.."玩家金币不足")
	end
	-- else
	-- 	msg.type = 2
	-- 	p:send_msg("game.ContinuedHORSE",msg)
	-- 	LOG_WARNING(uid.."你已经续投过了")
	-- end
end

--取消押注
local function Cancel_bet(p)
	-- body
	local msg = {}
	local sum = 0
	for _,v in pairs(pour_message[p.uid]) do
		sum = sum + v
	end
	if sum > 0 then
		for k,v in pairs(pour_message[p.uid]) do
			total_pour[k]=total_pour[k]-v
			if not test_gold then
				p:call_userdata("add_gold",v, game_id)
			end
			p.gold = p.gold + v*100
		end
			-- 复原数据赋值
		restore_message[p.uid] = table.deepcopy(pour_message[p.uid])
		pour_message[p.uid] = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}
		-- xutou[p.uid] = true
		fuyuan[p.uid] = true
		msg.type=1
	else
		msg.type=2
	end
	p:send_msg("game.CancelHORSE",msg)
end

-- 复原
local function Restore_bet(p)
	local uid = p.uid
	local msg = {}
	--是否可复原
	local pour = 0
	for _,v in pairs(pour_message[uid]) do
		pour = pour + v
	end
	if fuyuan[uid] and pour <= 0 then 
		-- 押注金额
		local sum = 0
		if restore_message[uid] ~= nil then
			for _,v in pairs(restore_message[uid]) do
				sum = sum + v
			end
			if (game_status ~= 0) or (sum <= 0) then
				msg.type = 3
				p:send_msg("game.RestoreHORSE",msg)
				-- LOG_WARNING(uid.."没有可复原的数据")
				return
			end
		else
			msg.type = 3
			p:send_msg("game.RestoreHORSE",msg)
			-- LOG_WARNING(uid.."没有可复原的数据")
			return
		end
		-- 判断钱
		if send_goldchange(p,-sum) then
			--用户押注赋值
			pour_message[uid] = table.deepcopy(restore_message[uid])
			restore_message[uid] = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}
			-- 玩家投注
			local t = {}
			for k,v in pairs(pour_message[uid]) do
				total_pour[k] = total_pour[k] or 0
				total_pour[k] = total_pour[k] + v
				tinsert(t,{pourobject = k,pourmoney = v})
			end
			msg.restores = t
			msg.type = 1
			p:send_msg("game.RestoreHORSE",msg)
			-- LOG_WARNING(uid.."复原成功~")
			fuyuan[uid] = false
		else
			msg.type = 4
			p:send_msg("game.RestoreHORSE",msg)
			-- LOG_DEBUG(uid.."玩家金币不足")
		end
	else
		msg.type = 2
		p:send_msg("game.RestoreHORSE",msg)
		-- LOG_WARNING(uid.."已有押注，无法复原")
	end
end

--下局游戏
local function Next_game()
	if game_status == 1 then
		--游戏初始化
		tclear(randomresult)
		tclear(tPour_Rate)
		tclear(tRunway)
		randomtype = 0
		game_status = 0
		for uid,p in pairs(players) do
			win_message[uid] = 0
			restore_message[uid] = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}
			pour_message[uid] = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}
			-- xutou[uid] = true
			fuyuan[uid] = false
			if p.leave then
				api_kick(p,1003)
			end
		end
		total_pour = {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}
		--游戏阶段和剩余时间
		next_status_time=os_time() + status_time[1]
		game_time()
		send_to_all("game.HistoryHORSE", {History = tHistory})
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
				jordan = false
				--倍率
				local tRate = {1000,500,250,175,125,100,80,60,30,20,10,8,5,4,3}
				table.random(tRate)
				tPour_Rate = table.deepcopy(tRate)
				local msg = {}
				msg.rates = tPour_Rate
				send_to_all("game.BetRateHORSE",msg)
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
	pour_message[p.uid] = pour_message[p.uid] or {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}
	restore_message[p.uid] = restore_message[p.uid] or {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}
	win_message[p.uid] = win_message[p.uid] or 0
	-- xutou[p.uid] = true
	p.leave = false
	if test_gold and not p.isrobot then
		p.gold = test_gold
	end
	return true
end

--接受客户端消息
function this.dispatch(p, name, msg)
	-- if not p.isrobot then
	-- 	LOG_WARNING(p.gold)
	-- end
	if game_status ~= 0 then
		return
	end
	if name=="PourHORSE" then  --下注阶段
		goldchange(p,msg.pourobject,msg.pourmoney)	-- 判断玩家金币足不足
	elseif name=="ContinuedHORSE" then  --续投
		Continued_bet(p)
	elseif name=="CancelHORSE" then  --取消
		Cancel_bet(p)
	elseif name=="RestoreHORSE" then  --复原
		Restore_bet(p)
	elseif name=="HistoryHORSE" then  --记录
		History_bet(p)
	end
end

--断线重连
function this.resume(p,nOnline)
	p.leave = false
	--发送倍率
	local msg = {}
	msg.rates = tPour_Rate
	p:send_msg("game.BetRateHORSE",msg)  
	--发送游戏阶段
	local msg = {}
	msg.status = game_status
	msg.time = next_status_time - os_time()
	-- 发送消息
	p:send_msg("game.StatusHORSE", msg)
	--发送历史落点
	History_bet(p)
	-- 恢复游戏
	if last_pour_message[p.uid] ~= nil then
		for i = 1,15 do
			if last_pour_message[p.uid][i] == nil then
				last_pour_message[p.uid][i] = 0
			end
		end
	end
	local msg = {}
	if nOnline then
		msg.status = game_status
	else
		msg.status = -1
	end
	msg.pourmessage  = {pourGold=last_pour_message[p.uid]}
	msg.result = tRunway
	msg.huode = win_message[p.uid] or 0
	msg.xiazhu = pour_message[uid] or {[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0,[7]=0,[8]=0,[9]=0,[10]=0,[11]=0,[12]=0,[13]=0,[14]=0,[15]=0}
	msg.totalpour = total_pour
	p:send_msg("game.ResumeHORSE", msg)
end

-- 离开房间
function this.leave_game(p)
	--数据赋值
	local sum = 0
	for _,v in pairs(pour_message[p.uid]) do
		sum = sum + v
	end
	if sum == 0 then
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
	played_times = 0
	total_times = m_times
	rule_score = m_score
	code = m_code
	endtime = os_time() + m_conf.wait_time
	test_gold = m_conf.test_gold
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
	-- check_join_robot()
end

return this