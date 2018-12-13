--金权
--2018年3月3日
-- 黑豹的月亮

-- 类型说明 【1】猫头鹰，【2】狐狸，【3】蝴蝶，【4】蓝花，【5】红花，【6】9，【7】10，【8】J，【9】Q，【10】K，【11】A，【12】豹子，【13】月亮			2 (2,5,20,500)

--group说明
--[[
	【1】猫头鹰，狐狸 	2 (2,25,125,750)175 175
	【2】蝴蝶       	3 (20,100,500) 370
	【3】蓝花，红花		3 (15,75,250) 200 200
	【4】9				2 (2,5,25,100) 500
	【5】10，J			3 (5,25,100) 240 240
	【6】Q				3 (5,30,125) 460
	【7】K，A			3 (10,40,150) 220 220
	【8】豹子			2 (10,250,2500,10000) 10
	【9】月亮			2 (2,5,20,500) 1
]]

local this = {}
local deal = require "hb_gamedeal"

--用户数据变量
local players --用户列表
local cards = {} -- 游戏牌
local compare_card = {} -- 比对牌
local leave_cd_time = 20 -- 离线踢出游戏时间
local ZHONG_RATE = 1 -- 中奖概率
local sysearn = 0
local kickback

local is_tastemode --是否体验模式

--游戏配置数据
local game_id --游戏id
local game_type --游戏类型
local game_config --游戏配置
local total_rate --总概率

--彩金数据
local big_gold --大彩金
local small_gold --小彩金
local old_big_gold --大彩金
local old_small_gold --小彩金
local big_max_gold --大彩金最大值(200万~300万)
local small_max_gold --小彩金最大值(80万~100万)
local big_system_gold --系统大彩金(初始：100万~150万)
local small_system_gold --系统小彩金(初始：30万~50万)
local run_times --运行次数



-- local is_big_send --大彩金是否派奖
-- local is_small_send --小彩金是否派奖

-- local big_add_gold --增加大彩金
-- local small_add_gold --增加小彩金

--------------------彩金配置数据-----------------
local CJ_REMOVE_RATE = 0.2 -- 彩金回收比例
local CJ_PAIJIANG_RATE = 0.6 -- 彩金派奖比例
local CJ_BIG_INFO = {min = 1000000, max = 1500000} --大彩金初始值
local CJ_SMALL_INFO = {min = 300000, max = 500000} --小彩金初始值
local CJ_BIG_MAX = {min = 2000000, max = 3000000} --大彩金最大值
local CJ_SMALL_MAX = {min = 800000, max = 1000000} --小彩金最大值

--------------------预置数据-----------------------
local total_cards = {
	101, 102, 103, 104, 105, 106, 107, 108, 109, 110,
	201, 202, 203, 204, 205, 206, 207, 208, 209, 210,
	301, 302, 303, 304, 305, 306, 307, 308, 309, 310,
	401, 402, 403, 404, 405, 406, 407, 408, 409, 410
}

--显示概率
local show_rate = {175, 175, 370, 200, 200, 500, 240, 240, 460, 220, 220, 10, 1}

--------------------本地函数-----------------------

local free_table
local send_to_all
local otime = os.time
local tinsert = table.insert
local tremove = table.remove
local api_report_gold
local api_game_start
local api_call_ctrl
local api_game_end
local api_kick

--------------------数据赋值-----------------------
-- 洗牌
local function ass_shuffle()
    cards = {}
    local index
    local tmp = {}
    for i=1,#total_cards do
    	tmp[i] = i
    end
    for i = #total_cards, 1, -1 do
        index = table.remove(tmp, math.random(i))
        table.insert(cards, total_cards[index])
    end
end

--显示类型赋值
local function ass_show_type(index)
	local now_sum = 0
	local now_rate = math.random(1, total_rate)
	for k,v in pairs(show_rate) do
		if now_sum + v >= now_rate then
			--判断显示 
			return k
		else
			now_sum = now_sum + v
		end
	end
	return 1
end

--中彩金赋值
local function ass_caijin_result(result)
	local run_result = result
	local line_box = deal.line_box[math.random(1,15)]

	--数据赋值
	for i=1,5 do
		local index = i * 3 - line_box[i] + 1
		run_result[index] = 12
	end

	return run_result
