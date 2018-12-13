local land_deal = require "land_deal"
local math_random = math.random
local ai_mgr = {}
local server_msg = {}
local robot_api
local robot_info
--测试用
local test_cards_storage
-- {
-- 	uid = 1,
-- 	seatid = 2,
--	teammate = seatid,   队友seatid 无则为0
--  card_score = 5, 	根据叫地主规则算出来的分数
--  mastered = 0, 		是否已经叫过地主
-- 	cards = {},
--  master = 1,			地主的seatid
--  replace = uid,		是否接的托管的玩家
-- }
local other_info
-- {
-- 		[seatid] = {cardnum = 1, uid = 1},
-- }
local content_dissolve
local uid_2_seatid
--当前出牌信息
local turn_info = {
	-- winner = 0,
	-- cards = {}
}
local JIAODIZHU = 4
local QIANGDIZHU = 6
local removed_cards

--当只能用炸弹来压对手的牌时 出炸弹的几率依赖对手手牌数量以及自己炸弹数量
local remain2odds = {
	[5] = 100,
	[6] = 85,
	[7] = 72,
	[8] = 60,
	[9] = 50,
	[10] = 20,
	[11] = 15,
	[12] = 10,
	[13] = 5,
	[14] = 2,
	[15] = 1,
}

local ownbomb2odds = {
	[1] = 5,
	[2] = 10,
	[3] = 60,
	[4] = 70,
	[5] = 100
}

local function send_to_server(name, msg)
	LOG_DEBUG("send_to_server [%s]", name)
	robot_api.send_msg(name, msg, robot_info.replace)
end

--延迟调用函数
local function delay_call(time, fun, pa)
	robot_api.register_delay_fun(time, fun, pa)
end

local function random_time(min,max)
	if test_cards_storage then
		return 0
	else	
		return math_random(min, max)
	end
end

local function dissolve_table( ... )
	send_to_server("DissolveTable", {opt = 2})
end

local function get_ready()
	send_to_server("GetReadyNtf", {})
end

local function play_card(pa)
	local cards = table.arraycopy(pa)
	local card_type = land_deal.getCardType(cards)
--	LOG_WARNING("robot [%d] play_card", robot_info.uid)
	send_to_server("PlayCard", {cards = cards, cardtype = card_type})
	-- if not removed_cards then
	-- 	land_deal.removeCards(cards, robot_info.cards)
	-- 	removed_cards = true
	-- end
	
end

local function get_master(pa)
--	LOG_WARNING("get_master:"..pa.result)
	send_to_server("GetMaster",pa);
end

local function get_rate( ... )
	local index = random_time(1,100)
	index = index > 50 and 3 or 0 
	send_to_server("SetRate",{result = index});
end

local function get_next_seatid(seatid)
	local nextseatid = seatid + 1
    if nextseatid > 3 then
        nextseatid = 1
    end
    return nextseatid
end

--[[
火箭为3分，炸弹为1分，大王1分，小王0分
则当分数 大于等于6分时抢，大于等于4分时叫地主
]]
local function set_card_score()
	local score = 0
	local turn_analayse = land_deal.getAnalyse()
	land_deal.getAnalyseCards(robot_info.cards, turn_analayse)
	if table.indexof(turn_analayse.cards[1], 515) then
		score = 1
	end

	if table.indexof(turn_analayse.cards[1], 514) then
		score = (score == 1) and 3 or 0
	end

	score = score + turn_analayse.blockcount[4] * 1

	-- for _,v in ipairs(robot_info.cards) do
	-- 	if table.indexof({102, 202, 302, 402}, v) then
	-- 		score = score + 2
	-- 	end
	-- end
	robot_info.card_score = score
	robot_info.mastered = 0
end

function server_msg.AddCard(msg)
	if msg.uid == robot_info.uid then
		if msg.count == 17 then
			robot_info.cards = table.arraycopy(msg.cards)
			set_card_score()
		else
			table.mergeByAppend(robot_info.cards, msg.cards)
		end
	else
		other_info = other_info or {}
		other_info[msg.seatid] = other_info[msg.seatid] or {}
		other_info[msg.seatid].uid = msg.uid
		other_info[msg.seatid].cardnum = (other_info[msg.seatid].cardnum or 0) + msg.count
	end
--	PRINT_T(other_info)
	uid_2_seatid = uid_2_seatid or {}
	uid_2_seatid[msg.uid] = msg.seatid
