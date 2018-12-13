#include <math.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <assert.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "luaconf.h"


#define path_length 30 
#define path_type 400
#define steps 100
#define smooth_value 1  //0 to 1
/*
    1.有两条鱼的路径配置没有path，还有许多重复点的
    2.example in lua
    --test bezier start
    local length 
    LOG_DEBUG("bezier init start")
    for k,v in pairs(fish_path_conf) do
        if v.path then
            length = bezier.init(v.path,#v.path,v.time,v.closePath,v.pathid)
        else
            LOG_DEBUG("this fish no path : "..k)
        end
    end
    --LOG_DEBUG("bezier init end, path number = "..i)
    local x,y,z = bezier.tick(4,6101)  -- time ，pathid
    --test bezier end
*/
struct inputpath
{
    float start_point_x;
    float start_point_y;
    float start_point_z;
    float start_tangent_x;
    float start_tangent_y;
    float start_tangent_z;
    float end_tangent_x;
    float end_tangent_y;
    float end_tangent_z;
    float end_point_x;
    float end_point_y;
    float end_point_z;
    float LastT;
    float length;
};
//static struct inputpath path[path_length]={0};
struct fishpath
{
    int pathid;
    struct inputpath path[path_length]; 
};
static struct fishpath fish_path[path_type]={0};
static int n = 0;
static float total_t;

