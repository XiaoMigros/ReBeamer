// ReBeamer: Beam over rests and/or apply custom beaming rules
// Copyright (C) 2023 XiaoMigros

// Changelog:
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

//beamMode not available for MU4?? or beamMode available for notes only or different system

import QtQuick 2.0;
import MuseScore 3.0;
import "presets/tuplets.js" as TPS

MuseScore {
    description: (qsTr("This plugin simplifies tuplets where suitable.") + "\n" + 
		qsTr("Requires MuseScore 3.5 or later"))
    requiresScore: true;
    version: "1.0";
    menuPath: "Plugins." + qsTr("ReBeamer") + "." + qsTr("Simplify Tuplets")
	
	//tuplet settings vars
	property var teighthSplit		: []
	property var tsixteenthSplit	: []
	property var tthirtytwondSplit	: []
	property var tsixteenthSplit8	: []
	property var tthirtytwondSplit8	: []
	property var tthirtytwondSplit16: []
	property var tbeamType			: 0; //3
	property var tsS8type			: 0; //3
	property var ttS8type			: 0; //3
	property var ttS16type			: 0; //3
	property var simplifyTuplets	: true
	property var beamToFromTuplets	: true //currently not changeable
	property var beamTuplets		: true //currently not changeable
	
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
	property bool	tupletMode: false;
	
	Component.onCompleted : {
        if (mscoreMajorVersion >= 4) {
			title = qsTr("ReBeamer: Simplify Tuplets")
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
	}//smartTick
	
	function countDecimals(value) {
		if (Math.floor(value) !== value) {
			return value.toString().split(".")[1].length || 0;
		} else {
			return 0;
		}
	}//countDecimals

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
		if (element && element.type == Element.REST) {
			return true;
		} else {
			return false;
		}
	}//validRest
	
	function validNote(element) {
		if (element && (element.type == Element.NOTE || element.type == Element.CHORD)) {
			return true;
		} else {
			return false;
		}
	}//validNote
	
	function validTuplet(element) {
		if (element && element.tuplet) {
			return true;
		} else {
			return false;
		}
	}//validTuplet
	
	function beamMode(tick, e, mode, type) {
		if (validType(e) && validTuplet(e) && tick < (mstart[mno] + mlen[mno])) {
			//type variables: whether to expose the subdivisions in rests (1), notes (2), none (0), or both (3).
			
			//this cursor is needed to compare the element to beam with its preceding element
			//beam type settings otherwise give undesired results
			var cursorr = curScore.newCursor()
			smartRewind(cursorr, tick)
			while (cursorr.tick >= tick && tick != 0) {//cursor.prev() alone yields mixed results
				cursorr.prev()
			}
			//cursorr.staffIdx = staff
			//cursorr.voice = voice
			//console.log("previous = " + cursorr.tick)
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
		}//if
	}//beamMode

    function applyBeamingRules() {
		var cursor = curScore.newCursor();            
		smartRewind(cursor, mstart[mno]);	//start of measure number mno, works for all voices
		
		tupletMode = true;
		
		//apply beams (tuplet)
		applyTupletBeaming(mstart[mno], mstart[mno] + mlen[mno], cursor)
		
	}//applybeamingrules
	
	function getShortestNote(starttick, endtick) {
		var cursorrr = curScore.newCursor()
		smartRewind(cursorrr, starttick)
		cursorrr.rewindToTick(starttick) //both needed for some reason
		//do ticks work differently for different staves?
		//console.log("start: " + starttick + "actual: " + cursorrr.tick)
		
		var beatChart = []
		
		while (cursorrr.element && cursorrr.tick < endtick) {
			if (validType(cursorrr.element)) {
				if (cursorrr.element.tuplet && (! tupletMode)) {
					beatChart.push(getDuration(cursorrr.element.tuplet));
				} else {
					beatChart.push(getDuration(cursorrr.element));
				}//else
			}//if
			cursorrr.next()
		}//while
		
		if (beatChart.length > 0) {
			beatChart.sort();
			console.log("shortest note in range " + starttick + "-" + endtick + " is " + beatChart[0])
			return beatChart[0];
		} else {
			console.log("no beats found in range " + starttick + "-" + endtick)
			return false;
		}//else
	}//getShortestNote
	
	function chop(startTick, endTick, cursor) {
		console.log("chopping..")
		//remove rogue beams from start of group
		smartRewind(cursor, startTick)
		while (cursor.element && cursor.tick < endTick) {
			if (validNote(cursor.element)) {
				beamMode(cursor.tick, cursor.element, 1, tbeamType)
				break;
			}
			if (validRest(cursor.element)) {
				beamMode(cursor.tick, cursor.element, 0, tbeamType)
				cursor.next()
			}
		}
		
		//remove rogue beams from end of group
		smartRewind(cursor, endTick)
		cursor.prev()
		while (validRest(cursor.element) && cursor.tick >= startTick) {
			beamMode(cursor.tick, cursor.element, 0, tbeamType)
			cursor.prev()
		}
		console.log("ended chopping")
	}//chop
	
	function applyTupletBeaming(startTick, endTick, cursor) {
		smartRewind(cursor, startTick)
		console.log("applying tuplet beaming...")
		while (cursor.element && cursor.tick < endTick) {
			if (validTuplet(cursor.element)) {
				var e = cursor.element;
				var tupletTracker	= []
				var tupletDuration	= 0;
				var tupletLength	= getDuration(e.tuplet) * division * 4.0;
				//tupletLength: absolute; tupletDuration: relative to inside tuplet
				var tupletStart	= cursor.tick;
				var tupletEnd	= tupletStart + tupletLength;
				var tupletN		= e.tuplet.actualNotes;
				var tupletD		= e.tuplet.normalNotes;
				
				while (cursor.element && cursor.tick < tupletEnd) {
					//walks through tuplet and logs all the relative note lengths
					tupletTracker.push(getDuration(cursor.element))
					cursor.next();
				}
				for (var i in tupletTracker) {
					tupletDuration += tupletTracker[i]
					//adds all the note lengths together to form the relative length of the tuplet
				}
				var tupletBaseLength = tupletDuration / tupletN
				//modified beaming functions for tuplet, using tuplet divisioned tick values
				
				var tupletBaseLengthActual = tupletLength / tupletN
				//actual value of one base unit in ticks
				
				console.log(tupletN + "/" + tupletD + " tuplet located.\n" + 
				"external duration: " + tupletLength  + ", internal duration: " + tupletDuration + " (Base Length: " + tupletBaseLength +
				", actual: " + tupletBaseLengthActual + ")" + "\nstarts at: " + tupletStart + ", ends at: " + tupletEnd)
				
				smartRewind(cursor, tupletStart)
				if (cursor.tick != 0) {
					cursor.prev()
				}
				
				var tupletsettings = TPS.getTupletRules(tupletN, tupletBaseLength)
				
				teighthSplit		= tupletsettings[0]
				tsixteenthSplit		= tupletsettings[1]
				tthirtytwondSplit	= tupletsettings[2]
				tsixteenthSplit8	= tupletsettings[3]
				tthirtytwondSplit8	= tupletsettings[4]
				tthirtytwondSplit16	= tupletsettings[5]
				tbeamType			= tupletsettings[6]
				tsS8type			= tupletsettings[7]
				ttS8type			= tupletsettings[8]
				ttS16type			= tupletsettings[9]
				simplifyTuplets		= tupletsettings[10]
				beamToFromTuplets	= tupletsettings[11]
				beamTuplets			= tupletsettings[12]
				
				if (beamTuplets) {
					//set all beaming to beammode 2;
					while (cursor.next() && cursor.tick < tupletEnd) {
						beamMode(cursor.tick, cursor.element, 2, tbeamType)
					}
					
					var relWHoleNote = tupletD / tupletN * division * 4.0
					//whole note relative to internal tuplet durations, used for calculating ticks
					var shortestNote = getShortestNote(tupletStart, tupletEnd)
					if (shortestNote < 0.25 && shortestNote != false) {
						for (var i = 0; (i+1) < teighthSplit.length; ++i) {
							var shortestNote = getShortestNote(tupletStart + teighthSplit[i] * (relWHoleNote/8), tupletStart + teighthSplit[i+1] * (relWHoleNote/8))
							if (shortestNote < 0.125) {
								for (var j = 0; tsixteenthSplit[j] * (relWHoleNote/16) < teighthSplit[i+1] * (relWHoleNote/8); ++j) {
									if (tsixteenthSplit[j] * (relWHoleNote/16) >= teighthSplit[i] * (relWHoleNote/8)) {
										var shortestNote = getShortestNote(tupletStart + tsixteenthSplit[j] * (relWHoleNote/16), tupletStart + tsixteenthSplit[j+1] * (relWHoleNote/16))
										if (shortestNote < 0.0625) {
											for (var k = 0; tthirtytwondSplit[k] * (relWHoleNote/32) < tsixteenthSplit[j+1] * (relWHoleNote/16); ++k) {
												if (tthirtytwondSplit[k] * (relWHoleNote/32) >= tsixteenthSplit[j] * (relWHoleNote/16)) {
													//var shortestNote = getShortestNote etcetc if wanted to expand for smaller notes
													//the below code would then go in the else, (of if shortest note > 32nd)
													for (var kk = 0; tthirtytwondSplit16[kk] * (relWHoleNote/32) < tthirtytwondSplit[k+1] * (relWHoleNote/32); ++kk) {
														if (tthirtytwondSplit16[kk] * (relWHoleNote/32) >= tthirtytwondSplit[k] * (relWHoleNote/32)) {
															smartRewind(cursor, (tupletStart + tthirtytwondSplit16[kk] * (relWHoleNote/32)))
															beamMode(cursor.tick, cursor.element, 6, ttS16type);
														}
													}
													for (var ii = 0; tthirtytwondSplit8[ii] * (relWHoleNote/32) < tthirtytwondSplit[k+1] * (relWHoleNote/32); ++ii) {
														if (tthirtytwondSplit8[ii] * (relWHoleNote/32) >= tthirtytwondSplit[k] * (relWHoleNote/32)) {
															smartRewind(cursor, (tupletStart + tthirtytwondSplit8[ii] * (relWHoleNote/32)))
															beamMode(cursor.tick, cursor.element, 5, ttS8type);
														}
													}
													console.log("beaming tuplet as 32nds")
												}
											}
										} else {
											for (var jj = 0; tsixteenthSplit8[jj] * (relWHoleNote/16) < tsixteenthSplit[j+1] * (relWHoleNote/16); ++jj) {
												if (tsixteenthSplit8[jj] * (relWHoleNote/16) >= tsixteenthSplit[j] * (relWHoleNote/16)) {
													smartRewind(cursor, (tupletStart + tsixteenthSplit8[jj] * (relWHoleNote/16)))
													beamMode(cursor.tick, cursor.element, 5, tsS8type);
												}
											}
											console.log("beaming tuplet as 16ths")
										}
									}
								}
							} else {
								console.log("beaming tuplet as 8ths")
							}
						}
					} else {
						console.log("nothing to beam in this tuplet")
					}
					
					console.log("applying tuplet corrections")
					
					//remove beams to and from >= 4th notes
					smartRewind(cursor, tupletStart);
					while (cursor.element && cursor.tick < tupletEnd) {
						if (validNote(cursor.element) && getDuration(cursor.element) >= 0.25) {
							//only treat tuplets as one unit if we arent in a tuplet!! (todo: sort subtuplets)
							//if a note is 4th or longer
							
							//reset it
							beamMode(cursor.tick, cursor.element, 0, tbeamType)
							var temptick = cursor.tick
							
							//undo preceding rests...
							cursor.prev();
							while (validRest(cursor.element) && cursor.tick >= mstart[mno]) {
								beamMode(cursor.tick, cursor.element, 0, tbeamType)
								cursor.prev();
							}//while
							
							//... and undo succeeding rests
							cursor.rewindToTick(temptick)
							
							cursor.next();
							while (cursor.element && cursor.tick < mstart[mno] + mlen[mno]) {
								if (validNote(cursor.element)) {
									beamMode(cursor.tick, cursor.element, 1, tbeamType)
									break;
								}
								if (validRest(cursor.element)) {
									beamMode(cursor.tick, cursor.element, 0, tbeamType)
									cursor.next()
								}
							}
							
							cursor.rewindToTick(temptick)
						}//if
						cursor.next();
					}//while
					
					chop(tupletStart, tupletEnd, cursor)
					
					console.log("applied corrections to tuplet")
				}//if beamTuplets
				
				//remove excessive brackets around tuplet
				if (simplifyTuplets) {
					smartRewind(cursor, tupletStart)
					var notes = []
					var k = 0;
					var actSimplifytuplets = true;
					if (tupletBaseLength >= 0.25) {
						actSimplifytuplets = false;
					}
					while (validType(cursor.element) && cursor.tick < tupletEnd) {
						if (validNote(cursor.element)) {
							notes.push(k)
						}//if
						if (getDuration(cursor.element) >= 0.25) {
							actSimplifytuplets = false;
						}
						k += 1
						cursor.next();
					}//while
					cursor.rewindToTick(tupletStart)
					if (notes[0] == 0 && notes[notes.length-1] == k-1 && actSimplifytuplets) {
						cursor.element.tuplet.bracketType = 2;
						//0 = auto, 1 = brackets, 2 = no brackets
						console.log("simplified tuplet brackets!")
					}
				}//if simplifyTuplets
				
				smartRewind(cursor, tupletEnd)
				cursor.prev()
			}//if tuplet found
			cursor.next()
		}//while
		console.log("applied tuplet beaming...")
	}//applyTupletBeaming
			
	onRun: {
		if ((mscoreMajorVersion < 4 && mscoreMinorVersion < 3) || mscoreMajorVersion < 3) {
            Qt.quit()
        } else {
			curScore.startCmd()
			beamOverRests()
			curScore.endCmd()
		}
	} //onrun
	
	function beamOverRests() {
	
		var c = curScore.newCursor()
		
		if (! curScore.selection.isRange && (dockable && validType(cur.element))) {
			curScore.selection.selectRange(cur.tick, cur.tick+1, cur.staffIdx, cur.staffIdx);
		}
		if (curScore.selection.isRange) {
			console.log(curScore.selection.startTick, curScore.selection.endTick, curScore.selection.startStaff, curScore.selection.endStaff)
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
					applyBeamingRules();
					c.nextMeasure();
					mno += 1;
				} //while
			} //for voice
		} // for staff

		removeElement(curScore.lastMeasure);
        console.log("end");
		smartQuit()
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
} //MuseScore