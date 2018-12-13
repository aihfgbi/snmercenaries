--金权
--2017年12月20日
--百人游戏数据配置

--游戏说明
--[[
	游戏种类：
	【1】牛牛
	【2】小九
	【3】二八杠
	【4】憋十
    【5】两张
]]

local this = {}

--函数
local tsort = table.sort
local tinsert = table.insert

--游戏数据
this.pos_num = {4, 3, 3, 3, 6} --位置个数
this.open_num = {5, 4, 4, 4, 4} --开牌个数
this.pos_cardnum = {5, 2, 2, 2, 2} --位置卡牌个数
this.bet_max_rate = {10, 1, 1, 1, 1} --押注最大比例
this.banker_max_times = {20, 20, 20, 20, 20} --连庄次数
this.banker_up_gold = {10000000, 10000000, 10000000, 10000000, 10000000} --上庄金币
this.banker_down_gold = {5000000, 5000000, 5000000, 5000000, 5000000} --下庄金币
this.send_card_num = {0, 0, 1, 0, 0} --发牌个数
this.is_get_banker = {0, 1, 1, 1, 1} -- 是否抢庄

-- 筹码金币
this.chip_gold = {
	{1000, 10000, 100000, 500000, 1000000, 5000000},
	{1000, 10000, 100000, 500000, 1000000, 5000000},
	{1000, 10000, 100000, 500000, 1000000, 5000000},
	{1000, 10000, 100000, 500000, 1000000, 5000000},
	{1000, 10000, 100000, 500000, 1000000, 5000000}
}

--所有牌
this.total_cards = {
	{
	    101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113,
	    201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213,
	    301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313,
	    401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415
	},
	{
	    101, 102, 103, 104, 105, 106, 107, 108, 109, 110,
	    201, 202, 203, 204, 205, 206, 207, 208, 209, 210,
	    301, 302, 303, 304, 305, 306, 307, 308, 309, 310,
	    401, 402, 403, 404, 405, 406, 407, 408, 409, 410
	},
	{
	    101, 102, 103, 104, 105, 106, 107, 108, 109, 110,
	    201, 202, 203, 204, 205, 206, 207, 208, 209, 210,
	    301, 302, 303, 304, 305, 306, 307, 308, 309, 310,
	    401, 402, 403, 404, 405, 406, 407, 408, 409, 410
	},
	{
	    101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113,
        201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213,
        301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313,
        401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413
	},
	{
		401, 102, 302, 403, 104, 204, 304, 404, 
		105, 305, 106, 206, 306, 406, 107, 207, 
		307, 407, 108, 208, 308, 408, 109, 309,
		110, 210, 310, 410, 111, 311, 112, 312
	}
}

--倍率
this.cardtype_rate = {
	{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10, 10},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
	{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2},
	{1}
}

--状态时间
this.status_time = {
	{3, 13, 16, 6},
	{3, 13, 12, 6},
	{3, 7, 13, 8, 6},
	{3, 13, 12, 6},
	{3, 13, 12, 6}
}

--游戏流程
this.status_name = {
    {"waiting","bet","open","result"},
    {"waiting","bet","open","result"},
    {"waiting","send","bet","open","result"},
    {"waiting","bet","open","result"},
    {"waiting","bet","open","result"}
}



----------------------比牌公共函数---------------------
--获取牌大小
local function getValue(card)
    return card % 100
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
		elseif card1 < card2 then
			return -1
		else
			return 0
		end
	elseif val1 > val2 then
		if val2 == 1 and val1 <= 13 then
			return -1
		else
			return 1
		end
	else
		if val1 == 1 and val2 <= 13 then
			return 1
		else
			return -1
		end
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
    local max_card1 = getMaxCard(cards1)
    local max_card2 = getMaxCard(cards2)
    return compareCard(max_card1,max_card2)
end