end

--------------------发送消息-----------------------
--发送消息
local function send_player(p,n,m)
	if p then
		if not p.leave then
			p:send_msg(n,m)
		end
	else
		send_to_all(n, m)
	end
end

-- 金币改变
local function send_goldchange(p,gold)
	-- local ok = true, result
	local ok = true
	if is_tastemode then
		p.gold = p.gold + gold
		return p.gold >= 0
	end

	if gold > 0 then
		--增加金币
		p:call_userdata("add_gold", gold, game_id)
	elseif gold < 0 then
		-- --减少金币
		if gold + p.gold >= 0 then
			p:call_userdata("sub_gold", -gold, game_id)
		else
			ok = false
		end
	end

	--判断处理
	if ok then
		--数据赋值
		if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 1 then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold - gold
		elseif p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 2 then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + gold
		end
		p.gold = p.gold + gold
	end

	return ok
end

-- 发送彩金
local function send_caigold(p)
	--定义变量
	local msg = {}

	--起始数据
	msg.biggold = big_gold
	msg.smallgold = small_gold

	--判断赋值
	if not p then
		if old_big_gold ~= big_gold then
			old_big_gold = big_gold --大彩金
			old_small_gold = small_gold--小彩金

			--发送消息
			send_player(p, "game.CaiJinChangeNtf",msg)
		end
	else
		--发送消息
		send_player(p, "game.CaiJinChangeNtf",msg)
	end
end

-- 增加彩金
local function add_caiGold(bet)
	if is_tastemode then return end
	--增加彩金
	big_gold = big_gold + math.max(1, math.floor(bet * 0.07))
	small_gold = small_gold + math.max(1, math.floor(bet * 0.03))

	--判断是否回收彩金
	if big_gold > big_max_gold then
		big_max_gold = math.random(CJ_BIG_MAX.min, CJ_BIG_MAX.max) --大彩金最大值
		big_system_gold = math.max(0, big_system_gold - math.floor(big_gold * 0.2))
		big_gold = math.floor(big_gold * 0.8)
	end
	if small_gold > small_max_gold then
		small_max_gold = math.random(CJ_SMALL_MAX.min, CJ_SMALL_MAX.max) --小彩金最大值
		small_system_gold = math.max(0, small_system_gold - math.floor(small_gold * 0.2))
		small_gold = math.floor(small_gold * 0.8)
	end
end

-- 判断是否中彩金
local function juge_zhong_caijin(msg)
	if is_tastemode then return false end
	for i=1,15 do
		if msg.wintype[i] == 8 and msg.winnumber[i] == 5 then
			return true
		end
	end
	return false
end

--------------------游戏流程---------------------
--全局控制
local function juge_totalctrl(p, wingold)
	if is_tastemode then return true end
	--判断不控制
	if kickback == 1 then
		LOG_DEBUG("全局控制本局不起效")
		return true
	end

	--判断控制
	local rate = math.random(1 , 100000)
	if kickback * ZHONG_RATE < 1 then
		if rate < 100000 * (1 - kickback * ZHONG_RATE) then
			LOG_DEBUG("全局控制起效：玩家输")
			if wingold <= 0 then
				return true
			else
				p.ctrl_result = 1
				return false
			end
		else
			LOG_DEBUG("全局控制本局不起效")
			return true
		end
	else
		if rate < 100000 * (kickback * ZHONG_RATE - 1) then
			LOG_DEBUG("全局控制起效：玩家赢")
			if wingold >= 0 then
				return true
			else
				p.ctrl_result = 2
				return false
			end
		else
			LOG_DEBUG("全局控制本局不起效")
			return true
		end
	end
end

