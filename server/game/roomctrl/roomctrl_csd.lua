local this = {}
local send_to_all
local goldpool=10000000          --奖池金额
local goldpool_limit=10000000      --奖池金额限制（可以中大奖）
local last_biggoldpool=10000000       --之前的奖金池数量
local last_smallgoldpool=10000000
local playerinfo={}
local all_cost=0
local all_earn=0
local percentage=10000    --抽成金额限制
local gameid=10004
-- local hadwin=1   --用hadwin记录信息是否送大奖  0表示未发送  1表示已经发送
local isneedsend=false
local histroy_goldpool={}

--彩金数据
local big_gold --大彩金
local small_gold --小彩金
local big_system_gold --系统大彩金
local small_system_gold --系统小彩金
local big_add_gold --增加大彩金
local small_add_gold --增加小彩金
local is_paijing --彩金是否派奖
local run_times --运行次数

--------------------彩金配置数据-----------------
local CJ_REMOVE_RATE = 0.60 --彩金回收比例
local CJ_PAIJIANG_RATE = 0.2 -- 派奖比例
local CJ_BIG_REMOVE_GOLD = 3000000 --彩金回收金币
local CJ_SMALL_REMOVE_GOLD = 1000000 --彩金回收金币
local CJ_BIG_ADD = {min = 500, max = 1000} --大彩金每秒增加
local CJ_SMALL_Add = {min = 100, max = 500} --小彩金每秒增加
local CJ_BIG_INFO = {min = 1000000, max = 1500000} --大彩金初始化
local CJ_SMALL_INFO = {min = 300000, max = 500000} --小彩金初始化
local last_caijin_add_big
local last_caijin_add_small

local function SendMessage(msg)
	--LOG_WARNING("发送给所有玩家")
	send_to_all("ReceiveMessage",msg,gameid)
end

--检测彩金
local function check_cai_gold()
	--判断返回
	if not run_times then
		return
	end

	--数据赋值
	run_times = run_times + 1

	--判断赋值
	if run_times >= 20 then
		--数据赋值
		-- run_times = nil
		-- local big_nowadd_gold = math.random(CJ_BIG_ADD.min, CJ_BIG_ADD.max) --增加大彩金
		-- local small_nowadd_gold = math.random(CJ_SMALL_Add.min, CJ_SMALL_Add.max)--增加小彩金
		-- big_gold = big_gold + big_nowadd_gold + big_add_gold --大彩金
		-- small_gold = small_gold + small_nowadd_gold + small_add_gold --小彩金
		-- big_system_gold = big_system_gold + big_nowadd_gold --系统大彩金
		-- small_system_gold = small_system_gold + small_nowadd_gold --系统小彩金

		--判断回收金币
		if big_gold > CJ_BIG_REMOVE_GOLD then
			-- big_system_gold = math.floor(big_system_gold - big_gold * CJ_REMOVE_RATE)
			big_gold = math.floor(big_gold * (1 - CJ_REMOVE_RATE))
		end
		if small_gold > CJ_SMALL_REMOVE_GOLD then
			-- small_system_gold = math.floor(small_system_gold - small_gold * CJ_REMOVE_RATE)
			small_gold = math.floor(small_gold * (1 - CJ_REMOVE_RATE))
		end

		--发送消息
		SendMessage({big_gold,small_gold})

		--数据赋值
		run_times = 0
		-- big_add_gold = 0
		-- small_add_gold = 0
	end
end

function this.update()

	if last_biggoldpool~=big_gold or last_smallgoldpool~= small_gold then
		last_biggoldpool,last_smallgoldpool=big_gold,small_gold
		SendMessage({big_gold,small_gold})
	end

	-- if hadwin==1 and isneedsend == true then 
	-- 	isneedsend=false
	-- 	--LOG_WARNING("取消可以中奖")
	-- 	SendMessage("false")
	-- end

	--检测彩金
	check_cai_gold()
end

function this.init(t,api,ps,ftable,ttable)
	send_to_all=api.call_all_table
	players=ps

	--彩金数据初始化
	run_times = 0
	-- big_add_gold = 0 --增加大彩金
	-- small_add_gold =  0--增加小彩金
	big_system_gold = math.random(CJ_BIG_INFO.min, CJ_BIG_INFO.max) --系统大彩金
	small_system_gold = math.random(CJ_SMALL_INFO.min, CJ_SMALL_INFO.max) --系统小彩金
	big_gold = big_system_gold --大彩金
	small_gold = small_system_gold --小彩金
end

function this.ReceiveMessage(uid,status,gold)    --status  玩家金币状态 1表示 玩家下注的金币  2表示玩家赢取的金币数量（不包含彩金池的数量）3表示彩金池数据变动
	-- LOG_WARNING("接收到服务器发送的数据："..gold)			--增加状态4  如果有4的信息发送 表示之前
											
	if playerinfo.uid ==nil then
		playerinfo.uid={cost=0,earn=0}
	end

	if status==1 then
		playerinfo.uid.cost=gold +playerinfo.uid.cost
		big_gold =big_gold+ math.max(1, math.floor((gold) * 0.07)) --增加大彩金
		small_gold =small_gold+ math.max(1, math.floor((gold) * 0.03))--增加小彩金
		all_cost=all_cost+gold
	elseif status==2 then
		playerinfo.uid.earn=gold +playerinfo.uid.earn
		all_earn=all_earn+gold
	elseif status==3 then
		local win_goldpool1,win_goldpool2
		if gold~=0 and (gold.big>0 or gold.small>0) then
			-- hadwin=1
			win_goldpool1,win_goldpool2 = big_gold*0.01*gold.big,small_gold*0.01*gold.small
			-- big_system_gold,small_system_gold=big_system_gold*(1-0.01*gold.big),small_system_gold*(1-0.01*gold.big)
			big_gold,small_gold=big_gold-win_goldpool1,small_gold-win_goldpool2
			all_earn=all_earn+win_goldpool1+win_goldpool2
			playerinfo.uid.earn=win_goldpool1+win_goldpool2 +playerinfo.uid.earn
			last_caijin_add_big,last_caijin_add_small=win_goldpool1,win_goldpool2
			table.insert(histroy_goldpool,1,{nickname=players[uid].nickname,biggold=big_gold,smallgold=small_gold})
			return win_goldpool1,win_goldpool2 
		else
			return  big_gold,small_gold
		end
	elseif status==4 then
		if  next(histroy_goldpool) then 
			for	i=1,#histroy_goldpool do 
				if histroy_goldpool[i].nickname==players[uid].nickname then
					big_gold,small_gold=big_gold+histroy_goldpool[i].biggold,small_gold+histroy_goldpool[i].smallgold
					all_earn=all_earn-histroy_goldpool[i].biggold-histroy_goldpool[i].smallgold
					playerinfo.uid.earn=playerinfo.uid.earn-histroy_goldpool[i].biggold-histroy_goldpool[i].smallgold
					table.remove(histroy_goldpool,i)
					break
				end
			end
		end
	end
end

return this