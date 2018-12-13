--[[
	根据规则组合牌

]]
local this = {}
local tinsert = table.insert
local tremove = table.remove
local tremovebyvalue = table.removebyvalue
local tindexof = table.indexof
local mrandom = math.random

local logic_2_reality = {
	[3] = {103, 203, 303, 403},
	[4] = {104, 204, 304, 404},
	[5] = {105, 205, 305, 405},
	[6] = {106, 206, 306, 406},
	[7] = {107, 207, 307, 407},
	[8] = {108, 208, 308, 408},
	[9] = {109, 209, 309, 409},
	[10] = {110, 210, 310, 410},
	[11] = {111, 211, 311, 411},
	[12] = {112, 212, 312, 412},
	[13] = {113, 213, 313, 413},
	[14] = {101, 201, 301, 401},
	[15] = {102, 202, 302, 402},
	[16] = {514},
	[17] = {515},
}

--检出不重复的牌
local function check_norepeated(cards)
	local tmp = {}
	for i,v in ipairs(cards) do
		if not tindexof(tmp, cards[i]) then
			tinsert(tmp, cards[i])
		end
	end
	return tmp
end

local function insert_to_card_store(cards, store, icards)
	table.join(store, icards)
	for i=1, #icards do
		for j=1,#icards[i] do
			tremovebyvalue(cards, icards[i][j])
		end
	end
end

--插入到玩家手牌中
local function insert_to_hands(cards, hands, icards)
	local pidx
	for i=1, #icards do
		pidx = #hands[1] > #hands[2] and 2 or 1
		pidx = #hands[3] > #hands[pidx] and pidx or 3
		if #hands[pidx] + #icards[i] > 17 then
			return 
		end
		table.join(hands[pidx], icards[i])
		for j=1,#icards[i] do
			tremovebyvalue(cards, icards[i][j])
		end
	end
end

--从1-num中随机cnt个不同的数
local function random_index(num, cnt)
	local indexs = {}
	if cnt <= 0 then return indexs end
	if cnt >= num then
		for i=1, num do
			tinsert(indexs, i)
		end
	else
		while true do
			local index = mrandom(1, num)
		--	indexs[index] = index
			if not tindexof(indexs, index) then
				tinsert(indexs, index)
			end
			if table.len(indexs) == cnt then
				break
			end
		end
	end
	
	table.sort(indexs)
	return indexs
end

--找出有num张重复的牌
local function search_same_cards(cards, num)
	local val = 0
	local cnt = 0
	local ret = {}
	for i,v in ipairs(cards) do
		if val ~= v then
			val = v
			cnt = 1
		else
			cnt = cnt + 1
			if cnt == num then
				tinsert(ret, v)
			end
		end
	end
	return ret
end

