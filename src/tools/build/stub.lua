--- @script stub
--- @file src/tools/build/stub.lua
--- @description C source of the game launcher stub, kept as a Lua string so the repo stays 100% Lua.
--- build.lua writes this to a temp folder and compiles it once, then caches the exe in src/bin.

return [[

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

#define MAGIC "MODITPK1"
#define MAGIC_SIZE 8
#define TRAILER_SIZE 16

typedef struct {
    const char *name;
    uint32_t name_len;
    const char *data;
    uint32_t data_len;
} Entry;

static char *payload = NULL;
static Entry *entries = NULL;
static uint32_t entry_count = 0;

static uint32_t read_u32(const unsigned char *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void fatal(const char *message) {
    fprintf(stderr, "%s\n", message);
#ifdef _WIN32
    /* Windows-subsystem builds have no console, so show the error in a dialog */
    MessageBoxA(NULL, message, "Game error", MB_OK | MB_ICONERROR);
#endif
}

static int exe_path(char *buffer, size_t size) {
#ifdef _WIN32
    DWORD length = GetModuleFileNameA(NULL, buffer, (DWORD)size);
    return length > 0 && length < size;
#else
    ssize_t length = readlink("/proc/self/exe", buffer, size - 1);
    if (length <= 0) return 0;
    buffer[length] = '\0';
    return 1;
#endif
}

/* Relative paths (mods, saves, assets) are always relative to the exe, however it was launched */
static void chdir_to_exe(void) {
    char path[4096];
    if (!exe_path(path, sizeof path)) return;

    char *slash = strrchr(path, '/');
    char *backslash = strrchr(path, '\\');

    if (!slash || (backslash && backslash > slash)) {
        slash = backslash;
    }

    if (!slash) return;
    *slash = '\0';

#ifdef _WIN32
    SetCurrentDirectoryA(path);
#else
    if (chdir(path) != 0) return;
#endif
}

/* Reads the attached game data. Returns NULL on success, or an error message */
static const char *load_bundle(void) {
    char path[4096];
    if (!exe_path(path, sizeof path)) return "Could not find the executable path.";

    FILE *file = fopen(path, "rb");
    if (!file) return "Could not open the executable.";

    if (fseek(file, 0, SEEK_END) != 0) { fclose(file); return "Could not read the executable."; }
    long file_size = ftell(file);
    if (file_size < TRAILER_SIZE) { fclose(file); return "No game data is attached to this executable."; }

    unsigned char trailer[TRAILER_SIZE];
    if (fseek(file, file_size - TRAILER_SIZE, SEEK_SET) != 0
        || fread(trailer, 1, TRAILER_SIZE, file) != TRAILER_SIZE) {
        fclose(file);
        return "Could not read the executable.";
    }

    if (memcmp(trailer + 8, MAGIC, MAGIC_SIZE) != 0) {
        fclose(file);
        return "No game data is attached to this executable.\nBuild a game with src/editor/builder/build.lua.";
    }

    entry_count = read_u32(trailer);
    uint32_t payload_size = read_u32(trailer + 4);
    if ((long)payload_size > file_size - TRAILER_SIZE) { fclose(file); return "The game data is corrupt."; }

    payload = (char *)malloc(payload_size > 0 ? payload_size : 1);
    entries = (Entry *)calloc(entry_count > 0 ? entry_count : 1, sizeof(Entry));
    if (!payload || !entries) { fclose(file); return "Out of memory."; }

    if (fseek(file, file_size - TRAILER_SIZE - (long)payload_size, SEEK_SET) != 0
        || fread(payload, 1, payload_size, file) != payload_size) {
        fclose(file);
        return "Could not read the game data.";
    }
    fclose(file);

    size_t offset = 0;
    for (uint32_t i = 0; i < entry_count; i++) {
        const unsigned char *p = (const unsigned char *)payload;

        if (offset + 4 > payload_size) return "The game data is corrupt.";
        uint32_t name_len = read_u32(p + offset);
        offset += 4;

        if (offset + name_len + 4 > payload_size) return "The game data is corrupt.";
        entries[i].name = payload + offset;
        entries[i].name_len = name_len;
        offset += name_len;

        uint32_t data_len = read_u32(p + offset);
        offset += 4;

        if (offset + data_len > payload_size) return "The game data is corrupt.";
        entries[i].data = payload + offset;
        entries[i].data_len = data_len;
        offset += data_len;
    }

    return NULL;
}

static const Entry *find_entry(const char *name, size_t length) {
    for (uint32_t i = 0; i < entry_count; i++) {
        if (entries[i].name_len == length && memcmp(entries[i].name, name, length) == 0) {
            return &entries[i];
        }
    }
    return NULL;
}

static int bundle_has(lua_State *L) {
    size_t length;
    const char *name = luaL_checklstring(L, 1, &length);
    lua_pushboolean(L, find_entry(name, length) != NULL);
    return 1;
}

static int bundle_get(lua_State *L) {
    size_t length;
    const char *name = luaL_checklstring(L, 1, &length);
    const Entry *entry = find_entry(name, length);

    if (entry) {
        lua_pushlstring(L, entry->data, entry->data_len);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int message_handler(lua_State *L) {
    lua_getfield(L, LUA_GLOBALSINDEX, "debug");
    if (!lua_istable(L, -1)) { lua_pop(L, 1); return 1; }

    lua_getfield(L, -1, "traceback");
    if (!lua_isfunction(L, -1)) { lua_pop(L, 2); return 1; }

    lua_pushvalue(L, 1);
    lua_pushinteger(L, 2);
    lua_call(L, 2, 1);
    return 1;
}

int main(int argc, char **argv) {
    chdir_to_exe();

    const char *error = load_bundle();
    if (error) {
        fatal(error);
        return 1;
    }

    const Entry *prelude = find_entry("@prelude", 8);
    if (!prelude) {
        fatal("The game data has no start-up script.");
        return 1;
    }

    lua_State *L = luaL_newstate();
    if (!L) {
        fatal("Could not create the Lua state.");
        return 1;
    }
    luaL_openlibs(L);

    lua_newtable(L);
    for (int i = 0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");

    lua_newtable(L);
    lua_pushcfunction(L, bundle_has);
    lua_setfield(L, -2, "has");
    lua_pushcfunction(L, bundle_get);
    lua_setfield(L, -2, "get");
    lua_setglobal(L, "MODIT_BUNDLE");

    lua_pushcfunction(L, message_handler);
    int handler = lua_gettop(L);

    int status = luaL_loadbuffer(L, prelude->data, prelude->data_len, "=prelude");
    if (status == 0) status = lua_pcall(L, 0, 0, handler);

    if (status != 0) {
        const char *message = lua_tostring(L, -1);
        fatal(message ? message : "Unknown error.");
        lua_close(L);
        return 1;
    }

    lua_close(L);
    return 0;
}
]]