local this = {}

this[1001] = {
    type = "douniu", --游戏类别
    name = "牛牛", --游戏名称
    logic = "douniu", --加载的逻辑
    init_params = 1, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
    min_player = 2,
    max_player = 5,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {90,170,250,400,800,1200}, --开一把需要的钱 与times对应,90对应10局的AA 400对应10的房主支付 以此类推
    score = { 3, 5 },
    times = { 10, 20, 30 },
    usegold = nil,
    add_robot = nil,
    rate = { [3] = { 1, 2, 3 }, [5] = { 1, 2, 3, 5 } },
    record = true
}

this[1002] = {
    type = "douniu",
    name = "牛牛", --游戏名称
    logic = "douniu", --加载的逻辑
    init_params = 2, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
    min_player = 2,
    max_player = 5,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {90,170,250,400,800,1200}, --开一把需要的钱
    score = { 3, 5 },
    times = { 10, 20, 30 },
    usegold = nil,
    add_robot = nil,
    rate = { [3] = { 1, 2, 3 }, [5] = { 1, 2, 3, 5 } },
    record = true
}

this[1003] = {
    type = "douniu",
    name = "牛牛", --游戏名称
    logic = "douniu", --加载的逻辑
    init_params = 3, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
    min_player = 2,
    max_player = 5,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {90,170,250,400,800,1200}, --开一把需要的钱
    score = { 3, 5 },
    times = { 10, 20, 30 },
    usegold = nil,
    add_robot = nil,
    rate = { [3] = { 1, 2, 3 }, [5] = { 1, 2, 3, 5 } },
    record = true
}

this[1004] = {
    type = "douniu", --游戏类别
    name = "牛牛", --游戏名称
    logic = "douniu", --加载的逻辑
    init_params = 120, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
    min_player = 2,
    max_player = 5,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {90,170,250,400,800,1200}, --开一把需要的钱 与times对应,90对应10局的AA 400对应10的房主支付 以此类推
    score = { 3, 5 },
    times = { 10, 20, 30 },
    usegold = nil,
    add_robot = true,
    rate = { [3] = { 1, 2, 3 }, [5] = { 1, 2, 3, 5 } },
    record = true,
    min_gold = 3000
}

this[1005] = {
    type = "douniu",
    name = "牛牛", --游戏名称
    logic = "douniu", --加载的逻辑
    init_params = 400, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
    min_player = 2,
    max_player = 5,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {90,170,250,400,800,1200}, --开一把需要的钱
    score = { 3, 5 },
    times = { 10, 20, 30 },
    usegold = nil,
    add_robot = true,
    rate = { [3] = { 1, 2, 3 }, [5] = { 1, 2, 3, 5 } },
    record = true,
    min_gold = 10000
}

this[1006] = {
    type = "douniu",
    name = "牛牛", --游戏名称
    logic = "douniu", --加载的逻辑
    init_params = 1000, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
    min_player = 2,
    max_player = 5,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {90,170,250,400,800,1200}, --开一把需要的钱
    score = { 3, 5 },
    times = { 10, 20, 30 },
    usegold = nil,
    add_robot = true,
    rate = { [3] = { 1, 2, 3 }, [5] = { 1, 2, 3, 5 } },
    record = true,
    min_gold = 100000
}

this[1101] = {
    type = "douniu",
    name = "牛牛体验场", --游戏名称
    logic = "douniu", --加载的逻辑
    init_params = 1000, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
    min_player = 2,
    max_player = 5,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {90,170,250,400,800,1200}, --开一把需要的钱
    score = { 3, 5 },
    times = { 10, 20, 30 },
    usegold = nil,
    add_robot = true,
    rate = { [3] = { 1, 2, 3 }, [5] = { 1, 2, 3, 5 } },
    record = true,
    min_gold = 100000,
    test_gold = 1000000,
}

this[5001] = {
    name = "百人牛牛", --游戏名称
    logic = "hundred_niuniu", --加载的逻辑
    init_params =
    {
        robot_count = 10, --默认机器人数量
        per_max_gold = 5, --每局最大下注多少*万
        room_min_gold = 0.1, --房间最低金币限制*万
        unit = 10000, --单位
        min_master_gold = 100 --上庄最低金钱
    }, --加载逻辑的时候用到的参数
    min_player = 2,
    max_player = 100,
    wait_time = 0, --不需要开房
    price = 0, --自定义下注
    score = { 3, 5 },
    times = 0, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 }
}

