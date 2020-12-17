//=================================================================//
// AssaultRunner offline mutator - ©2009 timo@utassault.net        //
// Updated Dec 2020:                                               //
//  - Added PlayerStart optimisation based on tags and distance    //
//    from FortStandards.                                          //
//=================================================================//
class ASARO expands Mutator config(AssaultRunner);

var bool Initialized, bRecording, bProcessedEndGame, bSuperDebug, bGotWorldStamp, bIsModernClient, bLoggedCM, bIDDQD, bIDNoclip, bIDFly, bTurbo, bCheatsEnabled, bSpeedChanged, bJumpChanged;
var string AppString, ShortAppString, GRIFString, ExtraData;
var int AttackingTeam, MapAvailableTime, TickCount, ObjCount, SimCounter, TimeLag, RemainingTime, ticks;
var float SecondCount, FloatCount, WorldStamp, LifeStamp, fConquerTime, fConquerLife, ElapsedTime, TimerPreRate, TimerPostRate, InitSpeed, StartZ, StartWS, StartGS, StartAS;

var LeagueAS_GameReplicationInfo LeagueASGameReplicationInfo;
var PlayerPawn Debugger, ASAROPlayer;
var HUD ASAROHUD;

var() config bool bEnabled;
var() config bool bDebug;
var() config bool bAttackOnly;
var() config bool bAllowRestart;
var() config bool bUseSmartReset;

var() config int iResolution;

var() config bool bAutoDemoRec;

var() config bool bGRPMethod;
var() config bool bUseFloatAlways;
var() config bool bFullTime;
var() config string GRIString;

var() config string LastDemoFileName;


event PreBeginPlay()
{
	local GameReplicationInfo GRI;
	local int TimeLimit;
	local FortStandard F;
	local PlayerStart PS;
	
	if(!Initialized && bEnabled)
	{
		if(Level.Game.IsA('Assault'))
		{
			Assault(Level.Game).bCoopWeaponMode = Assault(Level.Game).bMultiWeaponStay;
			SecondCount = Level.TimeSeconds;
			if (Assault(Level.Game).CurrentDefender==1)
				AttackingTeam = 0;
			else
				AttackingTeam = 1;

			ForEach AllActors(class'FortStandard', F)
			{
				TimeLimit = Max(TimeLimit, F.DefenseTime);
				ObjCount++;
			}
			TimeLag = TimeLimit * 60;
			MapAvailableTime = TimeLag;
			SimCounter = 0;
			bGotWorldStamp = false;
			bProcessedEndGame = false;

			StartZ = -1;
			StartAS = -1;
			StartWS = -1;
			StartGS = -1;

			OptimisePlayerStarts();
			SetTimer(TimerPreRate,true);

			SaveConfig();
			if (bIsModernClient)
			{
				//log(AppString@"initialization complete. (Mode = "$String(Level.NetMode)$"; modern engine detected - ["$Level.EngineVersion$Level.EngineRevision"]).");	
			}
			else
				log(AppString@"initialization complete. (Mode = "$String(Level.NetMode)$").");
			Initialized=True;
		} else {
			bProcessedEndGame = true;
			log(AppString@"running, but disabled (not AS gametype).");
			Initialized=True;
		}
		Initialized=True;
	}
	else
	{
		if (!bEnabled)
		{
			bProcessedEndGame = true;
			log(AppString@"running, but disabled (bEnabled = false).");
			Initialized=True;
		}
	}
}

function string GDP(string Input, int Places)
{
	if (Places == 0)
		return Left(Input,InStr(Input,"."));
	else
		return Left(Input,InStr(Input,"."))$"."$Left(Right(Input,Len(Input)-(InStr(Input,".")+1)),Places);
}

