//=================================================================//
// AR_RadiusTrigger - ©2009 timo@utassault.net                     //
//=================================================================//
class AR_RadiusTrigger expands TeamTrigger;
var float RecordedTime;
//
// Called when something touches the trigger
// Just records touch/untouch - no events parsed
//
function Touch( actor Other )
{
	local actor A;
//	Super.Touch(Other);
	if( IsRelevant( Other ) )
	{
			
		if( Message != "" )
			// Send a string message to the toucher.
			Other.Instigator.ClientMessage( Message );

		if( bTriggerOnceOnly )
			// Ignore future touches.
			SetCollision(False);
		else if ( RepeatTriggerTime > 0 )
			SetTimer(RepeatTriggerTime, false);
	}
}

defaultproperties {

}