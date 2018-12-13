local tindexof = table.indexof
local tinsert = table.insert
local tremove = table.remove
local tmerge_by_append = table.mergeByAppend

local cardTool = {}

cardTool.CT_ERROR = 0			--错误类型
cardTool.CT_SINGLE = 1			--单牌类型
cardTool.CT_DOUBLE = 2			--对牌类型
cardTool.CT_THREE = 3			--三条类型
cardTool.CT_THREE_TAKE_ONE = 4	--三带一单
cardTool.CT_THREE_TAKE_TWO = 5	--三带一对
cardTool.CT_SINGLE_LINE = 6		--单连类型
cardTool.CT_BOMB_CARD = 7		--炸弹类型
cardTool.CT_MISSILE_CARD = 8	--火箭类型
cardTool.CT_DOUBLE_LINE = 9		--对连类型
cardTool.CT_THREE_LINE = 10		--飞机不带
cardTool.CT_THREE_LINE_ONE = 11		--飞机带单
cardTool.CT_THREE_LINE_TWO = 12		--飞机带双
cardTool.CT_FOUR_TAKE_ONE = 13	--四带两单
cardTool.CT_FOUR_TAKE_TWO = 14	--四带两对

--当队友的牌(单、对、三)大于这个逻辑值 则直接pass
local PASS_LIMIT_CARD = 12

--[[
analayse_data = {
 	"blockcount" = {
         1 = 13
         2 = 5
         3 = 2
         4 = 0
     }
     "cards" = {
         1 = {
             1 = 515
             2 = 514
             3 = 202
             4 = 201
             5 = 113
             6 = 112
             7 = 211
             8 = 210
             9 = 108
             10 = 107
             11 = 206
             12 = 305
             13 = 104
         }
         2 = {
             1 = 313
             2 = 113
             3 = 312
             4 = 112
             5 = 310
             6 = 210
             7 = 208
             8 = 108
             9 = 307
             10 = 107
         }
         3 = {
             1 = 412
             2 = 312
             3 = 112
             4 = 408
             5 = 208
             6 = 108
         }
         4 = {
         }
     }

}

]]


--获得牌的数值（1 -- 13）
function cardTool.getCardValue(card)
--    return card - math.floor(card/100)*100
	return card % 100
end

--获得牌的颜色（0 -- 4）
function cardTool.getCardColor(card)
	return math.floor(card/100)
end

--获取牌的逻辑数值(3-17)
function cardTool.getCardLogicValue(card)
	local value = cardTool.getCardValue(card)
	local color = cardTool.getCardColor(card)
	if value <=0 or value > 15 then
		return 0
	end
	if color == 5 then
		return (value + 2)
	end
	return (value <= 2 and (value + 13) or value)
end

--排列扑克
function cardTool.sortCards(cards)
	local cardcount = #cards
	if cardcount == 0 then return end
	local cardvalues = {}
	for i = 1, cardcount do
		cardvalues[i] = cardTool.getCardLogicValue(cards[i])
	end
	
	local bSorted = false
	local cbSwitch = 0
	while (bSorted == false) do
		bSorted = true
		for i = 1, cardcount-1 do
			if cardvalues[i] < cardvalues[i+1] or (cardvalues[i] == cardvalues[i+1] and cards[i] < cards[i+1]) then
				bSorted = false
				--扑克数据
				cbSwitch=cards[i]
				cards[i]=cards[i+1]
				cards[i+1]=cbSwitch

				--排序值
				cbSwitch=cardvalues[i]
				cardvalues[i]=cardvalues[i+1]
				cardvalues[i+1]=cbSwitch
			end
		end
		cardcount = cardcount - 1
	end

end

--排列扑克
function cardTool.sortOutCards(cards)
	--获取牌型
	local cardtype = cardTool.getCardType(cards)
	if cardtype == cardTool.CT_THREE_TAKE_ONE or cardtype == cardTool.CT_THREE_TAKE_TWO then
		--分析牌
		local analayse_data = cardTool.getAnalyse()
		cardTool.getAnalyseCards(cards, analayse_data)
		local tmpcards = {}
		for i = 1, #(analayse_data.cards[3]) do
			table.insert(tmpcards, analayse_data.cards[3][i])
		end
		for i = 1, 4 do
			while true do
				if i == 3 then break end
				if analayse_data.blockcount[i] > 0 then
					for j = 1, #(analayse_data.cards[i]) do
						table.insert(tmpcards, analayse_data.cards[i][j])
					end
				end
				break
			end
		end
		cards = tmpcards
	elseif cardtype == cardTool.CT_FOUR_TAKE_ONE or cardtype == cardTool.CT_FOUR_TAKE_TWO then
		--分析牌
		local analayse_data = cardTool.getAnalyse()
		cardTool.getAnalyseCards(cards, analayse_data)
		local tmpcards = {}
		for i = 1, #(analayse_data.cards[4]) do
			table.insert(tmpcards, analayse_data.cards[4][i])
		end
		for i = 1, 4 do
			while true do
				if i == 4 then break end
				if analayse_data.blockcount[i] > 0 then
					for j = 1, #(analayse_data.cards[i]) do
						table.insert(tmpcards, analayse_data.cards[i][j])
					end
				end
				break
			end
		end
		cards = tmpcards
	end
