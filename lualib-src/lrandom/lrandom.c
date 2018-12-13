/*
* lrandom.c
* random-number library for Lua 5.3 based on the MT19937
*/

#include <math.h>
#include <stdio.h>
#include <time.h>

#include "lua.h"
#include "lauxlib.h"

#define MYTYPE  "lrandom"

/* Period parameters */  
#define N 624
#define M 397
#define MATRIX_A 0x9908b0dfUL   /* constant vector a */
#define UPPER_MASK 0x80000000UL /* most significant w-r bits */
#define LOWER_MASK 0x7fffffffUL /* least significant r bits */

typedef struct {
    unsigned long v[N]; /* the array for the state vector  */
    int i;
} MT;

#define mt  (o->v)
#define mti (o->i)

/* initializes mt[N] with a seed */
static void init_genrand(MT *o, unsigned long s)
{
    mt[0]= s & 0xffffffffUL;
    for (mti=1; mti<N; mti++) {
        mt[mti] = 
      (1812433253UL * (mt[mti-1] ^ (mt[mti-1] >> 30)) + mti); 
        /* See Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier. */
        /* In the previous versions, MSBs of the seed affect   */
        /* only MSBs of the array mt[].                        */
        /* 2002/01/09 modified by Makoto Matsumoto             */
        mt[mti] &= 0xffffffffUL;
        /* for >32 bit machines */
    }
}

/* generates a random number on [0,0xffffffff]-interval */
static unsigned long genrand_int32(MT *o)
{
    unsigned long y;
    static unsigned long mag01[2]={0x0UL, MATRIX_A};
    /* mag01[x] = x * MATRIX_A  for x=0,1 */

    if (mti >= N) { /* generate N words at one time */
        int kk;

        if (mti == N+1)   /* if init_genrand() has not been called, */
            init_genrand(o,5489UL); /* a default initial seed is used */

        for (kk=0;kk<N-M;kk++) {
            y = (mt[kk]&UPPER_MASK)|(mt[kk+1]&LOWER_MASK);
            mt[kk] = mt[kk+M] ^ (y >> 1) ^ mag01[y & 0x1UL];
        }
        for (;kk<N-1;kk++) {
            y = (mt[kk]&UPPER_MASK)|(mt[kk+1]&LOWER_MASK);
            mt[kk] = mt[kk+(M-N)] ^ (y >> 1) ^ mag01[y & 0x1UL];
        }
        y = (mt[N-1]&UPPER_MASK)|(mt[0]&LOWER_MASK);
        mt[N-1] = mt[M-1] ^ (y >> 1) ^ mag01[y & 0x1UL];

        mti = 0;
    }
  
    y = mt[mti++];

    /* Tempering */
    y ^= (y >> 11);
    y ^= (y << 7) & 0x9d2c5680UL;
    y ^= (y << 15) & 0xefc60000UL;
    y ^= (y >> 18);

    return y;
}

/* generates a random number on [0,1)-real-interval */
static double genrand_real2(MT *o)
{
    return genrand_int32(o)*(1.0/4294967296.0); 
    /* divided by 2^32 */
}

/* generates a random number on [0,1) with 53-bit resolution*/
// static double genrand_res53(MT *o) 
// { 
//     unsigned long a=genrand_int32(o)>>5, b=genrand_int32(o)>>6; 
//     return(a*67108864.0+b)*(1.0/9007199254740992.0); 
// } 
// #define genrand  genrand_res53

#define genrand genrand_real2

static FILE* frand = 0;

unsigned int get_seed()
{
	unsigned int num;
	if(!frand)
		frand = fopen("/dev/urandom", "r");

	if(!frand || fread(&num, sizeof(num), 1, frand) <= 0)
	{
	    num = time(0);
	}
	// if(frand)
	// 	fclose(frand);

	return num;
}

static int Lhardrand(lua_State *L)
{
    unsigned int seed = get_seed();
    lua_pushinteger(L,seed);
    return 1;
}

static MT *Pget(lua_State *L, int i)
{
 return luaL_checkudata(L,i,MYTYPE);
}

static MT *Pnew(lua_State *L)
{
 MT *c=lua_newuserdata(L,sizeof(MT));
 luaL_setmetatable(L,MYTYPE);
 return c;
}

static int Lnew(lua_State *L)			/** new() */
{
 MT *c=Pnew(L);
 init_genrand(c, get_seed());
 return 1;
}

static int Lseed(lua_State *L)			/** seed(c) */
{
 MT *c=Pget(L,1);
 init_genrand(c, get_seed());
 lua_settop(L,1);
 return 1;
}

static int Lvalue(lua_State *L)			/** value(c,[a,b]) */
{
 MT *c=Pget(L,1);
 int a,b;
 double r=genrand(c);
 switch (lua_gettop(L))
 {
  case 1:
   lua_pushnumber(L,r);
   return 1;
  case 2:
   a=1;
   b=luaL_checkinteger(L,2);
   break;
  default:
   a=luaL_checkinteger(L,2);
   b=luaL_checkinteger(L,3);
   break;
 }
 if (a>b) { int t=a; a=b; b=t; }
 if (a>b) return 0;
 r=a+floor(r*(b-a+1));
 lua_pushinteger(L,r);
 return 1;
}


int luaopen_lrandom(lua_State *L)
{
  luaL_checkversion(L);
  luaL_newmetatable(L, MYTYPE);
  
  luaL_Reg l[] =
  {
	{ "new", Lnew },
	{ "seed", Lseed },
	{ "value", Lvalue },
    { "hardrand", Lhardrand },
	{ NULL, NULL },
  };

  luaL_newmetatable(L,MYTYPE);
 luaL_setfuncs(L,l,0);
 lua_pushliteral(L,"__index");
 lua_pushvalue(L,-2);
 lua_settable(L,-3);
 lua_pushliteral(L,"__call");     /** __call(c) */
 lua_pushliteral(L,"value");
 lua_gettable(L,-3);
 lua_settable(L,-3);

  return 1;
}