--判断是否开牌
local function juge_game_start(p, wingold)
	if is_tastemode then
		return true
	end

	local now_ctrlgold
	--循环次数到
	if p.start_times > 20 then
		LOG_DEBUG("循环算法次数大于20次，放弃控制")
		return true
	end
	
	--判断显示
	if p.start_times == 0 then
		if p.ctrlinfo and p.ctrlinfo.ctrltype then
			--数据赋值
			local rate = math.random(1,100)

			--判断返回
			now_ctrlgold = p.ctrlinfo.ctrlnowgold
			
			--判断赋值
			if p.ctrlinfo.ctrltype == 1 then
				now_ctrlgold = now_ctrlgold - wingold
			else
				now_ctrlgold = now_ctrlgold + wingold
			end

			--判断赋值
			if p.ctrlinfo.ctrlcount and p.ctrlinfo.ctrlcount > 0 then
				rate = 0
			end
			
			--判断是否超过上限
			if p.ctrlinfo.ctrlmaxgold < now_ctrlgold then
				if p.ctrlinfo.ctrltype == 1 then
					if wingold > 0 then
						return true
					else
						p.ctrl_result = 2
						return false
					end
				else
					if wingold < 0 then
						return true
					else
						p.ctrl_result = 1
						return false
					end
				end
			else
				--判断
				if rate <= p.ctrlinfo.ctrlrate then
					if p.ctrlinfo.ctrltype == 1 then
						if wingold < 0 then
							return true
						else
							p.ctrl_result = 1
							return false
						end
					else
						if wingold > 0 then
							return true
						else
							p.ctrl_result = 2
							return false
						end
					end
				end
			end
		end
		
		--全局控制
		return juge_totalctrl(p, wingold)
	else
		if p.ctrl_result == 1 then
			if wingold < 0 then
				return true
			else
				return false
			end
		else
			if p.ctrlinfo and p.ctrlinfo.ctrltype then
				--判断返回
				now_ctrlgold = p.ctrlinfo.ctrlnowgold
				
				--判断赋值
				if p.ctrlinfo.ctrltype == 1 then
					now_ctrlgold = now_ctrlgold - wingold
				else
					now_ctrlgold = now_ctrlgold + wingold
				end

				--判断赋值
				if p.ctrlinfo.ctrlmaxgold < now_ctrlgold and p.ctrlinfo.ctrltype == 2  then
					ctrl_result = 1
					return false
				else
					if wingold > 0 then
						return true
					else
						return false
					end
				end
			else
				if wingold > 0 then
					return true
				else
					return false
				end
			end
		end
	end
end

--游戏开始
local function game_start(p,bet)
	local msg = {}
	local win_gold
	local caijin_gold
	local run_result = {}
	local line_bet = bet / 15
	local free_box_num = 0
	local total_wingold
	
	--数据赋值
	p.bet = bet
	for i=1,15 do
		run_result[i] = ass_show_type(i)
		if run_result[i] == 13 then
			free_box_num = free_box_num + 1
		end
	end

	--判断中彩金
	if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrlcaijin == 2 and not is_tastemode then
		if math.random() < 0.2 then
			run_result = ass_caijin_result(run_result)
		end
	end

	--判断结束
	if free_box_num > 5 then
		game_start(p,bet)
		return
	end

	--判断赋值
	if p.freetimes > 0 then
		msg = deal.assResult(run_result, line_bet, true)
		win_gold = msg.wintotal
	else
		msg = deal.assResult(run_result, line_bet, false)
		win_gold = msg.wintotal - bet
	end
	total_wingold = win_gold

	--判断是否可以出彩金
	if juge_zhong_caijin(msg) then
		if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrlcaijin == 2 then
			--彩金数据赋值
			if p.freetimes > 0 then
				caijin_gold = math.floor(big_gold * CJ_PAIJIANG_RATE)
			else
				caijin_gold = math.floor(small_gold * CJ_PAIJIANG_RATE)
			end
			total_wingold = total_wingold + caijin_gold

			--判断
			if  p.ctrlinfo.ctrlmaxgold < p.ctrlinfo.ctrlnowgold + total_wingold then
				p.ctrlinfo.ctrlcaijin = 1
				game_start(p,bet)
				return
			end
		else
			game_start(p,bet)
			return
		end
	end

	--判断是否开始
	if not juge_game_start(p, total_wingold) then
		--数据赋值
		p.start_times = p.start_times + 1

		--重新发牌
		game_start(p, bet)
		return
	end

	--判断返回
	if not p.ctrlinfo then
		if total_wingold > sysearn * 0.1 then
			--数据赋值
			p.start_times = p.start_times + 1

			--重新发牌
			game_start(p, bet)
			return
		end
	end
	
	--彩金数据赋值
	if caijin_gold then
		if p.freetimes > 0 then
			big_gold = big_gold - caijin_gold
			msg.winbig = caijin_gold
		else
			small_gold = small_gold - caijin_gold
			msg.winsmall = caijin_gold
		end
		msg.wintotal = msg.wintotal + caijin_gold
		p.ctrlinfo.ctrlcaijin = 1
	end

	--彩金赋值
	add_caiGold(bet)

	local now_earn
	if p.freetimes and p.freetimes > 0 then
		now_earn = total_wingold
	else
		now_earn = total_wingold + bet
	end

	if not is_tastemode then
		--上次报
		--LOG_DEBUG("上报数据:cost="..bet..",earn="..now_earn)
		api_report_gold(bet, now_earn)
	end
	
	--控制次数赋值
	if p.ctrlinfo and p.ctrlinfo.ctrltype then
		if p.ctrlinfo.ctrlcount then
			p.ctrlinfo.ctrlcount =  p.ctrlinfo.ctrlcount - 1
			if  p.ctrlinfo.ctrlcount == 0 then
				p.ctrlinfo.ctrlcount = nil
			end
		end
	end

	--免费次数赋值
	if p.freetimes > 0 then
		p.freetimes = p.freetimes - 1
	end
	p.freetimes = p.freetimes + msg.randomtime
	p.wingold = now_earn
	
	--金币改变
	send_goldchange(p,total_wingold)

	--发送消息
	msg.owngold = p.gold
	msg.randomtime = p.freetimes
	send_player(p,"game.GameResultCSD",msg)