event Timer()
{
	local bool bStopCountDown;
	local string DataString;
	local float fLT;

	if ( Level.NetMode == NM_Client || Level.NetMode == NM_Standalone )
	{
		if (ASAROPlayer != None)
			bStopCountDown = ASAROPlayer.GameReplicationInfo.bStopCountDown;
			
		if (Level.TimeSeconds - SecondCount >= Level.TimeDilation)
		{
			ElapsedTime = ElapsedTime+1;
			SecondCount += Level.TimeDilation;
		}
	}

	if (!bGotWorldStamp && !bProcessedEndGame)
	{
		if (LeagueAssault(Level.Game).bMapStarted) {
			WorldStamp = Level.TimeSeconds;
			LifeStamp = (Level.Hour * 60 * 60) + (Level.Minute * 60) + Level.Second + (Level.MilliSecond/1000);
			ElapsedTime = 0;
			if (bDebug) log("Captured level start timestamp as:"@WorldStamp$", reset ET:"@ElapsedTime,'ASARO');
			Tag='EndGame';
			bGotWorldStamp = true;
			InitSpeed = Level.TimeDilation;
			SetTimer(TimerPostRate,true);
		}
	}
	else {
		if (ASAROPlayer != None) {
			ASAROPlayer.bCheatsEnabled = bCheatsEnabled;
			
			if (bCheatsEnabled)
				bLoggedCM = True;
			if (bGotWorldStamp)
			{
				if (ASAROPlayer.ReducedDamageType == 'All')
					bIDDQD = True;
				
				if (ASAROPlayer.bCollideWorld == False)
					bIDNoclip = True;

				if (ASAROPlayer.Physics == PHYS_Flying)
					bIDFly = True;
				
				if (Level.TimeDilation != InitSpeed)
					bTurbo = True;

				if (ASAROPlayer.GroundSpeed != StartGS || ASAROPlayer.WaterSpeed != StartWS || ASAROPlayer.AirSpeed != StartAS)
					bSpeedChanged=True;
			}
			if (bLoggedCM || bIDNoclip || bIDDQD || bIDFly || bTurbo || bSpeedChanged || bJumpChanged)
			{
				ExtraData = " | Detected:";
				if (bLoggedCM)
					ExtraData = ExtraData@"Cheat Mode toggled;";
				if (bIDNoclip)
					ExtraData = ExtraData@"Ghost mode;";
				if (bIDFly)
					ExtraData = ExtraData@"Fly mode;";
				if (bIDDQD)
					ExtraData = ExtraData@"God mode;";
				if (bTurbo)
					ExtraData = ExtraData@"Speed (slomo);";
				if (bSpeedChanged)
					ExtraData = ExtraData@"Speed (friction);";
				if (bJumpChanged)
					ExtraData = ExtraData@"Jump Height (Z);";
					
				ExtraData = Left(ExtraData,Len(ExtraData)-1);
			}

			if (ASAROPlayer.Scoring != None) {
				TournamentScoreBoard(ASAROPlayer.Scoring).Ended = AppString;
				fLT = fConquerLife / (Assault(Level.Game).GameSpeed * Level.TimeDilation);
				DataString = "[L:"$GDP(string(fLT),3)@"| E:"$GDP(string(ElapsedTime),0)@"| G:"$GDP(string(Assault(Level.Game).GameSpeed),2)@"| D:"$GDP(string(Level.TimeDilation),2)@"| A:"$GDP(string(Assault(Level.Game).AirControl),2)$ExtraData$"]";
				TournamentScoreBoard(ASAROPlayer.Scoring).Continue = DataString;
				if (bProcessedEndGame)
					SetTimer(0.0,false);
				else
					SetTimer(TimerPostRate,true);
			}
		}
	}

}

simulated function Tick(float DeltaTime)
{
	local Pawn Other;
	local int i;
	local int SR;
	
  if ( !bHUDMutator && Level.NetMode != NM_DedicatedServer )
  	RegisterHUDMutator();
        
	Super.Tick(DeltaTime);
	ticks++;
	
	if (LeagueAssault(Level.Game).bMapEnded != true && SR < 0)
	{
		SimCounter++;	
		TickCount++;
		if (TickCount > 0) {
			FloatCount = TickCount - (TickCount*(Level.TimeDilation-1));
		}
		else
			FloatCount = 0;
		if (TimeLag > Assault(Level.Game).RemainingTime) {
			TimeLag = Assault(Level.Game).RemainingTime;
			TickCount = 0;
			FloatCount = 0;
		}
	} else {
		if(Assault(Level.Game).bAssaultWon && !bProcessedEndGame) {
			LogGameEnd();
		}
	}
	
	if (bDebug==true && !bGotWorldStamp)
	{
		if (Debugger != None)
		{
			Debugger.ClientMessage(ReturnTimeStr(!bProcessedEndGame,false,bFullTime));
		}
	}
}
//simulated event Actor (UT) SpawnNotification(Actor (UT) A) 