--------------------------牛牛-------------------------
--百人牛牛规则
--[[
	牌说明:
	1.共54张牌，含大小王
	2.个位和十位表示牌大小：1,2,3,4,j j=11... 
	3.百位表示颜色：4,3,2,1 黑，红，梅，方
	4.没牛0<有牛[1-9]<牛牛10<四花牛11<五花牛12<炸弹牛13<五小牛14
	5.当大、小王不百变时，只能做王本省，不是花（J.Q.K）
	6.单王百变时，那就属于该牌型中最小的牌
	7.出现双王，则为该牌中最大的牌。
]]

--获取王个数
local function NN_getWangNum(cards)
    local wang_num = 0
    for i,v in ipairs(cards) do
        if getValue(v) > 13 then
            wang_num = wang_num + 1
        end
    end
    return wang_num
end

-----------------王不当癞子情况---------------------
--判断五花牛/四花牛
local function NN_isWHN_Lz_No(cards)
    local c_num = 0
    for i,v in ipairs(cards) do
        if getValue(v) < 10 then
            return -1
        else
            if getValue(v) == 10 then
                c_num = c_num + 1
            end
        end
    end
    if c_num == 0 then
        return 12
    elseif c_num == 1 then
        return 11
    else
        return -1
    end
end

--判断牛
local function NN_isNiu_Lz_No(cards)
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

-------------------王当癞子情况---------------------
--判断五小牛
local function NN_isWXN_Lz_Yes(cards)
    local sum_val = 0
    local wang_num = 0
    for i,v in ipairs(cards) do
        if getValue(v) > 5 then
            if getValue(v) > 13 then
                wang_num = wang_num + 1
            else
                return -1
            end
        else
            sum_val = sum_val + getValue(v)
        end
    end
    if wang_num > 0 then
        if sum_val + wang_num <= 10 then
            return 14
        else
            return -1
        end
    else
        if sum_val <= 10 then
            return 14
        else
            return -1
        end
    end
end

--判断炸弹牛
local function NN_isZDN_Lz_Yes(cards)
    local wang_num = 0
    local cards_val = {}
    for i,v in ipairs(cards) do
        cards_val[i] = getValue(v)
        if cards_val[i] > 13 then
            wang_num = wang_num + 1
        end
    end
    tsort(cards_val)
    if wang_num == 1 then
        if cards_val[1] == cards_val[3] then
            return cards_val[1]
        elseif cards_val[2] == cards_val[4] then
            return cards_val[2]
        else
            return -1
        end
    elseif wang_num == 2 then
        if cards_val[1] == cards_val[2] then
            return cards_val[1]
        elseif cards_val[2] == cards_val[3] then
            return cards_val[2]
        else
            return -1
        end
    else
        if cards_val[1] == cards_val[4] then
            return cards_val[1]
        elseif cards_val[2] == cards_val[5] then
            return cards_val[2]
        else
            return -1
        end
    end
end

--判断其他牛(有王情况)
local function NN_isNiu_Lz_Yes(cards)
    local cardtype = 0
    local wang_num = 0
    for i,v in ipairs(cards) do
        if getValue(v) <= 13 then
            cardtype = cardtype + math.min(10,getValue(v))
        else
            wang_num = wang_num + 1
        end
    end
    cardtype = cardtype % 10

    --按王个数
    if wang_num == 1 then
        local max_num = 0
        for k,v in pairs(cards) do
            if math.min(10,getValue(v)) % 10 == cardtype and getValue(v) <=13 then
                return 10
            end
        end
        for i=1,#cards do
            for j=i+1,#cards do
                if getValue(cards[i]) <= 13 and getValue(cards[j]) <= 13 then
                    local now_num = math.min(10,getValue(getValue(cards[i])))
                    now_num = now_num + math.min(10,getValue(getValue(cards[j])))
                    if now_num % 10 == 0 then
                        max_num = math.max(max_num,10)
                    else
                        max_num = math.max(max_num,now_num % 10)
                    end
                end
            end
        end
        return max_num
    elseif wang_num == 2 then
        return 10
    else
        return NN_isNiu_Lz_No(cards)
    end
end