end

--游戏比倍
local function game_compare(p, times, ctype)
	--定义变量
	local msg = {}
	
	--判断显示
	if times == 1 then
		--定义变量
		local win_gold -- 玩家赢的金币
		local user_bet

		--洗牌
		ass_shuffle()

		--数据赋值
		for i=1,5 do
			compare_card[i] = tremove(cards,1)
		end

		--判断赋值
		if deal.compareCard(compare_card[1], compare_card[2]) == 1 then
			if ctype == 1 then
				win_gold = -p.wingold / 2
				user_bet = p.wingold / 2
			else
				win_gold = -p.wingold
				user_bet = p.wingold
			end
		else
			if ctype == 1 then
				win_gold = p.wingold / 2
				user_bet = p.wingold / 2
			else
				win_gold = p.wingold
				user_bet = p.wingold
			end
		end

		--判断全局
		if not juge_game_start(p, win_gold) then
			--数据赋值
			p.start_times = p.start_times + 1

			--重新比倍
			game_compare(p, times, ctype)
			return
		end

		--判断返回
		if not p.ctrlinfo then
			if win_gold > sysearn * 0.1 then
				--数据赋值
				p.start_times = p.start_times + 1

				--重新比倍
				p.ctrl_result = 1
				game_compare(p, times, ctype)
				return
			end
		end

		--彩金赋值
		add_caiGold(user_bet)
		if not is_tastemode then
			--上次报
			local earn = win_gold + user_bet
			LOG_DEBUG("比倍上报数据:cost="..user_bet..",earn="..earn)
			api_report_gold(user_bet, earn)
		end
		

		--数据赋值
		p.wingold = p.wingold + win_gold

		--金币改变
		send_goldchange(p,win_gold)

		--发送消息
		msg.cards = {compare_card[1]}
		send_player(p, "game.CompareScoreResult", msg)
	elseif times == 2 then
		--发送消息
   		msg.gold = p.gold
		msg.cards = compare_card
  	 	msg.wingold = p.wingold

  	 	--发送消息
  	 	send_player(p, "game.CompareScoreResult", msg)
	end
end

--------------------系统调用---------------------
-- 接收客户端消息,player,cmd,msg
function this.dispatch(p, name, msg)
	if name=="PourCSD" then
		if p.gold < msg.pourmoney then
			return
		end

		--数据赋值
		p.start_times = 0

		--开始游戏
		game_start(p,msg.pourmoney) 
	elseif name == "CompareScore" then
		if p.wingold > 0  or msg.times2 == 2 then
			--数据赋值
			p.start_times = 0

			--开始比倍
			game_compare(p, msg.times2, msg.times1)
		else
			LOG_DEBUG("黑豹的月亮：客户端比倍异常")
		end
	end
