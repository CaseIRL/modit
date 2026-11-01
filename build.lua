--- @file build
--- @description Just a stub, allows for `luajit build.lua <project> [options]` instead of having to use `luajit src/editor/builder/build.lua`

package.path = "./?.lua;./?/init.lua;" .. package.path
require("src.tools.build.build")