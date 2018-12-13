
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local json = require "cjson"
local crypt = require "skynet.crypt"

local base64encode = crypt.base64encode

local send_msg --发送消息给客户端
local save_data --在下一个保存点保存数据
local save_data_imm --立刻保存数据
local call_manager
local join_game_mgr
local leave_game_mgr
local load_userdata_mgr
local update_client_info
local add_gold
local sub_gold
local sub_money
local add_money
local add_hongbao
local sub_hongbao
local sub_bank
local add_bank
local log
local add_buy_count
local table = table

local this = {}
local CMD = {}
local userdata
local uid
local nodename
local player
local redis
local logredis
local cfgShop = _cfgShop
local cfgGoods = _cfgGoods
local cfgData = _cfgData
local cfgTask = _cfgTask
local taskType2Id = {}
local rankserver
this.CMD = CMD

local gamenode, gameaddr

--签到奖励配置
local SIGN_GOLD = cfgData.sign_gold
-- 红包兑换配置
local cfgWinHongbao = cfgData.winhongbao
-- 绑定红包奖励
local cfgBindhongbao = cfgData.bindhongbao

local function decode_data(data)
	return skynet.unpack(data)
end

local function encode_data(info)
	return skynet.packstring(info)
end

--记录用户加入游戏
local function join_game(node, addr, gid)
	gamenode = node
	gameaddr = addr
	player.gamenode = node
	player.gameaddr = addr
	player.gameid = gid
	LOG_DEBUG("user[%d] join_game[%s] node[%s] addr[%s]", uid, tostring(gid), tostring(node), tostring(addr))

	log("join_game", string.format('{"gold":%d,"money":%d,"gameid":%d,"node":"%s","addr":"%s"}',
		userdata.gold or 0, userdata.money or 0, gid or 0, node or "nil", addr or "nil"))

	-- local ok, data = pcall(skynet.call, redis, "lua", "execute", "get", "user:"..tostring(uid))
	if online and not userdata.gm then
		pcall(skynet.send, logredis, "lua", "execute", "HSET", "user_map", uid, 
			string.format('{"uid":%d,"gold":%d,"money":%d,"bank":"%s","charged":"%s","hongbao":"%s","channel":0,"gameid":%d,"onlinetime":"%s","jointime":"%s","nickname":"%s"}',
				uid, userdata.gold, userdata.money, userdata.bank, userdata.charged, userdata.hongbao, gid, onlinetime or 0, os.date("%Y-%m-%d %X"), userdata.nickname))
	end
	join_game_mgr(node, addr) --调用userdata里面的api.join_game，实际上就是调用了agent里面的join用来记录node和addr
end

--今天是否已签到
local function is_today_signed( ... )
	if userdata.lastsigntime and userdata.lastsigntime > 0 then
		local last_t = string.split(os.date("%Y-%j", userdata.lastsigntime), "-")
		local now_t = string.split(os.date("%Y-%j", os.time()),"-")
		if tonumber(last_t[1]) >= tonumber(now_t[1]) and tonumber(last_t[2]) >= tonumber(now_t[2]) then	
			return true
		end
	end
end

local function clear_invite_list()
	if not userdata.group or not userdata.group.child then return end
	for k,v in pairs(userdata.group.child) do
		if k ~= "time" then
			userdata.group.oldchild = userdata.group.oldchild or {}
			userdata.group.oldchild[k] = v
		end

		userdata.group.child = nil
	end
end

local function check_clear_invite_list()
	if userdata.group and userdata.group.child then
		if not userdata.group.child.time then
			userdata.group.child = nil
			save_data()
			return
		end
		local now = os.time()
		local d1 = os.date("*t", userdata.group.child.time)
		local d2 = os.date("*t", now)
		if d2.yday - d1.yday >= 7 then
			clear_invite_list()
		else
			if d2.yday ~= d1.yday then
				-- 不是同一天
				if d1.wday == 1 then
					-- 每周一更新
					clear_invite_list()
				elseif d1.wday > 2 and d2.wday < d1.wday and d2.wday > 1 then
					clear_invite_list()
				elseif d2.wday == 1 then
					clear_invite_list()
				end
			end
		end
	end
end

local function reset_task(id, resettime)
	userdata.task[id] = nil
	userdata.task[id] = {
		progress1 = 0,
		progress2 = 0,
		endtime = 0,
		status = 1,
		receivetime = resettime,
	}
end

--获得当天凌晨时间戳
local function get_daybreak_time()
	local tmp = os.date("*t", os.time())
	local time_table = {
		year = tmp.year,
		month = tmp.month,
		day = tmp.day,
		hour = 0,
		min = 0,
		sec = 0
	}
	return os.time(time_table)
end

local function check_clear_week_task()
	local nowtime = os.time()
	local date = os.date("*t", nowtime)
	local resettime
	if date.wday == 2 then
		if userdata.task then
			for id,data in pairs(userdata.task) do
				if cfgTask[id] then
					if cfgTask[id].tasktype == "week" and (nowtime - (userdata.receivetime or 0) >= 24*60*60) then
						if not resettime then
							resettime = get_daybreak_time()
						end
						reset_task(id, resettime)
					end
				else
					userdata.task[id] = nil
				end
				
			end
		end
	end
end

