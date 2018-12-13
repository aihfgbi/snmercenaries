local tinsert = table.insert


function table_join(array, tarray)
  -- body
  if next(tarray) then
    for _,v in pairs(tarray) do
      table.insert(array, v)
    end
  end
end

local cardsHelp = {}


--获取本牌中的癞子
function cardsHelp.getLaiZi(myCards)
  local cards = cardsHelp.structure(myCards)
  local nLaiZi = cards[21].count + cards[22].count
  local tLaizi = {}
  table_join(tLaizi,cards[21].cards)
  table_join(tLaizi,cards[22].cards)
  return nLaiZi,tLaizi
end

--转换我的牌到指定数据结构
function cardsHelp.structure(cards)
    local new = {}
    for i = 1, 22 do -->王最大值522
        new[i] = { cal_value = i, count = 0, cards = {} }
    end
    for k, v in pairs(cards) do
        local r = v % 100
        new[r].count = new[r].count + 1
        table.insert(new[r].cards, v)
    end
    return new
end

--向一个数组中添加牌
function cardsHelp.insert(tarCrads, origCards)
    for i = 1, #origCards do
        table.insert(tarCrads, origCards[i])
    end
end

--压牌：直接获取单，双，三的牌
function cardsHelp.cards_normal(cards, type, max)
  local two_count = cards[16].count
  local two_table = cards[16].cards
  -- 有就直接管
  for k, v in pairs(cards) do
    if type == v.count and v.cal_value > max then
      local r = {}
      r.max = v.cal_value
      r.type = type
      r.len = v.count
      r.cards = v.cards
      return r
    end
  end
  --没有先拆2
  for i = 1,two_count do
    if i == type and 16 > max then
      local r = {}
      r.max = 16
      r.type = type
      r.len = i
      r.cards = {}
      for j = 1,i do
        table.insert(r.cards,two_table[j])
      end
      return r
    end
  end
  --没有2拆对或三
  for k, v in pairs(cards) do
    if (v.count >= type) and (v.cal_value > max) and (v.count <= 3) then
      local r = {}
      r.max = v.cal_value
      r.type = type
      r.len = type
      r.cards = {}
      for i = 1,type do
        table.insert(r.cards,v.cards[i])
      end
      return r
    end
  end
end

--三代一对
function cardsHelp.getSanDaiyi(cards, type, max)
  local returnCards = {}
  local c = {}
  returnCards.cards = c
  for i = 1, #cards do -- 获取三--[[]]
      local v = cards[i]
      if v.count == 3 and v.cal_value > max then
          returnCards.max = v.cal_value
          returnCards.type = type
          returnCards.len = 5
          cardsHelp.insert(c, v.cards)
          break
      end
  end
  for i = 1, #cards do --获取2
      local v = cards[i]
      if v.count == 2 then
          cardsHelp.insert(c, v.cards)
          break
      end
  end
  if #returnCards.cards == 5 then
      return returnCards
  end
end

--提供递归 type == 2 | 3
function cardsHelp.recursion(cards, type, startIndex, len)
    local r = {}
    if startIndex > #cards - len then return nil end
    for i = startIndex, startIndex + len - 1 do
        if cards[i].count == type then
            cardsHelp.insert(r, cards[i].cards)
            if #r >= len then
              break
            end
        else
            r = {}
            break
        end
    end
    if r and #r > 0 then
        return r
    else
        return cardsHelp.recursion(cards, type, startIndex + 1, len)
    end
end