--判断牛几
local function NN_getType(cards)
    if NN_isWXN_Lz_Yes(cards) ~= -1 then
        return 14
    elseif NN_isZDN_Lz_Yes(cards) ~= -1 then
        return 13
    elseif NN_isWHN_Lz_No(cards) ~= -1 then
        return NN_isWHN_Lz_No(cards)
    else
        return NN_isNiu_Lz_Yes(cards)
    end
end

-----------------牛牛比大小------------------
--判断五小牛大小
local function NN_compareWXN(cards1,cards2)
    local wang_num1 = NN_getWangNum(cards1)
    local wang_num2 = NN_getWangNum(cards2)
    if wang_num1 == 2 then
        return 1
    elseif wang_num1 == 1 then
        if wang_num2 == 1 then
            return compareCards(cards1,cards2)
        else
            return -1
        end
    else
        if wang_num2 == 2 then
            return -1
        elseif wang_num2 == 1 then
            return 1
        else
            return compareCards(cards1,cards2)
        end
    end
end

--判断炸弹牛大小
local function NN_compareZDN(cards1,cards2)
    local zd_val1 = NN_isZDN_Lz_Yes(cards1)
    local zd_val2 = NN_isZDN_Lz_Yes(cards2)
    if zd_val1 > zd_val2 then
        return 1
    else
        return -1
    end
end

--判断其他牛
local function NN_compareNiu(cards1,cards2,niutype)
    local is_laizi1 = false
    local is_laizi2 = false
    local wang_num1 = NN_getWangNum(cards1)
    local wang_num2 = NN_getWangNum(cards2)
    if niutype ~= NN_isNiu_Lz_No(cards1) then
        is_laizi1 = true
    end
    if niutype ~= NN_isNiu_Lz_No(cards2) then
        is_laizi2 = true
    end
    if wang_num1 == 2 then
        return 1
    elseif wang_num1 == 1 then
        if wang_num2 == 1 then
            if is_laizi1 then
                if is_laizi2 then
                    return compareCards(cards1,cards2)
                else
                    return -1
                end
            else
                if is_laizi2 then
                    return 1
                else
                    return compareCards(cards1,cards2)
                end
            end
        else
            if is_laizi1 then
                return -1
            else
                return compareCards(cards1,cards2)
            end
        end
    else
        if wang_num2 == 2 then
            return -1
        elseif wang_num2 == 1 then
            if is_laizi2 then
                return 1
            else
                compareCards(cards1,cards2)
            end
        else
            return compareCards(cards1,cards2)
        end
    end
end

--比牌大小
local function NN_compareCards(cards1,cards2)
    local cardtype1 = NN_getType(cards1)
    local cardtype2 = NN_getType(cards2)
    if cardtype1 > cardtype2 then
        return 1
    elseif cardtype1 < cardtype2 then
        return -1
    else
        if cardtype1 == 14 then
            return NN_compareWXN(cards1,cards2)
        elseif cardtype1 == 13 then
            return NN_compareZDN(cards1,cards2)
        elseif cardtype1 == 11 or cardtype1 == 12 then
            return compareCards(cards1,cards2)
        else
            return NN_compareNiu(cards1,cards2,cardtype1)
        end
    end
end

--输赢计算
local function NN_assIsWin(posnum,cards,totalbet,bankergold)
	local is_win = {}
	for i=1,posnum do
		is_win[i] = NN_compareCards(cards[i],cards[posnum + 1])
	end
	return is_win
end

--计算庄家输赢
local function NN_assBankerWinGold(posnum,posbet,cardtype,iswin,totalbet,bankergold)
	local banker_wingold = 0
	for i=1,posnum do
		local now_cardtype
		if iswin[i] == 1 then
			now_cardtype = math.max(1,cardtype[i])
			banker_wingold = banker_wingold - posbet[i] * this.cardtype_rate[1][now_cardtype]
		else
			now_cardtype = math.max(1,cardtype[posnum + 1])
			banker_wingold = banker_wingold + posbet[i] * this.cardtype_rate[1][now_cardtype]
		end
	end
	return banker_wingold
