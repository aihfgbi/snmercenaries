local this = {}
local tinsert = table.insert
local tremove = table.remove
local tremovebyvalue = table.removebyvalue
local tindexof = table.indexof
local mrandom = math.random

local logic_2_reality = {
	[3] = {103, 203, 303, 403,103, 203, 303, 403},
	[4] = {104, 204, 304, 404,104, 204, 304, 404},
	[5] = {105, 205, 305, 405,105, 205, 305, 405},
	[6] = {106, 206, 306, 406,106, 206, 306, 406},
	[7] = {107, 207, 307, 407,107, 207, 307, 407},
	[8] = {108, 208, 308, 408,108, 208, 308, 408},
	[9] = {109, 209, 309, 409,109, 209, 309, 409},
	[10] = {110, 210, 310, 410,110, 210, 310, 410},
	[11] = {111, 211, 311, 411,111, 211, 311, 411},
	[12] = {112, 212, 312, 412,112, 212, 312, 412},
	[13] = {113, 213, 313, 413,113, 213, 313, 413},
	[14] = {114, 214, 314, 414,114, 214, 314, 414},
	[15] = {116, 216, 316, 416,116, 216, 316, 416},
	[16] = {521,521},
	[17] = {522,522},
}

local function insert_to_card_store(cards, store, icards)
	table.join(store, icards)
	for i=1, #icards do
		for j=1,#icards[i] do
			tremovebyvalue(cards, icards[i][j])
		end
	end
end

--value在array中的数量
function table_count(array, value)
	local sum = 0
	for i = 1, #array do
	  if array[i] == value then 
	  	sum = sum+1
	  end
	end
	return sum
end

--检出不重复的牌
local function check_norepeated(cards)
	local tmp = {}
	for i,v in ipairs(cards) do
		if (not tindexof(tmp, cards[i])) or (table_count(tmp,cards[i])==1) then
			tinsert(tmp, cards[i])
		end
	end
	return tmp
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
		local index = mrandom(1, num)
		while true do
			if (mrandom(100) > 50) and (index < 12) then
				index = index + 1
			else
				index = mrandom(1, num)
			end
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


--找出有大于num张重复的牌
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