end

--获取类型
function cardTool.getCardType(cards)
	local cardcount = #cards
	cardTool.sortCards(cards)
	if cardcount == 0 then		--空牌
		return cardTool.CT_ERROR
	elseif cardcount == 1 then	--单牌
		return cardTool.CT_SINGLE
	elseif cardcount == 2 then
		if cards[1] == 515 and cards[2] == 514 then	--火箭
			return cardTool.CT_MISSILE_CARD
		end
		if cardTool.getCardLogicValue(cards[1]) == cardTool.getCardLogicValue(cards[2]) then	--对子
			return cardTool.CT_DOUBLE
		end
		return cardTool.CT_ERROR
	end

	local analayse_data = cardTool.getAnalyse()
	cardTool.getAnalyseCards(cards, analayse_data)
	--四牌判断
	if analayse_data.blockcount[4] > 0 then
		if analayse_data.blockcount[4] == 1 and cardcount == 4 then return cardTool.CT_BOMB_CARD end	--炸弹
		if analayse_data.blockcount[4] == 1 and cardcount == 6 then return cardTool.CT_FOUR_TAKE_ONE end	--四带两张
		if analayse_data.blockcount[4] == 1 and cardcount == 8 and analayse_data.blockcount[2] == 2 then return cardTool.CT_FOUR_TAKE_TWO end	--四带两对
		return cardTool.CT_ERROR
	end
--	PRINT_T(analayse_data)
	--三牌判断
	if analayse_data.blockcount[3] > 0 then
		--连牌判断
		if analayse_data.blockcount[3] > 1 then
			local card = analayse_data.cards[3][1]
			local cardvalue = cardTool.getCardLogicValue(card)

			if cardvalue >= 15 then return cardTool.CT_ERROR end

			for i = 2, analayse_data.blockcount[3] do
				card = analayse_data.cards[3][i * 3]
				if cardvalue ~= (cardTool.getCardLogicValue(card) + i - 1) then return cardTool.CT_ERROR end
			end
		elseif cardcount == 3 then
			return cardTool.CT_THREE
		elseif cardcount == 4 then
			return cardTool.CT_THREE_TAKE_ONE
		elseif cardcount == 5 then
			if analayse_data.blockcount[2] == 1 then
				return cardTool.CT_THREE_TAKE_TWO
			else
				return cardTool.CT_ERROR
			end
		end

		if analayse_data.blockcount[3] * 3 == cardcount then return cardTool.CT_THREE_LINE end	--三连飞机
		if analayse_data.blockcount[3] * 4 == cardcount then return cardTool.CT_THREE_LINE_ONE end	--三带一张飞机
		if analayse_data.blockcount[3] * 5 == cardcount then 
			if analayse_data.blockcount[2] == 2 then
				--三带一对飞机
				return cardTool.CT_THREE_LINE_TWO 
			end
			
		end	

		return cardTool.CT_ERROR
	end
--	PRINT_T(analayse_data)
	--两张判断
	if analayse_data.blockcount[2] >= 3 then
		local card = analayse_data.cards[2][1]
		local cardvalue = cardTool.getCardLogicValue(card)

		if cardvalue >= 15 then return cardTool.CT_ERROR end

		for i = 2, analayse_data.blockcount[2] do
			card = analayse_data.cards[2][i * 2]
			if cardvalue ~= (cardTool.getCardLogicValue(card) + i - 1) then return cardTool.CT_ERROR end
		end

		if analayse_data.blockcount[2] * 2 == cardcount then return cardTool.CT_DOUBLE_LINE end

		return cardTool.CT_ERROR
	end
--	PRINT_T(analayse_data, cardcount)
	--单张判断
	if analayse_data.blockcount[1] >= 5 and analayse_data.blockcount[1] == cardcount then
		local card = analayse_data.cards[1][1]
		local cardvalue = cardTool.getCardLogicValue(card)

		if cardvalue >= 15 then return cardTool.CT_ERROR end
		
		for i = 2, analayse_data.blockcount[1] do
			card = analayse_data.cards[1][i]
			if cardvalue ~= (cardTool.getCardLogicValue(card) + i - 1) then 
				return cardTool.CT_ERROR 
			end
		end
		
		return cardTool.CT_SINGLE_LINE	--顺子
	end

	return cardTool.CT_ERROR
end

--分析结构
function cardTool.getAnalyse()
	local analayse = {}
	analayse.blockcount = {0,0,0,0}
	analayse.cards = {}
	for i = 1, 4 do
		analayse.blockcount[i] = 0
		analayse.cards[i] = {}
	end
	return analayse
end