local function combine_bottom_cards(cards, bottom_cards)
	local bottom_num = 3
	local indexs = random_index(#cards, bottom_num)
--	PRINT_T(indexs)
	for i=#indexs, 1, -1 do
		tinsert(bottom_cards, tremove(cards, indexs[i]))
	end
end

local function combine_joker(cards, joker)
	local len = #cards
	for i=1,2 do
		if cards[len] < 16 then
			break
		end
		tinsert(joker, tremove(cards))
		len = len - 1
	end
	table.sort(joker)
end
--这里是遍历牌库 还有一种见combine_bomb_with_bottom
local function combine_bomb( cards, bomb)
	-- local val = 0
	-- local cnt = 0
	local four_cards = search_same_cards(cards, 4)
	--90%概率不能組成2的炸彈
	if math.random(100) > 10 then
		for i=1,#four_cards do
			if four_cards[i] == 15 then
				table.remove(four_cards, i)
				break
			end
		end
	end

--	PRINT_T(four_cards)
	--低概率出现8个炸弹
	local bomb_num
	local random_num = mrandom(100)
	if random_num <= 1 then
		bomb_num = 8
	elseif random_num <= 3 then
		bomb_num = 6
	elseif random_num <= 6 then
		bomb_num = 5
	else
		bomb_num = mrandom(2,4)
	end
	
	
--	PRINT_T(four_cards)
	local indexs = random_index(#four_cards, bomb_num)
	-- PRINT_T(four_cards)
	-- PRINT_T(indexs)
	LOG_DEBUG("bomb_num[%d]", #indexs)
--	PRINT_T(indexs)
	for i=#four_cards, 1, -1 do
		if not tindexof(indexs, i) then
			tremove(four_cards, i)
		end
	end
--	PRINT_T(four_cards)
	local pindex
	local len = #indexs

	for i=1, #four_cards do
		bomb[i] = {}
		for j=1,4 do
			tinsert(bomb[i], four_cards[i])
		end
		tremovebyvalue(cards, four_cards[i], 1)
	--	tremovebyvalue(indexs, indexs[i])
		
		-- len = len - 1
	end

end

-- local function combine_bomb_with_bottom( cards, hands, bottom )
-- 	local four_cards = {}
-- 	for i=3,15 do
-- 		if not tindexof(bottom, i) then
-- 			tinsert(four_cards, i)
-- 		end
-- 	end
-- 	PRINT_T(four_cards)
-- end

local function combine_straight( cards, s_cards )
	local straight = {}
	local cards_copy = table.arraycopy(cards)

	local min_index = 0
	for m=1, 100 do
		if #straight > 10 then break end
--	for m=1, 100 do
		local tmp_cards = check_norepeated(cards_copy)
	--	PRINT_T(tmp_cards)
		local list
	--	PRINT_T(tmp_cards)
		min_index = mrandom(3,10)
	--	LOG_DEBUG("min_index:"..min_index)
		for i, v in ipairs(tmp_cards) do
		--	LOG_DEBUG("i = "..i)
			if i + 4 > #tmp_cards then break end
			local num = v
			
			
			if v ~= min_index then goto continue end
		--	if num < min_index + 2 then goto continue end
			list = {v}
			for j=i+1, #tmp_cards do
			--	LOG_DEBUG("i = %d j = %d", i, j)
				--顺子只能到A(14) 15是2的逻辑值
				if tmp_cards[j] >= 15 then break end
				if tmp_cards[j] == num + 1 then
					tinsert(list, tmp_cards[j])
					if #list >=5 then break end
					num = tmp_cards[j]
				end
			end

			if #list>=5 then
			--	tinsert(straight, list)
				for i,v in ipairs(list) do
					tremovebyvalue(cards_copy, v)
				end
			--	min_index = list[1]
				break
			else
				list = nil
			end
			::continue::
		end

		if list then
			tinsert(straight, list)
		-- else
		-- 	break
		end
	end
--	PRINT_T(straight)
	LOG_DEBUG("find %d straight", #straight)
	local straight_num = mrandom(4) - 1
	LOG_DEBUG("random_straight_num:"..straight_num)
	for i=1, straight_num do
		if i>#straight then break end
		local idx = #s_cards + 1 
		for j=#s_cards, 1, -1 do
			if straight[i][1] > s_cards[j][1] then
				break
			end
			idx = j
		end
		table.insert(s_cards, idx, straight[i])
	end

	for i,v in ipairs(s_cards) do
		for j,card in ipairs(v) do
			tremovebyvalue(cards, s_cards[i][j])
		end
	end
	LOG_DEBUG("conbine [%d] straight", #s_cards)
end

local function move_2_to_single(cards, single)
	for i=#cards, 1, -1 do
		if cards[i] == 15 then
			table.insert(single, table.remove(cards, i))
		end
	end
end

local function combine_3_cards( cards, three )
	local same_result = search_same_cards(cards, 3)
--	PRINT_T(same_result)
	local tmp = {}
	local cnt = 1
	for i, v in ipairs(same_result) do
		if cnt >2 then break end
		tmp[i] = {}
		for j=1,3 do
			tinsert(tmp[i], v)
		end
		cnt = cnt + 1
	end
	LOG_DEBUG("3_cards [%d]", cnt - 1)
--	insert_to_hands(cards, hands, tmp)
	insert_to_card_store(cards, three, tmp)
end

local function combine_2_cards( cards, two )
	local same_result = search_same_cards(cards, 2)
	local tmp = {}
	local cnt = 1
	for i, v in ipairs(same_result) do
		if cnt > 4 then break end
		tmp[i] = {}
		for j=1,2 do
			tinsert(tmp[i], v)
		end
		cnt = cnt + 1
	end
	LOG_DEBUG("2_cards [%d]", cnt - 1)
--	insert_to_hands(cards, hands, tmp)
	insert_to_card_store(cards, two, tmp)
--	PRINT_T(same_result)
end

local function combine_single( cards, single )
	local copy_cards = table.arraycopy(cards)
	local len = #copy_cards
	for i=#cards, 1, -1 do
		table.insert(single, table.remove(cards, i))
	end
	table.sort(single)
end

local function random_pidx(min, max)
	return max and mrandom(min, max) or mrandom(min)
end

--获得手牌手最少的idx
local function get_less_idx(hands)
	local idx = 1
	local min = #hands[idx]
	for i=2,#hands do
		if #hands[i] < min then
			min = #hands[i]
			idx = i
		end
	end
	return idx
end

local function dispatch_joker(joker, hands, prior)
	local has_prior
	while next(joker) do
		if prior and not has_prior then
			tinsert(hands[1], tremove(joker))
			has_prior = true
		else
			tinsert(hands[random_pidx(3)], tremove(joker))
		end
	end
end

local function dispatch_straight(straight, hands, prior)
	local pidx = random_pidx(3)
	for i=#straight, 1, -1 do
		table.join(hands[pidx%3+1],tremove(straight))
		pidx = pidx + 1
	end
end

local function dispatch_bomb(bomb, hands, prior)
	if not next(bomb) then return end
	local pidx
	if prior then
		if tindexof(hands[1],16) and tindexof(hands[1], 17) then
			pidx = random_pidx(1,2)
		else
			-- if not hands[1] then
			-- 	PRINT_T(hands)
			-- end
			-- PRINT_T(bomb)
			table.join(hands[1], tremove(bomb))
			pidx = 1
		end
	else
		pidx = random_pidx(3)
	end

	for i=#bomb, 1, -1 do
		table.join(hands[pidx%3+1],tremove(bomb))
		pidx = pidx + 1
	end
end

local function dispatch_three(three, hands, prior)
	local pidx
	if prior then
		pidx = 3
	else
		pidx = get_less_idx(hands) + 2
	end

	-- 确保所有的3张都能发到玩家手中，之所以不用while循环是防止当
	-- 每个玩家只缺1张获2张牌时，此时用while会陷入死循环
	for i=1, 100 do
		if not next(three) then
			break
		end
		if prior then
			pidx = 3
		end
		if #hands[pidx%3+1] + 3 <= 17 then
			table.join(hands[pidx%3+1],tremove(three))
		end 
		pidx = pidx + 1
		
	end
end

local function dispatch_two(two, hands, prior)
	local pidx = get_less_idx(hands) + 2
	--确保所有的3张都能发到玩家手中，之所以不用while循环是防止当
	--每个玩家只缺1张获2张牌时，此时用while会陷入死循环
	for i=1, 100 do
		if not next(two) then
			break
		end
		if #hands[pidx%3+1] + 2 <= 17 then
			table.join(hands[pidx%3+1],tremove(two))
		end 
		pidx = pidx + 1
		
	end
end

local function dispatch_single(single, hands, prior)
	local pidx = get_less_idx(hands) + 2
	for i=1, 100 do
		if not next(single) then break end
		if #hands[pidx%3+1] + 1 <= 17 then
			tinsert(hands[pidx%3+1],tremove(single))
		end  
		pidx = pidx + 1
		
	end
end

--分发牌组
local function dispatch_cards(store, hands, prior)
	dispatch_joker(store.joker, hands, prior)
	dispatch_straight(store.straight, hands, prior)

	dispatch_bomb(store.bomb, hands, prior)

	dispatch_three(store.three, hands, prior)

	dispatch_two(store.two, hands, prior)
	
	--当有3张或2张没有发完是需加到当中
	if next(store.three) then 
		for i=#store.three, 1, -1 do
			table.join(store.single, tremove(store.three))
		end
	end
	if next(store.two) then 
		for i=#store.two, 1, -1 do
			table.join(store.single, tremove(store.two))
		end
	end
	dispatch_single(store.single, hands, prior)
end

local function build_card(hands, bottom)
	local reality_cards = table.deepcopy(logic_2_reality)
	local index
	for i,v in ipairs(hands) do
		for k,v in ipairs(v) do
			index = hands[i][k]
			hands[i][k] = tremove(reality_cards[index], mrandom(#reality_cards[index]))
		end
	end

	for i,v in ipairs(bottom) do
		index = bottom[i]
		bottom[i] = tremove(reality_cards[index], mrandom(#reality_cards[index]))
	end
end

--@param:prior 是否需要提高hands[1]都胜率
function this.build_land_cards(prior)
	LOG_DEBUG("prior[%s]", tostring(prior))
	local logic_cards = {}
	local bottom_cards = {}
	local card_store = {
		bottom = {},
		joker = {},
		straight = {},
		bomb = {},
		three = {},
		two = {},
		single = {}
	}
	local player_cards = {{},{},{}}
	for i=1,4 do
		for k=3,15 do
			tinsert(logic_cards, k)
		end
	end
	table.sort(logic_cards)
	tinsert(logic_cards, 16)
	tinsert(logic_cards, 17)
	--底牌
	combine_bottom_cards(logic_cards, card_store.bottom)
--	LOG_DEBUG("bottom card[%d][%d][%d]", bottom_cards[1], bottom_cards[2], bottom_cards[3])
--	PRINT_T(bottom_cards)
	--大小王
	combine_joker(logic_cards, card_store.joker)
--	LOG_DEBUG("remain cards num:%d", #logic_cards)
	--顺子
	combine_straight(logic_cards, card_store.straight)
	--炸弹
	combine_bomb(logic_cards, card_store.bomb)
	--組完炸彈后若还有2则统统移动到单排中
	move_2_to_single(logic_cards, card_store.single)
	
	--3张
	combine_3_cards(logic_cards, card_store.three)
	--对子
	combine_2_cards(logic_cards, card_store.two)
	
	--单张
	combine_single(logic_cards, card_store.single)
--	PRINT_T(card_store)
	dispatch_cards(card_store, player_cards, prior)
	build_card(player_cards, card_store.bottom)
	-- PRINT_T(card_store)
	-- PRINT_T(player_cards)
	return player_cards, card_store.bottom
end

return this