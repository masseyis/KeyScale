-- Run from the repository root: lua5.1 tests/note_and_chord_behaviour.lua
local mock = dofile("tests/support/renoise.lua")
local chord_command = "Pattern Editor:KeyScale:Chordify Current"
local cases = 0
local function expect(actual, expected, context)
	assert(actual == expected, string.format("%s: expected %s, got %s", context, tostring(expected), tostring(actual)))
end
local function invoke(env, name)
	env:invoke("Pattern Editor:KeyScale:" .. name)
end
local chords = {
	{ 48, 51, 55 }, -- Scale triad, C natural minor
	{ 48, 51, 55, 58 }, -- Scale seventh
	{ 48, 51, 55, 58, 62 }, -- Scale ninth
	{ 48, 50, 55 }, -- Sus2
	{ 48, 53, 55 }, -- Sus4
	{ 48, 51, 55, 62 }, -- Add9
	{ 48, 52, 55 }, -- Major
	{ 48, 51, 55 }, -- Minor
	{ 48, 51, 54 }, -- Diminished
	{ 48, 52, 56 }, -- Augmented
	{ 48, 52, 55, 58 }, -- Dominant seventh
	{ 48, 52, 55, 59 }, -- Major seventh
	{ 48, 51, 55, 58 }, -- Minor seventh
}

