//===================================================//
//MuseScore 4 Beam Mode Conversion for ReBeamer Plugin
//Copyright (C) 2023 XiaoMigros
//v 1.0
//Changelog:
//===================================================//

// MuseScore 4 uses different enumeration values to set beam modes of notes.
// This function converts them

// MuseScore 3 | MuseScore 4
//      0      |      0
//      1      |      2
//      2      |      5
//      3      |      6
//      4      |      1
//      5      |      3
//      6      |      4
//      +      |      +
//      5      |      5
// (all values >= 7 are treated as beamMode 5)

function convertBeamMode(mode) {
	switch (mode) {
		case 0: {
			break
		}
		case 1: {
			mode = 2
			break
		}
		case 2: {
			mode = 5
			break
		}
		case 3: {
			mode = 6
			break
		}
		case 4: {
			mode = 1
			break
		}
		case 5: {
			mode = 3
			break
		}
		case 6: {
			mode = 4
			break
		}
		default: {
			mode = 0
			break
		}
	}
	return mode
}