--检查任务列表
local function check_task_list()
	local need_save
	if not userdata.task then 
		userdata.task = {} 
		need_save = 1
	end
	local resettime
--	PRINT_T(cfgTask)
	for id, v in pairs(cfgTask) do
		if v.time and #(v.time) == 0 and not userdata.task[id] then
			if not resettime then
				resettime = get_daybreak_time()
			end
			reset_task(id, resettime)
			need_save = 1
		end
		if v.targettype1 and #v.targettype1 > 0 then
			taskType2Id[v.targettype1] = taskType2Id[v.targettype1] or {}
			table.insert(taskType2Id[v.targettype1], id)
		end
		
		if v.targettype2 and #v.targettype2 > 0 then
			taskType2Id[v.targettype2] = taskType2Id[v.targettype2] or {}
			table.insert(taskType2Id[v.targettype2], id)
		end
	end
	if need_save then
		save_data()
	end
--	PRINT_T(userdata)
end

local function send_to_game(func, ...)
	if gamenode and gameaddr then
		pcall(cluster.send, gamenode, gameaddr, func, ...)
	end
end

local function check_binding_award()
	if userdata.binding and not userdata.bindaward then
		skynet.fork(send_msg, "user.BindAwardsNtf", {})
	end
end

local function get_bind_award()
	-- cfgBindhongbao
	local value = math.random(cfgBindhongbao[1] or 10, cfgBindhongbao[2] or 100)
	LOG_DEBUG(uid.."获取绑定红包:"..value)

	userdata.bindaward = true
	add_hongbao(value, 1004)
	save_data()

	return value
end

--添加任务奖励
local function add_task_award(id)
	local task_info = assert(cfgTask[id])
	if task_info.targettype1 == "add_friend" then
		add_hongbao(task_info.award, 1005)
	end
end

function this.check_in_game()
	return gamenode and gameaddr
end

function this.destroy()
	-- 释放内存
end


function this.init(id, api, data, p, rds, logrds)
	send_msg = api.send_msg
	save_data = api.save_data
	save_data_imm = api.save_data_imm
	call_manager = api.call_manager
	join_game_mgr = api.join_game
	leave_game_mgr = api.leave_game
	load_userdata_mgr = api.load_userdata
	add_gold = api.add_gold
	sub_gold = api.sub_gold
	sub_money = api.sub_money
	add_money = api.add_money
	add_hongbao = api.add_hongbao
	sub_hongbao = api.sub_hongbao
	add_bank = api.add_bank
	sub_bank = api.sub_bank
	add_buy_count = api.add_buy_count
	update_client_info = api.update_client_info
	log = api.log
	userdata = data
	uid = id
	player = p
	redis = rds
	logredis = logrds
	check_task_list()
	check_binding_award()
	check_clear_invite_list()
	check_clear_week_task()

	rankserver = skynet.uniqueservice("rankserver")
end

function this.offline()
	LOG_DEBUG("userdata offline:"..uid)
	if gamenode and gameaddr then
		LOG_DEBUG(uid..":"..gamenode..":"..gameaddr)
		-- 如果游戏内部offline返回true的话表示将玩家踢出桌子
		local ok, result = pcall(cluster.call, gamenode, gameaddr, "offline", uid)
		if not ok or (ok and result) then
			LOG_DEBUG("用户离开桌子了:"..uid..":"..tostring(result))
			gamenode = nil
			gameaddr = nil
		end
	end
end

function this.BindAwardsReq(msg)
	if userdata.binding then
		if not userdata.bindaward then
			return "user.BindAwardsRep", {value = get_bind_award()}
		else
			return "user.BindAwardsRep", {value = -2}
		end
	else
		local ok, data = pcall(skynet.call, redis, "lua", "execute", "get", "user:"..tostring(uid))
		if ok and data then
			local ok, info = pcall(json.decode, data)
			if ok and info then
				return "user.BindAwardsRep", {value = get_bind_award()}
			end
		end
		return "user.BindAwardsRep", {value = -1}
	end
end

function this.MatchRangeReq(msg)
	if msg and msg.matchid then
	-- local ok, result = pcall(skynet.call, redis, "lua", "execute", "LRANGE", "match->"..uid, 0, -1)
		local ok, range = pcall(skynet.call, redis, "lua", "execute", "ZREVRANK", "match_range->"..msg.matchid, uid)
		if ok then
			range = tonumber(range or -2)
			range = range + 1
			return "user.MatchRangeRep", {range = range}
		end
	end
end

-- 1001 id不存在
-- 1002 胜利次数不足
function this.BuyHongbaoReq(msg)
	if not msg or not msg.id then return end
	if not cfgWinHongbao[msg.id] then return "user.BuyHongbaoRep", {result = 1001, value = 0} end
	local cfg = cfgWinHongbao[msg.id]
	if not userdata.wincount or userdata.wincount < cfg.cost then
		-- update_client_info
		return "user.BuyHongbaoRep", {result = 1001, value = 0}
	end
	userdata.wincount = userdata.wincount - cfg.cost
	update_client_info("wincount")
	save_data()
	local node = getNodeByWeight(cfg.award)
	local v = math.random(node.earn[1], node.earn[2])
	log("exchange_hongbao", string.format('{"gold":%d,"money":%d,"id":%d,"cost":%d,"wincount":%d,"hongbao":"%s"}',
		userdata.gold or 0, userdata.money or 0, msg.id, cfg.cost, userdata.wincount, v))
	add_hongbao(v, 1001)
	return "user.BuyHongbaoRep", {result = 0, value = v}
