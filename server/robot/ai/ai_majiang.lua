require "majiang_const_define"
local game_conf = require "game_conf"
local mj_specrule_cfg = require "mj_specrule_conf"
local mj_baserule_cfg = require "mj_baserule_conf"
local mj_rate_cfg = require "mj_rate_conf"
local mj_deal = require "majiang_deal"
local ai_mgr = {}
local server_msg = {}
local robot_api
local robot_info
local last_tile
local banker_seatid 				--庄位
local gen_zhuang_tile  		--跟庄信息牌
local table_tiles = {} 				--牌桌上已打出的牌 不包括吃碰杠的牌
local shifter1 
local shifter2

--[[
robot_info = {
	uid = num,
	seatid = num,
	tiles = {},
	hold = {
		peng = {11,32},
		gang = {41,23},
	},
	replace = uid,		是否接的托管的玩家
	noPeng = 0, 棄碰过圈规则
	noDeal = 0  臭吃规则
}
]]

local function send_to_server(name, msg)
	LOG_DEBUG("send_to_server [%s]", name)
	robot_api.send_msg(name, msg, robot_info.replace)
end

--延迟调用函数
local function delay_call(time, fun, params)
	robot_api.register_delay_fun(time, fun, params)
end

--判断下家是不是庄家 用作跟庄牌
local function is_next_banker( ... )
	local next_seatid = robot_info.seatid + 1
	if next_seatid > 4 then
		next_seatid = 1
	end
	return next_seatid == banker_seatid
end

