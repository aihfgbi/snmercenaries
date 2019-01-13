local skynet = require "skynet"
local cluster = require "skynet.cluster"
local crypt = require "skynet.crypt"
local mysql = require "skynet.db.mysql"
local json = require "cjson"
local sharedata = require "skynet.sharedata"
local centerbank = skynet.getenv("use_center_bank")
local use_debug = skynet.getenv("use_debug")
rankname = skynet.getenv("rank_list_name")

-- local _cfgShop 配置表为全局的
-- local _cfgGoods

local base64encode = crypt.base64encode
local base64decode = crypt.base64decode

local CMD = {}
local api = {}

online = false
local agnode
local agaddr
local manager
local gmmanager
local gamenode  --玩家所在游戏的node
local gameaddr  --玩家所在游戏的addr

local _userdata
local _uid

local TIMEOUT = 3 * 60 --5*60  --离线5分钟之后销毁userdata  单位：秒
local TIMESLICE = 5 --5   --轮询时间 单位：秒
local AUTOTIME = 30 --60	  --如果数据由变化，默认一分钟后存储,除非是充值数据，不然其他数据均可以一分钟存储一次 单位：秒
local SAVE_CNT = math.ceil(AUTOTIME / TIMESLICE)
local KILL_CNT = math.ceil(TIMEOUT / TIMESLICE)

local _need_save = false
local _not_save_cnt = 0
local _offline_cnt = 0
local _nodename
local _redis
local _logredis
local _logname = skynet.getenv("logname")
local _p

local string = string

local logic

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
--请求刷新的类型，0所有信息，1金币 2绑定信息 3自定义签名 4等级和经验 5头像 6已充值金额
userdataFlag = {
	gold = 2,--gold bank
	bind = 3,--phone alipayacc alipayrealname bankacc bankrealname
	signature = 4,--signature
	level = 5,--level vipexp
	headimg = 6,--headimg
	charged = 7 --charged
}
--全局变量

local function log(type, content)
	-- LOG_DEBUG(tostring(_uid)..","..tostring(type)..","..tostring(content))
	local log = string.format('{"type":"%s","uid":%d,"time":%d,"data":%s}', type, _uid, os.time(), content)
	-- LOG_DEBUG("[log]"..log)
	if _logname and #_logname > 0 then
		local ok, result = pcall(skynet.send, _logredis, "lua", "execute", "LPUSH", _logname, log)
		if not ok then
			LOG_ERROR("error：写入日志失败:" .. tostring(result))
		end
	end
end

local function decode_userdata(data)
	return json.decode(data)
 --skynet.unpack(data)
end

local function encode_userdata(info)
	json.encode_sparse_array(true)
	return json.encode(info)
 --skynet.packstring(info)
end

local function get_gm_manager()
	if not gmmanager then
		local ok, addr = pcall(cluster.query, "gmctrl", "userctrl")
		if ok and addr then
			gmmanager = addr
		end
	end
	return gmmanager
end

local function get_new_user(nn)
	-- 新用户
	-- LOG_DEBUG("新用户:" .. tostring(_uid))
	-- local ok, data = pcall(skynet.call, _redis, "lua", "execute", "get", "user:" .. tostring(_uid))
	-- if not ok or not data then
	-- 	if use_debug == "0" or nn then
	-- 		return {
	-- 			gold = 5000,
	-- 			money = 10000,
	-- 			bank = 0,
	-- 			nickname = nn or "用户" .. tostring(_uid),
	-- 			exp = 0,
	-- 			vipexp = 0,
	-- 			sex = 1,
	-- 			headimg = "",
	-- 			usermsg = ""
	-- 		}
	-- 	else
	-- 		return
	-- 	end
	-- end
	-- local ok, info = pcall(json.decode, data)
	-- if not ok or not info then
	-- 	if use_debug == "0" or nn then
	-- 		return {
	-- 			gold = 5000,
	-- 			money = 10000,
	-- 			bank = 0,
	-- 			nickname = nn or "用户" .. tostring(_uid),
	-- 			exp = 0,
	-- 			vipexp = 0,
	-- 			sex = 1,
	-- 			headimg = "",
	-- 			usermsg = ""
	-- 		}
	-- 	else
	-- 		return
	-- 	end
	-- end
	-- if info.nickname and #info.nickname > 0 then
	-- 	info.nickname = base64decode(info.nickname)
	-- end
	-- -- LOG_DEBUG(data)
	-- info.gender = math.floor(tonumber(info.gender or 1) or 1)
	-- info.avatar = tostring(info.avatar) or ""
	-- if info.avatar == "userdata: (nil)" or info.avatar == "userdata:(nil)" or info.avatar == "nil" then
	-- 	info.avatar = ""
	-- end
	-- -- luadump(info)
	-- return {
	-- 	gold = 5000,
	-- 	money = 10000,
	-- 	bank = 0,
	-- 	nickname = info.nickname or "用户" .. tostring(_uid),
	-- 	exp = 0,
	-- 	vipexp = 0,
	-- 	sex = info.gender,
	-- 	headimg = info.avatar,
	-- 	usermsg = ""
	-- }
