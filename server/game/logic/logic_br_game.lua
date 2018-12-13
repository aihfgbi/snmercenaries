--金权
--2017年12月20日
--百人游戏

--游戏说明
--[[
	游戏种类：
	【1】牛牛
	【2】小九
	【3】二八杠
	【4】憋十
	【5】两张
]]
local deal = require "br_gamedeal"
local resultctrl = require "br_resultctrl"
local this = {}

--游戏数据
local cards = {} --洗牌后牌
local pos_num --位置个数
local open_num --开牌个数
local pos_card --位置牌
local pos_iswin --位置是否赢
local pos_cardtype --位置牌型
local pos_totalbet --位置所有下注
local pos_betdetail = {} --位置下注内容
local pos_cardnum --位置卡牌个数
local chip_gold -- 筹码金币
local total_bet --用户总押注
local total_cards --所有牌
local bet_max_rate --押注最大倍率
local record -- 历史记录
local openrate -- 开牌随机数
local ranking_data

local is_tastemode --是否体验模式

--庄家数据
local banker_id --庄家id
local banker_data --庄家数据
local banker_list --庄家列表
local banker_times --庄家次数
local banker_max_times --连庄次数
local banker_up_gold --上庄金币
local banker_down_gold --下庄金币
local banker_wingold -- 庄家赢得金币
local is_get_banker --是否抢庄

--用户数据变量
local players --用户列表

--游戏流程变量
local run_time --运行时间
local next_time --next时间
local has_start --是否开始
local game_status --游戏状态
local status_time --状态时间
local status_name --状态名称
local send_card_num --开牌个数

--[[status_name
	【waiting】等待时间
	【send】发牌时间
	【bet】下注时间
	【open】开奖时间
	【result】结算时间
]]

--游戏配置数据
local game_id --游戏id
local game_type --游戏类型
local game_config --游戏配置
local game_name = {"百人牛牛", "百人小九", "二八杠", "百人憋十", "温州两张"}

--------------------本地函数-----------------------

local getType
local assIsWin
local free_table
local send_to_all
local assuserWingold
local assBankerWinGold
local otime = os.time
local tinsert = table.insert
local tremove = table.remove
local api_report_gold
local api_game_start
local api_game_end
local api_join_robot
local api_kick

--------------------系统默认-----------------------
--系统数据
local system_data = {
	uid = 0,
	sex = 0,
	gold = 100000000,
	nickname = "系统",
	headimg = ""
}

--------------------数据赋值-----------------------
--table赋值
local function ass_table(tb)
	local now_tb = {}
	for k,v in pairs(tb) do
		now_tb[k] = v
	end
	return now_tb
end

-- 庄家数据赋值
local function ass_banker()
	--判断赋值
	if banker_id == 0 then
		return system_data
	else
		if players[banker_id] then
			return players[banker_id]
		else
			banker_id = 0
			return system_data
		end
	end
end

-- 判断是否在庄稼列表
local function ass_banker_index(uid)
	local index = 0
	for i,v in ipairs(banker_list) do
		if v == uid then
			index = i
			break
		end
	end
	return index
end

-- 庄稼列表赋值0：下庄，1：上庄
local function ass_bankerlist(uid,type)
	local index = ass_banker_index(uid)
	if index > 0 then
		if type == 0 then
			tremove(banker_list,index)
			return true
		elseif type == 1 then
			return false
		end
	else
		if type == 0 then
			return false
		elseif type == 1 then
			tinsert(banker_list,uid)
			return true
		end
	end
end

--庄家列表改变
local function ass_changebankerList()
	local is_change = 0
	for i=1,#banker_list do
		if not players[banker_list[i]] then
			is_change = 1
			ass_bankerlist(banker_list[i],0)
		elseif i == 1 and players[banker_list[i]].gold < banker_down_gold then
			is_changelist = 1
			ass_bankerlist(banker_list[i],0)
		end
	end
	return is_change
end

--当前庄家赋值
local function ass_nowbanker()
	if #banker_list == 0 then
		--系统坐庄
		banker_id = 0
		banker_times = 0;
		banker_data = ass_banker()
	else
		--玩家坐庄
		banker_id = banker_list[1]
		banker_data = ass_banker()
		banker_times = banker_max_times
	end