--根据已打出的牌选出应该出的牌
local function get_discard_tile()
	local tiles = {{},{},{},{}}
	for tile, num in pairs(table_tiles) do
		if not tiles[num] then
			luadump(table_tiles)
			LOG_ERROR("something is error in table_tiles!!!!")
		--	assert(false)
		end
		table.insert(tiles[num], tile)
	end

	--先将鬼牌剔除
	local tmp_tiles = {}
	for _, tile in ipairs(robot_info.tiles) do
		if tile ~= shifter1 and tile ~= shifter2 then
			table.insert(tmp_tiles, tile)
		end
	end

	for i=3, 1, -1 do
		for _, tile in ipairs(tiles[i]) do
			if table.indexof(tmp_tiles, tile) then
				return tile
			end
		end
	end
	-- if last_tile and last_tile ~= shifter1 and last_tile ~= shifter2 then 
	-- 	return last_tile 
	-- end
	--吃碰杠后
	local hand_tiles = {}
	for _,tile in ipairs(tmp_tiles) do
		if tile ~= shifter1 and tile ~= shifter2 then
			hand_tiles[tile] = (hand_tiles[tile] or 0) + 1
		end
	end
	local single_tiles = {}
	for tile,num in pairs(hand_tiles) do
		if num == 1 then
			table.insert(single_tiles, tile)
		end
	end

	if not next(single_tiles) then
		for tile, num in pairs(hand_tiles) do
			if num == 3 then
				return tile
			end
		end
		for tile, num in pairs(hand_tiles) do
			if num == 2 then
				return tile
			end
		end
		for tile, num in pairs(hand_tiles) do
			return tile
		end
	end

	table.sort(single_tiles)
	local shun = {}
	for i,tile in ipairs(single_tiles) do
		if not next(shun) then
			table.insert(shun, {tile})
		else
			if tile == shun[#shun][#(shun[#shun])] + 1 then
				table.insert(shun[#shun], tile)
			else
				table.insert(shun, {tile})
			end
		end
	end
	
	local cnt = 10
	local index
	local discard_tile
	for i,v in ipairs(shun) do
		if #v == 1 then
			discard_tile = v[1]
			break
		else
			if #v < cnt then
				cnt = #v
				index = i
			end
		end
	end

	if not discard_tile then
		discard_tile = shun[index][1]
	end
	assert(discard_tile)
	return discard_tile
end

local function discard()
	local discard_tile
	-- if is_next_banker() then
	-- 	if gen_zhuang_tile and table.indexof(robot_info.tiles, gen_zhuang_tile) then
	-- 		discard_tile = gen_zhuang_tile
	-- 	end
	-- end

	if not discard_tile then
		discard_tile = get_discard_tile()
	end

	table.removebyvalue(robot_info.tiles, discard_tile)
	
	send_to_server("reqMJPlayerOpt", {opts = {opttype=OPT_TYPE.DISCARD, cards={discard_tile}}})
--	LOG_WARNING("robot[%d] discard[%s] over", robot_info.uid, tostring(discard_tile))
	LOG_DEBUG("robot[%d] discard[%s] cur_tiles[%s]", robot_info.uid, tostring(discard_tile), table.concat(robot_info.tiles, ","))
	last_tile = nil
end

local function win()
	LOG_DEBUG("robot[%d] win", robot_info.uid)
	send_to_server("reqMJPlayerOpt", {opts = {opttype=OPT_TYPE.WIN, cards={}}})
end

local function player_opt_req(pa)
	send_to_server("reqMJPlayerOpt", {opts = pa})
end

local function pass()
	send_to_server("reqMJPlayerOpt", {opts = {opttype=OPT_TYPE.PASS, cards={}}})
end

local function get_ready()
	send_to_server("reqReady", {})
end

local function MJRequestDealTiles( ... )
--	LOG_WARNING("send_to_server MJRequestDealTiles [%d]", robot_info.uid)
	send_to_server("MJRequestDealTiles", {})
end

local function check_win()
	return mj_deal.check_win_all(robot_info.tiles, last_tile)
end

local function check_an_gang( ... )
	table.sort(robot_info.tiles)
	local cnt = 0
	local tile
	for _,card in ipairs(robot_info.tiles) do
		if not tile then
			tile = card
			cnt = 1
		elseif card == tile then
			cnt = cnt + 1
			if cnt == 4 then
				return tile
			end
		else
			tile = card
			cnt = 1
		end
	end
end

local function check_peng_gang(tile)
	if robot_info.hold and robot_info.hold.peng and table.indexof(robot_info.hold.peng, tile) then
		return tile
	end
end

--碰 杠
local function move_to_hold(opt, num, tile)
	for i=1,num do
		table.removebyvalue(robot_info.tiles, tile)
	end
	if opt == "peng" then
		robot_info.hold.peng = robot_info.hold.peng or {}
		table.insert(robot_info.hold.peng, tile)
	elseif opt == "peng_gang" then
		table.removebyvalue(robot_info.hold.peng, tile)
		robot_info.hold.gang = robot_info.hold.gang or {}
		table.insert(robot_info.hold.gang, tile)
	elseif opt == "gang" then
		robot_info.hold.gang = robot_info.hold.gang or {}
		table.insert(robot_info.hold.gang, tile)
	end
end

--吃单独处理
local function player_chi(tiles)
	-- body
end

function server_msg.MJGameInfo(msg)
	
end

--[[
    @desc: 发牌
    author:{author}
    time:2019-01-03 24:53:27
    --@msg: 
    @return:
]]
function server_msg.resMJDealCard(msg)
	--发牌
	if msg.cards and #msg.cards == 13 then
		robot_info.tiles = msg.cards
		robot_info.hold = {}
		if next(table_tiles) then
			table.clear(table_tiles)
		end
	end
	banker_seatid = msg.banker
	shifter1 = msg.shifter[1] or 0
	shifter2 = msg.shifter[2] or 0
	mj_deal.set_deal_shifter(shifter1, shifter2)
	delay_call(2, MJRequestDealTiles)--这个功能暂时是没有用的20190103
end

function server_msg.resMJPlayerOpt(msg)
	if msg.result and msg.result == 1 then --不能出这张牌，重新出牌
		LOG_DEBUG("不能出这张牌，重新出牌")
		discard()
		return
	end
	if msg.result and msg.result == 2 then --不能碰这张牌，过
		LOG_DEBUG("不能碰这张牌，过")
		delay_call(math.random(0,1), pass)
		return
	end
	--有人出牌
	if msg.cards and #msg.cards == 1 and msg.opttype == OPT_TYPE.DISCARD then
		if fromSeatid == banker_seatid then
			gen_zhuang_tile = msg.cards[1]
		elseif gen_zhuang_tile and msg.cards[1] ~= gen_zhuang_tile then
			gen_zhuang_tile = nil
		end

		table_tiles[msg.cards[1]] = (table_tiles[msg.cards[1]] or 0) + 1
		local tile_num = 0
		for tile,num in pairs(table_tiles) do
			tile_num = tile_num + num
		end
	--	LOG_WARNING("cur_discard[%d] table_tiles num[%d]", msg.cards[1], tile_num)
	end
	--有人吃碰杠的消息
	if msg.areaid == TILE_AREA.HOLD then
		gen_zhuang_tile = nil
		if msg.toSeatid == robot_info.seatid then
			if msg.opttype == OPT_TYPE.PENG then
				move_to_hold("peng", 2, msg.cards[1])
			elseif msg.opttype == OPT_TYPE.PENG_GANG then
				move_to_hold("peng_gang", 1, msg.cards[1])
			elseif msg.opttype == OPT_TYPE.BLACK_GANG then
				move_to_hold("gang", 4, msg.cards[1])
			elseif msg.opttype == OPT_TYPE.LIGHT_GANG then
				move_to_hold("gang", 3, msg.cards[1])
			end
		end
	end
end

function server_msg.resMJDrawCard(msg)
	if not msg.card then
		return
	end
	last_tile = msg.card

	--第一轮需要额外延迟几秒
	local extra_time = 0
	if not next(table_tiles) then
		extra_time = 3
	end
	if check_win() then
		delay_call(math.random(2+extra_time,3+extra_time), win)
	else
		table.insert(robot_info.tiles, last_tile)
		local an_gang_tile = check_an_gang()
		if an_gang_tile then
			delay_call(math.random(1+extra_time,2+extra_time), player_opt_req, {opttype=OPT_TYPE.BLACK_GANG, cards={an_gang_tile}})
		elseif check_peng_gang(last_tile) then
			delay_call(math.random(1+extra_time,2+extra_time), player_opt_req, {opttype=OPT_TYPE.PENG_GANG, cards={last_tile}})
		else
			delay_call(math.random(2+extra_time,3+extra_time), discard)
		end
	end
end

--检查手中是否有这张牌 有则返回位置
local function has_tile(t, tile)
    if type(tile) == "table" then
        local i = 1
        local result
        for k,v in ipairs(t) do
            if v == tile[i] then
                result = result or {}
                result[i] = k
                i = i + 1
            end
        end
        return result
    else
        for k,v in pairs(t) do
            if v == tile then
                return k
            end
        end
    end 
end

function server_msg.resMJNotifyPlayerOpt(msg)
	if msg.seatid == robot_info.seatid then
		if msg.opts then
			if msg.opts[1].opttype == OPT_TYPE.DRAW or msg.opts[1].opttype == OPT_TYPE.DRAW_REVERSE and msg.opts[1].cards then
				
			elseif msg.opts[1].opttype == OPT_TYPE.DISCARD then
				delay_call(math.random(2,3), discard)
			else
				local opts = {}
				for _,v in ipairs(msg.opts) do
					table.insert(opts, v.opttype)
				end
				if table.indexof(opts, OPT_TYPE.WIN) then
					delay_call(math.random(2,3), win)
				elseif table.indexof(opts, OPT_TYPE.LIGHT_GANG) then
					-- LOG_WARNING("robot[%d] ming gang", robot_info.uid)
					delay_call(math.random(2,3), player_opt_req, {opttype=OPT_TYPE.LIGHT_GANG, cards={msg.opts[1].cards[1]}})
				--	move_to_hold("light_gang", 3, msg.opts[1].cards[1])
				elseif table.indexof(opts, OPT_TYPE.PENG) then
					delay_call(math.random(2,3), player_opt_req, {opttype=OPT_TYPE.PENG, cards={msg.opts[1].cards[1]}})
				--	move_to_hold("peng", 2, msg.opts[1].cards[1])
				elseif table.indexof(opts, OPT_TYPE.CHI) then
					delay_call(math.random(2,3), player_opt_req, {opttype=OPT_TYPE.CHI, cards={msg.opts[1].cards[1]}})
				else
					delay_call(math.random(2,3), pass)
				end
			end

		end
	end
end

-- function server_msg.init_replace_robot(msg)
-- 	LOG_WARNING("init replace robot")
	
-- 	robot_info.replace = msg.uid
-- 	robot_info.seatid = msg.seatid
-- 	robot_info.tiles = msg.tiles
-- 	robot_info.uid = msg.uid
-- 	robot_info.hold = msg.hold
-- end

function server_msg.GameResult(msg)
	
end

function server_msg.reqMJPlayerOpt(msg)
	-- body
end

function server_msg.MJPlayerOptRep(msg)
	
	
end

function server_msg.MJWinnersInfo(msg)
	-- body
end

function server_msg.MJShowCards(msg)
	-- body
end

function server_msg.StartRound(msg)
	-- body
	LOG_DEBUG("机器人收到了局数开始的命令StartRound")
end

function server_msg.resMJResult(msg)
	robot_info.tiles = nil
	delay_call(math.random(5,10), get_ready)
end


function server_msg.GameStart(msg)
	-- body
end

--[[
    @desc: 收到服務器的坐下命令後隨機1到2秒進行機器人的準備
    author:{author}
    time:2019-01-01 01:14:46
    --@msg: 
    @return:
]]
function server_msg.resSitDown(msg)
	LOG_DEBUG("SitdownNtf")
	if msg.uid and msg.uid == robot_info.uid then
		robot_info.seatid = msg.seatid
		delay_call(math.random(1,2), get_ready)
	end
end

function server_msg.GetReadyNtf(msg)
	-- body
end

function server_msg.UpdateGoldInGame(msg)
	-- body
end

function ai_mgr.init(api, uid, gameid)
	robot_api = api
	robot_info = robot_info or {}
	robot_info.uid = uid
	LOG_DEBUG("init  robot uid[%d] gameid[%s]", robot_info.uid, tostring(gameid))
	local mj_cfg = game_conf[gameid]
	mj_deal.set_rule_data(mj_specrule_cfg[mj_cfg.init_params.special_rule], mj_rate_cfg[mj_cfg.init_params.rate_rule])
end

function ai_mgr.dispatch(name, msg)
	LOG_DEBUG("server msg %s", name)
	local f = server_msg[name]
	if f then
		f(msg)
	else
		LOG_INFO("no matching function deal server msg[%s]", tostring(name))
	end
end

function ai_mgr.free()
	-- body
end

return ai_mgr