end

--计算玩家输赢(把本钱计算进去)
local function NN_assUserWinGold(posnum,userbet,cardtype,iswin,totalbet,bankergold)
	local user_wingold = 0
	for i=1,posnum do
		local now_cardtype
		if iswin[i] == 1 then
			now_cardtype = math.max(1,cardtype[i])
			user_wingold = user_wingold + userbet[i] * (this.cardtype_rate[1][now_cardtype] + 1)
		else
			now_cardtype = math.max(1,cardtype[posnum + 1])
			user_wingold = user_wingold - userbet[i] * (this.cardtype_rate[1][now_cardtype] - 1)
		end
	end
	return user_wingold
end

--历史记录初始化赋值
local function NN_assRecordInfo()
	local record = {}
	tinsert(record,this.pos_num[1])
	for i=1,15 do
		for j=1,this.pos_num[1] do
			local random = math.random()
			if random < 0.5 then
				tinsert(record,1);
			else
				tinsert(record,-1);
			end
		end
	end
	return record;
end

--------------------------小九-------------------------
--小九
--[[
	牌说明:
	1.共40张牌
	2.个位和十位表示牌大小：1,2,3,4,...10
	3.百位表示颜色：4,3,2,1 黑，红，梅，方
	10对[20]>9对[19]>8对[18]>7对[17]>6对[16]>5对[15]>4对[14]>3对[13]>2对[12]>A对[11]
    9点[9]>8点[8]>7点[7]>6点[6]>5点[5]>4点[4]>3点[3]>2点[2]>1点[1]>0点[0](10点=0点)
]]
local xj_bet_rate = 0.5

--判断牌型
local function XJ_getType(cards)
    local card_val = {}
    for k,v in pairs(cards) do
        card_val[k] = getValue(v)
    end
    
    --判断返回
    if card_val[1] == card_val[2] then
        return card_val[1] + 10
    else
        return (card_val[1] + card_val[2]) % 10
    end
end

-- 比牌
local function XJ_compareCards(cards1,cards2)
    local cardtype1 = XJ_getType(cards1)
    local cardtype2 = XJ_getType(cards2)

 	--判断
    if cardtype1 > cardtype2 then
        return 1
    elseif cardtype1 < cardtype2 then
        return -1
    else
        return 0
    end
end

--输赢计算
local function XJ_assIsWin(posnum,cards,totalbet,bankergold)
	local is_win = {}
	for i=1,posnum do
		local now_iswin = XJ_compareCards(cards[i],cards[posnum + 1])
		if now_iswin == 0 then
			if totalbet >= bankergold * xj_bet_rate then
				is_win[i] = 0
			else
				is_win[i] = -1
			end
		else
			is_win[i] = now_iswin
		end
	end
	return is_win
end

--计算庄家输赢
local function XJ_assBankerWinGold(posnum,posbet,cardtype,iswin,totalbet,bankergold)
	local banker_wingold = 0
	for i=1,posnum do
		local now_cardtype
		if iswin[i] == 1 then
			now_cardtype = math.max(1,cardtype[i])
			if totalbet >= bankergold * xj_bet_rate then
				banker_wingold = banker_wingold - posbet[i]
			else
				banker_wingold = banker_wingold - posbet[i] * this.cardtype_rate[2][now_cardtype]
			end
		elseif iswin[i] == -1 then
			banker_wingold = banker_wingold + posbet[i]
		end
	end
	return banker_wingold
end

--计算玩家输赢(把本钱计算进去)
local function XJ_assUserWinGold(posnum,userbet,cardtype,iswin,totalbet,bankergold)
	local user_wingold = 0
	for i=1,posnum do
		local now_cardtype
		if iswin[i] == 1 then
			now_cardtype = math.max(1,cardtype[i])
			if totalbet >= bankergold * xj_bet_rate then
				user_wingold = user_wingold + userbet[i] * 2
			else
				user_wingold = user_wingold + userbet[i] * (this.cardtype_rate[2][now_cardtype] + 1)
			end
		elseif iswin[i] == 0 then
			user_wingold = user_wingold + userbet[i]
		end
	end
	return user_wingold