this[5101] = {
    name = "百人牛牛体验场", --游戏名称
    logic = "hundred_niuniu", --加载的逻辑
    init_params =
    {
        robot_count = 10, --默认机器人数量
        per_max_gold = 5, --每局最大下注多少*万
        room_min_gold = 0.1, --房间最低金币限制*万
        unit = 10000, --单位
        min_master_gold = 100 --上庄最低金钱
    }, --加载逻辑的时候用到的参数
    min_player = 2,
    max_player = 100,
    wait_time = 0, --不需要开房
    price = 0, --自定义下注
    score = { 3, 5 },
    times = 0, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 },
    test_gold = 1000000,
}

this[5002] = {
    type = "br_niuniu", --游戏类别
    name = "百人牛牛", --游戏名称
    logic = "br_game", --加载的逻辑
    init_params = 1, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
    min_player = 1,
    max_player = 100,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3, 5 },
    times = { 10, 20, 30 },
    usegold = nil,
    add_robot = true,
    rate = { [3] = { 1, 2, 3 }, [5] = { 1, 2, 3, 5 } }
}

this[5102] = {
    type = "br_niuniu", --游戏类别
    name = "百人牛牛", --游戏名称
    logic = "br_game", --加载的逻辑
    init_params = 1, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
    min_player = 1,
    max_player = 100,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3, 5 },
    times = { 10, 20, 30 },
    usegold = nil,
    add_robot = true,
    rate = { [3] = { 1, 2, 3 }, [5] = { 1, 2, 3, 5 } },
    test_gold = 1000000,
}

this[6001] = {
    type = "majiang",
    name = "普通麻将", --游戏名称
    logic = "majiang", --加载的逻辑
    init_params =
    {
        base_rule = 10001, --基础规则id
        special_rule = 10001, --特殊规则id
        rate_rule = 1001,       --胡牌类型(倍率)
    },
    min_player = 4,
    max_player = 4,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {110,220,320,640}, --自定义下注
 --   score = { -1, 4, 6, 8 },
    score = {1},
    times = {8, 16}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    record = true
}

this[6101] = {
    type = "majiang",
    name = "金币场麻将", --游戏名称
    logic = "majiang", --加载的逻辑
    init_params =
    {
        base_rule = 11001, --基础规则id
        special_rule = 10001, --特殊规则id
        rate_rule = 1101,       --胡牌类型(倍率)
        base_score = 100,
        min_gold = 1000,
    },
    min_player = 4,
    max_player = 4,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --自定义下注
    score = { -1, 4, 6, 8 },
    times = {8, 16}, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 },
    record = true,
}

this[6102] = {
    type = "majiang",
    name = "金币场普通麻将", --游戏名称
    logic = "majiang", --加载的逻辑
    init_params =
    {
        base_rule = 11001, --基础规则id
        special_rule = 10001, --特殊规则id
        rate_rule = 1101,       --胡牌类型(倍率)
        base_score = 500,
        min_gold = 10000,
    },
    min_player = 4,
    max_player = 4,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --自定义下注
    score = { -1, 4, 6, 8 },
    times = {8, 16}, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 },
    record = true
}

this[6103] = {
    type = "majiang",
    name = "金币场普通麻将", --游戏名称
    logic = "majiang", --加载的逻辑
    init_params =
    {
        base_rule = 11001, --基础规则id
        special_rule = 10001, --特殊规则id
        rate_rule = 1101,       --胡牌类型(倍率)
        base_score = 2000,
        min_gold = 100000,
    },
    min_player = 4,
    max_player = 4,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --自定义下注
    score = { -1, 4, 6, 8 },
    times = {8, 16}, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 },
    record = true
}

this[6201] = {
    type = "majiang",
    name = "金币场麻将体验模式", --游戏名称
    logic = "majiang", --加载的逻辑
    init_params =
    {
        base_rule = 11001, --基础规则id
        special_rule = 10001, --特殊规则id
        rate_rule = 1101,       --胡牌类型(倍率)
        base_score = 2000,
        min_gold = 100000,
    },
    min_player = 4,
    max_player = 4,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --自定义下注
    score = { -1, 4, 6, 8 },
    times = {8, 16}, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 },
    record = true,
    test_gold = 1000000,
}


this[10002] = {
    type = "fqzs",
   name = "飞禽走兽", --游戏名称
    logic = "fqzs", --加载的逻辑
    init_params = nil,
    min_player = 1,
    max_player = 100,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 }
}

this[10007] = {
    type = "port_horse",
    name = "港式跑马", --游戏名称
    logic = "port_horse", --加载的逻辑
    init_params = nil,
    min_player = 1,
    max_player = 100,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 }
}

return this