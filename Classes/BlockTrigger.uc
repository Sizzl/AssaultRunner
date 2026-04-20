//=============================================================================
// BlockTrigger.
//=============================================================================
class BlockTrigger extends BlockAll;

var bool NewColActors;
var bool NewBlockActors;
var bool NewBlockPlayers;

function SetMode( bool initColActors, bool initBlockActors, bool initBlockPlayers, bool trigColActors, bool trigBlockActors, bool trigBlockPlayers )
{
	SetCollision( initColActors, initBlockActors, initBlockPlayers );
	NewColActors = trigColActors;
	NewBlockActors = trigBlockActors;
	NewBlockPlayers = trigBlockPlayers;
}

function Trigger( Actor Other, Pawn EventInstigator )
{
	Instigator = EventInstigator;
	SetCollision( NewColActors, NewBlockActors, NewBlockPlayers );
}

defaultproperties
{
   bStatic=False
}