end

--历史记录初始化赋值
local function XJ_assRecordInfo()
	local record = {}
	tinsert(record,this.pos_num[2])
	for i=1,15 do
		for j=1,this.pos_num[2] do
			local random = math.random()
			if random < 0.48 then
				tinsert(record,1);
			elseif random < 0.96 then
				tinsert(record,-1);
			else
				tinsert(record,0);
			end
		end
	end
	return record
end

-------------------------二八杠-------------------------
--二八杠
--[[
	牌说明:
	1.共40张牌
	2.个位和十位表示牌大小：1,2,3,4,...白板
	3.百位表示颜色：4,3,2,1
	二八杠[10]>白板豹子[20]>9豹子[19]>8豹子[18]>7豹子[17]>6豹子[16]>5豹子[15]>4豹子[14]>3豹子[13]>2豹子[12]>1豹子[11]>
    9.5点>9点>8.5点>8点>7.5点>7点>6.5点>6点>5.5点>5点>4.5点>4点>3.5点>3点>2.5点>2点>1.5点>1点>0点
]]

--判断牌型
local function EBG_getType(cards)
    local card_val = {}
    for k,v in pairs(cards) do
        card_val[k] = getValue(v)
    end

    --牌类型赋值
    if card_val[1] == card_val[2] then
    	return card_val[1] + 10
    else
        if card_val[1] + card_val[2] ==10 and math.abs(card_val[1] - card_val[2]) == 6 then
            return 10
        else
        	if card_val[1] == 10 then
        		return (card_val[2] + 0.5) % 10
        	elseif card_val[2] == 10 then
        		return (card_val[1] + 0.5) % 10
        	else
        		return (card_val[1] + card_val[2]) % 10
        	end
        end
    end
end

-- 比牌1:card1>card2,-1:card1<card2,0:card1=card2
local function EBG_compareCards(cards1,cards2)
    local card_val1 = {}
    local card_val2 = {}
    local card_type1 = EBG_getType(cards1)
    local card_type2 = EBG_getType(cards2)
    
    --判断
    if card_type1 > card_type2 then
        if card_type2 == 10 then
            return -1
        else
            return 1
        end
    elseif card_type1 < card_type2 then
        if card_type1 == 10 then
            return 1
        else
            return -1
        end
    else
    	--牌赋值
    	for k,v in pairs(cards1) do
	        card_val1[k] = getValue(v)
	    end
	    for k,v in pairs(cards2) do
	        card_val2[k] = getValue(v)
	    end
	    tsort(card_val1)
	    tsort(card_val2)

       	--判断大小
       	if card_val1[2] == card_val2[2] then
       		return 0
       	elseif card_val1[2] > card_val2[2] then
       		return 1
       	else
       		return -1
       	end
    end
end

--输赢计算
local function EBG_assIsWin(posnum,cards,totalbet,bankergold)
	local is_win = {}
	for i=1,posnum do
		is_win[i] = EBG_compareCards(cards[i],cards[posnum + 1])
	end
	return is_win
end

--计算庄家输赢
local function EBG_assBankerWinGold(posnum,posbet,cardtype,iswin,totalbet,bankergold)
	local banker_wingold = 0
	for i=1,posnum do
		local now_cardtype
		if iswin[i] == 1 then
			banker_wingold = banker_wingold - posbet[i]
		elseif iswin[i] == -1 then
			banker_wingold = banker_wingold + posbet[i]
		end
	end
	return banker_wingold
end

--计算玩家输赢(把本钱计算进去)
local function EBG_assUserWinGold(posnum,userbet,cardtype,iswin,totalbet,bankergold)
	local user_wingold = 0
	for i=1,posnum do
		local now_cardtype
		if iswin[i] == 1 then
			user_wingold = user_wingold + userbet[i] * 2
		elseif iswin[i] == 0 then
			user_wingold = user_wingold + userbet[i]
		end
	end
	return user_wingold
