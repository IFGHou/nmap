/*
** $Id: ltablib.c,v 1.38.1.2 2007/12/28 15:32:23 roberto Exp $
** Library for Table Manipulation
** See Copyright Notice in lua.h
*/


#include <stddef.h>

#define ltablib_c
#define LUA_LIB

#include "lua.h"

#include "lauxlib.h"
#include "lualib.h"


#define aux_getn(L,n)	(luaL_checktype(L, n, LUA_TTABLE), luaL_getn(L, n))


static int foreachi (lua_State *L) {
  int i;
  int n = aux_getn(L, 1);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  for (i=1; i <= n; i++) {
    lua_pushvalue(L, 2);  /* function */
    lua_pushinteger(L, i);  /* 1st argument */
    lua_rawgeti(L, 1, i);  /* 2nd argument */
    lua_call(L, 2, 1);
    if (!lua_isnil(L, -1))
      return 1;
    lua_pop(L, 1);  /* remove nil result */
  }
  return 0;
}


static int foreach (lua_State *L) {
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  lua_pushnil(L);  /* first key */
  while (lua_next(L, 1)) {
    lua_pushvalue(L, 2);  /* function */
    lua_pushvalue(L, -3);  /* key */
    lua_pushvalue(L, -3);  /* value */
    lua_call(L, 2, 1);
    if (!lua_isnil(L, -1))
      return 1;
    lua_pop(L, 2);  /* remove value and result */
  }
  return 0;
}


static int maxn (lua_State *L) {
  lua_Number max = 0;
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_pushnil(L);  /* first key */
  while (lua_next(L, 1)) {
    lua_pop(L, 1);  /* remove value */
    if (lua_type(L, -1) == LUA_TNUMBER) {
      lua_Number v = lua_tonumber(L, -1);
      if (v > max) max = v;
    }
  }
  lua_pushnumber(L, max);
  return 1;
}


static int getn (lua_State *L) {
  lua_pushinteger(L, aux_getn(L, 1));
  return 1;
}


static int setn (lua_State *L) {
  luaL_checktype(L, 1, LUA_TTABLE);
#ifndef luaL_setn
  luaL_setn(L, 1, luaL_checkint(L, 2));
#else
  luaL_error(L, LUA_QL("setn") " is obsolete");
#endif
  lua_pushvalue(L, 1);
  return 1;
}


static int tinsert (lua_State *L) {
  int e = aux_getn(L, 1) + 1;  /* first empty element */
  int pos;  /* where to insert new element */
  switch (lua_gettop(L)) {
    case 2: {  /* called with only 2 arguments */
      pos = e;  /* insert new element at the end */
      break;
    }
    case 3: {
      int i;
      pos = luaL_checkint(L, 2);  /* 2nd argument is the position */
      if (pos > e) e = pos;  /* `grow' array if necessary */
      for (i = e; i > pos; i--) {  /* move up elements */
        lua_rawgeti(L, 1, i-1);
        lua_rawseti(L, 1, i);  /* t[i] = t[i-1] */
      }
      break;
    }
    default: {
      return luaL_error(L, "wrong number of arguments to " LUA_QL("insert"));
    }
  }
  luaL_setn(L, 1, e);  /* new size */
  lua_rawseti(L, 1, pos);  /* t[pos] = v */
  return 0;
}


static int tremove (lua_State *L) {
  int e = aux_getn(L, 1);
  int pos = luaL_optint(L, 2, e);
  if (!(1 <= pos && pos <= e))  /* position is outside bounds? */
   return 0;  /* nothing to remove */
  luaL_setn(L, 1, e - 1);  /* t.n = n-1 */
  lua_rawgeti(L, 1, pos);  /* result = t[pos] */
  for ( ;pos<e; pos++) {
    lua_rawgeti(L, 1, pos+1);
    lua_rawseti(L, 1, pos);  /* t[pos] = t[pos+1] */
  }
  lua_pushnil(L);
  lua_rawseti(L, 1, e);  /* t[e] = nil */
  return 1;
}