end

local function insert_new_user()
	-- LOG_DEBUG("insert user into mysql:" .. _uid)
	-- local d = get_new_user()
	-- if not d then
	-- 	return
	-- end
	-- local sql =
	-- 	"INSERT INTO tbl_user_info_" ..
	-- 	(_uid % 10) ..
	-- 		"(UserID,GameID,NickName,OwnCash,BankCash,Diamond,UserType,UserInfo1,UserInfo2,UserInfo3)" ..
	-- 			" VALUES(" .. _uid .. "," .. _uid .. ",'" .. d.nickname .. "',0,0,0,1,NULL,NULL,NULL)"

	--for i=1,3 do
	--	local ok,t = pcall(skynet.call, ".mysqlpool", "lua", "execute", sql)
	--	if ok then
	--		-- luadump(t)
	--		break
	--	end
	--end

	-- return d
end

local function load_userdata()
	if not _uid then
		return false
	end
	for i = 1, 3 do
		-- 用获取的uid获取用户信息
		local userinfo,bankinfo,ok,data
		ok, data = pcall(skynet.call, _redis, "lua", "execute", "hget", "USER-INFO", _uid)
		if ok then
			-- 转换用户数据
			ok, userinfo = pcall(json.decode, data)
			if ok then
				_userdata = userinfo
				_userdata.id = math.floor(userinfo.id)
				_userdata.userType = math.floor(userinfo.userType)
				_userdata.sex = math.floor(userinfo.sex)
				-- 获取用户金币和银行信息
				ok, data = pcall(skynet.call, _redis, "lua", "execute", "hget", "USER-ACCOUNT_INFO", _uid .. "#1001")
				if ok then
					-- 转换用户金币数据
					ok, bankinfo = pcall(json.decode, data)
					if ok then
						_userdata.gold = math.floor( bankinfo.aNum )
						_userdata.bank = math.floor( bankinfo.aBank )
						_userdata.bankpwd = bankinfo.aPassword
					else
						_userdata.gold = 0
						_userdata.bank = 0
						_userdata.bankpwd = "0"
					end
					luadump(_userdata, "用户信息==")
					break
				end
				luadump(_userdata, "用户信息==")
			end
		end
	end

	if _userdata then
		return true
	end

	return false
end

