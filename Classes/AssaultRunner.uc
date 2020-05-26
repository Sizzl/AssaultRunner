//=================================================================//
// AssaultRunner mutator - ©2009 timo@utassault.net                //
//=================================================================//

class AssaultRunner expands Mutator config(AssaultRunner);

var bool Initialized, bRecording, bProcessedEndGame, bSuperDebug;
var string AppString, FirstSpawnsTag, ShortAppString;
var name FirstSpawnsRef;
var int AttackingTeam, SlotCount, MapAvailableTime, WaitLeft, MaxRecords, TickCount, TickRate, NPID, AtkCount, ObjCount, CurrentID, SimCounter, TimeLag, ElapsedTime, RemainingMinute, iaSDdelay, lastSound;
var float SecondCount, FloatCount, WorldStamp, CurrentRecord;
var LeagueAS_GameReplicationInfo LeagueASGameReplicationInfo;
var PlayerPawn Debugger;
var() config bool bEnabled;
var() config bool bDebug;
var() config int NetWait;
var() config int WaitTime;
var() config bool bAttackOnly;
var() config bool bAllowRestart;
var() config bool bStrictMode;
var() config bool bUseSmartReset;
var() config float fSRFrequency;
var() config int iSDFrequency;
var() config string SmartResetMessage;
var() config int ARRTLeeway;
var() config bool bRequestDemoRec;
var() config bool bAutoDemoRec;
var() config bool bForceTournament;
var() config bool bGRPMethod;
var() config bool bUseFloatAlways;
var() config bool bFullTime;
var() config int iResolution;
var() config int iSDdelay;
var() config bool bRepeatSDDelay;
var() config string GRIString;
var() config string LastDemoFileName;
var() config string RecordMaps[41];
var() config string RecordPlayers[41];
var() config float RecordTimes[41];
var() config string RecordDemos[41];
var() config sound ResetSound;
//=================================================================//

function PostNetBeginPlay()
{
		if(Level.Game.IsA('LeagueAssault'))
		{
			CheckSettings();
			CheckRecords();
		}
}

function PostBeginPlay()
{
	local GameReplicationInfo GRI;
	local int TimeLimit;
	local FortStandard F;
	local AR_RadiusTrigger ARRT;
	local PlayerStart PS;
	
	if(!Initialized && bEnabled)
	{
		if(Level.Game.IsA('Assault'))
		{
			SecondCount = Level.TimeSeconds;
			if(Level.Game.IsA('LeagueAssault'))
			{
				Level.Game.BaseMutator.AddMutator(Self);
				Level.Game.RegisterMessageMutator(Self);
				SetFirstSpawns();
			}

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
			
			if (bUseSmartReset) // also enables announcing map records
			{
				if (bDebug) log(ShortAppString@"Smart Reset Enabled!");
				
				ForEach AllActors(class'PlayerStart',PS)
				{
					if (PS.bEnabled==true && PS.TeamNumber==1)
					{
						ARRT = Spawn(class'AR_RadiusTrigger',Self,'ARRTfsInit', PS.Location, PS.Rotation);
						ARRT.SetCollisionSize(PS.CollisionRadius+ARRTLeeway,2);
						ARRT.SetCollision(true,false,false);
						ARRT.Message=SmartResetMessage;
						ARRT.bTriggerOnceOnly=false;
					}
				}
				if (fSRFrequency <= 0)
					fSRFrequency = 0.5;
				
				if (bDebug) log(ShortAppString@"Setting timer at "$fSRFrequency$"s");
				
				SetTimer(fSRFrequency, true);
			}
			iaSDdelay = iSDdelay;
			TickRate = int(ConsoleCommand("get IpDrv.TcpNetDriver NetServerMaxTickRate"));
			SimCounter = 0;
			SaveConfig();
	    if (WaitTime == -1) // NetWait
			{
				if (DeathMatchPlus(Level.Game).Netwait > 0)
					WaitLeft = DeathMatchPlus(Level.Game).Netwait;
			}
			else
				WaitLeft = WaitTime;
			log(AppString@"initialization complete. (Strict mode = "$bStrictMode$").");
		} else {
			bProcessedEndGame = true;
			log(AppString@"running, but disabled (not AS gametype).");
		}
		Initialized=True;
	} else {
		if (!bEnabled) {
			bProcessedEndGame = true;
			log(AppString@"running, but disabled (bEnabled = false).");
			Initialized=True;
		}
	}
}

