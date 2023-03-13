//===================================================//
//Tuplet Presets for ReBeamer Plugin
//Copyright (C) 2023 XiaoMigros
//v 1.0
//Changelog:
//===================================================//

//returns settings in one big array
//calculates beaming rules based on tuplet size
//to-do: account for tuplets with base length of 1.5, etc

// CODE STRUCTURE:
//
// - 3 arrays per timesig: 8th splitpoints, 16th splitpoints & 32nd splitpoints
//   Splitpoints are where in the measure the beam is split
//   the beam is split after X 8ths/16ths/32nds/ have occured in the tuplet
//
// - 2 8th subdivision arrays: 16th sub8 & 32nd sub8
//   determines where to show the 8th subdivision in 16th and 32nd notes/rests
//   functions the same way as the previous splitpoints
//
// - 1 16th subdivision array: 32nd sub16
//
// - Type variables:
//   whether to change the beam for rests (1), notes (2), none (0), or both (3)
//   tsS8type = tuplet sixteenth sub 8 type, etc
//
// - tbeamType:
//   Whether to (in general) beam rests (1), notes (2), nothing (0), or everything (3).
//   Note: beamType does not override the subbeam types
//
// - simplifyTuplets: whether to hide a tuplet's brackets where suitable
//
// - beamToFromTuplets: whether to allow beams going towards and away from tuplets, or whether they should be treated as separate units
//
// - beamTuplets: whether the beaming of a tuplet should be changed at all

function getTupletRules(tupletN, tupletBaseLength) {
	
	//default values for all tuplets
	var teighthSplit		= []
	var tsixteenthSplit		= []
	var tthirtytwondSplit	= []
	var tsixteenthSplit8	= []
	var tthirtytwondSplit8	= []
	var tthirtytwondSplit16	= []
	var tbeamType			= 3;
	var tsS8type			= 3;
	var ttS8type			= 3;
	var ttS16type			= 3;
	var simplifyTuplets		= true
	var beamToFromTuplets	= true //currently not changeable
	var beamTuplets			= true //currently not changeable
	//change them by redefining the value later on in the function
	
	switch (tupletBaseLength) {
		case (tupletBaseLength >= 0.5): {
			//0.5: tupletN
			//1: tupletN * 2
			//2: tupletN * 4
			for (var i = 0; i <= tupletN * tupletBaseLength * 2; ++i) {
				teighthSplit.push(4*i)
			}
			for (var i = 0; i <= tupletN * tupletBaseLength * 4; ++i) {
				tsixteenthSplit.push(4*i)
				tthirtytwondSplit.push(8*i)
			}
			for (var i = 0; i <= tupletN * tupletBaseLength * 8; ++i) {
				tsixteenthSplit8.push(2*i)
				tthirtytwondSplit8.push(4*i)
			}
			for (var i = 0; i <= tupletN * tupletBaseLength * 8; ++i) {
				tsixteenthSplit8.push(2*i)
				tthirtytwondSplit8.push(4*i)
			}
			for (var i = 0; i <= tupletN * tupletBaseLength *16; ++i) {
				tthirtytwondSplit16.push(2*i)
			}
			break;
		}
		case 0.25: {
			for (var i = 0; i <= tupletN * 1; ++i) {
				teighthSplit.push(2*i)
				tsixteenthSplit.push(4*i);
				tthirtytwondSplit.push(8*i);
			}
			for (var i = 0; i <= tupletN * 2; ++i) {
				tsixteenthSplit8.push(2*i);
				tthirtytwondSplit8.push(4*i);
			}
			for (var i = 0; i <= tupletN * 4; ++i) {
				tthirtytwondSplit16.push(2*i)
			}
			break;
		}
		case 0.125: {
			teighthSplit.push(0)
			teighthSplit.push(tupletN)
			tsixteenthSplit.push(0)
			tsixteenthSplit.push(tupletN * 2)
			tthirtytwondSplit.push(0)
			tthirtytwondSplit.push(tupletN * 4)
			for (var i = 0; i <= tupletN * 1; ++i) {
				tsixteenthSplit8.push(2*i)
				tthirtytwondSplit8.push(4*i)
			}
			for (var i = 0; i <= tupletN * 2; ++i) {
				tthirtytwondSplit16.push(i)
			}
			break;
		}
		case 0.0625: {
			teighthSplit.push(0)
			teighthSplit.push(tupletN / 2)
			tsixteenthSplit.push(0)
			tsixteenthSplit.push(tupletN)
			tsixteenthSplit8.push(0)
			tsixteenthSplit8.push(tupletN)
			tthirtytwondSplit.push(0)
			tthirtytwondSplit.push(tupletN * 2)
			tthirtytwondSplit8.push(0)
			tthirtytwondSplit8.push(tupletN * 2)
			for (var i = 0; i <= tupletN * 1; ++i) {
				tthirtytwondSplit16.push(i)
			}
			break;
		}
		default: {//smaller than or equal to 32nd tuplets
			teighthSplit.push(0)
			teighthSplit.push(tupletN * tupletBaseLength * 8)
			tsixteenthSplit.push(0)
			tsixteenthSplit.push(tupletN * tupletBaseLength * 16)
			tsixteenthSplit8.push(0)
			tsixteenthSplit8.push(tupletN * tupletBaseLength * 16)
			tthirtytwondSplit.push(0)
			tthirtytwondSplit.push(tupletN * tupletBaseLength * 32)
			tthirtytwondSplit8.push(0)
			tthirtytwondSplit8.push(tupletN * tupletBaseLength * 32)
			tthirtytwondSplit16.push(0)
			tthirtytwondSplit16.push(tupletN * tupletBaseLength * 32)
			break;
		}
	}//switch
	return [teighthSplit, tsixteenthSplit, tthirtytwondSplit, tsixteenthSplit8, tthirtytwondSplit8, tthirtytwondSplit16,
		tbeamType, tsS8type, ttS8type, ttS16type, simplifyTuplets, beamToFromTuplets, beamTuplets];
}//getTupletRules