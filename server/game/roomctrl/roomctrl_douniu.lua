local this = {}

--桌子数据
local players
local game_type
local free_table
local total_tables

--api函数
local call_table
local call_all_table
local get_user_count

--控制数据
local win_rate -- 用户赢得概率
local total_win_gold -- 总输赢金币

--判断是否开牌
function this.is_open(wingold)
	local now_rate = math.random(1,100)
	if now_rate < win_rate then
		if wingold <= 0 then
			total_win_gold = total_win_gold + wingold
			LOG_DEBUG(game_type.." 总回收金币："..total_win_gold)
		end
		return 2
	else
		if wingold >= 0 then
			total_win_gold = total_win_gold + wingold
			LOG_DEBUG(game_type.." 总回收金币："..total_win_gold)
		end
		return 1
	end
end

--定时器100ms
function this.update()

end

--初始化
function this.init(t,api,ps,ftable,ttable)
	--数据赋值
	players = ps
	game_type = t
	free_table = ftable
	total_tables = ttable

	--函数赋值
	call_table = api.call_table
	call_all_table = api.call_all_table
	get_user_count = api.get_user_count

	--控制数据赋值
	win_rate = 50 -- 用户赢得概率
	total_win_gold = 0 -- 总输赢金币
end

return this