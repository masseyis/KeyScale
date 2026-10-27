-- Small in-memory Renoise fixture. Tests invoke the real registered commands.
local mock = {}

local function note_column()
	local values = { note_value = 121, instrument_value = 255, volume_value = 255 }
	return setmetatable({}, {
		__index = values,
		__newindex = function(_, key, value)
			local limit = key == "note_value" and 121 or 255
			assert(type(value) == "number" and value % 1 == 0 and value >= 0 and value <= limit,
				"Invalid note column value: " .. key .. "=" .. tostring(value))
			values[key] = value
		end,
	})
end

function mock.new(options)
	options = options or {}
	local env = { bindings = {}, menus = {}, statuses = {}, lines = {} }
	local tool, tracks = {}, {}
	function tool.add_keybinding(_, binding)
		assert(not env.bindings[binding.name], "Duplicate binding: " .. binding.name)
		env.bindings[binding.name] = binding.invoke
	end
	function tool.add_menu_entry(_, entry)
		assert(not env.menus[entry.name], "Duplicate menu: " .. entry.name)
		env.menus[entry.name] = entry
	end
	for index, kind in ipairs(options.tracks or { "sequencer", "sequencer", "sequencer", "sequencer", "sequencer", "master" }) do
		local count = kind == "sequencer" and 12 or 0
		tracks[index] = {
			max_note_columns = count,
			visible_note_columns = count > 0 and (options.visible_columns or 1) or 0,
			volume_column_visible = options.volume_visible ~= false,
		}
		env.lines[index] = {}
		for row = 1, 4 do
			local columns = {}
			for col = 1, count do columns[col] = note_column() end
			env.lines[index][row] = {
				note_columns = columns,
				note_column = function(self, col) return assert(self.note_columns[col]) end,
			}
		end
	end
	local pattern = {
		track = function(_, track)
			return { line = function(_, row) return assert(env.lines[track][row]) end }
		end,
	}
	local track = options.track or 1
	local song = {
		tracks = tracks,
		selected_track_index = track,
		selected_pattern_index = 1,
		selected_line_index = 2,
		selected_note_column_index = tracks[track].max_note_columns > 0 and (options.column or 1) or 0,
		selected_instrument_index = 3,
		selected_track = tracks[track],
		selected_line = env.lines[track][2],
		selection_in_pattern = options.selection,
		transport = { keyboard_velocity_enabled = options.velocity_enabled ~= false, keyboard_velocity = 80 },
		track = function(_, index) return assert(tracks[index]) end,
		pattern = function(_, index) assert(index == 1); return pattern end,
	}
	renoise = {
		PatternLine = { EMPTY_NOTE = 121, EMPTY_INSTRUMENT = 255, EMPTY_VOLUME = 255 },
		Document = {
			create = function()
				return function(values)
					local prefs = {}
					for key, value in pairs(values) do prefs[key] = { value = value } end
					return prefs
				end
			end,
		},
		tool = function() return tool end,
		song = function() return song end,
		app = function()
			return { show_status = function(_, message) table.insert(env.statuses, message) end }
		end,
	}
	dofile("main.lua")
	env.prefs, env.song = tool.preferences, song
	env.prefs.same_track.value = options.same_track or false
	env.prefs.chord_index.value = options.chord or 1
	env.prefs.inversion_index.value = options.inversion or 0
	function env:invoke(name)
		assert(self.bindings[name], "Missing keybinding: " .. name)()
	end
	function env:note(track_index, col, row)
		return self.lines[track_index or track][row or 2].note_columns[col or song.selected_note_column_index]
	end
	return env
end

return mock