end

--历史记录初始化赋值
local function EBG_assRecordInfo()
	local record = {}
	tinsert(record,this.pos_num[3])
	for i=1,15 do
		for j=1,this.pos_num[3] do
			local random = math.random()
			if random < 0.5 then
				tinsert(record,1);
			else
				tinsert(record,-1);
			end
		end
	end
	return record
end

--------------------------憋十-------------------------
--憋十
--[[
    牌说明:
    1.共40张牌
    2.个位和十位表示牌大小：1,2,3,4,...10
    3.百位表示颜色：4,3,2,1 黑，红，梅，方
    10对[20]>9对[19]>8对[18]>7对[17]>6对[16]>5对[15]>4对[14]>3对[13]>2对[12]>A对[11]>
    10点[10]>9点[9]>8点[8]>7点[7]>6点[6]>5点[5]>4点[4]>3点[3]>2点[2]>1点[1]
]]
local bs_bet_rate = 0.5

--判断牌型
local function BS_getType(cards)
    local card_val = {}
    for k,v in pairs(cards) do
        card_val[k] = getValue(v)
        if card_val[k] > 10 then
            card_val[k] = 0
        end
    end
    
    --判断返回
    if card_val[1] == card_val[2] then
        if card_val[1] == 0 then
            return 0
        else
            return card_val[1] + 10
        end
    else
        if (card_val[1] + card_val[2]) % 10 == 0 then
            return 10
        else
            return (card_val[1] + card_val[2]) % 10
        end
    end
end

-- 比牌
local function BS_compareCards(cards1,cards2)
    local cardtype1 = BS_getType(cards1)
    local cardtype2 = BS_getType(cards2)

    --判断
    if cardtype1 > cardtype2 then
        return 1
    elseif cardtype1 < cardtype2 then
        return -1
    else
        return 0
    end
end

--输赢计算
local function BS_assIsWin(posnum,cards,totalbet,bankergold)
	local is_win = {}
	for i=1,posnum do
		local now_iswin = BS_compareCards(cards[i],cards[posnum + 1])
		if now_iswin == 0 then
			if totalbet >= bankergold * bs_bet_rate then
				is_win[i] = 0
			else
				is_win[i] = -1
			end
		else
			is_win[i] = now_iswin
		end
	end
	return is_win
end

--计算庄家输赢
local function BS_assBankerWinGold(posnum,posbet,cardtype,iswin,totalbet,bankergold)
	local banker_wingold = 0
	for i=1,posnum do
		local now_cardtype
		if iswin[i] == 1 then
			now_cardtype = math.max(1,cardtype[i])
			if totalbet >= bankergold * bs_bet_rate then
				banker_wingold = banker_wingold - posbet[i]
			else
				banker_wingold = banker_wingold - posbet[i] * this.cardtype_rate[4][now_cardtype]
			end
		elseif iswin[i] == -1 then
			banker_wingold = banker_wingold + posbet[i]
		end
	end
	return banker_wingold
end

--计算玩家输赢(把本钱计算进去)
local function BS_assUserWinGold(posnum,userbet,cardtype,iswin,totalbet,bankergold)
	local user_wingold = 0
	for i=1,posnum do
		local now_cardtype
		if iswin[i] == 1 then
			now_cardtype = math.max(1,cardtype[i])
			if totalbet >= bankergold * bs_bet_rate then
				user_wingold = user_wingold + userbet[i] * 2
			else
				user_wingold = user_wingold + userbet[i] * (this.cardtype_rate[4][now_cardtype] + 1)
			end
		elseif iswin[i] == 0 then
			user_wingold = user_wingold + userbet[i]
		end
	end
	return user_wingold
end

--历史记录初始化赋值
local function BS_assRecordInfo()
	local record = {}
	tinsert(record,this.pos_num[4])
	for i=1,15 do
		for j=1,this.pos_num[4] do
			local random = math.random()
			if random < 0.48 then
				tinsert(record,1);
			elseif random < 0.96 then
				tinsert(record,-1);
			else
				tinsert(record,0);
			end
		end
	end
	return record
