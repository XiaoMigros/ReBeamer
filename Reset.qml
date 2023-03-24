// ReBeamer: Beam over rests and/or apply custom beaming rules
// Copyright (C) 2023 XiaoMigros

// Changelog:
//	v0.8.0 (20230324):	MuseScore 4 support
//						minor code improvements
//						new loading screen appears if plugin takes longer than 1 second to run
//	v0.7.0 (20230313):	completely rewritten beaming system
//						support of complex time signatures
//						support for rebeaming notes
//						addition of other plugin tools
//	v0.6.2 (20230205):	forceBeamM improvements and code restructuring
//	v0.6.1 (20230203):	Improved 8th beaming rules
//	v0.6.0 (20230202):	Beta Release

// Beaming rules source:
// Gould, Elaine (2011). Behind Bars: The definitive guide to music notation (1st ed.). Faber Music Ltd.
//
// If any rules are broken (and not due to user input) that is unintentional!
//
// For optimal results, make sure the beaming set by the plugin is in line with what is written in the score
// Additionally, make sure the score is not corrupt.
// The plugin also does not alter or rewrite any existing note values, for that use 'Tools/Regroup Rhythms'.

// Plugin Structure:
// Plugin:
// - mapMeasures function: logs length, start, and time signature of every measure
// - applyBeamingRules: applies beaming rules to a measure based on engraving rules,
//   chop, applyCorrections functions: fix mistakes left by applyBeamingRules
// - posBeamRests (in progress): automatically repositions notes and beams
// - onRun function: determines how to run the plugin (dockable or not, etc)
// - beamOverRests function: goes through score/selection and beams
// Presets folder: contains an editable list of rules
// Assets folder: contains other files needed by the plugin
// Reset.qml: Retroactively undoes any changes made by this plugin
// Simplify Tuplets.qml: A lightweight edit of the plugin that only focuses on tuplets

import QtQuick 2.0;
import MuseScore 3.0;
import QtQuick.Dialogs 1.2
import QtQuick.Controls 1.0
import QtQuick.Layouts 1.0
import Qt.labs.settings 1.0