end

function this.CheckBuyStatusReq(...)
	-- 检测有没有不能购买的东西
	local list = {}
	if userdata.buycounts then
		for shopid,v in pairs(cfgShop) do
			if v and v.buycount and v.buycount > 0 then
				if userdata.buycounts[shopid] and userdata.buycounts[shopid] >= v.buycount then
					table.insert(list, shopid)
				end
			end
		end
	end
	return "user.CheckBuyStatusRep", {status = list}
end

-- 1001协议错误
-- 1002手机号码有误
-- 1003商品ID错误
-- 1004改商品不是实物商品
-- 1005红包不足
function this.BuyRealGoodsReq(msg)
	if not msg or not msg.shopid or not msg.phone then
		return "user.BuyRealGoodsRep", {result = 1001, phone="-"}
	end
	if #(msg.phone) ~= 11 then
		return "user.BuyRealGoodsRep", {result = 1002, phone=msg.phone}
	end

	local cfg = cfgShop[msg.shopid]
	if not cfg then return "user.BuyRealGoodsRep", {result = 1003, phone=msg.phone} end
	if cfg.type ~= 5 then return "user.BuyRealGoodsRep", {result = 1004, phone=msg.phone} end

	local price = cfg.price
	if sub_hongbao(price, 1006) then
		log("real_goods", string.format('{"shopid":%d, "phone":"%s"}', msg.shopid, msg.phone))
		add_buy_count(msg.shopid, 1)
		return "user.BuyRealGoodsRep", {result = 1, phone=msg.phone}
	else
		return "user.BuyRealGoodsRep", {result = 1005, phone=msg.phone}
	end
end

-- message BuyRealGoodsReq {
-- 	required int32 shopid = 1; //shop表里面的ID
-- 	required string phone = 2; //用户手机号码
-- 	optional string des = 3; //用户留下的其他信息,暂时不填
-- }
-- message BuyRealGoodsRep {
-- 	required int32 result = 1; // 1表示成功，其他值表示失败
-- 	required string phone = 2; //用户手机号码
-- 	optional string des = 3; //用户留下的其他信息,暂时不填
-- }

-- 1001 参数错误
-- 1002 不让购买，例如人民币购买行为
-- 1003 钱不够
function this.BuyReq(msg)
	if not msg or not msg.id or not msg.count then return end
	local cfg = cfgShop[msg.id]
	if not cfg then return "user.BuyRep", {id=msg.id, count=msg.count, result=1001} end
	-- this[1001]={type=0,payid=1001,price=6,goodsid=1002,count=600,exgoods={}}
	if cfg.payid == 1002 then
		-- 钻石购买
		if not sub_money(cfg.price * msg.count, 1005) then
			return "user.BuyRep", {id=msg.id, count=msg.count, result=1003}
		end
	elseif cfg.payid == 1003 then
		-- 金币购买
		if not sub_gold(cfg.price * msg.count, 103) then
			return "user.BuyRep", {id=msg.id, count=msg.count, result=1003}
		end
	else
		-- 不让购买
		return "user.BuyRep", {id=msg.id, count=msg.count, result=1001}
	end

	-- 增加物品
	local function add_goods(id, count, free)
		LOG_DEBUG("add goods:"..id..",count="..count)
		if id == 1001 then
			-- 增加人民币，做不到啊
		elseif id == 1002 then
			-- 钻石
			if free then
				add_money(count, 1006)
			else
				add_money(count, 1005)
			end
		elseif id == 1003 then
			local reason
			if free then 
				reason = 104
			else
				reason = 103
			end
			if add_gold(count, reason) then
				LOG_DEBUG("加钱了")
				-- 如果是金币增加了，那么需要通知给游戏
				send_to_game("add_gold", uid, count, 1001)
			else
				LOG_DEBUG("加钱失败了")
			end
		end
	end

	-- 发放商品
	add_goods(cfg.goodsid, cfg.count*msg.count)
	local id, cnt
	for i=1,#(cfg.exgoods),2 do
		id = cfg.exgoods[i]
		cnt = cfg.exgoods[i+1]
		add_goods(id, cnt*msg.count, true)
	end
	return "user.BuyRep",{id=msg.id, count=msg.count, result=0}
end

