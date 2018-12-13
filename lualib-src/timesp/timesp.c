#include <time.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <lua.h>
#include <lauxlib.h>
#include <sys/time.h>

static int
get_time(lua_State *L) {
	uint64_t t;
	struct timeval tv;
	gettimeofday(&tv, NULL);
	t = (uint64_t)tv.tv_sec * 1000;
	t += tv.tv_usec / 1000;
	lua_pushinteger(L,t);
	return 1;
}

int
luaopen_timesp(lua_State *L) {
	static const struct luaL_Reg l[] = {
		{ "time" , get_time},
		{ NULL, NULL }
	};
	luaL_newlib(L, l);
	return 1;
}
