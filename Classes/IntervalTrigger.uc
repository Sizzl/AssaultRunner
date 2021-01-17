//==================================================================//
// AssaultRunner offline mutator - ©2009 timo@utassault.net         //
//                                                                  //
// Updated Jan 2021:                                                //
//  - See https://github.com/Sizzl/AssaultRunner for update history //
//                                                                  //
//==================================================================//

class IntervalTrigger expands Trigger;

var() SpecialEvent SpecialEventHook;
var() bool bDebug, bBroadcast;

function Touch( actor Other )
{
	local string CapturedTime;
	if( IsRelevant( Other ) )
	{
		if (bDebug)
			log("IntervalTrigger touched.",'ASARO');
		if (Owner != None && Owner.isA('ASARO'))
		{
			CapturedTime = ASARO(Owner).ReturnTimeStr(!ASARO(Owner).bProcessedEndGame,false,ASARO(Owner).bDebug,true);
			
			if (bDebug)
				log("IntervalTrigger time captured:"@CapturedTime,'ASARO');

			if (SpecialEventHook != None && Event != '')
			{
				SpecialEventHook.bBroadcast = bBroadcast;
				SpecialEventHook.Message = default.Message@CapturedTime;
				Message = "";
			}
			else
			{
				// Use built-in messaging if the SE hook isn't present.
				Message = default.Message@CapturedTime;
				Event = '';
			}
		}
	}
	bHidden=true;
	Super.Touch(Other);
}


defaultProperties
{
	//defaults
	bTriggerOnceOnly=true
	bInitiallyActive=true
	TriggerType=TT_PlayerProximity
	//DrawType=DT_Mesh
	//Mesh=Mesh'Botpack.UTRingex'
	//Texture=Texture'Botpack.Effects.ASaRing'
	//DrawScale=1
	DrawType=DT_Sprite
	DrawScale=1.5
	Texture=Texture'Botpack.Icons.YellowFlag'
	bMeshEnviroMap=true
	bHidden=false
	Message="Interval captured:"
	Tag='CustomIntervalTriggers'
	Style=STY_Translucent
}