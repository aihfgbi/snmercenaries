--[[
	麻将根据规则组合牌
]]

local tinsert = table.insert
local tremove = table.remove
local tindexof = table.indexof

local this = {}
local origin_wall = {}
local shifter1 = 0
local shifter2 = 0
local shifter_num1
local shifter_num2
local COMBINE = {}

local weight = {
	pinghu = 30,
	qidui = 5,
	qingyise = 6,
	qingqidui = 3,
	pengpenghu = 5,
	hunyise = 8,
	hunduidui = 6,
	longqidui = 5,
	shisanyao = 3,
	ziyise = 10,
	shibaluohan = 0,
}

--万条筒风
local WAN, TIAO, TONG, FENG = 1, 2, 3, 4


--加权随机
local function random_by_weight(t)
	local sum = 0
	for _,v in pairs(t) do
		sum = sum + v
	end
	local random_index = math.random(1, sum)
	local cnt = 0
	for k, v in pairs(t) do
		cnt = cnt + v
		if random_index <= cnt then
			return k
		end
	end
end

local function get_id2tiles( ... )
	local idx2tile = {}
	for k, v in pairs(origin_wall) do
		if v > 0 then
			tinsert(idx2tile, k)
		end
	end
	return idx2tile
end

--按万条筒字分牌
local function get_type_tiles( ... )
	local tiles = {{},{},{},{}}
	for k, v in pairs(origin_wall) do
		if v > 0 then
			local card_type = math.floor(k/10)
			if card_type > 3 then
				tinsert(tiles[4], k)
			else
				tinsert(tiles[card_type], k)
			end
		end
	end
	return tiles
end

--所有牌  index:1万 2条 3筒 4风 nil则表示所有
local function get_all_tiles(index)
	local tiles = {{},{},{},{}}
	for k, v in pairs(origin_wall) do
		for i=1,v do
			local card_type = math.floor(k/10)
			if card_type > 3 then
				tinsert(tiles[4], k)
			else
				tinsert(tiles[card_type], k)
			end
		end
	end
	
	return tiles[index] or tiles
end