static int tconcat (lua_State *L) {
  luaL_Buffer b;
  size_t lsep;
  int i, last;
  const char *sep = luaL_optlstring(L, 2, "", &lsep);
  luaL_checktype(L, 1, LUA_TTABLE);
  i = luaL_optint(L, 3, 1);
  last = luaL_opt(L, luaL_checkint, 4, luaL_getn(L, 1));
  luaL_buffinit(L, &b);
  for (; i <= last; i++) {
    lua_rawgeti(L, 1, i);
    luaL_argcheck(L, lua_isstring(L, -1), 1, "table contains non-strings");
    luaL_addvalue(&b);
    if (i != last)
      luaL_addlstring(&b, sep, lsep);
  }
  luaL_pushresult(&b);
  return 1;
}



/*
** {======================================================
** Quicksort
** (based on `Algorithms in MODULA-3', Robert Sedgewick;
**  Addison-Wesley, 1993.)
*/


static void set2 (lua_State *L, int i, int j) {
  lua_rawseti(L, 1, i);
  lua_rawseti(L, 1, j);
}

static int sort_comp (lua_State *L, int a, int b) {
  if (!lua_isnil(L, 2)) {  /* function? */
    int res;
    lua_pushvalue(L, 2);
    lua_pushvalue(L, a-1);  /* -1 to compensate function */
    lua_pushvalue(L, b-2);  /* -2 to compensate function and `a' */
    lua_call(L, 2, 1);
    res = lua_toboolean(L, -1);
    lua_pop(L, 1);
    return res;
  }
  else  /* a < b? */
    return lua_lessthan(L, a, b);
}

static int call_comp (lua_State *L)
{
  int res;
  lua_pushvalue(L, 2);
  lua_pushvalue(L, -2);
  lua_pushvalue(L, -4);
  lua_call(L, 2, 1);
  res = lua_toboolean(L, -1);
  lua_pop(L, 1);
  return res;
}

#define compare(L, c)  (c ? call_comp(L) : lua_lessthan(L, -1, -2))

static int partition (lua_State *L, int p, int r, int c)
{
  int i = p - 1, j;
  lua_rawgeti(L, 1, r);
  /* for r - p = 1 */
  if (p - r == 1)
  {
    lua_rawgeti(L, 1, p);
    if (!compare(L, c))
    {
      lua_rawseti(L, 1, r);
      lua_rawseti(L, 1, p);
    }
    else
      lua_pop(L, 2);
    return i + 1;
  }
  for (j = p; j < r; j++)
  {
    lua_rawgeti(L, 1, j);
    if (compare(L, c))
    {
      i++;
      lua_rawgeti(L, 1, i);
      lua_pushvalue(L, -2);
      lua_rawseti(L, 1, i);
      lua_rawseti(L, 1, j);
    }
    lua_pop(L, 1);
  }
  lua_pop(L, 1);
  i++;
  lua_rawgeti(L, 1, r);
  lua_rawgeti(L, 1, i);
  lua_rawseti(L, 1, r);
  lua_rawseti(L, 1, i);
  return i;
}

static void quicksort (lua_State *L, int p, int r, int c)
{
  if (p < r)
  {
    int q = partition(L, p, r, c);
    quicksort(L, p, q - 1, c);
    quicksort(L, q + 1, r, c);
  }
}
static int calls = 0;

