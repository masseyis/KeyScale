-- Run from the repository root: lua5.1 tests/chord_track_boundaries.lua
-- Simulates only the Renoise API needed to exercise the registered chord commands.
local bindings, song, statuses = {}, nil, {}
local tool = {}
function tool:add_keybinding(binding)
	bindings[binding.name] = binding.invoke
end
function tool:add_menu_entry() end

renoise = {
	PatternLine = { EMPTY_NOTE = 121, EMPTY_INSTRUMENT = 255, EMPTY_VOLUME = 255 },
	Document = {
		create = function()
			return function(values)
				local prefs = {}
				for key, value in pairs(values) do
					prefs[key] = { value = value }
				end
				return prefs
			end
		end,
	},
	tool = function() return tool end,
	song = function() return song end,
	app = function()
		return { show_status = function(_, message) table.insert(statuses, message) end }
	end,
}

local function setup(track_types, same_track, selected_track)
	local tracks, lines = {}, {}
	statuses = {}
	for index, kind in ipairs(track_types) do
		local count = kind == "sequencer" and 12 or 0
		tracks[index] = {
			max_note_columns = count,
			visible_note_columns = count > 0 and 1 or 0,
			volume_column_visible = true,
		}
		local columns = {}
		for column = 1, count do
			columns[column] = { note_value = 121, instrument_value = 255, volume_value = 255 }
		end
		lines[index] = {
			note_columns = columns,
			note_column = function(self, column) return self.note_columns[column] end,
		}
	end
	local pattern = {
		track = function(_, index)
			return { line = function() return lines[index] end }
		end,
	}
	selected_track = selected_track or 1
	song = {
		tracks = tracks,
		selected_pattern_index = 1,
		selected_track_index = selected_track,
		selected_line_index = 1,
		selected_note_column_index = tracks[selected_track].max_note_columns > 0 and 1 or 0,
		selected_instrument_index = 3,
		selected_track = tracks[selected_track],
		selected_line = lines[selected_track],
		transport = { keyboard_velocity_enabled = true, keyboard_velocity = 80 },
		track = function(_, index) return tracks[index] end,
		pattern = function() return pattern end,
	}
	tool.preferences.same_track.value = same_track or false
	return lines
end

dofile("main.lua")

local cases = 0
local function check(condition, message)
	assert(condition, message)
end

-- Exercise both scale and chromatic chord paths through public keybindings.
for _, chord_index in ipairs({ 1, 7 }) do
	tool.preferences.chord_index.value = chord_index
	local third = chord_index == 1 and 51 or 52 -- C minor scale / C major chromatic
	for _, boundary in ipairs({ "master", "group", "send" }) do
		for _, position in ipairs({ 2, 3 }) do
			local types = { "sequencer", "sequencer", "sequencer", "sequencer" }
			types[position] = boundary
			local lines = setup(types)
			bindings["Pattern Editor:KeyScale:Chordify Current"]()
			check(lines[1].note_columns[1].note_value == 48, "Root should be inserted")
			if position == 3 then
				check(lines[2].note_columns[1].note_value == third, "Keep the inserted third")
			end
			check(#lines[position].note_columns == 0, "Boundary track must stay empty")
			check(lines[position + 1].note_columns[1].note_value == 121, "Do not cross boundary")
			check(#statuses == 1, "Report the truncated chord")
			cases = cases + 1
		end

		local lines = setup({ "sequencer", boundary }, true)
		bindings["Pattern Editor:KeyScale:Chordify Current"]()
		check(lines[1].note_columns[3].note_value == 55, "Same-track chord must remain complete")
		check(song.selected_track.visible_note_columns == 3, "Show all chord columns")
		check(#statuses == 0, "Same-track mode should not report a boundary")
		cases = cases + 1

		lines = setup({ "sequencer", boundary }, false, 2)
		bindings["Pattern Editor:KeyScale:Chordify Current"]()
		check(lines[1].note_columns[1].note_value == 121, "Invalid starting track must be a no-op")
		cases = cases + 1
	end

	local lines = setup({ "sequencer", "sequencer", "sequencer", "master" })
	bindings["Pattern Editor:KeyScale:Chordify Current"]()
	check(lines[2].note_columns[1].note_value == third, "Preserve ordinary chord voicing")
	check(lines[3].note_columns[1].note_value == 55, "Preserve the fifth")
	check(lines[3].note_columns[1].instrument_value == 2, "Preserve instrument")
	check(lines[3].note_columns[1].volume_value == 80, "Preserve velocity")
	check(#statuses == 0, "A complete chord should not warn")
	cases = cases + 1

	setup({ "sequencer" })
	bindings["Pattern Editor:KeyScale:Chordify Current"]()
	cases = cases + 1 -- Running out of tracks must also remain safe.
end

print(string.format("Passed %d chord track boundary scenarios", cases))
