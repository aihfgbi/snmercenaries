local skynet = require "skynet"
local snax = require "snax"
local cluster = require "cluster"


local cs
local CMD = {}

function CMD.reload_config()
	load_servermap()
	local clusterd = skynet.uniqueservice("clusterd")
	skynet.call(clusterd, "lua", "reload")
end

function CMD.ping()
	return true
end

local function register_self( ... )
	while true do
		if not cs then
			local ok,id = pcall(cluster.query, "cs", "centerd")
			if ok and id then
				cs = cluster.proxy("cs", id)
			end
		end
		
		pcall(skynet.call, cs, "lua", "server_register", NODE_NAME, skynet.self())
		--LOG_INFO("register self to cs fail, wait...")
		skynet.sleep(100*5)
	end
end


skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(...)))
	end)

	--skynet.fork(register_self)

end)


