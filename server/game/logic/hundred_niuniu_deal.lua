--冷廷学
--二〇一七年十一月二十日 15:38:00
--doc 百人牛牛判定
--基本牌型大小：五小牛50>四炸40>五花牛30>四花牛20>牛牛10>有牛1-9>没牛0

local cardTool = require "niuniu_deal"

--对于没有王的情况
--四花牛
function cardTool.isFourColoNiu(cards)
    cards = cardTool.sort(cards)
    local index = 1
    if cards[2] > 500 then
        index = 3
    elseif cards[1] > 500 then
        index = 2
    end
    local count = 0
    for i = index, #cards do
        if cards[i] % 100 < 10 then
            return -1
        elseif cards[i] % 100 == 10 then
            count = count + 1
        end
    end
    if count < 2 then
        return 20
    end
    return -1
end

-- print(cardTool.isFourColoNiu({113, 111, 112, 211, 311 }))

--五花牛
function cardTool.isColourNiu2(cards)
    cards = cardTool.sort(cards)
    if cards[2] > 500 then
        if cards[3] % 100 > 10 and cards[4] % 100 > 10 and cards[5] % 100 > 10 then
            return 30
        else
            return -1
        end
    elseif cards[1] > 500 then
        if cards[2] % 100 > 10 and cards[3] % 100 > 10 and cards[4] % 100 > 10 and cards[5] % 100 > 10 then
            return 30
        else
            return -1
        end
    end
    if cardTool.isColourNiu(cards) == 41 then
        return 30
    end
    return -1
end

-- print(cardTool.isColourNiu2({501, 201, 112, 211, 311 }))

--炸弹
function cardTool.isBomb2(cards)
    cards = cardTool.sort(cards)
    if cards[2] > 500 then
        return cardTool.isBomb2Inner(cards, 3)
    elseif cards[1] > 500 then
        return cardTool.isBomb2Inner(cards, 2)
    end
    if cardTool.isBomb(cards) == 51 then
        return 40
    end
    return -1
end

function cardTool.isBomb2Inner(cards, index)
    local t = cards[index] % 100
    for i = index + 1, #cards do
        if cards[i] % 100 ~= t then
            return -1
        end
    end
    return 40
end

-- print(cardTool.isBomb2({502,402,101,201,301}))

--五小牛
function cardTool.isSmallNiu2(cards)
    cards = cardTool.sort(cards)
    local index = 1
    if cards[2] > 500 then
        index = 3
    elseif cards[1] > 500 then
        index = 2
    end
    if index > 0 then
        local count = 0
        for i = index, #cards do
            if cards[i] % 100 <= 5 then
                count = count + cards[i] % 100
            else
                return -1
            end
        end
        if count <= 10 then
            return 50
        end
    end
    if cardTool.isSmallNiu(cards) == 31 then
        return 50
    end
    return -1
end

-- print(cardTool.isSmallNiu2({502,201,101,102,103}))

--牛牛判断
function cardTool.getNiu2(cards)
    cards = cardTool.sort(cards)
    if cards[2] > 500 then --必定牛牛
        return 10
    elseif cards[1] > 500 then
        local max = -1
        for i = 2, #cards do --如果有2张为10的倍数，必定为牛牛
            local t = cardTool.getCardChgVal(cards[i])
            t = t == 10 and -1 or t
            max = max > t and max or t
            for j = 3, #cards do
                if (t + cardTool.getCardChgVal(cards[j])) % 10 == 0 then
                    return 10
                end
            end
        end
        return max
    end
    return cardTool.getNiu(cards)
end

--print(cardTool.getNiu2({ 402, 401, 101, 102, 103 }))

--方法封装
function cardTool.doGetNiu(cards)
    local cardCalculate =
    {
        cardTool.getNiu2(cards),
        cardTool.isFourColoNiu(cards),
        cardTool.isColourNiu2(cards),
        cardTool.isBomb2(cards),
        cardTool.isSmallNiu2(cards),
    }
    return cardTool.sort(cardCalculate)
end

--获取最大的牌
function cardTool.getCardsMax2(cards)
    cards = cardTool.sort(cards)
    if cards[2] > 500 then --如果有两张王，最大
        return 414
    end 
    return cardTool.getCardsMax(cards)
end

--提供外部接口判断
function cardTool.niuniuCompare(master,client)
    tMaster = cardTool.doGetNiu(master)
    tClient = cardTool.doGetNiu(client)
    print(table.concat(tMaster,','))
    print(table.concat(tClient,','))
    m = tMaster[1]
    c = tClient[1]

    if m == c then 
        local masterMax = cardTool.getCardsMax2(master)
        local clientMax = cardTool.getCardsMax2(client)
        print(masterMax,clientMax)
        return cardTool.compareMax(masterMax,clientMax),tMaster,tClient
    else
        return cardTool.compare(m,c),tMaster,tClient
    end
end

-- print(table.concat(cardTool.doGetNiu({ 502, 501, 101, 102, 103 }),','))
-- print(cardTool.niuniuCompare({ 502, 501, 101, 102, 103 },{ 502, 101, 201, 301, 401 }))