static int Linit(lua_State* L) 
{
    int i,j,closePath,type=-1;
    float xc1,yc1,zc1,xc2,yc2,zc2,xc3,yc3,zc3,len1,len2,len3,k1,k2,xm1,ym1,zm1,xm2,ym2,zm2;
    float length = 0,current_length;
    float t;
    float   ax, bx, cx,current_point_x,current_point_y,current_point_z;
    float   ay, by, cy,prev_x=0,prev_y=0,prev_z=0;
    float   az, bz, cz;
    
    for (i=0;i<path_type;i++)
    {
        if (fish_path[i].pathid == 0)
        {
            type = i;
            break;
        }
    }   
    assert(i<path_type);
    //int input_num = lua_gettop(L);
    //printf("bezier init ###########\n");
    //printf("input_num = %d\n",input_num);
    fish_path[type].pathid = lua_tonumber(L, 5);
    printf("index = %d,pathid = %d\n",type,fish_path[type].pathid);
    closePath = lua_toboolean(L, 4);
    total_t = lua_tonumber(L, 3);
    //printf("bezier init start total_t = %f\n",total_t);
    j = lua_tonumber(L, 2);
    n = j/3 - 1;
    //printf("path length = %d\n",j);
    lua_pop(L, 1);  
    lua_pop(L, 1);  
    lua_pop(L, 1); 
    lua_pop(L, 1); 
    if (!lua_istable(L, -1)) 
    {
        printf("error! input2 is not a table\n");
        return 1;
    }
    //printf("4\n");
    j = 1;
    for(i=0;i<n;j++)
    {
        //printf("4\n");
        lua_rawgeti(L, -1, j);
         if(i == 0)
        {
            if(j==1)
                fish_path[type].path[i].start_point_x = lua_tonumber(L, -1);
            else if(j==2)
                fish_path[type].path[i].start_point_y = lua_tonumber(L, -1);
            else if(j==3)
                fish_path[type].path[i].start_point_z = lua_tonumber(L, -1);
            else if(j==4)
                fish_path[type].path[i].end_point_x = lua_tonumber(L, -1);
            else if(j==5)
                fish_path[type].path[i].end_point_y = lua_tonumber(L, -1);
            else if(j==6)
            {
                fish_path[type].path[i].end_point_z = lua_tonumber(L, -1);
                i++;
                //printf("7\n");
            }
        }
        else
        {
            if(j==(i*3+4))
                fish_path[type].path[i].end_point_x = lua_tonumber(L, -1);
            else if(j==(i*3+5))
                fish_path[type].path[i].end_point_y = lua_tonumber(L, -1);
            else if(j==(i*3+6))
            {
                fish_path[type].path[i].start_point_x = fish_path[type].path[i-1].end_point_x;
                fish_path[type].path[i].start_point_y = fish_path[type].path[i-1].end_point_y;
                fish_path[type].path[i].start_point_z = fish_path[type].path[i-1].end_point_z;
                fish_path[type].path[i].end_point_z = lua_tonumber(L, -1);
                i++;
                //printf("9\n");
            }
        }
        lua_pop(L, 1);
        //printf("start_point  = %f,%f,%f;\n",path[i].start_point_x,path[i].start_point_y,path[i].start_point_z);
        //printf("end_point  = %f,%f,%f;\n",path[i].end_point_x,path[i].end_point_y,path[i].end_point_z);
    }
    //printf("\n");
    //printf("bezier num n=%d;\n",n);
    if(closePath == 1)
    {
        printf("loop path@@@@@@@@@@@@@@@@@@, pathid = %d\n",fish_path[type].pathid);
        fish_path[type].path[n].start_point_x = fish_path[type].path[n-1].end_point_x;
        fish_path[type].path[n].start_point_y = fish_path[type].path[n-1].end_point_y;
        fish_path[type].path[n].start_point_z = fish_path[type].path[n-1].end_point_z;
        fish_path[type].path[n].end_point_x = fish_path[type].path[0].start_point_x;
        fish_path[type].path[n].end_point_y = fish_path[type].path[0].start_point_y;
        fish_path[type].path[n].end_point_z = fish_path[type].path[0].start_point_z;
        n++;
    }
    //get the control point
    for(i=0;i<n;i++)
    {
        // 1. x0,x1,x2,x3;假设控制点在(x1,y1)和(x2,y2)之间，第一个点和最后一个点分别是曲线路径上的上一个点和下一个点
        // 2.求中点
        // 3.求各中点连线长度
        //printf("get the control point i=%d;\n",i);
        //printf("start_point  = %f,%f,%f;\n",path[i].start_point_x,path[i].start_point_y,path[i].start_point_z);
        //printf("end_point  = %f,%f,%f;\n",path[i].end_point_x,path[i].end_point_y,path[i].end_point_z);
        if(i==0)
        {
            xc1 = fish_path[type].path[i].start_point_x;//任意指定
            yc1 = fish_path[type].path[i].start_point_y;//任意指定
            zc1 = fish_path[type].path[i].start_point_z;//任意指定
            len1 = 0;
        }
        else
        {
            xc1 = (fish_path[type].path[i-1].start_point_x + fish_path[type].path[i].start_point_x) / 2.0;
            yc1 = (fish_path[type].path[i-1].start_point_y + fish_path[type].path[i].start_point_y) / 2.0;
            zc1 = (fish_path[type].path[i-1].start_point_z + fish_path[type].path[i].start_point_z) / 2.0;
            len1 = sqrt(pow((fish_path[type].path[i].start_point_x - fish_path[type].path[i-1].start_point_x),2)  + 
                pow((fish_path[type].path[i].start_point_y - fish_path[type].path[i-1].start_point_y),2) + 
                pow((fish_path[type].path[i].start_point_z - fish_path[type].path[i-1].start_point_z),2));
        }
        //printf("xc1,yc1,zc1 = %f,%f,%f,len1=%f;\n",xc1,yc1,zc1,len1);
        xc2 = (fish_path[type].path[i].end_point_x + fish_path[type].path[i].start_point_x) / 2.0;
        yc2 = (fish_path[type].path[i].end_point_y + fish_path[type].path[i].start_point_y) / 2.0;
        zc2 = (fish_path[type].path[i].end_point_z + fish_path[type].path[i].start_point_z) / 2.0;
        len2 = sqrt(pow((fish_path[type].path[i].end_point_x - fish_path[type].path[i].start_point_x),2)  + 
                pow((fish_path[type].path[i].end_point_y - fish_path[type].path[i].start_point_y),2) + 
                pow((fish_path[type].path[i].end_point_z - fish_path[type].path[i].start_point_z),2));
        //printf("xc2,yc2,zc2 = %f,%f,%f,len2=%f;\n",xc2,yc2,zc2,len2);
        if(len2 == 0)
        {
            printf("start point eaqul to end point,pathid = %d\n",fish_path[type].pathid);
            //assert(0);
        }
        if((i+1)==n)
        {
            xc3 = fish_path[type].path[i].end_point_x;//任意指定
            yc3 = fish_path[type].path[i].end_point_y;//任意指定
            zc3 = fish_path[type].path[i].end_point_z;//任意指定
            len3 = 0;
        }
        else
        {
            xc3 = (fish_path[type].path[i+1].start_point_x + fish_path[type].path[i+1].end_point_x) / 2.0;
            yc3 = (fish_path[type].path[i+1].start_point_y + fish_path[type].path[i+1].end_point_y) / 2.0;
            zc3 = (fish_path[type].path[i+1].start_point_z + fish_path[type].path[i+1].end_point_z) / 2.0;
            len3 = sqrt(pow((fish_path[type].path[i+1].start_point_x - fish_path[type].path[i+1].end_point_x),2)  + 
                pow((fish_path[type].path[i+1].start_point_y - fish_path[type].path[i+1].end_point_y),2) + 
                pow((fish_path[type].path[i+1].start_point_z - fish_path[type].path[i+1].end_point_z),2));
        }
        //printf("xc3,yc3,zc3 = %f,%f,%f,len3=%f;\n",xc3,yc3,zc3,len3);
        // 4.求中点连线长度比例（用来确定平移前p2, p3的位置）
        k1 = len1 / (len1 + len2);
        k2 = len2 / (len2 + len3);
        // 5.平移p2
        xm1 = xc1 + (xc2 - xc1) * k1;
        ym1 = yc1 + (yc2 - yc1) * k1;
        zm1 = zc1 + (zc2 - zc1) * k1;
        // 6.平移p3
        xm2 = xc2 + (xc3 - xc2) * k2;
        ym2 = yc2 + (yc3 - yc2) * k2;
        zm2 = zc2 + (zc3 - zc2) * k2;
        //printf("k1,k2,xm1,ym1,zm1,xm2,ym2,zm2 = %f,%f,%f,%f,%f,%f,%f,%f;\n",k1,k2,xm1,ym1,zm1,xm2,ym2,zm2);
        // Resulting control points. Here smooth_value is mentioned
        // above coefficient K whose value should be in range [0...1].
        // 7.微调控制点与顶点之间的距离，越大曲线越平直
        /*起点和终点坐标的确定办法，xy坐标上垂直点，示意：|————|，即起点逆时针旋转90度，终点也逆时针旋转90度，长度是起点到终点距离的一半
        (x, y)绕(0, 0)顺时针转90度后坐标为(y, -x)
        (x, y)绕(p, q)顺时针转90度，先把原点移到(p, q), (x-p, y-q)绕(0, 0)旋转90度后为(y-q, p-x)
        最终结果(y-q+p, p-x+q)
        如果逆时针，（-y,x）,last (q-y,x-p), (p+q
        -y,q-p+x)
        起点坐标（x1,y1,z1）, 中心点坐标（xd,yd,zd）,终点坐标(x2,y2,z2)
        control point1: (x1+y1-yd,y1-x1+xd,z1)
        control point2: (x2+y2-yd,y2-x2+xd,z2)  (x2-y2+yd,x2+y2-xd,z2)*/
        if(i==0)
        {
            fish_path[type].path[i].start_tangent_x = fish_path[type].path[0].start_point_x + fish_path[type].path[0].start_point_y - yc2;
            fish_path[type].path[i].start_tangent_y = fish_path[type].path[0].start_point_y - fish_path[type].path[0].start_point_x + xc2;;
            fish_path[type].path[i].start_tangent_z = fish_path[type].path[0].start_point_z;
        }
        else
        {
            fish_path[type].path[i].start_tangent_x = (xc2 - xm1) * smooth_value + fish_path[type].path[i].start_point_x;
            fish_path[type].path[i].start_tangent_y = (yc2 - ym1) * smooth_value + fish_path[type].path[i].start_point_y;
            fish_path[type].path[i].start_tangent_z = (zc2 - zm1) * smooth_value + fish_path[type].path[i].start_point_z;
        }
        
        if((i+1)==n)
        {
            fish_path[type].path[i].end_tangent_x = fish_path[type].path[i].end_point_x + fish_path[type].path[i].end_point_y - yc2;
            fish_path[type].path[i].end_tangent_y = fish_path[type].path[i].end_point_y - fish_path[type].path[i].end_point_x + xc2;;
            fish_path[type].path[i].end_tangent_z = fish_path[type].path[i].end_point_z;
        }
        else
        {
            fish_path[type].path[i].end_tangent_x = (xc2 - xm2) * smooth_value + fish_path[type].path[i].end_point_x;
            fish_path[type].path[i].end_tangent_y = (yc2 - ym2) * smooth_value + fish_path[type].path[i].end_point_y;
            fish_path[type].path[i].end_tangent_z = (zc2 - zm2) * smooth_value + fish_path[type].path[i].end_point_z;
        }
        //printf("start_tangent_x,start_tangent_y,start_tangent_z = %f,%f,%f;\n",path[i].start_tangent_x,path[i].start_tangent_y,path[i].start_tangent_z);
        //printf("end_tangent_x,end_tangent_y,end_tangent_z = %f,%f,%f;\n",path[i].end_tangent_x,path[i].end_tangent_y,path[i].end_tangent_z);
    }
    //get the bezier length
    length = 0;
    for(i=0;i<n;i++)
    {
        //printf("get the bezier length i=%d;\n",i);
        fish_path[type].path[i].length = 0;
        cx = 3.0 * (fish_path[type].path[i].start_tangent_x - fish_path[type].path[i].start_point_x);
        bx = 3.0 * (fish_path[type].path[i].end_tangent_x - fish_path[type].path[i].start_tangent_x) - cx;
        ax = fish_path[type].path[i].end_point_x - fish_path[type].path[i].start_point_x - cx - bx;

        cy = 3.0 * (fish_path[type].path[i].start_tangent_y - fish_path[type].path[i].start_point_y);
        by = 3.0 * (fish_path[type].path[i].end_tangent_y - fish_path[type].path[i].start_tangent_y) - cy;
        ay = fish_path[type].path[i].end_point_y - fish_path[type].path[i].start_point_y - cy - by;

        cz = 3.0 * (fish_path[type].path[i].start_tangent_z - fish_path[type].path[i].start_point_z);
        bz = 3.0 * (fish_path[type].path[i].end_tangent_z - fish_path[type].path[i].start_tangent_z) - cz;
        az = fish_path[type].path[i].end_point_z - fish_path[type].path[i].start_point_z - cz - bz;

        for(j=0;j<steps;j++)
        {
            t = (j+0.0)/steps;

            current_point_x = (ax * t * t *t) + (bx * t * t) + (cx * t) + fish_path[type].path[i].start_point_x;
            current_point_y = (ay * t * t *t) + (by * t * t) + (cy * t) + fish_path[type].path[i].start_point_y;
            current_point_z = (az * t * t *t) + (bz * t * t) + (cz * t) + fish_path[type].path[i].start_point_z;
            //printf("t=%f,current_point=%f,%f,%f\n",t,current_point_x,current_point_y,current_point_z);

            if(j>0)
            {
                current_length= sqrt(pow((prev_x - current_point_x),2)  + 
                pow((prev_y - current_point_y),2) + 
                pow((prev_z - current_point_z),2));
                fish_path[type].path[i].length += current_length;
                //printf("j=%d,current_length=%f;\n",j,current_length);
            }
            prev_x = current_point_x;
            prev_y = current_point_y;
            prev_z = current_point_z;
        }
        current_length = sqrt(pow((fish_path[type].path[i].end_point_x - current_point_x),2)  + 
                pow((fish_path[type].path[i].end_point_y - current_point_y),2) + 
                pow((fish_path[type].path[i].end_point_z - current_point_z),2));
        fish_path[type].path[i].length += current_length;
        //printf("j=%d,current_length=%f, the i length = %f;\n",j,current_length,fish_path[type].path[i].length);
        length += fish_path[type].path[i].length;
    }
    for(i=0;i<n;i++)
    {
        if(i==0)
            fish_path[type].path[i].LastT = fish_path[type].path[i].length/length;
        else
            fish_path[type].path[i].LastT = fish_path[type].path[i-1].LastT + fish_path[type].path[i].length/length;
    }
    printf("bezier init end, the bezier length=%f,pathid = %d\n",length,fish_path[type].pathid);
    lua_pushnumber(L,length);
    return 1;
}