function Timer()
{
	local Pawn P;
	local Pawn Other;
	AtkCount = 0;

	if (bSuperDebug) // Respond SuperDebug logs less often.
		SlotCount++;
		
	for( Other=Level.PawnList; Other!=None; Other=Other.NextPawn ) {
		if (Other.isA('PlayerPawn')) {
			if(Other.PlayerReplicationInfo.Team==AttackingTeam) {
				AtkCount++;
			}
		}
	}

	if (bDebug) {
		if (AtkCount == 0) {
			bDebug = false;
			log(ShortAppString@"No attackers present, disabling Debug mode");
		}
	}
	

	if(Level.Game.CurrentID > NPID) // At least one new player has joined.
	{
		for( Other=Level.PawnList; Other!=None; Other=Other.NextPawn ) {
			if (Other.isA('PlayerPawn')) {
				if(Other.PlayerReplicationInfo.PlayerID == NPID) {
					break;
				}
			}
		}

		NPID++;
		// Make sure it is a player.
		if(Other != none && Other.bIsPlayer && Other.IsA('PlayerPawn') && !Other.PlayerReplicationInfo.bIsSpectator && !Other.PlayerReplicationInfo.bWaitingPlayer && !Other.PlayerReplicationInfo.bIsABot)
			AnnounceMapRecords(Other);
	}
	if ((iaSDdelay > 0) && (WorldStamp > Level.TimeSeconds+iaSDdelay))
	{
		if (!bRepeatSDDelay)
			iaSDdelay = 0;
		CheckSpawnResetTriggers();
	}
	else // no delay
		CheckSpawnResetTriggers();
		
	if (SlotCount>(iSDFrequency*(1/fSRFrequency)))
		SlotCount = 0;
}


function tick(float DeltaTime)
{
	local Pawn Other;
	local int i;
	local int SR;

	Super.Tick(DeltaTime);

  if (LeagueASGameReplicationInfo != None)
		SR =LeagueASGameReplicationInfo.StartTimeRemaining;
	else
		SR = -1;
	if (TimeLag == MapAvailableTime)
		WorldStamp = Level.TimeSeconds;	

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
			bProcessedEndGame = true;
			CheckNewRecord(TickCount,DeltaTime);
			SetGRIString();
		}		
	}
	
	if (bDebug==true)
	{
		if (Debugger != None)
		{
			Debugger.ClientMessage(ReturnTimeStr(-1,-1,-1,bFullTime));
		}
	}
}

