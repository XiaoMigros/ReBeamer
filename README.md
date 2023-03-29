# [ReBeamer (v0.8.1)](https://musescore.org/en/project/rebeamer)
A plugin for MuseScore that rebeams music, following preset or custom rules. Automatically rebeam notes, rests, or tuplets!

This plugin is still in a primitive testing stage, no warranty of any kind is provided.

Please read the [Usage](https://github.com/XiaoMigros/ReBeamer#Usage) section below to get the most out of it

MuseScore 3.5 or later is required.

## Features
 - Beam over notes, rests, or tuplets
 - Different beaming rules depending on Time Signature or tuplet size
 - Rebeam the whole score, or just a selection
 - Undo/Redo compatible
 - Create your own custom rulesets

### Upcoming Features (by v1.0, presumably)
- Improved custom settings process
- Bug fixes
- DockMode: rebeam the score automatically during the creation process

## Changelog
## v0.8.1 (20230329)
- Bug fix for compound time signatures
### v0.8.0 (20230324)
- MuseScore 4 support
- minor code improvements
- new loading screen appears if plugin takes longer than 1 second to run
### v0.7.0 (20230313)
- completely rewritten beaming system
- support of complex time signatures
- support for rebeaming notes
- addition of other plugin tools
### v0.6.2 (20230205)
- Code restructuring
### v0.6.1 (20230203)
- Improved 8th beaming function
### v0.6.0 (20230202)
- Beta release

## Installation
Download all the files, unzip them and move them to MuseScore's plugins folder.

For more help installing this plugin, visit [this page](https://musescore.org/en/handbook/3/plugins#installation).

## Usage

Run the plugin from the 'Plugins' tab, or assign a shortcut to it in the Plugin Manager.The plugin will detect if there is a selection and apply itself accordingly (Note: it will always apply itself to whole measures). MuseScore's Undo/Redo commands work as usual.

If the plugin crashes, an error message will appear at the end of the score.

### Optimisation
Here are some things you can do to avoid issues with the plugin:
* Regroup rhythms: The plugin works best when all of your sheet's rhythms are notated correctly. If you know what you're doing, great! If you don't, run 'Tools/Regroup Rhythms' before running the plugin.
* 2nd+ Voices: The plugin might not work correctly if there are any deleted rests in voices 2-4. If you don't want a rest to be seen, make it invisible instead.

### Customisation
To create your own custom rules, see ['presets/timesig template'](https://github.com/XiaoMigros/ReBeamer/blob/main/presets/timesig%20template). There you can define rules for in general or for specific time signatures.