--从数组arrey_pool中无放回的随机num个
local function random_non_replacement(arrey_pool, num)
	if type(arrey_pool) == "number" then
		local n = arrey_pool
		arrey_pool = {}
		for i=1, n do
			tinsert(arrey_pool, i)
		end
	end
	assert(#arrey_pool >= num)
	local rst = {}
	for i=1, num do
		local index = math.random(#arrey_pool)
		tinsert(rst, arrey_pool[index])
		tremove(arrey_pool, index)
	end
	return rst
end

--平胡牌
function COMBINE.pinghu()
	local all_tiles = get_all_tiles()
	
	for type, tiles in pairs(all_tiles) do
		table.sort(tiles)
	end
	local shun_pool = {}
	local shun_random_pool = {}
	for i=1, 3 do
		local temp_shun
		while true do
			for j,v in ipairs(all_tiles[i]) do
				if not temp_shun then
					temp_shun = {}
					tinsert(temp_shun, v)
				elseif v == temp_shun[#temp_shun] + 1 then
					tinsert(temp_shun, v)
				elseif v > temp_shun[#temp_shun] + 1 then
					if #temp_shun >= 3 then
						break
					else
						table.clear(temp_shun)
						tinsert(temp_shun, v)
					end
				end
			end

			if temp_shun and #temp_shun >= 3 then
				tinsert(shun_pool, temp_shun)
				for _,v in ipairs(temp_shun) do
					table.removebyvalue(all_tiles[i], v)
				end
				temp_shun = nil
			else
				break
			end
		end
	end
	
	for _,v in ipairs(shun_pool) do 
		if #v == 3 then
			tinsert(shun_random_pool, v)
		elseif #v == 4 then
			local index = math.random(1,2)
			local t = {}
			for i=index,index+2 do
				tinsert(t, v[i])
			end
			tinsert(shun_random_pool, t)
		elseif #v == 5 then
			local index = math.random(1,3)
			local t = {}
			for i=index,index+2 do
				tinsert(t, v[i])
			end
			tinsert(shun_random_pool, t)
		elseif #v >= 6 then
			local index = math.floor(#v/2)
			local index1 = math.random(1,index-2)
			local index2 = math.random(index+1,#v-2)
			
			local t = {}
			for i=index2,index2+2 do
				tinsert(t,v[i])
			end
			
			tinsert(shun_random_pool, table.arraycopy(t))
			table.clear(t)
			for i=index1,index1+2 do
				tinsert(t,v[i])
			end
			tinsert(shun_random_pool, table.arraycopy(t))
		end
	end

	local result_shun
	if #shun_random_pool > 4 then
		result_shun = {}
		local tmp_arr = {}
		for i=1,#shun_random_pool do
			tinsert(tmp_arr,i)
		end
		local index_arr = random_non_replacement(tmp_arr, 4)
		for _,idx in ipairs(index_arr) do
			tinsert(result_shun, table.arraycopy(shun_random_pool[idx]))
		end
	else
		result_shun = table.deepcopy(shun_random_pool)
	end
	local tmp_origin_wall = table.deepcopy(origin_wall)  
	local ke_pool = {}
	for _,v in ipairs(result_shun) do
		for i,tile in ipairs(v) do
			tmp_origin_wall[tile] = tmp_origin_wall[tile] - 1
			assert(tmp_origin_wall[tile] >= 0)
		end
	end
	for tile,num in pairs(tmp_origin_wall) do
		if num >= 3 then
			tinsert(ke_pool, tile)
		end
	end
	local result_ke
	if #ke_pool > 4 then
		result_ke = {}
		local tmp_arr = {}
		for i=1,#ke_pool do
			tinsert(tmp_arr,i)
		end
		local index_arr = random_non_replacement(tmp_arr, 4)
		for _,idx in ipairs(index_arr) do
			tinsert(result_ke, ke_pool[idx])
		end
	else
		result_ke = table.deepcopy(ke_pool)
	end
	if #result_ke + #result_shun < 4 then
		return
	end
	for _,v in ipairs(result_ke) do
		tmp_origin_wall[v] = tmp_origin_wall[v] - 3
		assert(tmp_origin_wall[v] >= 0)
	end
	local dui_pool = {}
	for tile,num in pairs(tmp_origin_wall) do
		if num >= 2 then
			tinsert(dui_pool, tile)
		end
	end
	if #dui_pool < 1 then
		return 
	end
	local result_dui = dui_pool[math.random(#dui_pool)]
	local shun_num, ke_num
	if #result_ke + #result_shun == 4 then
		shun_num = #result_shun
	elseif #result_ke == 0 then
		shun_num = 4
	elseif #result_shun <= 3 then
		shun_num = #result_shun
	else
		if math.random(100) > 70 then
			shun_num = 3
		else
			shun_num = 4
		end
	end
	ke_num = 4 - shun_num
	local ke_index
	local shun_index
	if ke_num > 0 then
		ke_index = random_non_replacement(#result_ke, ke_num)
	end
	shun_index = random_non_replacement(#result_shun, shun_num)
	local tiles = {}
	if ke_index then
		for i,idx in ipairs(ke_index) do
			for j=1,3 do
				tinsert(tiles, result_ke[idx])
			end
		end
	end

	for i,idx in ipairs(shun_index) do
		for _,tile in ipairs(result_shun[idx]) do
			tinsert(tiles, tile)
		end
	end

	for i=1, 2 do
		tinsert(tiles, result_dui)
	end
--	PRINT_T(tiles)
	return tiles
end

--七对
function COMBINE.qidui()
--	LOG_DEBUG("qidui")
	local random_pool = {}

	for k, v in pairs(origin_wall) do
		if v >= 2 then
			tinsert(random_pool, k)
		end
	end
	if #random_pool < 7 then
		return
	end
	local tiles = {}
	local tile_indexs = random_non_replacement(random_pool, 7)

	for i=1, 2 do
		for _,t in ipairs(tile_indexs) do
			tinsert(tiles, t)
		end
	end

	return tiles
end

--清一色
function COMBINE.qingyise()
	local all_tiles = get_all_tiles()
	local random_type_pool = {}
	local tiles_pool = {}
	local type_order = {}
	for ttype,v in pairs(all_tiles) do
		if #v >= 14 and ttype <= 3 then
			tinsert(random_type_pool, ttype)
			tiles_pool[ttype] = table.arraycopy(v)
			if not next(type_order) then
				tinsert(type_order, ttype)
			else
				local flag = true
				for i=1, #type_order do
					if #v >= #(all_tiles[type_order[i]]) then
						tinsert(type_order, i, ttype)
						flag = false
						break
					end
				end
				if flag then
					tinsert(type_order,ttype)
				end
			end
		end
	end

	if not next(random_type_pool) then
		return
	end
	
	local tiles = {}
	--随机万条筒
--	local card_type = random_type_pool[math.random(#random_type_pool)]
	for _, card_type in ipairs(type_order) do
		local shun_pool = {}
		local shun_random_pool = {}
		
		local temp_shun
		local tonghua_tiles = {}
		for k,v in pairs(tiles_pool[card_type]) do
			tonghua_tiles[v] = (tonghua_tiles[v] or 0) + 1
		end
		
		while true do
			for j,v in ipairs(tiles_pool[card_type]) do
				if not temp_shun then
					temp_shun = {}
					tinsert(temp_shun, v)
				elseif v == temp_shun[#temp_shun] + 1 then
					tinsert(temp_shun, v)
				elseif v > temp_shun[#temp_shun] + 1 then
					if #temp_shun >= 3 then
						break
					else
						table.clear(temp_shun)
						tinsert(temp_shun, v)
					end
				end
			end

			if temp_shun and #temp_shun >= 3 then
				tinsert(shun_pool, temp_shun)
				for _,v in ipairs(temp_shun) do
					table.removebyvalue(tiles_pool[card_type], v)
				end
				temp_shun = nil
			else
				break
			end
		end
	--	PRINT_T(shun_pool)
		for _,v in ipairs(shun_pool) do 
			if #v == 3 then
				tinsert(shun_random_pool, v)
			elseif #v == 4 then
				local index = math.random(1,2)
				local t = {}
				for i=index,index+2 do
					tinsert(t, v[i])
				end
				tinsert(shun_random_pool, t)
			elseif #v == 5 then
				local index = math.random(1,3)
				local t = {}
				for i=index,index+2 do
					tinsert(t, v[i])
				end
				tinsert(shun_random_pool, t)
			elseif #v >= 6 then
				local index = math.floor(#v/2)
				local index1 = math.random(1,index-2)
				local index2 = math.random(index+1,#v-2)
				
				local t = {}
				for i=index2,index2+2 do
					tinsert(t,v[i])
				end
				
				tinsert(shun_random_pool, table.arraycopy(t))
				table.clear(t)
				for i=index1,index1+2 do
					tinsert(t,v[i])
				end
				tinsert(shun_random_pool, table.arraycopy(t))
			end
		end
	--	PRINT_T(shun_random_pool)
		if #shun_random_pool >= 4 then
			local indexs = random_non_replacement(#shun_random_pool, 4)
			local result_shun = {}
			for _,idx in ipairs(indexs) do
				tinsert(result_shun, shun_random_pool[idx])
			end
			
			for k,v in ipairs(result_shun) do
				for _,tile in ipairs(v) do
					tonghua_tiles[tile] = tonghua_tiles[tile] - 1
				end
			end
			local dui = {}
			
			for tile, num in pairs(tonghua_tiles) do
				if num >= 2 then
					tinsert(dui, tile)
				end
			end
			
			if #dui >= 1 then
				local index = random_non_replacement(#dui, 1)
				local result_dui = {dui[index[1]], dui[index[1]]}
				for _, v in ipairs(result_shun) do
					table.mergeByAppend(tiles, v)
				end
				table.mergeByAppend(tiles, result_dui)
			end
		end
		if next(tiles) then
			break
		end
	end
	
	if not next(tiles) then
		return
	end
	
	return tiles
end

--清七对
function COMBINE.qingqidui()
	
	local tiles_pool = {[WAN]={},[TIAO]={},[TONG]={}}
--	PRINT_T(tiles_pool)
	local type_pool = {}
	local card_type
	for tile, num in pairs(origin_wall) do
		if num >= 2 then 
			card_type = math.floor(tile/10)
			if card_type < 4 then
				tinsert(tiles_pool[card_type], tile)
			end
		end
	end

	for k,v in pairs(tiles_pool) do
		if #v >= 7 then
			tinsert(type_pool, k)
		end
	end
	if not next(type_pool) then
		return
	end
	card_type = type_pool[math.random(#type_pool)]
	local tiles = {}
	local tmp = random_non_replacement(tiles_pool[card_type], 7)
	for i=1, 2 do
		for _,t in ipairs(tmp) do
			tinsert(tiles, t)
		end
	end

	return tiles
end

--碰碰胡
function COMBINE.pengpenghu()
	local ke_pool = {}
	local eye_pool = {}
	for tile, num in pairs(origin_wall) do
		if num >= 3 then 
			tinsert(ke_pool, tile)
		end
	end

	if #ke_pool < 4 then
		return false
	end
	local ke_tiles = random_non_replacement(ke_pool, 4)

	local wall_plus = table.deepcopy(origin_wall) 
	for tile, num in pairs(wall_plus) do
		if tindexof(ke_tiles, tile) then
			wall_plus[tile] = wall_plus[tile] - 3
		end
		if wall_plus[tile] >= 2 then
			tinsert(eye_pool, tile)
		end
	end

	if not next(eye_pool) then
		return false
	end
	local tiles = {}
	local eye_tiles = {eye_pool[math.random(#eye_pool)]}
	for _, tile in ipairs(ke_tiles) do
		for i=1, 3 do
			tinsert(tiles, tile)
		end
	end
	for _, tile in ipairs(eye_tiles) do
		for i=1, 2 do
			tinsert(tiles, tile)
		end
	end

	return tiles
end

--混一色 至少一对风
--风的组合 一对 一刻 一对一刻 两刻
function COMBINE.hunyise()
	local hua_tiles = COMBINE.qingyise()
	if not hua_tiles then return end
	local pair = {
		[2] = {0,2},
		[3] = {1,0},
		[4] = {0,1},
		[6] = {1,1},
	}
	local total_weight = 2 + 3 + 4 + 6
	local random_num = math.random(total_weight)
	local dui_num = 0
	local ke_num = 0
	if random_num <= 2 then
		dui_num = pair[2][1]
		ke_num = pair[2][2]
	elseif random_num <= 5 then
		dui_num = pair[3][1]
		ke_num = pair[3][2]
	elseif random_num <= 9 then
		dui_num = pair[4][1]
		ke_num = pair[4][2]
	else
		dui_num = pair[6][1]
		ke_num = pair[6][2]
	end

	local function find_feng( ... )
		local feng_wall = {}
		local ke_pool = {}
		for tile, num in pairs(origin_wall) do
			if math.floor(tile/10) > 3 then
				if num >= 2 then
					feng_wall[tile] = num
				end
				if num >= 3 then
					tinsert(ke_pool, tile)
				end
			end
		end
		local result_ke = {}
		if ke_num > 0 then
			if #ke_pool < ke_num then return end
			
			local indexs = random_non_replacement(#ke_pool, ke_num)

			for _,idx in ipairs(indexs) do
				tinsert(result_ke, ke_pool[idx])
			end
		end
		local result_dui
		if dui_num > 0 then
			local dui_pool = {}
			for tile,num in pairs(feng_wall) do
				if not tindexof(result_ke, tile) then
					tinsert(dui_pool, tile)
				end
			end
			if #dui_pool < dui_num then return end
			result_dui = dui_pool[math.random(#dui_pool)]
		end
		local fengs = {}
		for _,tile in ipairs(result_ke) do
			for i=1, 3 do
				tinsert(fengs, tile)
			end
		end
		if result_dui then
			tinsert(fengs, result_dui)
			tinsert(fengs, result_dui)
		end
		return fengs
	end
	
	local feng_tiles = find_feng()
	if not feng_tiles then
		for k,v in pairs(pair) do
			dui_num = v[1]
			ke_num = v[2]
			feng_tiles = find_feng()
			if feng_tiles then break end
		end
	end
	if not feng_tiles or not next(feng_tiles) then return end

	if dui_num > 0 then
		tremove(hua_tiles)
		tremove(hua_tiles)
	end
	for i=1, ke_num*3 do
		tremove(hua_tiles, 1)
	end

	table.mergeByAppend(hua_tiles, feng_tiles)

	return hua_tiles

	-- local feng_pool = {}
	-- local feng_cnt = 0

	-- for tile, num in pairs(origin_wall) do
	-- 	if math.floor(tile/10) > 3 then
	-- 		if num >= 2 then
	-- 			feng_pool[tile] = num
	-- 			feng_cnt = feng_cnt + num
	-- 		end
	-- 	end
	-- end
	-- if feng_cnt < 2 then
	-- 	return 
	-- end
	-- local pair = {
	-- 	[2] = {1,0},
	-- 	[3] = {0,1},
	-- 	[4] = {2,0},
	-- 	[5] = {1,1},
	-- 	[6] = {0,2},
	-- 	[7] = {2,1},
	-- 	[8] = {3,0},
	-- }
	-- --考虑到各种组合 这里做10次随机,若10次都不满足则认为不能组合该牌型
	-- local random_max
	-- local idx
	-- local feng_dui_num
	-- local feng_ke_num 
	-- local ke_pool = {}
	-- local dui_pool = {}
	-- local ke_tiles
	-- local dui_tiles
	-- local combine_success
	-- random_max = (feng_cnt <= 8) and feng_cnt or 8
	-- --这里还可以考虑每循环一次random_max-1
	-- for i=1, 10 do
	-- 	table.clear(ke_pool)
	-- 	table.clear(dui_pool)
	-- 	ke_tiles = nil
	-- 	dui_tiles = nil
	-- 	idx = math.random(2,random_max)
	-- 	feng_dui_num = pair[idx][1]
	-- 	feng_ke_num = pair[idx][2]
	-- 	local feng_pool_plus = table.deepcopy(feng_pool)
	-- 	for tile, num in pairs(feng_pool_plus) do
	-- 		if num >= 3 then
	-- 			tinsert(ke_pool, tile)
	-- 		end
	-- 	end
	-- 	if #ke_pool >= feng_ke_num then
	-- 		ke_tiles = random_non_replacement(ke_pool, feng_ke_num)
	-- 		for _,tile in ipairs(ke_tiles) do
	-- 			feng_pool_plus[tile] = feng_pool_plus[tile] - 3
	-- 		end

	-- 		for tile, num in pairs(feng_pool_plus) do
	-- 			if num >= 2 then
	-- 				tinsert(dui_pool, tile)
	-- 			end
	-- 		end
	-- 		if #dui_pool >= feng_dui_num then
	-- 			dui_tiles = random_non_replacement(dui_pool, feng_dui_num)
	-- 			for _,tile in ipairs(ke_tiles) do
	-- 				feng_pool_plus[tile] = feng_pool_plus[tile] - 2
	-- 			end
	-- 			combine_success = true
	-- 			break
	-- 		end
	-- 	end
	-- end
	
	-- if not combine_success then
	-- 	return
	-- end
	-- local fen_num = 3*feng_ke_num + 2*feng_dui_num
	-- local hua_num = 14 - fen_num
	-- local all_tiles = get_all_tiles() 
	-- local type_pool = {}
	-- for ctype,v in pairs(all_tiles) do
	-- 	if ctype < 4 and #v >= hua_num then
	-- 		tinsert(type_pool, ctype)
	-- 	end
	-- end

	-- if not next(type_pool) then return end
	-- local hua_type = type_pool[math.random(#type_pool)]
	-- local hua_tiles = random_non_replacement(all_tiles[hua_type], hua_num)
	-- local tiles = {}
	-- for _,tile in ipairs(ke_tiles) do
	-- 	for i=1, 3 do
	-- 		tinsert(tiles, tile)
	-- 	end
	-- end
	-- for _,tile in ipairs(dui_tiles) do
	-- 	for i=1, 2 do
	-- 		tinsert(tiles, tile)
	-- 	end
	-- end
	-- table.mergeByAppend(tiles, hua_tiles)
	-- LOG_DEBUG("hunyise")
	-- return tiles
end

--混对对
function COMBINE.hunduidui()
	local eye_type 
	local random_max 
	local feng_ke_num
	local feng_pool = {}
	for tile, num in pairs(origin_wall) do
		if math.floor(tile/10) > 3 then
			if num >= 2 then
				feng_pool[tile] = num
			end
		end
	end
	local feng_ke_pool
	local feng_dui_pool
	local ke_tiles
	local dui_tiles
	for i=1, 10 do
		local feng_pool_plus = table.deepcopy(feng_pool)
		eye_type = math.random(4)
		random_max = (eye_type == 4) and 3 or 4
		feng_ke_num = math.random(random_max)
		feng_ke_pool = {}
		feng_dui_pool = {}
		for tile, num in pairs(feng_pool_plus) do
			if num >= 3 then
				tinsert(feng_ke_pool, tile)
			end
		end

		if #feng_ke_pool < feng_ke_num then goto continue end
		ke_tiles = random_non_replacement(feng_ke_pool, feng_ke_num)
		if eye_type == 4 then
			for _,tile in ipairs(ke_tiles) do
				feng_pool_plus[tile] = feng_pool_plus[tile] - 3
			end
			for tile, num in pairs(feng_pool_plus) do
				if num >= 2 then
					tinsert(feng_dui_pool, tile)
				end
			end
			if not next(feng_dui_pool) then goto continue end
			dui_tiles = random_non_replacement(feng_dui_pool, 1)
		end
		break

	::continue::
		feng_ke_pool = nil
		feng_dui_pool = nil
		ke_tiles = nil
	end
	if not ke_tiles then
		LOG_WARNING("no ke_tiles")
		return 
	end
	
	local hua_ke_num = 4 - feng_ke_num
	local hua_pool = {{},{},{}}
	local hua_ke_pool = {{},{},{}}
	for tile, num in pairs(origin_wall) do
		local card_type = math.floor(tile/10)
		if card_type < 4 then 
			if num >= 2 then
				hua_pool[card_type][tile] = num
				if num >= 3 then
					hua_ke_pool[card_type][tile] = num
				end
			end
		end
	end

	local hua_dui_tiles
	local hua_ke_tiles
	local function random_hua_dui( ... )
		local hua_type_random_pool = {}
		for ctype, v in pairs(hua_pool) do
			if table.len(v) >= 0 then
				tinsert(hua_type_random_pool, ctype)
			end
		end
		if #hua_type_random_pool == 0 then
			LOG_WARNING("no hua_type_random_pool")
			return 
		end
		eye_type = hua_type_random_pool[math.random(#hua_type_random_pool)]
		local tmp = {}
		for tile,_ in pairs(hua_pool[eye_type]) do
			tinsert(tmp, tile)
		end
		if not next(tmp) then
			return
		end
		local tiles = random_non_replacement(tmp, 1)
		hua_pool[eye_type][tiles[1]] = hua_pool[eye_type][tiles[1]] - 2
		hua_ke_pool[eye_type][tiles[1]] = nil
		return tiles
	end

	if hua_ke_num == 0 then
		assert(eye_type ~= 4)
		hua_dui_tiles = random_hua_dui()
		if not hua_dui_tiles then
			LOG_WARNING("no hua_dui_tiles")
			return
		end
	else
		if eye_type ~= 4 then
			hua_dui_tiles = random_hua_dui()
			if not hua_dui_tiles then
				LOG_WARNING("no hua_dui_tiles")
				return
			end
		end
		local hua_type_random_pool = {} 
		
		for ctype, v in pairs(hua_ke_pool) do
			if table.len(v) >= hua_ke_num then
				tinsert(hua_type_random_pool, ctype)
			end
		end
		if not next(hua_type_random_pool) then 
			LOG_WARNING("no hua_type_random_pool")
			return 
		end
		eye_type = hua_type_random_pool[math.random(#hua_type_random_pool)]
		local tmp = {}
		for tile,_ in pairs(hua_ke_pool[eye_type]) do
			tinsert(tmp, tile)
		end
		hua_ke_tiles = random_non_replacement(tmp, hua_ke_num)
		if not hua_ke_tiles then
			LOG_WARNING("no hua_ke_tiles")
			return
		end
	end
	
	local tiles = {}
	for _,tile in ipairs(ke_tiles or {}) do
		for i=1,3 do
			tinsert(tiles, tile)
		end
	end

	for _,tile in ipairs(hua_ke_tiles or {}) do
		for i=1,3 do
			tinsert(tiles, tile)
		end
	end

	for _,tile in ipairs(dui_tiles or {}) do
		for i=1,2 do
			tinsert(tiles, tile)
		end
	end

	for _,tile in ipairs(hua_dui_tiles or {}) do
		for i=1,2 do
			tinsert(tiles, tile)
		end
	end

	return tiles
end

--龙七对
function COMBINE.longqidui()
	local gang_pool = {}
	local dui_pool = {}
	for tile,num in pairs(origin_wall) do
		if num >= 2 then
			tinsert(dui_pool, tile)
			if num == 4 then
				tinsert(gang_pool, tile)
			end
		end
		
	end
	if #gang_pool < 1 or #dui_pool < 6 then
		return
	end
	local gang_tiles
	gang_tiles = random_non_replacement(gang_pool, 1)
	table.removebyvalue(dui_pool, gang_tiles[1])
	local dui_tiles = random_non_replacement(dui_pool, 5)
	local tiles = {}
	for i=1,4 do
		tinsert(tiles, gang_tiles[1])
	end
	for _,tile in ipairs(dui_tiles) do
		for i=1,2 do
			tinsert(tiles, tile)
		end
	end

	return tiles
end

--十三幺
function COMBINE.shisanyao()
	local idx2tile = get_id2tiles()
	for _,tile in ipairs(SHI_SAN_YAO) do
		if tile ~= shifter1 and tile ~= shifter2 and not tindexof(idx2tile, tile) then
			return
		end
	end
	
	local tiles = table.arraycopy(SHI_SAN_YAO)
	local lack_tile_pool = {}
	for tile,num in pairs(origin_wall) do
		if tindexof(tiles, tile) and num > 1 then
			tinsert(lack_tile_pool, tile)	
		end
	end

	tinsert(tiles, lack_tile_pool[math.random(#lack_tile_pool)])

	return tiles
end

--字一色
function COMBINE.ziyise()
	local feng_ke_pool = {}
	local feng_dui_pool = {}
	for tile,num in pairs(origin_wall) do
		if num >= 2 then
			tinsert(feng_dui_pool, tile)
			if num >= 3 then
				tinsert(feng_ke_pool, tile)
			end
		end	
	end

	if #feng_ke_pool < 4 then
		return 
	end
	local ke_tiles = random_non_replacement(feng_ke_pool, 4)
	for _, tile in ipairs(ke_tiles) do
		table.removebyvalue(feng_dui_pool, tile)
	end
	if #feng_dui_pool < 1 then
		return
	end
	local dui_tiles = random_non_replacement(feng_dui_pool, 1)
	local tiles = {}
	for _,tile in ipairs(ke_tiles) do
		for i=1,3 do
			tinsert(tiles, tile)
		end
	end
	for i=1,2 do
		tinsert(tiles, dui_tiles[1])
	end
	
	return tiles
end

--十八罗汉
function COMBINE.shibaluohan()
	LOG_DEBUG("shibaluohan")
	local tiles = {}
	
	return tiles
end

local function init_wall(fengpai)
	for k,v in pairs(MJ_TILE) do
		for tile,_ in pairs(v) do
			if fengpai or (math.floor(tile/10) < 4) then
				if tile ~= shifter1 and tile ~= shifter2 then
					origin_wall[tile] = 4
				end
			end
		end
	end
end

function this.random_non_replacement(array, num)
	return random_non_replacement(array, num)
end

--[[
@param guipai:鬼牌(癞子牌)
@param rule:是否组牌
@param fengpai:是否有风
@param prior:是否有优先牌
]]
function this.build_mj_card(guipai1, guipai2, fengpai)
--	prior = prior or 0
	shifter1 = guipai1 or 0
	shifter2 = guipai2 or 0
	shifter_num1 = shifter1 > 0 and 4 or 0
	shifter_num2 = shifter2 > 0 and 4 or 0
	
	init_wall(fengpai)
	local tiles = {}
	local i = 0
--	PRINT_T(origin_wall)
	local win_tiles
	local rule
	if fengpai then
		while #tiles < 4 do
			rule = random_by_weight(weight)
			local f = assert(COMBINE[rule])
			local t = f()
			if t then
				table.sort(t)
				for k, v in ipairs(t) do
					if v == shifter1 then
						shifter_num1 = shifter_num1 - 1
					elseif v == shifter2 then
						shifter_num2 = shifter_num2 - 1
					else
						origin_wall[v] = origin_wall[v] - 1
						assert(origin_wall[v] >= 0)
					end
				end
				LOG_DEBUG(rule)
				table.insert(tiles, t)
			end
			i = i+1
		--	print(i)
			--最多循环组合20次
			if i > 20 then
				break
			end
		end
	end
	-- PRINT_T(tiles)
	
	local function get_all()
		local t = {}
		for tile, num in pairs(origin_wall) do
			for i=1, num do
				tinsert(t, tile)
			end
		end
		return t
	end
	local tmp_wall
	if #tiles < 4 then
		tmp_wall = get_all()

		for i=1, (4 - #tiles) do
			tinsert(tiles, random_non_replacement(tmp_wall, 14))
			for _,tile in ipairs(tiles[#tiles]) do
				origin_wall[tile] = origin_wall[tile] - 1
				assert(origin_wall[tile] >= 0)
			end
		end
	end
	-- local prior_wall
	-- for i,v in ipairs(tiles) do
	-- 	local lack_tiles
	-- 	if prior > 0 and i==prior then
	-- 		lack_tiles = {}
	-- 		prior_wall = random_non_replacement(tiles[i], math.random(1,4))
	-- 	else
	-- 		lack_tiles = random_non_replacement(tiles[i], math.random(4,6))
	-- 	end
	-- 	for _,tile in ipairs(lack_tiles) do
	-- 		if tile == shifter then
	-- 			shifter_num = shifter_num + 1
	-- 		else
	-- 			origin_wall[tile] = origin_wall[tile] + 1
	-- 		end
	-- 	end
	-- end
	-- tmp_wall = nil
	-- tmp_wall = get_all()
	-- for i,v in ipairs(tiles) do
	-- 	local fill_tile = random_non_replacement(tmp_wall, 13-(#v))
	-- 	table.mergeByAppend(tiles[i], fill_tile)
	-- 	for _,tile in ipairs(fill_tile) do
	-- 		origin_wall[tile] = origin_wall[tile] - 1
	-- 		assert(origin_wall[tile] >= 0)
	-- 	end
	-- end
	-- PRINT_T(tiles)
	-- PRINT_T(prior_wall)
	local wall = {}
	for k,v in pairs(origin_wall) do
		for i=1, v do
			tinsert(wall, k)
		end
	end
	if shifter1 > 0 then
		for i=1, shifter_num1 do
			tinsert(wall, shifter1)
		end
	end
	if shifter2 > 0 then
		for i=1, shifter_num2 do
			tinsert(wall, shifter2)
		end
	end


--	PRINT_T(tiles)
	-- local cnt = 0
	-- for k,v in ipairs(tiles) do
	-- 	cnt = cnt + #v
	-- end
	-- local all_tiles_num = cnt+#wall
	-- LOG_WARNING("all tiles num[%d]", all_tiles_num)
	-- assert(all_tiles_num == 136)

	-- local test_origin_wall = {}
	-- for k,v in ipairs(tiles) do
	-- 	for _,tile in ipairs(v) do
	-- 		test_origin_wall[tile] = (test_origin_wall[tile] or 0) + 1
	-- 	end
	-- end

	-- for i,tile in ipairs(wall) do
	-- 	test_origin_wall[tile] = (test_origin_wall[tile] or 0) + 1
	-- end
	-- for tile,num in pairs(test_origin_wall) do
	-- 	assert(num == 4)
	-- end
--	PRINT_T(test_origin_wall)
	return wall, tiles
end

return this