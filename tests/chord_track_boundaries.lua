-- Run from the repository root: lua5.1 tests/chord_track_boundaries.lua
local mock = dofile("tests/support/renoise.lua")
local command = "Pattern Editor:KeyScale:Chordify Current"
local cases = 0

for _, chord in ipairs({ 1, 7 }) do
	local third = chord == 1 and 51 or 52 -- C minor scale / C major chromatic
	for _, boundary in ipairs({ "master", "group", "send" }) do
		for _, position in ipairs({ 2, 3 }) do
			local types = { "sequencer", "sequencer", "sequencer", "sequencer" }
			types[position] = boundary
			local env = mock.new({ tracks = types, chord = chord })
			env:invoke(command)
			assert(env:note(1, 1).note_value == 48, "Root should be inserted")
			if position == 3 then
				assert(env:note(2, 1).note_value == third, "Keep the inserted third")
			end
			assert(#env.lines[position][2].note_columns == 0, "Boundary track must stay empty")
			assert(env:note(position + 1, 1).note_value == 121, "Do not cross boundary")
			assert(#env.statuses == 1, "Report the truncated chord")
			cases = cases + 1
		end

		local env = mock.new({ tracks = { "sequencer", boundary }, same_track = true, chord = chord })
		env:invoke(command)
		assert(env:note(1, 3).note_value == 55, "Same-track chord must remain complete")
		assert(env.song.selected_track.visible_note_columns == 3, "Show all chord columns")
		assert(#env.statuses == 0, "Same-track mode should not report a boundary")
		cases = cases + 1

		env = mock.new({ tracks = { "sequencer", boundary }, track = 2, chord = chord })
		env:invoke(command)
		assert(env:note(1, 1).note_value == 121, "Invalid starting track must be a no-op")
		cases = cases + 1
	end

	local env = mock.new({ chord = chord })
	env:invoke(command)
	assert(env:note(2, 1).note_value == third, "Preserve ordinary chord voicing")
	assert(env:note(3, 1).note_value == 55, "Preserve the fifth")
	assert(env:note(3, 1).instrument_value == 2, "Preserve instrument")
	assert(env:note(3, 1).volume_value == 80, "Preserve velocity")
	assert(#env.statuses == 0, "A complete chord should not warn")
	cases = cases + 1

	env = mock.new({ tracks = { "sequencer" }, chord = chord })
	env:invoke(command)
	cases = cases + 1
end

print(string.format("Passed %d chord track boundary scenarios", cases))
