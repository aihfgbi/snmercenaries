local this = {}

this[10001] = {
	name="斗地主淘汰赛",
	type = "taotai", --比赛模式套用的逻辑
	time = "0.0.0.0.0.0:0.0.0.24.0.0", --开始时间，结束时间，年月日时分秒
	ticket = 1002, --门票类型
	ticketCount = 10,
	minGold = 10000, --最低入场金额
	useGold = true, --是否使用玩家真实金币结算
	gameid = 10001, --使用的游戏ID
	active = true,
}

this[2001] = {
	name="斗地主淘汰赛",
	type = "taotai", --比赛模式套用的逻辑
	time = "0.0.0.18.0.0:0.0.0.20.0.0", --开始时间，结束时间，年月日时分秒
	ticket = 1002, --门票类型
	ticketCount = 10,
	minGold = 10000, --最低入场金额
	useGold = true, --是否使用玩家真实金币结算
	gameid = 2002, --使用的游戏ID
	active = true,
}

return this
