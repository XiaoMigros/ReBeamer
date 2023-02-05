// Beam Over Rests

// Changelog:
//	v0.6.2 (20230205):  forceBeamM improvements and code restructuring
//	v0.6.1 (20230203):	Improved 8th beaming rules
//	v0.6.0 (20230202):	Beta Release

// Beaming rules source:
// Gould, Elaine (2011). Behind Bars: The definitive guide to music notation (1st ed.). Faber Music Ltd.
//
// If any rules are broken (and not due to user input) that is unintentional!
//
// For optimal results, make sure that the notes' default beaming groups are the same as the plugin's ones.
// Currently, the plugin only minimally rebeams notes.
// This may be changed in a future update, so the beaming is correct as defined regardless of time signature.
// The plugin also does not alter or rewrite any existing note values, for that use 'Tools/Regroup Rhythms'.

// Plugin Structure:
// - mapMeasures function: logs length, start, and time signature of every measure
// - applyBeamingRules: applies beaming rules to a measure based on engraving rules,
//   user settings and mapMeasure values. Runs other functions to clean up any mistakes.
// - Beam functions: Beam note values according to parameters from applyBeamingRules
// - posBeamRests (in progress): automatically repositions notes and beams
// - onRun function: combines above functions to correctly beam over rests

import QtQuick 2.9;
import MuseScore 3.0;
//import Qt.labs.settings 1.0

