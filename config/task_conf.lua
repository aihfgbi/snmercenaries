--[[
	任务配置表
]]

local task = {
	[10001] = {
		id = 10001, 			 						--"任务id"
		describe = "邀请好友", 						--"任务描述"
		targettype1 = "add_friend",
		targettype2 = "",
		target1 = nil,
		target2 = nil,
		targetcnt1 = 5,
		targetcnt2 = 0,
		award = 5*100,			 					--"红包奖励 单位 分"
		time = "", 									--为空表示终身任务
		duration = 24*60*60,
		tasktype = "week", 							--任务类型 week为周任务
	},
	[10002] = {
		id = 10002, 			 						--"任务id"
		describe = "邀请好友", 						--"任务描述"
		targettype1 = "add_friend",
		targettype2 = "",
		target1 = nil,
		target2 = nil,
		targetcnt1 = 10,
		targetcnt2 = 0,
		award = 18*100,			--"任务奖励"
		time = "", 									--为空表示终身任务
		duration = 24*60*60,
		tasktype = "week", 							--任务类型 week为周任务
	},
	[10003] = {
		id = 10003, 			 						--"任务id"
		describe = "邀请好友", 						--"任务描述"
		targettype1 = "add_friend",
		targettype2 = "",
		target1 = nil,
		target2 = nil,
		targetcnt1 = 20,
		targetcnt2 = 0,
		award = 27*100,			--"任务奖励"
		time = "", 									--为空表示终身任务
		duration = 24*60*60,
		tasktype = "week", 							--任务类型 week为周任务
	},
	[10004] = {
		id = 10004, 			 						--"任务id"
		describe = "邀请好友", 						--"任务描述"
		targettype1 = "add_friend",
		targettype2 = "",
		target1 = nil,
		target2 = nil,
		targetcnt1 = 40,
		targetcnt2 = 0,
		award = 34*100,			--"任务奖励"
		time = "", 									--为空表示终身任务
		duration = 24*60*60,
		tasktype = "week", 							--任务类型 week为周任务
	},
	[10005] = {
		id = 10005, 			 						--"任务id"
		describe = "邀请好友", 						--"任务描述"
		targettype1 = "add_friend",
		targettype2 = "",
		target1 = nil,
		target2 = nil,
		targetcnt1 = 50,
		targetcnt2 = 0,
		award = 66*100,			--"任务奖励"
		time = "", 									--为空表示终身任务
		duration = 24*60*60,
		tasktype = "week", 							--任务类型 week为周任务
	},
	[10006] = {
		id = 10006, 			 						--"任务id"
		describe = "邀请好友", 						--"任务描述"
		targettype1 = "add_friend",
		targettype2 = "",
		target1 = nil,
		target2 = nil,
		targetcnt1 = 100,
		targetcnt2 = 0,
		award = 125*100,			--"任务奖励"
		time = "", 									--为空表示终身任务
		duration = 24*60*60,
		tasktype = "week", 							--任务类型 week为周任务
	},
}

return task