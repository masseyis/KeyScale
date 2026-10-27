## KeyScale: same-track chord option

### Added

- **Insert notes into same track** option (**Tools → KeyScale → Insert notes into same track**). When checked, the chord commands place every chord note in the current track instead of spreading them across consecutive tracks:
  - Notes start at the cursor's note column and fill the columns to its right.
  - Extra note columns are shown automatically when needed (up to Renoise's 12 per track). If a chord doesn't fit, the remaining notes are skipped and a status message is shown.
  - The setting is saved with the tool's preferences and is off by default, so existing behavior is unchanged.

### Changed

- The two chord functions (scale-based and chromatic) now share one note-placement helper, `place_chord_notes`, which handles both the across-tracks and same-track modes.
- README: documents the new option under **Building chords**.