end

-- 加入房间
function this.join(p)
	if is_tastemode then
		p.gold = game_config.test_gold
	end
	return true
end

--恢复房间
function this.resume(p)
	if not p.info then
		--数据初始化
		p.bet = 120
		p.wingold = 0
		p.freetimes = 0
		p.info = true
	end
	p.leave = false
	p.leave_time = nil

	--发送协议
	send_caigold()
end

--离线调用
function this.offline(p)
	--玩家离线
	p.leave = true
	p.leave_time = otime() + leave_cd_time
end

-- 离开游戏
function this.leave_game(p)
	return true
end

-- 数据更新(100)
function this.update()
	--每秒发送消息
	run_times = run_times + 1
	if run_times > 10 then
		run_times = 0
		send_caigold()
	end

	--检测剔除玩家
	for uid,p in pairs(players) do
		if p.leave and otime() > p.leave_time then
			api_kick(p,1003)
		end
	end
end

--金币该改变通知
function this.add_gold(p,gold,resaon)
	--定义变量
	local msg = {}

	--数据赋值
	p.gold = p.gold + gold
	msg.uid = p.uid
	msg.goldadd = gold
	msg.gold = p.gold

	--发送金币改变通知
	send_player(p,"game.UpdateGoldInGame", msg)
end

-- 发送房间信息
function this.get_tableinfo(p)
	local msg = {}
	local list = {}
	list[1] = {
		uid = p.uid, 
		nickname = p.nickname,
		seatid = p.seatid or 0,
		ready = p.ready or 0,
		online = p.online or 1,
		score = p.score or 0,
		sex = p.sex or 1,
		headimg = p.headimg or nil,
		gold = p.gold,
		params = nil
	}
	msg.owner = p.uid  
	msg.endtime =  0
	msg.gameid = game_id
	msg.times = 1000 
	msg.playedtimes = 0 
	msg.paytype = 1
	if p.freetimes then
		msg.score = p.bet
		msg.code = p.freetimes
	else
		msg.code = 0
		msg.score = 120
	end
	msg.players = list
	msg.isGoldGame= 1
    
	return msg
end

-- 解散房间
function this.free()
	LOG_DEBUG("黑豹的月亮：解散房间")
end

--设置概率
function this.set_kickback(kb, sys)
	if is_tastemode then return end
	kickback = kb
	if sys then
		sysearn = sys
	end
end

-- 初始化
function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid, usegold, _, params, kb)
    -- 数据赋值
	players = ps
	game_id = m_gameid
	game_config = m_conf
	kickback = kb
	if game_config.test_gold and game_config.test_gold > 0 then
		is_tastemode = true
	end
	--api函数
	free_table = api.free_table
	send_to_all = api.send_to_all
	api_game_start = api.game_start
	api_call_ctrl = api.call_ctrl
	api_game_end = api.game_end
	api_report_gold = api.report_gold
	api_kick = api.kick

	--彩金数据初始化
	run_times = 0
	big_max_gold = math.random(CJ_BIG_MAX.min, CJ_BIG_MAX.max) --大彩金最大值
	small_max_gold = math.random(CJ_SMALL_MAX.min, CJ_SMALL_MAX.max) --小彩金最大值
	big_system_gold = math.random(CJ_BIG_INFO.min, CJ_BIG_INFO.max) --系统大彩金
	small_system_gold = math.random(CJ_SMALL_INFO.min, CJ_SMALL_INFO.max) --系统小彩金
	old_big_gold = big_gold --大彩金
	old_small_gold = small_gold--小彩金
	big_gold = big_system_gold --大彩金
	small_gold = small_system_gold --小彩金

	--总概率赋值
	total_rate = 0
	for k,v in pairs(show_rate) do
		total_rate = total_rate + v
	end

	--初始化日志
	LOG_DEBUG("黑豹的月亮：初始化")
end

return this