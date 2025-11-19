-- KeyScale main.lua

local rs = renoise.song

------------------------------------------------------------
-- CONFIG: Scales & names
------------------------------------------------------------

local SCALES = {
  { name = "Major (Ionian)", steps = { 0, 2, 4, 5, 7, 9, 11 } },
  { name = "Natural Minor (Aeol)", steps = { 0, 2, 3, 5, 7, 8, 10 } },
  { name = "Dorian", steps = { 0, 2, 3, 5, 7, 9, 10 } },
  { name = "Mixolydian", steps = { 0, 2, 4, 5, 7, 9, 10 } },
  { name = "Harmonic Minor", steps = { 0, 2, 3, 5, 7, 8, 11 } },
  { name = "Major Pentatonic", steps = { 0, 2, 4, 7, 9 } },
  { name = "Minor Pentatonic", steps = { 0, 3, 5, 7, 10 } },
}

local DEFAULT_ROOT_NOTE = 48 -- C-4
local DEFAULT_SCALE_INDEX = 2 -- Natural Minor

------------------------------------------------------------
-- Preferences (root + scale, persisted across sessions)
------------------------------------------------------------

local KeyScalePrefs = renoise.Document.create("KeyScalePreferences")({
  root_note_value = DEFAULT_ROOT_NOTE,
  scale_index = DEFAULT_SCALE_INDEX,
})

renoise.tool().preferences = KeyScalePrefs

local function get_root_note()
  return KeyScalePrefs.root_note_value.value
end

local function get_scale()
  local idx = KeyScalePrefs.scale_index.value
  if idx < 1 then idx = 1 end
  if idx > #SCALES then idx = #SCALES end
  return SCALES[idx].steps, SCALES[idx].name
end

local NOTE_NAMES = {
  "C","C#","D","D#","E","F","F#","G","G#","A","A#","B"
}

local function note_name_from_value(note)
  if note < 0 or note > 119 then return "?" end
  local pc = note % 12
  local oct = math.floor(note / 12)
  return string.format("%s-%d", NOTE_NAMES[pc + 1], oct)
end

local function show_status_current_scale()
  local root = get_root_note()
  local scale, name = get_scale()
  local msg = string.format("KeyScale: Root %s, %s", note_name_from_value(root), name)
  renoise.app():show_status(msg)
end

------------------------------------------------------------
-- Core scale math
------------------------------------------------------------

local function is_valid_note(n) return n and n >= 0 and n <= 119 end

local function note_to_scale_degree(note_value)
  if not is_valid_note(note_value) then return nil end

  local ROOT = get_root_note()
  local SCALE = get_scale()

  local diff = note_value - ROOT
  local octave = math.floor(diff / 12)
  local rel = diff - octave * 12

  local best_idx, best_diff = 1, math.huge

  for i, st in ipairs(SCALE) do
    local ad = math.abs(rel - st)
    if ad < best_diff then
      best_diff = ad
      best_idx = i
      if ad == 0 then break end
    end
  end

  return octave, best_idx
end

local function scale_degree_to_note(oct, deg)
  local ROOT = get_root_note()
  local SCALE = get_scale()
  local len = #SCALE

  while deg < 1 do deg = deg + len; oct = oct - 1 end
  while deg > len do deg = deg - len; oct = oct + 1 end

  local note = ROOT + SCALE[deg] + 12 * oct
  if note < 0 then note = 0 end
  if note > 119 then note = 119 end
  return note
end

local function transform_note(note_obj, ddeg, doct)
  if not is_valid_note(note_obj.note_value) then return end

  local oct, deg = note_to_scale_degree(note_obj.note_value)
  if not oct then return end

  deg = deg + (ddeg or 0)
  oct = oct + (doct or 0)

  note_obj.note_value = scale_degree_to_note(oct, deg)
end

------------------------------------------------------------
-- Selection / cursor helpers
------------------------------------------------------------

local function for_each_selected_note(callback)
  local song = rs()
  local sel = song.selection_in_pattern
  if not sel then return end

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

local function get_or_insert_note_at_cursor()
  local song = rs()
  local line = song.selected_line
  local col = song.selected_note_column_index

  if col < 1 or col > #line.note_columns then return nil end

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
  local note = get_or_insert_note_at_cursor()
end

local function move_up_scale_degree()
  local song = rs()
  if song.selection_in_pattern then
    for_each_selected_note(function(n) transform_note(n, 1, 0) end)
  else
    local n = get_or_insert_note_at_cursor()
    if n then transform_note(n, 1, 0) end
  end
end

local function move_down_scale_degree()
  local song = rs()
  if song.selection_in_pattern then
    for_each_selected_note(function(n) transform_note(n, -1, 0) end)
  else
    local n = get_or_insert_note_at_cursor()
    if n then transform_note(n, -1, 0) end
  end
end

local function move_up_octave()
  local song = rs()
  if song.selection_in_pattern then
    for_each_selected_note(function(n) transform_note(n, 0, 1) end)
  else
    local n = get_or_insert_note_at_cursor()
    if n then transform_note(n, 0, 1) end
  end
end

local function move_down_octave()
  local song = rs()
  if song.selection_in_pattern then
    for_each_selected_note(function(n) transform_note(n, 0, -1) end)
  else
    local n = get_or_insert_note_at_cursor()
    if n then transform_note(n, 0, -1) end
  end
end

------------------------------------------------------------
-- Commands: root / scale selection
------------------------------------------------------------

local function next_scale()
  local idx = KeyScalePrefs.scale_index.value + 1
  if idx > #SCALES then idx = 1 end
  KeyScalePrefs.scale_index.value = idx
  show_status_current_scale()
end

local function prev_scale()
  local idx = KeyScalePrefs.scale_index.value - 1
  if idx < 1 then idx = #SCALES end
  KeyScalePrefs.scale_index.value = idx
  show_status_current_scale()
end

local function next_root()
  local r = KeyScalePrefs.root_note_value.value + 1
  if r > 59 then r = 48 end
  KeyScalePrefs.root_note_value.value = r
  show_status_current_scale()
end

local function prev_root()
  local r = KeyScalePrefs.root_note_value.value - 1
  if r < 48 then r = 59 end
  KeyScalePrefs.root_note_value.value = r
  show_status_current_scale()
end

local function show_current_scale()
  show_status_current_scale()
end

------------------------------------------------------------
-- Register keybindings (renamed to KeyScale)
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

