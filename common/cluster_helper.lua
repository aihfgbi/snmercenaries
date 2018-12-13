local skynet = require "skynet"
local datacenter = require "skynet.datacenter"
local cluster = require "skynet.cluster"
local dbs_count = skynet.getenv "dbs_count"
dbs_count = tonumber(dbs_count)

function get_userdata(uid)
	local index = uid % dbs_count
	-- index = index + 1
	local dbs = dbs_list[index]
	local node = "dbs"..index
	if not dbs then
		local ok,id = pcall(cluster.query, node, "manager")
		if not ok then
			return false
		end

		dbs = id
		dbs_list[index] = id
	end

	local ok, addr = pcall(cluster.call, node, dbs, "forward", uid, nodename)
	if not ok then
		dbs_list[index] = nil
		LOG_DEBUG(addr)
		return false
	end

	return node, addr
end