function this.reqRefreshInfo(msg)
	if not msg then return end
	if msg.uid == uid then
		-- optional int32 uid = 1;
		-- optional int32 type = 2;
		-- optional int64 gold = 3;
		-- optional int64 bank = 4;
		-- optional int32 level = 5;
		-- optional int32 vipexp = 6;
		-- optional int32 sex = 7;
		-- optional int32 charged = 8;//已充值金额
		-- optional int32 gameid = 9;//游戏id
	
		-- optional string headimg = 12;
		-- optional string nickname = 13;
		-- optional string signature = 14;//自定义签名
		
		-- optional string phone = 15;
		-- optional string alipayacc = 16;
		-- optional string alipayrealname = 17;
		-- optional string bankacc = 18;
		-- optional string bankrealname = 19;
		if msg.type == 0 then
			-- body
			return "hall.resRefreshInfo", { uid=uid, type = 0,nickname=userdata.nickname,gold=userdata.gold,
			bank=userdata.bank,exp=userdata.exp,vipexp=userdata.vipexp,sex=userdata.sex,usermsg=userdata.usermsg or " ",
			hongbao=userdata.hongbao or 0, money=userdata.money or 0, headimg = userdata.headimg, wincount = userdata.wincount or 0,
			charged=userdata.charged or 0}
		end
	elseif msg.uid then
		local data = load_userdata_mgr(msg.uid)
		if data then
			-- luadump(data)
			local t = 1 + 32 + 128 + 64 + 4
			return "hall.resRefreshInfo", {type = t, gold=data.gold,uid=msg.uid, nickname=data.nickname, sex=data.sex, usermsg=data.usermsg or "", headimg = userdata.headimg or ""}
		else
			-- 用户不存在
			return "hall.resRefreshInfo", {type = 1, uid=msg.uid, nickname="unknow"}
		end
	end
end

-- 0成功
-- 1001参数不合法
-- type错误
function this.ModifyUserInfoReq(msg)
	if not msg then return end
	if msg.type == 1 then
		if msg.value and #(msg.value) < 100 then
			userdata.usermsg = msg.value
			save_data_imm()
			LOG_DEBUG(msg.value)
			send_msg("user.UserInfoResonpse", {uid=uid, usermsg=userdata.usermsg, type = 128})
			return "user.ModifyUserInfoRep",{result=0}
		else
			return "user.ModifyUserInfoRep",{result=1001}
		end
	elseif msg.type == 2 then
		if msg.value then
			userdata.nickname = msg.value
			save_data_imm()
			player.nickname = userdata.nickname
			send_msg("user.UserInfoResonpse", {uid=uid, nickname=userdata.nickname, type = 1})
			return "user.ModifyUserInfoRep",{result=0}
		else
			return "user.ModifyUserInfoRep",{result=1001}
		end
	end
	return "user.ModifyUserInfoRep",{result=1002}
end

--快速加入
function this.QuickJoinRequest(msg)
	if gamenode then
		return "user.QuickJoinResonpse", {result=100, gameid=0, ismatch = -1}
	end
	if msg.code and msg.code ~= 0 then
		local node, addr, gid = call_manager("join_table", msg.code, player)
		if not addr then
			node = tonumber(node) or 101
			return "user.QuickJoinResonpse", {result=node,gameid=0, ismatch = -1}
		end
		join_game(node, addr, gid)
		return
	elseif msg.gameid and msg.gameid ~= 0 and msg.pay and msg.pay ~= 0 and msg.score and msg.score ~=0 and msg.times and msg.times ~= 0 then
		local node, addr = call_manager("create_table", msg.gameid, msg.pay, msg.score, msg.times,player, msg.params)
		if not addr then
			node = tonumber(node) or 101
			return "user.QuickJoinResonpse", {result=node,gameid=0, ismatch = -1}
		end
		join_game(node, addr, msg.gameid)
		return
	else
		return "user.QuickJoinResonpse", {result=200,gameid=0, ismatch = -1}
	end
end

--快速加入金币游戏
function this.QuickJoinGoldGameReq(msg)
	if not msg or not msg.gameid then return end
	if gamenode then
		return "user.QuickJoinResonpse", {result = 100, gameid = msg.gameid, ismatch = -1}
	end
	-- quick_join(gameid, player)
	local node, addr = call_manager("quick_join", msg.gameid, player) --这个是调用usermanager里面的
	if not addr then
		node = tonumber(node) or 101
		return "user.QuickJoinResonpse", {result=node,gameid=0, ismatch = -1}
	end
	join_game(node, addr, msg.gameid) --这个是用来记录日志和node和addr的
end

--加入比赛
function this.JoinMatch(msg)
	if not msg or not msg.matchid then return end
	if gamenode then
		return "user.QuickJoinResonpse", {result = 100, gameid = msg.matchid, ismatch = 1}
	end
	local node, addr = call_manager("join_match", msg.matchid, player)
	if not addr then
		node = tonumber(node) or 101
		return "user.QuickJoinResonpse", {result=node,gameid=0, ismatch = 1}
	end
	join_game(node, addr, msg.matchid)
end

function this.MatchStatusReq(msg)
	local ok, result = pcall(skynet.call, redis, "lua", "execute", "LRANGE", "match->"..uid, 0, -1)
	if ok and result then
		return "user.MatchStatusRep", {matchlist=result}
	end
	return "user.MatchStatusRep", {matchlist={}}
end

