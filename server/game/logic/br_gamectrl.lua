--金权
--2017年12月20日
--百人游戏控制器

local this = {}

--数据变量
local players -- 玩家列表
local kickback --概率
local sysearn = 0

local isTaste

--控制变量
local ctrl_type --控制类型(1:个人控制，2：全局控制)
local ctrl_result --控制结果(1:用户输，2：用户赢)
local ctrl_user --控制用户

-----------------常用函数---------------
local tinsert = table.insert
local tremove = table.remove

-----------------外部调用----------------
--检测全局控制
local function check_total_ctrl(t_bet, t_win)
	--判断返回控制玩家输
	if t_win - t_bet > sysearn * 0.1 then
		ctrl_type  = 2 --控制类型(1:个人控制，2：全局控制)
		ctrl_result = 1 --控制结果(1:用户输，2：用户赢)
		return false
	end
	
	--判断不控制
	if kickback == 1 then
		LOG_DEBUG("全局控制本局不起效")
		return true
	end

	--判断控制
	local rate = math.random(1 , 100000)
	if kickback < 1 then
		if rate < 100000 * (1 - kickback) then
			if t_win - t_bet <= 0 then
				LOG_DEBUG("全局控制起效：玩家输")
				return true
			else
				ctrl_type  = 2 --控制类型(1:个人控制，2：全局控制)
				ctrl_result = 1 --控制结果(1:用户输，2：用户赢)
				return false
			end
		else
			LOG_DEBUG("全局控制本局不起效")
			return true
		end
	else
		if rate < 100000 * (kickback - 1) then
			if t_win - t_bet >= 0 then
				LOG_DEBUG("全局控制起效：玩家赢")
				return true
			else
				ctrl_type  = 2 --控制类型(1:个人控制，2：全局控制)
				ctrl_result = 2 --控制结果(1:用户输，2：用户赢)
				return false
			end
		else
			LOG_DEBUG("全局控制本局不起效")
			return true
		end
	end
end

--判断是否控制起效
local function juge_player_ctrl(p)
	if not p.wingold or not p.totalbet then
		return 2
	end
	
	--数据赋值
	local rate = math.random(1,100)
	local now_ctrlgold = p.ctrlinfo.ctrlnowgold

	--判断赋值
	if p.ctrlinfo.ctrltype == 1 then
		now_ctrlgold = now_ctrlgold - (p.wingold - p.totalbet)
	else
		now_ctrlgold = now_ctrlgold + (p.wingold - p.totalbet)
	end

	--判断赋值
	if p.ctrlinfo.ctrlcount and p.ctrlinfo.ctrlcount > 0 then
		rate = 0
	end
	
	--判断赋值
	if p.ctrlinfo.ctrltype == 2 and math.max(now_ctrlgold, p.ctrlinfo.ctrlnowgold) > p.ctrlinfo.ctrlmaxgold then
		return 1
	elseif p.ctrlinfo.ctrltype == 1 and p.ctrlinfo.ctrlnowgold > p.ctrlinfo.ctrlmaxgold then
		return 1
	else
		--判断
		if rate <= p.ctrlinfo.ctrlrate then
			if p.ctrlinfo.ctrltype == 1 and p.wingold - p.totalbet < 0 then
				if p.ctrlinfo.ctrlcount and p.ctrlinfo.ctrlcount > 0 then
					p.ctrlinfo.ctrlcount = p.ctrlinfo.ctrlcount - 1
					if p.ctrlinfo.ctrlcount == 0 then
						p.ctrlinfo.ctrlcount = nil
					end
				end
				return true
			elseif p.ctrlinfo.ctrltype == 2 and p.wingold - p.totalbet > 0 then
				if p.ctrlinfo.ctrlcount and p.ctrlinfo.ctrlcount > 0 then
					p.ctrlinfo.ctrlcount = p.ctrlinfo.ctrlcount - 1
					if p.ctrlinfo.ctrlcount == 0 then
						p.ctrlinfo.ctrlcount = nil
					end
				end
				return true
			else
				return false
			end
		end
	end
end