function string ReturnTimeStr(int RemainingTime, int SavedTime, int TimeLimit, bool bShowFullTime)
{
	local int ConquerTime, Minutes, Seconds;
	local string TimeResult,strSubTime;
	local float SubTime, TickDiff;
	if (RemainingTime < 0) RemainingTime = Assault(Level.Game).RemainingTime;
	if (SavedTime < 0) SavedTime = Assault(Level.Game).SavedTime;
	if (TimeLimit < 0) TimeLimit = Assault(Level.Game).TimeLimit;
	
	if ( SavedTime > 0 )
 		ConquerTime = SavedTime - RemainingTime;
	else
		ConquerTime = TimeLimit * 60 - RemainingTime;

	Minutes = ConquerTime/60;

	if ( Minutes > 0 )
		TimeResult = string(Minutes)$":";
	else
		TimeResult = "0:";

	Seconds = ConquerTime % 60;

	if ( Seconds == 0 )
		TimeResult = TimeResult$"00";
	else if ( Seconds < 10 )
		TimeResult = TimeResult$"0"$Seconds;
	else
		TimeResult = TimeResult$Seconds;
	
	TickDiff = SimCounter;
	If (TimeLag == (Assault(Level.Game).TimeLimit*60))
		SubTime = 0;
	else {
		if (TickCount >= TickRate || bUseFloatAlways)
			SubTime = ((1/TickRate)*FloatCount);
		else
			SubTime = ((1/TickRate)*TickCount);
	}

	strSubTime = string(subTime);
	strSubTime = Right(strSubTime,Len(strSubTime)-(InStr(strSubTime,".")+1));
	if (iResolution > 0)
		strSubTime = Left(strSubTime,iResolution);

	if (bSuperDebug || bDebug || bShowFullTime)
		strSubTime = strSubTime@"(World:"$(Level.TimeSeconds-WorldStamp)$", TR:"$TickRate$")";
		
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
		else if (MutateString~="ar restart")
		{
					if (Level.TimeSeconds >= WaitLeft)
					{
						// Perform map restart
						RestartMap();
					}
					else
					{
						Sender.ClientMessage("* You must wait"@int(WaitLeft - Level.TimeSeconds)$" seconds before you can !restart the clock");
					}
		}
		else if (MutateString~="ar demo" || MutateString~="ar demorec")
		{
			if (bRequestDemoRec) {
				RequestDemo();
			}
			else
				Sender.ClientMessage("* Sorry! Server demo recording is not currently enabled.");
		}
		else if (MutateString~="ar reset")
		{
					if (Level.TimeSeconds >= WaitLeft)
					{
						// Perform clock and spawns reset - check if objectives can be respawned.
						ResetSpawns();
						if (ResetObjectives() == false)
							Sender.ClientMessage("* Warning: Objectives could not be reset, please use !restart or 'mutate ar restart' to reset objectives.");
						Sender.Died(None, 'Fell', Sender.Location);
						Level.Game.DiscardInventory(Sender);
						Level.Game.RestartPlayer(Sender);
						CheckSpawnResetTriggers();
						Sender.ClientMessage("* Reset attempted.");
					}
					else
						Sender.ClientMessage("* You must wait"@int(WaitLeft - Level.TimeSeconds)$" seconds before you can !reset the clock");
		}
		else if (Left(MutateString,11)~="ar setwait ")
		{
			if (Len(Right(MutateString,Len(MutateString)-11))>0)
				i = int(Right(MutateString,Len(MutateString)-11));
			else
				i = 4;
			if ((i > 13) || i < 2)
				i = 4;
				
			SaveConfig();
			Sender.ClientMessage(AppString@"- "@GT@" SpeedRun Mutator - set pre-map wait to "$i$"s.");
		}
		else if (MutateString~="ar go")
		{
			Sender.ClientMessage(AppString@"- "@GT@" SpeedRun Mutator - Sent an FMS request to LeagueAS...");
			LeagueAssault(Level.Game).PEFForceMatchStart();
		}
		else if (MutateString~="ar disable")
		{
			bEnabled = false;
			SaveConfig();
			Sender.ClientMessage(AppString@"- "@GT@" SpeedRun Mutator - will be disabled on next map start.");
		}
	} else {
		if(MutateString~="ar enable")
		{
			bEnabled = true;
			SaveConfig();
			Sender.ClientMessage(AppString@"- "@GT@" SpeedRun Mutator - will be enabled on next map start.");
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
			if(S~= "!reset") {
				Mutate("ar reset",PlayerPawn(Sender));
			}
			if(S~= "!start") {
				Mutate("ar go",PlayerPawn(Sender));
			}
			if(S~= "!go") {
				Mutate("ar go",PlayerPawn(Sender));
			}
			if((Left(S,9)~= "!setwait ") || (Left(S,9)~= "!netwait ")) {
				Mutate("ar setwait "$Right(S,Len(S)-9),PlayerPawn(Sender));
			}
			if(Left(S,6)~= "!wait ") {
				Mutate("ar setwait "$Right(S,Len(S)-6),PlayerPawn(Sender));
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

function CheckSpawnResetTriggers()
{
	local PlayerPawn P;
	local FortStandard F;
	local AR_RadiusTrigger ARRT;
	local LeagueAS_Inventory LASi;
	local int PCount, ACount, FSCount;
	local PlayerPawn RelevantPlayers[12];

	if (bStrictMode) {
		foreach AllActors(class'FortStandard', F)
		{
			FSCount++;
		}
		if (FSCount < ObjCount) {
			return;
		}
	}	

	foreach AllActors(class'AR_RadiusTrigger',ARRT)
	{
		ACount++;

		foreach ARRT.TouchingActors(class'PlayerPawn', P)
		{
			if (ARRT.IsRelevant(P))
			{
				PCount++;
				if (ResetSound != None) {
					if (int(Level.TimeSeconds) > lastSound+2) {
						P.ClientPlaySound(ResetSound,false, true);
					}
				}
			}
	  }
	}
	if (ResetSound != None)
		lastSound = Level.TimeSeconds;
	
	if (bSuperDebug && SlotCount>(iSDFrequency*(1/fSRFrequency))) {
		log(ShortAppString@"Counted "$ACount$" ARR Triggers");
		log(ShortAppString@"Counted "$PCount$"/"$AtkCount$" relevant players");
	}
	if (PCount >= AtkCount && ACount > 0)
	{
		foreach AllActors(class'LeagueAS_Inventory',LASi)
		{
			if (LASi.PlayerOwner != None) {
				if (TeamGamePlus(Level.Game).IsOnTeam(PlayerPawn(LASi.PlayerOwner), AttackingTeam)) {
					LASi.ActivateSpawnProtection();
				}
			}
		}
		RestartClock();
	}
}

function SetGRIString()
{
	local Pawn P;
	if (bGRPMethod==true) {
		for (P=Level.PawnList; P!=None; P=P.NextPawn)
		{
			if(		PlayerPawn(P) != None
				&&	P.PlayerReplicationInfo != None
				&&	NetConnection(PlayerPawn(P).Player) != None)
			{
				LeagueAS_GameReplicationInfo(PlayerPawn(P).GameReplicationInfo).GameEndedComments = GRIString@ReturnTimeStr(-1,-1,-1,bFullTime);
			}
		}
	} else {
		LeagueAS_GameReplicationInfo(Level.Game.GameReplicationInfo).GameEndedComments = GRIString@ReturnTimeStr(-1,-1,-1,bFullTime);
	}
}

function RestartMap()
{
	LeagueAssault(Level.Game).bDefenseSet = False;
	LeagueAssault(Level.Game).NumDefenses = 0;
	LeagueAssault(Level.Game).CurrentDefender = 0;
	LeagueAssault(Level.Game).SavedTime = 0.0;
	LeagueAssault(Level.Game).GameCode = "";
	LeagueAssault(Level.Game).Part = 1;
	LeagueAssault(Level.Game).bTiePartOne = False;
	LeagueAssault(Level.Game).SaveConfig();
	SaveConfig();
	Level.ServerTravel( "?Restart", false );
}

function RestartClock()
{
	Assault(Level.Game).RemainingTime = MapAvailableTime;
	SimCounter = 0;
	if (bStrictMode)
		WorldStamp = Level.TimeSeconds;
}

function ResetSpawns()
{
	local PlayerStart PS;
	foreach AllActors( class 'PlayerStart', PS) {
		if (String(PS.Tag) ~= FirstSpawnsTag || PS.Name == FirstSpawnsRef)	{
			PS.bEnabled = true;
		}
		else {
			if (PS.TeamNumber == 0)
				PS.bEnabled = false;
		}
	}
}

function bool ResetObjectives()
{
	// :hm: - think objectives are destroy()'d after completed, in which case a map soft restart would be needed?
	// alternatively could map out objectives in a seperate actor and respawn them?
	return true;
}

function SetFirstSpawns()
{
	local PlayerStart PS;
	local bool TagLogged;
	
	foreach AllActors( class 'PlayerStart', PS) {
		if (PS.bEnabled == true && PS.TeamNumber == 1) {
			if (TagLogged==false)
				FirstSpawnsTag = String(PS.Tag);
			TagLogged = true;
			FirstSpawnsRef = PS.Name;
		}
	}
}

function CheckSettings()
{
			if (DeathMatchPlus(Level.Game).Netwait != NetWait) {
				DeathMatchPlus(Level.Game).Netwait = NetWait;
				// DeathMatchPlus(Level.Game).SaveConfig();
			}
			MapAvailableTime = Assault(Level.Game).RemainingTime;
			if (LeagueAssault(Level.Game).bAttackOnly != bAttackOnly) {
				LeagueAssault(Level.Game).bAttackOnly = bAttackOnly;
			}

			if (bAutoDemoRec) {
				RequestDemo();
			}
}

function CheckRecords()
{
	local int i;
	local string S;
	local bool bFound;
	
	S = Left(Self, InStr(Self, "."));
	for (i = 0; i <= MaxRecords; i++) {
		if (RecordMaps[i]~=S && bFound==false)	{
			bFound = true;
			CurrentRecord = RecordTimes[i];
		}
		else if (RecordMaps[i]=="" && bFound==false) {
			RecordMaps[i] = S;
			RecordTimes[i] = MapAvailableTime;
			CurrentRecord = MapAvailableTime;
			bFound = true;
			SaveConfig();
		}
	}
}
function AnnounceMapRecords(Pawn P)
{
			PlayerPawn(P).ClientMessage("Record for"@Left(Self, InStr(Self, "."))@"on this server is currently set at:"@ReturnTimeStr(0,CurrentRecord,-1,false));
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

function CheckNewRecord(float TickCount, float DeltaTime)
{
	local int i, ConquerTime;
	local string S;
	local bool bFound;
	
	if ( Assault(Level.Game).SavedTime > 0 )
 		ConquerTime = Assault(Level.Game).SavedTime - Assault(Level.Game).RemainingTime;
	else
 		ConquerTime = Assault(Level.Game).TimeLimit * 60 - Assault(Level.Game).RemainingTime;
	
	if (CurrentRecord	> ConquerTime) {
		// We have a new record!
		CurrentRecord = ConquerTime;
		S = Left(Self, InStr(Self, "."));
		for (i = 0; i <= MaxRecords; i++) {
			if (RecordMaps[i]~=S && bFound==false)	{

				RecordTimes[i] = CurrentRecord;
				if (bRecording)
					RecordDemos[i] = LastDemoFileName;

				bFound = true;
				SaveConfig();
			}
			else if (RecordMaps[i]=="" && bFound==false) {
				RecordMaps[i] = S;
				RecordTimes[i] = CurrentRecord;

				if (bRecording)
					RecordDemos[i] = LastDemoFileName;
					
				bFound = true;
				SaveConfig();
			}
		}
	}
}

function AddMutator(Mutator M)
{
  if ( M.Class != Class )
    Super.AddMutator(M);
  else if ( M != Self )
    M.Destroy();
}


function String GetItemName( string FullName )
{
	local int i;
	if (Left(FullName,7)~="AR:GET:")
	{
		// Get top X records and shout back.
		FullName = "AR:Result";
	}
	return FullName;
}

//=================================================================//

defaultproperties
{
	AppString="AssaultRunner v1.0 by timo@utassault.net"
	GRIString="Map completed in:"
	ShortAppString="AssaultRunner:"
	bEnabled=true
	MaxRecords=40
	NetWait=5
	WaitTime=10
	bAttackOnly=true
	bAllowRestart=true
	bRequestDemoRec=true
	bAutoDemoRec=false
	bForceTournament=false
	LastDemoFileName=""
	bGRPMethod=false
	bUseFloatAlways=true
	bFullTime=true
	iResolution=2
	SmartResetMessage=""
	bUseSmartReset=true
	fSRFrequency=0.01
	iSDFrequency=1
	iSDdelay=6
	ARRTLeeway=20
	bStrictMode=true
	bRepeatSDDelay=false
	ResetSound=Sound'Botpack.Translocator.ReturnTarget'
}
//=================================================================//