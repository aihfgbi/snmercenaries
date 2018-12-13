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

this[2001] = {
    type = "jdddz",
    name = "斗地主", --游戏名称
    logic = "classic_landlord", --加载的逻辑
    init_params = { master_type = 1},         --加载逻辑的时候用到的参数, 1是抢地主，2是叫分
                    
    min_player = 3,
    max_player = 3,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {110,220,320,640}, --开一把需要的钱
    score = { 3, 4, 5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = nil,
    bomb = { 3, 4, 5 },
    record = true, 
}

this[2002] = {
    type = "jdddz",
    name = "斗地主", --游戏名称
    logic = "classic_landlord", --加载的逻辑
    init_params = { master_type = 2, },       --加载逻辑的时候用到的参数, 1是抢地主，2是叫分
                     
    min_player = 3,
    max_player = 3,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {110,220,320,640}, --开一把需要的钱
    score = { 3, 4, 5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = nil,
    bomb = { 3, 4, 5 },
    record = true, 
}

this[2101] = {
    type = "jdddz",
    name = "斗地主", --游戏名称
    logic = "classic_landlord", --加载的逻辑
    init_params = { master_type = 1,        --加载逻辑的时候用到的参数, 1是抢地主，2是叫分
                    base_score = 20,
                    min_gold = 3000,}, 
    min_player = 3,
    max_player = 3,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3, 4, 5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = true,
    bomb = { 3, 4, 5 },
    record = true, 
}

this[2102] = {
    type = "jdddz",
    name = "斗地主", --游戏名称
    logic = "classic_landlord", --加载的逻辑
    init_params = { master_type = 1,        --加载逻辑的时候用到的参数, 1是抢地主，2是叫分
                    base_score = 70,
                    min_gold = 20000,}, 
    min_player = 3,
    max_player = 3,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3, 4, 5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = true,
    bomb = { 3, 4, 5 },
    record = true, 
}

this[2103] = {
    type = "jdddz",
    name = "斗地主", --游戏名称
    logic = "classic_landlord", --加载的逻辑
    init_params = { master_type = 1,        --加载逻辑的时候用到的参数, 1是抢地主，2是叫分
                    base_score = 300,
                    min_gold = 100000,}, 
    min_player = 3,
    max_player = 3,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3, 4, 5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = true,
    bomb = { 3, 4, 5 },
    record = true, 
}

this[2201] = {
    type = "jdddz",
    name = "斗地主体验模式", --游戏名称
    logic = "classic_landlord", --加载的逻辑
    init_params = { master_type = 1,        --加载逻辑的时候用到的参数, 1是抢地主，2是叫分
                    base_score = 300,
                    min_gold = 100000,}, 
    min_player = 3,
    max_player = 3,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3, 4, 5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = true,
    bomb = { 3, 4, 5 },
    record = true, 
    test_gold = 1000000,
}

this[3001] = {
    type = "nbddz",
    name = "宁波斗地主", --游戏名称
    logic = "fight_landlord_nb", --加载的逻辑
    init_params = {}, --加载逻辑的时候用到的参数:2是叫分
    min_player = 4,
    max_player = 4,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = {90,170,320,640}, --开一把需要的钱
    score = { 3,5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = nil,
    record = true
}

this[3101] = {
    type = "nbddz",
    name = "宁波斗地主", --游戏名称
    logic = "fight_landlord_nb", --加载的逻辑
    init_params = {base_score = 100,
                    min_gold = 1000,}, --加载逻辑的时候用到的参数:2是叫分
    min_player = 4,
    max_player = 4,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3,5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = true,
    min_gold = 1000,
    record = true
}

this[3102] = {
    type = "nbddz",
    name = "宁波斗地主", --游戏名称
    logic = "fight_landlord_nb", --加载的逻辑
    init_params = {base_score = 1000,
                    min_gold = 10000,}, --加载逻辑的时候用到的参数:2是叫分
    min_player = 4,
    max_player = 4,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3,5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = true,
    min_gold = 10000,
    record = true
}

this[3103] = {
    type = "nbddz",
    name = "宁波斗地主", --游戏名称
    logic = "fight_landlord_nb", --加载的逻辑
    init_params = {base_score = 10000,
                    min_gold = 100000,}, --加载逻辑的时候用到的参数:2是叫分
    min_player = 4,
    max_player = 4,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3,5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = true,
    min_gold = 100000,
    record = true
}

this[4001] = {
    type = "fish",
    name = "悟空闹海·体验",
    logic = "buyu02",
    init_params = {base = {500,600,700,800,900,1000,1500,2000},type=1,gold = 1000000, boss=4001},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {100, 200, 500, 1000}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = nil,
    min_gold = 0,
    test_gold = 1000000,
    -- rate = {1,2,3}
}

this[4002] = {
    type = "fish",
    name = "悟空闹海·百倍",
    logic = "buyu02",
    init_params = {base = {10,20,30,40,50,60,80,100}, boss=4001},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 1000,
    -- rate = {1,2,3}
}

this[4003] = {
    type = "fish",
    name = "悟空闹海·千倍",
    logic = "buyu02",
    init_params = {base = {100,200,300,400,500,600,800,1000}, boss=4001},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 10000,
    -- rate = {1,2,3}
}

this[4004] = {
    type = "fish",
    name = "悟空闹海·万倍",
    logic = "buyu02",
    init_params = {base = {1000,2000,3000,4000,5000,6000,8000,10000}, boss=4001},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 100000,
    -- rate = {1,2,3}
}

this[4101] = {
    type = "fish",
    name = "李逵捕鱼·体验",
    logic = "buyu02",
    init_params = {base = {500,600,700,800,900,1000,1500,2000},type=1,gold = 1000000, boss=4002},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {100, 200, 500, 1000}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = nil,
    min_gold = 0,
    test_gold = 1000000,
    -- rate = {1,2,3}
}

this[4102] = {
    type = "fish",
    name = "李逵捕鱼·百倍",
    logic = "buyu02",
    init_params = {base = {10,20,30,40,50,60,80,100}, boss=4002},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 1000,
    kickback = 0.04,
    -- rate = {1,2,3}
}

this[4103] = {
    type = "fish",
    name = "李逵捕鱼·千倍",
    logic = "buyu02",
    init_params = {base = {100,200,300,400,500,600,800,1000}, boss=4002},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 10000,
    -- rate = {1,2,3}
}

this[4104] = {
    type = "fish",
    name = "李逵捕鱼·万倍",
    logic = "buyu02",
    init_params = {base = {1000,2000,3000,4000,5000,6000,8000,10000}, boss=4002},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 100000,
    -- rate = {1,2,3}
}

this[4201] = {
    type = "fish",
    name = "加勒比捕鱼·体验",
    logic = "buyu02",
    init_params = {base = {500,600,700,800,900,1000,1500,2000},type=1,gold = 1000000, boss=4003},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {100, 200, 500, 1000}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = nil,
    min_gold = 0,
    test_gold = 1000000,
    -- rate = {1,2,3}
}

this[4202] = {
    type = "fish",
    name = "加勒比捕鱼·百倍",
    logic = "buyu02",
    init_params = {base = {10,20,30,40,50,60,80,100}, boss=4003},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 1000,
    -- rate = {1,2,3}
}

this[4203] = {
    type = "fish",
    name = "加勒比捕鱼·千倍",
    logic = "buyu02",
    init_params = {base = {100,200,300,400,500,600,800,1000}, boss=4003},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 10000,
    -- rate = {1,2,3}
}

this[4204] = {
    type = "fish",
    name = "加勒比捕鱼·万倍",
    logic = "buyu02",
    init_params = {base = {1000,2000,3000,4000,5000,6000,8000,10000}, boss=4003},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 100000,
    -- rate = {1,2,3}
}

this[4300] = {
    type = "fish",
    name = "海王宝藏·百倍",
    logic = "buyu02",
    init_params = {base = {10,20,30,40,50,60,80,100}, boss=4004, scenescnt = 4},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 1000,
    -- rate = {1,2,3}
}

this[4301] = {
    type = "fish",
    name = "海王宝藏·千倍",
    logic = "buyu02",
    init_params = {base = {100,200,300,400,500,600,800,1000}, boss=4004, scenescnt = 4},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 10000,
    -- rate = {1,2,3}
}

this[4302] = {
    type = "fish",
    name = "海王宝藏·万倍",
    logic = "buyu02",
    init_params = {base = {1000,2000,3000,4000,5000,6000,8000,10000}, boss=4004, scenescnt = 4},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {80,160}, --开一把需要的钱
    score = {1,10},
    times = {1,2,3,6},
    usegold = nil,
    add_robot = true,
    min_gold = 100000,
    -- rate = {1,2,3}
}

this[4500] = {
    type = "fish",
    name = "海王宝藏·二人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}, boss=4004, scenescnt = 4},
    min_player = 1,
    max_player = 2,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 600, 800, 1000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4501] = {
    type = "fish",
    name = "海王宝藏·四人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}, boss=4004, scenescnt = 4},
    min_player = 1,
    max_player = 4,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 600, 800, 1000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4502] = {
    type = "fish",
    name = "海王宝藏·六人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}, boss=4004, scenescnt = 4},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 600, 800, 1000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4900] = {
    type = "fish",
    name = "悟空闹海·二人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}},
    min_player = 1,
    max_player = 2,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 600, 800, 1000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4901] = {
    type = "fish",
    name = "悟空闹海·四人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}},
    min_player = 1,
    max_player = 4,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 1200, 1600, 2000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4902] = {
    type = "fish",
    name = "悟空闹海·六人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 1800, 2400, 3000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4910] = {
    type = "fish",
    name = "李逵捕鱼·二人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}},
    min_player = 1,
    max_player = 2,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 600, 800, 1000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4911] = {
    type = "fish",
    name = "李逵捕鱼·四人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}},
    min_player = 1,
    max_player = 4,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 1200, 1600, 2000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4912] = {
    type = "fish",
    name = "李逵捕鱼·六人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 1800, 2400, 3000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4920] = {
    type = "fish",
    name = "加勒比捕鱼·二人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}, boss=4003},
    min_player = 1,
    max_player = 2,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 600, 800, 1000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4921] = {
    type = "fish",
    name = "加勒比捕鱼·四人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}},
    min_player = 1,
    max_player = 4,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 1200, 1600, 2000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
}

this[4922] = {
    type = "fish",
    name = "加勒比捕鱼·六人",
    logic = "buyu02",
    init_params = {base = {1,2,3,4,5,6}},
    min_player = 1,
    max_player = 6,
    wait_time = 20*60, --房间等待时间，秒为单位
    price = {300, 400, 500, 1800, 2400, 3000}, --开一把需要的钱
    score = {1,2},
    times = {6,8,10},
    usegold = nil,
    add_robot = true,
    min_gold = 0,
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

this[5003] = {
    type = "br_xiaojiu", --游戏类别
    name = "小九", --游戏名称
    logic = "br_game", --加载的逻辑
    init_params = 2, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
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

this[5103] = {
    type = "br_xiaojiu", --游戏类别
    name = "小九体验场", --游戏名称
    logic = "br_game", --加载的逻辑
    init_params = 2, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
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

this[5004] = {
    type = "br_erbagang", --游戏类别
    name = "二八杠", --游戏名称
    logic = "br_game", --加载的逻辑
    init_params = 3, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
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

this[5104] = {
    type = "br_erbagang", --游戏类别
    name = "二八杠体验场", --游戏名称
    logic = "br_game", --加载的逻辑
    init_params = 3, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
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

this[5005] = {
    type = "br_bieshi", --游戏类别
    name = "憋十", --游戏名称
    logic = "br_game", --加载的逻辑
    init_params = 4, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
    min_player = 1,
    max_player = 100,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3, 5 },
    times = { 10, 20, 30 },
    usegold = nil,
    add_robot = true,
    rate = { [3] = { 1, 2, 3 }, [5] = { 1, 2, 3, 5 } },
}

this[5105] = {
    type = "br_bieshi", --游戏类别
    name = "憋十体验场", --游戏名称
    logic = "br_game", --加载的逻辑
    init_params = 4, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
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

this[10001] = {
    type = "jxlw",
    name = "九线拉王", --游戏名称
    logic = "jxlw", --加载的逻辑
    init_params = {
        lock_pournumber=9,
        lock_pourmoney=500,
        pour_money=100,
        pour_number =1,
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 }
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
this[10003] = {
    type = "slyz",
    name = "时来运转", --游戏名称
    logic = "slyz", --加载的逻辑
    init_params = {lock_pourmoney=1000,pour_money=100,},
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 }
}

this[5006] = {
    type = "br_liangzhang", --游戏类别
    name = "温州两张", --游戏名称
    logic = "br_game", --加载的逻辑
    init_params = 5, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
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

this[5106] = {
    type = "br_liangzhang", --游戏类别
    name = "温州两张体验场", --游戏名称
    logic = "br_game", --加载的逻辑
    init_params = 5, --加载逻辑的时候用到的参数, 1是抢庄牛牛，2是轮庄，3是固定庄
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

-- 比赛

this[100001] = {
    type = "jdddz",
    name = "斗地主淘汰赛", --游戏名称
    logic = "classic_landlord", --加载的逻辑
    init_params = { master_type = 1,        --加载逻辑的时候用到的参数, 1是抢地主，2是叫分
                    base_score = 50,
                    min_gold = 1000,}, 
    min_player = 3,
    max_player = 3,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3, 4, 5 },
    times = { 8, 16 },
    usegold = true,
    add_robot = true,
    bomb = { 3, 4, 5 },
    record = false, 
    ismatch = true
}

this[10004] = {
    type = "csd",
    name = "财神到", --游戏名称
    logic = "csd", --加载的逻辑
    init_params = {
        lock_pourmoney=45000,
        pour_money=9000,
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 }
}
this[10005] = {
    type = "heibao",
    name = "黑豹的月亮", --游戏名称
    logic = "heibao", --加载的逻辑
    init_params = {
        lock_pourmoney=93750,
        pour_money=15000,
    },
    min_player = 1,
    max_player = 200,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 }
}

this[11005] = {
    type = "heibao",
    name = "黑豹的月亮体验场", --游戏名称
    logic = "heibao", --加载的逻辑
    init_params = {
        lock_pourmoney=93750,
        pour_money=15000,
    },
    min_player = 1,
    max_player = 200,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    test_gold = 1000000,
}

this[10006] = {
    type = "slwh",
    name = "森林舞会初级场", --游戏名称
    logic = "slwh_game", --加载的逻辑
    init_params = nil,
    min_player = 1,
    max_player = 100,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 },
    min_gold = 100
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
this[10008] = {
    type = "tgg",
    name = "跳高高初级场", --游戏名称
    logic = "tgg", --加载的逻辑
    init_params = {
        lock_pourmoney=600000,
        pour_money=5000,
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
}

this[11001] = {
    type = "jxlw",
    name = "九线拉王体验房", --游戏名称
    logic = "jxlw", --加载的逻辑
    init_params = {
        lock_pournumber=9,
        lock_pourmoney=500,
        pour_money=100,
        pour_number =1,
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    test_gold = 1000000,
}

this[11002] = {
    type = "fqzs",
   name = "飞禽走兽体验房", --游戏名称
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
    rate = { 1, 2, 3 },
    test_gold = 1000000,
}

this[11003] = {
    type = "slyz",
    name = "时来运转体验房", --游戏名称
    logic = "slyz", --加载的逻辑
    init_params = {lock_pourmoney=1000,pour_money=100,},
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    test_gold = 1000000,
}
this[11004] = {
    type = "csd",
    name = "财神到体验房", --游戏名称
    logic = "csd", --加载的逻辑
    init_params = {
        lock_pourmoney=45000,
        pour_money=9000,
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    test_gold = 1000000,
}

this[3104] = {
    type = "nbddz",
    name = "宁波斗地主体验房", --游戏名称
    logic = "fight_landlord_nb", --加载的逻辑
    init_params = {base_score = 10000,
                    min_gold = 0,}, --加载逻辑的时候用到的参数:2是叫分
    min_player = 4,
    max_player = 4,
    wait_time = 20 * 60, --房间等待时间，秒为单位
    price = { 40, 160 }, --开一把需要的钱
    score = { 3,5 },
    times = { 8, 16 },
    usegold = nil,
    add_robot = true,
    record = true,
    min_gold = 0,
    test_gold = 1000000,
}

this[11006] = {
    type = "slwh",
    name = "森林舞会体验房", --游戏名称
    logic = "slwh_game", --加载的逻辑
    init_params = nil,
    min_player = 1,
    max_player = 100,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 },
    test_gold = 1000000,
}

this[11008] = {
    type = "tgg",
    name = "跳高高体验房", --游戏名称
    logic = "tgg", --加载的逻辑
    init_params = {
        lock_pourmoney=600000,
        pour_money=5000,
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    test_gold = 1000000,
}

this[11007] = {
    type = "port_horse",
    name = "港式跑马体验房", --游戏名称
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
    rate = { 1, 2, 3 },
    test_gold = 1000000,
}

this[10009] = {
    type = "slwh",
    name = "森林舞会富豪场", --游戏名称
    logic = "slwh_game", --加载的逻辑
    init_params = nil,
    min_player = 1,
    max_player = 100,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 },
    min_gold = 1000
}

this[10010] = {
    type = "slwh",
    name = "森林舞会至尊场", --游戏名称
    logic = "slwh_game", --加载的逻辑
    init_params = nil,
    min_player = 1,
    max_player = 100,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = true,
    rate = { 1, 2, 3 },
    min_gold = 10000
}

this[10011] = {
    type = "tql",
    name = "跳起来初级场", --游戏名称
    logic = "tql", --加载的逻辑
    init_params = {
        lock_pourmoney=3750000,
        pour_money=6000,
        gold_rate = {2,3,5,10,30},  --游戏内下注的倍率
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    min_gold = 10000,
}

this[11011] = {
    type = "tql",
    name = "跳起来体验房", --游戏名称
    logic = "tql", --加载的逻辑
    init_params = {
        lock_pourmoney=3750000,
        pour_money=6000,
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    test_gold = 1000000,
    numberChance={[0]=200,[5]=10,[6]=10,[8]=10,[10]=10,[12]=10,[15]=50,[20]=50,[25]=20,[30]=20,   --测试服概率
        [40]=80,[50]=50,[60]=50,[70]=50,[80]=50,[90]=50,[100]=70,[150]=40,[175]=30,[200]=50,[250]=30,[1000]=1},   --1000代表免费  其余代表倍率
}

this[10012] = {
    type = "tql",
    name = "跳起来中级场", --游戏名称
    logic = "tql", --加载的逻辑
    init_params = {
        lock_pourmoney=3750000,
        pour_money=6000,
        gold_rate = {10,30,50,80,125},  --游戏内下注的倍率
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    min_gold = 100000,
}

this[10013] = {
    type = "tql",
    name = "跳起来高级场", --游戏名称
    logic = "tql", --加载的逻辑
    init_params = {
        lock_pourmoney=3750000,
        pour_money=6000,
        gold_rate = {125,250,500,750,1250},  --游戏内下注的倍率
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    min_gold = 1000000,
}

this[10014] = {
    type = "tgg",
    name = "跳高高中级场", --游戏名称
    logic = "tgg", --加载的逻辑
    init_params = {
        lock_pourmoney=600000,
        pour_money=5000,
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
}

this[10015] = {
    type = "tgg",
    name = "跳高高高级场", --游戏名称
    logic = "tgg", --加载的逻辑
    init_params = {
        lock_pourmoney=600000,
        pour_money=5000,
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
}

this[10016] = {
    type = "tql_2",
    name = "跳起来2初级场", --游戏名称
    logic = "tql_2", --加载的逻辑
    init_params = {
        lock_pourmoney=5000000,
        pour_money=8000,
        gold_rate = {2,3,5,10,30},  --游戏内下注的倍率
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    min_gold = 10000,
}

this[11016] = {
    type = "tql_2",
    name = "跳起来2体验房", --游戏名称
    logic = "tql_2", --加载的逻辑
    init_params = {
        lock_pourmoney=5000000,
        pour_money=8000,
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    test_gold = 1000000,
    numberChance={[0]=200,[5]=10,[6]=10,[8]=10,[10]=10,[12]=10,[15]=50,[20]=50,[25]=20,[30]=20,   --测试服概率
        [40]=80,[50]=50,[60]=50,[70]=50,[80]=50,[90]=50,[100]=70,[150]=40,[175]=30,[200]=50,[250]=30,[1000]=1},   --1000代表免费  其余代表倍率
}

this[10017] = {
    type = "tql_2",
    name = "跳起来2中级场", --游戏名称
    logic = "tql_2", --加载的逻辑
    init_params = {
        lock_pourmoney=5000000,
        pour_money=8000,
        gold_rate = {10,30,50,80,125},  --游戏内下注的倍率
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    min_gold = 100000,
}

this[10018] = {
    type = "tql_2",
    name = "跳起来2高级场", --游戏名称
    logic = "tql_2", --加载的逻辑
    init_params = {
        lock_pourmoney=5000000,
        pour_money=8000,
        gold_rate = {125,250,500,750,1250},  --游戏内下注的倍率
    },
    min_player = 1,
    max_player = 1,
    wait_time = 0, --不需要开房
    price = {0}, --自定义下注
    score = { 3, 5 },
    times = {10,20,30}, --不限局数
    usegold = nil,
    add_robot = nil,
    rate = { 1, 2, 3 },
    min_gold = 1000000,
}

return this