end

--庄数据赋值
local function ass_changebanker()
	if banker_id == 0 then
		if banker_list[1] then
			if players[banker_list[1]] and players[banker_list[1]].gold > banker_up_gold then
				banker_id = -1
				banker_times = 0
			else
				--移除庄家
				ass_bankerlist(banker_list[1],0)

				--重新赋值
				ass_changebanker();
			end
		end
	else
		if banker_list[1] then
			if banker_id ~= banker_list[1] then
				if players[banker_list[1]] and players[banker_list[1]].gold > banker_up_gold then
					banker_id = -1
					banker_times = 0
				else
					--移除庄家
					ass_bankerlist(banker_list[1],0)

					--重新赋值
					ass_changebanker();
				end
			else
				if banker_times < 1 then
					banker_id = -1
					banker_times = 0
					ass_bankerlist(banker_list[1],0)
				end
			end
		else
			banker_id = -1
			banker_times = 0
		end
	end
end

--恢复房间赋值
local function ass_resume(p)
	--数据初始化
	if p then
		p.leave = false
		if not p.info then
			p.info = true
			p.wingold = 0
			p.userbet = {}
			p.totalbet = 0
			p.betdetail = {}
			for i=1,pos_num do
				p.userbet[i] = 0
			end
		end
		if p.isrobot then
			p.nowtimes = 0
			p.playtimes = 5 + math.random(10)
		end
	end
end

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

-- 初始化数据
local function ass_info()
	--清空数据
	total_bet = 0
	pos_card = nil
	pos_iswin = nil
	pos_cardtype = nil
	pos_totalbet = {}
	pos_betdetail = {}
	for i=1,pos_num do
		pos_totalbet[i] = 0
	end
	
	--清除用户
	for uid,v in pairs(players) do
		if v.leave then
			--判断是否上庄
			local index = ass_banker_index(v.uid)
			if index > 0 then
				--移除
				tremove(banker_list,index)
			end
			
			--清除用户
			api_kick(v,1003)
		end
	end
	
	--用户数据处理
	local player_num = 0
	for uid,v in pairs(players) do
		v.userbet = {}
		v.totalbet = 0
		v.betdetail = {}
		player_num = player_num + 1
		for i=1,pos_num do
			v.userbet[i] = 0
		end
	end

	return player_num
end

--押注赋值
local function ass_userbet(p,pos,gold)
	--数据赋值
	p.totalbet = p.totalbet + gold
	p.userbet[pos] = p.userbet[pos] + gold
	if p.betdetail[pos] then
		if p.betdetail[pos][gold] then
			p.betdetail[pos][gold] = p.betdetail[pos][gold] + 1
		else
			p.betdetail[pos][gold] = 1
		end
	else
		p.betdetail[pos] = {}
		p.betdetail[pos][gold] = 1
	end

	--押注数据赋值
	total_bet = total_bet + gold
	pos_totalbet[pos] = pos_totalbet[pos] + gold
	if pos_betdetail[pos] then
		if pos_betdetail[pos][gold] then
			pos_betdetail[pos][gold] = pos_betdetail[pos][gold] + 1
		else
			pos_betdetail[pos][gold] = 1
		end
	else
		pos_betdetail[pos] = {}
		pos_betdetail[pos][gold] = 1
	end
end

-- 筹码内容数据赋值
local function ass_betdetail(detail)
	local num = 1
	local bet_detail = {}
	if detail then
		for k,v in pairs(chip_gold) do
			if detail[v] then
				bet_detail[num] = v
				bet_detail[num + 1] = detail[v]
				num = num + 2
			end
		end
	end
	return bet_detail
end