MuseScore {
    description: "This plugin adds beams over rests, following standard music notation." + 
    "\nBest applied at the end of the score creation process, and after running 'Tools/Regroup Rhythms'.";
    requiresScore: true;
    version: "0.6.2";
    menuPath: "Tools.Beam Over Rests";
	
	Component.onCompleted : {
        if (mscoreMajorVersion >= 4) {
			title = qsTr("Beam Over Rests") ;
			//thumbnailName = "logo.png";
			categoryCode = "notes-rests";
        } //if
    }//component
	
    function mapMeasures(mstart, mlen, maTsN, maTsD, mnTsN, mnTsD, mno, fullScore, lm) {
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
            mno = mno + 1;
        } //while                   
        console.log("built measure map")

    } //function

    function applyBeamingRules(m, mstart, mlen, maTsN, maTsD, mnTsN, mnTsD, mno, staff, voice) {
    //this function tells the program how to beam each section in the score.
    //all beaming settings will only change this part of the plugin.
		var cursor = curScore.newCursor();            
		cursor.rewindToTick(mstart[mno])    //start of measure number mno, works for all voices
		cursor.voice = voice;
		cursor.staffIdx = staff;
		var timesig = (mnTsN[mno] + "/" + mnTsD[mno])
		var actTimesig = (maTsN[mno] + "/" + maTsD[mno])            
		//by using the nominal (written) time signature rather than the actual one,
		//the plugin can apply correct beaming rules to shortened measures.
		var tuplet8unbeam = new Array(); //used to unbeam tuplet mistakes with a base length of 8 or longer
		var tuplet16unbeam = new Array(); // " 16
		var tuplet32unbeam = new Array(); // " 32 or shorter
		
		//SETTINGS============================================================================================================================
		
		//general
		var forceBeamM = false; //beams everything in a measure together
		var forceBeamG = false; //beams everything in a(n 8th) group together, useful for cut time, will force activation of beam8, beam16 and beam32
		
		//regular beaming
		var beam8 = true; //whether 8ths are beamed over in general
		var beam8474 = true; // " in 4/4
		var beam8274 = false; // " in 2/4
		var beam16 = true;
		var beam32 = true; //currently also beams values smaller than 32nds
		
		//tuplets
		var beamTuplets = true; //whether tuplets are beamed over
		var beamToTuplets = true; //whether tuplets are beamed to the preceding notes
		var beamFromTuplets = true; // " suceeding notes
		var simplifyTuplets = true; //whether the tuplet bracket will be removed where applicable
		var beamLongerTuplets = true; //whether 4th, 2nd, or larger note tuplets will be beamed over where applicable
		var tupletForceBeamG = true; //these ones should be clear
		var tupletBeam8 = true;
		var tupletBeam16 = true;
		var tupletBeam32 = true;
		
		//====================================================================================================================================
            
		//TIME SIGNATURE SETTINGS=============================================================================================================
		
		//settings for X/4 timesigs
		if (mnTsD[mno] == 4) {
			  //prompt user settings for forceBeamG, beam8, beam8 in 4/4 or 2/4, and splitbeam/divnotes stuff
			  //set splitbeams to []; if not wanted
			  //settings are neatly allocated for now but can be moved up when needed
			  
			  //32nds
			  var splitBeam1 = [2, 4, 6]; //splits into 16th/32nd, 4 not necessarily needed
			  var splitBeam2 = [4]; //splits into 8th/16th
			  var divNotes1 = false;
			  var divNotes2 = true;
			  var divNotesPlus = false; //split notes larger than 32nd into 8th/16th
			  if (beam32) {
					for (var i = 0; i < mnTsN[mno]; ++i) {
						  thirtytwond(mstart[mno]+(480*i), 8, splitBeam1, splitBeam2, divNotes1, divNotes2, divNotesPlus, mstart, mlen, maTsN, maTsD, mno, staff, voice, beam32)
						  tuplet32unbeam.push(480*i)
						  } //for
					} //32nds
			  
			  //16ths
			  var splitBeam = [2]; //does 8th 16th after 2nd 16th note, used here to do 8th16th instead of 16th16th
			  var divNotes = false; //whether notes should be 8th,16th (true) or 16th,16th (false)
			  var splitBeamOverride = []; //splits notes and rests regardless of splitbeam, useful for /2 and /1 keysigs
			  if (beam16) {
					for (var i = 0; i < mnTsN[mno]; ++i) {                              
						  sixteenth(mstart[mno]+(480*i), 4, splitBeam, divNotes, splitBeamOverride, mstart, mlen, maTsN, maTsD, mno, staff, voice, beam16)
						  tuplet16unbeam.push(480*i)
						  } //for
					} //16ths
					
			  //eighths
			  //var beam8474 = true;
			  //var beam8274 = true;
			  //for other timesigs do nothing or todo: prompt user settings/input
			  if((forceBeamG || beam8) && ((mnTsN[mno] == 4 && beam8474 == true) || (mnTsN[mno] == 2 && beam8274 == true))) {
					for(var i = 0; i < mnTsN[mno]/2; ++i) {
						  eighth(mstart[mno]+(960*i), 4, mstart, mlen, maTsN, maTsD, mno, staff, voice, forceBeamG, forceBeamM)
						  tuplet8unbeam.push(960*i)
						  }//for
					}//eighths
			  }// X/4 timesigs
            
        //settings for X/8 timesigs
        if (mnTsD[mno] == 8) {
            //3X/8 (3/8, 6/8, 9/8, ...)
            if (mnTsN[mno] % 3 == 0) {
				forceBeamG = true;     
		  
				//32nds
				var splitBeam1 = [2, 4, 6, 8, 10];
				var splitBeam2 = [4, 8]; //splits into 8th/16th
				var divNotes1 = false;
				var divNotes2 = true;
				var divNotesPlus = false; //split notes larger than 32nd into 8th/16th
				if (beam32) {
					for (var i = 0; i < mnTsN[mno]/3; ++i) {
						thirtytwond(mstart[mno]+(720*i), 12, splitBeam1, splitBeam2, divNotes1, divNotes2, divNotesPlus, mstart, mlen, maTsN, maTsD, mno, staff, voice, beam32)
						tuplet32unbeam.push(720*i)
					} //for
				} //32nds
				
				//16ths
				var splitBeam = [2, 4]; //does 8th 16th after 2nd 16th note
				var divNotes = false; //whether notes should be 8th,16th (true) or 16th,16th (false)
				var splitBeamOverride = []; //splits notes and rests regardless of splitbeam, useful for /2 and /1 keysigs
				//used here to do 8th16th instead of 16th16th      
				if (beam16) {
					for (var i = 0; i < mnTsN[mno]/3; ++i) {                              
						sixteenth(mstart[mno]+(720*i), 6, splitBeam, divNotes, splitBeamOverride, mstart, mlen, maTsN, maTsD, mno, staff, voice, beam16)
						tuplet16unbeam.push(720*i)
					} //for
				} //16ths
		  
				//eighths
				if (forceBeamG || beam8) {
				//differentiate between force and regular in eighth function itself
					for (var i = 0; i < mnTsN[mno]/3; ++i) {
						eighth(mstart[mno]+(720*i), 3, mstart, mlen, maTsN, maTsD, mno, staff, voice, forceBeamG, forceBeamM)
						tuplet8unbeam.push(720*i)
						}//for
				} //else forceBeamG
				
			}// 3X/8
                        
			if (mnTsN[mno] % 3 != 0) {
				//assumes X groups of 1 8th
				forceBeamG = false;                  
		  
				//32nds
				var splitBeam1 = [2];
				var splitBeam2 = []; //splits into 8th/16th
				var divNotes1 = false;
				var divNotes2 = true;
				var divNotesPlus = false; //split notes larger than 32nd into 8th/16th
				if (beam32) {
					for (var i = 0; i < mnTsN[mno]; ++i) {
						thirtytwond(mstart[mno]+(240*i), 4, splitBeam1, splitBeam2, divNotes1, divNotes2, divNotesPlus, mstart, mlen, maTsN, maTsD, mno, staff, voice, beam32)
						tuplet32unbeam.push(240*i)
						tuplet16unbeam.push(240*i)
						tuplet8unbeam.push(240*i)
					} //for
				} //32nds
				
				//16ths
				var splitBeam = []; //does 8th 16th after 2nd 16th note
				var divNotes = false; //whether notes should be 8th,16th (true) or 16th,16th (false)
				var splitBeamOverride = []; //splits notes and rests regardless of splitbeam, useful for /2 and /1 keysigs
				//used here to do 8th16th instead of 16th16th      
				if (beam16) {
					for (var i = 0; i < mnTsN[mno]; ++i) {                              
						//sixteenth(mstart[mno]+(240*i), 2, splitBeam, divNotes, splitBeamOverride, mstart, mlen, maTsN, maTsD, mno, staff, voice, beam16)
						//not needed since no rests to beam over
					} //for
				} //16ths
		  
				//eighths; not needed (for now)
				
			}//other /8 timesigs
                              
        }// X/8 timesigs
                  
		//settings for X/2 and X/1 timesigs
		if (mnTsD[mno] == 2) {
			//console.log("X/2 detected")
			forceBeamG = true;
			
			//32nds
			var splitBeam1 = [2, 4, 6]; //splits into 16th/32nd, 4 not necessarily needed
			var splitBeam2 = [4]; //splits into 8th/16th
			var divNotes1 = false;
			var divNotes2 = true;
			var divNotesPlus = false; //split notes larger than 32nd into 8th/16th 
			if (beam32) {
				for (var i = 0; i < (mnTsN[mno]/mnTsD[mno]*4); ++i) {
					thirtytwond(mstart[mno]+(480*i), 8, splitBeam1, splitBeam2, divNotes1, divNotes2, divNotesPlus, mstart, mlen, maTsN, maTsD, mno, staff, voice, beam32)
					tuplet32unbeam.push(480*i)
				} //for
			} //32nds
			  
			//16ths
			var splitBeam = [2, 4, 6]; //does 8th 16th after 2nd 16th note, used here to do 8th16th instead of 16th16th
			var divNotes = false; //whether notes should be 8th,16th (true) or 16th,16th (false)
			var splitBeamOverride = [4]; //splits notes and rests regardless of splitbeam, useful for /2 and /1 keysigs
			if (beam16) {
				for (var i = 0; i < (mnTsN[mno]/mnTsD[mno]*2); ++i) {                              
					sixteenth(mstart[mno]+(960*i), 8, splitBeam, divNotes, splitBeamOverride, mstart, mlen, maTsN, maTsD, mno, staff, voice, beam16)
					tuplet16unbeam.push(960*i)
				} //for
			} //16ths
					
			//eighths
			//for other timesigs do nothing or todo: prompt user settings/input
			if (forceBeamG || beam8) {
				for(var i = 0; i < mnTsN[mno]/2; ++i) {
					eighth(mstart[mno]+(960*i), 4, mstart, mlen, maTsN, maTsD, mno, staff, voice, forceBeamG, forceBeamM)
					tuplet8unbeam.push(960*i)
				}//for
			}//eighths
				
		}// X/2 and X/1 timesigs
			  
        //====================================================================================================================================
            
		//ForcebeamM
		//still a little buggy, fix planned soon
		if (forceBeamM) {
			forceBeamG = true;
			beam8 = true;
			beam16 = true;
			beam32 = true;
			beamTuplets = true;
			beamToTuplets = true;
			beamFromTuplets = true;
			beamLongerTuplets = true;
			tupletForceBeamG = true;
			tupletBeam8 = true;
			tupletBeam16 = true;
			tupletBeam32 = true;
			//only runs 8th to preserve 16th and 32nd subdivisions
			eighth(mstart[mno], (mnTsN[mno] / mnTsD[mno])*8, mstart, mlen, maTsN, maTsD, mno, staff, voice, forceBeamG, forceBeamM);
			
			//if notes are outside of the 32nd/16th groups
			cursor.rewindToTick(mstart[mno])
			cursor.voice = voice;
			cursor.staffIdx = staff;
			while (cursor.element && cursor.tick < mstart[mno] + mlen[mno]) {
				if (cursor.element && cursor.element.type == Element.REST && cursor.element.beamMode == 0) {
					cursor.element.beamMode = 2;
				}
				if (cursor.element == Element.CHORD && cursor.element.beamMode <= 1) {
					cursor.element.beamMode = 2;
				}
				cursor.next();
			}
			
		}//if forceBeamM
            
		//TUPLETS=============================================================================================================================
		fBeamTuplets(m, mstart, mlen, maTsN, maTsD, mnTsN, mnTsD, mno, staff, voice, beamTuplets, beamToTuplets, beamFromTuplets, simplifyTuplets, beamLongerTuplets,
			tupletForceBeamG, tupletBeam8, tupletBeam16, tupletBeam32, forceBeamM, forceBeamG, tuplet8unbeam, tuplet16unbeam, tuplet32unbeam, cursor)
		//once these are in a time signature definition, complex timesigs can work
		//====================================================================================================================================
		
		//APPLY CORRECTIONS===================================================================================================================
		applyCorrections(m, mstart, mlen, maTsN, maTsD, mnTsN, mnTsD, mno, staff, voice, cursor)
		//====================================================================================================================================
		
	} //applyBeamingRules
    
	function fBeamTuplets(m, mstart, mlen, maTsN, maTsD, mnTsN, mnTsD, mno, staff, voice, beamTuplets, beamToTuplets, beamFromTuplets, simplifyTuplets, beamLongerTuplets,
			tupletForceBeamG, tupletBeam8, tupletBeam16, tupletBeam32, forceBeamM, forceBeamG, tuplet8unbeam, tuplet16unbeam, tuplet32unbeam, cursor) {
				
		//First unbeam them
		cursor.rewindToTick(mstart[mno]);
		cursor.voice = voice;
		cursor.staffIdx = staff;
		var notes = new Array();
		while (cursor.tick && cursor.tick < (mstart[mno]+mlen[mno])) {
			  cursor.voice = voice;
			  cursor.staffIdx = staff;
			  var e = cursor.element;
			  if (e && e.tuplet) {
					//console.log("TUPLET")
					//if (beamTuplets) {
						//e.beamMode = 5
					//} else {
						e.beamMode = 0;
					//}
				}//if tuplet
			  cursor.next();
		}//while
		
		//rebeam them if required
		if (beamTuplets) {
			cursor.rewindToTick(mstart[mno]);
			cursor.voice = voice;
			cursor.staffIdx = staff;
			while (cursor.element && cursor.tick && cursor.tick < (mstart[mno]+mlen[mno])) {
				if (cursor.element && cursor.element.tuplet) {
					var e = cursor.element;
					var tupletTracker = new Array();
					var tupletDuration = 0;
					var tupletLength = (e.tuplet.duration.numerator/e.tuplet.duration.denominator)*1920;
					//tupletLength: absolute; tupletDuration: relative to inside tuplet
					var tupletStart = cursor.tick;
					var tupletEnd = tupletStart + tupletLength;
					var tupletN = e.tuplet.actualNotes;
					var tupletD = e.tuplet.normalNotes;
					
					//calculate whether beam to/from tuplet should be considered
					////cursor.rewindToTick(tupletStart)
					//var e = cursor.element;
					//cursor.prev();
					//if	(e.duration.numerator/e.duration.denominator < 0.25 && beamToTuplets == true &&
					//	cursor.element && cursor.element.beamMode != 4 && cursor.element.beamMode != 0)
					
					while (cursor.element && cursor.tick < tupletEnd) {
						//walks through tuplet and logs all the relative note lengths
						var ed = cursor.element.duration;
						tupletTracker.push(ed.numerator/ed.denominator);
						cursor.next();
					}
					for (var i = 0; i < tupletTracker.length; i++) {
						tupletDuration = tupletDuration + tupletTracker[i]
						//adds all the note lengths together to form the relative length of the tuplet
					}
					var tupletBaseLength = tupletDuration / tupletN
					//modified beaming functions for tuplet, using tuplet divisioned tick values
					
					//var tupletBaseLengthActual = tupletDuration*1920 / tupletLength
					var tupletBaseLengthActual = tupletDuration*division;
					//actual value of one base unit in ticks
					
					console.log(tupletN + "/" + tupletD + " tuplet located.\n" + 
					"external duration: " + tupletLength  + ", internal duration: " + tupletDuration + " (Base Length: " + tupletBaseLength +
					", actual: " + tupletBaseLengthActual + ")" + "\nstarts at: " + tupletStart + ", ends at: " + tupletEnd)
					
					if (tupletBaseLength < 0.25 || beamLongerTuplets == true) {
						
						//32nds
						var tupletSplitBeam1 = []; //splits into 16th/32nd
						var tupletSplitBeam2 = []; //splits into 8th/16th
						var tupletDivNotes1;
						var tupletDivNotes2;
						var tupletDivNotesPlus; //split notes larger than 32nd into 8th/16th
						if (tupletBaseLength >= 0.125) {
							for (var i = 1; i < tupletN*16*tupletBaseLength; ++i) {
								tupletSplitBeam1.push(2*i)
							}//for
							for (var i = 1; i < tupletN*8*tupletBaseLength; ++i) {
								tupletSplitBeam2.push(4*i)
							}//for
						}//for
						if (tupletBaseLength == 0.0625) {
							for (var i = 1; i < tupletN; ++i) {
								tupletSplitBeam1.push(2*i)
							}//for
						}//for
						if (tupletBaseLength <= 0.03125) {
							for (var i = 1; i < tupletN; ++i) {
								tupletSplitBeam1.push(i)
							}//for
						}//for
						tupletDivNotes1 = false;
						tupletDivNotes2 = true;
						tupletDivNotesPlus = false; //split notes larger than 32nd into 8th/16th
						//tuplet = 1/8, tupletN*4
						//tuplet = 1/16, tupletN*2
						//tuplet = 1/32, tupletN
						
						if (tupletBeam32) {
							var number = tupletN * (32*tupletBaseLength);
							var btick = tupletBaseLengthActual / (32*tupletBaseLength);
						
							tupletThirtytwond(tupletStart, tupletEnd, number, btick, tupletN, tupletBaseLength, tupletBaseLengthActual,
							tupletSplitBeam1, tupletSplitBeam2, tupletDivNotes1, tupletDivNotes2, tupletDivNotesPlus, tupletBeam32,
							beamToTuplets, beamFromTuplets, voice, staff);
						}
						
						//16ths
						var tupletSplitBeam = [2, 4]; //does 8th 16th after 2nd 16th note
						var tupletDivNotes = true; //whether notes should be 8th,16th (true) or 16th,16th (false)
						var tupletSplitBeamOverride = []; //splits notes and rests regardless of splitbeam, useful for /2 and /1 keysigs
						//used here to do 8th16th instead of 16th16th
						if (tupletBaseLength >= 0.125) {
							for (var i = 1; i < tupletN*8*tupletBaseLength; ++i) {
								tupletSplitBeam.push(2*i)
							}
						}
						if (tupletBaseLength <= 0.0625) {
							for (var i = 1; i < tupletN; ++i) {
								tupletSplitBeam.push(i)
							}
						}
						
						if (tupletBeam16) {
							var number = tupletN * (16*tupletBaseLength);
							var btick = tupletBaseLengthActual / (16*tupletBaseLength);
							
							tupletSixteenth(tupletStart, tupletEnd, number, btick, tupletN, tupletBaseLength, tupletBaseLengthActual,
							tupletSplitBeam, tupletDivNotes, tupletSplitBeamOverride, tupletBeam16,
							beamToTuplets, beamFromTuplets, voice, staff);
						}
						
						//8ths
						if (tupletForceBeamG || tupletBeam8) {
							var number = tupletN * (8*tupletBaseLength);
							var btick = tupletBaseLengthActual / (8*tupletBaseLength);
							
							tupletEighth(tupletStart, tupletEnd, number, btick, tupletN, tupletBaseLength, tupletBaseLengthActual, tupletForceBeamG, voice, staff);
						}
					}//if tuplet will be beamed
					
					//remove excessive brackets around tuplet
					if (simplifyTuplets == true) {
						cursor.rewindToTick(tupletStart);
						cursor.voice = voice;
						cursor.staffIdx = staff;
						var notes = new Array();
						var k = 0;
						var actSimplifytuplets = true;
						if (tupletBaseLength >= 0.25) {
							actSimplifytuplets = false;
						}
						while (cursor.element && cursor.tick && cursor.tick < tupletEnd) {
							cursor.voice = voice;
							cursor.staffIdx = staff;
							var e = cursor.element;
							if (e && e.type == Element.CHORD) {
								//null needed as failsafe against empty voices
								notes.push(k)
							}//if
							if (e.duration.numerator / e.duration.denominator >= 0.25) {
								actSimplifytuplets = false;
							}
							k = k + 1
							cursor.next();
						}//while
						k = k - 1;
						cursor.rewindToTick(tupletStart)
						if (notes[0] == 0 && notes[notes.length - 1] == k && actSimplifytuplets == true) {
							console.log("simplifying tuplet")
							//console.log(cursor.element.tuplet.bracketType)
							cursor.element.tuplet.bracketType = 2;
							//0 = auto, 1 = brackets, 2 = no brackets
						}
					}//if simplifyTuplets
					
					cursor.rewindToTick(tupletEnd);
					cursor.prev();
				}//if tuplet found
				cursor.next();
			}//while
		}//if beamtuplets
		
		//beam to tuplets
		if (beamToTuplets == true) {
			cursor.rewindToTick(mstart[mno]);
			cursor.voice = voice;
			cursor.staffIdx = staff;
			while (cursor.element && cursor.tick && cursor.tick < (mstart[mno]+mlen[mno])) {
				if (cursor.element && cursor.element.tuplet) {
					var e = cursor.element;
					var t = cursor.tick;
					cursor.prev();
					if (cursor.element && ((cursor.element.beamMode != 0 && cursor.element.type == Element.REST) ||
					(cursor.element.type == Element.CHORD && cursor.element.duration.numerator/cursor.element.duration.denominator < 0.25))) {
						e.beamMode = 5;
						cursor.next();
						cursor.next();
						while (cursor.element && cursor.element.type == Element.REST) {
							cursor.element.beamMode = 5;
							cursor.next();
						}//while
					}
					cursor.rewindToTick(t + (e.tuplet.duration.numerator/e.tuplet.duration.denominator) * 1920);
					cursor.prev();
				}
				cursor.next();
			} //while
		} else {
			cursor.rewindToTick(mstart[mno]);
			cursor.voice = voice;
			cursor.staffIdx = staff;
			while (cursor.element && cursor.tick && cursor.tick < (mstart[mno]+mlen[mno])) {
				if (cursor.element && cursor.element.tuplet) {
					var e = cursor.element;
					var t = cursor.tick;
					e.beamMode = 0;
					cursor.prev();
					while (cursor.element && cursor.element.type == Element.REST) {
						cursor.element.beamMode = 0;
						cursor.prev();
					}//while
					cursor.rewindToTick(t + (e.tuplet.duration.numerator/e.tuplet.duration.denominator) * 1920);
				} else {
				cursor.next();
				}
			} //while
		} //if beamtotuplets
		
		//beam from tuplets
		if (beamFromTuplets == true) {
			cursor.rewindToTick(mstart[mno]+mlen[mno]);
			cursor.voice = voice;
			cursor.staffIdx = staff;
			cursor.prev();
			while (cursor.element && cursor.tick && cursor.tick >= (mstart[mno])) {
				if (cursor.element && cursor.element.tuplet) {
					var e = cursor.element;
					cursor.next();
					var t = cursor.tick;
					if (cursor.element && ((cursor.element.beamMode != 0 && cursor.element.type == Element.REST) ||
					(cursor.element.type == Element.CHORD && cursor.element.duration.numerator/cursor.element.duration.denominator < 0.25))) {
						e.beamMode = 5;
						//show 8th subdivisions if tuplet and note are a 16th or smaller
						if (e.type == Element.CHORD && cursor.element.type == Element.CHORD && 
						e.duration.numerator/e.duration.denominator < 0.125 && cursor.element.duration.numerator/cursor.element.duration.denominator < 0.125) {
							cursor.element.beamMode = 5;
						}
						cursor.prev();
						cursor.prev();
						while (cursor.element && cursor.element.type == Element.REST) {
							cursor.element.beamMode = 5;
							cursor.prev();
						}//while
					}
					cursor.rewindToTick(t - (e.tuplet.duration.numerator/e.tuplet.duration.denominator) * 1920);
				}//if tuplet
				cursor.prev();
			} //while
		} else {
			cursor.rewindToTick(mstart[mno]+mlen[mno]);
			cursor.voice = voice;
			cursor.staffIdx = staff;
			//var t = cursor.tick;
			cursor.prev();
			while (cursor.element && cursor.tick && cursor.tick >= (mstart[mno])) {
				if (cursor.element && cursor.element.tuplet) {
					var e = cursor.element;
					e.beamMode = 0;
					cursor.next();
					var t = cursor.tick;
					while (cursor.element && cursor.element.type == Element.REST) {
						cursor.element.beamMode = 0;
						cursor.next();
					}//while
					cursor.rewindToTick(t - (e.tuplet.duration.numerator/e.tuplet.duration.denominator) * 1920);
				}
				cursor.prev();
			} //while
		} //if beamtotuplets
		
		//fix beaming to tuplet
		if (beamToTuplets == true && forceBeamM == false) {
			cursor.rewindToTick(mstart[mno]);
			cursor.voice = voice;
			cursor.staffIdx = staff;
			while (cursor.element && cursor.tick && cursor.tick < (mstart[mno]+mlen[mno])) {
				if (cursor.element && cursor.element.tuplet) {
					var e = cursor.element;
					var tupletTracker = new Array();
					var tupletDuration = 0;
					var tupletLength = (e.tuplet.duration.numerator/e.tuplet.duration.denominator)*1920;
					//tupletLength: absolute; tupletDuration: relative to inside tuplet
					var tupletStart = cursor.tick;
					var tupletEnd = tupletStart + tupletLength;
					var tupletN = e.tuplet.actualNotes;
					var tupletD = e.tuplet.normalNotes;
					
					while (cursor.element && cursor.tick < tupletEnd) {
						//walks through tuplet and logs all the relative note lengths
						var ed = cursor.element.duration;
						tupletTracker.push(ed.numerator/ed.denominator);
						cursor.next();
					}
					for (var i = 0; i < tupletTracker.length; i++) {
						tupletDuration = tupletDuration + tupletTracker[i]
						//adds all the note lengths together to form the relative length of the tuplet
					}
					var tupletBaseLength = tupletDuration / tupletN
					//modified beaming functions for tuplet, using tuplet divisioned tick values
					
					//var tupletBaseLengthActual = tupletDuration*1920 / tupletLength
					var tupletBaseLengthActual = tupletDuration*division;
					//actual value of one base unit in ticks
					
					cursor.rewindToTick(tupletStart);
					var e = cursor.element;
					
					if (tupletBaseLength >= 0.125) {
						for (var i = 0; i < tuplet8unbeam.length; ++i) {
							if (tupletStart == mstart[mno] + tuplet8unbeam[i]) {
								//e.beamMode = 1 might be enough, the rest was added due to another error
								if (e.type == Element.CHORD) {
									e.beamMode = 1;
								} else {
									e.beamMode = 0;
									while (cursor.element.type != Element.CHORD && cursor.tick < tupletEnd) {
										cursor.next();
										cursor.element.beamMode = 0;
									}
								}
							}
						}
					}
					if (tupletBaseLength == 0.0625) {
						for (var i = 0; i < tuplet16unbeam.length; ++i) {
							if (tupletStart == mstart[mno] + tuplet16unbeam[i]) {
								if (e.type == Element.CHORD) {
									e.beamMode = 1;
								} else {
									e.beamMode = 0;
									while (cursor.element.type != Element.CHORD && cursor.tick < tupletEnd) {
										cursor.next();
										cursor.element.beamMode = 0;
									}
								}
							}
						}
					}
					if (tupletBaseLength <= 0.03125) {
						for (var i = 0; i < tuplet32unbeam.length; ++i) {
							if (tupletStart == mstart[mno] + tuplet32unbeam[i]) {
								if (e.type == Element.CHORD) {
									e.beamMode = 1;
								} else {
									e.beamMode = 0;
									while (cursor.element.type != Element.CHORD && cursor.tick < tupletEnd) {
										cursor.next();
										cursor.element.beamMode = 0;
									}
								}
							}
						}
					}
					cursor.rewindToTick(tupletStart+tupletLength)
					cursor.prev();
				}
				cursor.next();
			}
		}
		
		//fix beaming from tuplet
		if (beamFromTuplets == true && forceBeamM == false) {
			cursor.rewindToTick(mstart[mno]+mlen[mno]);
			cursor.voice = voice;
			cursor.staffIdx = staff;
			cursor.prev();
			while (cursor.element && cursor.tick && cursor.tick >= mstart[mno]) {
				if (cursor.element && cursor.element.tuplet) {
					cursor.next();
					var tupletEnd = cursor.tick
					var e = cursor.element;
					cursor.prev();
					var tupletLength = (cursor.element.tuplet.duration.numerator/cursor.element.tuplet.duration.denominator)*1920;
					//tupletLength: absolute; tupletDuration: relative to inside tuplet
					var tupletTracker = new Array();
					var tupletDuration = 0;
					var tupletStart = tupletEnd - tupletLength;
					var tupletN = cursor.element.tuplet.actualNotes;
					var tupletD = cursor.element.tuplet.normalNotes;
					
					cursor.rewindToTick(tupletStart);
					
					while (cursor.element && cursor.tick < tupletEnd) {
						//walks through tuplet and logs all the relative note lengths
						var ed = cursor.element.duration;
						tupletTracker.push(ed.numerator/ed.denominator);
						cursor.next();
					}
					for (var i = 0; i < tupletTracker.length; i++) {
						tupletDuration = tupletDuration + tupletTracker[i]
						//adds all the note lengths together to form the relative length of the tuplet
					}
					var tupletBaseLength = tupletDuration / tupletN
					//modified beaming functions for tuplet, using tuplet divisioned tick values
					
					//var tupletBaseLengthActual = tupletDuration*1920 / tupletLength
					var tupletBaseLengthActual = tupletDuration*division;
					//actual value of one base unit in ticks
					
					cursor.rewindToTick(tupletEnd);
					cursor.prev();
					
					if (tupletBaseLength >= 0.125) {
						for (var i = 0; i < tuplet8unbeam.length; ++i) {
							if (tupletEnd == mstart[mno] + tuplet8unbeam[i] + tuplet8unbeam[1]) {
								console.log("AAAAAAAAAAAAAAAAAAAAAAAAAAA")
								//tuplet8unbeam[1] not strictly needed
								if (e.type == Element.CHORD) {
									e.beamMode = 1;
								} else {
									e.beamMode = 0;
								}
								while (cursor.element.type != Element.CHORD && cursor.tick >= tupletStart) {
									cursor.element.beamMode = 0;
									cursor.prev();
								}
							}
						}
					}
					if (tupletBaseLength == 0.0625) {
						for (var i = 0; i < tuplet16unbeam.length; ++i) {
							if (tupletEnd == mstart[mno] + tuplet16unbeam[i] + tuplet16unbeam[1]) {
								console.log("AAAAAAAAAAAAAAAAAAAAAAAAAAA")
								if (e.type == Element.CHORD) {
									e.beamMode = 1;
								} else {
									e.beamMode = 0;
								}
								while (cursor.element.type != Element.CHORD && cursor.tick >= tupletStart) {
									cursor.element.beamMode = 0;
									cursor.prev();
								}
							}
						}
					}
					if (tupletBaseLength <= 0.03125) {
						for (var i = 0; i < tuplet32unbeam.length; ++i) {
							if (tupletEnd == mstart[mno] + tuplet32unbeam[i] + tuplet32unbeam[1]) {
								if (e.type == Element.CHORD) {
									e.beamMode = 1;
								} else {
									e.beamMode = 0;
								}
								while (cursor.element.type != Element.CHORD && cursor.tick < tupletStart) {
									cursor.element.beamMode = 0;
									cursor.prev();
								}
							}
						}
					}
					cursor.rewindToTick(tupletStart)
				}
				cursor.prev();
			}
		}
	}
	
    function eighth(startTick, number, mstart, mlen, maTsN, maTsD, mno, staff, voice, forceBeamG, forceBeamM) {
		console.log("running eighth at " + startTick)
		var curs = curScore.newCursor();     
		curs.rewindToTick(startTick);
		curs.voice = voice;
		curs.staffIdx = staff;
		var notes = new Array();
		var actBeam8 = true;
		if (curs.element && curs.element.type == Element.CHORD) {
			curs.element.beamMode = 1;
			}
		//start a new beam at start of function, maybe necessary for 16th and 32nd too in another form 
				   
		for (var i = 0; i < number; ++i) {
			curs.rewindToTick(startTick + i*240)
			curs.voice = voice;
			curs.staffIdx = staff;
			var e = curs.element;
			if (e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.25) {
				notes.push(i);
				}//if
		}//for
		curs.rewindToTick(startTick);
		while (curs.element && curs.tick && curs.tick < mstart[mno] + mlen[mno]) {
			var e = curs.element;
			if (forceBeamG == false && e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.125) {
				actBeam8 = false;
				}//if
			curs.next();
		}
		//console.log("8ths will be beamed: " + actBeam8)
		if (actBeam8 && notes.length > 1) {
			notes.sort()
			console.log(notes)
			curs.rewindToTick(startTick);
			curs.voice = voice;
			curs.staffIdx = staff;
			for (var i = 0; i < number; ++i) {
				curs.rewindToTick(startTick + i*240)
				curs.voice = voice;
				curs.staffIdx = staff;
				var e = curs.element;
				if (e && ((e.type == Element.REST) || (forceBeamM && e.type == Element.CHORD)) && e.duration.numerator / e.duration.denominator >= 0.125
				//duration stops beaming of 16th notes
				&& i > notes[0] && i < notes[notes.length-1]
				//checks that the rest lies between two notes in the function
				//&& e.beamMode != 2
				//function will only change previously unaltered beams
				) {
					e.beamMode = 5; //used to be 2, but 5 should look the same in all cases
				}//if
			}//for
					
			//overrides default note beaming a bit
			//maybe include in regular beaming rules by allowing notes < 0.25 to be beaed there
			for (var i = 0; i < number; ++i) {
				curs.rewindToTick(startTick + i*240)
				curs.voice = voice;
				curs.staffIdx = staff;
				var e = curs.element;
				curs.rewindToTick(startTick + (i+1)*240);
				if (curs.element && curs.element.duration.numerator / curs.element.duration.denominator <= 0.125
				//if theres a note
				&& i+1 < number
				//within the function
				&& e && e.type == Element.REST && e.beamMode != 0) {
				//and the preceding rest is beamed over
					curs.element.beamMode = 2;
					//beam the note
				}//if
			}//for
				
			//removes mistaken beamed-over rests at the end of the function
			curs.rewindToTick(startTick + number*240)
			curs.prev();
			while (curs.element && curs.element.type == Element.REST && curs.tick >= startTick) {
				curs.element.beamMode = 0
				curs.prev();
			}
		}//actbeam8 noteslength
	} //eighth
            
    function sixteenth(startTick, number, splitBeam, divNotes, splitBeamOverride, mstart, mlen, maTsN, maTsD, mno, staff, voice, beam16) {
      // set beam to 8th 16th on regular beats in 8th timesigs
      // handled through array splitBeam
            console.log("running sixteenth at " + startTick)
            var curs = curScore.newCursor();
            curs.rewindToTick(startTick);
            curs.voice = voice;
            curs.staffIdx = staff;
            var notes = new Array();
            var actBeam16 = true;
            //curs.element.beamMode = 1;            
            for (var i = 0; i < number; ++i) {
                  curs.rewindToTick(startTick + i*120)
                  curs.voice = voice;
                  curs.staffIdx = staff;
                  var e = curs.element;
                  if (e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.25) {
                        notes.push(i)
                        }//if
                  if (beam16 == false && e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.0625) {
                        actBeam16 = false;
                        //console.log("beam8 is " + beam8)
                        }//if
                  }//for
            if (actBeam16 && notes.length > 1) {
                  notes.sort()
                  console.log(notes)
                  curs.rewindToTick(startTick);
                  curs.voice = voice;
                  curs.staffIdx = staff;
                  for (var i = 0; i < number; ++i) {
                        curs.rewindToTick(startTick + i*120)
                        curs.voice = voice;
                        curs.staffIdx = staff;
                        var e = curs.element;
                        if (e && e.type == Element.REST && e.duration.numerator / e.duration.denominator >= 0.0625
                        //stops beaming of 32nd notes
                        && i > notes[0] && i < notes[notes.length-1]) {
                            e.beamMode = 2;
                        }//if e
                        }//for
                                                            
                  if (splitBeam != []) {
                  //splits notes and rests
                  //need only rests version for /4 timesigs
                        //console.log("in splitbeam")
                        for (var i = 0; i < splitBeam.length; ++i) {
                              console.log(splitBeam[i])
                              curs.rewindToTick(startTick + splitBeam[i]*120);
                              curs.voice = voice;
                              curs.staffIdx = staff;
                              var e = curs.element;
                              if (e && e.type == Element.REST &&
                              splitBeam[i] > notes[0] && splitBeam[i] <= notes[notes.length-1] &&
                              e.duration.numerator / e.duration.denominator >= 0.0625) {
                              // <= so it can still apply to a note if its the last one and exactly on the beat
                                    e.beamMode = 5;
                                    console.log("beamed")
                                    } //if element                                  
                              if (e && e.type == Element.CHORD &&
                              splitBeam[i] > notes[0] && splitBeam[i] <= notes[notes.length-1] &&
                              e.duration.numerator / e.duration.denominator >= 0.0625) {
                                    if (divNotes == true) {                              
                                          e.beamMode = 5;
                                          //console.log("beamed")
                                          } else {
                                          curs.prev();
                                          //copypasted from above, e = curs.element
                                          if (curs.element && curs.element.type == Element.REST &&
                                          splitBeam[i] > notes[0] && splitBeam[i] <= notes[notes.length-1] &&
                                          e.duration.numerator / e.duration.denominator >= 0.0625
                                          && curs.tick >= startTick + (i-1)*120) {
                                                curs.element.beamMode = 5;
                                                //console.log("beamed")
                                                }//if curs
                                          } //else divnotes                                          
                                    } //if element
                              } //for
                        } //if splitbeam
                  
                  
                  if (splitBeamOverride != []) {
                  //rebeams splitbeams when needed (usually X/2 or X/1 timesigs)
                  //need only rests version for /4 timesigs
                        //console.log("in splitbeamoverride")
                        for (var i = 0; i < splitBeamOverride.length; ++i) {
                              //console.log(splitBeamOverride[i])
                              curs.rewindToTick(startTick + splitBeamOverride[i]*120);
                              curs.voice = voice;
                              curs.staffIdx = staff;
                              var e = curs.element;
                              if (e && (e.type == Element.REST || e.type == Element.CHORD) &&
                              splitBeamOverride[i] > notes[0] && splitBeamOverride[i] <= notes[notes.length-1] &&
                              e.duration.numerator / e.duration.denominator >= 0.0625) {
                              // <= so it can still apply to a note if its the last one and exactly on the beat
                                    e.beamMode = 5;
                                    //console.log("beamed")
                                    } //if element                                  
                              } //for
                        } //if splitbeamoverride
                  
                  //remove wrong beams      
                  for (var i = 0; i < number; ++i) {
                        curs.rewindToTick(startTick + i*120);                        
                        curs.voice = voice;
                        curs.staffIdx = staff;
                        var e = curs.element;
                        if ((e && e.type == Element.REST && e.duration.numerator / e.duration.denominator >= 0.125 && i < notes[0]) ||
                        (e && e.type == Element.REST && e.duration.numerator / e.duration.denominator >= 0.125 && i > notes[notes.length-1])) {
                              e.beamMode = 0;
                              }
                        //checks if rest is last one in function, as if its longer than
                        //the base unit some of it will be counted as a note
                        curs.next();
                        if (e && e.type == Element.REST && curs.tick >= startTick + number*120) {
                              e.beamMode = 0;
                              }
                        }//for
                  
                  }//noteslength            
            
            } //sixteenth
      
    function thirtytwond(startTick, number, splitBeam1, splitBeam2, divNotes1, divNotes2, divNotesPlus, mstart, mlen, maTsN, maTsD, mno, staff, voice, beam32) {
      //in /8 and /4: 4 split into groups of 4 using 8/16
      // in /16: like 16ths except 16/32 where 8/16 was
      // handled through array splitBeam
      //should only be used alone in /8 or /16
            console.log("running thirtytwond at " + startTick)
            var curs = curScore.newCursor();
            curs.rewindToTick(startTick);
            curs.voice = voice;
            curs.staffIdx = staff;
            var notes = new Array();
            var actBeam32 = true;
            //curs.element.beamMode = 1;            
            for (var i = 0; i < number; ++i) {
                  curs.rewindToTick(startTick + i*60)
                  curs.voice = voice;
                  curs.staffIdx = staff;
                  var e = curs.element;
                  if (e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.25) {
                        notes.push(i)
                        }//if
                  if (beam32 == false && e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.03125) {
                        actBeam32 = false;
                        //console.log("beam8 is " + beam8)
                        }//if
                  }//for
            if (actBeam32 && notes.length > 1) {
                  notes.sort()
                  console.log(notes)
                  curs.rewindToTick(startTick);
                  curs.voice = voice;
                  curs.staffIdx = staff;
                  for (var i = 0; i < number; ++i) {
                        curs.rewindToTick(startTick + i*60)
                        curs.voice = voice;
                        curs.staffIdx = staff;
                        var e = curs.element;
                        if (e && e.type == Element.REST //&& e.duration.numerator / e.duration.denominator >= 0.03125
                        //would stop beaming of 64th notes 
                        //is not needed while 32nd is smallest beam function                       
                        && i > notes[0] && i < notes[notes.length-1]) {
                              e.beamMode = 2;
                              console.log("scude 32: " + (i + 1))
                              }//if
                        }//for
                                                            
                  if (splitBeam1 != []) {
                  //smaller subdivision for 32nd notes, beams a point as 16/32
                        //console.log("in splitbeam1")
                        for (var i = 0; i < splitBeam1.length; ++i) {
                              //console.log(splitBeam1[i])
                              curs.rewindToTick(startTick + splitBeam1[i]*60);
                              curs.voice = voice;
                              curs.staffIdx = staff;
                              var e = curs.element;
                              if (e && e.type == Element.REST && 
                              splitBeam1[i] > notes[0] && splitBeam1[i] <= notes[notes.length-1] &&
                              e.duration.numerator / e.duration.denominator <= 0.0625) {
                                    e.beamMode = 6;
                                    console.log("beamed 32nd sub")
                                    } //if element
                              if (e && e.type == Element.CHORD && 
                              splitBeam1[i] > notes[0] && splitBeam1[i] <= notes[notes.length-1] &&
                              e.duration.numerator / e.duration.denominator <= 0.0625) { 
                                    if (divNotes1 == true) {                              
                                          e.beamMode = 6;
                                          console.log("beamed 32nd sub")
                                          } else {
                                          curs.prev();                                          
                                          if (curs.element && curs.element.type == Element.REST &&
                                          splitBeam1[i] > notes[0] && splitBeam1[i] <= notes[notes.length-1] && 
                                          e.duration.numerator / e.duration.denominator <= 0.0625) {
                                                curs.element.beamMode = 6;
                                                console.log("beamed 32nd sub")
                                                } //if curs
                                          } //else divnotes1
                                    } //if element      
                              } //for
                        } //if splitbeam1
                  
                  if (splitBeam2 != []) {
                  //larger subdivision for 32nd notes, beams a point as 8/16
                        console.log("in splitbeam2")
                        for (var i = 0; i < splitBeam2.length; ++i) {
                              //console.log(splitBeam2[i])
                              curs.rewindToTick(startTick + splitBeam2[i]*60);
                              curs.voice = voice;
                              curs.staffIdx = staff;
                              var e = curs.element;
                              if (e && e.type == Element.REST && 
                              splitBeam2[i] > notes[0] && splitBeam2[i] <= notes[notes.length-1] && 
                              e.duration.numerator / e.duration.denominator <= 0.0625) {
                                    e.beamMode = 5;
                                    console.log("beamed32 16th sub")
                                    } //if element
                              if (e && e.type == Element.CHORD && 
                              splitBeam2[i] > notes[0] && splitBeam2[i] <= notes[notes.length-1] &&
                              e.duration.numerator / e.duration.denominator <= 0.0625) {
                                    if (divNotes2 == true) {
                                          e.beamMode = 5; //6 was here before??
                                          console.log("beamed 32nd sub")
                                          if (divNotesPlus == false && e.duration.numerator / e.duration.denominator >= 0.0625) {
                                          //reverts beam subdivision to default if the note is larger than 32nd
                                                curs.prev();
                                                if (curs.element && curs.element.type == Element.CHORD &&
                                                //splitBeam2[i] > notes[0] && splitBeam2[i] <= notes[notes.length-1] && clarified in a previous if??
                                                //curs.element.tick + (curs.element.duration.numerator / curs.element.duration.denominator)*1920 <= e.tick &&
                                                curs.element.duration.numerator / curs.element.duration.denominator >= 0.0625) {
                                                      e.beamMode = 0;
                                                      console.log("unbeamed 32nd sub")
                                                      }//if element
                                                }//if divnotesplus
                                                
                                          } else {
                                          curs.prev();                                          
                                          if (curs.element && curs.element.type == Element.REST &&
                                          splitBeam2[i] > notes[0] && splitBeam2[i] <= notes[notes.length-1] &&
                                          e.duration.numerator / e.duration.denominator <= 0.125) {
                                                curs.element.beamMode = 5; //6 was here before??
                                                console.log("beamed 32nd sub")
                                                } //if curs
                                          } //else divnotes2
                                    } //if element
                              if (e && e.tick &&
                              (e.tick + (e.duration.numerator / e.duration.denominator)*1920) > (startTick + splitBeam2[i]*60)) {
                                    console.log("success, apparently")
                                    e.beamMode = 5;
                                    }//if
                              } //for i
                        } //if splitbeam2
                        
                  for (var i = 0; i < number; ++i) {
                        curs.rewindToTick(startTick + i*60);                        
                        curs.voice = voice;
                        curs.staffIdx = staff;
                        var e = curs.element;
                        
                        if (e && e.type == Element.REST && e.duration.numerator / e.duration.denominator >= 0.0625 
                        && (i < notes[0] || i > notes[notes.length-1])) {
                              e.beamMode = 0;
                              }
                        //checks if rest is last one in function, as if its longer than
                        //the base unit some of it will be counted as a note
                        curs.next();
                        if (e && e.type == Element.REST && curs.tick >= startTick + number*60) {
                              e.beamMode = 0;
                              }
                        }//for
                  
                  }//noteslength
            }//thirtytwond
      
	function tupletEighth(tupletStart, tupletEnd, number, btick, tupletN, tupletBaseLength, tupletBaseLengthActual, tupletForceBeamG, voice, staff) {
		console.log("running tuplet eighth at " + tupletStart)
		var curs = curScore.newCursor();     
		curs.rewindToTick(tupletStart);
		curs.voice = voice;
		curs.staffIdx = staff;
		var notes = new Array();
		var actBeam8 = true;
				   
		for (var i = 0; i < number; ++i) {
			curs.rewindToTick(tupletStart + i*btick)
			curs.voice = voice;
			curs.staffIdx = staff;
			var e = curs.element;
			if (e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.25) {
				notes.push(i);
				}//if
			if (tupletForceBeamG == false && e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.125) {
				actBeam8 = false;
				}//if
		}//for
		//console.log("8ths will be beamed: " + actBeam8)
		if (actBeam8 && notes.length > 1) {
			notes.sort()
			console.log(notes)
			curs.rewindToTick(tupletStart);
			curs.voice = voice;
			curs.staffIdx = staff;
			for (var i = 0; i < number; ++i) {
				curs.rewindToTick(tupletStart + i*btick)
				curs.voice = voice;
				curs.staffIdx = staff;
				var e = curs.element;
				if (e && e.type == Element.REST && e.duration.numerator / e.duration.denominator >= 0.125
				//duration stops beaming of 16th notes
				&& i > notes[0] && i < notes[notes.length-1]
				//checks that the rest lies between two notes in the function
				//&& e.beamMode != 2
				//function will only change previously unaltered beams
				) {
					e.beamMode = 5; //used to be 2, but 5 should look the same in all cases
				}//if
			}//for
		}//actbeam8 noteslength
	}//tuplet8th
	  
	function tupletSixteenth(tupletStart, tupletEnd, number, btick, tupletN, tupletBaseLength, tupletBaseLengthActual,
				tupletSplitBeam, tupletDivNotes, tupletSplitBeamOverride, tupletBeam16,
				beamToTuplets, beamFromTuplets, voice, staff) {
		console.log("running tuplet sixteenth at " + tupletStart)
        var curs = curScore.newCursor();
        curs.rewindToTick(tupletStart);
        curs.voice = voice;
        curs.staffIdx = staff;
        var notes = new Array();
        var actBeam16 = true;
        //curs.element.beamMode = 1;            
        for (var i = 0; i < number; ++i) {
            curs.rewindToTick(tupletStart + i*btick)
            curs.voice = voice;
            curs.staffIdx = staff;
            var e = curs.element;
            if (e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.25) {
				//null needed as failsafe against empty voices
                notes.push(i)
            }//if
            if (tupletBeam16 == false && e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.0625) {
                actBeam16 = false;
                //console.log("beam8 is " + beam8)
            }//if
        }//for
        if (actBeam16 && notes.length > 1) {
            notes.sort()
			console.log(notes)
			curs.rewindToTick(tupletStart);
			curs.voice = voice;
			curs.staffIdx = staff;
			for (var i = 0; i < number; ++i) {
				curs.rewindToTick(tupletStart + i*btick)
				curs.voice = voice;
				curs.staffIdx = staff;
				var e = curs.element;
				if (e && e.type == Element.REST && e.duration.numerator / e.duration.denominator >= 0.0625 //stops beaming of 32nd notes
				&& i > notes[0] && i < notes[notes.length-1]) {
					e.beamMode = 2;
					//console.log("scues16")
				}//if e
			}//for
                                                            
			if (tupletSplitBeam != []) {
			//splits notes and rests
			//need only rests version for /4 timesigs
				//console.log("in splitbeam")
				for (var i = 0; i < tupletSplitBeam.length; ++i) {
					console.log(tupletSplitBeam[i])
					curs.rewindToTick(tupletStart + tupletSplitBeam[i]*btick);
					curs.voice = voice;
					curs.staffIdx = staff;
					var e = curs.element;
					if (e && e.type == Element.REST &&
					tupletSplitBeam[i] > notes[0] && tupletSplitBeam[i] <= notes[notes.length-1] &&
					e.duration.numerator / e.duration.denominator >= 0.0625) {
					 // <= so it can still apply to a note if its the last one and exactly on the beat
						e.beamMode = 5;
						console.log("beamed")
					} //if element                                  
					if (e && e.type == Element.CHORD &&
					tupletSplitBeam[i] > notes[0] && tupletSplitBeam[i] <= notes[notes.length-1] &&
					e.duration.numerator / e.duration.denominator >= 0.0625) {
						if (tupletDivNotes == true) {                              
							e.beamMode = 5;
							//console.log("beamed")
						} else {
							curs.prev();
							//copypasted from above, e = curs.element
							if (curs.element && curs.element.type == Element.REST &&
							tupletSplitBeam[i] > notes[0] && tupletSplitBeam[i] <= notes[notes.length-1] &&
							e.duration.numerator / e.duration.denominator >= 0.0625
							&& curs.tick >= tupletStart + (i-1)*btick) {
								curs.element.beamMode = 5;
								//console.log("beamed")
							}//if curs
						} //else divnotes                                          
					} //if element
				} //for
			} //if splitbeam
                  
			if (tupletSplitBeamOverride != []) {
                //rebeams splitbeams when needed (usually X/2 or X/1 timesigs)
                //need only rests version for /4 timesigs
				//console.log("in splitbeamoverride")
				for (var i = 0; i < tupletSplitBeamOverride.length; ++i) {
					//console.log(splitBeamOverride[i])
					curs.rewindToTick(tupletStart + tupletSplitBeamOverride[i]*btick);
					curs.voice = voice;
					curs.staffIdx = staff;
					var e = curs.element;
					if (e && (e.type == Element.REST || e.type == Element.CHORD) &&
					tupletSplitBeamOverride[i] > notes[0] && tupletSplitBeamOverride[i] <= notes[notes.length-1] &&
					e.duration.numerator / e.duration.denominator >= 0.0625) {
					// <= so it can still apply to a note if its the last one and exactly on the beat
						e.beamMode = 5;
						//console.log("beamed")
					} //if element                                  
				} //for
			} //if splitbeamoverride
                  
            //remove wrong beams      
            for (var i = 0; i < number; ++i) {
                curs.rewindToTick(tupletSplitBeam + i*btick);                        
                curs.voice = voice;
				curs.staffIdx = staff;
				var e = curs.element;
				if (e && e.type == Element.REST && e.duration.numerator / e.duration.denominator >= 0.125 &&
				((i < notes[0] && beamToTuplets == false) || (i > notes[notes.length-1] && beamFromTuplets == false))) {
					e.beamMode = 0;
				}
				//checks if rest is last one in function, as if its longer than
				//the base unit some of it will be counted as a note
				curs.next();
				if (e && e.type == Element.REST && curs.tick >= tupletStart + number*btick) {
					e.beamMode = 0;
				}
			}//for
                  
        }//noteslength 
	}//tuplet 16th
	  
	function tupletThirtytwond(tupletStart, tupletEnd, number, btick, tupletN, tupletBaseLength, tupletBaseLengthActual,
				tupletSplitBeam1, tupletSplitBeam2, tupletDivNotes1, tupletDivNotes2, tupletDivNotesPlus, tupletBeam32,
				beamToTuplets, beamFromTuplets, voice, staff) {
			
			console.log("running tuplet thirtytwond at " + tupletStart);
            var curs = curScore.newCursor();
            curs.rewindToTick(tupletStart);
            curs.voice = voice;
            curs.staffIdx = staff;
            var notes = new Array();
            var actBeam32 = true;
            //curs.element.beamMode = 1;            
            for (var i = 0; i < number; ++i) {
                  curs.rewindToTick(tupletStart + i*btick)
                  curs.voice = voice;
                  curs.staffIdx = staff;
                  var e = curs.element;
                  if (e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.25) {
                  //null needed as failsafe against voices
                        notes.push(i)
                        }//if
                  if (tupletBeam32 == false && e && e.type == Element.CHORD && e.duration.numerator / e.duration.denominator < 0.03125) {
                        actBeam32 = false;
                        //console.log("beam8 is " + beam8)
                        }//if
                  }//for
            if (actBeam32 && notes.length > 1) {
                notes.sort()
                console.log(notes)
                curs.rewindToTick(tupletStart);
                curs.voice = voice;
                curs.staffIdx = staff;
                for (var i = 0; i < number; ++i) {
                        curs.rewindToTick(tupletStart + i*btick)
                        curs.voice = voice;
                        curs.staffIdx = staff;
                        var e = curs.element;
                        if (e && e.type == Element.REST //&& e.duration.numerator / e.duration.denominator >= 0.03125
                        //would stop beaming of 64th notes 
                        //is not needed while 32nd is smallest beam function                       
                        && i > notes[0] && i < notes[notes.length-1]) {
                              e.beamMode = 2;
                              console.log("scude 32: " + (i + 1))
                              }//if
                        }//for
                                                            
                  if (tupletSplitBeam1 != []) {
                  //smaller subdivision for 32nd notes, beams a point as 16/32
                        //console.log("in splitbeam1")
                        for (var i = 0; i < tupletSplitBeam1.length; ++i) {
                              //console.log(tupletSplitBeam1[i])
                              curs.rewindToTick(tupletStart + tupletSplitBeam1[i]*btick);
                              curs.voice = voice;
                              curs.staffIdx = staff;
                              var e = curs.element;
                              if (e && e.type == Element.REST && 
                              tupletSplitBeam1[i] > notes[0] && tupletSplitBeam1[i] <= notes[notes.length-1] &&
                              e.duration.numerator / e.duration.denominator <= 0.0625) {
                                    e.beamMode = 6;
                                    console.log("beamed 32nd sub")
                                    } //if element
                              if (e && e.type == Element.CHORD && 
                              tupletSplitBeam1[i] > notes[0] && tupletSplitBeam1[i] <= notes[notes.length-1] &&
                              e.duration.numerator / e.duration.denominator <= 0.0625) { 
                                    if (tupletDivNotes1 == true) {                              
                                          e.beamMode = 6;
                                          console.log("beamed 32nd sub")
                                          } else {
                                          curs.prev();                                          
                                          if (curs.element && curs.element.type == Element.REST &&
                                          tupletSplitBeam1[i] > notes[0] && tupletSplitBeam1[i] <= notes[notes.length-1] && 
                                          e.duration.numerator / e.duration.denominator <= 0.0625) {
                                                curs.element.beamMode = 6;
                                                console.log("beamed 32nd sub")
                                                } //if curs
                                          } //else divnotes1
                                    } //if element      
                              } //for
                        } //if splitbeam1
                  
                  if (tupletSplitBeam2 != []) {
                  //larger subdivision for 32nd notes, beams a point as 8/16
                        console.log("in splitbeam2")
                        for (var i = 0; i < tupletSplitBeam2.length; ++i) {
                              //console.log(tupletSplitBeam2[i])
                              curs.rewindToTick(tupletStart + tupletSplitBeam2[i]*btick);
                              curs.voice = voice;
                              curs.staffIdx = staff;
                              var e = curs.element;
                              if (e && e.type == Element.REST && 
                              tupletSplitBeam2[i] > notes[0] && tupletSplitBeam2[i] <= notes[notes.length-1] && 
                              e.duration.numerator / e.duration.denominator <= 0.0625) {
                                    e.beamMode = 5;
                                    console.log("beamed32 16th sub")
                                    } //if element
                              if (e && e.type == Element.CHORD && 
                              tupletSplitBeam2[i] > notes[0] && tupletSplitBeam2[i] <= notes[notes.length-1] &&
                              e.duration.numerator / e.duration.denominator <= 0.0625) {
                                    if (tupletDivNotes2 == true) {
                                          e.beamMode = 5; //6 was here before??
                                          console.log("beamed 32nd sub")
                                          if (tupletDivNotesPlus == false && e.duration.numerator / e.duration.denominator >= 0.0625) {
                                          //reverts beam subdivision to default if the note is larger than 32nd
                                                curs.prev();
                                                if (curs.element && curs.element.type == Element.CHORD &&
                                                //splitBeam2[i] > notes[0] && splitBeam2[i] <= notes[notes.length-1] && clarified in a previous if??
                                                //curs.element.tick + (curs.element.duration.numerator / curs.element.duration.denominator)*1920 <= e.tick &&
                                                curs.element.duration.numerator / curs.element.duration.denominator >= 0.0625) {
                                                      e.beamMode = 0;
                                                      console.log("unbeamed 32nd sub")
                                                      }//if element
                                                }//if divnotesplus
                                                /*if (curs.element &&curs.element.tick &&
                                                (curs.element.tick + (curs.element.duration.numerator / curs.element.duration.denominator)*1920) > (startTick + splitBeam2[i]*60)) {
                                                      console.log("success, apparently")
                                                      curs.element.beamMode = 5;
                                                      }//if*/
                                          } else {
                                          curs.prev();                                          
                                          if (curs.element && curs.element.type == Element.REST &&
                                          tupletSplitBeam2[i] > notes[0] && tupletSplitBeam2[i] <= notes[notes.length-1] &&
                                          e.duration.numerator / e.duration.denominator <= 0.125) {
                                                curs.element.beamMode = 5; //6 was here before??
                                                console.log("beamed 32nd sub")
                                                } //if curs
                                          } //else divnotes2
                                    } //if element
                              if (e && e.tick &&
                              (e.tick + (e.duration.numerator / e.duration.denominator) * (btick*32)) > (tupletStart + tupletSplitBeam2[i]*btick)) {
                                    console.log("success, apparently")
                                    e.beamMode = 5;
                                    }//if
                              } //for i
                        } //if splitbeam2
                        
                  for (var i = 0; i < number; ++i) {
                        curs.rewindToTick(tupletStart + i*btick);                        
                        curs.voice = voice;
                        curs.staffIdx = staff;
                        var e = curs.element;
                        
						//conditional, depends on beam to/from tuplet
                        if (e && e.type == Element.REST && e.duration.numerator / e.duration.denominator >= 0.0625 
                        && ((i < notes[0] && beamToTuplets == false) || (i > notes[notes.length-1] && beamFromTuplets == false))) {
                              e.beamMode = 0;
                              }
                        //checks if rest is last one in function, as if its longer than
                        //the base unit some of it will be counted as a note
                        curs.next();
                        /*if (e && e.type == Element.REST && curs.tick >= tupletStart + number*btick) {
                              e.beamMode = 0;
                              } //cant happen in tuplets, note would have to extend outside of it*/
                        }//for
            }//noteslength
	}
	
	function applyCorrections(m, mstart, mlen, maTsN, maTsD, mnTsN, mnTsD, mno, staff, voice, cursor) {
		
		//remove rogue beams from previously shortened measure================================================================================
		
		cursor.rewindToTick(mstart[mno] + mlen[mno]);
		cursor.voice = voice;
		cursor.staffIdx = staff;
		var addedRest = false;
		if (cursor.element) {
			cursor.element.beamMode = 0;
		}
		//this should make the function work for 2nd+ voices, but it won't add the rest!
		/*if (! cursor.element) {
			cursor.rewindToTick(mstart[mno] + mlen[mno]);
			cursor.voice = voice;
			cursor.staffIdx = staff;
			cursor.addRest(true);
			addedRest = true;
		}*/
		cursor.prev();
		while (cursor.element && cursor.element.type == Element.REST && cursor.tick >= mstart[mno]) {
			cursor.element.beamMode = 0;
			cursor.prev();
		}//while
		/*if (addedRest == true) {
			cursor.rewindToTick(mstart[mno] + mlen[mno])
			cursor.voice = voice;
			cursor.staffIdx = staff;
			removeElement(cursor.element)
		}*/
		//====================================================================================================================================
		
		//remove rogue beams from front of measure (rarely needed)============================================================================
		cursor.rewindToTick(mstart[mno]);
		cursor.voice = voice;
		cursor.staffIdx = staff;
		while (cursor.element && cursor.element.type == Element.REST && cursor.tick < mstart[mno] + mlen[mno]) {
			cursor.element.beamMode = 0;
			cursor.next();
		}//while
		//====================================================================================================================================
		
		//remove beams to and from >= 4th notes===============================================================================================
		cursor.rewindToTick(mstart[mno]);
		cursor.voice = voice;
		cursor.staffIdx = staff;
		while (cursor.element && cursor.tick < (mstart[mno] + mlen[mno])) {
			//runs through every note in measure
			//have to use mstart + mlen because not all selections will have more than one mno
			
			if (cursor.element.type == Element.CHORD && cursor.element.duration.numerator / cursor.element.duration.denominator >= 0.25) {
				//if a note is 4th or longer, undo preceding rests
				
				cursor.element.beamMode = 0;
				var temptick = cursor.tick
				//console.log("UNBEAMED")
				
				cursor.prev();
				while (cursor.element && cursor.element.type == Element.REST && cursor.tick >= mstart[mno]) {
					cursor.element.beamMode = 0;
					cursor.prev();
				}//while
				
				//... and undo succeeding rests
				cursor.rewindToTick(temptick)
				
				cursor.next();
				while (cursor.element && cursor.element.type == Element.REST && cursor.tick < (mstart[mno] + mlen[mno])) {
					cursor.element.beamMode = 0;
					cursor.next();
				}//while
				
				cursor.rewindToTick(temptick)
			}//if
			cursor.next();
		}//while
		//====================================================================================================================================
	}
	
	//not working yet
    function posBeamRests(m, mstart, mlen, maTsN, maTsD, mnTsN, mnTsD, mno, staff, voice) {
        var curso = curScore.newCursor();
        curso.voice = voice;
        curso.staffIdx = staff;
        curso.rewindToTick(mstart[mno]);
		console.log("positioning beams..")
        while (curso.element && curso.tick < (mstart[mno]+mlen[mno])) {
            var e = curso.element;
            if (e.type == Element.REST && e.beam == true) {
                console.log(e.beamPos + " BWmpos")
            }//if
            //else {console.log("badbeam")}
            curso.next();
        }//while
    }//posBeamRests
			
	onRun: {

		//check that the MuseScore version is correct
        if (mscoreMajorVersion < 3 || mscoreMinorVersion < 6) {
            return;
        }
        var c = curScore.newCursor();                        
        var mstart = new Array(); //start tick of each measure
        var mlen = new Array(); //length of each measure in ticks
        var maTsN = new Array(); //only use to compare ts to previous one, or customising to each time change will be impossible
        var maTsD = new Array();
        var mnTsN = new Array();
        var mnTsD = new Array();
        var mno = 0; //measure number - 1                                  
        var lm; //the last measure (start tick), not counting the appended one            
        var startStaff; //used to track selection
        var endStaff;            
        var fullScore = false;            
        var selOffset = 0; //needed to do mno when selection doesnt start at start (WIP)
            
	    c.rewind(Cursor.SELECTION_START);
        if (c.segment == null) { // no selection
            fullScore = true;
            startStaff = 0; // start with 1st staff
            endStaff = curScore.nstaves - 1; // and end with last
            lm = curScore.lastMeasure.firstSegment.tick;
        } else {
            startStaff = c.staffIdx;
            c.rewind(Cursor.SELECTION_END);
            endStaff = c.staffIdx;
            if (c.tick == 0) {
                lm = curScore.lastMeasure.firstSegment.tick;
            } else {
                lm = c.measure.firstSegment.tick;
            }//else   
        } //else
            
        if (fullScore) {
            c.rewind(Cursor.SCORE_START);
        } else {
            c.rewind(Cursor.SELECTION_START);
        }
            
        mapMeasures(mstart, mlen, maTsN, maTsD, mnTsN, mnTsD, mno, fullScore, lm);
        curScore.appendMeasures(1); //safety against weird ticks with end of score stuff, removed at the end of the onrun function
        //error message, visible to end user in the score
        var text = newElement(Element.SYSTEM_TEXT);
        text.text = "An error with the\nplugin has occured."
        text.size = 12;                           
        text.placement = Placement.ABOVE;
        c.rewindToTick(curScore.lastMeasure.firstSegment.tick);
        c.add(text);
            
		for (var staff = startStaff; staff <= endStaff; staff++) {
			console.log("In staff " + (staff+1))
			for (var voice = 0; voice < 4; voice++) {
				console.log("In voice " + (voice+1))
				mno = 0; //resetting it to 0, used by other functions to count through score
				if (fullScore) {
					  c.rewind(Cursor.SCORE_START);
				} else {
					  c.rewind(Cursor.SELECTION_START);
				}
				c.voice = voice; //goes through all different voices
				c.staffIdx = staff;
				//import these values to all functions/rewinds
				while (mno < mstart.length) {
					console.log("At measure " + (mno+1))
					applyBeamingRules(c.measure, mstart, mlen, maTsN, maTsD, mnTsN, mnTsD, mno, staff, voice);
					posBeamRests(c.measure, mstart, mlen, maTsN, maTsD, mnTsN, mnTsD, mno, staff, voice);
					mno = mno + 1;
					c.nextMeasure();
				} //while
			} //for voice
		} // for staff

		removeElement(curScore.lastMeasure);
        console.log("end");
        //Qt.quit(); test only
	} //onrun
} //MuseScore
