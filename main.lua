-- KeyScale main.lua

local rs = renoise.song

------------------------------------------------------------
-- CONFIG: Scales & names
------------------------------------------------------------

local SCALES = {
	{ name = "Major (Ionian)", steps = { 0, 2, 4, 5, 7, 9, 11 } },
	{ name = "Natural Minor (Aeolian)", steps = { 0, 2, 3, 5, 7, 8, 10 } },
	{ name = "Dorian", steps = { 0, 2, 3, 5, 7, 9, 10 } },
	{ name = "Phrygian", steps = { 0, 1, 3, 5, 7, 8, 10 } },
	{ name = "Lydian", steps = { 0, 2, 4, 6, 7, 9, 11 } },
	{ name = "Mixolydian", steps = { 0, 2, 4, 5, 7, 9, 10 } },
	{ name = "Harmonic Minor", steps = { 0, 2, 3, 5, 7, 8, 11 } },
	{ name = "Melodic Minor", steps = { 0, 2, 3, 5, 7, 9, 11 } },
	{ name = "Major Pentatonic", steps = { 0, 2, 4, 7, 9 } },
	{ name = "Minor Pentatonic", steps = { 0, 3, 5, 7, 10 } },
}

-- Chord types definition
-- Scale-based chords use "degrees" (scale degree offsets)
-- Chromatic chords use "semitones" (fixed semitone intervals)
local CHORD_TYPES = {
	-- Scale-based (diatonic)
	{ name = "Triad (Scale)", degrees = { 2, 4 } },
	{ name = "Seventh (Scale)", degrees = { 2, 4, 6 } },
	{ name = "Ninth (Scale)", degrees = { 2, 4, 6, 8 } },
	{ name = "Sus2", degrees = { 1, 4 } },
	{ name = "Sus4", degrees = { 3, 4 } },
	{ name = "Add9 (Scale)", degrees = { 2, 4, 8 } },
	-- Chromatic (fixed intervals)
	{ name = "Major Triad", semitones = { 4, 7 }, chromatic = true },
	{ name = "Minor Triad", semitones = { 3, 7 }, chromatic = true },
	{ name = "Diminished Triad", semitones = { 3, 6 }, chromatic = true },
	{ name = "Augmented Triad", semitones = { 4, 8 }, chromatic = true },
	{ name = "Dominant 7th", semitones = { 4, 7, 10 }, chromatic = true },
	{ name = "Major 7th", semitones = { 4, 7, 11 }, chromatic = true },
	{ name = "Minor 7th", semitones = { 3, 7, 10 }, chromatic = true },
}

-- Root note is stored as a note value in a reference octave.
-- We'll start at C-4 (48).
local DEFAULT_ROOT_NOTE = 48 -- C-4
local DEFAULT_SCALE_INDEX = 2 -- Natural Minor
local DEFAULT_CHORD_INDEX = 1 -- Triad

------------------------------------------------------------
-- Preferences (root + scale + chord, persisted across sessions)
------------------------------------------------------------

local KeyScalePrefs = renoise.Document.create("KeyScalePreferences")({
	root_note_value = DEFAULT_ROOT_NOTE,
	scale_index = DEFAULT_SCALE_INDEX,
	chord_index = DEFAULT_CHORD_INDEX,
})

renoise.tool().preferences = KeyScalePrefs

local function get_root_note()
	return KeyScalePrefs.root_note_value.value
end

local function get_scale()
	local idx = KeyScalePrefs.scale_index.value
	if idx < 1 then
		idx = 1
	end
	if idx > #SCALES then
		idx = #SCALES
	end
	return SCALES[idx].steps, SCALES[idx].name
end

local function get_chord()
	local idx = KeyScalePrefs.chord_index.value
	if idx < 1 then
		idx = 1
	end
	if idx > #CHORD_TYPES then
		idx = #CHORD_TYPES
	end
	local chord = CHORD_TYPES[idx]
	return chord.degrees, chord.semitones, chord.chromatic, chord.name
end

local NOTE_NAMES = {
	"C",
	"C#",
	"D",
	"D#",
	"E",
	"F",
	"F#",
	"G",
	"G#",
	"A",
	"A#",
	"B",
}

local function note_name_from_value(note)
	if note < 0 or note > 119 then
		return "?"
	end
	local pc = note % 12
	local oct = math.floor(note / 12)
	return string.format("%s-%d", NOTE_NAMES[pc + 1], oct)
end