--第一次判断控制
local function check_open_first(t_bet, t_win)
	-------------------单人控制判断------------------
	local ctrl_player = {}
	for uid,p in pairs(players) do
		if not p.isrobot then
			if p.ctrlinfo and p.ctrlinfo.ctrltype and p.ctrlinfo.ctrllevel then
				if p.totalbet > 0 or p.wingold ~= 0 then
					if not ctrl_player[p.ctrlinfo.ctrllevel] then
						ctrl_player[p.ctrlinfo.ctrllevel] = {}
					end
					tinsert(ctrl_player[p.ctrlinfo.ctrllevel], uid)
				end
			end
		end
	end
	
	--判断控制
	for i=12,1,-1 do
		if ctrl_player[i] then
			if #ctrl_player[i] == 1 then
				local player_ctrl = juge_player_ctrl(players[ctrl_player[i][1]])
				
				--判断显示
				if player_ctrl == true then
					return true
				elseif player_ctrl == false then
					ctrl_type  = 1 --控制类型(1:个人控制，2：全局控制)
					ctrl_user = ctrl_player[i][1] --控制用户
					ctrl_result = players[ctrl_player[i][1]].ctrlinfo.ctrltype --控制结果(1:用户输，2：用户赢)
					return false
				elseif  player_ctrl == 1 then
					--判断反控制
					ctrl_type  = 1 --控制类型(1:个人控制，2：全局控制)
					ctrl_user = ctrl_player[i][1] --控制用户
					if players[ctrl_player[i][1]].ctrlinfo.ctrltype == 1 then
						ctrl_result = 2
					else
						ctrl_result = 1
					end
					return false
				end
			else
				local is_open = true
				for k,uid in pairs(ctrl_player[i]) do
					--判断冲突
					if juge_player_ctrl(players[uid]) == false then
						is_open = false
						break
					end
				end

				--判断是否可以开牌
				if is_open then
					return true
				end
			end
		end
	end

	-------------------全局控制判断------------------
	--走全局控制
	return check_total_ctrl(t_bet, t_win)
end

--检测是否开牌
function this.check_open(_times, t_bet, t_win)
	--体验模式不控制
	if isTaste then return true end
	--判断返回
	if _times > 20  then
		LOG_DEBUG("循环算法次数大于20次，放弃控制")
		return true
	elseif _times == 0 then
		return check_open_first(t_bet, t_win)
	else
		if ctrl_type == 1 then
			if ctrl_result == 1 then
				if players[ctrl_user].wingold - players[ctrl_user].totalbet <= 0  then
					return true
				else
					return false
				end
			else
				local now_ctrlgold = players[ctrl_user].ctrlinfo.ctrlnowgold

				--判断赋值
				if players[ctrl_user].ctrlinfo.ctrltype == 1 then
					now_ctrlgold = now_ctrlgold - (players[ctrl_user].wingold - players[ctrl_user].totalbet)

					--判断
					if now_ctrlgold < 0 then
						ctrl_result = 1
						return false
					else
						if players[ctrl_user].wingold - players[ctrl_user].totalbet >= 0  then
							return true
						else
							return false
						end
					end
				else
					now_ctrlgold = now_ctrlgold + (players[ctrl_user].wingold - players[ctrl_user].totalbet)

					--判断
					if now_ctrlgold > players[ctrl_user].ctrlinfo.ctrlmaxgold then
						ctrl_result = 1
						return false
					else
						if players[ctrl_user].wingold - players[ctrl_user].totalbet >= 0  then
							return true
						else
							return false
						end
					end
				end
			end
		else
			if ctrl_result == 1 then
				--1:用户输
				if t_win - t_bet <= 0 then
					return true
				else
					return false
				end
			else
				--2：用户赢
				if t_win - t_bet >= 0 then
					return true
				else
					return false
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
	if isTaste then return end
	--数据更新
	kickback = kb
	if sys then
		sysearn = sys
	end
end

--初始化数据
function this.init(p, kb, is_taste)
	--初始化数据
	players = p
	isTaste = is_taste
	if not isTaste then
		kickback = kb
	end
end

return this


