-- Exact reference voicings for every chord, in both placement modes.
for index, notes in ipairs(chords) do
	for _, same_track in ipairs({ false, true }) do
		local env = mock.new({ chord = index, same_track = same_track, column = 3, visible_columns = 3 })
		env:invoke(chord_command)
		for voice, value in ipairs(notes) do
			local note = env:note(same_track and 1 or voice, same_track and voice + 2 or 1)
			expect(note.note_value, value, "Chord " .. index .. " voice " .. voice)
			expect(note.instrument_value, 2, "Selected instrument")
			expect(note.volume_value, 80, "Keyboard velocity")
		end
		if same_track then
			expect(env:note(2, 1).note_value, 121, "Adjacent track untouched")
			expect(env:note(1, 2).note_value, 121, "Column before cursor untouched")
		end
		expect(env:note(1, 3, 1).note_value, 121, "Row before cursor untouched")
		expect(env:note(1, 3, 3).note_value, 121, "Row after cursor untouched")
		cases = cases + 1
	end

	-- Every inversion must retain chord pitch classes, with the selected voice in bass.
	for inversion = 0, #notes - 1 do
		local env = mock.new({ chord = index, inversion = inversion, same_track = true })
		env:invoke(chord_command)
		local pitch_classes = {}
		for _, note in ipairs(notes) do pitch_classes[note % 12] = true end
		expect(env:note(1, 1).note_value, notes[inversion + 1], "Inversion bass")
		for column = 1, #notes do
			local value = env:note(1, column).note_value
			assert(value >= notes[inversion + 1] and value <= 119, "Playable inversion voice")
			assert(pitch_classes[value % 12], "Inversion changed chord quality")
		end
		cases = cases + 1
	end

	-- All starting columns, including partial chords at the right-hand limit.
	for column = 1, 12 do
		local env = mock.new({ chord = index, same_track = true, column = column, visible_columns = column })
		env:invoke(chord_command)
		expect(env.song.selected_track.visible_note_columns, math.min(12, column + #notes - 1), "Visible columns")
		for dest = column, math.min(12, column + #notes - 1) do
			expect(env:note(1, dest).note_value, notes[dest - column + 1], "Column-limit voicing")
		end
		for dest = 1, column - 1 do expect(env:note(1, dest).note_value, 121, "Earlier column untouched") end
		expect(#env.statuses, column + #notes - 1 > 12 and 1 or 0, "Truncation warning")
		cases = cases + 1
	end
end

-- Explicit inverted voicing, including octave placement, rather than pitch classes alone.
for inversion, expected in ipairs({ { 48, 52, 55 }, { 52, 55, 60 }, { 55, 60, 64 } }) do
	local env = mock.new({ chord = 7, inversion = inversion - 1, same_track = true })
	env:invoke(chord_command)
	for column, value in ipairs(expected) do expect(env:note(1, column).note_value, value, "Major inversion") end
	cases = cases + 1
end

-- Preserve an existing instrument and explicit velocity; otherwise use keyboard velocity only when enabled and visible.
for _, same_track in ipairs({ false, true }) do
	for _, volume_visible in ipairs({ false, true }) do
		for _, velocity_enabled in ipairs({ false, true }) do
			for _, explicit_volume in ipairs({ 63, 255 }) do
				local env = mock.new({ same_track = same_track, volume_visible = volume_visible, velocity_enabled = velocity_enabled })
				local bass = env:note(1, 1)
				bass.note_value, bass.instrument_value, bass.volume_value = 48, 9, explicit_volume
				env:invoke(chord_command)
				local upper = env:note(same_track and 1 or 2, same_track and 2 or 1)
				local expected = 255
				if volume_visible then
					if explicit_volume ~= 255 then expected = explicit_volume
					elseif velocity_enabled then expected = 80 end
				end
				expect(upper.instrument_value, 9, "Existing instrument")
				expect(upper.volume_value, expected, "Upper voice velocity")
				cases = cases + 1
			end
		end
	end
end

-- A missing instrument on an existing note falls back to the selected instrument.
local env = mock.new({ same_track = true })
env:note(1, 1).note_value = 48
env:invoke(chord_command)
expect(env:note(1, 2).instrument_value, 2, "Missing instrument fallback")
cases = cases + 1

-- Empty, OFF and effect-column cursor handling.
for _, same_track in ipairs({ false, true }) do
	env = mock.new({ same_track = same_track, column = 0 })
	env:invoke(chord_command)
	expect(env:note(1, 1).note_value, 121, "Effect-column cursor is a no-op")
	env = mock.new({ same_track = same_track })
	env:note(1, 1).note_value = 120
	env:invoke(chord_command)
	expect(env:note(1, 1).note_value, 120, "OFF remains OFF")
	expect(env:note(same_track and 1 or 2, same_track and 2 or 1).note_value, 121, "OFF creates no chord")
	cases = cases + 2
end

-- Extreme upper notes and inversions must never turn into OFF or EMPTY values.
for _, chord in ipairs({ 1, 3, 7, 11 }) do
	for _, same_track in ipairs({ false, true }) do
		env = mock.new({ chord = chord, inversion = 1, same_track = same_track })
		env:note(1, 1).note_value = 119
		env:invoke(chord_command)
		for voice = 1, #chords[chord] do
			assert(env:note(same_track and 1 or voice, same_track and voice or 1).note_value <= 119)
		end
		cases = cases + 1
	end
end

-- Scale movement, snapping and automatic root insertion.
for _, scenario in ipairs({
	{ "Move Up Scale Degree", 121, 50 },
	{ "Move Down Scale Degree", 121, 46 },
	{ "Move Up Octave", 121, 60 },
	{ "Move Down Octave", 121, 36 },
	{ "Move Up Scale Degree", 49, 50 },
	{ "Move Down Scale Degree", 48, 46 },
	{ "Move Up Octave", 119, 119 },
	{ "Move Down Octave", 0, 0 },
	{ "Move Up Scale Degree", 120, 120 },
}) do
	env = mock.new()
	env:note(1, 1).note_value = scenario[2]
	invoke(env, scenario[1])
	expect(env:note(1, 1).note_value, scenario[3], scenario[1])
	cases = cases + 1
end

env = mock.new({ selection = { start_track = 1, end_track = 1, start_line = 1, end_line = 2,
	start_column = 2, end_column = 3 } })
env:note(1, 2, 1).note_value = 48
env:note(1, 3, 2).note_value = 120
env:note(1, 1, 1).note_value = 48
invoke(env, "Move Up Scale Degree")
expect(env:note(1, 2, 1).note_value, 50, "Selected note transformed")
expect(env:note(1, 2, 2).note_value, 121, "Selected empty cell stays empty")
expect(env:note(1, 3, 2).note_value, 120, "Selected OFF stays OFF")
expect(env:note(1, 1, 1).note_value, 48, "Unselected note unchanged")
cases = cases + 1

-- Menu toggles update the registered preference and preserve the default.
env = mock.new()
local menu = env.menus["Main Menu:Tools:KeyScale:Insert notes into same track"]
expect(menu.selected(), false, "Default chord placement")
menu.invoke()
expect(menu.selected(), true, "Toggle same-track on")
menu.invoke()
expect(menu.selected(), false, "Toggle same-track off")
cases = cases + 1

for _, setting in ipairs({
	{ "Scale", "scale_index", 10 }, { "Chord", "chord_index", 13 }, { "Inversion", "inversion_index", 2 },
}) do
	env = mock.new()
	local low = setting[1] == "Inversion" and 0 or 1
	env.prefs[setting[2]].value = setting[3]
	env:invoke("Global:KeyScale:Next " .. setting[1])
	expect(env.prefs[setting[2]].value, low, "Wrap forward " .. setting[1])
	env:invoke("Global:KeyScale:Previous " .. setting[1])
	expect(env.prefs[setting[2]].value, setting[3], "Wrap backward " .. setting[1])
	cases = cases + 1
end

print(string.format("Passed %d note and chord behaviour scenarios", cases))