static  int Ltick(lua_State *L)
{
    float start_point_x=0;
    float start_point_y=0;
    float start_point_z=0;
    float start_tangent_x=0;
    float start_tangent_y=0;
    float start_tangent_z=0;
    float end_tangent_x=0;
    float end_tangent_y=0;
    float end_tangent_z=0;
    float end_point_x=0;
    float end_point_y=0;
    float end_point_z=0;
    float current_t = lua_tonumber(L, 1);
    int pathid = lua_tonumber(L, 2);
    printf("bezier tick start\n");
    printf("Ltick current_t = %f,pathid = %d; \n",current_t,pathid);
    int i = 0,type = -1;
    float t;

    float   ax, bx, cx, current_point;
    float   ay, by, cy;
    float   az, bz, cz;
    
    for (i=0;i<path_type;i++)
    {
        if (fish_path[i].pathid == pathid)
        {
            type = i;
            break;
        }
    }   
    assert(i<path_type);
    current_t = current_t/total_t;
    //printf("Ltick t = %f; \n",current_t);
    //printf("Ltick path[0].LastT = %f; \n",path[0].LastT);
    for(i=0;i<n;i++)
    {
        if(current_t < fish_path[type].path[i].LastT)
        {
            start_point_x = fish_path[type].path[i].start_point_x;
            start_point_y = fish_path[type].path[i].start_point_y;
            start_point_z = fish_path[type].path[i].start_point_z;
            start_tangent_x = fish_path[type].path[i].start_tangent_x;
            start_tangent_y = fish_path[type].path[i].start_tangent_y;
            start_tangent_z = fish_path[type].path[i].start_tangent_z;
            end_point_x = fish_path[type].path[i].end_point_x;
            end_point_y = fish_path[type].path[i].end_point_y;
            end_point_z = fish_path[type].path[i].end_point_z;
            end_tangent_x = fish_path[type].path[i].end_tangent_x;
            end_tangent_y = fish_path[type].path[i].end_tangent_y;
            end_tangent_z = fish_path[type].path[i].end_tangent_z;
            break;
        }
    }
    if(i==0)
        total_t = fish_path[type].path[0].LastT; 
    else
    {
        current_t -= fish_path[type].path[i-1].LastT;
        total_t = fish_path[type].path[i].LastT - fish_path[type].path[i-1].LastT;
    }
    printf("start_point = %f,%f,%f; \n",start_point_x,start_point_y,start_point_z);
    printf("start_tangent = %f,%f,%f; \n",start_tangent_x,start_tangent_y,start_tangent_z);
    printf("end_point = %f,%f,%f; \n",end_point_x,end_point_y,end_point_z);
    printf("end_tangent = %f,%f,%f; \n",end_tangent_x,end_tangent_y,end_tangent_z);
    cx = 3.0 * (start_tangent_x - start_point_x);
    bx = 3.0 * (end_tangent_x - start_tangent_x) - cx;
    ax = end_point_x - start_point_x - cx - bx;

    cy = 3.0 * (start_tangent_y - start_point_y);
    by = 3.0 * (end_tangent_y - start_tangent_y) - cy;
    ay = end_point_y - start_point_y - cy - by;

    cz = 3.0 * (start_tangent_z - start_point_z);
    bz = 3.0 * (end_tangent_z - start_tangent_z) - cz;
    az = end_point_z - start_point_z - cz - bz;
    //printf("ax = %f; bx = %f; cx = %f; \n",ax,bx,cx);
    t = current_t/total_t;
    for(i=0;i<3;i++)
    {
        if(i==0)
            current_point = (ax * t * t *t) + (bx * t * t) + (cx * t) + start_point_x;
        else if(i==1)
            current_point = (ay * t * t *t) + (by * t * t) + (cy * t) + start_point_y;
        else
            current_point = (az * t * t *t) + (bz * t * t) + (cz * t) + start_point_z;
        printf("output point(%f) = %f\n",t,current_point);
        lua_pushnumber(L,current_point);
    }	
    return 3;
}


 int luaopen_lbezier(lua_State* L) 
 {
     //const char* libName = "lbezier";
     //luaL_register(L,libName,mylibs);

    luaL_checkversion(L);
    luaL_Reg l[] = {
        {"init", Linit},
        {"tick", Ltick},
        {NULL, NULL} 
    };
    luaL_newlib(L,l);
    luaL_setfuncs(L, l, 0);

    return 1;
 }