--金权
--2018年01月19日
--阿拉斗牛规则
--[[
	牌说明:
	1.共52张牌，不含大小王
	2.个位和十位表示牌大小：1,2,3,4,j j=11... 
	3.百位表示颜色：4,3,2,1 黑，红，梅，方
	没牛0<有牛[1-9]<牛牛10<顺子11<同花12<葫芦13<五小牛14<五花牛15<炸弹16<同花顺17
]]

local this = {}

--函数
local tsort = table.sort
local tinsert = table.insert

----------------------比牌公共函数---------------------
--获取牌大小
local function getValue(card)
    return card % 100
end

--获取牌大小(多)
local function getValues(cards)
	local card_val = {}
	for i,v in pairs(cards) do
		card_val[i] = getValue(v)
	end
	return card_val
end

--获取牌花色
local function getColor(card)
    return math.floor(card / 100)
end

-- 单牌比大小
local function compareCard(card1,card2)
	local val1 = getValue(card1)
	local val2 = getValue(card2)
	if val1 == val2 then
		if card1 > card2 then
			return 1
		else
			return -1
		end
	elseif val1 > val2 then
		return 1
	else
		return -1
	end
end

--获取最大牌
local function getMaxCard(cards)
    local max_card = cards[1]
    for i=2,#cards do
        if compareCard(max_card,cards[i]) == -1 then
            max_card = cards[i]
        end
    end
    return max_card
end

--多牌比大小
local function compareCards(cards1,cards2)
	--判断赋值
    local max_card1 = getMaxCard(cards1)
    local max_card2 = getMaxCard(cards2)
    return compareCard(max_card1,max_card2)
end

----------------------判断特殊牛---------------------
--顺子(11)
local function is_SZ(cards)
	local card_val = getValues(cards)
	tsort(card_val)
	for i=1,#card_val - 1 do
		if card_val[i] + 1 ~= card_val[i + 1] then
			return -1
		end
	end
	return 11
end

--同花(12)
local function is_TH(cards)
	local colour = getColor(cards[1])
	for i=2,#cards do
		if colour ~= getColor(cards[i]) then
			return -1
		end
	end
	return 12
end

--葫芦(13)
local function is_HL(cards)
	local card_val = getValues(cards)
	tsort(card_val)
	if card_val[1] == card_val[3] and card_val[4] == card_val[5] then
		return card_val[3]
	elseif card_val[1] == card_val[2] and card_val[3] == card_val[5] then
		return card_val[3]
	else
		return -1
	end
end

--五小牛(14)
local function is_WXN(cards)
	local sum_val = 0
	for i,v in pairs(cards) do
		local val = getValue(v)
		if val > 5 then
			return -1
		else
			sum_val = sum_val + val
		end
	end
	if sum_val > 10 then
		return -1
	else
		return 14
	end
end

--五花牛(15)
local function is_WHN(cards)
	for i,v in pairs(cards) do
		if getValue(v) < 11 then
			return -1
		end
	end
	return 15
end

--炸弹(16)
local function is_ZD(cards)
	local card_val = getValues(cards)
	tsort(card_val)
	if card_val[1] == card_val[4] then
		return card_val[3]
	elseif card_val[2] == card_val[5] then
		return card_val[3]
	else
		return -1
	end
end

--同花顺(17)
local function is_THS(cards)
	if is_TH(cards) ~=-1 and is_SZ(cards) ~= -1 then
		return 17
	else
		return -1
	end
end

--判断牛(0~10)
local function is_Niu(cards)
	local cardtype = 0
    for i,v in ipairs(cards) do
        cardtype = cardtype + math.min(10,getValue(v))
    end
    cardtype = cardtype % 10
    for i=1,#cards do
        for j=i+1,#cards do
            local now_type = math.min(10,getValue(cards[i]))
            now_type = now_type + math.min(10,getValue(cards[j]))
            now_type = now_type % 10
            if now_type == cardtype then
                if cardtype == 0 then
                    return 10
                else
                    return cardtype
                end
            end
        end
    end
    return 0
end

--葫芦比大小
local function compare_HL(cards1,cards2)
	local hl_type1 = is_HL(cards1)
	local hl_type2 = is_HL(cards2)
	if hl_type1 > hl_type2 then
		return 1
	else
		return -1
	end
end

--炸弹比大小
local function compare_ZD(cards1,cards2)
	local zd_type1 = is_ZD(cards1)
	local zd_type2 = is_ZD(cards2)
	if hl_type1 > hl_type2 then
		return 1
	else
		return -1
	end
end

--获取牌型
function this.getType(cards)
	if is_THS(cards) == 17 then
		return 17
	elseif is_ZD(cards) ~= -1 then
		return 16
	elseif is_WHN(cards) == 15 then
		return 15
	elseif is_WXN(cards) == 14 then
		return 14
	elseif is_HL(cards) ~= -1 then
		return 13
	elseif is_TH(cards) == 12 then
		return 12
	elseif is_SZ(cards) == 11 then
		return 11
	else
		return is_Niu(cards)
	end
end

--比较牌大小
function this.compare(cards1,cards2)
	local cardtype1 = this.getType(cards1)
	local cardtype2 = this.getType(cards2)
	if cardtype1 > cardtype2 then
		return 1
	elseif cardtype1 < cardtype2 then
		return -1
	else
		if cardtype1 == 13 then
			return compare_HL(cards1,cards2)
		elseif cardtype1 == 16 then
			return compare_ZD(cards1,cards2)
		else
			return compareCards(cards1,cards2)
		end
	end
end

return this