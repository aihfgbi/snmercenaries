local skynet = require "skynet"
local nodename = skynet.getenv("nodename")
local robot_name_store = require "robot_name"

local CMD = {}
local uid_index = 0
local robot_list = {}
local count = 0

local robot_names = {}
local headimgs = {}

local function init_names( ... )
	table.clear(robot_names)
	table.join(robot_names, robot_name_store)
end

local function init_headimgs()
	for i=1, 15000 do
		table.insert(headimgs, i)
	end
end

local function get_robot_name( ... )
	if #robot_names == 0 then
		init_names()
	end
	local index = math.random(#robot_names)
	-- local name = table.remove(robot_names, index)
	-- if #robot_names > 0 then
	-- 	name = table.remove(robot_names, math.random(#robot_names))
	-- end
	
	return table.remove(robot_names, index)
end

local function give_back_name(name)
	table.insert(robot_names, name)
end

local function get_robot_headimp( ... )
	if #headimgs == 0 then
		init_headimgs()
	end
	local index = math.random(#headimgs)
	local headimgcnt = table.remove(headimgs, index)

	local imgurl
	if headimgcnt <= 5000 then
		imgurl = "http://wximg.ld68.com/touxiang/1%20("..headimgcnt..").jpg"
	elseif headimgcnt <= 10000 then
		imgurl = "http://wximg.ld68.com/touxiang3/a"..headimgcnt..".jpg"
	else
		imgurl = "http://wximg.ld68.com/touxiang2/a"..(headimgcnt-10000)..".jpg"
	end
	return imgurl
end

function CMD.get_robot(type, gold, gameid, gamenode, gamerobot)
	uid_index = uid_index + 1
	local robot = skynet.newservice("robot")
	local rname = get_robot_name()
	local rheadimp = get_robot_headimp()
	skynet.call(robot, "lua", "init", type, gameid, gamenode, gamerobot, skynet.self(), uid_index, gold)
	robot_list[uid_index] = {	uid=uid_index,
				agnode=nodename,
				agaddr=robot,
				nickname=rname,
				gold=gold,
				headimg=rheadimp,
				money=0,
				sex = 1,
				isrobot = true}
	count = count + 1
	LOG_DEBUG("game[%d] get_robot[%d], gold[%d]", gameid, uid_index, gold)
	return robot_list[uid_index]
end

function CMD.free_robot(uid)
	if uid and robot_list[uid] then
		give_back_name(robot_list[uid].nickname)
		count = count - 1
		robot_list[uid] = nil
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
	init_headimgs()
	collectgarbage("collect")
	collectgarbage("collect")
	collectgarbage("collect")
end)
