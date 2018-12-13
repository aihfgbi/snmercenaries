-- Copyright (C) 2013 LazyZhu (lazyzhu.com)
-- Copyright (C) 2013 IdeaWu (ideawu.com)
-- Copyright (C) 2012 Yichun Zhang (agentzh)

local socketchannel = require "socketchannel"

local sub = string.sub
local insert = table.insert
local concat = table.concat
local remove = table.remove
local len = string.len
local pairs = pairs
local unpack = table.unpack
local setmetatable = setmetatable
local tonumber = tonumber
local error = error
local gmatch = string.gmatch



local _M = { _VERSION = '0.03' }


local commands = {
    "set",                  "get",                 "del",
    "scan",                 "rscan",               "keys",
    "incr",                 "decr",                "exists",
    "multi_set",            "multi_get",           "multi_del",
    "multi_exists",
    "hset",                 "hget",                "hdel",
    "hscan",                "hrscan",              "hkeys",
    "hincr",                "hdecr",               "hexists",
    "hsize",                "hlist",               "hgetall",
    --[[ "multi_hset", ]]   "multi_hget",          "multi_hdel",
    "multi_hexists",        "multi_hsize",
    "zset",                 "zget",                "zdel",
    "zscan",                "zrscan",              "zkeys",
    "zincr",                "zdecr",               "zexists",
    "zsize",                "zlist",
    --[[ "multi_zset", ]]   "multi_zget",          "multi_zdel",
    "multi_zexists",        "multi_zsize",   
    "auth"
}


local mt = { __index = _M }


local function _query_resp(self)
    return function(sock)
		local var = {}

        local len,data
        while true do
            len = sock:readline()
            len = tonumber(len)
            if not len or len <= 0 then break end
            len = len+1
            data = sock:read(len)
            insert(var, data:sub(1,-2))
        end

        if #var > 1 then 
            remove(var, 1)
        end

        return true, var
    end
end


local function _gen_req(args)
    local req = {}

    for i = 1, #args do
        local arg = args[i]

        if arg then
            insert(req, len(arg))
            insert(req, "\n")
            insert(req, arg)
            insert(req, "\n")
        else
            return nil, err
        end
    end
    insert(req, "\n")

    return concat(req, "")
end


local function _do_cmd(self, ...)
    local args = {...}

    local channel = self.sockchannel

    if not channel then
        return nil, "not initialized"
    end

    local req = _gen_req(args)

    if not self.query_resp then
        self.query_resp = _query_resp(self)
    end

    return channel:request(req, self.query_resp)
end


for i = 1, #commands do
    local cmd = commands[i]

    _M[cmd] =
        function (self, ...)
            return _do_cmd(self, cmd, ...)
        end
end


function _M.multi_hset(self, hashname, ...)
    local args = {...}
    if #args == 1 then
        local t = args[1]
        local array = {}
        for k, v in pairs(t) do
            insert(array, k)
            insert(array, v)
        end
        
        return _do_cmd(self, "multi_hset", hashname, unpack(array))
    end

    -- backwards compatibility
    return _do_cmd(self, "multi_hset", hashname, ...)
end


function _M.multi_zset(self, keyname, ...)
    local args = {...}
    if #args == 1 then
        local t = args[1]
        local array = {}
        for k, v in pairs(t) do
            insert(array, k)
            insert(array, v)
        end
        -- print("key", keyname)
        return _do_cmd(self, "multi_zset", keyname, unpack(array))
    end

    -- backwards compatibility
    return _do_cmd(self, "multi_zset", keyname, ...)
end



function _M.connect( opts)

    local self = setmetatable( {}, mt)

    local password = opts.password or ""

    local channel = socketchannel.channel {
        host = opts.host,
        port = opts.port or 8011,
        __auth = function ()
            if #password > 0 then
                _do_cmd(self, "auth", password)
            end
        end
    }

    -- try connect first only once
    channel:connect(true)
    self.sockchannel = channel

    return self
end

function _M.disconnect(self)
    self.sockchannel:close()
    setmetatable(self, nil)
end

return _M