local function combine_bomb( cards, bomb)
	local four_cards = search_same_cards(cards, 4)
	--低概率出现8个炸弹
	local bomb_num
	if mrandom(100) <= 80 then
		bomb_num = 8
	else
		bomb_num = mrandom(9,10)
	end
	local indexs = random_index(#four_cards, bomb_num)
	for i=#four_cards, 1, -1 do
		if not tindexof(indexs, i) then
			tremove(four_cards, i)
		end
	end
	for i=1, #four_cards do
		bomb[i] = {}
		local n
		local x = mrandom(100)
		if x<60 then n=4 elseif x<90 then n=5 else n=6 end
		for j=1,n do
			tinsert(bomb[i], four_cards[i])
			tremovebyvalue(cards, four_cards[i])
		end
	end
end


local function combine_bottom_cards(cards, bottom_cards)
	local bottom_num = 8
	local indexs = random_index(#cards, bottom_num)
--	PRINT_T(indexs)
	for i=#indexs, 1, -1 do
		tinsert(bottom_cards, tremove(cards, indexs[i]))
	end
end

local function combine_liandui( cards, s_cards )
	local liandui = {}
	local cards_copy = table.arraycopy(cards)

	local min_index = 0
	for m=1, 100 do
		if #liandui > 12 then break end
		local tmp_cards = check_norepeated(cards_copy)
		local list
		min_index = mrandom(3,12)
		for i=1,#tmp_cards,2 do
			-- print("i = "..i)
			if i+5 > #tmp_cards then break end
			local num = tmp_cards[i]
			if tmp_cards[i] ~= min_index then goto continue end
			list = {tmp_cards[i],tmp_cards[i+1]}
			for j=i+2, #tmp_cards,2 do
				--顺子只能到A(14) 15是2的逻辑值
				if tmp_cards[j] >= 15 then break end
				if tmp_cards[j] == num + 1 then
					tinsert(list, tmp_cards[j])
					tinsert(list, tmp_cards[j+1])
					local t = {6,8,10,12}
					table.random(t)
					if #list >=t[1] then break end
					num = tmp_cards[j]
				end
			end

			if #list>=6 then
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
			tinsert(liandui, list)
		end
	end
	for i=1,2 do
		if i>#liandui then break end
		local idx = #s_cards + 1 
		for j=#s_cards, 1, -1 do
			if liandui[i][1] > s_cards[j][1] then
				break
			end
			idx = j
		end
		table.insert(s_cards, idx, liandui[i])
	end
	for i,v in ipairs(s_cards) do
		for j,card in ipairs(v) do
			tremovebyvalue(cards, s_cards[i][j])
		end
	end
end

local function combine_3_cards( cards, three )
	local same_result = search_same_cards(cards, 3)
	-- PRINT_T(same_result)
	local tmp = {}
	local cnt = 1
	for i, v in ipairs(same_result) do
		if cnt >5 then break end
		tmp[i] = {}
		for j=1,3 do
			tinsert(tmp[i], v)
		end
		cnt = cnt + 1
	end
	-- LOG_DEBUG("3_cards [%d]", cnt - 1)
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

local function random_pidx(min, max)
	return max and mrandom(min, max) or mrandom(min)
end

local function dispatch_bomb(bomb, hands, prior)
	if not next(bomb) then return end
	local pidx
	if prior then
		if tindexof(hands[1],16) and tindexof(hands[1], 17) then
			pidx = random_pidx(1,3)
		else
			table.join(hands[1], tremove(bomb))
			pidx = 1
		end
	else
		pidx = random_pidx(3)
	end
	for i=#bomb, 1, -1 do
		table.join(hands[pidx%4+1],tremove(bomb))
		pidx = pidx + 1
	end
end

local function dispatch_LianDui(liandui, hands, prior)
	local pidx = random_pidx(4)
	for i=#liandui, 1, -1 do
		table.join(hands[pidx%4+1],tremove(liandui))
		pidx = pidx + 1
	end
end

local function dispatch_three(three, hands, prior)
	local pidx
	if prior then
		pidx = 4
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
			pidx = 4
		end
		if #hands[pidx%4+1] + 3 <= 25 then
			table.join(hands[pidx%4+1],tremove(three))
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
		if #hands[pidx%3+1] + 2 <= 25 then
			table.join(hands[pidx%3+1],tremove(two))
		end 
		pidx = pidx + 1
		
	end
end

local function dispatch_single(single, hands, prior)
	local pidx = get_less_idx(hands) + 2
	for i=1, 100 do
		if not next(single) then break end
		if #hands[pidx%4+1] + 1 <= 25 then
			tinsert(hands[pidx%4+1],tremove(single))
		end  
		pidx = pidx + 1
	end
end

local function dispatch_cards(store, hands, prior)
	dispatch_bomb(store.bomb, hands, prior)
	-- PRINT_T(hands)
	dispatch_LianDui(store.LianDui, hands, prior)

	dispatch_three(store.three, hands, prior)

	dispatch_two(store.double, hands, prior)
	-- PRINT_T(store)
	--当有3张或2张没有发完是需加到当中
	if next(store.three) then 
		for i=#store.three, 1, -1 do
			table.join(store.single, tremove(store.three))
		end
	end
	if next(store.double) then 
		for i=#store.double, 1, -1 do
			table.join(store.single, tremove(store.double))
		end
	end
	-- PRINT_T(store)
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

function this.build_land_cards(prior)
	--LOG_DEBUG("prior[%s]", tostring(prior))
	local logic_cards = {}
	local bottom_cards = {}
	local card_store = {
		bottom = {},
		bomb = {},
		LianDui = {},
		three = {},
		double = {},
		single = {},
	}
	local player_cards = {{},{},{},{}}
	for i=1,8 do
		for k=3,15 do
			tinsert(logic_cards, k)
		end
	end
	table.sort(logic_cards)
	tinsert(logic_cards, 16)
	tinsert(logic_cards, 16)
	tinsert(logic_cards, 17)
	tinsert(logic_cards, 17)
	--炸弹
	combine_bomb(logic_cards, card_store.bomb)
	--底牌
	combine_bottom_cards(logic_cards, card_store.bottom)
	-- PRINT_T(card_store)
	--连对
	combine_liandui(logic_cards, card_store.LianDui)
	-- PRINT_T(card_store)
-- 	--3张
	combine_3_cards(logic_cards, card_store.three)
	-- PRINT_T(card_store)
-- 	--对子
	combine_2_cards(logic_cards, card_store.double)
		-- PRINT_T(card_store)
-- 	--单张
	combine_single(logic_cards, card_store.single)
	-- PRINT_T(card_store)
	dispatch_cards(card_store, player_cards, prior)
	build_card(player_cards, card_store.bottom)
-- 	-- PRINT_T(card_store)
-- 	-- PRINT_T(player_cards)
	return player_cards, card_store.bottom
end

return this