simulated function PostRender(canvas Canvas)
{
	local GameReplicationInfo GRI;
	local float XL, YL;
	local font CanvasFont;
	local bool bIsC;
	local Actor T;

	
	ASAROPlayer = Canvas.Viewport.Actor;
	if ( ASAROPlayer != None )
	{
		if (StartZ < 0)
		{
			StartZ = ASAROPlayer.JumpZ;
			ASAROPlayer.bAdmin = false;
		}
		
		if (StartGS < 0)
			StartGS = ASAROPlayer.GroundSpeed;
		
		if (StartWS < 0)
			StartWS = ASAROPlayer.WaterSpeed;
		
		if (StartAS < 0)
			StartAS = ASAROPlayer.AirSpeed;
			

  		ASAROHUD = ASAROPlayer.myHUD;
  		GRI = ASAROPlayer.GameReplicationInfo;

		if (!bProcessedEndGame && bGotWorldStamp) {
			Canvas.StrLen("Test", XL, YL);
			Canvas.DrawColor.R = 255;
			Canvas.DrawColor.G = 255;
			Canvas.DrawColor.B = 255;
			bIsC = Canvas.bCenter;
			Canvas.bCenter = true;
			Canvas.SetPos(0, 1 * YL);
			Canvas.DrawText(ReturnTimeStr(!bProcessedEndGame,false,bDebug));
			if (bSuperDebug)
			{
				Canvas.SetPos(0, 2 * YL);
				Canvas.DrawText(ReturnTimeStr(!bProcessedEndGame,true,bDebug));
				if (ExtraData != "")
				{
					Canvas.SetPos(0, 3 * YL);
					Canvas.DrawText(Right(ExtraData,Len(ExtraData)-2));
				}
			}
			Canvas.bCenter = bIsC;
 		}
 		else if (!bProcessedEndGame) {
			Canvas.StrLen("Test", XL, YL);
			Canvas.DrawColor.R = 200;
			Canvas.DrawColor.G = 150;
			Canvas.DrawColor.B = 50;
 			bIsC = Canvas.bCenter;
			Canvas.bCenter = true;
 			Canvas.SetPos(0, Canvas.ClipY - Min(YL*6, Canvas.ClipY * 0.1));
 			Canvas.DrawText(AppString);
 			Canvas.bCenter = bIsC;
 		}
	}
	if ( NextHUDMutator != None )
		NextHUDMutator.PostRender(Canvas);
}


event Trigger(Actor Other, Pawn EventInstigator)
{
	if (Other.IsA('Assault'))
	{
		LogGameEnd();
	}
}

