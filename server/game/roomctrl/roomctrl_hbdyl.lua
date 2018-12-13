local this = {}
local send_to_all
local goldpool=10000000          --奖池金额
local goldpool_limit=10000000      --奖池金额限制（可以中大奖）
local last_goldpool=10000000       --之前的奖金池数量
local playerinfo={}
local all_cost=0
local all_earn=0
local percentage=10000    --抽成金额限制
local gameid=10005
local hadwin=1   --用hadwin记录信息是否送大奖  0表示未发送  1表示已经发送
local isneedsend=false

local function SendMessage(msg)
	--LOG_WARNING("发送给所有玩家")
	send_to_all("ReceiveMessage",msg,gameid)
end

function this.update()
	if all_cost >= percentage then
		--LOG_WARNING("可以抽成")
		local current_sub=math.floor(all_cost/percentage)
		goldpool=goldpool+ current_sub*percentage*0.1
		all_cost=all_cost-current_sub*percentage
		last_goldpool=goldpool
		SendMessage(goldpool)
	end

	if goldpool~=last_goldpool then
		last_goldpool=goldpool
		SendMessage(goldpool)
	end

	if goldpool>= goldpool_limit*1.5 then
		SendMessage("true")
		--LOG_WARNING("发送可以中奖")
		hadwin=0
		isneedsend=true
		SendMessage(goldpool)
	end

	if hadwin==1 and isneedsend == true then 
		isneedsend=false
		--LOG_WARNING("取消可以中奖")
		SendMessage("false")
	end
end

function this.init(t,api,ps,ftable,ttable)
	--LOG_WARNING("初始化成功")
	-- ctrl.init(type,api,players,free_table,total_tables)
	send_to_all=api.call_all_table
	players=ps
end

function this.ReceiveMessage(uid,status,gold)    --status  玩家金币状态 1表示 玩家下注的金币  2表示玩家赢取的金币数量（不包含彩金池的数量）3表示彩金池数据变动
	--LOG_WARNING("接收到服务器发送的数据："..gold)
	if playerinfo.uid ==nil then
		playerinfo.uid={cost=0,earn=0}
	end

	if status==1 then
		playerinfo.uid.cost=gold +playerinfo.uid.cost
		all_cost=all_cost+gold
	elseif status==2 then
		playerinfo.uid.earn=gold +playerinfo.uid.earn
		all_earn=all_earn+gold
	elseif status==3 then
		if gold>0 then
			--LOG_DEBUG("111111")
			hadwin=1
		end
		local win_goldpool = goldpool*0.01*gold
		goldpool=goldpool-win_goldpool
		all_earn=all_earn+win_goldpool
		playerinfo.uid.earn=win_goldpool +playerinfo.uid.earn
		--SendMessage(goldpool)
		if win_goldpool<=0 then
			--LOG_DEBUG("22222")
			win_goldpool=nil
		end

		return win_goldpool or goldpool
	end
	-- last_goldpool=gold
	-- LOG_DEBUG("last_goldpool"..last_goldpool)
end

return this