--连队
function cardsHelp.getLianDui(cards, type, max, len)
    for i = 1, #cards do
        local v = cards[i]
        if v.count == 2 and v.cal_value > (max-(len/2)+1) then
            local r = {}
            local c = cardsHelp.recursion(cards, 2, i, len)
            if c and #c > 0 then
                r.max = c[#c] % 100
                r.len = len
                r.type = type
                r.cards = c
            end
            if #r > 0 then
              return nil
            else
              return r
            end
        end
    end
end

--三顺
function cardsHelp.getSanShun(cards, type, max, len)
    for i = 1, #cards do
        local v = cards[i]
        if v.count == 3 and v.cal_value > (max-(len/3)+1) then
            local r = {}
            local c = cardsHelp.recursion(cards, 3, i, len)
            if c and #c > 0 then
                r.max = c[#c] % 100
                r.len = len
                r.type = type
                r.cards = c
            end
            return r
        end
    end
end

--三顺+连队
function cardsHelp.getHuDie(cards, type, max, len)
    local three = cardsHelp.getSanShun(cards, type, max, (len-(len/5)*2))
    if three and three.cards and #three.cards > 0 then
      local two = cardsHelp.getLianDui(cards, type, 0, (len-(len/5)*3))
      if two and two.cards and #two.cards > 0 then
        cardsHelp.insert(three.cards, two.cards)
        return three
      end
    end
end

--炸弹
function cardsHelp.getlowbomb(myCards)
  local cards = cardsHelp.structure(myCards)
  local nLaiZi,tLaizi = cardsHelp.getLaiZi(myCards)
  for i = 1, #cards do
    local v = cards[i]
    if v.count == 4 then
      v.type = 8
      v.max = v.cal_value
      v.len = v.count
      return v
    end
  end
  for i = 1, #cards do
    local v = cards[i]
    for n = 0,nLaiZi do
      if (v.count + n >= 4) then
        v.type = 8
        v.max = v.cal_value
        v.len = v.count + n
        table.random(tLaizi)
        v.avatarCards = {}
        for k = 1,n do
          table.insert(v.avatarCards,tLaizi[k])
          table.insert(v.avatarCards,v.cards[1])
        end
        return v
      end
    end
    for m = 4 ,8 do
      if v.count >= m then
        v.type = 8
        v.max = v.cal_value
        v.len = v.count
        return v
      end
    end
  end
end

function cardsHelp.getbomb(myCards, type, max, len)
  local cards = cardsHelp.structure(myCards)
  local nLaiZi,tLaizi = cardsHelp.getLaiZi(myCards)
  for i = 1, #cards do
    local v = cards[i]
    if (v.count == len and v.cal_value > max) then
      v.type = 8
      v.max = v.cal_value
      v.len = v.count
      return v
    end
  end
  for i = 1, #cards do
    local v = cards[i]
    for j = 1,nLaiZi do
      if(v.count + j == len and v.cal_value > max) then
        v.type = 8
        v.max = v.cal_value
        v.len = v.count + j
        table.random(tLaizi)
        v.avatarCards = {}
        for k = 1,j do
          table.insert(v.avatarCards,tLaizi[k])
          table.insert(v.avatarCards,v.cards[1])
        end
        return v
      end
    end
  end
  for i = 1, #cards do
    local v = cards[i]
    if v.count > len then
      v.type = 8
      v.max = v.cal_value
      v.len = v.count
      return v
    end
  end
  for i = 1, #cards do
    local v = cards[i]
    for j = 1,nLaiZi do
      if(v.count + j >= len and v.cal_value > max) then
        v.type = 8
        v.max = v.cal_value
        v.len = v.count + j
        table.random(tLaizi)
        v.avatarCards = {}
        for k = 1,j do
          table.insert(v.avatarCards,tLaizi[k])
          table.insert(v.avatarCards,v.cards[1])
        end
        return v
      end
    end
  end
end

function cardsHelp.creat_cards(myCards,type,tBe,max)

  local cards = cardsHelp.structure(myCards)
  local nLaiZi,tLaizi = cardsHelp.getLaiZi(myCards)
  local r = {}
  r.max = max%100
  r.type = type
  r.len = #myCards
  r.cards = {}
  r.avatarCards = {}
  table.mergeByAppend(r.cards,myCards)
  for i = 1,nLaiZi do
    table.removebyvalue(r.cards,tLaizi[i])
    table.insert(r.avatarCards,tLaizi[i])
    table.insert(r.avatarCards,tBe[i])
  end
  return r
end

--判断玩家是否只有炸弹了
function cardsHelp.checkOnlyBombs(myCards, type)
  table.sort(myCards, function(a,b)  return (a%100) < (b%100) end) --对手中牌进行排序
  local cards = cardsHelp.structure(myCards)
  local cardcount = table.len(myCards)
  local nLaiZi,tLaizi = cardsHelp.getLaiZi(myCards)
  table.remove(cards,22) --移除癞子牌
  table.remove(cards,21) --移除癞子牌
  if type == 8 then return nil end
  local x = nLaiZi
  for i = 1, #cards do
    local v = cards[i]
    if v.count > 0 and (v.count + x < 4) then
      return nil
    else
      if (v.count > 0) and (v.count < 4) then
        x = x-(4-v.count)
      end
    end
  end
  -- 是否就一个炸弹
  if (cardcount >= 4) then
    if myCards[1]%100 == myCards[cardcount-nLaiZi]%100 then
      local tAvatar = {}
      for i=1,nLaiZi do
        tinsert(tAvatar,myCards[1])
      end
      return cardsHelp.creat_cards(myCards,8,tAvatar,myCards[1])
    end
  end
  --只有炸弹
  for k, v in pairs(cards) do
    if v.count ~= 0 then
      v.type = 8
      v.max = v.cal_value
      v.len = v.count
      v.avatarCards = {}
      return v
    end
  end
  for k, v in pairs(cards) do
    for i=1,nLaiZi do
      if (v.count + i) >= 4 then
        v.type = 8
        v.max = v.cal_value
        v.len = v.count + i
        v.avatarCards = {}
        for j = 1,i do
          table.insert(v.avatarCards,tLaizi[j])
          table.insert(v.avatarCards,v.cards[1])
        end
        return v
      end
    end
  end
end

function cardsHelp.jordan(myCards,nIndex)
  local sum = 0
  for k,v in pairs(myCards) do
    if table.len(v.cards) == nIndex then
      sum = sum + 1
    end
  end
  if sum > 0 then
    return sum
  else
    return false
  end
end

function cardsHelp.avatar(cards,nIndex)
  local t = {}
  for k,v in pairs(cards) do
    if v.count == nIndex then
      tinsert(t,v.cards[1])
    end
  end
  return t
end

local function farmer(user_cards,master,nIndex)
  local other_cards = {1,2,3,4}
  local t = {}
  for k,v in pairs(other_cards) do
    if v~=master.seatid then
      t[k] = table.len(user_cards[k])
    end
  end
  for k,v in pairs(t) do
    if v == nIndex then
      return true
    end
  end
end
------------------------------------------------------------------------------- >
function cardsHelp.error_deal(myCards,p)
  local cards = cardsHelp.structure(myCards) --对牌组进行排序
  for i = 1, #cards do
    local v = cards[i]
    if v.count >= 1 and v.count <= 3 then
      v.type = v.count
      v.max = v.cal_value
      v.len = v.count
      return v
    end
  end
end

-- 外部接口
-- 自己出牌
-- myCards 我手里的牌，必不为空
-- pre_cards 必不为空
function cardsHelp.get_cards(user_cards,master,p)
  local myCards = user_cards[p.seatid]
  local masterCards = user_cards[master.seatid]
  local cardcount = #myCards --牌的数量
  local cards = cardsHelp.structure(myCards) --对牌组进行排序
  local nLaiZi,tLaizi = cardsHelp.getLaiZi(myCards) --癞子
  local onlyBombs = cardsHelp.checkOnlyBombs(myCards, 1)
  table.sort(myCards, function(a,b)  return (a%100) < (b%100) end) --对手中牌进行排序
  table.remove(cards,22) --移除癞子牌
  table.remove(cards,21) --移除癞子牌
  if onlyBombs then
    return onlyBombs
  end
  ---------------是否能一次出完所有牌---------------------
  --是否是单牌
  if cardcount == 1 then
    local r = {}
    r.max = myCards[1]%100
    r.type = 1
    r.len = 1
    r.cards = {myCards[1]}
    r.avatarCards = {}
    return r
  end
  --是否是对子
  if cardcount == 2 then
    if (nLaiZi == 0 and cardsHelp.jordan(cards,2)) or (nLaiZi == 1) or (nLaiZi == 2 and tLaizi[1] == tLaizi[2]) then
      local tAvatar
      if nLaiZi == 1 then
        tAvatar = cardsHelp.avatar(cards,1)
      elseif nLaiZi == 0 then
        tAvatar = {}
      else
        local r = {}
        r.max = myCards[1]%100
        r.type = 2
        r.len = 2
        r.cards = {myCards[1],myCards[2]}
        r.avatarCards = {}
        return r
      end
      return cardsHelp.creat_cards(myCards,2,tAvatar,myCards[cardcount - nLaiZi])
    end
  end
  --是否是三不带
  if cardcount == 3 then
    if (nLaiZi == 0 and cardsHelp.jordan(cards,3)) or (nLaiZi == 1 and cardsHelp.jordan(cards,2)) or (nLaiZi == 2) then
      local tAvatar
      if nLaiZi == 1 then
        tAvatar = cardsHelp.avatar(cards,2)
      elseif nLaiZi == 2 then
        tAvatar = {myCards[1],myCards[1]}
      else
        tAvatar = {}
      end
      return cardsHelp.creat_cards(myCards,3,tAvatar,myCards[cardcount - nLaiZi])
    end
  end
  --是否是三带一对
  if cardcount == 5 then
    --没有癞子
    if nLaiZi == 0 then
      if (cardsHelp.jordan(cards,3)== 1) and (cardsHelp.jordan(cards,2)== 1) then
        local tAvatar = {}
        return cardsHelp.creat_cards(myCards,4,tAvatar,myCards[cardcount - nLaiZi])
      end
    --一个癞子
    elseif nLaiZi == 1 then
      --两个对子+一个癞子
      if (cardsHelp.jordan(cards,2) == 2) then
        local tAvatar = cardsHelp.avatar(cards,2)
        table.sort(tAvatar)
        table.remove(tAvatar,1)
        return cardsHelp.creat_cards(myCards,4,tAvatar,tAvatar[1])
      --一个单个+三对+癞子
      elseif (cardsHelp.jordan(cards,3) == 1) then
        local tAvatar = cardsHelp.avatar(cards,1)
        local tCopy = table.deepcopy(myCards)
        table.removebyvalue(tCopy,tAvatar[1])
        return cardsHelp.creat_cards(myCards,4,tAvatar,tCopy[1])
      end
    --两个癞子
    elseif nLaiZi == 2 then
      if cardsHelp.jordan(cards,2) == 1 then
        local tAvatar = cardsHelp.avatar(cards,1)
        local tCopy = table.deepcopy(tAvatar)
        table.join(tAvatar,tCopy)
        return cardsHelp.creat_cards(myCards,4,tAvatar,tAvatar[1])
      end
    --三个癞子
    elseif nLaiZi == 3 then
      if cardsHelp.jordan(cards,1) == 2 then
        local tAvatar = cardsHelp.avatar(cards,1)
        table.sort(tAvatar)
        local smaller = table.remove(tAvatar,1)
        local tCopy = table.deepcopy(tAvatar)
        table.join(tAvatar,tCopy)
        tinsert(tAvatar,smaller)
        return cardsHelp.creat_cards(myCards,4,tAvatar,tAvatar[1])
      end
    end
  end
  --是否是连对
  if (cardcount%2 == 0) and (cardcount >= 6) and (cardcount <= 24) then
    local nn = true
    local tAvatar = {}
    local Biggest
    for i =myCards[1]%100,myCards[cardcount-nLaiZi]%100 do
      if (cards[i].count > 2) then
        nn = false
      end
      for j = 1,2-cards[i].count do
        tinsert(tAvatar,100+i)
      end
    end
    if next(tAvatar) == nil then
      if myCards[cardcount-nLaiZi]%100 >= 14 then
        Biggest = myCards[cardcount-nLaiZi]
        for j=1,nLaiZi do
          tinsert(tAvatar,(myCards[1]%100)+99)
        end
      else
        Biggest = myCards[cardcount-nLaiZi]%100+101
        for j=1,nLaiZi do
          tinsert(tAvatar,(myCards[cardcount-nLaiZi]%100)+101)
        end
      end
    else
      Biggest = myCards[cardcount-nLaiZi]
    end
    if ((nLaiZi - #tAvatar)%2 == 0) and (nLaiZi >= #tAvatar)  and nn then
      return cardsHelp.creat_cards(myCards,5,tAvatar,Biggest)
    end
  end
  --是否是三顺
  if (cardcount%3 == 0) then
    local tAvatar = {}
    local nn = true
    for i =myCards[1]%100,myCards[cardcount-nLaiZi]%100 do
      if (cards[i].count > 3) then
        nn = false
      end
      for j = 1,3-cards[i].count do
        tinsert(tAvatar,100+i)
      end
    end
    -- 是否需要癞子
    if next(tAvatar) == nil then
      if myCards[cardcount-nLaiZi]%100 >= 14 then
        Biggest = myCards[cardcount-nLaiZi]
        for j=1,nLaiZi do
          tinsert(tAvatar,(myCards[1]%100)+99)
        end
      else
        Biggest = myCards[cardcount-nLaiZi]%100+101
        for j=1,nLaiZi do
          tinsert(tAvatar,(myCards[cardcount-nLaiZi]%100)+101)
        end
      end
    else
      Biggest = myCards[cardcount-nLaiZi]
    end
    if ((nLaiZi - #tAvatar)%3 == 0) and (nLaiZi >= #tAvatar)  and nn then
      return cardsHelp.creat_cards(myCards,6,tAvatar,Biggest)
    end
  end
  --是否是蝴蝶
  if (cardcount%5 == 0 and cardcount >= 10) then
  end
  ---------------无法一次出完，正常出牌顺序---------------
  ----对手还剩两张牌
  if (table.len(masterCards) == 2 and (p ~= master)) or((p == master) and farmer(user_cards,master,2)) then
    for i = 1,#cards do
      local v = cards[i]
      if v.count == 1 then
        v.type = v.count
        v.max = v.cal_value
        v.len = v.count
        return v
      end
    end
    --双顺
    for i=6,(math.floor(cardcount/2))*2 do
      local press_master = cardsHelp.getLianDui(cards, 5, 1+(i/2), i) or {}
      if next(press_master) then
        return press_master
      end
    end
    for i = #cards,1,-1 do
      local v = cards[i]
      if v.count == 3 then
        v.type = v.count
        v.max = v.cal_value
        v.len = v.count
        return v
      end
    end
    for i = #cards,1,-1 do
      local v = cards[i]
      if v.count == 2 then
        v.type = v.count
        v.max = v.cal_value
        v.len = v.count
        return v
      end
    end
    return cardsHelp.getlowbomb(myCards)
  end
  ----对手还剩一张牌
  if (table.len(masterCards) == 1 and (p ~= master)) or((p == master) and farmer(user_cards,master,1)) then
    for i = 1,#cards do
      local v = cards[i]
      if v.count == 2 then
        v.type = v.count
        v.max = v.cal_value
        v.len = v.count
        return v
      end
    end
    --双顺
    for i=6,(math.floor(cardcount/2))*2 do
      local press_master = cardsHelp.getLianDui(cards, 5, 1+(i/2), i) or {}
      if next(press_master) then
        return press_master
      end
    end
    for i = #cards,1,-1 do
      local v = cards[i]
      if v.count == 3 then
        v.type = v.count
        v.max = v.cal_value
        v.len = v.count
        return v
      end
    end
    for i = #cards,1,-1 do
      local v = cards[i]
      if v.count == 1 then
        v.type = v.count
        v.max = v.cal_value
        v.len = v.count
        return v
      end
    end
    return cardsHelp.getlowbomb(myCards)
  end
  ----队友还剩一张牌
  if table.len(masterCards) ~= 1 and (p ~= master) and farmer(user_cards,master,1) then
    for i = 1, #cards do
      local v = cards[i]
      if v.count >= 1 and v.count <= 3 then
        local r = {}
        r.max = v.cards[1]%100
        r.type = 1
        r.len = 1
        r.cards = {v.cards[1]}
        r.avatarCards = {}
        return r
      end
    end
  end
  --正常出牌
  if (cardcount == 2 and tLaizi[1] ~= tLaizi[2]) then
    local r = {}
    r.max = 21
    r.type = 1
    r.len = 1
    r.cards = {521}
    r.avatarCards = {}
    return r
  end
  for i = 1, #cards do
    local v = cards[i]
    if v.count >= 1 and v.count <= 3 then
      v.type = v.count
      v.max = v.cal_value
      v.len = v.count
      return v
    end
  end
end


--压牌
--myCards 我手里的牌，必不为空
--pre_cards 必不为空
function cardsHelp.press_cards(user_cards, pre_cards,master,p,players)
  local myCards = user_cards[p.seatid]
  local cards = cardsHelp.structure(myCards)
  local type, max, len, uid = pre_cards[1], pre_cards[4], pre_cards[5], pre_cards[6]
  local onlyBombs = cardsHelp.checkOnlyBombs(myCards, type)
  if (master.uid ~= uid) and (p ~= master) then
    local press = user_cards[players[uid].seatid]
    if (type == 8) or (max >= 16) or (#press<=2) then
      return
    end
  end
  if onlyBombs then
    return onlyBombs
  end
  local palycards
  if type == 1 or type == 2 or type == 3 then
    palycards = cardsHelp.cards_normal(cards, type, max)
  elseif type == 4 then
    palycards = cardsHelp.getSanDaiyi(cards, type, max)
  elseif type == 5 then
    palycards = cardsHelp.getLianDui(cards, type, max, len)
  elseif type == 6 then
    palycards = cardsHelp.getSanShun(cards, type, max, len)
  elseif type == 7 then
    palycards = cardsHelp.getHuDie(cards, type, max, len)
  elseif type == 8 then
    palycards = cardsHelp.getbomb(myCards, type, max, len)
  end
  if not palycards or next(palycards) == nil then
    if p == master and type ~= 8 then
      palycards = cardsHelp.getlowbomb(myCards)
    else
      if uid ~= master.uid then
        return
      else
        if type == 8 then 
          return
        else 
          palycards = cardsHelp.getlowbomb(myCards)
        end
      end
    end
  end
  return palycards
end

return cardsHelp