--开牌赋值
local function ass_cards(t)
	--原始牌赋值
	local total_wingold = 0
	local old_poscards = {}
	local total_userbet = 0
	local old_cards = ass_table(cards)

	--数据初始化
	if not pos_card then
		pos_card = {}
		pos_cardtype = {}
	end
	
	--判断赋值
	if t == 1 then
		-- 先发牌流程
		for i=1,open_num do
			pos_card[i] = {}
			for j=1,send_card_num do
				pos_card[i][j] = table.remove(cards,1)
			end
		end
	elseif t == 0 then
		local add_card = {}
		for i=1,open_num do
			add_card[i] = {}
			for j=1,pos_cardnum - send_card_num do
				tinsert(add_card[i],table.remove(cards,1))
			end
		end

		--结果数据赋值
		local open_result = resultctrl.assResult(pos_card, add_card, total_bet, banker_data.gold, banker_id, pos_totalbet)

		--开奖数据赋值
		pos_card = open_result.pos_card
		pos_iswin = open_result.pos_iswin
		pos_cardtype = open_result.pos_cardtype
		banker_wingold = open_result.banker_wingold
		banker_data.wingold = banker_wingold

		--庄家金币赋值
		if banker_id == 0 then
			banker_data.gold = banker_data.gold + banker_wingold
			system_data.gold = banker_data.gold
		end

		--处理系统金币过少或者机器人金币过少
		if banker_id == 0 and system_data.gold < banker_down_gold then
			system_data.gold = 1000000000
			banker_data.gold = system_data.gold
		end

		--上报总
		--LOG_DEBUG("上报数据:cost="..open_result.totalbet..",earn="..open_result.totalwin)
		api_report_gold(open_result.totalbet, open_result.totalwin)
	end
end

--最大金币赋值
local function ass_max_gold()
	local max_gold = 0
	for uid,p in pairs(players) do
		if not p.isrobot then
			max_gold = math.max(p.gold,max_gold)
		end
	end
	return max_gold
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
		if p.gold < 0 then
			ok = false
		end
		return ok
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
			LOG_DEBUG("控制玩家输："..p.ctrlinfo.ctrlnowgold)
		elseif p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrltype == 2 then
			p.ctrlinfo.ctrlnowgold = p.ctrlinfo.ctrlnowgold + gold
			LOG_DEBUG("控制玩家赢："..p.ctrlinfo.ctrlnowgold)
		end
		p.gold = p.gold + gold
	end

	return ok
end