end

-----------------------温州两张----------------------
--温州两张
--[[
    牌说明:
    1.共32张牌
    2.个位和十位表示牌大小：1,2,3,4,...10
    3.百位表示颜色：4,3,2,1 黑，红，梅，方
    2张红Q、2张红J、4张10、2张红9、4张8、4张7、4张6、2张红5、4张4、2张2、黑桃A、黑桃3 
]]

--牌大小
local lz_card_val = {
	[403] = 1, [105] = 1, [305] = 1, [401] = 1, [207] = 1, [407] = 1, [208] = 1, [408] = 1, [109] = 1, [309] = 1,
	[106] = 2, [306] = 2, [107] = 2, [307] = 2, [110] = 2, [310] = 2, [111] = 2, [311] = 2,
	[204] = 3, [404] = 3, [206] = 3, [406] = 3, [210] = 3, [410] = 3,
	[104] = 4, [304] = 4,
	[108] = 5, [308] = 5,
	[102] = 6, [302] = 6, 
	[112] = 7, [312] = 7
}

--特殊牌型
local lz_special_cards = {
	{c = {401, 403}, ct = 21, cn = "至尊宝", cct = 1},
	{c = {112, 312}, ct = 20, cn = "双天", cct = 1},
	{c = {102, 302}, ct = 19, cn = "双地", cct = 1},
	{c = {108, 308}, ct = 18, cn = "双人", cct = 1},
	{c = {104, 304}, ct = 17, cn = "双和", cct = 1},
	{c = {110, 310}, ct = 16, cn = "双梅", cct = 1},
	{c = {106, 306}, ct = 16, cn = "双长", cct = 1},
	{c = {204, 404}, ct = 16, cn = "双板凳", cct = 1},
	{c = {111, 311}, ct = 15, cn = "双斧头", cct = 1},
	{c = {210, 410}, ct = 15, cn = "双红头", cct = 1},
	{c = {206, 406}, ct = 15, cn = "双幺五", cct = 1},
	{c = {107, 307}, ct = 15, cn = "双铜棰", cct = 1},
	{c = {109, 309}, ct = 14, cn = "杂九", cct = 1},
	{c = {208, 408}, ct = 14, cn = "杂八", cct = 1},
	{c = {207, 407}, ct = 14, cn = "杂七", cct = 1},
	{c = {105, 305}, ct = 14, cn = "杂五", cct = 1},
	{c = {9, 12}, ct = 13, cn = "九天王", cct = 2},
	{c = {8, 12}, ct = 12, cn = "天槓", cct = 2},
	{c = {2, 8}, ct = 11, cn = "地槓", cct = 2}
}

--判断牌类型
local function LZ_getType(cards)
	local card_type
	local card_val = {}
	for i,v in ipairs(cards) do
		card_val[i] = getValue(v)
	end
	tsort(cards)
	tsort(card_val)

	--判断特殊牌型
	for i,v in ipairs(lz_special_cards) do
		if v.cct == 1 then
			if cards[1] == v.c[1] and cards[2] == v.c[2] then
				card_type = v.ct
			end
		else
			if card_val[1] == v.c[1] and card_val[2] == v.c[2] then
				card_type = v.ct
			end
		end
	end

	--判断返回
	if card_type then
		return card_type
	else
		card_type = 0
		if cards[1] == 401 then
			card_type = card_type + 6
		else
			card_type = card_type + getValue(cards[1])
		end
		if cards[2] == 401 then
			card_type = card_type + 6
		else
			card_type = card_type + getValue(cards[2])
		end
		return card_type % 10
	end
end

