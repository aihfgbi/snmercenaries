/* 
    MT19937-64
*/
#include <stdint.h>
#include <stdio.h>
#include <time.h>
#include <math.h>
#include <stdlib.h>

#include <lua.h>
#include <lauxlib.h>

#define NN 312
#define MM 156
#define MATRIX_A UINT64_C(0xB5026F5AA96619E9)
#define UM UINT64_C(0xFFFFFFFF80000000) /* Most significant 33 bits */
#define LM UINT64_C(0x7FFFFFFF) /* Least significant 31 bits */


typedef struct {
    uint64_t v[NN]; /* the array for the state vector  */
    int i; /* mti==NN+1 means mt[NN] is not initialized */
} MT;

#define mt  (o->v)
#define mti (o->i)

void init_by_urandom(MT *o);

/* initializes mt[NN] with a seed */
void init_genrand64(MT *o, uint64_t seed)
{
    mt[0] = seed;
    for (mti=1; mti<NN; mti++) 
        mt[mti] =  (UINT64_C(6364136223846793005) * (mt[mti-1] ^ (mt[mti-1] >> 62)) + mti);
}

/* initialize by an array with array-length */
/* init_key is the array for initializing keys */
/* key_length is its length */
void init_by_array64(MT *o, uint64_t init_key[],
                                    uint64_t key_length)
{
    unsigned int i, j;
    uint64_t k;
    init_genrand64(o, UINT64_C(19650218));
    i=1; j=0;
    k = (NN>key_length ? NN : key_length);
    for (; k; k--) {
        mt[i] = (mt[i] ^ ((mt[i-1] ^ (mt[i-1] >> 62)) * UINT64_C(3935559000370003845)))
          + init_key[j] + j; /* non linear */
        i++; j++;
        if (i>=NN) { mt[0] = mt[NN-1]; i=1; }
        if (j>=key_length) j=0;
    }
    for (k=NN-1; k; k--) {
        mt[i] = (mt[i] ^ ((mt[i-1] ^ (mt[i-1] >> 62)) * UINT64_C(2862933555777941757)))
          - i; /* non linear */
        i++;
        if (i>=NN) { mt[0] = mt[NN-1]; i=1; }
    }

    mt[0] = UINT64_C(1) << 63; /* MSB is 1; assuring non-zero initial array */ 
}

/* generates a random number on [0, 2^64-1]-interval */
uint64_t genrand64_int64(MT *o)
{
    int i;
    uint64_t x;
    static uint64_t mag01[2]={UINT64_C(0), MATRIX_A};

    if (mti >= NN) { /* generate NN words at one time */

        /* if init_genrand64() has not been called, */
        /* a default initial seed is used     */
        if (mti == NN+1) 
            init_by_urandom(o); 

        for (i=0;i<NN-MM;i++) {
            x = (mt[i]&UM)|(mt[i+1]&LM);
            mt[i] = mt[i+MM] ^ (x>>1) ^ mag01[(int)(x&UINT64_C(1))];
        }
        for (;i<NN-1;i++) {
            x = (mt[i]&UM)|(mt[i+1]&LM);
            mt[i] = mt[i+(MM-NN)] ^ (x>>1) ^ mag01[(int)(x&UINT64_C(1))];
        }
        x = (mt[NN-1]&UM)|(mt[0]&LM);
        mt[NN-1] = mt[MM-1] ^ (x>>1) ^ mag01[(int)(x&UINT64_C(1))];

        mti = 0;
    }
  
    x = mt[mti++];

    x ^= (x >> 29) & UINT64_C(0x5555555555555555);
    x ^= (x << 17) & UINT64_C(0x71D67FFFEDA60000);
    x ^= (x << 37) & UINT64_C(0xFFF7EEE000000000);
    x ^= (x >> 43);

    return x;
}

/* generates a random number on [0, 2^63-1]-interval */
int64_t genrand64_int63(MT *o)
{
    return (int64_t)(genrand64_int64(o) >> 1);
}

/* generates a random number on [0,1]-real-interval */
double genrand64_real1(MT *o)
{
    return (genrand64_int64(o) >> 11) * (1.0/9007199254740991.0);
}

/* generates a random number on [0,1)-real-interval */
double genrand64_real2(MT *o)
{
    return (genrand64_int64(o) >> 11) * (1.0/9007199254740992.0);
}

/* generates a random number on (0,1)-real-interval */
double genrand64_real3(MT *o)
{
    return ((genrand64_int64(o) >> 12) + 0.5) * (1.0/4503599627370496.0);
}

/* hard */

static FILE* _f_rand = 0;

uint32_t read_urandom()
{
    uint32_t num = 0;
    if(!_f_rand)
        _f_rand = fopen("/dev/urandom", "r");

    if(!_f_rand || fread(&num, sizeof(num), 1, _f_rand) <= 0)
    {
        num = random();
    }

    // if(_f_rand)
    //  fclose(_f_rand);
    return num;
}

uint64_t get_seed64()
{
    uint64_t seed = read_urandom();
    uint32_t now = time(0);

    seed = seed<<32;
    seed = seed | now;
    return seed;
}

void init_by_urandom(MT *o)
{
    int i;
    uint64_t init[32];

    for (i = 0; i < 32; ++i)
        init[i] = get_seed64();

    init_by_array64(o, init, 32);

    for (i = 0; i < 5000; ++i)
        genrand64_int64(o);
}

static __thread MT _mt = { .i = NN+1 };
static int Lrandom(lua_State *L)           /** random([a,b]) */
{
    MT *o = &_mt;
    uint64_t min, max;
    switch (lua_gettop(L))
    {
        case 0:
        {   
            min = genrand64_int64(o);
            lua_pushinteger(L, min);
            return 1;
        }
        case 1:
        {
            min = 1;
            max = luaL_checkinteger(L, 1);
            break;
        }
        default:
        {
            min = luaL_checkinteger(L, 1);
            max = luaL_checkinteger(L, 2);
            break;
        }
    }

    if (min > max) 
    { 
        uint64_t t = min; 
        min = max; 
        max = t; 
    }
    if (min > max) 
    {
        lua_pushinteger(L, min);
        return 1;
    }

    double r = genrand64_real1(o);
    r = min + floor(r * (max-min+1));
    lua_pushinteger(L, r);
    return 1;
}

int luaopen_lrandom64(lua_State *L)
{
    luaL_checkversion(L);

    luaL_Reg l[] = {
        { "random", Lrandom },
        { NULL, NULL },
    };
    luaL_newlib(L,l);

    return 1;
}