function this.CheckReconnectReq()
	LOG_DEBUG("CheckReconnectReq:"..tostring(gamenode)..","..tostring(gameaddr)..","..tostring(uid))

	-- if not gamenode or not gameaddr then
	-- 	local ok, data = pcall(skynet.call, redis, "lua", "execute", "get", "tableinfo->"..tostring(uid))

	-- 	if ok and data then
	-- 		gamenode, gameaddr = string.match(data, "([^:]*):([^:]*)")
	-- 		if not gamenode or not gameaddr then
	-- 			gamenode = nil
	-- 			gameaddr = nil
	-- 		end
	-- 	else
	-- 		-- LOG_DEBUG(tostring(data))
	-- 	end
	-- end

	if gamenode and gameaddr then
		-- gameaddr = tonumber(gameaddr)
		-- luadump(player)
		local ok, result = pcall(cluster.call, gamenode, gameaddr, "check_player", uid, player.agnode, player.agaddr, player.datnode, player.dataddr)
		if ok and result then
			LOG_DEBUG("需要断线重连:"..uid..",gameid:"..result)
			join_game(gamenode, gameaddr, result)
			return "user.CheckReconnectRep", {gameid = result}
		else
			gameaddr = nil
			gamenode = nil
			-- pcall(skynet.send, redis, "lua", "execute", "del", "tableinfo->"..tostring(uid))
		end
	end

	return "user.CheckReconnectRep", {gameid = 0}
end

function this.GameListReq()
	-- body
	-- redis
	-- local info = decode_data({time,time+config.wait_time,paytype,times,score,gameid,code})
	local ok, result = pcall(skynet.call, redis, "lua", "execute", "LRANGE", "tablelist->"..uid, 0, 100)
	-- luadump(result)
	local nowtime = os.time()
	local list = {}
	if ok and result then
		for i,v in ipairs(result) do
			local a, b = pcall(decode_data, v)
			if a and b then
				if nowtime >= b[2] then
					pcall(skynet.send, redis, "lua", "execute", "LREM", "tablelist->"..uid, 0, v)
				else
					table.insert(list,{time=b[1],endtime=b[2],paytype=b[3],times=b[4],score=b[5],gameid=b[6],code=b[7],params=b[8]})
				end
			end
		end
	end

	return "user.GameListRep", {list = list}
end

function this.HistroyListReq()
	local ok, result = pcall(skynet.call, redis, "lua", "execute", "LRANGE", "histroy->"..uid, 0, 50)
	local list = {}
	if ok and result then
		for i,v in ipairs(result) do
			local ok, b = pcall(decode_data, v)
			if ok and b then
				b.times = b.times or -1
				if b.times == 0 then
					b.times = -1
				end
				table.insert(list, {index=i,gameid=b.gameid, code=b.code,time=b.time,
					score=b.score,owner=b.owner,times=b.times,scores=b.scores,players=b.players})
			end
		end
	end

	-- luadump(list)
--	PRINT_T(list)
	return "user.HistroyListRep", {list=list}
end

function this.SingleHistroyReq(msg)
	if not msg or not msg.index then return end
	if msg.index > 50 or msg.index < 0 then return end

	local ok, result = pcall(skynet.call, redis, "lua", "execute", "LINDEX", "histroy->"..uid, msg.index - 1)
	if ok and result then
		local ok, data = pcall(decode_data, result)
		if ok and data then
			-- luadump(data)
			local list = {}
			local datalist = data.hash
			if datalist then
				for i,h in pairs(datalist) do
					if h and h.hash and h.players and h.scores then
						table.insert(list, {hash=h.hash, players=h.players, scores=h.scores})
					end
				end
				return "user.HistroyInfo", {list = list}
			end
		else
			LOG_DEBUG("战绩数据解析失败:"..tostring(data))
		end
	end
end

function this.DissolveTableReq(msg)
	if msg and msg.code and msg.code ~= 0 then
		local result = call_manager("dissolve_table", msg.code, uid)
		return "user.DissolveTableRep", {result=result}
	end
end

