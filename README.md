# KeyScale — Keyboard-Driven Scale-Locked Note Entry for Renoise

**KeyScale** is a Renoise tool designed for **non-musicians, beginners, and anyone who prefers typing over playing**.  
It turns Renoise’s pattern editor into a **scale-aware, keyboard-friendly composing surface**, letting you:

- insert notes using simple **QWERTY keyboard shortcuts**  
- move notes **up/down scale degrees** instead of semitones  
- shift notes **up/down octaves**  
- automatically **snap off-scale notes** into the nearest in-scale degree  
- quickly change the **root note** and **scale** from the keyboard  
- work entirely without a MIDI keyboard

It’s the closest thing Renoise has to a **scale lock mode**, built specifically for tracker-style entry and people who *think in keys, not pitches*.

---

## ✨ Features

### 🎹 Keyboard-first melody creation  

If you don't play piano (or don’t want to reach for a MIDI keyboard), KeyScale gives you a fast, musical workflow fully controlled from the typing keyboard.

### 🔒 Automatic scale locking  

All transformations (degree movement, octave movement, root insertion) snap incoming notes into the active scale.

### 🎯 Smart note insertion  

If you trigger a move action on an **empty cell**, KeyScale will:

1. insert the **root note** automatically  
2. then apply the requested scale/octave movement  

This means you can “walk” melodies into existence using just ↑/↓ keybinds.

### 🔄 Scale degree movement  

Instead of semitone steps, move notes by their **scale degree**, keeping them strictly in key.

### 📈 Octave shifts  

Fast octave up/down movement, still scale-locked.

### 🎚️ Velocity support  

Inserted notes use Renoise’s **Computer Keyboard Velocity** setting (if enabled), matching standard QWERTY entry behavior.

### 🎼 Root + Scale switching  

Choose keys/modes **entirely by keyboard**, via:

- next/previous scale  
- next/previous root note  
- status popup showing the current setting  

---

## 🚀 How to Use

### 1. Install the Tool  

Drop the `.xrnx` into Renoise or install via *Tools → Install*.

### 2. Bind Your Keys  

Open:

Edit -> Preferences -> Keys

Then assign shortcuts you like to:

- **Pattern Editor → KeyScale → Insert Root Note**  
- **Pattern Editor → KeyScale → Move Up Scale Degree**  
- **Pattern Editor → KeyScale → Move Down Scale Degree**  
- **Pattern Editor → KeyScale → Move Up Octave**  
- **Pattern Editor → KeyScale → Move Down Octave**  

And global controls:

- **Global → KeyScale → Next Scale**  
- **Global → KeyScale → Previous Scale**  
- **Global → KeyScale → Next Root**  
- **Global → KeyScale → Previous Root**  
- **Global → KeyScale → Show Current Scale**  

Suggested bindings:

| Action | Suggested Key |
|--------|----------------|
| Move Up Degree | `Alt + ↑` |
| Move Down Degree | `Alt + ↓` |
| Move Up Octave | `Shift + Alt + ↑` |
| Move Down Octave | `Shift + Alt + ↓` |
| Insert Root Note | `Ctrl + Enter` |
| Next Scale | `Ctrl + Alt + →` |
| Previous Scale | `Ctrl + Alt + ←` |
| Next Root | `Ctrl + Alt + ↑` |
| Previous Root | `Ctrl + Alt + ↓` |

---

## 📝 Working With KeyScale

### No selection → affects **current cell**

- If the cell **contains a note** → it gets transformed.
- If the cell is **empty** → KeyScale inserts the root note then moves it.

### Selection active → affects **all notes in the selection**

Use this to reshape large melodic patterns while keeping everything in key.

### Changing scale or root

Use the next/previous commands to rotate through:

- Major / Minor / Dorian / Mixolydian  
- Harmonic Minor  
- Pentatonics  

All scale-degree and octave actions immediately use the new scale.

---

## 💡 Tips

- Press **Cmd+U** (macOS) or **Ctrl+U** (Windows/Linux) to clear selections quickly.
- Use **Fn+Backspace** on a Mac laptop to delete a single note cell.
- Keep the **volume column visible** if you want keyboard velocity applied.
- Try building melodies entirely from an empty track using only degree up/down keys — you’ll be surprised how quickly musical shapes appear.

---

## ❤️ Why KeyScale?

Renoise is amazing for fast composition, but for many users — especially people without formal musical training — entering notes chromatically can be intimidating and unmusical.

**KeyScale bridges that gap**, making Renoise feel more like:

- a **step sequencer**,  
- a **scale-aware tracker**,  
- or a **note-safe piano roll**,  

all operated entirely from your keyboard.

Whether you’re a non-musician, a programmer-minded composer, or just someone who wants to stay inside the tracker flow, KeyScale lets you work *musically* without touching a MIDI keyboard.

---

## ? License

MIT License — free to use, modify, and build upon.

---

Happy composing — and welcome to scale-safe tracker writing!  
If you have feature requests or ideas, feel free to reach out.
