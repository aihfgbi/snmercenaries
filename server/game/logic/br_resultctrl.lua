--金权
--2017年12月20日
--百人游戏结果控制

local this = {}
local deal = require "br_gamedeal"

--数据变量
local players -- 玩家列表
local kickback -- 全局概率
local sysearn = 0 -- 库存
local game_type -- 游戏类型
local RETURN_RATE = 0.9 --回收概率
local game_name = {"百人牛牛", "百人小九", "二八杠", "百人憋十", "温州两张"}

--游戏基本数据
local pos_num -- 位置个数
local open_num -- 开牌个数
local is_tastemode --是否体验模式

--开奖数据
local total_bet -- 总押注
local banker_gold -- 庄家金币
local pos_totalbet -- 位置总押注
local first_cards -- 首次发的牌
local add_cards --增加的牌
local open_result --开奖结果
local total_result -- 所有开奖结果

--控制数据
local ctrl_type -- 控制类型(1:个人控制，2：全局控制)
local ctrl_result -- 控制结果(1:用户输，2：用户赢)
local ctrl_uid -- 控制玩家

--------------游戏规则函数---------------
local getType -- 获取牌类型
local assIsWin -- 判断输赢
local assUserWingold -- 玩家输赢赋值
local assBankerWinGold -- 庄家输赢赋值
local tinsert = table.insert
local tremove = table.remove

--本局单控玩家赋值
local function assPlayerCtrl()
	if is_tastemode then return end
	local ctrl_player = {}
	for uid,p in pairs(players) do
		if not p.isrobot then
			if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrllevel then
				if p.totalbet > 0 then
					if not ctrl_player[p.ctrlinfo.ctrllevel] then
						ctrl_player[p.ctrlinfo.ctrllevel] = {}
					end
					tinsert(ctrl_player[p.ctrlinfo.ctrllevel], uid)
				end
			end
		end
	end

	--判断返回控制
	for i=12,1,-1 do
		if ctrl_player[i] then
			if #ctrl_player[i] == 1 then
				return ctrl_player[i][1]
			end
		end
	end
end

--全局控制赋值
local function assTotalCtrl()
	if is_tastemode then return end
	--判断控制
	local rate = math.random(1 , 100000)
	if kickback * RETURN_RATE < 1 then
		if rate < 100000 * (1 - kickback * RETURN_RATE) then
			return 1
		end
	else
		if rate < 100000 * (kickback * RETURN_RATE - 1) then
			return 2
		end
	end
end

--计算所有结果
local function assTotalResult()
	--数据赋值
	total_result = {}
	for k,open_index in pairs(open_result) do
		--定义变量
		local result = {}

		--当前牌赋值
		result.totalwin = 0
		result.totalbet = 0
		result.pos_card = {}
		result.pos_cardtype = {}
		for i=1,open_num do
			--数据初始化
			result.pos_card[i] = {}

			--首次牌赋值
			if first_cards[i] then
				for k,first_card in pairs(first_cards[i]) do
					tinsert(result.pos_card[i], first_card)
				end
			end
			
			--增加牌赋值
			for k,add_card in pairs(add_cards[open_index[i]]) do
				tinsert(result.pos_card[i], add_card)
			end
			result.pos_cardtype[i] = getType(result.pos_card[i])
		end

		--输赢赋值
		result.pos_iswin = assIsWin(pos_num,result.pos_card, total_bet, banker_gold)
		
		--庄家赢钱赋值
		result.banker_wingold = assBankerWinGold(pos_num, pos_totalbet, result.pos_cardtype, result.pos_iswin, total_bet, banker_gold)
		if banker_id ~= 0 and not players[banker_id].isrobot then
			result.totalwin = result.totalwin + result.banker_wingold
			if ctrl_uid == banker_id then
				result.userbet = 0
				result.userwin = result.banker_wingold
			end
		end

		--计算玩家输赢
		for uid,p in pairs(players) do
			if uid ~= banker_id and not p.isrobot then
				local user_wingold = assUserWingold(pos_num, p.userbet, result.pos_cardtype, result.pos_iswin, total_bet, banker_gold)
				result.totalwin = result.totalwin + user_wingold
				result.totalbet = result.totalbet + p.totalbet
				if ctrl_uid == uid then
					result.userbet = p.totalbet
					result.userwin = user_wingold
				end
			end
		end
		
		--结果赋值
		tinsert(total_result, result)
	end
end

--单控玩家出牌结果
local function assPlayerResultIndex()
	--定义变量
	local user_winmax
	local ststem_winindex = 1

	--数据赋值
	for k,result in pairs(total_result) do
		local system_wingold = result.totalbet - result.totalwin
		local user_wingold = result.userwin - result.userbet
		if ctrl_result == 1 and result.userwin - result.userbet < 0 and  system_wingold >= 0 then
			return k
		elseif  ctrl_result == 2 then
			if players[ctrl_uid].ctrlinfo.ctrlnowgold + user_wingold <= players[ctrl_uid].ctrlinfo.ctrlmaxgold then
				if user_wingold > 0 and system_wingold >= - user_wingold * 1.2 then
					return k
				elseif system_wingold >= 0 then
					if not user_winmax then
						ststem_winindex = k
						user_winmax = result.userwin
					else
						if user_winmax < result.userwin then
							ststem_winindex = k
							user_winmax = result.userwin
						end
					end
				end
			end
		end
	end

	return ststem_winindex
end