-- 比牌
local function LZ_compareCards(cards1,cards2)
	local cardtype1 = LZ_getType(cards1)
    local cardtype2 = LZ_getType(cards2)

    --判断
    if cardtype1 > cardtype2 then
        return 1
    elseif cardtype1 < cardtype2 then
        return -1
    else
    	if cardtype1 == 0 then
    		return 0
        elseif cardtype1 < 10 then
        	--比单牌大小
        	local card_val1 = {}
        	local card_val2 = {}
        	for i,v in ipairs(cards1) do
        		card_val1[i] = lz_card_val[v]
        	end
        	for i,v in ipairs(cards2) do
        		card_val2[i] = lz_card_val[v]
        	end
        	tsort(card_val1)
        	tsort(card_val2)

        	--比单牌大小
        	if card_val1[2] > card_val2[2] then
        		return 1
        	elseif card_val1[2] < card_val2[2] then
        		return -1
        	else
        		return 0
        	end
        else
        	return 0
        end
    end
end

--输赢计算
local function LZ_assIsWin(posnum,cards,totalbet,bankergold)
	local is_win = {}
	for i=1,posnum do
		if i < 4 then
			if LZ_compareCards(cards[i],cards[4]) == 1 then
				is_win[i] = 1
			else
				is_win[i] = -1
			end
		elseif i == 4 then
			if is_win[1] + is_win[2] == 0 then
				is_win[i] = 0
			elseif is_win[1] + is_win[2] == 2 then
				is_win[i] = 1
			else
				is_win[i] = -1
			end
		elseif i == 5 then
			if is_win[1] + is_win[3] == 0 then
				is_win[i] = 0
			elseif is_win[1] + is_win[3] == 2 then
				is_win[i] = 1
			else
				is_win[i] = -1
			end
		elseif i == 6 then
			if is_win[2] + is_win[3] == 0 then
				is_win[i] = 0
			elseif is_win[2] + is_win[3] == 2 then
				is_win[i] = 1
			else
				is_win[i] = -1
			end
		end
	end
	return is_win
end

--计算庄家输赢
local function LZ_assBankerWinGold(posnum,posbet,cardtype,iswin,totalbet,bankergold)
	local banker_wingold = 0
	for i=1,posnum do
		local now_cardtype
		if iswin[i] == 1 then
			banker_wingold = banker_wingold - posbet[i]
		elseif iswin[i] == -1 then
			banker_wingold = banker_wingold + posbet[i]
		end
	end
	return banker_wingold
end

--计算玩家输赢(把本钱计算进去)
local function LZ_assUserWinGold(posnum,userbet,cardtype,iswin,totalbet,bankergold)
	local user_wingold = 0
	for i=1,posnum do
		local now_cardtype
		if iswin[i] == 1 then
			user_wingold = user_wingold + userbet[i] * 2
		end
	end
	return user_wingold
end

--历史记录初始化赋值
local function LZ_assRecordInfo()
	local record = {}
	tinsert(record,3)
	for i=1,15 do
		for j=1,3 do
			local random = math.random()
			if random < 0.5 then
				tinsert(record,1)
			else
				tinsert(record,-1)
			end
		end
	end
	return record
end

--获取牌型
this.getType = {
	NN_getType,
	XJ_getType,
	EBG_getType,
	BS_getType,
	LZ_getType
}

--输赢计算
this.assIsWin = {
	NN_assIsWin,
	XJ_assIsWin,
	EBG_assIsWin,
	BS_assIsWin,
	LZ_assIsWin
}

--计算庄家输赢
this.assBankerWinGold = {
	NN_assBankerWinGold,
	XJ_assBankerWinGold,
	EBG_assBankerWinGold,
	BS_assBankerWinGold,
	LZ_assBankerWinGold
}

--机选玩家输赢
this.assuserWingold = {
	NN_assUserWinGold,
	XJ_assUserWinGold,
	EBG_assUserWinGold,
	BS_assUserWinGold,
	LZ_assUserWinGold
}

--历史记录初始化赋值
this.assRecordInfo = {
	NN_assRecordInfo,
	XJ_assRecordInfo,
	EBG_assRecordInfo,
	BS_assRecordInfo,
	LZ_assRecordInfo
}

return this