end

function server_msg.PushDissolveTable(msg)
	if not content_dissolve then
		delay_call(random_time(3,10), dissolve_table)
		content_dissolve = true
	end
end

function server_msg.GameLandResume(msg)
	-- body
end

function server_msg.GameResult(msg)
	delay_call(random_time(3,10), get_ready)
end

function server_msg.PlayCard(msg)
	if #msg.cards > 0 and msg.uid ~= robot_info.uid then
		turn_info.winner = uid_2_seatid[msg.uid]
		turn_info.cards = msg.cards
		-- PRINT_T(msg)
		-- PRINT_T(other_info)
		other_info[uid_2_seatid[msg.uid]].cardnum = other_info[uid_2_seatid[msg.uid]].cardnum - #msg.cards
	else
		if msg.uid == robot_info.uid and not removed_cards then
			land_deal.removeCards(msg.cards, robot_info.cards)
		--	removed_cards = true
		end
		if get_next_seatid(uid_2_seatid[msg.uid]) == turn_info.winner then
			table.clear(turn_info)
		end
	end
--	LOG_WARNING("after play_card [%d]cardnum:%d", robot_info.uid, #robot_info.cards)
end

function server_msg.AskPlayCard(msg)
	if msg.seatid == robot_info.seatid then
		--special_rule特殊规则
		--当自己是地主，此时若有农民只剩一张牌则若出牌则尽量不出单张,出单张从大到小出，若跟牌，跟最大牌，special_rule=1
		--当自己是农民，此时若下一家是地主只剩一张牌则若出牌则尽量不出单张,出单张从大到小出，若跟牌，跟最大牌，special_rule=2
		--当自己是农民，此时若队友只剩一张牌则若出牌则尽量出单张，若跟牌且上家出的单牌则不跟special_rule=3
		--当队友是自己下家 且队友手上只有一张牌 而自己手上有小于等于5的牌 则有炸就炸special_rule=4

		local special_rule = 0
		if robot_info.master == robot_info.seatid then
			for k,v in pairs(other_info) do
				if v.cardnum == 1 then
					special_rule = 1
					break
				end
			end
		else
			if other_info[robot_info.teammate].cardnum == 1 and #(turn_info.cards or {}) == 1 then
				special_rule = 3
			end
			if get_next_seatid(msg.seatid) == robot_info.master and other_info[robot_info.master].cardnum == 1 then
				special_rule = 2
			end
			if get_next_seatid(msg.seatid) == robot_info.teammate and other_info[robot_info.teammate].cardnum == 1 then
				special_rule = 4
			end
		end
	
		local outcards = land_deal.searchCards(robot_info.cards, turn_info.cards or {}, special_rule)
		
		if turn_info.winner and #outcards > 0 and #outcards ~= #robot_info.cards then    
			if turn_info.winner == robot_info.teammate then
				--队友打出的牌是除了单牌及对子以外的牌型，则选择PASS。 
				--当手中没有相应牌跟时，如果是本方人员出的牌，PASS   
				if #turn_info.cards > 2 or #outcards ~= #turn_info.cards then
					table.clear(outcards)
				elseif special_rule < 1 then
					if #turn_info.cards == 1 then
						if land_deal.getCardLogicValue(outcards[1]) > 14 then
							table.clear(outcards)
						end
					else
						if land_deal.getCardLogicValue(outcards[1]) > 13 then
							table.clear(outcards)
						end
					end
				end
			else
				local card_type = land_deal.getCardType(outcards)
				local cards_num = #robot_info.cards
				local opp_card_num = other_info[turn_info.winner].cardnum
				--对手出的牌 当需要炸弹来压的时候 做一个权重概率随机
				if (card_type == land_deal.CT_MISSILE_CARD and cards_num > 5) or 
				   (card_type == land_deal.CT_BOMB_CARD and cards_num > 7) then
				   	local analayse_data = land_deal.getAnalyse()
					land_deal.getAnalyseCards(robot_info.cards, analayse_data)
				   	local bomb_nums = analayse_data.blockcount[4] or 0
					local bomb_odds = ownbomb2odds[bomb_nums] or 0
					
					opp_card_num = (opp_card_num > 15) and 15 or (opp_card_num < 5 and 5 or opp_card_num)
					local remain_odds =  remain2odds[opp_card_num] or 0
					local random_num = math.random(100)
					-- PRINT_T(other_info)
					-- PRINT_T(turn_info)
				--	LOG_WARNING("bomb_nums[%d] opp_card_num[%d] bomb_odds[%d] remain_odds[%d] totalodds[%d] random[%d]", 
					--			bomb_nums, opp_card_num, bomb_odds, remain_odds,remain_odds+bomb_odds,  random_num	)
					if random_num > (bomb_odds + remain_odds) then
						table.clear(outcards)
					end
				end
				
				if #outcards == 1 and outcards[1] == 515 then
					if opp_card_num > 10 then
						table.clear(outcards)
					end
				end
			end
		end
		local delay_time = random_time(2,4)
		if robot_info.replace then
			delay_time = 1
		end
		delay_call(delay_time, play_card, outcards)
		removed_cards = false
	end
end

function server_msg.LandTrusteeship(msg)
	-- body
end

function server_msg.SetMaster(msg)
	if msg.uid == robot_info.uid then
		robot_info.master = robot_info.seatid
		robot_info.teammate = -1
	else
		for seatid,v in pairs(other_info) do
			if v.uid == msg.uid then
				robot_info.master = seatid
			else
				robot_info.teammate = seatid
			end
		end
	end
end

function server_msg.StartRound(msg)
	table.clear(turn_info)
	robot_info.cards = nil
	robot_info.mastered = nil
	other_info = nil
end

function server_msg.AskMaster(msg)
	-- PRINT_T(msg, uid)
	-- PRINT_T(robot_info)
	if msg.seatid and robot_info.seatid == msg.seatid then
--		LOG_WARNING("robot score:"..robot_info.card_score)
		local master_msg = {result = 0}
		if (robot_info.card_score and robot_info.card_score >= QIANGDIZHU) or 
		  (robot_info.mastered and robot_info.mastered == 0 and robot_info.card_score >= JIAODIZHU) then
			master_msg.result = 1
			robot_info.mastered = 1
		end 
		if test_cards_storage then
			if robot_info.uid == 1 then
				master_msg.result = 1
			else
				master_msg.result = 0
			end
		end
		delay_call(random_time(1,3), get_master, master_msg)
	end
end

function server_msg.AskRate(msg)
	-- if robot_info.uid == uid then
	-- 	delay_call(random_time(1,3), get_rate)
	-- end
end

function server_msg.GetMaster(msg)
	-- body
end

function server_msg.SetRate(msg)
	-- body
end

function server_msg.GameStart(msg)
	-- body
end

function server_msg.GameLandlordEnd(msg)
	-- body
end

function server_msg.SitdownNtf(msg)
	if msg.uid and msg.uid == robot_info.uid then
		robot_info.seatid = msg.seatid
		delay_call(random_time(1,2), get_ready)
	end
end

function server_msg.GetReadyNtf(msg)
	-- body
end

function server_msg.UpdateGoldInGame(msg)
	-- body
end

function server_msg.GameStart(msg)

end

function server_msg.init_replace_robot(msg)
	LOG_DEBUG("init replace robot")
	
	robot_info.replace = msg.uid
	robot_info.seatid = msg.seatid
	robot_info.cards = msg.cards
	robot_info.uid = msg.uid
	uid_2_seatid = uid_2_seatid or {}
	uid_2_seatid[msg.uid] = msg.seatid
--	LOG_WARNING("cardnum:"..#msg.cards)
	for k,v in ipairs(msg.other) do
		uid_2_seatid[v.uid] = v.seatid
		other_info = other_info or {}
		other_info[v.seatid] = {cardnum=v.cardnum, uid=v.uid}
		if msg.master ~= msg.uid and msg.master ~= v.uid then
			robot_info.teammate = v.seatid
		end
	end
	robot_info.master = uid_2_seatid[msg.master]
	removed_cards = false
end

function ai_mgr.init(api, uid, gameid, gold)
	if gold == 11223344 then
		test_cards_storage = true
		LOG_WARNING("test_cards_storage")
	end
	robot_api = api
	robot_info = robot_info or {}
	robot_info.uid = uid
	LOG_DEBUG("robot uid[%d]", robot_info.uid)
end

function ai_mgr.dispatch(name, msg)
	local f = server_msg[name]
	if f then
		f(msg)
	else
		LOG_DEBUG("no matching function deal server msg[%s] !!!!!!!!!!!", tostring(name))
	end
end

function ai_mgr.free()
	robot_info = nil
end

return ai_mgr