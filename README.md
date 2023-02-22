# [Beam Over Rests (v0.6.2)](https://musescore.org/en/project/beam-over-rests)
A plugin for MuseScore that beams over rests, following preset rules.
This plugin is still in a primitive testing stage, and is missing many key features.
Please read [the following documentation](https://github.com/XiaoMigros/beam-over-rests#usage) to get the most out of it, and to avoid crashes.
MuseScore 3.6 or later is required.

### MuseScore 4 Compatibility
Due to the difference in how beaming works, this plugin currently has no effect in MuseScore 4. This will change in a later release.

## Features
 - Beam over Rests in a score, according to preset rules
 - Beam over the whole score, or just a selection
 - Beam over tuplet rests, and simplify tuplet optics when appropriate
 - Undo/Redo compatible

### Upcoming Features (by v1.0, presumably)
- A simple settings window, allowing for customisation
- Make your own presets for different time signatures
- An option to beam over everything in a measure
- More presets bundled in
- Various bug fixes
- More legible code structure
- MuseScore 4 compatibility

### Later release(s):
- Overhaul of settings window: Proper GUI, apply score-specific settings
- Addition of complex time signatures
- Autoadjustment of rest + beam positions
- Option to rebeam all notes as well as rests

## Changelog
- v0.6.1 (20230203): Improved 8th beaming function
- v0.6.0 (20230202): Beta release

## Installation
Download and move 'Beam Over Rests.qml' to MuseScore's plugins folder.

For more help installing this plugin, visit [this page](https://musescore.org/en/handbook/3/plugins#installation).

## Usage

Run the plugin from the bottom of the 'Tools' tab, or assign a shortcut to it in the Plugin Manager. The plugin will detect if there is a selection and apply itself accordingly (note: it will always apply itself to whole measures). MuseScore's Undo/Redo commands work as usual.

If the plugin crashes, an error message will appear at the end of the score.

### Optimisation
Here are some things you can do to avoid issues with the plugin:
* Regroup rhythms: The plugin works best when all of your sheet's rhythms are notated correctly. If you know what you're doing, great! If you don't, run 'Tools/Regroup Rhythms' before running the plugin.
* 2nd+ Voices: The plugin won't work correctly if there are any deleted rests in voices 2-4. If you don't want a rest to be seen, make it invisible instead.

### Customisation
To customise how the plugin runs, you will need to edit the code. Below, the easily changeable parameters are documented:
#### [Lines 95-119: General Settings](https://github.com/XiaoMigros/beam-over-rests/blob/main/Beam%20Over%20Rests.qml#L95)
- forceBeamM: Whether all rests within a measure should be beamed together (only partially working). Can be set to either true or false.
- forceBeamG: Whether all rests within a group should be beamed together, regardless of context. Can be set to either true or false.
- beam8: Whether 8th rests are beamed over. Can be set to either true or false.
- beam8474: Whether 8th rests are beamed over in 4/4. Can be set to either true or false.
- beam8274: Whether 8th rests are beamed over in 2/4. Can be set to either true or false.
- beam16: Whether 16th rests are beamed over. Can be set to either true or false.
- beam32: Whether 32nd rests are beamed over. Can be set to either true or false.

- beamTuplets: Whether tuplets are beamed over. Can be set to either true or false.
- beamToTuplets: Whether tuplets should be beamed to preceding notes/rests. Can be set to either true or false.
- beamFromTuplets: Whether tuplets should be beamed to succeeding notes/rests. Can be set to either true or false.
- simplifyTuplets: Whether, when appropriate, a tuplet's bracket will be hidden, leaving just the number. Can be set to either true or false.
- beamLongerTuplets: Whether tuplets with a base length of 1/4th note, 1/2 note, etc. should still be beamed over when possible. Can be set to either true or false.
- tupletForceBeamG-tupletBeam32: The same as above, only for tuplets. Can be set to either true or false.

#### [Lines 121-284: Time Signature Settings](https://github.com/XiaoMigros/beam-over-rests/blob/main/Beam%20Over%20Rests.qml#L121)
Setting any of the above values in here will apply them only to a specific time signature. Time signatures are currently split into 4 groups: X/4 time signatures, compound X/8 time signatures, other X/8 time signatures, and X/2 time signatures.
The variables below are adapted to each time signature:
- splitBeam1: the 16th subdivisions within 32nd note beams. After each number of 32nds, the plugin will add a 16th subdivision. If no subdivisions are wanted, delete all the numbers (leaving [];)
- splitBeam2: 8th subdivisions for 32nd note beams. Same rules apply as above.
- divNotes1: whether 32nd notes should also show the subdivisions that splitBeam1 rests will. Can be set to either true or false.
- divNotes2: the same, for splitBeam2
- divNotesPlus: whether notes larger than 32nds should show the 8th subdivisions. Can be set to either true or false.

- splitBeam: 8th subdivisions for 16th note. Same rules as other splitbeam functions
- divNotes: the same as other divnotes functions, but for splitBeam
- splitBeamOverride: Useful for X/2 time signatures. Will show the 8th subdivision independtly of divNotes, allowing for the subdivision to be shown in some places and not others. Same rules as other splitbeam functions.