MuseScore {
    description: (qsTr("This plugin resets changes made by 'Rebeam Music'.") + "\n" + 
		qsTr("Requires MuseScore 3.5 or later"))
    requiresScore: true;
    version: "1.0";
    menuPath: "Plugins." + qsTr("ReBeamer") + "." + qsTr("Reset")
	
	//settings vars
	property var beamType: beamNotes.checked ? (beamRests.checked ? 3 : 2) : (beamRests.checked ? 1 : 0)
	
	//function vars
	property var	mstart:	[];	//start tick of each measure
	property var	mlen:	[];	//length of each measure in ticks
	property var	maTsN:	[];	//only use to compare ts to previous one, or customising to each time change will be impossible
	property var	maTsD:	[];
	property var	mnTsN:	[];
	property var	mnTsD:	[];
	property var	mno:	0;	//measure number - 1
	property var	lm;			//the last measure (start tick), not counting the appended one
	property var	startStaff; //used to track selection
	property var	endStaff;
	property var	fullScore: false;
	property var	staff;
	property var	voice;
	
	Component.onCompleted : {
        if (mscoreMajorVersion >= 4) {
			title = qsTr("ReBeamer: Reset")
			//thumbnailName = "logo.png"
			categoryCode = "notes-rests"
        } //if
    }//component
	
	function mapMeasures() {
		//this function maps every measure in the score, their start ticks, their length, and their time signature.
		var cursor = curScore.newCursor();
		if (fullScore) {
			cursor.rewind(Cursor.SCORE_START);
		} else {
			cursor.rewind(Cursor.SELECTION_START);
		}
		while ((cursor.measure) && (cursor.measure.firstSegment.tick <= lm)) {
			var m = cursor.measure; 
			var aTsN = m.timesigActual.numerator;
			var aTsD = m.timesigActual.denominator;
			var nTsN = m.timesigNominal.numerator;
			var nTsD = m.timesigNominal.denominator;
			var mTicks = division * 4.0 * aTsN / aTsD;
			mstart.push(m.firstSegment.tick);
			mlen.push(mTicks);
			maTsN.push(aTsN);
			maTsD.push(aTsD);
			mnTsN.push(nTsN);
			mnTsD.push(nTsD);
			if (aTsN == nTsN && aTsD == nTsD) {
				console.log(mlen[mno] + " tick long measure at tick " + mstart[mno] + 
				". TS: " + maTsN[mno] + "/" + maTsD[mno] + ",  measure no. " + (mno+1));
			} else {
				console.log(mlen[mno] + " tick long measure at tick " + mstart[mno] + 
				". TS: " + mnTsN[mno] + "/" + mnTsD[mno] + " (actual: " + maTsN[mno] + "/" + maTsD[mno] + "),  measure no. " + (mno+1));
			}
			cursor.nextMeasure();
			mno += 1;
		} //while
		console.log("built measure map")
	} //function
	
	function smartRewind(cursorrrr, tick) {
		//rewinds to the correct place
		cursorrrr.rewindToTick(tick)
		cursorrrr.staffIdx = staff
		cursorrrr.voice = voice
	}
	
	function smartTick(tick) {
		//converts ticks into human readable beats, fit for the debug console
		var places = 3 //max number of decimal places
		var places2 = Math.pow(10, places)
		var beat = ((tick - mstart[mno]) / division) + 1
		if (countDecimals(beat) > 6) {
			beat = Math.round(beat * places2) / places2
		}
		return ("beat " + beat);
	}
	
	function countDecimals(value) {
		if (Math.floor(value) !== value) {
			return value.toString().split(".")[1].length || 0;
		} else {
			return 0;
		}
	}

	function getDuration(element) {
		//returns an element's duration as a number, outside of the fraction wrapper
		return (element.duration.numerator / element.duration.denominator);
	}//getDuration
	
	function validType(element) {
		if (element && (element.type == Element.REST || element.type == Element.NOTE || element.type == Element.CHORD)) {
			return true;
		} else {
			return false;
		}
	}//validType
	
	function validRest(element) {
		return (element && element.type == Element.REST)
	}//validRest
	
	function validNote(element) {
		return (element && (element.type == Element.NOTE || element.type == Element.CHORD))
	}//validNote
	
	function validTuplet(element) {
		return (element && element.tuplet)
	}
	
	function beamMode(tick, e, mode, type) {
		if (validType(e)) {
			//type variables: whether to expose the subdivisions in rests (1), notes (2), none (0), or both (3).
			
			//this cursor is needed to compare the element to beam with its preceding element
			//beam type settings otherwise give undesired results
			var cursorr = curScore.newCursor()
			smartRewind(cursorr, tick)
			while (cursorr.tick >= tick && tick != 0) {//cursor.prev() alone yields mixed results
				cursorr.prev()
			}
			
			switch (type) {
				case 0: {
					console.log("not beaming " + smartTick(tick))
					break;
				}
				case 1: {
					if (validRest(e) || validRest(cursorr.element)) {
						e.beamMode = mode
						console.log("beamed rest " + smartTick(tick) + " to " + mode)
					}
					break;
				}
				case 2: {
					if (validNote(e) && validNote(cursorr.element)) {
						e.beamMode = mode
						console.log("beamed note " + smartTick(tick) + " to " + mode)
					}
					break;
				}
				case 3: {
					e.beamMode = mode
					console.log("beamed " + smartTick(tick) + " to " + mode)
					break;
				}
				default: {
					console.log("error beaming")
					break;
				}
			}//switch
		}
	}//beamMode

    function applyReset() {
		var cursor = curScore.newCursor();            
		smartRewind(cursor, mstart[mno]);	//start of measure number mno, works for all voices
		
		//set all beaming to beammode 0
		while (cursor.next() && cursor.tick < mstart[mno] + mlen[mno]) {
			beamMode(cursor.tick, cursor.element, 0, beamType)
			if (validTuplet(cursor.element) && tupletShape.checked) {
				cursor.element.tuplet.bracketType = 0;
			}
		}
	}//applybeamingrules
			
	onRun: {
		if ((mscoreMajorVersion < 4 && mscoreMinorVersion < 3) || mscoreMajorVersion < 3) {
            Qt.quit()
        } else {
			resetDialog.open()
		}
	} //onrun
	
	Dialog {
		id: resetDialog
		title: qsTr("ReBeamer: Reset")
		ColumnLayout {
			spacing: 10
			anchors.margins: 10
			CheckBox {
				id: beamNotes
				text: qsTr("Reset Notes")
			}
			CheckBox {
				id: beamRests
				text: qsTr("Reset Rests")
			}
			CheckBox {
				id: tupletShape
				text: qsTr("Reset Tuplet Brackets")
			}
		}
		standardButtons: StandardButton.Cancel | StandardButton.Ok
		onAccepted: {
			curScore.startCmd()
			beamOverRests()
			curScore.endCmd()
			resetDialog.close()
			smartQuit()
		}
		onRejected: {
			resetDialog.close()
			smartQuit()
		}
	}
	
	function beamOverRests() {
		var c = curScore.newCursor()
		
		if (curScore.selection.isRange) {
			console.log(curScore.selection.startSegment, curScore.selection.endSegment, curScore.selection.startStaff, curScore.selection.endStaff)
			startStaff = curScore.selection.startStaff
			endStaff = curScore.selection.endStaff
			c.rewind(Cursor.SELECTION_END)
			if (c.tick == 0) {
				lm = curScore.lastMeasure.firstSegment.tick;
			} else {
				lm = c.measure.firstSegment.tick;
			}//else
        } else {
			fullScore = true;
            startStaff = 0; // start with 1st staff
            endStaff = curScore.nstaves; // and end with last
            lm = curScore.lastMeasure.firstSegment.tick;
		}
            
        mapMeasures()
        curScore.appendMeasures(1); //safety against weird ticks with end of score stuff, removed later on
		
        //error message, visible to end user in the score
        var msg  = newElement(Element.SYSTEM_TEXT);
        msg.text = qsTr("An error with the\nplugin has occured.")
        msg.size = 12;
        msg.placement = Placement.ABOVE;
        c.rewindToTick(curScore.lastMeasure.firstSegment.tick);
        c.add(msg);
            
		for (staff = startStaff; staff < endStaff; staff++) {
			console.log("In staff " + (staff+1))
			for (voice = 0; voice < 4; voice++) {
				console.log("In voice " + (voice+1))
				
				//add backup rest in last measure, safety against bad voice calculations
				smartRewind(c, curScore.lastMeasure.firstSegment.tick)
				c.addRest(c.duration)
				
				mno = 0; //used by other functions to count through score
				
				while (mno < mstart.length) {
					console.log("At measure " + (mno+1))
					applyReset();
					c.nextMeasure();
					mno += 1;
				} //while
			} //for voice
		} // for staff

		removeElement(curScore.lastMeasure);
        console.log("end");
	}//beamOverRests
	
	function smartQuit() {
		if (mscoreMajorVersion < 4) {
			Qt.quit()
		}
		else {
			quit()
		}
	}//smartQuit
	
	function addError(error) {
		var errtext  = newElement(Element.SYSTEM_TEXT);
		errtext.text = error
		errtext.size = 12;
		errtext.placement = Placement.BELOW;
		var cursor5 = curScore.newCursor()
		cursor5.rewindToTick(curScore.lastMeasure.firstSegment.tick);
		cursor5.add(errtext);
	}
	
	Settings {
		id: settings
		property alias beamNotes: beamNotes.checked
		property alias beamRests: beamRests.checked
		property alias tupletShape: tupletShape.checked
	}
} //MuseScore