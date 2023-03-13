//===================================================//
//Time Signature Presets for ReBeamer Plugin
//Copyright (C) 2023 XiaoMigros
//v 1.0
//Changelog:
//===================================================//

//returns settings in one big array
//calculates beaming rules based on time signature

// CODE STRUCTURE:
//
// - 3 arrays per timesig: 8th splitpoints, 16th splitpoints & 32nd splitpoints
//   Splitpoints are where in the measure the beam is split
//   the beam is split after X 8ths/16ths/32nds/ have occured in a measure
//
// - 2 8th subdivision arrays: 16th sub8 & 32nd sub8
//   determines where to show the 8th subdivision in 16th and 32nd notes/rests
//   functions the same way as the previous splitpoints
//
// - 1 16th subdivision array: 32nd sub16
//
// - Type variables:
//   whether to change the beam for rests (1), notes (2), none (0), or both (3)
//   sS8type = sixteenth sub 8 type, etc
//
// - beamType:
//   Whether to (in general) beam rests (1), notes (2), nothing (0), or everything (3).
//   Note: beamType does not override the subbeam types

function getTimesigRules(numerator, denominator, custom) {
	
	//default settings for every time signature
	var eighthSplit			= []
	var sixteenthSplit		= []
	var thirtytwondSplit	= []
	var sixteenthSplit8		= []
	var thirtytwondSplit8	= []
	var thirtytwondSplit16	= []
	var beamType			= 3
	var sS8type				= 1
	var tS8type				= 3
	var tS16type			= 1
	//change them by redefining the value later on in the function
	
	switch (denominator) {
		case 1: {
			for (var i = 0; i <= numerator * 2; ++i) {
				eighthSplit.push(4*i)
			}
			for (var i = 0; i <= numerator * 4; ++i) {
				sixteenthSplit.push(4*i);
				thirtytwondSplit.push(8*i);
			}
			for (var i = 0; i <= numerator * 8; ++i) {
				sixteenthSplit8.push(2*i);
				thirtytwondSplit8.push(4*i);
			}
			for (var i = 0; i <= numerator * 16; ++i) {
				thirtytwondSplit16.push(2*i)
			}
			break;
		}// X/1
		
		case 2: {
			for (var i = 0; i <= numerator * 1; ++i) {
				eighthSplit.push(4*i)
			}
			for (var i = 0; i <= numerator * 2; ++i) {
				sixteenthSplit.push(4*i);
				thirtytwondSplit.push(8*i);
			}
			for (var i = 0; i <= numerator * 4; ++i) {
				sixteenthSplit8.push(2*i);
				thirtytwondSplit8.push(4*i);
			}
			for (var i = 0; i <= numerator * 8; ++i) {
				thirtytwondSplit16.push(2*i)
			}
			break;
		}// X/2
		
		case 4: {
			switch (numerator) {
				case 4: {
					eighthSplit = [0, 4, 8]
					break;
				}
				case 5: {
					eighthSplit = [0, 2, 4, 6, 10] //split 8th groups everywhere except last two beats (3+2/4 beaming)
					break;
				}
				case 6: {
					if (mnTsN.includes(4)) {
						eighthSplit = [0, 4, 8, 12] //beam like 3/2 if score contains 4/4
						break;
					}
				}
				default: {
					for (var i = 0; i <= numerator * 1; ++i) {
						eighthSplit.push(2*i)
					}
					break;
				}
			}//switch
			for (var i = 0; i <= numerator * 1; ++i) {
				sixteenthSplit.push(4*i);
				thirtytwondSplit.push(8*i);
			}
			for (var i = 0; i <= numerator * 2; ++i) {
				sixteenthSplit8.push(2*i);
				thirtytwondSplit8.push(4*i);
			}
			for (var i = 0; i <= numerator * 4; ++i) {
				thirtytwondSplit16.push(2*i)
			}
			break;
		}// X/4
		
		case 8: {
			if (numerator % 3 == 0) {
				sS8type = 3
				for (var i = 0; i <= denominator / 3; ++i) {
					eighthSplit.push(3*i);
					sixteenthSplit.push(6*i);
					thirtytwondSplit.push(12*i);
				}
				for (var i = 0; i <= denominator * 1; ++i) {
					sixteenthSplit8.push(2*i)
					thirtytwondSplit8.push(4*i)
				}
				for (var i = 0; i <= denominator * 2; ++i) {
					thirtytwondSplit16.push(2*i)
				}
			} else {
				sS8type = 1
				for (var i = 0; i <= numerator * 1; ++i) {
					eighthSplit.push(i)
					sixteenthSplit.push(2*i)
					thirtytwondSplit.push(4*i)
				}
				for (var i = 0; i <= numerator * 2; ++i) {
					sixteenthSplit8.push(i)
					thirtytwondSplit8.push(2*i)
				}
				for (var i = 0; i <= numerator * 4; ++i) {
					thirtytwondSplit16.push(i)
				}
			}
			break;
		}// X/8
		
		case 16: {
			eighthSplit.push(0)
			eighthSplit.push(numerator / 2)
			if (numerator % 3 == 0) {
				for (var i = 0; i <= denominator / 3; ++i) {
					sixteenthSplit.push(3*i);
					thirtytwondSplit.push(6*i);
				}
				for (var i = 0; i <= denominator * 1; ++i) {
					sixteenthSplit8.push(i)
					thirtytwondSplit8.push(2*i)
				}
				for (var i = 0; i <= denominator * 2; ++i) {
					thirtytwondSplit16.push(i)
				}
			} else {
				for (var i = 0; i <= numerator * 1; ++i) {
					sixteenthSplit.push(i)
					thirtytwondSplit.push(2*i)
				}
				for (var i = 0; i <= numerator * 2; ++i) {
					sixteenthSplit8.push(i)
					thirtytwondSplit8.push(2*i)
				}
				for (var i = 0; i <= numerator * 4; ++i) {
					thirtytwondSplit16.push(i)
				}
			}
			break;
		}// X/16
		
		case 32: {
			eighthSplit.push(0)
			eighthSplit.push(numerator / 4)
			sixteenthSplit.push(0)
			sixteenthSplit.push(numerator / 2)
			sixteenthSplit8.push(0)
			sixteenthSplit8.push(numerator / 2)
			thirtytwondSplit.push(0)
			thirtytwondSplit.push(numerator)
			thirtytwondSplit8.push(0)
			thirtytwondSplit8.push(numerator)
			for (var i = 0; i <= denominator * 1; ++i) {
				thirtytwondSplit16.push(i)
			}
			break;
		}// X/32
		
		case 64: {
			eighthSplit.push(0)
			eighthSplit.push(numerator / 8)
			sixteenthSplit.push(0)
			sixteenthSplit.push(numerator / 4)
			sixteenthSplit8.push(0)
			sixteenthSplit8.push(numerator / 4)
			thirtytwondSplit.push(0)
			thirtytwondSplit.push(numerator / 2)
			thirtytwondSplit8.push(0)
			thirtytwondSplit8.push(numerator / 2)
			thirtytwondSplit16.push(0)
			thirtytwondSplit16.push(numerator / 2)
			break;
		}// X/64
		
		default: {
			addError(qsTr("Unrecognised time signature at measure ") + (mno+1))
			smartQuit()
		}//error
	}//timesig switch
	
	if (custom) {
		//==================================//
		
		//paste your custom settings here
		
		//==================================//
		
		//add security values missing from custom definitions
		eighthSplit.splice(0, 0, 0)
		eighthSplit.push((numerator / denominator) * 8)
		sixteenthSplit.splice(0, 0, 0)
		sixteenthSplit.push((numerator / denominator) * 16)
		sixteenthSplit8.splice(0, 0, 0)
		sixteenthSplit8.push((numerator / denominator) * 16)
		thirtytwondSplit.splice(0, 0, 0)
		thirtytwondSplit.push((numerator / denominator) * 32)
		thirtytwondSplit8.splice(0, 0, 0)
		thirtytwondSplit8.push((numerator / denominator) * 32)
		thirtytwondSplit16.splice(0, 0, 0)
		thirtytwondSplit16.push((numerator / denominator) * 32)
	}//if custom
	
	/*if (beamType != 3) {
		function change(beamType, type) {
			switch (beamType) {
				case 3: {
					break;
				}
				case 2: {
					switch (type) {
						case 3: {
							type = 2
							break;
						}
						case 2: {
							type = 2
							break;
						}
						case 1: {
							type = 0
							break;
						}
						case 0: {
							type = 0
							break;
						}
					}
					break;
				}
				case 1: {
					switch (type) {
						case 3: {
							type = 1
							break;
						}
						case 2: {
							type = 0
							break;
						}
						case 1: {
							type = 1
							break;
						}
						case 0: {
							type = 0
							break;
						}
					}
					break;
				}
				case 0: {
					type = 0
					break;
				}
			}
			return type;
		}
		sS8type = change(beamType, sS8type)
		tS8type = change(beamType, tS8type)
		tS16type = change(beamType, tS16type)
	}*/
	
	return [eighthSplit, sixteenthSplit, thirtytwondSplit, sixteenthSplit8, thirtytwondSplit8, thirtytwondSplit16,
		beamType, sS8type, tS8type, tS16type];
}//function