local function save_userdata()
	if not _uid then
		return
	end
	-- LOG_DEBUG("check save user data:".._uid..",_need_save="..tostring(_need_save))
	if _need_save then
		local err1 = true
		local err2 = true
		local ok, data = pcall(encode_userdata, _userdata)
		if not ok then
			LOG_ERROR("save data error uid:" .. _uid .. ",reason:" .. tostring(data))
			return
		end

		-- local group = _userdata.group
		-- _userdata.group = nil
		-- data1 = encode_userdata(_userdata)
		-- data2 = encode_userdata(group)
		-- _userdata.group = group
		for i = 1, 3 do
			-- 尝试三次
			local ok, result = pcall(skynet.call, _redis, "lua", "execute", "set", "userdata->" .. tostring(_uid), data)
			if ok and result then
				-- return
				-- LOG_DEBUG("save user data into redis now:".._uid..", data size:"..#data)
				err1 = false
				break
			else
				LOG_ERROR("save user data to redis error " .. i .. ":" .. _uid)
			end
		end

		--[[data1 = mysql.quote_sql_str(data1)
		data2 = mysql.quote_sql_str(data2)
		local sql = "UPDATE tbl_user_info_"..(_uid%10).." SET NickName='"..
		_userdata.nickname.."',BankCash=".. _userdata.bank ..",UserInfo1="..data1..",UserInfo2="..data2.." where UserID = ".._uid
		if #data1 > 30 *1024 then
			LOG_ERROR("error:用户数据1太大了:".._uid..":"..#data1)
		end
		if #data2 > 30 *1024 then
			LOG_ERROR("error:用户数据2太大了:".._uid..":"..#data2)
		end
		for i=1,3 do
			-- 尝试三次
			local ok,t = pcall(skynet.call, ".mysqlpool", "lua", "execute", sql)
			if ok then
				if t and t.error then
					LOG_ERROR("save user data to mysql error "..i..":".._uid)
					luadump(t)
				else
					LOG_DEBUG("save user data into mysql now:".._uid..", data1 size:"..#data1..", data2 size:"..#data2)
					err2 = false
				end
				break
			else
				LOG_ERROR("save user data to mysql error "..i..":".._uid)
			end
		end

		_need_save = false
		_not_save_cnt = 0
		]]
		err2 = false
		if err1 or err2 then
			LOG_ERROR("save userdata error:" .. _uid)
			luadump(_userdata)
			local ok, info = pcall(json.encode, _userdata)
			if ok then
				log("save_data_error", '{"info":"' .. tostring(info) .. '""}')
			else
				LOG_ERROR("userdata encode to json error:" .. tostring(info))
			end
		end
	end
end

local _last_time
local function time_timer()
	while true do
		skynet.sleep(TIMESLICE * 100)
		_not_save_cnt = _not_save_cnt + 1
		if _need_save and _not_save_cnt >= SAVE_CNT then
			save_userdata()
		end

		if not online then
			_offline_cnt = _offline_cnt + 1
			if _offline_cnt >= KILL_CNT and not logic.check_in_game() then
				-- 如果在游戏中，不能离线
				if _uid then
					save_userdata()
					LOG_DEBUG("need exit userdata:" .. _uid)
					pcall(skynet.call, manager, "lua", "unforward", _uid)
					if logic and logic.destroy then
						logic.destroy()
					end
				end
				skynet.exit()
			end
		end

		local now = os.date("%Y%m%d")
		if _last_time ~= now then
			if logic then
				logic.nextDay()
			end
		end
		_last_time = now
	end
end

local function send_to_client(name, msg)
	if not online then
		return
	end
	local ok, result = pcall(cluster.send, agnode, agaddr, "send_to_client", _uid, name, msg)
	if not ok then
	LOG_DEBUG("agent离线")
	end
end

local function get_bank_data()
	local ok, value = pcall(skynet.call, manager, "lua", "query_bank", _uid)
	if ok and value then
		LOG_DEBUG(_uid .. ",bank=" .. value)
		CMD.set_bank(_uid, value, 1001)
	end
end

local function update_client_info(...)
	if not _uid then
		return
	end
	if not online then
		return
	end
	local keys = {...}
	local msg = {uid = _uid}
	local type = 0
	for _, k in pairs(keys) do
		if k == "gold" then
			msg[k] = _userdata[k] or 0
			msg["bank"] = _userdata["bank"] or 0
		elseif k == "bind" then--phone alipayacc alipayrealname bankacc bankrealname
		elseif k == "level" then--level vipexp
		elseif _userdata[k] then
			msg[k] = _userdata[k]
		end
		if userdataFlag[k] then
			type = userdataFlag[k]
		end
	end

	msg.type = type
	send_to_client("hall.resRefreshInfo", msg)
end

local function send_to_gmctrl(cmd, ...)
	get_gm_manager()
	if gmmanager then
		local ok, result = pcall(cluster.call, "gmctrl", gmmanager, cmd, ...)
		if not ok then
			LOG_ERROR("call gmctrl [%s] faild : %s", tostring(cmd), tostring(result))
			gmmanager = nil
		end
	end
end

local function task_add_friend(uid, tType, target, cnt)
	--	LOG_WARNING("task_add_friend uid[%d]", uid)
	if uid ~= _uid then
		LOG_WARNING("uid[%s] not match _uid[%d]", tostring(uid), _uid)
		return
	end

	if tType ~= "add_friend" then
		LOG_WARNING("type[%s] not add_friend task", tostring(tType))
		return
	end
	if not _userdata.parentuid then
		LOG_WARNING("no puid")
		return
	end
	api.call_manager("task_add_friend", _userdata.parentuid, tType, target, cnt, uid)
end

function CMD.start(mgr, nodename)
	-- LOG_DEBUG("user data start:"..uid)
	manager = mgr
	_nodename = nodename
	_last_time = os.date("%Y%m%d")
	skynet.fork(time_timer)
end

function CMD.online(uid, node, addr)
	LOG_DEBUG("user data online:" .. uid)
	if online and agnode and agaddr then
		LOG_DEBUG(agnode .. "," .. agaddr)
		pcall(cluster.call, agnode, agaddr, "kick", 7)
	end
	online = true
	agnode = node
	agaddr = addr
	_uid = uid

	if not _userdata then
		if not load_userdata() then
			LOG_ERROR("load userdata error:" .. tostring(uid))
			return false
		end
	end

	_p = {
		uid = _uid,
		agnode = agnode,
		agaddr = agaddr,
		datnode = _nodename,
		dataddr = skynet.self(),
		nickname = _userdata.nickName,
		gold = _userdata.gold,
		headimg = _userdata.headImg,
		money = 0,
		sex = _userdata.sex or 1,
		bank = _userdata.bank,
		ip = _userdata.lastIp or "",
	}

	if _userdata.ctrltype then
		_p.ctrlinfo = {
			ctrltype = _userdata.ctrltype,
			ctrlrate = _userdata.ctrlrate,
			ctrlmaxgold = _userdata.ctrlmaxgold,
			ctrlnowgold = _userdata.ctrlnowgold or 0,
			ctrlstarttime = _userdata.ctrlstarttime,
			ctrloverttime = _userdata.ctrloverttime,
			ctrllevel = _userdata.ctrllevel,
			ctrlcount = _userdata.ctrlcount,
			ctrlcaijin = _userdata.ctrlcaijin
		}
	end

	for key, f in pairs(CMD) do
		if not api[key] then
			api[key] = f
		end
	end

	api.log = log
	api.update_client_info = update_client_info

	logic.init(uid, api, _userdata, _p, _redis, _logredis) --调用了datalogic里面的init，传递了用户数据等参数，然后把CMD里面的函数全部复制给api发了过去

	log(
		"online",
		string.format(
			'{"gold":%d,"bank":%d,"did":"-","ip":"%s","location":"-","client":"-","os":"-"}',
			_userdata.gold or 0,
			_userdata.bank or 0,
			ip or "-"
		)
	)
	if _userdata.gm then
		send_to_gmctrl("gm_online", _p)
	else
		--向gmctrl服中注册
		send_to_gmctrl("user_online", _p)
	end

	if centerbank then
		LOG_DEBUG("get_bank_data")
		skynet.fork(get_bank_data)
	end

	onlinetime = os.date("%Y-%m-%d %X")

	if online and not _userdata.gm then
		pcall(
			skynet.send,
			_logredis,
			"lua",
			"execute",
			"HSET",
			"user_map",
			_uid,
			string.format(
				'{"uid":%d,"gold":%d,"bank":"%s","charged":"%s","channel":0,"gameid":%d,"onlinetime":"%s","jointime":"%s","nickname":"%s"}',
				_uid,
				_userdata.gold,
				_userdata.bank,
				_userdata.charged,
				0,
				onlinetime or 0,
				"0",
				_userdata.nickName
			)
		)
	end
	LOG_DEBUG("用户上线成功")
	return true
end

function CMD.offline_use(uid)
	LOG_DEBUG("user data offline use:" .. uid)
	_uid = uid
	if not _userdata then
		if not load_userdata() then
			LOG_ERROR("load userdata error:" .. tostring(uid))
			return false
		end
	end

	logic.init(
		uid,
		api,
		_userdata,
		{
			uid = _uid,
			agnode = agnode,
			agaddr = agaddr,
			datnode = _nodename,
			dataddr = skynet.self(),
			nickname = _userdata.nickName,
			headimg = _userdata.headimg
		},
		_redis
	)

	return true
end

-- 由agent或者manager直接调用的，不允许其他服务调用
function CMD.offline(reason)
	LOG_DEBUG("user data offline:" .. _uid .. ",reason:" .. tostring(reason))
	online = false
	logic.offline(reason)
	log(
		"offline",
		string.format('{"gold":%d,"money":%d,"bank":%d}', _userdata.gold or 0, _userdata.money or 0, _userdata.bank or 0)
	)
	-- skynet.call(manager, "kick", _uid)
	-- save_userdata()
	if _userdata.gm then
		send_to_gmctrl("gm_offline", _uid)
	else
		send_to_gmctrl("user_offline", _uid)
	end

	-- HDEL key field1 [field2]
	if not _userdata.gm then
		pcall(skynet.send, _logredis, "lua", "execute", "HDEL", "user_map", _uid)
	end
end

function CMD.client_req(uid, name, msg)
	if uid ~= _uid then
		return
	end
	local f = logic[name]
	if not f then
		LOG_DEBUG("datalogic 上面缺少接口:" .. tostring(name))
		return
	end

	return f(msg)
end

function CMD.bind_parent(uid, child)
	if not _userdata then
		return
	end
	if uid == child then
		return
	end
	if uid ~= _uid then
		return
	end
	_userdata.group = _userdata.group or {}
	if not _userdata.group.child then
		_userdata.group.child = {}
		_userdata.group.child.time = os.time()
	end
	_userdata.group.oldchild = _userdata.group.oldchild or {}
	if not _userdata.group.child[child] and not _userdata.group.oldchild[child] then
		-- 本周列表和过往列表中都没有这个用户的时候才可以
		_userdata.group.child[child] = 0
		_need_save = true
		return true
	end
end

function CMD.gm_req(uid, name, msg)
	if _userdata.gm then
		get_gm_manager()
		if gmmanager then
			local ok, rename, remsg = pcall(cluster.call, "gmctrl", gmmanager, "dispatch", uid, name, msg)
			if not ok then
				LOG_ERROR("call gmctrl [%s] faild : %s", tostring(cmd), tostring(result))
				gmmanager = nil
			else
				return rename, remsg
			end
		end
	end
end

-- 1000  玩家充值
-- 1001  开房消耗
-- 1002  发动态表情消耗
-- 1003  房间没开起来的返还
-- 1004  GM操作
-- 1005  商城购买消耗
-- 1006	 商城购买额外赠送
-- 1007  参加比赛消耗
-- 1008  首充礼包
function CMD.sub_money(uid, money, reason)
	if uid ~= _uid then
		return false
	end
	if not reason then
		return false
	end
	if not _userdata then
		return false
	end
	money = tonumber(money)
	if not money then
		return false
	end
	money = math.floor(money)
	if money < 0 then
		return false
	end
	if _userdata.money < money then
		return false
	end
	_userdata.money = _userdata.money - money
	log(
		"sub_money",
		string.format('{"gold":%d,"money":%d,"value":%d,"reason":%d}', _userdata.gold or 0, _userdata.money, money, reason)
	)
	_need_save = true
	update_client_info("money")
	return true
end

function CMD.add_money(uid, money, reason)
	LOG_DEBUG("add_money..." .. tostring(uid) .. "," .. tostring(money) .. "," .. tostring(reason))
	-- LOG_DEBUG(uid, money, reason)
	if uid ~= _uid then
		return false
	end
	if not reason then
		return false
	end
	if not _userdata then
		return false
	end
	money = tonumber(money)
	if not money then
		return false
	end
	money = math.floor(money)
	if money < 0 then
		return false
	end
	_userdata.money = _userdata.money + money
	log(
		"add_money",
		string.format('{"gold":%d,"money":%d,"value":%d,"reason":%d}', _userdata.gold or 0, _userdata.money, money, reason)
	)
	_need_save = true
	update_client_info("money")
	return true
end

function CMD.sub_hongbao(uid, value, reason)
	if uid ~= _uid then
		return false
	end
	return api.sub_hongbao(value, reason)
end

function CMD.charge(uid, count, channel, order)
	local ok = CMD.add_money(uid, count * 100, 1000)
	if not _userdata.charged or _userdata.charged < 1 then
		-- end
		-- 首充礼包
		_userdata.charged = (_userdata.charged or 0) + count
		-- if count == 5 then
		CMD.add_money(uid, 100, 1008)
		CMD.add_gold(uid, 20000, 108)
		update_client_info("charged")
	else
		_userdata.charged = (_userdata.charged or 0) + count
	end

	if ok then
		log(
			"charge",
			string.format(
				'{"gold":%d,"money":"%s","type":"%s","value":"%s","orderid":"%s","did":"-","ip":"-","location":"-","client":"-","os":"-"}',
				_userdata.gold or 0,
				_userdata.money or 0,
				channel,
				count,
				order
			)
		)
		send_to_client("user.ChargeNtf", {rmb = count * 100, count = count * 100})
	else
		LOG_ERROR("用户充值入账失败:" .. uid .. "," .. _uid .. "," .. count)
	end
	return ok
end

-- 银行转账收入
function CMD.transfer_bank(uid, value, fromuid)
	if CMD.add_bank(uid, value, 1004) then
		-- send_to_client
		_userdata.safenotify = 1
		send_to_client(logic.SafeStatusRep())
		return true, _userdata.nickname
	end
end

-- 1001	用户刚刚登录，初始化银行设定的值
-- 1002 APP那边改变了
function CMD.set_bank(uid, value, reason)
	if uid ~= _uid then
		return false
	end
	if not reason then
		return false
	end
	if not _userdata then
		return false
	end
	value = tonumber(value)
	if not value then
		return false
	end
	value = math.floor(value)
	if value < 0 then
		return false
	end
	_userdata.bank = value
	log(
		"set_bank",
		string.format(
			'{"gold":%d,"money":%d,"value":%d,"reason":%d,"bank":%d}',
			_userdata.gold or 0,
			_userdata.money or 0,
			value,
			reason,
			_userdata.bank
		)
	)
	_need_save = true
	update_client_info("bank")
	send_to_gmctrl("set_bank", uid, _userdata.bank, reason)
	return _userdata.bank
end

function CMD.init_bank(uid, value)
	if uid ~= _uid then
		return false
	end
	if not _userdata then
		return false
	end
	bank_inited = true
	LOG_DEBUG("init_bank:" .. uid .. "," .. value)
	return CMD.set_bank(uid, value, 1001)
end

-- 1001银行存钱
-- 1002银行取钱
-- 1003银行转出/赠送
-- 1004银行转入/获赠
-- 1005转账失败退回的钱
function CMD.add_bank(uid, value, reason)
	if uid ~= _uid then
		return false
	end
	if not reason then
		return false
	end
	if not _userdata then
		return false
	end
	value = tonumber(value)
	if not value then
		return false
	end
	value = math.floor(value)
	if value < 0 then
		return false
	end

	if centerbank then
		local ok, value = pcall(skynet.call, manager, "lua", "add_bank", uid, value)
		if not ok or not value then
			return
		end
		value = tonumber(value)
		if not value then
			return
		end
		value = math.floor(value)
		_userdata.bank = value
	else
		_userdata.bank = _userdata.bank or 0
		_userdata.bank = _userdata.bank + value
	end
	LOG_DEBUG(uid .. "增加银行：" .. value .. ",增加之后金币数额:" .. _userdata.bank)

	log(
		"add_bank",
		string.format(
			'{"gold":%d,"money":%d,"value":%d,"reason":%d,"bank":%d}',
			_userdata.gold or 0,
			_userdata.money or 0,
			value,
			reason,
			_userdata.bank
		)
	)
	_need_save = true
	update_client_info("bank")
	send_to_gmctrl("set_bank", uid, _userdata.bank, reason)
	return _userdata.bank
end

function CMD.sub_bank(uid, value, reason)
	if uid ~= _uid then
		return false
	end
	if not reason then
		return false
	end
	if not _userdata then
		return false
	end
	value = tonumber(value)
	if not value then
		return false
	end
	value = math.floor(value)
	if value < 0 then
		return false
	end

	if centerbank then
		local ok, value = pcall(skynet.call, manager, "lua", "sub_bank", uid, value)
		if not ok or not value then
			return
		end
		value = tonumber(value)
		if not value then
			return
		end
		value = math.floor(value)
		_userdata.bank = value
	else
		_userdata.bank = _userdata.bank or 0
		if _userdata.bank < value then
			return false
		end
		_userdata.bank = _userdata.bank - value
	end

	log(
		"sub_bank",
		string.format(
			'{"gold":%d,"money":%d,"value":%d,"reason":%d,"bank":%d}',
			_userdata.gold or 0,
			_userdata.money or 0,
			value,
			reason,
			_userdata.bank
		)
	)
	_need_save = true
	update_client_info("bank")
	send_to_gmctrl("set_bank", uid, _userdata.bank, reason)
	return _userdata.bank
end

function CMD.sub_gold(uid, gold, reason)
	if uid ~= _uid then
		return false
	end
	if not reason then
		return false
	end
	if not _userdata then
		return false
	end
	gold = tonumber(gold)
	if not gold then
		return false
	end
	gold = math.floor(gold)
	if gold < 0 then
		return false
	end
	if _userdata.gold < gold then
		return false
	end
	_userdata.gold = _userdata.gold - gold
	log(
		"sub_gold",
		string.format('{"gold":%d,"value":%d,"reason":%d}', _userdata.gold or 0, gold, reason)
	)
	_need_save = true
	if _p then
		_p.gold = _userdata.gold
	end
	update_client_info("gold")
	--金币变化需要通知到gm服务
	send_to_gmctrl("gold_change", _uid, 0 - gold, reason)
	luadump(_userdata,"====")
	local nn = _userdata.nickname
	pcall(skynet.call, _redis, "lua", "execute", "ZADD", rankname .. "3", _userdata.gold, _uid .. ":" .. nn)
	return _userdata.gold
end

-- 101 签到奖励
-- 102 GM操作
-- 103 商城购买操作
-- 104 商城购买额外赠送
-- 105 参加比赛消耗
-- 106 存钱到银行消耗金币
-- 107 从银行取钱增加金币
-- 108 首充奖励
-- 109 存钱失败，返还金币
-- 1000以上表示游戏内的结算，reason就表示gameid
function CMD.add_gold(uid, gold, reason)
	if uid ~= _uid then
		return false
	end
	if not reason then
		return false
	end
	if not _userdata then
		return false
	end
	gold = tonumber(gold)
	if not gold then
		return false
	end
	gold = math.floor(gold)
	if gold < 0 then
		return false
	end
	_userdata.gold = _userdata.gold + gold
	LOG_DEBUG(uid .. "增加金币：" .. gold .. ",增加之后金币数额:" .. _userdata.gold)
	log(
		"add_gold",
		string.format('{"gold":%d,"value":%d,"reason":%d}', _userdata.gold or 0, gold, reason)
	)
	_need_save = true
	if _p then
		_p.gold = _userdata.gold
	end
	update_client_info("gold")
	--金币变化需要通知到gm服务
	send_to_gmctrl("gold_change", _uid, gold, reason)
	luadump(_userdata,"====")
	local nn = _userdata.nickname
	pcall(skynet.call, _redis, "lua", "execute", "ZADD", rankname .. "3", _userdata.gold, _uid .. ":" .. nn)
	return _userdata.gold
end

-- 1001 游戏正常获胜
-- 1002 GM
function CMD.add_win(uid, gameid, reason)
	if uid ~= _uid then
		return false
	end
	if not gameid then
		return false
	end
	if not _userdata then
		return false
	end
	if not reason then
		return false
	end
	_userdata.wincount = _userdata.wincount or 0
	_userdata.wincount = _userdata.wincount + 1

	_userdata.totalwincount = _userdata.totalwincount or 0
	_userdata.totalwincount = _userdata.totalwincount + 1

	log(
		"add_win",
		string.format(
			'{"gold":%d,"money":%d,"gameid":%d,"wincount":%d}',
			_userdata.gold or 0,
			_userdata.money or 0,
			gameid,
			_userdata.wincount
		)
	)
	_need_save = true
	update_client_info("wincount")

	if _userdata.totalwincount >= 10 and _userdata.group and _userdata.group.parent and _userdata.binding then
		-- 任务达成，通知上级
		if not _userdata.reportparent then
			LOG_DEBUG(_uid .. " 有上级，达成胜利10局的条件，通知上级:" .. _userdata.group.parent)
			_userdata.reportparent = true
			api.call_manager("add_done_child", _userdata.group.parent, _uid)
			_need_save = true
		end
	end

	return _userdata.wincount
end

-- 增加一个完成任务的下级
function CMD.add_done_child(uid, child)
	if _uid ~= uid then
		return
	end
	if not child then
		return
	end
	if uid == child then
		return
	end
	if not _userdata then
		return
	end
	if not _userdata.group or not _userdata.group.child then
		return
	end
	if not _userdata.group.child[child] then
		return
	end

	_userdata.group.child[child] = 1
	LOG_DEBUG(uid .. "下级完成任务，更新任务数据,下级是:" .. child)

	if logic then
		logic.check_task("add_friend", nil, 1)
	end
end

function CMD.gm_cmd(uid, cmd, ...)
	if uid ~= _uid then
		return false
	end
	if not _userdata then
		return false
	end
	if cmd == "add_hongbao" then
		local v = {...}
		v = v[1]
		return api.add_hongbao(v, 1002)
	elseif cmd == "sub_hongbao" then
		local v = {...}
		v = v[1]
		return api.sub_hongbao(v, 1002)
	elseif cmd == "set_hongbao" then
	elseif cmd == "set_win" then
		local v = {...}
		v = v[1]
		v = tonumber(v)
		if not v then
			return
		end
		if v < 0 then
			return
		end
		v = math.floor(v)
		local before = _userdata.wincount or 0
		_userdata.wincount = v
		_need_save = true
		log(
			"gm_set_win",
			string.format(
				'{"gold":%d,"money":%d,"before":%d,"after":%d}',
				_userdata.gold or 0,
				_userdata.money or 0,
				before,
				_userdata.wincount
			)
		)
		update_client_info("wincount")
		return _userdata.wincount
	elseif cmd == "set_gold" then
		-- local v = {...}
		-- v = v[1]
		-- return
	elseif cmd == "add_gold" then
		local v = {...}
		v = v[1]
		return CMD.add_gold(uid, v, 102)
	elseif cmd == "sub_gold" then
		local v = {...}
		v = v[1]
		return CMD.sub_gold(uid, v, 102)
	elseif cmd == "set_money" then
		-- local v = {...}
		-- v = v[1]
		-- return
	elseif cmd == "add_money" then
		local v = {...}
		v = v[1]
		return CMD.add_money(uid, v, 1004)
	elseif cmd == "sub_money" then
		local v = {...}
		v = v[1]
		return CMD.sub_money(uid, v, 1004)
	end
end

-- function CMD.add_hongbao(uid, value, reason)
-- 	if uid ~= _uid then return false end
-- 	return api.add_hongbao(value, reason)
-- end

-- function CMD.sub_hongbao(uid, value, reason)
-- 	if uid ~= _uid then return false end
-- 	return api.sub_hongbao(value, reason)
-- end

function CMD.get_json()
	-- luadump(_userdata)
	-- 需要过滤一些转换会失败的数据
	-- 任务
	local task = _userdata.task
	local group = _userdata.group
	local buycounts = _userdata.buycounts
	_userdata.task = nil
	_userdata.group = nil
	_userdata.buycounts = nil
	local info = json.encode(_userdata)
	_userdata.task = task
	_userdata.group = group
	_userdata.buycounts = buycounts
	return info
end

-- function CMD.check_task(uid, type, target, cnt)
-- 	if uid ~= _uid then return end
-- 	logic.check_task(type, target, cnt)
-- en

-- 1001  红包胜利场兑换获得
-- 1002  GM
-- 1003  参加比赛消耗
-- 1004  首次绑定获得红包
-- 1005  邀请好友任务奖励
-- 1006  购买实物道具消耗
function api.add_hongbao(value, reason)
	if not _userdata then
		return false
	end
	if not reason then
		return false
	end
	value = tonumber(value)
	if not value then
		return false
	end
	if value < 0 then
		return false
	end
	value = math.floor(value)
	_userdata.hongbao = _userdata.hongbao or 0
	_userdata.hongbao = _userdata.hongbao + value
	_userdata.totalhongbao = _userdata.totalhongbao or 0
	_userdata.totalhongbao = _userdata.totalhongbao + value
	if _p then
		_p.hongbao = _userdata.hongbao
		_p.totalhongbao = _userdata.totalhongbao
	end
	_need_save = true
	log(
		"add_hongbao",
		string.format(
			'{"gold":%d,"money":%d,"add":%d,"total":%d,"reason":%d}',
			_userdata.gold or 0,
			_userdata.money or 0,
			value,
			_userdata.hongbao,
			reason
		)
	)
	update_client_info("hongbao")
	--红包变化需要通知到gm服务
	send_to_gmctrl("hongbao_change", _uid, _userdata.hongbao, _userdata.totalhongbao or 0)

	local nn = base64encode(_userdata.nickname)
	pcall(skynet.call, _redis, "lua", "execute", "ZINCRBY", rankname .. "1", value, _uid .. ":" .. nn)
	pcall(skynet.call, _redis, "lua", "execute", "ZINCRBY", rankname .. "2", value, _uid .. ":" .. nn)
	return _userdata.hongbao
end

function api.sub_hongbao(value, reason)
	if not _userdata then
		return false
	end
	if not reason then
		return false
	end
	value = tonumber(value)
	if not value then
		return false
	end
	if value < 0 then
		return false
	end
	value = math.floor(value)
	if not _userdata.hongbao or _userdata.hongbao < value then
		return false
	end
	_userdata.hongbao = _userdata.hongbao - value
	if _p then
		_p.hongbao = _userdata.hongbao
	end
	_need_save = true
	log(
		"sub_hongbao",
		string.format(
			'{"gold":%d,"money":%d,"sub":%d,"total":%d,"reason":%d}',
			_userdata.gold or 0,
			_userdata.money or 0,
			value,
			_userdata.hongbao,
			reason
		)
	)
	update_client_info("hongbao")
	--红包变化需要通知到gm服务
	send_to_gmctrl("hongbao_change", _uid, _userdata.hongbao, _userdata.totalhongbao or 0)
	return _userdata.hongbao
end

function api.add_buy_count(shopid, count)
	if not shopid or not count then
		return
	end
	count = tonumber(count)
	if not count or count < 1 then
		return
	end
	count = math.floor(count)
	_userdata.buycounts = _userdata.buycounts or {}
	_userdata.buycounts[shopid] = _userdata.buycounts[shopid] or 0
	_userdata.buycounts[shopid] = _userdata.buycounts[shopid] + count
	_need_save = false
end

function api.send_msg(name, msg)
	send_to_client(name, msg)
end
function api.save_data()
	_need_save = true
end

function api.save_data_imm()
	_need_save = true
	save_userdata()
end

function api.load_userdata(uid)
	if not uid then
		return false
	end
	for i = 1, 3 do
		-- 尝试三次
		local ok, data = pcall(skynet.call, _redis, "lua", "execute", "hget", "USER-INFO" , tostring(uid))
		if ok then
			if data then
				local info = json.decode(data)
				-- 获取用户金币和银行信息
				ok, data = pcall(skynet.call, _redis, "lua", "execute", "hget", "USER-ACCOUNT_INFO", uid .. "#1001")
				if ok then
					-- 转换用户金币数据
					if data then
						-- body
						local goldinfo = json.decode(data)
						info.gold = math.floor( goldinfo.aNum )
						info.bank = math.floor( goldinfo.aBank )
						info.bankpwd = goldinfo.aPassword
					else
						info.gold = 0
						info.bank = 0
						info.bankpwd = "0"
					end
				end
				return info
			end
		else
			LOG_DEBUG("load userdata error:" .. tostring(data))
		end
	end
end

function api.add_bank(value, reason)
	return CMD.add_bank(_uid, value, reason)
end

function api.sub_bank(value, reason)
	return CMD.sub_bank(_uid, value, reason)
end

function api.add_gold(gold, reason)
	return CMD.add_gold(_uid, gold, reason)
end

function api.sub_gold(gold, reason)
	return CMD.sub_gold(_uid, gold, reason)
end

function api.add_money(gold, reason)
	return CMD.add_money(_uid, gold, reason)
end

function api.sub_money(gold, reason)
	return CMD.sub_money(_uid, gold, reason)
end

function api.call_manager(func, ...)
	return skynet.call(manager, "lua", func, ...)
end

function api.join_game(node, addr)
	local ok, result = pcall(cluster.call, agnode, agaddr, "join_game", node, addr)
	if not ok then
		LOG_DEBUG("join_game失败！！！！" .. tostring(result))
		return
	end
	gamenode = node
	gameaddr = addr
end

function api.leave_game()
	local ok, result = pcall(cluster.call, agnode, agaddr, "leave_game")
	if not _userdata.gm then
		send_to_gmctrl("user_leavegame", _uid)
	end
	gamenode = nil
	gameaddr = nil
end

skynet.start(
	function()
		-- for fname,f in pairs(logic.CMD) do
		-- 	if CMD[fname] then
		-- 		assert(nil, "datalogic.lua中,CMD表,有不合法的函数名:"..fname)
		-- 	end
		-- 	CMD[fname] = f
		-- end

		skynet.dispatch(
			"lua",
			function(session, source, command, uid, ...)
				local f = CMD[command]

				if f then
					skynet.ret(skynet.pack(f(uid, ...)))
					return
				else
					f = logic.CMD[command]
					if f and uid == _uid then
						skynet.ret(skynet.pack(f(...)))
						return
					end
				end
				LOG_ERROR("call userdata method error :" .. tostring(command))
				skynet.ret(skynet.pack(nil))
			end
		)

		_redis = skynet.uniqueservice("redispool")
		_logredis = skynet.uniqueservice("logredispool")

		_cfgGoods = sharedata.query "goods_conf"
		_cfgShop = sharedata.query "shop_conf"
		_cfgData = sharedata.query "data_conf"
		_cfgTask = sharedata.query "task_conf"
		logic = require("datalogic")

		collectgarbage("collect")
		collectgarbage("collect")
		collectgarbage("collect")
	end
)