local function show_status_current_scale()
	local root = get_root_note()
	local _, scale_name = get_scale()
	local msg = string.format("KeyScale: Root %s, %s", note_name_from_value(root), scale_name)
	renoise.app():show_status(msg)
end

local function show_status_current_chord()
	local _, _, _, chord_name = get_chord()
	local msg = string.format("KeyScale: Chord Type: %s", chord_name)
	renoise.app():show_status(msg)
end

------------------------------------------------------------
-- Core scale math
------------------------------------------------------------

local function is_valid_note(n)
	return n and n >= 0 and n <= 119
end

-- Given a note value, return (octave, degree_index) in scale, snapping
local function note_to_scale_degree(note_value)
	if not is_valid_note(note_value) then
		return nil
	end

	local ROOT = get_root_note()
	local SCALE = get_scale()

	local diff = note_value - ROOT
	local octave = math.floor(diff / 12)
	local rel = diff - octave * 12 -- 0..11

	local best_idx, best_diff = 1, math.huge

	for i, st in ipairs(SCALE) do
		local ad = math.abs(rel - st)
		if ad < best_diff then
			best_diff = ad
			best_idx = i
			if ad == 0 then
				break
			end
		end
	end

	return octave, best_idx
end

-- Given (octave, degree_index) -> note value
local function scale_degree_to_note(oct, deg)
	local ROOT = get_root_note()
	local SCALE = get_scale()
	local len = #SCALE

	while deg < 1 do
		deg = deg + len
		oct = oct - 1
	end
	while deg > len do
		deg = deg - len
		oct = oct + 1
	end

	local note = ROOT + SCALE[deg] + 12 * oct
	if note < 0 then
		note = 0
	end
	if note > 119 then
		note = 119
	end
	return note
end

local function transform_note(note_obj, ddeg, doct)
	if not is_valid_note(note_obj.note_value) then
		return
	end

	local oct, deg = note_to_scale_degree(note_obj.note_value)
	if not oct then
		return
	end

	deg = deg + (ddeg or 0)
	oct = oct + (doct or 0)

	note_obj.note_value = scale_degree_to_note(oct, deg)
end

------------------------------------------------------------
-- Selection / cursor helpers
------------------------------------------------------------

-- Iterate over selection only (if exists)
local function for_each_selected_note(callback)
	local song = rs()
	local sel = song.selection_in_pattern
	if not sel then
		return
	end

	local patt = song:pattern(song.selected_pattern_index)

	for t = sel.start_track, sel.end_track do
		local ptrack = patt:track(t)
		for l = sel.start_line, sel.end_line do
			local line = ptrack:line(l)
			for c = sel.start_column, sel.end_column do
				if c <= #line.note_columns then
					callback(line.note_columns[c])
				end
			end
		end
	end
end

-- Get note at cursor; if empty, insert root (with instrument + velocity) and return it.
local function get_or_insert_note_at_cursor()
	local song = rs()
	local line = song.selected_line
	local col = song.selected_note_column_index

	if col < 1 or col > #line.note_columns then
		return nil
	end

	local note = line.note_columns[col]

	if note.note_value == renoise.PatternLine.EMPTY_NOTE then
		note.note_value = scale_degree_to_note(0, 1)
		note.instrument_value = song.selected_instrument_index - 1

		if song.selected_track.volume_column_visible and song.transport.keyboard_velocity_enabled then
			note.volume_value = song.transport.keyboard_velocity
		end
	end

	return note
end

------------------------------------------------------------
-- Commands: note actions
------------------------------------------------------------

local function insert_root_note()
	-- Just re-use the helper, which also handles instrument + velocity
	get_or_insert_note_at_cursor()
end

local function move_up_scale_degree()
	local song = rs()
	if song.selection_in_pattern then
		for_each_selected_note(function(n)
			transform_note(n, 1, 0)
		end)
	else
		local n = get_or_insert_note_at_cursor()
		if n then
			transform_note(n, 1, 0)
		end
	end
end

local function move_down_scale_degree()
	local song = rs()
	if song.selection_in_pattern then
		for_each_selected_note(function(n)
			transform_note(n, -1, 0)
		end)
	else
		local n = get_or_insert_note_at_cursor()
		if n then
			transform_note(n, -1, 0)
		end
	end
end

local function move_up_octave()
	local song = rs()
	if song.selection_in_pattern then
		for_each_selected_note(function(n)
			transform_note(n, 0, 1)
		end)
	else
		local n = get_or_insert_note_at_cursor()
		if n then
			transform_note(n, 0, 1)
		end
	end
