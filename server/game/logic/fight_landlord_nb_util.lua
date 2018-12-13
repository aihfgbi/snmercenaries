--
-- Created by IntelliJ IDEA.
-- User: 冷廷学
-- Date: 2017/11/23
-- Time: 10:50
-- doc ：只做校验!!
--


--1单张：单个牌
--2对牌：数值相同的两张牌。
--3三张：数值相同的三张牌（如三个 10 ）。
--4俘虏（三带一对）：数值相同的三张牌只给带一对牌。例如： 333+44
--5连对（双顺）：三对或更多的连续对牌 （如： AA2233、334455 、 88991010JJ ）。双顺最少要求 3对。
--6三顺：二个或更多的连续三张牌（如： AAA222、333444 、 444-555-666-777 ）。三顺最少要 求两个 “ 三张 ” 。
--7蝴蝶（双飞）：三顺+同数量顺。例如： 333444+7788 。 备注：飞机所带的对子必须是相连的，否则不能出
--8炸弹：四张或四张以上同数值牌（如四个 5 或六个 7 ）。除比自己大的炸弹外，什么牌型都可 打。相同张数的炸弹，数值大的比数值小的大（ 2 最大，其次 A …）；张数多的炸弹比张数小的炸弹大。
--9天王炸：四个王，最大。
--百搭：大小王可以代替除大小王的任何牌称为“百搭“，如 333+ 大王是 3 炸弹（大王即是 3 ）， 33+44+5+ 小王是三顺（小王即是 5 ）。注：两张相同的王可以当对子出，但只有一张大王和一张小王时不可以一起出。王可以代替任何牌，按大的算。如AA33王就按AAA33算。33+两个王+55可以按334455出。
--牌型大小：
--天王炸 > 炸弹 > 其它牌型。对一般牌型而言，只有当牌型相同并总张数相同的牌，才可比较大小。其中像三带一对、飞机带翅膀等组合牌型，只要比较其牌数最多牌值就行。只有比当前出的牌大的牌才能出。
--单牌按分值比大小，依次是大王>小王 >2>A>K>Q>J>10>9>8>7>6>5>4>3 ，不分花色。