--分析扑克
function cardTool.getAnalyseCards(cards, analayse_data)
	-- for i = 1, #cards do
	-- 	local samecount = 1
	-- 	local cardvalue = cardTool.getCardLogicValue(cards[i])
	-- 	--搜索同牌
	-- 	for j = i+1, #cards do
	-- 		if cardTool.getCardLogicValue(cards[j]) ~= cardvalue then break end
	-- 		samecount = samecount + 1
	-- 	end
	-- 	if samecount > 4 then
	-- 		analayse_data = cardTool.getAnalyse()
	-- 		return
	-- 	end
	-- 	local index = analayse_data.blockcount[samecount]
	-- 	analayse_data.blockcount[samecount] = index + 1
	-- 	for k = 1, samecount do
	-- 		analayse_data.cards[samecount][index * samecount + k] = cards[i + k - 1]
	-- 	end
	-- 	i = i + samecount - 1
	-- end
 	local data = {}

	for i=1, #cards do
		local index = cardTool.getCardLogicValue(cards[i])
		data[index] = data[index] or {}
		tinsert(data[index], cards[i])
	end
--	PRINT_T(data)
	for k,v in pairs(data) do
		local count = #v
		if count > 4 then
			analayse_data = cardTool.getAnalyse()
			return
		end
		analayse_data.blockcount[count] = analayse_data.blockcount[count] + 1
		tmerge_by_append(analayse_data.cards[count], v)
	end

	for i=1, 4 do
		if next(analayse_data.cards[i]) then
			cardTool.sortCards(analayse_data.cards[i])
		end
	end
end

--分布结构
function cardTool.getDistribution()
	local distribution = {}
	distribution.count = 0	--扑克数目
	distribution.struct = {}
	for i = 1, 15 do
		distribution.struct[i] = {0,0,0,0,0,0}
	end
	return distribution
end

--分析分布
function cardTool.AnalyseDistribution(cards, distribution_data)
	for i = 1, #cards do
		local color = cardTool.getCardColor(cards[i])
		local value = cardTool.getCardValue(cards[i])
		distribution_data.count = distribution_data.count + 1
		distribution_data.struct[value][6] = distribution_data.struct[value][6] + 1
		distribution_data.struct[value][color] = distribution_data.struct[value][color] + 1
	end
end

--对比扑克
function cardTool.compareCard(turncards, thecards, turncount)
	local turntype = cardTool.getCardType(turncards)
	local thecount = #thecards
	local thetype = cardTool.getCardType(thecards)

	--类型判断
	if thetype == cardTool.CT_ERROR then return false end
	if thetype == cardTool.CT_MISSILE_CARD then return true end

	--炸弹判断
	if turntype ~= cardTool.CT_BOMB_CARD and thetype == cardTool.CT_BOMB_CARD then return true end
	if turntype == cardTool.CT_BOMB_CARD and thetype ~= cardTool.CT_BOMB_CARD then return false end
	--规则判断
	if turntype ~= thetype or turncount ~= thecount then return false end

	if thetype == cardTool.CT_SINGLE or thetype == cardTool.CT_DOUBLE or thetype == cardTool.CT_THREE or
		thetype == cardTool.CT_SINGLE_LINE or thetype == cardTool.CT_DOUBLE_LINE or thetype == cardTool.CT_THREE_LINE or
		thetype == cardTool.CT_BOMB_CARD then
		local turnvalue = cardTool.getCardLogicValue(turncards[1])
		local thevalue = cardTool.getCardLogicValue(thecards[1])
		return thevalue > turnvalue
	elseif thetype == cardTool.CT_THREE_TAKE_ONE or thetype == cardTool.CT_THREE_TAKE_TWO then
		local turn_analayse = cardTool.getAnalyse()
		cardTool.getAnalyseCards(turncards, turn_analayse)

		local the_analayse = cardTool.getAnalyse()
		cardTool.getAnalyseCards(thecards, the_analayse)

		local turnvalue = cardTool.getCardLogicValue(turn_analayse.cards[3][1])
		local thevalue = cardTool.getCardLogicValue(the_analayse.cards[3][1])
		return thevalue > turnvalue
	elseif thetype == cardTool.CT_FOUR_TAKE_ONE or thetype == cardTool.CT_FOUR_TAKE_TWO then
		local turn_analayse = cardTool.getAnalyse()
		cardTool.getAnalyseCards(turncards, turn_analayse)

		local the_analayse = cardTool.getAnalyse()
		cardTool.getAnalyseCards(thecards, the_analayse)

		local turnvalue = cardTool.getCardLogicValue(turn_analayse.cards[4][1])
		local thevalue = cardTool.getCardLogicValue(the_analayse.cards[4][1])
		return thevalue > turnvalue
	elseif thetype == cardTool.CT_THREE_LINE_ONE or thetype == cardTool.CT_THREE_LINE_TWO then 
		local turn_analayse = cardTool.getAnalyse()
		cardTool.getAnalyseCards(turncards, turn_analayse)

		local the_analayse = cardTool.getAnalyse()
		cardTool.getAnalyseCards(thecards, the_analayse)
		local turnvalue = cardTool.getCardLogicValue(turn_analayse.cards[3][1])
		local thevalue = cardTool.getCardLogicValue(the_analayse.cards[3][1])
		return thevalue > turnvalue
	end
	return false
end

--删除扑克
function cardTool.removeCards(removecards, playercards)
	local rcount = #removecards
	local pcount = #playercards
	
	if rcount > pcount or pcount > 20 then
		LOG_ERROR("removecnt[%s] playercnt[%s]", tostring(rcount), tostring(pcount))
		return false 
	end
	
	local tcards = playercards
	
	local deletecount = 0
	for i = 1,rcount do
		for j = 1, pcount do
			if removecards[i] == playercards[j] then
				deletecount = deletecount + 1
				playercards[j] = 0
				break
			end
		end
	end
