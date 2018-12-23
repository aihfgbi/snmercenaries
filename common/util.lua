local skynet = require "skynet"

if skynet.getenv("daemon") then
	CONSOLE_LOG = false
end

NODE_NAME = skynet.getenv("nodename")

local SERVICE_NAME = SERVICE_NAME

function LOG_DEBUG(fmt, ...)
	local params = {...}
	local msg
	if #params > 0 then
		msg = string.format(fmt, ...)
		local info = debug.getinfo(2)
		if info then
			msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
		end
	else
		msg = fmt
		local info = debug.getinfo(2)
		if info then
			msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
		end
	end

	skynet.error(msg)
	-- skynet.send(".logger", "lua", "debug", SERVICE_NAME, msg)
end

function LOG_INFO(fmt, ...)
	local msg = string.format(fmt, ...)
	local info = debug.getinfo(2)
	if info then
		msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
	end

	skynet.send(".logger", "lua", "info", SERVICE_NAME, msg)
end

function LOG_WARNING(fmt, ...)
	local msg = string.format(fmt, ...)
	local info = debug.getinfo(2)
	if info then
		msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
	end

	skynet.send(".logger", "lua", "warning", SERVICE_NAME, msg)
end

function LOG_ERROR(fmt, ...)
	local msg = string.format(fmt, ...)
	local info = debug.getinfo(2)
	if info then
		msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
	end

	skynet.send(".logger", "lua", "error", SERVICE_NAME, msg)
end

function LOG_FATAL(fmt, ...)
	local msg = string.format(fmt, ...)
	local info = debug.getinfo(2)
	if info then
		msg = string.format("[%s:%d] %s", info.short_src, info.currentline, msg)
	end

	skynet.send(".logger", "lua", "fatal", SERVICE_NAME, msg)
end

--[[
    @desc: 随机数字
    author:{author}
    time:2018-12-14 10:06:58
    --@n:
	--@m: 
    @return:
]]
function RAND_NUM(n, m)
	math.randomseed(os.clock() * math.random(1000000, 9000000) + math.random(1000000, 9000000))
	return math.random(n, m)
end


--[[
    @desc: 随机生成一个指定长度的字符串
    author:{author}
    time:2018-12-06 23:31:03
    --@len: 
    @return:
]]
function RAND_STR(len)
    local big = "QWERTYUIOPASDFGHJKLZXCVBNM"
    local small = "qwertyuiopasdfghjklzxcvbnm"
    local num = "1234567890"
    local tmpLen = len
    local tmpStr = nil
    
    if not tmpLen then
        tmpLen = RAND_NUM(10, 20)
    end
    tmpStr = big .. small .. num

    local maxLen = string.len(tmpStr)
    local str = {}
    for i = 1, tmpLen do
        local index = RAND_NUM(1, maxLen)
        str[i] = string.sub(tmpStr, index, index)
    end
    return table.concat(str, "")
end

--[[
    @desc: 分解或者合成游戏id
    author:{author}
    time:2018-12-22 23:44:13
    --@type: 1分解  2合成
    @return:
]]
function CHANGE_GAMEID(type,gid,mid)
	if type == 1 and gid and gid > 1000 then
		local gameid = math.floor(gid/1000)
		local modelid = math.floor( gid%1000 )
		return gameid,modelid
	elseif type == 2 and gid and mid then
		return gid * 1000 + mid
	end
end