-- 庄家列表
local function send_bankerlist(p)
	local msg = {}
	local list = {}
	for i=1,#banker_list do
		list[i] = {}
	    list[i].sex = 1
		list[i].uid = players[banker_list[i]].uid
	    list[i].gold = players[banker_list[i]].gold
	    list[i].nickname = players[banker_list[i]].nickname
	    if players[banker_list[i]].headimg then
	    	list[i].headimg = players[banker_list[i]].headimg
	    end
	end
	list[#banker_list + 1] = {}
	list[#banker_list + 1].sex = 1
	list[#banker_list + 1].uid = 0
	list[#banker_list + 1].gold = system_data.gold
	list[#banker_list + 1].nickname = system_data.nickname
	msg.players = list
	
	--发送消息
	send_player(p,"game.BRMasterList", msg)
end

-- 玩家列表
local function send_playerlist(p)
	local msg = {}
	local list = {}
	local list_num = 1
	for k,v in pairs(players) do
		list[list_num] = {}
		list[list_num].sex = 1
		list[list_num].uid = v.uid
		list[list_num].gold = v.gold
		list[list_num].nickname = v.nickname
		if v.headimg then
	    	list[list_num].headimg = v.headimg
	    end
		list_num = list_num + 1
	end
	msg.players = list
	
	--发送消息
	send_player(p,"game.BRUserList", msg)
end

-- 发送庄改变
local function send_bankerchange(p)
	local msg = {}
	msg.uid = banker_id

	--发送庄家列表
	send_bankerlist(p)
	
	--发送消息
	send_player(p,"game.SetMaster", msg)
end

--发送初始化消息
local function send_info(p)
	p.start = true
	local msg = {}
	local infos = {}
	for i=1,pos_num do
		infos[i] = {}
		if pos_card and pos_card[i] then
			infos[i].count = #pos_card[i] --总卡牌数量
        	infos[i].cards = pos_card[i] --明牌
		else
			infos[i].count = 0 --总卡牌数量
        	infos[i].cards = nil --明牌
		end
		infos[i].bets = ass_betdetail(pos_betdetail[i])
		infos[i].selfbets = ass_betdetail(p.betdetail[i])
	end
    msg.infos = infos --玩家的卡牌
	msg.count = 0 --庄家的总卡牌数量
	msg.cards = nil --庄家已经明掉的牌
	msg.status = game_status --当前状态
	msg.record = record --历史记录
	if send_card_num > 0 then
		if status_name[game_status] == "bet" or status_name[game_status] == "send" then
			msg.cardsnum = #cards - open_num * (pos_cardnum - send_card_num) -- 卡牌个数
		else
			msg.cardsnum = #cards -- 卡牌个数
		end
	else
		msg.cardsnum = #cards -- 卡牌个数
	end
	msg.btimes = banker_times -- 庄家当装次数
	if run_time then
		msg.time = status_time[game_status] - run_time --当前状态剩余时间
	else
		msg.time = status_time[game_status] --当前状态剩余时间
	end
	msg.openrate = openrate -- 发牌随机数
	msg.gold = p.gold -- 玩家金币

	--判断显示庄家牌
	if pos_card and pos_card[open_num] then
		msg.count = #pos_card[open_num]
		msg.cards = pos_card[open_num]
	else
		msg.count = 0
		msg.cards = nil
	end
    
	-- 发送消息给用户
	send_bankerchange(p)
	
	-- 发送消息
	send_player(p,"game.BRResume",msg)
end

--发送用户状态
local function send_status(p)
	local msg = {}
	msg.status = game_status
	msg.time = status_time[game_status] - run_time

	-- 发送消息
	send_player(p,"game.BRStatusNtf", msg)
end

--下注消息
local function send_bet()
	local msg = {}
	for uid,v in pairs(players) do
		local infos = {}
		for i=1,pos_num do
			infos[i] = {}
			infos[i].bets = ass_betdetail(pos_betdetail[i])
			infos[i].selfbets = ass_betdetail(v.betdetail[i])
		end
		
		-- 发送消息
		msg.infos = infos
		send_player(v,"game.BRBetNtf",msg)
	end
end

-- 发送用户押注
local function send_userbet(p,gold,pos)
	local msg = {}
	msg.pos = pos
	msg.gold = p.gold - p.totalbet
	msg.betgold = gold

	--发送消息
	send_player(p,"game.BRBetRep",msg)
end

-- 发送开牌消息
local function send_open()
	for i=1,open_num do
		local msg = {}
		msg.uid = 0
		msg.seatid = i
		msg.cards = pos_card[i]

		-- 发送消息
		send_player(nil,"game.ShowCard",msg)
	end
end

--发送结算消息
local function send_result(p)
	local msg = {}
    msg.gold = p.gold --用户金币
	msg.wingold = p.wingold ---/用户金币
   	msg.mgold = banker_data.gold --庄家剩余的钱
    msg.mwgold = banker_data.wingold --庄家输赢
    msg.iswin = pos_iswin --位置输赢
    msg.cardsnum = #cards -- 卡牌个数
    msg.openrate = openrate -- 发牌随机数
    msg.ranking = ranking_data -- 排行数据
    
	-- 发送消息
	send_player(p,"game.BRResult",msg)
end

--------------------机器人控制-----------------------
--增加机器人
local function add_jqr()
	if game_config.add_robot then
		local jqr_min_gold = 10000
		local jqr_max_gold = 100000000
		local jqr_gold = jqr_min_gold + math.random(math.floor((jqr_max_gold - jqr_min_gold)/10000)) * 10000
		jqr_gold = jqr_gold + math.random(100) * 100

		--增加机器人
		pcall(api_join_robot,"br_game",jqr_gold)
	end
end

-- 机器人列表改变
local function jqr_list_change()
	if not game_config.add_robot then
		return
	end
	local min_num = 10
	local max_num = 20
	local now_robot_num = 0
	
	--回收机器人
	for uid,p in pairs(players) do
		if p.isrobot then
			p.nowtimes = p.nowtimes + 1
			if p.nowtimes >= p.playtimes and banker_id ~= p.uid then
				--判断是否上庄
				local index = ass_banker_index(p.uid)
				if index > 0 then
					--移除
					tremove(banker_list,index)

					--发送庄家列表
					send_bankerlist()
				end

				--删除机器人
				api_kick(p,1008)
			else
				if p.gold < 10000 and banker_id ~= p.uid then
					--判断是否上庄
					local index = ass_banker_index(p.uid)
					if index > 0 then
						--移除
						tremove(banker_list,index)

						--发送庄家列表
						send_bankerlist()
					end

					--删除机器人
					api_kick(p,1008)
				else
					now_robot_num = now_robot_num + 1
				end
			end
		end
	end
	
	--增加机器人
	if now_robot_num < min_num then
		for i=1,min_num - now_robot_num do
			add_jqr()
		end
	end
	
	--随机增加机器人
	if now_robot_num < max_num then
		local now_rate = math.random()
		if now_rate < 0.5 then
			add_jqr()
		end
	end
end

--------------------流程控制-----------------------
--游戏开始
local function game_start()
	--游戏初始化
	ass_info()

	--数据赋值
	run_time = 0
	game_status = 1
	next_time = otime() + status_time[1]
	openrate = math.floor(math.random() * 100)

	--庄家数据赋值
	banker_list = {}
	banker_data = ass_banker()

	--洗牌
	ass_shuffle()

	--开始游戏
	has_start = true
	LOG_DEBUG(game_name[game_type].."：游戏开始")
end

--游戏初始化
local function game_waiting()
	--历史记录复制
	for i=1,record[1] do
		tinsert(record, pos_iswin[i])
	end
	for i=1,record[1] do
		table.remove(record,2);
	end

	--初始化数据赋值
	local player_num = ass_info()

	--坐庄次数赋值
	if banker_id ~= 0 then
		banker_times = banker_times - 1
	end
	
	--庄家列表数据赋值
	local is_changelist = ass_changebankerList()

	--庄家是否改变
	ass_changebanker()

	--判断庄家是否改变
	if banker_id == -1 then
		if is_get_banker == 0 then
			ass_nowbanker()
		end

		--发送庄家改变
		send_bankerchange(nil)
	else
		if is_get_banker == 1 and banker_id == 0 then
			banker_id = -1
			banker_times = 0
			send_bankerchange(nil)
		else
			if is_changelist == 1 then
				send_bankerlist(nil)
			end
		end
	end
end

--游戏发牌
local function game_send()
	--判断庄家（抢庄玩法）
	if is_get_banker == 1 then
		if banker_id == -1 then
			--当前庄家赋值
			ass_nowbanker()

			--发送庄家改变
			send_bankerchange(nil)
		end
	end

	--开牌赋值
	ass_cards(1)

	--发送牌内容
	send_open()
end

--游戏押注
local function game_bet()
	--判断庄家（抢庄玩法）
	if is_get_banker == 1 and send_card_num == 0 then
		if banker_id == -1 then
			--当前庄家赋值
			ass_nowbanker()

			--发送庄家改变
			send_bankerchange(nil)
		end
	end

	--游戏开始
	api_game_start()
end

--比较排行
local function compareRanking(a, b)
    if a.gold > b.gold then
        return true
    end
    return false
end

--排行榜数据
local function ass_ranking()
	--数据初始化
	local now_ranking = {}

	--数据赋值
	for uid,p in pairs(players) do
		if uid ~= banker_id then
			local now_win = p.wingold - p.totalbet
			tinsert(now_ranking,{nickname = p.nickname, gold = now_win})
		end
	end

	--进行排序
	table.sort(now_ranking, compareRanking)

	--数据赋值
	ranking_data = {}
	for i=1,math.min(5,#now_ranking) do
		tinsert(ranking_data,now_ranking[i])
	end
end

--游戏开奖
local function game_open()
	--开牌赋值
	ass_cards(0)

	--开牌消息
	send_open()
	
	--判断洗牌
	if not cards or #cards < pos_cardnum * open_num then
		ass_shuffle()
	end

	--数据赋值
	openrate = math.floor(math.random() * 100)
	
	--排行榜数赋值
	ass_ranking();

	--庄家先结算
	if banker_id ~= 0 then
		if send_goldchange(players[banker_id],players[banker_id].wingold) then
			send_result(players[banker_id])
		end
	end

	--结算消息
	for uid,p in pairs(players) do
		if uid ~= banker_id then
			if send_goldchange(p,p.wingold - p.totalbet) then
				send_result(p)
			end
		end
	end
end

--游戏结算
local function game_result()
	--游戏结束
	api_game_end()

	--判断用户赢红包
	for uid,p in pairs(players) do
		if not p.totalbet then
			p.totalbet = 0
		end
		if p.wingold - p.totalbet > 0 and not p.isrobot and not is_tastemode then
			p:call_userdata("add_win", game_id, 1001);
		end
	end
end

--------------------系统调用---------------------
-- 接收客户端消息,player,cmd,msg
function this.dispatch(p, name, msg)
	--判断接收消息
    if name == "BRBetReq" then
    	-- 扣除金币
    	if banker_id ~= p.uid  and status_name[game_status] == "bet" then
    		--判断庄家金币不足
			if banker_data.gold >= bet_max_rate * (total_bet + msg.gold) then
				if  p.gold >= bet_max_rate * (p.totalbet + msg.gold) then
					--用户押注赋值
		    		ass_userbet(p,msg.pos,msg.gold)

		    		-- 发送消息
					send_userbet(p,msg.gold,msg.pos)
	    		else
					-- LOG_DEBUG(game_name[game_type].."：玩家金币不足")
	    		end
			else
				-- LOG_DEBUG(game_name[game_type].."：庄家金币不足")
			end
    	end
    elseif name == "AskMaster" then
    	local is_changebanker
    	if msg.opt == 0 then
    		if ass_bankerlist(p.uid,0) then
    			if game_status == 1 then
    				if is_get_banker == 0 then
    					ass_changebanker()
    					if banker_id == -1 then
    						ass_nowbanker()
    						send_bankerchange(nil)
						else
	    					send_bankerlist(nil)
						end
    				else
    					send_bankerlist(nil)
    				end
				else
	    			send_bankerlist(nil)
				end
    		end
    	elseif msg.opt == 1 then
    		if p.gold >= banker_up_gold then
    			if ass_bankerlist(p.uid,1) then
	    			if game_status == 1 then
	    				if is_get_banker == 0 then
	    					ass_changebanker()
	    					if banker_id == -1 then
	    						ass_nowbanker()
	    						send_bankerchange(nil)
							else
		    					send_bankerlist(nil)
							end
	    				else
	    					send_bankerchange(nil)
	    				end
	    			else
	    				send_bankerlist(nil)
	    			end
	    		end
    		end
    	elseif msg.opt == 2 then
    		if game_status == 1 then
    			print("庄家金币："..p.gold..banker_up_gold)
    			if banker_id == -1 and p.gold >= banker_up_gold then
    				ass_nowbanker()
    				send_bankerchange(nil)
    			else
    				--抢慢了

    			end
    		end
    	end
    elseif name == "BRMasterList" then
    	-- 下发庄家列表
    	send_bankerlist(p)
    elseif name == "BRUserList" then
    	-- 下发庄家列表
    	send_playerlist(p)
    end
end

-- 加入房间
function this.join(p)
	--开始游戏
	if not has_start then
		if is_tastemode then
			p.gold = game_config.test_gold
		end
		game_start()
	end
	
	return true
end

--恢复房间
function this.resume(p)
	--恢复房间赋值
	ass_resume(p)
	
    --发送结算
    if send_card_num > 0 then
    	if game_status > 3 then
    		send_result(p)
    	end
   	else
   		if game_status > 2 then
    		send_result(p)
    	end
   	end

    --发送初始化		
    send_info(p)
end

--离线调用
function this.offline(p)
	--数据赋值
	if has_start then
		p.leave = true
	end
end

-- 离开游戏
function this.leave_game(p)
	--数据赋值
	if p.uid ~= banker_id then
		if has_start and p.userbet then
			--用户押注赋值
			local bet = 0
			for i=1,pos_num do
				bet = bet + p.userbet[i]
			end
			
			--允许离开
			if bet == 0 then
				--判断是否在上庄列表
				for k,uid in pairs(banker_list) do
					if uid == p.uid then
						ass_bankerlist(p.uid,0)
						send_bankerlist(nil)
					end
				end
				
				return true
			else
				p.leave = true
			end
		else
			return true
		end
	else
		p.leave = true
	end
end

-- 数据更新(100)
function this.update()
	--游戏未开始
	if has_start == true then
		if next_time and otime() > next_time then
			--数据清空
			run_time = nil
			next_time = nil

			--机器人改变
			if game_status == 1 then
				--机器人改变
				jqr_list_change()
			end

			--状态数据
			game_status = game_status + 1
			if game_status > #status_time then
				game_status = 1
			end

			--判断显示界面
			if status_name[game_status] == "waiting" then
				game_waiting() --游戏初始化
			elseif status_name[game_status] == "send" then
				game_send() --游戏发牌
			elseif status_name[game_status] == "bet" then
				game_bet() --游戏押注
			elseif status_name[game_status] == "open" then
				game_open() --游戏开奖
			elseif status_name[game_status] == "result" then
				game_result() --游戏结算
			end

			--时间数据
			run_time = 0
			next_time = otime() + status_time[game_status]

			--发送用户状态
			send_status(nil)
		elseif next_time and run_time then
			--数据赋值
			local now_time = otime() - (next_time - status_time[game_status])

			--游戏定时器
			if run_time < now_time then
				run_time = now_time
				if status_name[game_status] == "bet" then
					send_bet() --发送下注消息
				end
			end
		end
    end
end

-- 初始化
function this.init(ps, api, m_conf, m_times, m_score, m_pay, m_code, m_gameid, uid, usegold, _, params, kb)
    -- 数据赋值
	players = ps
	game_id = m_gameid
	game_config = m_conf
	game_type = game_config.init_params
	if game_config.test_gold and game_config.test_gold > 0 then
		is_tastemode = true
	end
	--游戏数据赋值
	pos_num = deal.pos_num[game_type] --位置个数
	open_num = deal.open_num[game_type] --开牌个数
	pos_cardnum = deal.pos_cardnum[game_type] --位置卡牌个数
	bet_max_rate = deal.bet_max_rate[game_type] --押注最大比例
	banker_max_times = deal.banker_max_times[game_type] --连庄次数
	banker_up_gold = deal.banker_up_gold[game_type] --上庄金币
	banker_down_gold = deal.banker_down_gold[game_type] --下庄金币
	chip_gold = deal.chip_gold[game_type] -- 筹码金币
	total_cards = deal.total_cards[game_type] --所有牌
	status_time = deal.status_time[game_type] --状态时间
	status_name = deal.status_name[game_type] --状态名称
	send_card_num = deal.send_card_num[game_type] --状态名称
	is_get_banker = deal.is_get_banker[game_type] --是否抢庄
	record = deal.assRecordInfo[game_type]() -- 历史记录

	--api函数
	free_table = api.free_table
	send_to_all = api.send_to_all
	api_game_start = api.game_start
	api_join_robot = api.join_robot
	api_game_end = api.game_end
	api_report_gold = api.report_gold
	api_kick = api.kick

	--游戏规则函数
	getType = deal.getType[game_type]
	assIsWin = deal.assIsWin[game_type]
	assuserWingold = deal.assuserWingold[game_type]
	assBankerWinGold = deal.assBankerWinGold[game_type]

	--结果控制初始化
	resultctrl.init(players, kb, game_type, is_tastemode)

	--数据初始化
	banker_id = 0
	banker_times = 0
	has_start = false
	LOG_DEBUG(game_name[game_type].."：初始化")
end

--设置概率
function this.set_kickback(kb, sys)
	if not is_tastemode then
		resultctrl.set_kickback(kb, sys)
	end
end

--金币该改变通知
function this.add_gold(p,gold,resaon)
	--数据赋值
	p.gold = p.gold + gold
	
	--发送金币改变通知
	send_to_all("game.UpdateGoldInGame", { uid = p.uid, goldadd = gold, gold = p.gold })
end

-- 发送房间信息
function this.get_tableinfo(p)
	
end

-- 解散房间
function this.free()
	LOG_DEBUG(game_name[game_type].."：解散房间")
end

return this