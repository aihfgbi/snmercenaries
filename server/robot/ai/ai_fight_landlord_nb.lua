local ai_mgr = {}
local server_msg = {}
local robot_api
local robot_info
local content_dissolve
local My_card = {}
math.randomseed(os.time());

local function send_to_server(name, msg)
		-- LOG_DEBUG("send_to_server [%s]", name)
		robot_api.send_msg(name, msg)
end

--延迟调用函数
local function delay_call(time, fun, pa)
		robot_api.register_delay_fun(time, fun, pa)
end

local function dissolve_table( ... )
		send_to_server("DissolveTable", {opt = 2})
end

local function get_ready()
		send_to_server("GetReadyNtf", {})
end

local function play_card( ... )
		send_to_server("PlayCard", {})
end

function server_msg.AddCard(msg)
		-- body
	if msg.cards and table.len(msg.cards) >= 25 then
				My_card = table.deepcopy(msg.cards)
	end
end

function server_msg.PushDissolveTable(msg)
		if not content_dissolve then
				delay_call(math.random(3,10), dissolve_table)
				content_dissolve = true
		end
end

function server_msg.GameLandResume(msg)
		-- body
end

function server_msg.ShowCard(msg)
		-- body
end

function server_msg.GameResult(msg)
		delay_call(math.random(3,10), get_ready)
end

function server_msg.PlayCard(msg)
		-- body
end

function server_msg.AskPlayCard(msg)
		if msg.seatid == robot_info.seatid then
				delay_call(math.random(2,5), play_card)
		end
end

function server_msg.LandTrusteeship(msg)
		-- body
end

function server_msg.SetMaster(msg)
		-- body
end

function server_msg.StartRound(msg)
		-- body
end

--转换我的牌到指定数据结构
local function structure(cards)
	local new = {}
	for i = 1, 22 do -->王最大值522
			new[i] = { cal_value = i, count = 0, cards = {} }
	end
	for k, v in pairs(cards) do
			local r = v % 100
			new[r].count = new[r].count + 1
			table.insert(new[r].cards, v)
	end
	return new
end

-- 四王为3分，炸弹1分，大王1分，
-- 大于6分时叫三倍（大于8分时继续抢地主），大于5分时叫2倍      大于3分时叫1倍    小于3分时则不叫。
local function get_rate(rate_ask)
	local index
	-- local index = math.random(rate_ask,3)
	local cards = structure(My_card)
	-- PRINT_T(cards)
	local sum = 0
	for k,v in pairs(cards) do
		if v.count >= 4 then
				sum = sum + 1
		end
	end
	if (cards[21].count == 2) and (cards[22].count == 2) then
		sum = sum + 3
	else 
		sum = sum + cards[22].count
	end
	if sum >= 6 then
		index = 3
	elseif sum >= 5 then
		index = 2
	elseif sum >= 3 then
		index = 1
	else
		index = 0
	end
	if rate_ask[1] >= index then
		index = 0
	end
	send_to_server("SetRate",{rate = index,uid = robot_info.uid});
end

function server_msg.AskRate(msg)
		if robot_info.seatid == msg.seatid then
				delay_call(math.random(1,3), get_rate,{msg.opt})
		end
end

function server_msg.GetMaster(msg)
		-- body
end

function server_msg.SetRate(msg)
		-- body
end

function server_msg.GameStart(msg)
		-- body
end

function server_msg.GameLandlordEnd(msg)
		-- body
end

function server_msg.SitdownNtf(msg)
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


function server_msg.GameStart(msg)
end

function ai_mgr.init(api, uid)
		robot_api = api
		robot_info = robot_info or {}
		robot_info.uid = uid
		LOG_DEBUG("robot uid[%d]", robot_info.uid)
end

function ai_mgr.dispatch(name, msg)
		local f = server_msg[name]
		if f then
				f(msg)
		else
				LOG_DEBUG("no matching function deal server msg[%s] !!!!!!!!!!!", tostring(name))
		end
end

function ai_mgr.free()
		robot_info = nil
end

return ai_mgr