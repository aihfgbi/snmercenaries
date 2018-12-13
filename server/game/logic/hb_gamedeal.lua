--黑豹的月亮算法

--group说明
--[[
	【1】猫头鹰，狐狸 	2 (0,2,25,125,750)
	【2】蝴蝶       	3 (0,0,20,100,500)
	【3】蓝花，红花		3 (0,0,15,75,250)
	【4】9				2 (0,2,5,25,100)
	【5】10，J			3 (0,0,5,25,100)
	【6】Q				3 (0,0,5,30,125)
	【7】K，A			3 (0,0,10,40,150)
	【8】豹子			2 (0,10,250,2500,10000)
	【9】月亮			2 (0,2,5,20,500)
]]

local deal = {}
local group = {1,1,2,3,3,4,5,5,6,7,7,8,9}
local group_min_num = {2,3,3,2,3,3,3,2,2}
local group_beilv = {
	{0, 2, 25, 125, 750},
	{0, 0, 20, 100, 500},
	{0, 0, 15, 75, 250},
	{0, 2, 5, 25, 100},
	{0, 0, 5, 25, 100},
	{0, 0, 5, 30, 125},
	{0, 0, 10, 40, 150},
	{0, 10, 250, 2500, 10000},
	{0, 2, 5, 20, 500}
}
deal.line_box = {
	{2, 2, 2, 2, 2},
	{3, 3, 3, 3, 3},
	{1, 1, 1, 1, 1},
	{3, 2, 1, 2, 3},
	{1, 2, 3, 2, 1},
	{2, 3, 3, 3, 2},
	{2, 1, 1, 1, 2},
	{3, 3, 2, 1, 1},
	{1, 1, 2, 3, 3},
	{2, 1, 2, 3, 2},
	{2, 3, 2, 1, 2},
	{3, 2, 2, 2, 3},
	{1, 2, 2, 2, 1},
	{3, 2, 3, 2, 3},
	{1, 2, 1, 2, 1}
}

--数据赋值
function deal.assResult(result, bet, free)
	if #result ~= 15 then
		return
	end

	--定义变量
	local wintype = {}
	local wingold = {}
	local winorder = {}
	local winnumber = {}
	local randomtime = 0
	local total_wingold = 0
	local more_game_num = 0
	local box_type = {{}, {}, {}, {}, {}}
	local box_group = {{}, {}, {}, {}, {}}
	local now_result = {}

	--月亮个数赋值
	for k,v in pairs(result) do
		if v == 13 then
			more_game_num = more_game_num + 1
		end
	end

	--排序赋值
	for i=1,5 do
		box_type[i][1] = result[3 * i - 0]
		box_type[i][2] = result[3 * i - 1]
		box_type[i][3] = result[3 * i - 2]
		box_group[i][1] = group[box_type[i][1]]
		box_group[i][2] = group[box_type[i][2]]
		box_group[i][3] = group[box_type[i][3]]
	end

	--判断15条线
	for i=1,15 do
		--定义变量
		local double
		local now_group
		local now_group_num = 0
		for k,val in pairs(deal.line_box[i]) do
			 if not now_group then
			 	now_group = box_group[k][val]
			 	now_group_num = now_group_num + 1

			 	--判断是否是月亮
			 	if now_group == 9 then
			 		break
			 	end
			 elseif now_group == box_group[k][val] then
			 	now_group_num = now_group_num + 1
			 else
			 	if box_group[k][val] == 8 then
			 		double = true
			 		now_group_num = now_group_num + 1
			 	else
			 		break
			 	end
			 end
		end

		--判断赋值
		if now_group_num >= group_min_num[now_group] then
			winorder[i] = 0
			wintype[i] = now_group
			winnumber[i] = now_group_num
			if free then
				wingold[i] = bet * 3
			else
				if double then
					wingold[i] = bet * group_beilv[now_group][now_group_num] * 2
				else
					wingold[i] = bet * group_beilv[now_group][now_group_num]
				end
			end
			total_wingold = total_wingold + wingold[i]
		else
			wintype[i] = 0
			wingold[i] = 0
			winorder[i] = 0
			winnumber[i] = 0
		end
	end

	--增加特殊奖励算法
	if more_game_num > 1 then
		winorder[16] = 0
		wintype[16] = 9
		winnumber[16] = more_game_num
		if free then
			wingold[16] = bet * 15 * 3
		else
			wingold[16] = bet * 15 * group_beilv[9][more_game_num]
		end
		total_wingold = total_wingold + wingold[16]

		--判断赋值
		if more_game_num > 2 then
			randomtime = 15
		end
	end

	--数据赋值
	now_result.wintype = wintype
	now_result.wingold = wingold
	now_result.winorder = winorder
	now_result.winnumber = winnumber
	now_result.randomtime = randomtime
	now_result.wintotal = math.floor(total_wingold)
	now_result.showcards = result
	return now_result
end

--获取牌大小
local function getValue(card)
    return card % 100
end

--比牌大小
function deal.compareCard(card1, card2)
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

return deal