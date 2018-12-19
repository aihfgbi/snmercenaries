include "config.common"

nodename = "robot"

luaservice = luaservice .. root.."server/robot/?.lua;"..
    root.."server/robot/ai/?.lua;"..
	root.."server/game/logic/?.lua;"

-- 将添加到 package.path 中的路径，供 require 调用。
lua_path = lua_path .. "./server/robot/?.lua;"..
    root.."server/robot/ai/?.lua;"..
	root.."server/game/logic/?.lua;"..
	root.."config/?.lua;"..
	root.."protocol/?.lua;"

snax = lua_path

-- 后台模式
daemon = root.."pid/"..nodename..".pid"

logger = root.."h5gamelog/"..nodename..".log"
