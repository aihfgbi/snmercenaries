local skynet = require "skynet"

local index = 0
local activeTimer = {}
local timer = {}

local function getNewTimerid()
	index = index + 1
	return index
end

function timer.setTimer(duration, repeatcount, handler, ...)
	local id = getNewTimerid()
	local args = table.pack(...)
	local d = duration
	local count = 0

	skynet.fork(function ()
		while true do
			skynet.sleep(d*100)
			if not activeTimer[id] then
				activeTimer[id] = nil
				return
			end
			handler(table.unpack(args,1,args.n))
			count = count + 1
			if count >= repeatcount and repeatcount > 0 then
				activeTimer[id] = nil
				return
			end
		end
	end)
	activeTimer[id] = true
	return id
end

function timer.clearTimer(id)
	activeTimer[id] = nil
end

function timer.setTimeout(t, func, ...)
	local id = getNewTimerid()
	local args = table.pack(...)
	skynet.timeout(t*100, function()
		if activeTimer[id] then
			func(table.unpack(args,1,args.n))
			activeTimer[id] = nil
			id = nil
			args = nil
		end
	end)

	activeTimer[id] = true
	return id
end

function timer.clearTimeout(id)
	activeTimer[id] = nil
end

return timer