function OptimisePlayerStarts()
{

	local PlayerStart PS,ActivePS,NearestPSToFort;
	local FortStandard NearestFort;
	local string MapName;

	MapName = Left(Self, InStr(Self, "."));

	// Disable known-bad, or badly placed playerstarts
	foreach AllActors(Class'PlayerStart',PS)
	{
		if (Left(MapName,9)~="AS-Bridge")
		{
			if( PS.Name == 'PlayerStart7' || PS.Name == 'PlayerStart8' || PS.Name == 'PlayerStart9' || PS.Name == 'PlayerStart21' || PS.Name == 'PlayerStart24' || PS.Name == 'PlayerStart30')
			{
				DisablePlayerStart(PS,false);
			}
		}
	}
	// Determine active attacker playerstarts
	foreach AllActors(Class'PlayerStart',PS)
	{
		if (PS.TeamNumber==1 && PS.bEnabled)
		{
			ActivePS = PS;
		}
	}
	if (ActivePS != None)
	{
		// Find nearest fort first
		NearestFort = NearestObj(ActivePS);
		if (NearestFort != None)
		{
			if (bDebug) log("Found closest objective to active PlayerStart:"@NearestFort.Name,'ASARO');
			// Now find the nearest active playerstart for this fort and disable the others
			NearestPSToFort = NearestPlayerStart(NearestFort,true,ActivePS.TeamNumber,ActivePS.Tag);
			if (NearestPSToFort != None)
			{
				if (bDebug) log("Found closest PlayerStart to "@NearestFort.Name$":"@NearestPSToFort.Name,'ASARO');
				foreach AllActors(Class'PlayerStart',PS)
				{
					if (PS.TeamNumber==1 && PS.bEnabled)
					{
						if (PS.Name != NearestPSToFort.Name)
							DisablePlayerStart(PS,true);
						else
							if (bDebug) log("The most optimal PlayerStart to the closest objective is being used:"@PS.Name,'ASARO');	
					}
				}
			}
			else
			{
				if (bDebug) log("Could not find closest PlayerStart to FortStandard:"@NearestFort.Name,'ASARO');
			}
		}
	}
	// Repeat for inactive PlayerStarts, grouped by tag
	if (bDebug) log("Optimising future PlayerStarts...",'ASARO');
	foreach AllActors(Class'PlayerStart',PS)
	{
		if (PS.TeamNumber==1 && !(PS.bEnabled) && PS.Tag != 'SlowAssPlayerStart' && PS.Tag != '')
		{
			ActivePS = PS;
			NearestFort = NearestObj(ActivePS);
			if (NearestFort != None)
			{
				if (bDebug) log("Found closest objective to inactive PlayerStart ("$ActivePS.Name$"):"@NearestFort.Name,'ASARO');
				NearestPSToFort = NearestPlayerStart(NearestFort,false,ActivePS.TeamNumber,ActivePS.Tag);
				foreach AllActors(Class'PlayerStart',PS,ActivePS.Tag)
				{
					if (PS.Name != NearestPSToFort.Name)
					{
						DisablePlayerStart(PS,true);
					}
					else
					{
						if (bDebug) log("The most optimal future PlayerStart to the closest objective ("$NearestFort.Name$") is being used:"@PS.Name,'ASARO');	
					}
				}
			}
		}
	}



}
function DisablePlayerStart (PlayerStart PS, bool Optimising)
{
	if (PS != None)
	{
		PS.Tag = 'SlowAssPlayerStart';
		PS.bEnabled = false;
		if (bDebug)
		{
			if (Optimising)
			{
				if (PS.bEnabled)
					log("Disabling inefficient PlayerStart:"@PS.Name,'ASARO');
				else
					log("Disabling future inefficient PlayerStart:"@PS.Name,'ASARO');
			}
			else
				log("Disabling Known Bad PlayerStart:"@PS.Name,'ASARO');
		}
	}
}
function float DistanceFrom (Actor A1, Actor A2)
{
	local float DistanceX;
	local float DistanceY;
	local float DistanceZ;
	local float ADistance;

	DistanceX = A1.Location.X - A2.Location.X;
	DistanceY = A1.Location.Y - A2.Location.Y;
	DistanceZ = A1.Location.Z - A2.Location.Z;
	ADistance = Sqrt(Square(DistanceX) + Square(DistanceY) + Square(DistanceZ));
	return ADistance;
}

function PlayerStart NearestPlayerStart (Actor A, bool ActiveOnly,int TeamNumber,name Tag)
{
	local float DistToNearestPS,ThisPSDist;
	local PlayerStart PS,NearestPS;

	DistToNearestPS = 0.0;
	foreach AllActors(Class'PlayerStart', PS, Tag)
	{
		if (PS.TeamNumber == TeamNumber)
		{
			if ((ActiveOnly && PS.bEnabled) || !ActiveOnly)
			{
				if (bDebug) log("Measuring distance between "$A.Name$" and "$PS.Name,'ASARO');
				ThisPSDist = DistanceFrom(A,PS);
				if (bDebug) log("Measured distance between "$A.Name$" and "$PS.Name$":"@ThisPSDist,'ASARO');

				if ( (DistToNearestPS == 0) || (ThisPSDist < DistToNearestPS) )
				{
					NearestPS = PS;
					DistToNearestPS = ThisPSDist;
				}
			}
		}
	}
	return NearestPS;
}


