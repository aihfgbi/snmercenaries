# snmercenaries
GAMEID
数据结构 1代表麻将
gamelist = {
    1 = {
        bool isopen = true;//游戏是否开启
	    string version = "1.0.1";//版本号,控制热更新
	    string gamename = “港城麻将”;//游戏名字
        roomlist = {
            {
                int32 roomid = 1;//房间id
                int32 basescore = 10;//底分，单位：分
                int32 goldlimit = 1000;//入场限制，单位：分
                string roomname = "体验场";//房间名字，初级场，中级场等
                bool isopen = true;//房间是否开启
            },
            {
                int32 roomid = 2;//房间id
                int32 basescore = -1;//底分，单位：分，玩家选择
                int32 goldlimit = -1;//入场限制，单位：分，玩家选择
                string roomname = "私人场";//房间名字，初级场，中级场等
                bool isopen = false;//房间是否开启
            },

        }
    },
    2 = {
        ...
    }
}