# snmercenaries
GAMEID
数据结构 1代表麻将
{
    "12345"://游戏 ID
    {
        "isOpen":true,//游戏是否开启
        "gameStatus" : 1,// 游戏状态 0-正常,1-火热中 
        "closeMessage":"开发中...",//游戏关闭提示语
        "version" : "1.0.1",//版本号
        "packageName":"gcMJ",//包名
        "gameName" : "港城麻将",
​        "molds" : [
​            {
​                "moldId" : 1,//类型 ID
​                "baseScore" : 10,//底分
​                "entranceBound" : 1000,//入场下限，低于该数值不允许入场，-1为不限制
                "entranceLimit" : -1,//入场上限，高于该数值不允许入场，-1为不限制
​                 "moldName" : "体验场",//房间名字，初级场，中级场等
​                 "isOpen" : true//房间是否开启
​            },
​            {}
        ]
    }

}