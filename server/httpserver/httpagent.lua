local skynet = require "skynet"
local cluster = require "skynet.cluster"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local json = require "cjson"
local sharedata = require "skynet.sharedata"
local dbs_count = skynet.getenv "dbs_count"
local USE_DEBUG = skynet.getenv "use_debug"
dbs_count = tonumber(dbs_count)

local table = table
local string = string
local redis
local login

local function connect_to_login(first)
	while true do
		local ok,id = pcall(cluster.query, "login", "loginstatus")
		if ok and id then
			LOG_DEBUG("connected with login service,gate is ready!")
			login = id
			break
		end
		LOG_DEBUG("wait for login service!!!")
		skynet.sleep(5*100)
	end
end

local function call_usermanager(uid, name, ...)
	local index = 0--uid % dbs_count
	-- index = index + 1
	local node = "dbs"..index
	local ok,addr = pcall(cluster.query, node, "manager")
	if not ok then
		return false
	end

	local ok, result = pcall(cluster.call, node, addr, name, ...)
	if not ok then
		return false
	end

	return result
end

local function response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

skynet.start(function()
	redis = skynet.uniqueservice("redispool")
	skynet.fork(connect_to_login)
	skynet.dispatch("lua", function (_,_,id)
		socket.start(id)  -- 开始接收一个 socket
		-- limit request body size to 1024 (you can pass nil to unlimit)
		-- 一般的业务不需要处理大量上行数据，为了防止攻击，做了一个 8K 限制。这个限制可以去掉。
		-- 限制接受数据在2K以内
		local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 2048)
		if code then
			if code ~= 200 then  -- 如果协议解析有问题，就回应一个错误码 code 。
				response(id, code)
			else
				-- 这是一个示范的回应过程，你可以根据你的实际需要，解析 url, method 和 header 做出回应。
				-- local tmp = {}
				-- if header.host then
				-- 	table.insert(tmp, string.format("host: %s", header.host))
				-- end
				-- -- LOG_DEBUG("method="..method)
				-- local path, query = urllib.parse(url)
				-- table.insert(tmp, string.format("path: %s", path))
				-- if query then
				-- 	local q = urllib.parse_query(query)
				-- 	for k, v in pairs(q) do
				-- 		table.insert(tmp, string.format("query: %s= %s", k,v))
				-- 	end
				-- end
				local path, query = urllib.parse(url)
				local done
				if query then
					local tmp = urllib.parse_query(query)
					if tmp.h then
						local h = string.lower(tmp.h)
						cfgadmin = sharedata.query "admin_conf"
						luadump(cfgadmin)
						if cfgadmin and cfgadmin[h] then
							local path2 = string.sub(path, 2, #path)
							local cmd = tostring(tmp.cmd) or "~~~~"
							if table.indexof(cfgadmin[h], path2) or table.indexof(cfgadmin[h], cmd) then
								done = true
							end
						end
					end
				end
				if USE_DEBUG == "0" then
					done = true
				end
				LOG_DEBUG("done="..tostring(done))
				if done then
					LOG_DEBUG(path.."   "..query)
					if path == "/record" then
						if query then
							local q = urllib.parse_query(query)
							-- luadump(q)
							if q.uid and q.time then
								local ok, data = pcall(skynet.call, redis, "lua", "execute", "get", "record->"..q.uid..":"..q.time)
								LOG_DEBUG(tostring(data))
								if data then
									response(id, code, data)
									return
								end
							end
						end
						response(id, code, "error")
					elseif path == "/charge" then
						if query then
							local q = urllib.parse_query(query)
							if q.uid and q.money and q.channel and q.order then
								LOG_DEBUG(q.uid.."充值了:"..q.money..",channel="..tostring(q.channel)..",order="..q.order)
								-- 人名币和钻石比例1：100,此处是人名币
								local done = call_usermanager(tonumber(q.uid), "charge", tonumber(q.uid), tonumber(q.money), tostring(q.channel), tostring(q.order))
								if done then
									response(id, code, "1")
								else
									response(id, code, "0")
								end
							else
								response(id, code, "params error")
							end
						else
							response(id, code, "params error")
						end
					elseif path == "/shutdown" then
						-- 
					elseif path == "/ctrl_gate" then
						if login then
							if query then
								local q = urllib.parse_query(query)
								if q and q.node and q.cmd then
									LOG_DEBUG("ctrl_gate:"..q.node..","..q.cmd)
									local ok, result = pcall(cluster.call, "login", login, "ctrl_gate", q.node, q.cmd)
									if ok then
										if result then
											if result == 0 then
												response(id, code, "ok.")
											elseif result == 1 then
												response(id, code, "connect to node error.")
											elseif result == 3 then
												response(id, code, "cmd error.")
											elseif result == 2 then
												response(id, code, "node error.")
											end
											response(id, code, "unknow error.")
										else
											response(id, code, "unknow error.")
										end
									else
										login = nil
										skynet.fork(connect_to_login)
										response(id, code, "connect to status server error.")
									end
								else
									response(id, code, "params error.")
								end
							else
								response(id, code, "params error.")
							end
						end
						response(id, code, "status server is not ready.")
					elseif path == "/gate_status" then
						if login then
							local ok, cnt, map = pcall(cluster.call, "login", login, "gate_status")
							if ok then
								local info = {total=cnt, server=map}
								local ok, out = pcall(json.encode, info)
								if ok and out then
									response(id, code, out)
								else
									response(id, code, "encode json error.")
								end
							else
								login = nil
								skynet.fork(connect_to_login)
								response(id, code, "connect to status server error.")
							end
						end
						response(id, code, "status server is not ready.")
					elseif path == "/set_ctrl_user" then
						if query then
							local q = urllib.parse_query(query)
							if q.uid and q.token and q.level then
								local uid, level
								uid = tonumber(q.uid)
								level = tonumber(q.level)
								if uid and level then
									local info = string.format('{"uid":%d,"token":"%s","openid":"gm","gm":%d,"nickname":"Z20=","avatar":""}',uid,q.token,level)
									local ok, data = pcall(skynet.call, redis, "lua", "execute", "set", "user:"..uid, info)
									if ok then
										response(id, code, '{"result":"ok","msg":'..info..'}')
									else
										response(id, code, '{"result":"error","msg":"redis error"}')
									end
								else
									response(id, code, '{"result":"error","msg":"wrong params"}')
								end
							else
								response(id, code, '{"result":"error","msg":"wrong params"}')
							end
						else
							response(id, code, '{"result":"error","msg":"wrong params"}')
						end
					elseif path == "/del_ctrl_user" then
						if query then
							local q = urllib.parse_query(query)
							if q.uid then
								local uid = tonumber(q.uid)
								if uid then
									local ok, data = pcall(skynet.call, redis, "lua", "execute", "del", "user:"..uid)
									if ok then
										response(id, code, '{"result":"ok","msg":"done"}')
									else
										response(id, code, '{"result":"error","msg":"redis error"}')
									end
								else
									response(id, code, '{"result":"error","msg":"wrong params"}')
								end
							else
								response(id, code, '{"result":"error","msg":"wrong params"}')
							end
						else
							response(id, code, '{"result":"error","msg":"wrong params"}')
						end
					-- elseif path == "/list_ctrl_user" then
					elseif path == "/get_ctrl_user" then
						if query then
							local q = urllib.parse_query(query)
							if q.uid then
								local uid = tonumber(q.uid)
								if uid then
									local ok, data = pcall(skynet.call, redis, "lua", "execute", "get", "user:"..uid)
									if ok then
										response(id, code, data)
									else
										response(id, code, '{"result":"error","msg":"redis error"}')
									end
								else
									response(id, code, '{"result":"error","msg":"wrong params"}')
								end
							else
								response(id, code, '{"result":"error","msg":"wrong params"}')
							end
						else
							response(id, code, '{"result":"error","msg":"wrong params"}')
						end
					elseif path == "/gm" then
						if query then
							local q = urllib.parse_query(query)
							if q.uid and q.cmd then
								if q.cmd == "add_gold" then
									local done = call_usermanager(tonumber(q.uid), "gm_cmd", tonumber(q.uid), "add_gold", tonumber(q.v))
									if done then
										response(id, code, "{'result':'ok','msg':"..tostring(done).."}")
									else
										response(id, code, "0")
									end
								elseif q.cmd == "sub_gold" then
									local done = call_usermanager(tonumber(q.uid), "gm_cmd", tonumber(q.uid), "sub_gold", tonumber(q.v))
									if done then
										response(id, code, "{'result':'ok','msg':"..tostring(done).."}")
									else
										response(id, code, "0")
									end
								elseif q.cmd == "add_money" then
									local done = call_usermanager(tonumber(q.uid), "gm_cmd", tonumber(q.uid), "add_money", tonumber(q.v))
									if done then
										response(id, code, "{'result':'ok','msg':"..tostring(done).."}")
									else
										response(id, code, "0")
									end
								elseif q.cmd == "sub_money" then
									local done = call_usermanager(tonumber(q.uid), "gm_cmd", tonumber(q.uid), "sub_money", tonumber(q.v))
									if done then
										response(id, code, "{'result':'ok','msg':"..tostring(done).."}")
									else
										response(id, code, "0")
									end
								elseif q.cmd == "add_hongbao" then
									-- gm_cmd
									local done = call_usermanager(tonumber(q.uid), "gm_cmd", tonumber(q.uid), "add_hongbao", tonumber(q.v))
									if done then
										response(id, code, "{'result':'ok','msg':"..tostring(done).."}")
									else
										response(id, code, "0")
									end
								elseif q.cmd == "sub_hongbao" then
									local done = call_usermanager(tonumber(q.uid), "gm_cmd", tonumber(q.uid), "sub_hongbao", tonumber(q.v))
									if done then
										response(id, code, "{'result':'ok','msg':"..tostring(done).."}")
									else
										response(id, code, "0")
									end
								elseif q.cmd == "get_user" then
									local done = call_usermanager(tonumber(q.uid), "get_user_json", tonumber(q.uid))
									if done then
										response(id, code, done)
									else
										response(id, code, "0")
									end
								elseif q.cmd == "set_win" then
									local done = call_usermanager(tonumber(q.uid), "gm_cmd", tonumber(q.uid), "set_win", tonumber(q.v))
									if done then
										response(id, code, "{'result':'ok','msg':"..tostring(done).."}")
									else
										response(id, code, "0")
									end
								else
									response(id, code, "wrong cmd")
								end
							else
								response(id, code, "params error")
							end
						else
							response(id, code, "params error")
						end
					else
						response(id, code, "gun")
					end
				else
					response(id, code, "not limited.")
				end
			end
		else
			-- 如果抛出的异常是 sockethelper.socket_error 表示是客户端网络断开了。
			if url == sockethelper.socket_error then
				skynet.error("socket closed")
			else
				skynet.error(url)
			end
		end
		socket.close(id)
	end)
end)