end

local function move_down_octave()
	local song = rs()
	if song.selection_in_pattern then
		for_each_selected_note(function(n)
			transform_note(n, 0, -1)
		end)
	else
		local n = get_or_insert_note_at_cursor()
		if n then
			transform_note(n, 0, -1)
		end
	end
end

------------------------------------------------------------
-- Chordify helpers
------------------------------------------------------------

-- Place extra chord tones on following tracks, sharing instrument/velocity.
-- degree_offsets: list of scale-degree offsets *above the bass degree*
--   e.g. {2, 4}  -> triad (3rd & 5th)
--        {2, 4, 6} -> 7th chord (3rd, 5th, 7th)
local function chordify_on_tracks(degree_offsets)
	local song = rs()
	local patt = song:pattern(song.selected_pattern_index)
	local base_track = song.selected_track_index
	local line_index = song.selected_line_index

	local bass_note = get_or_insert_note_at_cursor()
	if not bass_note or not is_valid_note(bass_note.note_value) then
		return
	end

	-- Snap bass note exactly to scale
	local oct, deg = note_to_scale_degree(bass_note.note_value)
	if not oct then
		return
	end
	bass_note.note_value = scale_degree_to_note(oct, deg)

	-- Ensure instrument is set
	local instr = bass_note.instrument_value
	if instr == renoise.PatternLine.EMPTY_INSTRUMENT then
		instr = song.selected_instrument_index - 1
		bass_note.instrument_value = instr
	end

	local base_vol = bass_note.volume_value

	local function volume_for_track(track_index)
		local track = song:track(track_index)
		if not track.volume_column_visible then
			return renoise.PatternLine.EMPTY_VOLUME
		end
		if base_vol ~= renoise.PatternLine.EMPTY_VOLUME then
			return base_vol
		end
		if song.transport.keyboard_velocity_enabled then
			return song.transport.keyboard_velocity
		end
		return renoise.PatternLine.EMPTY_VOLUME
	end

	for i, deg_off in ipairs(degree_offsets) do
		local target_track_index = base_track + i -- +1, +2, +3...
		if target_track_index > #song.tracks then
			-- Not enough tracks to place this voice; stop quietly.
			break
		end

		local track = patt:track(target_track_index)
		local line = track:line(line_index)
		local note = line.note_columns[1] -- first column on that track

		note.note_value = scale_degree_to_note(oct, deg + deg_off)
		note.instrument_value = instr

		local vol = volume_for_track(target_track_index)
		if vol ~= renoise.PatternLine.EMPTY_VOLUME then
			note.volume_value = vol
		end
	end
end

-- Chromatic version: uses fixed semitone intervals from bass note
local function chordify_chromatic(semitone_offsets)
	local song = rs()
	local patt = song:pattern(song.selected_pattern_index)
	local base_track = song.selected_track_index
	local line_index = song.selected_line_index

	local bass_note = get_or_insert_note_at_cursor()
	if not bass_note or not is_valid_note(bass_note.note_value) then
		return
	end

	local bass_value = bass_note.note_value

	-- Ensure instrument is set
	local instr = bass_note.instrument_value
	if instr == renoise.PatternLine.EMPTY_INSTRUMENT then
		instr = song.selected_instrument_index - 1
		bass_note.instrument_value = instr
	end

	local base_vol = bass_note.volume_value

	local function volume_for_track(track_index)
		local track = song:track(track_index)
		if not track.volume_column_visible then
			return renoise.PatternLine.EMPTY_VOLUME
		end
		if base_vol ~= renoise.PatternLine.EMPTY_VOLUME then
			return base_vol
		end
		if song.transport.keyboard_velocity_enabled then
			return song.transport.keyboard_velocity
		end
		return renoise.PatternLine.EMPTY_VOLUME
	end

	for i, semitones in ipairs(semitone_offsets) do
		local target_track_index = base_track + i
		if target_track_index > #song.tracks then
			break
		end

		local track = patt:track(target_track_index)
		local line = track:line(line_index)
		local note = line.note_columns[1]

		local new_note = bass_value + semitones
		if new_note < 0 then
			new_note = 0
		end
		if new_note > 119 then
			new_note = 119
		end

		note.note_value = new_note
		note.instrument_value = instr

		local vol = volume_for_track(target_track_index)
		if vol ~= renoise.PatternLine.EMPTY_VOLUME then
			note.volume_value = vol
		end
	end
end

local function chordify_triad()
	-- bass + 3rd + 5th
	chordify_on_tracks({ 2, 4 })
