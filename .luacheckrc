std = "lua51"
read_globals = { "renoise" }
max_line_length = 140
codes = true

-- The test fixture supplies Renoise's global API in a standalone Lua process.
files["tests/support/renoise.lua"] = {
	globals = { "renoise" },
}