local nbTool = {}
nbTool.DANPAI = 1;
nbTool.DUIZI = 2;
nbTool.SANZHANG = 3;
nbTool.SANDAIDUI = 4;
nbTool.LIANDUI = 5;
nbTool.SANSHUN = 6;
nbTool.HUDIE = 7;
nbTool.ZHADAN = 8;
nbTool.WANGZHA = 9;
-----------------------------------------------------------------------
-- for test
local function print_r(t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end

    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_print_r(t, "  ")
        print("}")
    else
        sub_print_r(t, "  ")
    end
    print()
end

-----------------------------------------------------

--- 比较
function nbTool.compare(a, b)
    if a > b then
        return true
    end
    return false
end

function nbTool.sort(cards)
    table.sort(cards, nbTool.compare)
    return cards
end

--test
--已出牌数据结构
--local used_cards = {
--    [1] = {
--        [1] = nil, --牌型
--        [2] = {}, --普通
--        [3] = {}, --王
--        [4] = nil, --最大值
--        [5] = nil, --长度
--        [6] = nil --uid
--    }
--}
--获取最后一次牌型，最大值，长度3334445566-> 7蝴蝶,4最大值,6参与比较的牌数量
function nbTool.getPreCard(cards, uid)
    if #cards == 0 or uid == cards[#cards][6] then
        return nil, nil, nil, nil
    else
        return
        cards[#cards][1],
        cards[#cards][4],
        cards[#cards][5],
        cards[#cards][6]
    end
end

--判断不出是否合法:合法可以过 -> true
function nbTool.check_pass_legal(cards, uid)
    if #cards == 0 or uid == cards[#cards][6] then
        return false
    else
        return true
    end
end

--print(nbtool.getPreCard({}))

--单数组的拷贝,最后请清空
function nbTool.copyTable(t)
    local a = {}
    for i = 1, #t do
        a[i] = t[i]
    end
    return a
end

--检验ocards是否存在于tcard中
function nbTool.checkLegal(ocards, tcard)
    local target = nbTool.copyTable(tcard)
    for i = 1, #ocards do
        local f = false
        for j = 1, #target do
            if ocards[i] == target[j] then
                table.remove(target, j)
                f = true
                break
            end
        end
        if not f then
            return false
        end
    end
    target = nil
    return true
end

-- print(nbtool.checkLegal({ 1, 2, 1 }, { 1, 2 ,1}))

--获取真实牌组合：比如普通+王
function nbTool.geRealCards(cards)
    local t = nbTool.copyTable(cards[2])
    for i = 1, #cards[3] do
        if i % 2 == 1 then
            t[#t + 1] = cards[3][i]
        end
    end
    return t
end

--获取变换后牌组合:比如普通牌+王变换后的牌
function nbTool.getChangeCards(cards)
    local t = nbTool.copyTable(cards[2])
    for i = 1, #cards[3] do
        if i % 2 == 0 then
            t[#t + 1] = cards[3][i]
        end
    end
    return t
end

--test
--注意牌的数据结构
--local cards = {
--    [1] = 1, --牌行
--    [2] = {}, --普通牌
--    [3] = { 501, 103 }
--}
--nbTool.geRealCards(cards)
--nbTool.getChangeCards(cards)

--获取一张牌的值
function nbTool.getCardRealVal(card)
    return card % 100
end

--获取一张牌的值：返回需要转换
function nbTool.getCardRealVal2(v)
    if v == 1 then
        return 14
    elseif v == 2 then
        return 15
    end
end

--检测一组牌是否全部相等 -> {101,201,202,301}
function nbTool.checkCardsEqual(card)
    if #card <= 1 then
        return false
    else
        local index = card[1] % 100
        for i = 2, #card do
            if card[i] % 100 ~= index then
                return false
            end
        end
        return true
    end
end

--print(nbtool.checkCardsEqual({101,201,202,301}))

--方法封装
function nbTool.doGet(type, cards)
    if type == 1 then
        return nbTool.isSigle(cards)
    elseif type == 2 then
        return nbTool.isTwo(cards)

    elseif type == 3 then
        return nbTool.isThree(cards)

    elseif type == 4 then
        return nbTool.isSanDaiyi(cards)

    elseif type == 5 then
        return nbTool.isLianDui(cards)

    elseif type == 6 then
        return nbTool.isSanShun(cards)

    elseif type == 7 then
        return nbTool.isHuDie(cards)

    elseif type == 8 then
        return nbTool.isbomb(cards)

    elseif type == 9 then
        return nbTool.isBiggest(cards)
    end
end

--检验组合的牌即可
--3
function nbTool.isSigle(cards)
    if #cards == 1 then
        return true, cards[1], 1
    else
        return false, nil, nil
    end
end

--print("单牌", nbTool.isSigle({ 101 }))

--33
function nbTool.isTwo(cards)
    if #cards == 2 and nbTool.checkCardsEqual(cards) then
        return true, cards[1], 2
    else return false, nil, nil
    end
end

--print("isTwo", nbTool.isTwo({ 101, 101 }))

--333
function nbTool.isThree(cards)
    if #cards == 3 and nbTool.checkCardsEqual(cards) then
        return true, cards[1], 3
    else return false, nil, nil
    end
end

--33399
function nbTool.isSanDaiyi(cards)
    local cards = nbTool.sort(cards)
    if #cards == 5 then
        local t = nbTool.sort(cards)
        if t[1] == t[2] and t[4] == t[5] and (t[2] == t[3] or t[3] == t[4]) then
            return true, t[3], 5
        end
    end
    return false, nil, nil
end

--针对3344**,333444***,特殊的A,2注意判断
function nbTool.sequenceHelper(cards, index)
    if #cards % index == 0 then
        local t = nbTool.sort(cards)
        local indexMax = #cards
        for i = 1, indexMax, index do
            if i + index <= indexMax and
                    nbTool.getCardRealVal(cards[i + index]) ~= nbTool.getCardRealVal(cards[i]) - 1 then
                return false, nil, nil
            end
            if i + index < indexMax and
                    not nbTool.checkCardsEqual({ cards[i], cards[i + 1] }) then
                return false, nil, nil
            end
        end
        return true, t[1], #cards --连队需要张数
    end
    return false, nil, nil
end


--334455**
function nbTool.isLianDui(cards)
    if #cards > 5 then
        return nbTool.sequenceHelper(cards, 2)
    end
    return false, nil, nil
end

--print("isLianDui", nbTool.isLianDui({ 1, 1, 2, 2, 3, 3, 4, 4 }))

--333444***
function nbTool.isSanShun(cards)
    if #cards > 5 then
        return nbTool.sequenceHelper(cards, 3)
    end
    return false, nil, nil
end

-- print(nbtool.isSanShun({1,1,1,2,2,2,3,3,3}))

--这个判断好型有点儿问题，比如3344777888
--333444***6677**
function nbTool.isHuDie(cards)
    if #cards >= 10 then
        cards = nbTool.sort(cards)
        local p = #cards / 5
        if math.floor(p) ~= p then
            return false, nil, nil
        end
        --1种情况8, 8, 9, 9 , 3, 3, 3, 2, 2, 2
        local twoTable = {}
        for i = 1, 2 * p do
            twoTable[#twoTable + 1] = cards[i]
        end
        local f, max, leng = nbTool.sequenceHelper(twoTable, 2)
        local threeTable = {}
        if f then
            for i = 2 * p + 1, #cards do
                threeTable[#threeTable + 1] = cards[i]
            end
            local f2, max2, leng2 = nbTool.sequenceHelper(threeTable, 3)
            if f2 then
                return true, max2, #cards --只需要333***的张数即可
            end
        end
        --2种情况9, 9, 9 , 8, 8, 8,  3, 3,2, 2
        local twoTable = {}
        for i = 3 * p + 1, #cards do
            twoTable[#twoTable + 1] = cards[i]
        end
        local f, max, leng = nbTool.sequenceHelper(twoTable, 2)
        local threeTable = {}
        if f then
            for i = 1, 3 * p do
                threeTable[#threeTable + 1] = cards[i]
            end
            local f2, max2, leng2 = nbTool.sequenceHelper(threeTable, 3)
            if f2 then
                return true, max2, #cards --只需要333***的张数即可
            end
        end
    end
    return false, nil, nil
end

--print(nbTool.isHuDie({ 2, 2, 2, 3, 3, 3, 8, 8, 9, 9 }))
--print(nbTool.isHuDie({ 2, 2, 3, 3, 8, 8, 8, 9, 9, 9 }))

--3333*
function nbTool.isbomb(cards)
    if #cards > 3 and nbTool.checkCardsEqual(cards) then
        return true, cards[1], #cards
    else return false, nil, nil
    end
end

--521 521 522 522
function nbTool.isBiggest(cards)
    if #cards == 4 then
        for i = 1, 4 do
            if cards[i] < 20 then
                return false, nil, nil
            end
        end
        return true, nil, 4
    end
    return false, nil, nil
end

--获取计算值
function nbTool.get_calculate_cards(cards)
    local t = {}
    if cards and #cards > 0 then
        for i = 1, #cards do
            table.insert(t, cards[i] % 100)
        end
    end
    return t
end



--外部接口
--检验牌型，注意数据结构
--originCards 用户当前准备出的牌 { msg.cardtype, msg.cards, msg.avatarCards }
--targetCards 用户当前手里的牌 user_cards[p.seatid]
--usedCards   已经出的牌 used_cards
--curUid 当前出牌人
function nbTool.check(originCards, targetCards, usedCards, curUid)
    -- LOG_DEBUG("------------>nbTool start check")
    local realCards = nbTool.geRealCards(originCards)
    local changeCards = nbTool.getChangeCards(originCards)
    local calculate_cards = nbTool.get_calculate_cards(changeCards) --获取计算值
    local flag, max, leng, _uid = nbTool.getPreCard(usedCards, curUid)
    if #realCards == 0 and #changeCards == 0 and nbTool.check_pass_legal(usedCards, curUid) then --不出
        return true, 0, 0
    end
    if nbTool.checkLegal(realCards, targetCards) then --存在校验
        if not flag then --第一次出牌或该自己出牌
            local f, m, len = nbTool.doGet(originCards[1], calculate_cards)
            if f then
                return true, m, len
            end
        elseif flag == originCards[1] then --相同牌行检测
            local f, m, len = nbTool.doGet(flag, calculate_cards)
            if m ~= 0 then
                m = m % 100
            end
            if f then
                max = max % 100
                if flag > 7 and (len > leng or (len == leng and m > max)) then --炸弹检测
                    return true, m, len
                elseif m > max and leng == len then --普通检测
                    return true, m, len
                end
            end
        else --牌行不同，炸弹检测
            local cardtype = originCards[1]
            if (flag and flag ~= 9) and (cardtype == nbTool.ZHADAN or cardtype == nbTool.WANGZHA) then --排除上家出的天王炸
                local f, m, len = nbTool.doGet(cardtype, calculate_cards)
                if f then
                    return true, m, len
                end
            end
        end
    end
    LOG_ERROR("nbtoo check cards return false ---->")
--[[]]    return false
end

-- --test
--local originCards = {
--    [1] = 4, --牌行
--    [2] = { 114, 114, 116, 116 }, --普通牌
--    [3] = { 521, 114 }
--}
--local targetCards = { 114, 114, 116, 116, 521, 522 }
--local usedCards = {
--    [1] = {
--        [1] = 4, --牌行
--        [2] = { 103, 103, 103, 104, 104 }, --普通牌
--        [3] = {},
--        [4] = 4, --最大值
--        [5] = 5, --长度
--        [6] = nil --uid
--    }
--}
------- - 测试一下
--local r = nbTool.check(originCards, targetCards, usedCards, 99)
return nbTool