static void auxsort (lua_State *L, int l, int u) {
  calls++;
  if (calls > 20)
    printf("calls = %d; l = %d; u = %d;\n", calls, l, u);
  while (l < u) {  /* for tail recursion */
    int i, j;
    /* sort elements a[l], a[(l+u)/2] and a[u] */
    lua_rawgeti(L, 1, l);
    lua_rawgeti(L, 1, u);
    if (sort_comp(L, -1, -2))  /* a[u] < a[l]? */
      set2(L, l, u);  /* swap a[l] - a[u] */
    else
      lua_pop(L, 2);
    if (u-l == 1) break;  /* only 2 elements */
    i = (l+u)/2;
    lua_rawgeti(L, 1, i);
    lua_rawgeti(L, 1, l);
    if (sort_comp(L, -2, -1))  /* a[i]<a[l]? */
      set2(L, i, l);
    else {
      lua_pop(L, 1);  /* remove a[l] */
      lua_rawgeti(L, 1, u);
      if (sort_comp(L, -1, -2))  /* a[u]<a[i]? */
        set2(L, i, u);
      else
        lua_pop(L, 2);
    }
    if (u-l == 2) break;  /* only 3 elements */
    lua_rawgeti(L, 1, i);  /* Pivot */
    lua_pushvalue(L, -1);
    lua_rawgeti(L, 1, u-1);
    set2(L, i, u-1);
    /* a[l] <= P == a[u-1] <= a[u], only need to sort from l+1 to u-2 */
    i = l; j = u-1;
    for (;;) {  /* invariant: a[l..i] <= P <= a[j..u] */
      /* repeat ++i until a[i] >= P */
      while (lua_rawgeti(L, 1, ++i), sort_comp(L, -1, -2)) {
        if (i>u) luaL_error(L, "invalid order function for sorting");
        lua_pop(L, 1);  /* remove a[i] */
      }
      /* repeat --j until a[j] <= P */
      while (lua_rawgeti(L, 1, --j), sort_comp(L, -3, -1)) {
        if (j<l) luaL_error(L, "invalid order function for sorting");
        lua_pop(L, 1);  /* remove a[j] */
      }
      if (j<i) {
        lua_pop(L, 3);  /* pop pivot, a[i], a[j] */
        break;
      }
      set2(L, i, j);
    }
    lua_rawgeti(L, 1, u-1);
    lua_rawgeti(L, 1, i);
    set2(L, u-1, i);  /* swap pivot (a[u-1]) with a[i] */
    /* a[l..i-1] <= a[i] == P <= a[i+1..u] */
    /* adjust so that smaller half is in [j..i] and larger one in [l..u] */
    if (i-l < u-i) {
      j=l; i=i-1; l=i+2;
    }
    else {
      j=i+1; i=u; u=j-2;
    }
    auxsort(L, j, i);  /* call recursively the smaller one */
  }  /* repeat the routine for the larger one */
  calls--;
}

static int sort (lua_State *L) {
  int n = aux_getn(L, 1);
  int c;
  lua_settop(L, 2);  /* make sure there is two arguments */
  luaL_checkstack(L, 40, "");  /* assume array is smaller than 2^40 */
  if ((c = (!lua_isnil(L, 2))))  /* is there a 2nd argument? */
    luaL_checktype(L, 2, LUA_TFUNCTION);
  quicksort(L, 1, n, c);
  return 0;
}

static int oldsort (lua_State *L) {
  int n = aux_getn(L, 1);
  lua_settop(L, 2);  /* make sure there is two arguments */
  luaL_checkstack(L, 40, "");  /* assume array is smaller than 2^40 */
  if (!lua_isnil(L, 2))  /* is there a 2nd argument? */
    luaL_checktype(L, 2, LUA_TFUNCTION);
  auxsort(L, 1, n);
  return 0;
}

/* }====================================================== */


static const luaL_Reg tab_funcs[] = {
  {"concat", tconcat},
  {"foreach", foreach},
  {"foreachi", foreachi},
  {"getn", getn},
  {"maxn", maxn},
  {"insert", tinsert},
  {"remove", tremove},
  {"setn", setn},
  {"sort", sort},
  {"oldsort", oldsort},
  {NULL, NULL}
};


LUALIB_API int luaopen_table (lua_State *L) {
  luaL_register(L, LUA_TABLIBNAME, tab_funcs);
  return 1;
}