function FortStandard NearestObj (Actor A)
{
	local FortStandard F;
	local FortStandard NearestFort;
	local float DistToNearestFort;
	local float ThisFortDist;

	DistToNearestFort = 0.0;
	foreach AllActors(Class'FortStandard',F)
	{
		ThisFortDist = DistanceFrom(A,F);
		if ( (DistToNearestFort == 0) || (ThisFortDist < DistToNearestFort) )
		{
			NearestFort = F;
			DistToNearestFort = ThisFortDist;
		}
	}
	return NearestFort;
}


function LogGameEnd()
{
	local Pawn P;
	local TournamentScoreBoard T;
	
	fConquerTime = Level.TimeSeconds-WorldStamp;
	fConquerLife = ((Level.Hour * 60 * 60) + (Level.Minute * 60) + Level.Second + (Level.MilliSecond/1000)) - LifeStamp;
	if (bGRPMethod==true) {
		for (P=Level.PawnList; P!=None; P=P.NextPawn)
		{
			if(		PlayerPawn(P) != None
				&&	P.PlayerReplicationInfo != None
				&&	NetConnection(PlayerPawn(P).Player) != None)
			{
				if (!Assault(Level.Game).bAssaultWon)
					PlayerPawn(P).GameReplicationInfo.GameEndedComments = GRIFString;
				else
					PlayerPawn(P).GameReplicationInfo.GameEndedComments = GRIString@ReturnTimeStr(false,false,bFullTime);
			}
		}
	} else {
		if (!Assault(Level.Game).bAssaultWon)
			LeagueAS_GameReplicationInfo(Level.Game.GameReplicationInfo).GameEndedComments = GRIFString;
		else
			LeagueAS_GameReplicationInfo(Level.Game.GameReplicationInfo).GameEndedComments = GRIString@ReturnTimeStr(false,false,bFullTime);
	}

	bProcessedEndGame = true;
	SetTimer(0.05,true);
}

function string ReturnTimeStr(bool bLiveTimer, bool bRealTime, bool bShowFullTime)
{
	local int Minutes, Seconds;
	local string TimeResult,strSubTime, DataString;
	local float SubTime, TickDiff, ConquerTime, ConquerLife, fLT;

	if (bLiveTimer)
	{
		ConquerTime = Level.TimeSeconds-WorldStamp;
		ConquerLife = ((Level.Hour * 60 * 60) + (Level.Minute * 60) + Level.Second + (Level.MilliSecond/1000)) - LifeStamp;
	}
	else
	{
		ConquerTime = fConquerTime;
		ConquerLife = fConquerLife;
	}

	// Recalc offline timing...
	if (bRealTime)
		subTime = ConquerLife / (Assault(Level.Game).GameSpeed * Level.TimeDilation);
	else
		subTime = ConquerTime / (Assault(Level.Game).GameSpeed * Level.TimeDilation);

	Minutes = int(subTime)/60;

	if ( Minutes > 0 )
		TimeResult = string(Minutes)$":";
	else
		TimeResult = "0:";

	Seconds = int(subTime) % 60;

	if ( Seconds == 0 )
		TimeResult = TimeResult$"00";
	else if ( Seconds < 10 )
		TimeResult = TimeResult$"0"$Seconds;
	else
		TimeResult = TimeResult$Seconds;

	strSubTime = string(subTime);
	strSubTime = Right(strSubTime,Len(strSubTime)-(InStr(strSubTime,".")+1));
	if (iResolution > 0)
		strSubTime = Left(strSubTime,iResolution);

	fLT = ConquerLife / (Assault(Level.Game).GameSpeed * Level.TimeDilation);

	if (bDebug || bSuperDebug) {
		DataString = " [L:"$GDP(string(fLT),3);
		DataString = DataString$"|E:"$GDP(string(ElapsedTime),0);
		DataString = DataString$"|G:"$GDP(string(Assault(Level.Game).GameSpeed),2);
		DataString = DataString$"|D:"$GDP(string(Level.TimeDilation),2);
		DataString = DataString$"]";
	}
	else
		DataString = "";
		
	if (bSuperDebug || bDebug || bShowFullTime)
		strSubTime = strSubTime@"(World:"$(ConquerTime)$DataString$")";
		
	TimeResult = TimeResult$"."$strSubTime;
	return TimeResult;
}