function this.RangeListRep(msg)
	if not msg then return end
	if not msg.type then return end
	local ok, data = pcall(skynet.call, rankserver, "lua", "get_range", msg.type)
	-- LOG_DEBUG("请求榜单:"..msg.type)
	if ok then
		-- luadump(data)
		if data and #data > 0 then
			local list = {}
			local j
			for i,v in ipairs(data) do
				-- {uid, score, nickname}
				table.insert(list, {uid=v[1], value=v[2], nickname=v[3]})
				if i%20 == 0 then
					-- luadump(list)
					send_msg("user.RangeListReq", {index = i-(#list), count = #list, type = msg.type, list = list})
					list = {}
				end
				j = i
			end
			if #list then
				-- luadump(list)
				send_msg("user.RangeListReq", {index = j-(#list), count = #list, type = msg.type, list = list})
			end
		else
			return "user.RangeListReq", {index = 0, count = 0, type = msg.type}
		end
	else
		return "user.RangeListReq", {index = 0, count = 0, type = msg.type}
	end
end

function this.RequestSignInData()
	LOG_DEBUG("player[%d] RequestSignInData", uid)
	local is_signed = is_today_signed() and 1 or 0
	local signed_days = userdata.signdays or 0
	send_msg("user.ReponseSignInData", {isSigned = is_signed, signedDays = signed_days})
end

function this.UserSignIn()
	LOG_DEBUG("player[%d] UserSignIn", uid)
	if is_today_signed() then
		LOG_WARNING("illegal msg RequestSignInData")
		return
	end
	userdata.lastsigntime = os.time()
	userdata.signdays = (userdata.signdays or 0) + 1
	
	if userdata.signdays > 7 then userdata.signdays = 1 end
	add_gold(SIGN_GOLD[userdata.signdays], 101)
	-- call_manager("add_gold", uid, SIGN_GOLD[userdata.signdays], 101)
	save_data()
	send_msg("user.UserSignIn", {})

end

function this.SafeStatusRep()
	local msg = {}
	if userdata.safepass then
		msg.haspass = 1
	else
		msg.haspass = 0
	end

	if userdata.safenotify then
		msg.notify = 1
	else 
		msg.notify = 0
	end

	return "user.SafeStatusReq", msg
end

function this.CheckPassReq(msg)
	-- 做验证限制，防止出错
	if not msg or not msg.pass then return end
	if not userdata.safepass then return "user.CheckPassRep", {result = 1000} end
	if userdata.safepass ~= msg.pass then return "user.CheckPassRep", {result = 1001} end
	return "user.CheckPassRep", {result = 0}
end

function this.ResetSafePasswordReq(msg)
	if not msg or not msg.oldpass or not msg.newpass then return end
	if msg.oldpass == "-1" then
		if userdata.safepass then
			-- 已经设置过密码了，不能当第一次来设置
			return "user.ResetSafePasswordRep", {result = 1002}
		end
	elseif msg.oldpass == "-2" then
		-- 通过手机验证码重置密码
		local ok, value = pcall(skynet.call, redis, "lua", "execute", "get", uid.."vcode")
		if not ok or not value then
			return "user.ResetSafePasswordRep", {result = 1004}
		end
		if not msg.code or tostring(value) ~= tostring(msg.code) then
			return "user.ResetSafePasswordRep", {result = 1004}
		end
		pcall(skynet.call, redis, "lua", "execute", "del", uid.."vcode")
	else
		if not userdata.safepass then
			-- 还没设置过密码，不能修改密码
			return "user.ResetSafePasswordRep", {result = 1000}
		elseif userdata.safepass ~= msg.oldpass then
			-- 密码验证失败
			return "user.ResetSafePasswordRep", {result = 1001}
		end
	end
	local newpass = msg.newpass
	if #newpass ~= 32 then
		-- 密码应该是md5计算之后的值,所以是32位
		-- 密码格式不对
		return "user.ResetSafePasswordRep", {result = 1003}
	end
	userdata.safepass = newpass
	save_data()
	return "user.ResetSafePasswordRep", {result = 0}
end

function this.SafeMoneyReq(msg)
	if not msg or not msg.pass then return end
	if not userdata.safepass then return "user.SafeMoneyRep", {value = -2} end
	if userdata.safepass ~= msg.pass then return "user.SafeMoneyRep", {value = -1} end
	return "user.SafeMoneyRep", {value = userdata.bank or 0}
end

-- 存钱
function this.SaveSafeMoneyReq(msg)
	if not msg or not msg.value or not msg.pass then return end
	if not userdata.safepass then return "user.SaveSafeMoneyRep", {result=1000} end
	if userdata.safepass ~= msg.pass then return "user.SaveSafeMoneyRep",  {result=1001} end
	if gamenode then
		-- 在游戏中，不能存钱，请稍候再试
		return "user.SaveSafeMoneyRep", {result=1002}
	end
	local value = math.floor(tonumber(msg.value))

	if sub_gold(value, 106) then
		if add_bank(value, 1001) then
			local sql = "INSERT INTO tbl_bank_log_"..os.date("%Y%m").."(Uid,Type,Create_Time,Value) VALUES("..
			tostring(uid)..",1,"..tostring(os.time())..","..tostring(value)..")"
			LOG_DEBUG(sql)
			for i=1,3 do
				local ok, t = pcall(skynet.call, ".histroysql", "lua", "execute", sql)
				if ok then
					luadump(t)
					break
				end
			end
			log("save_safe_money", string.format('{"gold":%d,"money":%d,"bank":%d,"type":%d,"value":%d}',
				userdata.gold or 0, userdata.money or 0, userdata.bank or 0, 1, value))
			return "user.SaveSafeMoneyRep", {result=0, bank=userdata.bank}
		else
			add_gold(value, 109)
			-- LOG_ERROR(tostring(uid).."存钱的时候失败，钱扣了:"..tostring(value))
			-- 1004银行连接不上
			return "user.SaveSafeMoneyRep", {result=1004}
		end
	else
		return "user.SaveSafeMoneyRep", {result=1003}
	end
end

-- 取钱
function this.TakeSafeMoneyReq(msg)
	if not msg or not msg.value or not msg.pass or not msg.channel then return end
	if not userdata.safepass then return "user.TakeSafeMoneyRep", {result=1000} end
	if userdata.safepass ~= msg.pass then return "user.TakeSafeMoneyRep",  {result=1001} end
	local value = math.floor(tonumber(msg.value))
	if not value or value < 1 then return "user.TakeSafeMoneyRep",  {result=1002} end
	userdata.bank = userdata.bank or 0
	if value > userdata.bank then return "user.TakeSafeMoneyRep",  {result=1003} end
	if sub_bank(value, 1002) then

		if msg.channel == 1 then
			if add_gold(value, 107) then
				send_to_game("add_gold", uid, value, 1003)
				local sql = "INSERT INTO tbl_bank_log_"..os.date("%Y%m").."(Uid,Type,Create_Time,Value) VALUES("..
					tostring(uid)..",2,"..tostring(os.time())..","..tostring(value)..")"
				LOG_DEBUG(sql)
				for i=1,3 do
					local ok, t = pcall(skynet.call, ".histroysql", "lua", "execute", sql)
					if ok then
						luadump(t)
						break
					end
				end

				log("take_safe_money", string.format('{"gold":%d,"money":%d,"bank":%d,"type":%d,"value":%d}',
					userdata.gold or 0, userdata.money or 0, userdata.bank or 0, 2, value))
				return "user.TakeSafeMoneyRep",  {result=0, bank=userdata.bank}
			else
				LOG_ERROR(tostring(uid).."取钱的时候加钱失败，银行内钱扣了:"..tostring(value))
			end
		else
			local sql = "INSERT INTO tbl_bank_log_"..os.date("%Y%m").."(Uid,Type,Create_Time,Value) VALUES("..
				tostring(uid)..",4,"..tostring(os.time())..","..tostring(value)..")"
			LOG_DEBUG(sql)
			for i=1,3 do
				local ok, t = pcall(skynet.call, ".histroysql", "lua", "execute", sql)
				if ok then
					luadump(t)
					break
				end
			end

			log("take_safe_money", string.format('{"gold":%d,"money":%d,"bank":%d,"type":%d,"value":%d}',
					userdata.gold or 0, userdata.money or 0, userdata.bank or 0, 4, value))
			LOG_DEBUG(tostring(uid).."取钱到APP帐号,取:"..tostring(value))
			return "user.TakeSafeMoneyRep",  {result=0, bank=userdata.bank}
		end
	else
		return "user.TakeSafeMoneyRep",  {result=1003}
	end
end

function this.TransferSafeMoenyReq(msg)
 -- 保险箱转账功能
end

function this.SafeHistroyReq(msg)
-- 保险箱历史记录
	if not msg or not msg.year or not msg.month then return end
	if not userdata.safepass then return "user.SafeHistroyRep", {index=-1,total=-1} end
	if userdata.safepass ~= msg.pass then return "user.SafeHistroyRep", {index=-1,total=-1} end
	local time = tostring(msg.year)
	if msg.month < 10 then
		time = time .. "0"..msg.month
	else
		time = time .. msg.month
	end
	local sql = "SELECT * FROM tbl_bank_log_"..time.." WHERE Uid="..uid
	LOG_DEBUG(sql)
	for i=1,3 do
		local ok, t = pcall(skynet.call, ".histroysql", "lua", "execute", sql)
		if ok then
			if not t or t.err or t.errno then
				return "user.SafeHistroyRep", {index=-1,total=-1}
			end
			local total = #t
			if total%15 == 0 then
				total = math.floor(total/15)
			else
				total = math.floor(total/15) + 1
			end
			local info
			local list
			for i=0,total-1 do
				list = {}
				for j=1,15 do
					info = t[i*15+j]
					if not info then
						break
					end
					list[j] = {type=tonumber(info.Type), time = info.Create_Time, value=info.Value}
				end
				send_msg("user.SafeHistroyRep", {index=i+1, total=total, list=list})
			end
			break
		end
	end
end

function this.TransferHistroyReq(msg)
	
end

function this.BindParentNtf(msg)
	if not msg or not tonumber(msg.parent) then return end
	if tonumber(msg.parent) == uid then return end
	-- bind_parent
	if userdata.group and userdata.group.parent then
		LOG_DEBUG(uid.."尝试绑定上级"..msg.parent.."失败,已经有上级:"..userdata.group.parent)
		return
	end
	if call_manager("bind_parent", uid, msg.parent) then
		userdata.group = userdata.group or {}
		userdata.group.parent = msg.parent
		save_data()
		LOG_DEBUG(uid.."绑定上级成功:"..msg.parent)
	else
		LOG_DEBUG(uid.."尝试绑定上级"..msg.parent.."失败")
	end
end

function this.nextDay()
	-- 下一天
	-- 检查是否需要清理要求列表
	check_clear_invite_list()
	-- 检查清理周任务
	check_clear_week_task()
end

function this.RequestTaskInfo(msg)
	local taskInfo = {}
	for id, data in pairs(userdata.task) do
		table.insert(taskInfo, {taskid = id,
								status = data.status,
								progress1 = data.progress1,
								progress2 = data.progress2,
								endtime = data.endtime})
	end
	send_msg("user.RequestTaskInfoResult", {info = taskInfo})
end

function this.RequestTaskReward(msg)
	local result = -1
	local id = msg.taskid
	if userdata.task[id] then
		if userdata.task[id].status == 2 then
			--TODO add_reward
			userdata.task[id].status = 3
			save_data_imm()
			add_task_award(id)
			result = 1
		else
			result = userdata.task[id].status
		end
	end
	send_msg("user.RequestTaskRewardResult", {result = result})
end

function this.GetInviteListReq()
	local list = {}
	if userdata and userdata.group and userdata.group.child then
		for k,v in pairs(userdata.group.child) do
			if k ~= "time" then
				table.insert(list, k)
				table.insert(list, v)
			end
		end
	end
	return "user.GetInviteListRep", {list = list}
end

--检查任务
function this.check_task(tType, target, cnt)
	LOG_DEBUG("check_task uid[%d] tType[%s] target[%s], cnt[%s]", uid, tostring(tType), tostring(target), tostring(cnt))
	local notifyClient = {}
	local nowtime = os.time()
	for id, data in pairs(userdata.task) do
		local taskInfo = cfgTask[id]
		local progress1 = 0
		local progress2 = 0
		local status 
		if taskInfo.targettype1 == tType then
			if tType == "add_friend" and (data.endtime == 0 or (nowtime <= data.endtime)) then
			
				if not taskInfo.target1 or taskInfo.target1 == target then
					data.progress1 = (data.progress1 or 0) + 1
					progress1 = data.progress1 
				end
				-- if not taskInfo.target2 or taskInfo.target2 == target then
				-- 	data.progress2cnt = (data.progress2cnt or 0) + 1
				-- 	-- progress2 = data.progress2
				-- end
				-- if data.progress1 >= taskInfo.targetcnt1 then
				-- 	data.progress1 = (data.progress1 or 0) + 1
				-- 	progress1 = data.progress1 
				-- end
				if progress1 >= taskInfo.targetcnt1 then
					data.status = 2
					status = data.status
				end
			end
		end
		if progress1 > 0 or progress2 > 0 then
			table.insert(notifyClient, {taskid=id, progress1=progress1, progress2=progress2})
		end
	end 
	if next(notifyClient) then
		-- LOG_WARNING("PushTaskProgressChanged")
		-- PRINT_T(notifyClient)
		send_msg("user.PushTaskProgressChanged", {info = notifyClient})
		save_data()
	end
	-- PRINT_T(userdata)
end

function this.GetTodayHongbaoReq()
	-- pcall(skynet.call, _redis, "lua", "execute", "ZINCRBY", rankname.."1", value, _uid..":"..nn)
	-- ZSCORE key member 
	-- redis
	local nn = base64encode(userdata.nickname)
	local ok, score = pcall(skynet.call, redis, "lua", "execute", "ZSCORE", rankname.."1", uid..":"..nn)
	if ok then
		score = tonumber(score) or 0
		return "user.GetTodayHongbaoRep", {value=score}
	else
		return "user.GetTodayHongbaoRep", {value=0}
	end
end

----------------------------------------------------------------------------------------------------

function CMD.leave_game()
	LOG_DEBUG("离开游戏:"..tostring(uid))
	gamenode = nil
	gameaddr = nil

	log("leave_game", string.format('{"gold":%d,"money":%d,"gameid":%d}',
		userdata.gold or 0, userdata.money or 0, player.gameid or 0))

	if online and not userdata.gm then
		pcall(skynet.send, logredis, "lua", "execute", "HSET", "user_map", uid, 
			string.format('{"uid":%d,"gold":%d,"money":%d,"bank":"%s","charged":"%s","hongbao":"%s","channel":0,"gameid":%d,"onlinetime":"%s","jointime":"%s","nickname":"%s"}',
				uid, userdata.gold, userdata.money, userdata.bank, userdata.charged, userdata.hongbao, 0, onlinetime or 0, "", userdata.nickname))
	end

	leave_game_mgr()
end

function CMD.player_start_ctrl(ctrlinfo)
	userdata.ctrltype = ctrlinfo.ctrltype
	userdata.ctrlrate = ctrlinfo.ctrlrate
	userdata.ctrlmaxgold = ctrlinfo.ctrlmaxgold
	userdata.ctrlnowgold = ctrlinfo.ctrlnowgold
	userdata.ctrlstarttime = ctrlinfo.ctrlstarttime
	userdata.ctrloverttime = ctrlinfo.ctrloverttime
	userdata.ctrllevel = ctrlinfo.ctrllevel
	userdata.ctrlcount = ctrlinfo.ctrlcount
	userdata.ctrlcaijin = ctrlinfo.ctrlcaijin
	player.ctrlinfo = ctrlinfo

	save_data()
	LOG_DEBUG("player_start_ctrl, uid[%s]", tostring(uid))				
	send_to_game("player_start_ctrl", uid, ctrlinfo)
end

function CMD.player_stop_ctrl(...)
--	LOG_WARNING("player_stop_ctrl")
	userdata.ctrltype = nil
	userdata.ctrlrate = nil
	userdata.ctrlmaxgold = nil
	userdata.ctrlnowgold = nil
	userdata.ctrlstarttime = nil
	userdata.ctrloverttime = nil
	userdata.ctrllevel = nil
	userdata.ctrlcount = nil
	player.ctrlinfo = nil
	save_data()
	send_to_game("player_stop_ctrl", uid)
	-- if gamenode and gameaddr then
	-- 	local ok, result = pcall(cluster.call, gamenode, gameaddr, "player_stop_ctrl", uid)
	-- 	if not ok then
	-- 		LOG_DEBUG("notify game player_stop_ctrl faild: "..tostring(result))
	-- 		return
	-- 	end
	-- end
end


function CMD.ctrl_gold_changed(gold)
--	LOG_WARNING("ctrl_gold_changed")
	if userdata.ctrltype and player.ctrlinfo then
		userdata.ctrlnowgold = gold
		player.ctrlinfo.ctrlnowgold = gold
		save_data()
	end
end

function CMD.query_player_info( ... )
	return player
end



return this