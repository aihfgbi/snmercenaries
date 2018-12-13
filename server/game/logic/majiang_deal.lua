--
--	Filename:		algorithm.lua
--	Author:			fengqiang
--	Create:			2016-09-10 09:16:04
--	Last Modified:	2017-04-01 18:19:11
--
-- require "majiang.def"
require "majiang_const_define"
local _M = {}

local max_depth = 4
local shifter1
local shifter2

local function copy_table(t)
	if not t then return end

	local m = {}
	for k,v in pairs(t) do
		m[k] = v
	end

	return m
end

--找出不一样的牌
local function filter_odds(tiles)
	local remained = {}

	for i=1,#tiles do
		if tiles[i] ~= tiles[i-1] then
			table.insert(remained, tiles[i])
		end
	end
	table.sort(remained)
	return remained
end

local function filter_triplet(tiles)
	local i = 1
	while tiles[i] do
		if tiles[i] == tiles[i+1] and tiles[i] == tiles[i+2] then
			table.remove(tiles, i)
			table.remove(tiles, i)
			table.remove(tiles, i)
		else
			i = i + 1
		end
	end
end

local function tiles_has_tile(tiles, t)
	for i,v in ipairs(tiles) do
		if v == t then
			return i
		end
	end
end

local function remove_shifter(tiles)
	--移除赖子
	local cnt = 0
	if shifter1 then
		local i = 1
		while tiles[i] do
			if tiles[i] == shifter1 then
				table.remove(tiles, i)
				cnt = cnt + 1
			else
				i = i + 1
			end
		end
	end

	if shifter2 then
		local i = 1
		while tiles[i] do
			if tiles[i] == shifter2 then
				table.remove(tiles, i)
				cnt = cnt + 1
			else
				i = i + 1
			end
		end
	end

	return cnt
end

--组成七对还差几张
--排除掉所有的对子后剩的牌的数量就是组成七对还差几张
local function lacks_seven_pairs(tiles)
	table.sort(tiles)
	local single_cnt = 0
	local i = 1
	while tiles[i] do
		if tiles[i] == tiles[i + 1] then
			i = i + 2
		else
			i = i + 1
			single_cnt = single_cnt + 1
		end
	end

	return single_cnt
end

--普通牌型3*n+2类型还差几张牌
local function filter_tri(tiles)
	local total = 0
	for k,v in pairs(tiles) do
		if v >= 3 then
			tiles[k] = tiles[k] - 3
			total = total + 3
		end
	end

	return total
end

local function filter_seq(tiles, counts)
	local total = 0
	for _,v in pairs(tiles) do
		if counts[v] > 0 and counts[v+1] and counts[v+1] > 0 and counts[v+2] and counts[v+2] > 0 then
			counts[v] = counts[v] - 1
			counts[v+1] = counts[v+1] - 1
			counts[v+2] = counts[v+2] - 1
			total = total + 3
		end
	end

	return total	
end



--[[
	没有移除将头，所以
	如果有对或者有单张 总的差张数量为 单张数＊2+对数＋连－1
	如果没有对或者单张就要拆连着的两张 总的差张数量为 单张数＊2+对数＋连＋2
]]--
local function lacks_no_eye(tiles, counts)
	local pair_cnt = 0
	local seq_cnt = 0
	local single_cnt = 0
	local eyes ={}
	
	for _,v in pairs(tiles) do
		if counts[v] >= 2 then
			counts[v] = counts[v] - 2
			pair_cnt = pair_cnt + 1
			table.insert(eyes, v)
		elseif counts[v] > 0 and counts[v+1] and counts[v+1] > 0 then
			counts[v] = counts[v] - 1
			counts[v+1] = counts[v+1] - 1
			seq_cnt = seq_cnt + 1
		elseif counts[v] > 0 and counts[v+2] and counts[v+2] > 0 then
			counts[v] = counts[v] - 1
			counts[v+2] = counts[v+2] - 1
			seq_cnt = seq_cnt + 1
		elseif counts[v] > 0 then
			counts[v] = counts[v] - 1
			single_cnt = single_cnt + 1
			table.insert(eyes, v)
		end
	end

	if _M.eye_constraints and #_M.eye_constraints > 0 then
		for i,v in ipairs(eyes) do
			if tiles_has_tile(_M.eye_constraints, v) then
				return single_cnt * 2 + pair_cnt + seq_cnt - 1
			end
		end

		return single_cnt * 2 + pair_cnt + seq_cnt + 2
	end

	if single_cnt ~= 0 or pair_cnt ~= 0 then
		return single_cnt * 2 + pair_cnt + seq_cnt - 1
	else
		return seq_cnt + 2
	end	