--	LOG_DEBUG("need remove count[%d], real delete count[%d]", rcount, deletecount)
	if deletecount ~= rcount then 
		LOG_ERROR("deletecount[%s] rcount[%s]", tostring(deletecount), tostring(rcount))
		return false 
	end
	
	for i=#playercards, 1, -1 do
		if playercards[i] == 0 then
			table.remove(playercards, i)
		end
	end
	return true
end

local function find_out_cards( hand_cards, special_rule)
	local turn_analayse = cardTool.getAnalyse()
	cardTool.getAnalyseCards(hand_cards, turn_analayse)
	local tcards = turn_analayse.cards
--	PRINT_T(tcards)
	local out = {}
	--队友是自己下家 且队友手上只有一张牌 出最小的牌
	if special_rule == 4 then
		local min_logic = 100
		local min_tile
		for _,v in ipairs(hand_cards) do
			local logic_tile = cardTool.getCardLogicValue(v)
			if min_logic > logic_tile then
				min_logic = logic_tile
				min_tile = v
			end
		end
		if min_tile then
			tinsert(out, min_tile)
			return out
		end
	end

	--队友只剩一张牌,尽量出单张
	if special_rule == 3 then
		if #tcards[1] > 0 and cardTool.getCardLogicValue(tcards[1][#(tcards[1])]) < 16 then
			tinsert(out, tcards[1][#(tcards[1])])
			return out
		end
	end
	
	local function min_index(m, n)
		assert(m <= n)
		local temp_index = 0
		local min = 100 
		for i=m, n do
			local cds = tcards[i]
			if #cds > 0 then
				if cardTool.getCardLogicValue(cds[#cds]) < min then
					min = cardTool.getCardLogicValue(cds[#cds])
					temp_index = i
				end
			end
		end
		return temp_index
	end

	local function get_pairs(cds, all)
		local cpairs = {}
		if not next(cds) then return cpairs end
		local value1 = cardTool.getCardLogicValue(cds[#cds])
		local value2
		for i=#cds , 1, -1 do
			value2 = cardTool.getCardLogicValue(cds[i])
			if (value2 == value1 or (value2 - 1 == value1)) then
				if #cpairs > 0 and value2 ~= value1 and value2 > 14 then
					break
				end
				tinsert(cpairs, cds[i])
				value1 = value2
			else
				break
			end
		end
		--连队至少3对
		if #cpairs == 4 and not all then
			tremove(cpairs)
			tremove(cpairs)
		end
		return cpairs
	end

	local index = 0
	if special_rule == 1 or special_rule == 2 then
		index = min_index(2, 3)
		--没有对子或三张
		if index == 0 then
			-- if #tcards[4] > 0 then
			-- 	index = 4
			-- else
			-- --没有炸弹 出最大的单牌
			-- 	tinsert(out, tcards[1][#tcards[1]])
			-- 	return out
			-- end
			if #tcards[1] > 0 then
				if #tcards >= 2 then
					if tcards[1][1] == 515 and tcards[1][2] == 514 then
						if tcards[1][3] then
							tinsert(out, tcards[1][3])
						end
					else
						tinsert(out, tcards[1][1])
					end
				else
					tinsert(out, tcards[1][1])
				end
				if next(out) then
					return out
				end
			end
		end
	else
		index = min_index(1, 3)
	end
	local cards = tcards[index]
	
	if cards then
		if index == 1 then
			tinsert(out, tcards[index][#tcards[index]])
		elseif index == 2 then
			out = get_pairs(cards)
			
		elseif index == 3 then
			local value1 = cardTool.getCardLogicValue(cards[#cards])
			local value2
			for i=#cards , 1, -1 do
				value2 = cardTool.getCardLogicValue(cards[i])
				if value2 < 15 and (value2 == value1 or (value2 - 1 == value1)) then
					tinsert(out, cards[i])
					value1 = value2
				else
					break
				end
				if #out == 6 then break end
			end
			if #out == 3 then
				index = min_index(1,2)
				if index > 0 then
					--3带2
					local lian_dui
					if index == 2 then
						local cpairs = get_pairs(tcards[index])
						if #cpairs <= 2 then
							for i=1, 2 do
								tinsert(out, cpairs[i])
							end
						else
							lian_dui = true
						end
					else
						tinsert(out, tcards[1][#tcards[1]])
					end
					if lian_dui and #tcards[1] > 0 then
						tinsert(out, tcards[1][#tcards[1]])
					end
				end
			--飞机
			elseif #out == 6 then
				index = min_index(1, 2)
				if index > 0 then
					local no_single
					local no_pairs
					if index == 1 then
						--不能把王带出去
						if #tcards[1] >= 2 and cardTool.getCardLogicValue(tcards[1][#tcards[1]-1]) < 16  then
							tinsert(out, tcards[1][#tcards[1]])
							tinsert(out, tcards[1][#tcards[1]-1])
						else
							no_single = true
						end
					end
					if index == 2 or no_single then
						local cpairs = get_pairs(tcards[2], 1)
						if #cpairs <= 4 then
							table.mergeByAppend(out, cpairs)
						else
							no_pairs = true
						end
					end
					if index == 2 and no_pairs then
						if #tcards[1] >= 2 and cardTool.getCardLogicValue(tcards[1][#tcards[1]-1]) < 16  then
							tinsert(out, tcards[1][#tcards[1]])
							tinsert(out, tcards[1][#tcards[1]-1])
						end 
					end
				end
			end
		elseif index == 4 then
		--此时说明手牌中没有对子和三张了
			for i=#tcards[index], #tcards[index]-3, -1 do
				tinsert(out, tcards[index][i])
			end
			if #tcards[1] >= 2 then
				for i=1, 2 do
					tinsert(out, tcards[1][#tcards[1]-i+1])
				end
			end
		end
	end
	
	return out
end

--出牌搜索
function cardTool.searchCards(allcards, turncards, special_rule)
	special_rule = special_rule or 0
	--排列扑克
	cardTool.sortCards(allcards)
	cardTool.sortCards(turncards)
	local cardcount = #allcards
	local turncount = #turncards

	local resultcards = {}
	local tmpreslut = {}
	--获取类型
	local turntype = cardTool.getCardType(turncards)
--	LOG_DEBUG("===============   turn type[%d]", turntype)
	local turn_analayse = cardTool.getAnalyse()
	cardTool.getAnalyseCards(allcards, turn_analayse)
	
	if turntype == cardTool.CT_ERROR then
		local cardtype = cardTool.getCardType(allcards)
		--是否一手出完
		if cardtype ~= cardTool.CT_ERROR then
			return table.arraycopy(allcards)
		end

		resultcards = find_out_cards(allcards, special_rule)
	
		if next(resultcards) then
--			LOG_WARNING("find cards in find_out_cards")
			return resultcards
		end
		
		
		for k,v in ipairs(turn_analayse.cards) do
			if k == 4 then break end
			if #v > 0 then
				if cardTool.getCardLogicValue(v[#v]) < 14 then
					for i=1, k do
						tinsert(resultcards, v[#v+1-i])
					end
					return resultcards
				end
			end
		end
	
		for k,v in ipairs(turn_analayse.cards) do
			if k == 4 then break end
			if #v > 0 and cardTool.getCardLogicValue(v[#v]) < 16 then
				for i=1, k do
					tinsert(resultcards, v[#v+1-i])
				end
				return resultcards
			end
		end
	
		for k,v in ipairs(turn_analayse.cards) do
			if k == 1 and #v == 2 and v[1] == 515 and v[2] == 514 then

			else
				if #v > 0 then
					for i=1, k do
						tinsert(resultcards, v[#v+1-i])
					end
					return resultcards
				end
			end
			
		end


		-- --如果最小牌不是单牌，则提取
		-- local samecount = 0
		-- if cardcount > 1 and cardTool.getCardValue(allcards[cardcount]) == cardTool.getCardValue(allcards[cardcount-1]) then
		-- 	samecount = 1
		-- 	resultcards[1] = allcards[cardcount]
		-- 	local value = cardTool.getCardValue(allcards[cardcount])
		-- 	for i = cardcount - 1, 1, -1 do
		-- 		if cardTool.getCardValue(allcards[i]) == value then
		-- 			samecount = samecount + 1
		-- 			resultcards[samecount] = allcards[i]
		-- 		else
		-- 			break
		-- 		end
		-- 	end
		-- 	return resultcards	
		-- end

		-- --单牌
		-- if samecount ~= 1 then
		-- 	tmpreslut = cardTool.searchSameCard(allcards, 0 , 1)
		-- 	if #tmpreslut > 1 then
		-- 		resultcards = tmpreslut[1]
		-- 		return resultcards
		-- 	end
		-- end
		-- --对牌
		-- if samecount ~= 2 then
		-- 	tmpreslut = cardTool.searchSameCard(allcards, 0 , 2)
		-- 	if #tmpreslut > 1 then
		-- 		resultcards = tmpreslut[1]
		-- 		return resultcards
		-- 	end
		-- end
		-- --三条
		-- if samecount ~= 3 then
		-- 	tmpreslut = cardTool.searchSameCard(allcards, 0 , 3)
		-- 	if #tmpreslut > 1 then
		-- 		resultcards = tmpreslut[1]
		-- 		return resultcards
		-- 	end
		-- end
		-- --三带一
		-- tmpreslut = cardTool.searchTakeCard(allcards, 0, 3, 1)
		-- if #tmpreslut > 1 then
		-- 	resultcards = tmpreslut[1]
		-- 	return resultcards
		-- end
		-- --三带一对
		-- tmpreslut = cardTool.searchTakeCard(allcards, 0, 3, 2)
		-- if #tmpreslut > 1 then
		-- 	resultcards = tmpreslut[1]
		-- 	return resultcards
		-- end
		-- --单连
		-- tmpreslut = cardTool.searchLineCard(allcards, 0, 1, 0)
		-- if #tmpreslut > 1 then
		-- 	resultcards = tmpreslut[1]
		-- 	return resultcards
		-- end
		-- --连对
		-- tmpreslut = cardTool.searchLineCard(allcards, 0, 2, 0)
		-- if #tmpreslut > 1 then
		-- 	resultcards = tmpreslut[1]
		-- 	return resultcards
		-- end
		-- --三连
		-- tmpreslut = cardTool.searchLineCard(allcards, 0, 3, 0)
		-- if #tmpreslut > 1 then
		-- 	resultcards = tmpreslut[1]
		-- 	return resultcards
		-- end

		-- --炸弹
		-- if samecount ~= 4 then
		-- 	tmpreslut = cardTool.searchSameCard(allcards, 0 , 4)
		-- 	if #tmpreslut > 1 then
		-- 		resultcards = tmpreslut[1]
		-- 		return resultcards
		-- 	end
		-- end

		-- --搜索火箭
		-- if cardcount >= 2 and allcards[1] == 515 and allcards[2] == 514 then
		-- 	resultcards = {515, 514}
		-- 	return resultcards
		-- end
	end
	--当队友是自己下家 且队友手上只有一张牌 而自己手上有小于等于5的牌 则有炸就炸special_rule=4
	if special_rule == 4 then
		local tmp_table = {}
		for _, tile in ipairs(allcards) do
			tile_logic = cardTool.getCardLogicValue(tile)
			if tile_logic <= 5 then
				tmp_table[tile_logic] = 1
			end
		end
		local tmp_len = table.len(tmp_table)
		if tmp_len > 0 then
			if turn_analayse.blockcount[4] > 0 then
				local bomb_cnt = turn_analayse.blockcount[4]
				for i=bomb_cnt, 1, -1 do
					for j=(i-1)*4+1,(i-1)*4+4 do
						local bomb_logic = cardTool.getCardLogicValue(turn_analayse.cards[4][j])
						if tmp_len > 1 or not tmp_table[bomb_logic] then
							tinsert(resultcards, turn_analayse.cards[4][j])
						end
					end
					if next(resultcards) then
						return resultcards
					end
				end
			end

			if tindexof(allcards, 515) and tindexof(allcards, 514) then
				tinsert(resultcards, 515)
				tinsert(resultcards, 514)
				return resultcards
			end
		end
	end
	--队友只剩一张牌 且上家出的单牌则不跟
	if special_rule == 3 then
		return resultcards
	end
	
	if special_rule == 2 and turntype == cardTool.CT_SINGLE then
		local max_index = 0
		for i, tile in ipairs(allcards) do
			if cardTool.getCardLogicValue(turncards[1]) < cardTool.getCardLogicValue(tile) then
				if max_index == 0 then
					max_index = i
				else
					if cardTool.getCardLogicValue(allcards[max_index]) < cardTool.getCardLogicValue(tile) then
						max_index = i
					end
				end
			end
		end
		if max_index > 0 then
			tinsert(resultcards, allcards[max_index])
			return resultcards
		end
	end
	
	if turntype == cardTool.CT_SINGLE or turntype == cardTool.CT_DOUBLE or 
		   turntype == cardTool.CT_THREE or turntype == cardTool.CT_BOMB_CARD then
		--单牌/对牌/三条
		local refercard = turncards[1]

		local samecount = 1
		if turntype == cardTool.CT_DOUBLE then
			samecount = 2
		elseif turntype == cardTool.CT_THREE then
			samecount = 3
		elseif turntype == cardTool.CT_BOMB_CARD then
			samecount = 4
		end
		tmpreslut = cardTool.searchSameCard(allcards, refercard, samecount, true)
--		PRINT_T(tmpreslut)
		if #tmpreslut > 0 then
			--偏家只剩一张牌 跟最大牌
			if special_rule == 1 or special_rule == 2 then
				if #(tmpreslut[#tmpreslut]) == 4 then
					resultcards = table.arraycopy(tmpreslut[#tmpreslut])
				else
					for i=#tmpreslut, 1, -1 do
						if #tmpreslut[i] == samecount then
							resultcards = table.arraycopy(tmpreslut[i])
							break
						end
					end
				end
			else
				resultcards = tmpreslut[1]
			end			
			return resultcards
		end
	
	elseif turntype == cardTool.CT_SINGLE_LINE or turntype == cardTool.CT_DOUBLE_LINE or turntype == cardTool.CT_THREE_LINE then
		--单连/对连/三连
		local refercard = turncards[1]
		local blockcount = 1
		if turntype == cardTool.CT_DOUBLE_LINE then
			blockcount = 2
		elseif turntype == cardTool.CT_THREE_LINE then
			blockcount = 3
		end
		local linecount = turncount/blockcount
		tmpreslut = cardTool.searchLineCard(allcards, refercard, blockcount, linecount)
		if #tmpreslut > 1 then
			resultcards = tmpreslut[1]
			return resultcards
		end
	elseif turntype == cardTool.CT_THREE_TAKE_ONE or turntype == cardTool.CT_THREE_TAKE_TWO then
		--三带一/三带一对
		if cardcount < turncount then return resultcards end
		cardTool.sortOutCards(turncards)
		local refercard = turncards[1]
		if turncount == 4 or turncount == 5 then
			local takecount = 1
			if turntype == cardTool.CT_THREE_TAKE_TWO then takecount = 2 end
			--搜索三带牌型
			tmpreslut = cardTool.searchTakeCard(allcards, refercard, 3, takecount)
			if #tmpreslut >= 1 then
				resultcards = tmpreslut[1]
				return resultcards
			end
		else
			local takecount = 1
			if turntype == cardTool.CT_THREE_TAKE_TWO then takecount = 2 end
			local linecount = turncount / (3 + takecount)
			local tmpreslutcount = 1
			--搜索连牌
			local tmplinereslut = cardTool.searchLineCard(allcards, refercard, 3, linecount)
			if #tmplinereslut > 1 then
				--提取带牌
				for i = #tmplinereslut, 1, -1 do
					local tmpcards = {}
					--删除连牌
					for j = 1, cardcount do
						local ishave = false
						for k = 1, #(tmplinereslut[i]) do
							if allcards[j] == tmplinereslut[i][k] then
								ishave = true
								break
							end
						end
						if ishave == false then
							table.insert(tmpcards, allcards[j])
						end
					end
					--分析牌
					local analayse_data = cardTool.getAnalyse()
					cardTool.getAnalyseCards(tmpcards, analayse_data)
					--提取牌
					local distillcards = {}
					local distillcount = 0
					for j = takecount, 4 do
						local tmpblockcount = analayse_data.blockcount[j]
						if tmpblockcount > 0 then
							if j == takecount and tmpblockcount >= linecount then
								for k = (tmpblockcount - linecount) * takecount + 1, tmpblockcount * takecount do
									table.insert(distillcards, analayse_data.cards[j][k])
								end
								distillcount = takecount * linecount
							else
								for k = 1, tmpblockcount do
									for l = (tmpblockcount - k) * j + 1, (tmpblockcount - k + 1) * j do
										table.insert(distillcards, analayse_data.cards[j][l])
									end
									distillcount = distillcount + takecount
									--提取完成
									if distillcount == takecount * linecount then break end
								end
							end
						end
						--提取完成
						if distillcount == takecount * linecount then break end
					end
					--提取完成
					if distillcount == takecount * linecount then
						--复制牌
						for j = 1, #(tmplinereslut[i]) do
							table.insert(tmpreslut[tmpreslutcount],tmplinereslut[i][j])
						end
						for j = 1, #distillcards do
							table.insert(tmpreslut[tmpreslutcount],distillcards[j])
						end
						tmpreslutcount = tmpreslutcount + 1
					end
				end
				if #tmpreslut >= 1 then
					resultcards = tmpreslut[1]
					return resultcards
				end
			end
		end
	elseif turntype == cardTool.CT_FOUR_TAKE_ONE or turntype == cardTool.CT_FOUR_TAKE_TWO then
		local takecount = 1
		if turntype == cardTool.CT_FOUR_TAKE_TWO then takecount = 2 end
		cardTool.sortOutCards(turncards)
		local refercard = turncards[1]
		tmpreslut = cardTool.searchTakeCard(allcards, refercard, 4, takecount)
		if #tmpreslut >= 1 then
			resultcards = tmpreslut[1]
			return resultcards
		end
	end
	--搜索炸弹
	if cardcount >= 4 and turntype ~= cardTool.CT_MISSILE_CARD then
		local refercard = 0
		
		if turntype == cardTool.CT_BOMB_CARD then refercard = turncards[1] end
		--搜索炸弹
		
		tmpreslut = cardTool.searchSameCard(allcards, refercard, 4)
		
		if next(tmpreslut) then
			resultcards = tmpreslut[1]
			return resultcards
		end
	end
	--搜索火箭
	if turntype ~= cardTool.CT_MISSILE_CARD and cardcount >= 2 and allcards[1] == 515 and allcards[2] == 514 then
		resultcards = {515, 514}
		return resultcards
	end
	return resultcards
end

--是否和其他牌是组合(对子，三连，炸弹)
local function is_combo(analayse_data, card, blockcount)
	for i=4, blockcount+1, -1 do
		if tindexof(analayse_data.cards[i], card) then
			return true
		end
	end
	return false
end

--同牌搜索
function cardTool.searchSameCard(cards, refercard, samecount)
	--排列扑克
	cardTool.sortCards(cards)
	--分析扑克
	local analayse_data = cardTool.getAnalyse()
	cardTool.getAnalyseCards(cards, analayse_data)

	local refervalue
	if refercard == 0 then
		refervalue = 0
	else
		refervalue = cardTool.getCardLogicValue(refercard)
	end

	local result = {}
	local resultcount = 1
	local blockcount = samecount
	while (blockcount <= 4) do
		for i = 1, analayse_data.blockcount[blockcount] do
			local index = (analayse_data.blockcount[blockcount] - i) * blockcount + 1
			
			local card = analayse_data.cards[blockcount][index]
			if cardTool.getCardLogicValue(card) > refervalue and not is_combo(analayse_data, card, blockcount) then
				result[resultcount] = {}
				for j = 1, blockcount do
					table.insert(result[resultcount], analayse_data.cards[blockcount][index + j - 1])
				end
				resultcount = resultcount + 1
			end
		end
		blockcount = blockcount + 1
	end

	if #result > 0 and #result[1] > samecount then
		
		local ret = {}
		for i=1, #result do
			if i==1 then
				ret[i] = {}
				for j=1,samecount do
					tinsert(ret[i], result[i][j])
				end
			end
			tinsert(ret, result[i])
		end
		
		return ret
	end

	return result
end

--带牌类型搜索(三带一，四带一等)
function cardTool.searchTakeCard(cards, refercard, samecount, takecount)
	local result = {}
	local resultcount = 1
	if samecount == 3 or samecount == 4 then
		--排列扑克
		cardTool.sortCards(cards)
		local sameresult = cardTool.searchSameCard(cards, refercard, samecount)
		if #sameresult >= 1 then
			--分析扑克
			local analayse_data = cardTool.getAnalyse()
			cardTool.getAnalyseCards(cards, analayse_data)
			--需要牌数
			local needcount = samecount + takecount
			if samecount == 4 then needcount = needcount + takecount end
			--提取带牌
			for i = 1, #sameresult do
				local bmerge = false
				for j = takecount, 4 do
					for k = 1, analayse_data.blockcount[j] do
						--从小到大
						local index = (analayse_data.blockcount[j] - k) * j + 1

						while true do
							--过滤相同牌
							if cardTool.getCardValue(sameresult[i][1]) == cardTool.getCardValue(analayse_data.cards[j][index]) then
								break
							end
							--复制带牌
							for m = 1, takecount do
								table.insert(sameresult[i], analayse_data.cards[j][index + m - 1])
							end
							if #(sameresult[i]) < needcount then break end
							--复制结果
							result[resultcount] = result[resultcount] or {}
							for m = 1, #(sameresult[i]) do
								table.insert(result[resultcount], sameresult[i][m])
							end
							resultcount = resultcount + 1
							bmerge = true
							break
						end
						if bmerge == true then break end
					end
					if bmerge == true then break end
				end
			end
		end
	end
	return result
end

--连牌搜索
function cardTool.searchLineCard(cards, refercard, blockcount, linecount)
	local result = {}
	local resultcount = 1
	local lesslinecount = 0
	if linecount == 0 then
		if blockcount == 1 then
			lesslinecount = 5
		elseif blockcount == 2 then
			lesslinecount = 3
		else
			lesslinecount = 2
		end
	else
		lesslinecount = linecount
	end
	local referindex = 2
	if refercard ~= 0 then
		referindex = cardTool.getCardLogicValue(refercard) - lesslinecount + 1
	end
	--超过A
	if referindex + lesslinecount > 14 then return result end
	--长度判断
	if #cards < lesslinecount * blockcount then return result end
	--排列扑克
	cardTool.sortCards(cards)
	--分析扑克
	local distribution_data = cardTool.getDistribution()
	cardTool.AnalyseDistribution(cards, distribution_data)
	--搜索顺子
	local tmplinkcount = 0
	local valueindex = referindex + 1
	while valueindex < 14 do
		while true do
			--连续判断
			if distribution_data.struct[valueindex][6] < blockcount then
				if tmplinkcount < lesslinecount then
					tmplinkcount = 0
					break
				else
					valueindex = valueindex - 1
				end
			else
				tmplinkcount = tmplinkcount + 1
				if linecount == 0 then break end
			end

			if tmplinkcount >= lesslinecount then
				--复制扑克
				result[resultcount] = result[resultcount] or {}
				for cbindex = valueindex + 1 - tmplinkcount, valueindex do
					local tmpcount = 0
					for colorindex = 4, 1, -1 do
						if distribution_data.struct[cbindex][colorindex] > 0 then
							table.insert(result[resultcount], colorindex * 100 + cbindex)
							tmpcount = tmpcount + 1
							if tmpcount == blockcount then break end
						end
					end
				end
				resultcount = resultcount + 1
				if linecount ~= 0 then
					tmplinkcount = tmplinkcount - 1
				else
					tmplinkcount = 0
				end
			end

			break
		end
		valueindex = valueindex + 1
	end

	--特殊顺子
	if tmplinkcount >= lesslinecount - 1 and valueindex == 14 then
		--判断A
		if distribution_data.struct[1][6] >= blockcount or tmplinkcount >= lesslinecount then
			--复制扑克
			result[resultcount] = result[resultcount] or {}
			local tmpcount
			for cbindex = valueindex - tmplinkcount, 13 do
				tmpcount = 0
				for colorindex = 4, 1, -1 do
					if distribution_data.struct[cbindex][colorindex] > 0 then
						table.insert(result[resultcount], colorindex * 100 + cbindex)
						tmpcount = tmpcount + 1
						if tmpcount == blockcount then break end
					end
				end
			end
			--复制A
			if distribution_data.struct[1][6] >= blockcount then
				tmpcount = 0
				for colorindex = 4, 1, -1 do
					if distribution_data.struct[1][colorindex] > 0 then
						table.insert(result[resultcount], colorindex * 100 + 1)
						tmpcount = tmpcount + 1
						if tmpcount == blockcount then break end
					end
				end
			end
			resultcount = resultcount + 1
		end
	end

	return result
end

return cardTool