function Mutate(string MutateString, PlayerPawn Sender)
{
	local int i;
	local string GT;
	GT=Level.Game.MapPrefix;
	
	if(MutateString~="ar info")
	{
		Sender.ClientMessage(AppString@"- "@GT@" SpeedRun Mutator");
		Sender.ClientMessage("************");
		Sender.ClientMessage("Ticks this level: "@SimCounter);
	}

	if (bEnabled) {
		if (MutateString~="ar debug")
		{
			if (bDebug==true) {
				bDebug=false;
				Debugger = Sender;
			} else {
				bDebug=true;
				Debugger = Sender;			
			}
		}
		else if (MutateString~="ar superdebug")
		{
			if (bSuperDebug==true) {
				bSuperDebug=false;
				bDebug=false;
				Debugger = Sender;
			} else {
				bSuperDebug=true;
				bDebug=true;
				Debugger = Sender;			
			}
		}
		else if (Left(MutateString,8)~="ar cheat")
		{
			if (bCheatsEnabled)
			{
				bCheatsEnabled=False;
			}
			else
			{
				bCheatsEnabled=True;
				Sender.ClientMessage("Cheats are now enabled; this run will be flagged.");
			}
			SaveConfig();

		}
		else if (MutateString~="ar restart")
		{
			RestartMap();
		}
		else if (MutateString~="ar demo" || MutateString~="ar demorec")
		{
			RequestDemo();
		}
	}
	if ( NextMutator != None )
		NextMutator.Mutate(MutateString, Sender);
}

function bool MutatorTeamMessage(Actor Sender, Pawn Receiver, PlayerReplicationInfo PRI, coerce string S, name Type, optional bool bBeep)
{
	// MutatorTeamMessage is called once for every player on the server so
	// only log when the sender is the receiver to elimiate duplicates.	
	if(Receiver != none && Receiver == Sender)
	{

  	if (Sender.isA('PlayerPawn') && !Sender.isA('CHSpectator')) {
			if(S~= "!restart") {
				Mutate("ar restart",PlayerPawn(Sender));
			}
			if(S~= "!demorec") {
				Mutate("ar demo",PlayerPawn(Sender));
			}
		}
	}

	if ( NextMessageMutator != None )
		return NextMessageMutator.MutatorTeamMessage( Sender, Receiver, PRI, S, Type, bBeep );
	else
		return true;
}

function bool RequestDemo()
{
	if (bRecording==true)
		return false;

	ConsoleCommand("demostop");
	LastDemoFileName = Level.Year $ right("0" $ Level.Month,2) $ right("0" $ Level.Day,2) $ "-" $ right("0" $ Level.Hour,2) $ right("0" $ Level.Minute,2) $ right("0" $ Level.Second,2) $ "_" $ Left(Self, InStr(Self, "."));
	SaveConfig();
	ConsoleCommand("demorec " $ LastDemoFileName);
	bRecording = true;
	
	return bRecording;
}

function RestartMap()
{
	Assault(Level.Game).RemainingTime = MapAvailableTime;
	SimCounter = 0;
	Assault(Level.Game).bDefenseSet = False;
	Assault(Level.Game).NumDefenses = 0;
	Assault(Level.Game).CurrentDefender = 0;
	Assault(Level.Game).SavedTime = 0.0;
	LeagueAssault(Level.Game).GameCode = "";
	Assault(Level.Game).Part = 1;
	Assault(Level.Game).bTiePartOne = False;
	Level.Game.SaveConfig();
	SaveConfig();
	Level.ServerTravel( "?Restart?", false );
}

//=================================================================//

//=================================================================//

defaultproperties
{
     AppString="AssaultRunner Offline version 1.0d by timo@utassault.net"
     ShortAppString="AssaultRunner:"
     bEnabled=True
     bCheatsEnabled=False
     bAttackOnly=True
     bAllowRestart=True
     iResolution=3
     bAutoDemoRec=True
     bUseFloatAlways=True
     bFullTime=True
     GRIString="Map completed in:"
     GRIFString="You're an absolute failure. You have no time worthy of display."
     bAlwaysRelevant=True
     bNetTemporary=True
     RemoteRole=ROLE_SimulatedProxy
     TimerPreRate=0.05
     TimerPostRate=0.10
}