end

--[[
设置允许胡的特殊牌型
	 1 << 0 : 七对
	 1 << 1 : 十三幺
]]--

-- _M.TYPE_SEVEN_PAIRS = 1 << 0
-- _M.TYPE_THIRTEEN_ORPHANS = 1 << 1

-- function _M.set_qidui(t)
-- 	_M.qi_dui = (t ~= 0) and true or false
-- end

-- function _M.set_qingyise(t)
-- 	_M.qing_yi_se = (t ~= 0) and true or false
-- end

-- function _M.set_shisanyao(t)
-- 	_M.shi_yan_yao = (t ~= 0) and true or false
-- end

-- function _M.set_duiduihu(value)
-- 	_M.duiduihu = value
-- end

--设置将头的限制
function _M.set_eye_constraints(eyes)
	_M.eye_constraints = eyes
end


-- --清一色
-- local function single_lack(tiles)
-- 	if not _M.qing_yi_se then 
-- 		return 
-- 	end
-- 	table.sort(tiles)
-- 	local card_type = 0
-- 	local index = 1
-- 	for k,v in ipairs(tiles) do
-- 		if v == 75 then
-- 			k = k + 1
-- 		else
-- 			if index == 1 then
-- 				card_type = math.floor(v/10)
-- 			else
-- 				if card_type ~= math.floor(v/10) then
-- 					return false
-- 				end
-- 			end
-- 		end
-- 		index = index + 1
-- 	end
-- 	return true
-- 	-- if tiles[#tiles] - tiles[1] < 10 and tiles[1] < 60 then
-- 	-- 	return true
-- 	-- else
-- 	--  	return false
-- 	-- end 
-- end

--全大对
-- local function single_triplet(tiles, hold_tiles, shifter_cnt)
-- 	if _M.duiduihu == 0 then
-- 		return false
-- 	end
-- 	local copy = copy_table(tiles)
-- 	if hold_tiles then
-- 		for k,v in ipairs(hold_tiles) do
-- 			local cards = v.cards 
-- 			if not (#cards > 2 and cards[1] == cards[2]) then
-- 				return false
-- 			end
-- 		end
-- 	end
-- 	filter_triplet(copy)
-- 	local i = 1
-- 	while copy[i] do
-- 		if copy[i] == copy[i+1] and copy[i] == copy[i+2] then
-- 			table.remove(copy, i)
-- 			table.remove(copy, i)
-- 			table.remove(copy, i)
-- 		elseif copy[i] == copy[i+1] and shifter_cnt > 0 then
-- 			table.remove(copy, i)
-- 			table.remove(copy, i)
-- 			shifter_cnt = shifter_cnt - 1
-- 		else
-- 			i = i + 1
-- 		end
-- 	end
-- 	if #copy == 2 and copy[1] == copy[2] then
-- 		return true
-- 	elseif shifter_cnt - #copy >= 0 then
-- 		return true
-- 	else
-- 		return false
-- 	end
-- end

local function lacks(tiles, counts)
	local pair_cnt = 0
	local seq_cnt = 0
	local single_cnt = 0

	local copy = copy_table(counts)
	for _,v in pairs(tiles) do
		if copy[v] >= 2 then
			copy[v] = copy[v] - 2
			pair_cnt = pair_cnt + 1
		elseif copy[v] > 0 and copy[v+1] and copy[v+1] > 0 then
			copy[v] = copy[v] - 1
			copy[v+1] = copy[v+1] - 1
			seq_cnt = seq_cnt + 1
		elseif copy[v] > 0 and math.floor(v/10) <=3 and copy[v+2] and copy[v+2] > 0 then
			copy[v] = copy[v] - 1
			copy[v+2] = copy[v+2] - 1
			seq_cnt = seq_cnt + 1
		elseif copy[v] > 0 then
			copy[v] = copy[v] - 1
			single_cnt = single_cnt + 1
		end
	end

	return pair_cnt + seq_cnt + single_cnt * 2
end

local function dfs(cnt, tiles, tiles_cnt, shifter_cnt)
	local cal_lacks = true
	if cnt == max_depth or shifter_cnt == (max_depth - cnt) * 3 then
		return true
	end

	for k,t in pairs(tiles) do
		local t_cnt = tiles_cnt[t] or 0
		if t_cnt >= 3 then
			cal_lacks = false
			tiles_cnt[t] = tiles_cnt[t] - 3
			if dfs(cnt + 1,tiles, tiles_cnt, shifter_cnt) then return true end
			tiles_cnt[t] = tiles_cnt[t] + 3
		end

		if tiles_cnt[t] >= 1 and tiles_cnt[t+1] and tiles_cnt[t+1] >=1 and tiles_cnt[t+2] and tiles_cnt[t+2] >= 1 then
			cal_lacks = false
			tiles_cnt[t] = tiles_cnt[t] - 1
			tiles_cnt[t+1] = tiles_cnt[t+1] - 1
			tiles_cnt[t+2] = tiles_cnt[t+2] - 1
			if dfs(cnt+1, tiles, tiles_cnt, shifter_cnt) then return true end
			tiles_cnt[t] = tiles_cnt[t] + 1
			tiles_cnt[t+1] = tiles_cnt[t+1] + 1
			tiles_cnt[t+2] = tiles_cnt[t+2] + 1
		end
	end


	-- for k,t in pairs(tiles) do
	-- end

	if cal_lacks then
		if shifter_cnt >= lacks(tiles, tiles_cnt) then
			return true
		end
	end

	return false
end



--是不是七对
local function check_qidui(tiles, shifter_cnt)
	if not _M.hu_qidui then return false end
	assert(_M.fan_qidui)
	local single_cnt = 0
	for k,v in pairs(tiles) do
		single_cnt = single_cnt + v % 2
	end
	return single_cnt <= shifter_cnt
end

--十三幺
local function check_shisanyao(tiles, shifter_cnt)
	if not _M.hu_shisanyao then return false end
	assert(_M.fan_shisanyao)

	if shifter_cnt + table.len(tiles) >= 13 then
		for card,_ in pairs(tiles) do
			if not table.indexof(SHI_SAN_YAO, card) then
				return false
			end
		end
		return true
	end
end

--清一色
local function check_qingyise(tiles)
	if not _M.fan_qingyise then return false end
	remove_shifter(tiles)
	local card_type = math.floor(tiles[1]/10)
	for i=2,#tiles do
		if card_type > 3 or (math.floor(tiles[i]/10) ~= card_type) then
			return false
		end
		card_type = math.floor(tiles[i]/10)
	end
	return true
end

--碰碰胡
local function check_pengpenghu(shifter_cnt, tiles)
	if not _M.fan_pengpenghu then return false end
	if table.len(tiles) > 5 then return false end
	local lack_num = 0
	for k,v in pairs(tiles) do
		local tmp = v%3
		if tmp ~= 0 then
			lack_num = lack_num + 3 - tmp
		end
	end
	return lack_num == (shifter_cnt + 1)
end

--混一色
local function check_hunyise(tiles)
	if not _M.fan_hunyise then return false end

	remove_shifter(tiles)
	local card_type1 
	local card_type2
	for i=1,#tiles do
		local tmp = math.floor(tiles[i]/10)
		if tmp <= 3 then
			if not card_type1 then
				card_type1 = tmp
			end
			if tmp ~= card_type1 then
				return false
			end
		else
			card_type2 = tmp
		end
	end
	if not card_type1 or not card_type2 then
		return false
	end
	return true
end

-- --混对对
-- local function check_hunduidui(tiles)
-- 	if not _M.fan_hunduidui then return false end
-- end

--龙七对
local function check_longqidui(shifter_cnt, tiles, hold_tiles)
	if not _M.fan_longqidui then return end
	local tiles_num = 0
	for t, n in pairs(tiles) do
		tiles_num = tiles_num + n
	end
	if shifter_cnt + tiles_num ~= 14 then return end
	if not check_qidui(tiles, shifter_cnt) then
		return 
	end
	-- local tmp = {}
	-- for _, v in ipairs(tiles) do
	-- 	tmp[v] = (tmp[v] or 0) + 1
	-- end

	for k,v in pairs(tiles) do
		if v + shifter_cnt >= 4 then
			return true
		end
	end
	return false
end

--字一色
local function check_ziyise(shifter_cnt, tiles)
	if not _M.fan_ziyise then return false end
	local cnt = 0
	for k,v in pairs(tiles) do
		if math.floor(k/10) <= 3 then
			return false
		end
		cnt = cnt + v
	end
	if shifter_cnt + cnt ~= 14 then
		return false
	end
	return true
end

--十八罗汉
local function check_shibaluohan(tiles)
	if not _M.fan_shibaluohan then return false end
	if not tiles or #tiles ~= 4 then return false end
	for _,v in ipairs(tiles) do
		if v.opttype ~= OPT_TYPE.LIGHT_GANG and v.opttype ~= OPT_TYPE.BLACK_GANG and v.opttype ~= OPT_TYPE.PENG_GANG then
			return false
		end
	end
	return true
end

local function check_win(tiles)
	max_depth = math.floor(#tiles / 3)
	local shifter_cnt = remove_shifter(tiles)
	table.sort(tiles)

	local tiles_cnt = {}
	for k,v in pairs(tiles) do
		tiles_cnt[v] = tiles_cnt[v] or 0
		tiles_cnt[v] = tiles_cnt[v] + 1
	end

	if shifter_cnt + #tiles == 14 then
		if check_qidui(tiles_cnt, shifter_cnt) then
		--	LOG_DEBUG("qidui")
			return true
		end

		if check_shisanyao(tiles_cnt, shifter_cnt) then
		--	LOG_DEBUG("shisanyao")
			return true
		end
	end
	
	if shifter_cnt >= 2 then
		shifter_cnt = shifter_cnt - 2
		if dfs(0, tiles, tiles_cnt, shifter_cnt) then return true end
		shifter_cnt = shifter_cnt + 2
	end
	
	for k,v in pairs(tiles_cnt) do
		local couldBeEye = true
		local t_cnt = v or 0
		if _M.eye_constraints and not tiles_has_tile(_M.eye_constraints, k) then
			couldBeEye = false
		end
			
		if couldBeEye then
			local tmp_shifter_cnt = shifter_cnt
			if t_cnt + shifter_cnt >= 2 then
				if t_cnt < 2 then
					tiles_cnt[k] = 0
					shifter_cnt = shifter_cnt - 2 + t_cnt
				else	
					tiles_cnt[k] = tiles_cnt[k] - 2
				end
				if dfs(0, tiles, tiles_cnt, shifter_cnt) then
					
					return true 
				end
				
				tiles_cnt[k] = t_cnt
				shifter_cnt = tmp_shifter_cnt
			end
		end
	end
	
	return false
end

--胡牌详细信息
local function win_details(tiles, hold_tiles, shifter_cnt, qishouhu)
	local details_info = {}
--	details_info[HU_TYPE.PINGHU] = 1
	local total_tiles = copy_table(tiles)
	if hold_tiles then
		for k,v in ipairs(hold_tiles) do
			local cards = v.cards 
			for i,j in ipairs(cards) do
				table.insert(total_tiles, j)
			end
		end
	end
	-- PRINT_T(total_tiles)
	table.sort(total_tiles)
	local hand_tiles = copy_table(tiles)
	local tiles_cnt = {}
	for k,v in pairs(hand_tiles) do
		tiles_cnt[v] = tiles_cnt[v] or 0
		tiles_cnt[v] = tiles_cnt[v] + 1
	end
--	PRINT_T(hand_tiles)
	--清七对 清一色 七对
	local is_qidui = (shifter_cnt + #tiles == 14) and check_qidui(tiles_cnt, shifter_cnt)
	local is_qingyise = check_qingyise(copy_table(total_tiles))
	if _M.fan_qingqidui and is_qidui and is_qingyise then
		details_info[HU_TYPE.QIDUI] = _M.fan_qidui
	else
		if is_qidui then
			details_info[HU_TYPE.QIDUI] = _M.fan_qidui
		end
		if is_qingyise then
			details_info[HU_TYPE.QINGYISE] = _M.fan_qingyise
		end
	end

	--混对对 碰碰胡 混一色
	local is_pengpenghu = check_pengpenghu(shifter_cnt, tiles_cnt)
	local is_hunyise = check_hunyise(copy_table(total_tiles))
	if _M.fan_hunduidui and is_pengpenghu and is_hunyise then
		details_info[HU_TYPE.HUNDUIDUI] = _M.fan_hunduidui
	else
		if is_pengpenghu then
			details_info[HU_TYPE.PENGPENGHU] = _M.fan_pengpenghu
		end
		if is_hunyise then
			details_info[HU_TYPE.HUNYISE] = _M.fan_hunyise
		end
	end

	--龙七对
	if check_longqidui(shifter_cnt, tiles_cnt) then
		details_info[HU_TYPE.LONGQIDUI] = _M.fan_longqidui
		details_info[HU_TYPE.QIDUI] = nil
	end

	--天胡 地胡
	if qishouhu then
		if qishouhu.tianhu then
			details_info[HU_TYPE.TIANHU] = _M.fan_tianhu
		elseif qishouhu.dihu then
			details_info[HU_TYPE.DIHU] = _M.fan_dihu
		end
	end

	--字一色
	if check_ziyise(shifter_cnt, tiles_cnt) then
		details_info[HU_TYPE.ZIYIYE] = _M.fan_ziyise
	end

	--十八罗汉
	if check_shibaluohan(hold_tiles) then
		details_info[HU_TYPE.SHIBALUOHAN] = _M.fan_shibaluohan
	end

	if (shifter_cnt + #tiles == 14) and check_shisanyao(tiles_cnt, shifter_cnt) then
		details_info[HU_TYPE.SHISANYAO] = _M.fan_shisanyao
	end
	
	if (shifter1 and shifter1 > 0) or (shifter2 and shifter2 > 0) then
		if shifter_cnt == 0 then
			details_info[HU_TYPE.WUGUIJIABEI] = _M.fan_wuguijiabei
		end
	end

	-- if gangshangkaihua then
	-- 	details_info[HU_TYPE.GANGSHANGKAIHUA] = _M.fan_gangshangkaihua
	-- end
	-- PRINT_T(details_info)
	return details_info
end

--自摸
function _M.check_win_all(tiles, tile, hold_tiles)
	if tile and #tiles % 3 ~= 1 then return end
	if not tile and #tiles % 3 ~= 2 then return end

	local copy = copy_table(tiles)

	if tile then table.insert(copy, tile) end

	return check_win(copy)
end

--点炮
function _M.check_win_one(tiles, tile, hold_tiles)
	if not tile or #tiles % 3 ~= 1 then return end

	local copy = copy_table(tiles)

	table.insert(copy, tile)

	return check_win(copy)
end

--能不能暗杠
function _M.check_concealed_kong(tiles, tile)
	if #tiles < 3 then return end

	local n = 1
	local t = tiles[1]
	local kong_tiles

	for i=2,#tiles do
		if tiles[i] == t then
			n = n + 1
		else
			n = 1
			t = tiles[i]
		end

		if n == 4 or (n == 3 and t == tile) then
			kong_tiles = kong_tiles or {}
			table.insert(kong_tiles, t)
		end
	end

	return kong_tiles
end

--能不能明杠
function _M.check_kong(tiles, tile)
	--移除癞子
	local copy_tiles = copy_table(tiles)
--	remove_shifter(copy_tiles)
	if #copy_tiles < 3 then return end

	local n = 0

	for i=1,#copy_tiles do
		if copy_tiles[i] == tile then
			n = n + 1
		elseif copy_tiles[i] > tile then
			return
		end

		if n == 3 then
			return true
		end
	end
end

--能不能吃
function _M.check_chow(tiles, tile)
	local chows
	--东西南北中发白不能吃
	if tile > 39 then
		return chows
	end
	--移除癞子
	local copy_tiles = copy_table(tiles)
	remove_shifter(copy_tiles)
	local odds = filter_odds(copy_tiles)
	
	for i=1,#odds do
		if odds[i] == tile - 2 and odds[i+1] == tile - 1 then
			chows = chows or {}	
			table.insert(chows, tile-2)
			table.insert(chows, tile-1)
			table.insert(chows, tile)
		end

		if odds[i] == tile - 1 then
			if odds[i+1] == (tile + 1) or odds[i+2] == (tile + 1) then
				chows = chows or {}
				table.insert(chows, tile-1)
				table.insert(chows, tile+1)
				table.insert(chows, tile)
			end
		end

		if odds[i] == (tile + 1) and odds[i+1] == (tile + 2) then
			chows = chows or {}
			table.insert(chows, tile+1)
			table.insert(chows, tile+2)
			table.insert(chows, tile)
		end
	end

	return chows
end

--能不能碰
function _M.check_pung(tiles, tile)
	--移除癞子
	local copy_tiles = copy_table(tiles)
--	remove_shifter(copy_tiles)
	local n = 0
	for i,v in ipairs(copy_tiles) do
		if v == tile then
			n = n + 1
		elseif v > tile then
			return
		end

		if n == 2 then
			return true
		end
	end
end

--设置鬼牌
function _M.set_deal_shifter(shif1, shif2)
	shifter1 = shif1
	shifter2 = shif2
end

function _M.set_rule_data(spec_cfg, rate_cfg)
--	shifter1 = (spec_cfg.shifter and spec_cfg.shifter > 0) and spec_cfg.shifter
	_M.hu_qidui = spec_cfg.qidui and spec_cfg.qidui ~= 0
	_M.hu_shisanyao = spec_cfg.shisanyao and spec_cfg.shisanyao ~= 0

	_M.fan_qingyise = (rate_cfg.qingyise and rate_cfg.qingyise > 0) and rate_cfg.qingyise
	_M.fan_qidui 	= (rate_cfg.qidui and rate_cfg.qidui > 0) and rate_cfg.qidui
	_M.fan_pengpenghu 	= (rate_cfg.pengpenghu and rate_cfg.pengpenghu > 0) and rate_cfg.pengpenghu
	_M.fan_qingqidui 	= (rate_cfg.qingqidui and rate_cfg.qingqidui > 0) and rate_cfg.qingqidui
	_M.fan_hunyise 		= (rate_cfg.hunyise and rate_cfg.hunyise > 0) and rate_cfg.hunyise
	_M.fan_hunduidui 	= (rate_cfg.hunduidui and rate_cfg.hunduidui > 0) and rate_cfg.hunduidui
	_M.fan_longqidui 	= (rate_cfg.longqidui and rate_cfg.longqidui > 0) and rate_cfg.longqidui
	_M.fan_tianhu 		= (rate_cfg.tianhu and rate_cfg.tianhu > 0) and rate_cfg.tianhu
	_M.fan_dihu 		= (rate_cfg.dihu and rate_cfg.dihu > 0) and rate_cfg.dihu
	_M.fan_shisanyao 	= (rate_cfg.shisanyao and rate_cfg.shisanyao > 0) and rate_cfg.shisanyao
	_M.fan_ziyise 		= (rate_cfg.ziyise and rate_cfg.ziyise > 0) and rate_cfg.ziyise
	_M.fan_shibaluohan 	= (rate_cfg.shibaluohan and rate_cfg.shibaluohan > 0) and rate_cfg.shibaluohan
	_M.fan_wuguijiabei = (rate_cfg.wuguijiabei and rate_cfg.wuguijiabei > 0) and rate_cfg.wuguijiabei or nil
end

function _M.init()
	shifter1 = nil
	shifter2 = nil
	_M.eye_constraints = nil
	_M.allow_type = nil
end

function _M.clear()
	_M.init()
end

function _M.get_win_details(tiles, hold_tiles, tile, qishouhu)
	local copy = copy_table(tiles)
	table.insert(copy, tile)
	
	local shifter_cnt = remove_shifter(copy)
	local details_info = win_details(copy, hold_tiles, shifter_cnt, qishouhu)
--	PRINT_T(details_info)
	return details_info
end

function _M.check(tiles)
	table.sort(tiles)
	local copy = copy_table(tiles)

	

	local shifter_cnt = remove_shifter(copy, 75)
	local win = check_win(tiles,shifter_cnt)
	return win
end

return _M