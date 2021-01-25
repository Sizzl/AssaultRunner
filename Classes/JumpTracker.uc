//==================================================================//
// AssaultRunner offline mutator - ©2009 timo@utassault.net         //
//                                                                  //
// Updated Jan 2021:                                                //
//  - See https://github.com/Sizzl/AssaultRunner for update history //
//                                                                  //
//==================================================================//
class JumpTracker extends TournamentPickup;
var ASARO ParentRunner;

state Activated
{

Begin:
	Pawn(Owner).bCountJumps = True;
}

state DeActivated
{
Begin:		
}


function OwnerJumped()
{
	local float JumpVelo;
	if (ParentRunner != None)
	{
		if ( Pawn(Owner).Physics == PHYS_Walking )
			ParentRunner.JumpsWhileWalking++;
		else if ( Pawn(Owner).Physics == PHYS_Falling )
			ParentRunner.JumpsWhileFalling++;	
		else if ( Pawn(Owner).Physics == PHYS_Swimming )
			ParentRunner.JumpsWhileSwimming++;
		else
			ParentRunner.JumpsWhileOther++;
		
		JumpVelo = Sqrt(Square(Pawn(Owner).Velocity.X)+Square(Pawn(Owner).Velocity.Y)+Square(Pawn(Owner).Velocity.Z));
		ParentRunner.LastJumpVelo = JumpVelo;
		
		if (Pawn(Owner).bRun==1 && JumpVelo > 500)
			ParentRunner.bWFJ = true;

		if (JumpVelo == 0)
			ParentRunner.bJumpPhysicsAltered = true;
		
	}
	if( Inventory != None )
		Inventory.OwnerJumped();
}

defaultproperties
{
      bAutoActivate=True
      bActivatable=True
      bDisplayableInv=False
      ItemName="ASARO JumpTracker"
      Charge=0
      MaxDesireability=0
      RemoteRole=ROLE_DumbProxy
      CollisionRadius=0
      CollisionHeight=0
      bHidden=True
}