--全局控制出牌结果
local function assTotalResultIndex()
	local return_p = 1

	--数据赋值
	for k,result in pairs(total_result) do
		local system_wingold = result.totalbet - result.totalwin
		if ctrl_result == 1 and system_wingold >= 0 then
			return k
		elseif  ctrl_result == 2 then
			--判断返回控制玩家输
			if system_wingold <= 0 then
				if sysearn * 0.1 + system_wingold > 0 then
					return k
				end
			else
				return_p = k
			end
		end
	end
	return return_p
end

--返回赋值 type---->0：随机概率, 1:受控
local function assReturnData(index, ass_type)
	--判断赋值
	if not is_tastemode then
		if ass_type == 0 and total_result[index].totalwin - total_result[index].totalbet >= sysearn * 0.1 then
			if index  + 1 <= #total_result then
				return assReturnData(index + 1, ass_type)
			end
		end
	end
	
	--开奖结果赋值
	local open_detail = {}

	--数据赋值
	open_detail.totalwin = total_result[index].totalwin
	open_detail.totalbet = total_result[index].totalbet
	open_detail.pos_card = total_result[index].pos_card
	open_detail.pos_iswin = total_result[index].pos_iswin
	open_detail.pos_cardtype = total_result[index].pos_cardtype
	open_detail.banker_wingold = total_result[index].banker_wingold
	if banker_id ~= 0 then
		players[banker_id].wingold = open_detail.banker_wingold
	end

	--玩家数据赋值
	for uid,p in pairs(players) do
		if uid ~= banker_id then
			p.wingold = assUserWingold(pos_num, p.userbet, open_detail.pos_cardtype, open_detail.pos_iswin, total_bet, banker_gold)
		end
	end

	return open_detail
end

--结果赋值
function this.assResult(_first_cards, _add_cards, _total_bet, _banker_gold, _banker_id, _pos_totalbet)
	--数据赋值
	ctrl_uid = nil
	ctrl_type = nil
	ctrl_result = nil
	total_bet = _total_bet -- 总押注
	banker_id = _banker_id -- 庄家id
	banker_gold  = _banker_gold -- 庄家金币
	pos_totalbet = _pos_totalbet -- 位置总押注
	first_cards = _first_cards -- 首次发的牌
	add_cards = _add_cards --增加的牌

	--判断是否受控制
	ctrl_uid = assPlayerCtrl()

	--判断是否全局控制
	if ctrl_uid then
		ctrl_type = 1 -- 控制类型(1:个人控制，2：全局控制)
		if players[ctrl_uid].ctrlinfo.ctrlnowgold < players[ctrl_uid].ctrlinfo.ctrlmaxgold then
			ctrl_result = players[ctrl_uid].ctrlinfo.ctrltype -- 控制结果(1:用户输，2：用户赢)
		else
			--反控制
			if players[ctrl_uid].ctrlinfo.ctrltype == 1 then
				ctrl_result = 2
			else
				ctrl_result = 1
			end
		end
	else
		--全局控制
		local ctrl_result = assTotalCtrl()

		--判断赋值
		if ctrl_result then
			ctrl_type = 2
		end
	end

	--计算所有结果
	assTotalResult()

	--判断返回
	if ctrl_type then
		--定义变量
		local open_index

		--判断赋值
		if ctrl_type == 1 then
			open_index = assPlayerResultIndex()
		else
			open_index = assTotalResultIndex()
		end

		--返回数据
		return assReturnData(open_index, 1)
	else
		--返回数据
		return assReturnData(1, 0)
	end
end

--开奖结果赋值
local function ass_open_result()
	--判断赋值
	open_result = {}
	if open_num == 4 then
		for i=1,open_num do
			for j=1,open_num do
				if i ~= j then
					for k=1,open_num do
						if k ~=i and k ~= j then
							for p=1,open_num do
								if p ~=i and p ~= j and p ~= k then
									tinsert(open_result, {i, j, k, p})
								end
							end
						end
					end
				end
			end
		end
	elseif open_num == 5 then
		for i=1,open_num do
			for j=1,open_num do
				if i ~= j then
					for k=1,open_num do
						if k ~=i and k ~= j then
							for p=1,open_num do
								if p ~=i and p ~= j and p ~= k then
									for q=1,open_num do
										if q ~=i and q ~= j and q ~= k and q ~= p then
											tinsert(open_result, {i, j, k, p, q})
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

--更新数据
function this.set_kickback(kb, sys)
	-- kickback是一个>0的数值，1表示不抽水也不放水，自然概率
	-- 例如0.98表示玩家的每次下注行为都抽水0.02
	-- 如果需要转化成0-100的数值，那么就是kickback*50，且大于100的时候取100
	
	--数据更新
	kickback = kb
	if sys then
		sysearn = sys
	end
end

--初始化
function this.init(ps, kb, gt, tastemode)
	--数据赋值
	players = ps -- 玩家列表
	kickback = kb -- 全局概率
	game_type = gt -- 游戏类型
	is_tastemode = tastemode

	--配置数据赋值
	pos_num = deal.pos_num[game_type] --位置个数
	open_num = deal.open_num[game_type] --开牌个数
	
	--游戏规则函数
	getType = deal.getType[game_type]
	assIsWin = deal.assIsWin[game_type]
	assUserWingold = deal.assuserWingold[game_type]
	assBankerWinGold = deal.assBankerWinGold[game_type]

	--开奖结果赋值
	ass_open_result()
end

return this