end

local function chordify_seventh()
	-- bass + 3rd + 5th + 7th
	chordify_on_tracks({ 2, 4, 6 })
end

local function chordify_ninth()
	-- bass + 3rd + 5th + 7th + 9th
	chordify_on_tracks({ 2, 4, 6, 8 })
end

local function chordify_sus2()
	-- bass + 2nd + 5th (suspended second)
	chordify_on_tracks({ 1, 4 })
end

local function chordify_sus4()
	-- bass + 4th + 5th (suspended fourth)
	chordify_on_tracks({ 3, 4 })
end

local function chordify_add9()
	-- bass + 3rd + 5th + 9th (add nine, no 7th)
	chordify_on_tracks({ 2, 4, 8 })
end

local function chordify_current()
	-- Use the currently selected chord type
	local degrees, semitones, chromatic, _ = get_chord()
	if chromatic then
		chordify_chromatic(semitones)
	else
		chordify_on_tracks(degrees)
	end
end

------------------------------------------------------------
-- Commands: root / scale / chord selection
------------------------------------------------------------

local function next_scale()
	local idx = KeyScalePrefs.scale_index.value + 1
	if idx > #SCALES then
		idx = 1
	end
	KeyScalePrefs.scale_index.value = idx
	show_status_current_scale()
end

local function prev_scale()
	local idx = KeyScalePrefs.scale_index.value - 1
	if idx < 1 then
		idx = #SCALES
	end
	KeyScalePrefs.scale_index.value = idx
	show_status_current_scale()
end

local function next_root()
	local r = KeyScalePrefs.root_note_value.value + 1
	if r > 59 then
		r = 48
	end -- wrap C-4..B-4
	KeyScalePrefs.root_note_value.value = r
	show_status_current_scale()
end

local function prev_root()
	local r = KeyScalePrefs.root_note_value.value - 1
	if r < 48 then
		r = 59
	end
	KeyScalePrefs.root_note_value.value = r
	show_status_current_scale()
end

local function show_current_scale()
	show_status_current_scale()
end

local function next_chord()
	local idx = KeyScalePrefs.chord_index.value + 1
	if idx > #CHORD_TYPES then
		idx = 1
	end
	KeyScalePrefs.chord_index.value = idx
	show_status_current_chord()
end

local function prev_chord()
	local idx = KeyScalePrefs.chord_index.value - 1
	if idx < 1 then
		idx = #CHORD_TYPES
	end
	KeyScalePrefs.chord_index.value = idx
	show_status_current_chord()
end

local function show_current_chord()
	show_status_current_chord()
end

------------------------------------------------------------
-- Register keybindings
------------------------------------------------------------

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Insert Root Note",
	invoke = insert_root_note,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Move Up Scale Degree",
	invoke = move_up_scale_degree,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Move Down Scale Degree",
	invoke = move_down_scale_degree,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Move Up Octave",
	invoke = move_up_octave,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Move Down Octave",
	invoke = move_down_octave,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Chordify Triad",
	invoke = chordify_triad,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Chordify Seventh",
	invoke = chordify_seventh,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Chordify Ninth",
	invoke = chordify_ninth,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Chordify Sus2",
	invoke = chordify_sus2,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Chordify Sus4",
	invoke = chordify_sus4,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Chordify Add9",
	invoke = chordify_add9,
})

renoise.tool():add_keybinding({
	name = "Pattern Editor:KeyScale:Chordify Current",
	invoke = chordify_current,
})

renoise.tool():add_keybinding({
	name = "Global:KeyScale:Next Chord",
	invoke = next_chord,
})

renoise.tool():add_keybinding({
	name = "Global:KeyScale:Previous Chord",
	invoke = prev_chord,
})

renoise.tool():add_keybinding({
	name = "Global:KeyScale:Show Current Chord",
	invoke = show_current_chord,
})

renoise.tool():add_keybinding({
	name = "Global:KeyScale:Next Scale",
	invoke = next_scale,
})

renoise.tool():add_keybinding({
	name = "Global:KeyScale:Previous Scale",
	invoke = prev_scale,
})

renoise.tool():add_keybinding({
	name = "Global:KeyScale:Next Root",
	invoke = next_root,
})

renoise.tool():add_keybinding({
	name = "Global:KeyScale:Previous Root",
	invoke = prev_root,
})

renoise.tool():add_keybinding({
	name = "Global:KeyScale:Show Current Scale",
	invoke = show_current_scale,
})
