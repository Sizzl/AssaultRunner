//==================================================================//
// AssaultRunner offline mutator - ©2009 timo@utassault.net         //
//                                                                  //
// Updated Jan 2021:                                                //
//  - See https://github.com/Sizzl/AssaultRunner for update history //
//                                                                  //
//==================================================================//

class ASARO expands Mutator config(AssaultRunner);

// AssaultRunner vars
var bool Initialized, bRecording, bProcessedEndGame, bSuperDebug, bGotWorldStamp, bIsModernClient, bLoggedCM, bIDDQD, bIDNoclip, bIDFly, bTurbo, bCheatsEnabled, bSpeedChanged, bJumpChanged, bIsRestarting, bTimerDriftDetected, bIncludeCustomForts;
var string AppString, ShortAppString, GRIFString, ExtraData, FortTimes[20], CRCInfo;
var int AttackingTeam, MapAvailableTime, TickCount, ObjCount, SimCounter, TimeLag, RemainingTime, ticks, ISCount, ISSlot, Drift, iTolerance, LastCRC;
var float SecondCount, FloatCount, WorldStamp, LifeStamp, fConquerTime, fConquerLife, ElapsedTime, TimerPreRate, TimerPostRate, InitSpeed, StartZ, StartWS, StartGS, StartAS;

var LeagueAS_GameReplicationInfo LeagueASGameReplicationInfo;
var PlayerPawn Debugger, ASAROPlayer;
var PlayerStart FirstOptPS,ChosenPS,InitialStarts[32];
var HUD ASAROHUD;

// Config
var() config bool bEnabled;
var() config bool bDebug;
var() config bool bMigrated;
var() config bool bAttackOnly;
var() config bool bAllowRestart;
var() config bool bAutoDemoRec;
var() config bool bAutoStorePlayerIntervals;
var() config bool bBroadcastIntervals;
var() config bool bFullTime;
var() config bool bGRPMethod;
var() config bool bHUDAlwaysVisible;
var() config bool bUseFloatAlways;
var() config bool bUseSmartReset;

var() config int iResolution;
var() config string GRIString;

var() config string LastDemoFileName;
var() config string SavedSpawn[254];
var() config int SavedSlot;
var() config string SpawnedIntervals[254];
var() config int SpawnedSlot;

event PreBeginPlay()
{
	local int TimeLimit;
	local FortStandard F;

	if (Owner != None && Owner.isA('ASARO'))
	{
		// Importing history from a newer version, temporarily disable full init
		bEnabled = false;
		MigrateConfig(true);
		Group = ''; // Flag to parent that it's safe for me to go
		Self.Destroy();
	}

	if(!Initialized && bEnabled)
	{
		if(Level.Game.IsA('LeagueAssault'))
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

			if (!bMigrated)
			{
				bMigrated=MigrateConfig();
				SaveConfig();
			}
			
			OptimisePlayerStarts();
			RestorePlayerIntervals();
			
			if (bIncludeCustomForts)
				AddCustomFortStandards();
			
			AttachFortStandards();
			xxCheckCRCs();
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
	local int i;
	local PlayerStart PS;
	local LeagueAS_HUD LASHUD;

	if (!bProcessedEndGame)
	{
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
	}
	else
	{
		// Continue to check CRCs after game has ended
		xxCheckCRCs(true);
	}
	if (!bGotWorldStamp && !bProcessedEndGame)
	{
		if (bAutoDemoRec && !bRecording)
			RequestDemo();

		if (LeagueAssault(Level.Game).bMapStarted) {
			WorldStamp = Level.TimeSeconds;
			LifeStamp = (Level.Hour * 60 * 60) + (Level.Minute * 60) + Level.Second + (Level.MilliSecond/1000);
			ElapsedTime = 0;
			if (bDebug)
				log("Captured level start timestamp as:"@WorldStamp$", reset ET:"@ElapsedTime,'ASARO');
			Tag='EndGame';
			bGotWorldStamp = true;
			InitSpeed = Level.TimeDilation;
			SetTimer(TimerPostRate,true);
			foreach AllActors(Class'PlayerStart',PS)
			{
				if (PS.bEnabled != true)
					PS.bHidden = true;
			}
		}
		else
		{
			if (ASAROPlayer == None || ASAROHUD == None)
			{
				// Unable to capture in postrender; HUD might be hidden
				foreach AllActors(Class'LeagueAS_HUD',LASHUD)
				{
					if (LASHUD.Owner.isA('PlayerPawn') && PlayerPawn(LASHUD.Owner).bIsPlayer && PlayerPawn(LASHUD.Owner).bIsHuman)
					{
						ASAROPlayer = PlayerPawn(LASHUD.Owner);
						if (ASAROHUD == None)
						{
							ASAROHUD = LASHUD;
						}
					}

				}

			}
			if (ASAROHUD != None && bHUDAlwaysVisible)
				ChallengeHUD(ASAROHUD).bHideHUD = false; // reset any hidden HUD to visible
		}
	}
	else
	{
		if (ASAROPlayer != None)
		{
			// Overwrite objective score lines
			if (LeagueASGameReplicationInfo != None)
			{
				for (i = 0; i < 20; i++)
				{
					if (Len(LeagueASGameReplicationInfo.FortName[i]) > 0 && Left(LeagueASGameReplicationInfo.FortCompleted[i],15) ~= "Completed! - By")
					{
						LeagueASGameReplicationInfo.FortCompleted[i] = "Completed @ "$FortTimes[i];
						if (bDebug)
							log("Overwriting scoreboard for objective "$LeagueASGameReplicationInfo.FortName[i]$"; completed at - "$FortTimes[i],'ASARO');
					}
				}
			}

			// Check for naughty boys and girls (and any other non-binary specific naughty humans, aliens, or animals who might have evolved to play this game)
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
			// Check for a scoreboard to overwrite
			if (ASAROPlayer.Scoring != None) {

				if (bLoggedCM || bIDNoclip || bIDDQD || bIDFly || bTurbo || bSpeedChanged || bJumpChanged || bTimerDriftDetected)
				{
					ExtraData = " | Detected:";
					if (bTimerDriftDetected)
						ExtraData = ExtraData@"Timer drift [up to "$Drift$"s];";
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
					TournamentScoreBoard(ASAROPlayer.Scoring).GreenColor.R = 255;
					TournamentScoreBoard(ASAROPlayer.Scoring).GreenColor.G = 255;
					TournamentScoreBoard(ASAROPlayer.Scoring).GreenColor.B = 255;
				}
				TournamentScoreBoard(ASAROPlayer.Scoring).Ended = AppString;
				fLT = fConquerLife / (Assault(Level.Game).GameSpeed * Level.TimeDilation);
				DataString = "[L:"$GDP(string(fLT),3)@"| E:"$GDP(string(ElapsedTime),0)@"| G:"$GDP(string(Assault(Level.Game).GameSpeed),2)@"| D:"$GDP(string(Level.TimeDilation),2)@"| A:"$GDP(string(Assault(Level.Game).AirControl),2)$ExtraData$"]";
				TournamentScoreBoard(ASAROPlayer.Scoring).Continue = DataString@CRCInfo;
				if (bProcessedEndGame)
					SetTimer(1.0,true);
				else
					SetTimer(TimerPostRate,true);
			}
		}
	}

}

simulated function Tick(float DeltaTime)
{
	local int SR;
	
	if ( !bHUDMutator && Level.NetMode != NM_DedicatedServer && Owner == None ) // Don't register if spawned from a newer version
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

	RemainingTime = Assault(Level.Game).RemainingTime;
	if (bGotWorldStamp)
	{
		Drift = ElapsedTime - (MapAvailableTime-RemainingTime);
		if (Drift > iTolerance)
			bTimerDriftDetected = true;
	}
	if (bDebug==true && !bGotWorldStamp)
	{
		if (Debugger != None)
		{
			Debugger.ClientMessage(ReturnTimeStr(!bProcessedEndGame,false,bFullTime,false));
		}
	}
}
//simulated event Actor (UT) SpawnNotification(Actor (UT) A) 

simulated function PostRender(canvas Canvas)
{
	local GameReplicationInfo GRI;
	local float XL, YL;
	local int cLine;
	local bool bIsC;
	//local font CanvasFont; // TO-DO, font-scaling
	
	if (ASAROPlayer == None)
	{
		ASAROPlayer = Canvas.Viewport.Actor;
		if ( ASAROPlayer != None )
		{
			if (Level.Game.isA('LeagueAssault'))
				LeagueASGameReplicationInfo = LeagueAS_GameReplicationInfo(ASAROPlayer.GameReplicationInfo);
		}
	}
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
			Canvas.DrawText(ReturnTimeStr(!bProcessedEndGame,false,bDebug,false));
			cLine = 2;
			if (bTimerDriftDetected && !bIsRestarting)
			{
				Canvas.DrawColor.R = 255;
				Canvas.DrawColor.G = 30;
				Canvas.DrawColor.B = 30;
				Canvas.SetPos(0, cLine * YL);	
				Canvas.DrawText("Timer drift detected! It is now recommended to restart this run (mutate ar restart).");
				cLine++;
			}
			if (bSuperDebug)
			{
				Canvas.DrawColor.R = 255;
				Canvas.DrawColor.G = 255;
				Canvas.DrawColor.B = 255;
				Canvas.SetPos(0, cLine * YL);
				Canvas.DrawText("Elapsed Time:"@(MapAvailableTime-RemainingTime)$"s [Remaining:"@RemainingTime$"s; Limit:"@MapAvailableTime$"s], Time Lag:"@TimeLag$", Drift:"@Drift);
				cLine++;
				Canvas.SetPos(0, cLine * YL);
				Canvas.DrawText("CRC Data:"@CRCInfo);
				//Canvas.DrawText("Online Tick:"@TickCount$", Float:"@FloatCount$", CQ Time:"$string(fConquerTime)$", CL Time:"@string(fConquerLife));
				cLine++;
				Canvas.SetPos(0, cLine * YL);
				Canvas.DrawText("Real-world sampling:"@ReturnTimeStr(!bProcessedEndGame,true,false,true)); // real times, ignoring extra debug info
				cLine++;
				if (ExtraData != "")
				{
					Canvas.SetPos(0, cLine * YL);
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
	local int i;
	local string CapturedTime;
	local Actor A;
	if (bDebug)
		log("Incoming trigger for "@Other.Name$", via"@EventInstigator.Name,'ASARO');
	if (Other.IsA('Assault'))
	{
		LogGameEnd();
	}
	else if (Other.IsA('IntervalTrigger'))
	{
		// Hooked triggers for interval time recording	
		if (EventInstigator.isA('PlayerPawn'))
		{
			CapturedTime = ReturnTimeStr(!bProcessedEndGame,false,bDebug,true);
			if (bBroadcastIntervals)
			{
				foreach AllActors( class 'Actor', A, 'ASAROSEHandler' )
				{
					SpecialEvent(A).Message = "Interval captured:"@CapturedTime;
					A.Trigger( Other, Other.Instigator );
				}
			}
			else
			{
				EventInstigator.ClientMessage("Interval captured:"@CapturedTime);
			}
		}
	}
	else if (Other.IsA('FortStandard'))
	{
		// Hooked objectives for interval time recording
		if (EventInstigator.isA('PlayerPawn') && Level.Game.isA('LeagueAssault'))
		{
			LeagueASGameReplicationInfo = LeagueAS_GameReplicationInfo(PlayerPawn(EventInstigator).GameReplicationInfo);
			if (LeagueASGameReplicationInfo != None)
			{
				for (i = 0; i < 20; i++)
				{
					if (LeagueASGameReplicationInfo.FortName[i] == string(Other.Name) || LeagueASGameReplicationInfo.FortName[i] == FortStandard(Other).FortName)
					{
						FortTimes[i] = ReturnTimeStr(!bProcessedEndGame,false,bDebug,true);
						LeagueASGameReplicationInfo.FortCompleted[i] = "Completed @ "$FortTimes[i];
						if (bDebug)
							log("Objective "$Other.Name$" completed - "$FortTimes[i],'ASARO');
					}
				}
			}
		}
	}
}

function bool MigrateConfig(optional bool bIsChild, optional bool bAllPrevious)
{
	// Migrates config from older ASARO builds into current version, supported from 1j onwards
	local class<Mutator> C, CL;
	local bool bIgnore;
	local actor A;
	local Mutator M;
	local int i, j, LastSlot, StartVersion;
	local string LastPackage, Package, CurrentMinorVersion, CurrentMajorVersion, MapName, Command;
	local string SpawnHistory[254], IntervalHistory[254];

	Package = Left(string(self.class), InStr(string(self.class), ".")-1);
	CurrentMinorVersion = Right(Left(string(self.class), InStr(string(self.class), ".")),1);
	CurrentMajorVersion = Right(Package,1);

	if (bIsChild)
	{
		log("Running config migration [Child:"$bIsChild$"]",'ASARO');
		// Perform the actual migrations from the child objects into the parent object.
		if (Owner != None && Owner.IsA('ASARO'))
		{
			log("Merging in configuration from "$Self.Class$" to "$Owner.Class,'ASARO');
			if (ASARO(Owner) != None)
			{	
				// Expand this area where needed.
				ASARO(Owner).bDebug = bDebug;
				ASARO(Owner).bAutoDemoRec = bAutoDemoRec;
				ASARO(Owner).bHUDAlwaysVisible = bHUDAlwaysVisible;
				ASARO(Owner).bIncludeCustomForts = bIncludeCustomForts;
				ASARO(Owner).bBroadcastIntervals = bBroadcastIntervals;

				for (i = 0; i < 254; i++)
				{
					LastSlot = -1;
					if (Len(SavedSpawn[i]) > 0)
					{
						// Check owner config
						bIgnore = false;
						MapName = Left(SavedSpawn[i], InStr(SavedSpawn[i], ",")); // including comma

						for (j = 0; j < 254; j++)
						{
							if (Len(ASARO(Owner).SavedSpawn[j]) > 0 && Left(ASARO(Owner).SavedSpawn[j],Len(MapName)) ~= MapName)
							{
								bIgnore = true;
								LastSlot = j;
							}
						}

						if (!bIgnore) 
						{
							// Save into parent config
							ASARO(Owner).SavedSpawn[ASARO(Owner).SavedSlot] = SavedSpawn[i];
							ASARO(Owner).SavedSlot = ASARO(Owner).SavedSlot+1;
						}
						else if (LastSlot > -1)
						{
							// Save into parent config, overwriting existing entry
							ASARO(Owner).SavedSpawn[LastSlot] = SavedSpawn[i];
						}
					}
					if (Len(SpawnedIntervals[i]) > 0)
					{
						// Check owner config
						bIgnore = false;
						MapName = Left(SpawnedIntervals[i], InStr(SpawnedIntervals[i], ",")); // including comma
						/*
						// Too complicated to check the existing custom flags, just bring them in
						for (j = 0; j < 254; j++)
						{
							if (Len(ASARO(Owner).SpawnedIntervals[j]) > 0 && Left(ASARO(Owner).SpawnedIntervals[j],Len(MapName)) ~= MapName)
							{
								bIgnore = true;
							}
						}
						*/
						if (!bIgnore)
						{
							// Save into parent config
							ASARO(Owner).SpawnedIntervals[ASARO(Owner).SavedSlot] = SpawnedIntervals[i];
							ASARO(Owner).SpawnedSlot = ASARO(Owner).SpawnedSlot+1;
						}
					}
				}
				ASARO(Owner).SaveConfig();
			} // Owner check
			else
			{
				log("Failed to cast owner object for config transfer. Utilising console intead.",'ASARO');
		
				ConsoleCommand("set "$Owner.Class$" bDebug "$bDebug);
				ConsoleCommand("set "$Owner.Class$" bAutoDemoRec "$bAutoDemoRec);
				ConsoleCommand("set "$Owner.Class$" bHUDAlwaysVisible "$bHUDAlwaysVisible);
				ConsoleCommand("set "$Owner.Class$" bIncludeCustomForts "$bIncludeCustomForts);
				ConsoleCommand("set "$Owner.Class$" bBroadcastIntervals "$bBroadcastIntervals);

				for (i = 0; i < 254; i++)
				{
					LastSlot = -1;
					if (Len(SavedSpawn[i]) > 0)
					{
						// Check owner config
						bIgnore = false;
						MapName = Left(SavedSpawn[i], InStr(SavedSpawn[i], ",")); // including comma

						for (j = 0; j < 254; j++)
						{
							Command = ConsoleCommand("get "$Owner.Class$" SavedSpawn "$j);
							if (Len(Command) > 0 && Left(Command,Len(MapName)) ~= MapName)
							{
								bIgnore = true;
								LastSlot = j;
							}
						}

						if (!bIgnore) 
						{
							Command = ConsoleCommand("get "$Owner.Class$" SavedSlot");
							// Save into parent config and increase savedslot
							ConsoleCommand("set "$Owner.Class$" SavedSpawn "$int(Command)@SavedSpawn[i]);
							ConsoleCommand("set "$Owner.Class$" SavedSlot "$(int(Command)+1));
						}
						else if (LastSlot > -1)
						{
							// Save into parent config, overwriting existing entry
							ConsoleCommand("set "$Owner.Class$" SavedSpawn "$LastSlot@SavedSpawn[i]);
						}
					}
					if (Len(SpawnedIntervals[i]) > 0)
					{
						// Check owner config
						bIgnore = false;
						MapName = Left(SpawnedIntervals[i], InStr(SpawnedIntervals[i], ",")); // including comma

						if (!bIgnore)
						{
							Command = ConsoleCommand("get "$Owner.Class$" SpawnedSlot");
							// Save into parent config and increase savedslot
							ConsoleCommand("set "$Owner.Class$" SpawnedIntervals "$int(Command)@SpawnedIntervals[i]);
							ConsoleCommand("set "$Owner.Class$" SpawnedSlot "$(int(Command)+1));
						}
					}
				}
			}
		}
	}
	else
	{
		if (Package ~= "ASARO1j" && !bDebug)
		{
			log("Config migration will only work for future versions; abandoning for now.",'ASARO');	
			return true;
		}
		log("Begin config migration [Parent]",'ASARO');
		LastSlot = -1;

		if (Asc(CurrentMinorVersion) > 47 && Asc(CurrentMinorVersion) < 58)
		{
			// Actually a Major version, return to previous major version
			CurrentMajorVersion = string((int(CurrentMinorVersion)-1));
			CurrentMinorVersion = "{"; // next from 'z'
			Package = Package$CurrentMajorVersion;
		}
		else if (CurrentMinorVersion ~= "a")
		{
			// Go back to previous major version
			// TO-DO: also include current major x.0 release
			CurrentMajorVersion = string((int(CurrentMajorVersion)-1));
			CurrentMinorVersion = "{"; // next from 'z'
			Package = Left(Package,Len(Package)-1)$CurrentMajorVersion;
		}

		if (int(CurrentMajorVersion) == 1) 
			StartVersion = 106; // Start from version 'j'
		else
			StartVersion = 97; // start from version 'a'


		if (!bAllPrevious)
		{
			// Check what packages are good then pick the last one available and start from there
			log("Attempting to load:"@Package,'ASARO');
			CL = class<Mutator>(DynamicLoadObject(Package$".ASARO",class'class')); // check naked x.0 release (e.g. v2)
			if (CL != None)
				LastPackage = Package;
			
			log("Attemting to find previous versions '"$CurrentMajorVersion$Chr(StartVersion)$"' through "$CurrentMajorVersion$CurrentMinorVersion,'ASARO');
			
			for (i = StartVersion; i < Asc(CurrentMinorVersion); i++)
			{
				log("Attempting to load:"@Package$Chr(i),'ASARO');
				CL = class<Mutator>(DynamicLoadObject(Package$Chr(i)$".ASARO",class'class'));
				if (CL != None)
				{
					LastPackage = Package;
					StartVersion = i;
				}
			}
			if (LastPackage == "")
			{
				log("No previous package to import from; use 'mutate ar import' to force a search for older versions",'ASARO');
				// Nothing to import from
				return true;
			}
		}

		log("Attemting to import package history for "$Package$", versions '"$CurrentMajorVersion$Chr(StartVersion)$"' through "$CurrentMajorVersion$CurrentMinorVersion,'ASARO');

		for (i = 0; i < 254; i++)
		{
			// Grab latest version's existing records (if performing a manual import); these then won't be overwritten by the previous generations
			if (Len(SpawnedIntervals[i]) > 0)
			{
				IntervalHistory[i]	= SpawnedIntervals[i];
			}
			if (Len(SavedSpawn[i]) > 0)
			{
				SpawnHistory[i]	= SavedSpawn[i];
			}
		}

		for (i = StartVersion; i < Asc(CurrentMinorVersion); i++)
		{
			// Spawn older versions of this mutator and grab old config

			if (bDebug)
				log("- "$Package$Chr(i),'ASARO');

			C = class<Mutator>(DynamicLoadObject(Package$Chr(i)$".ASARO",class'class'));

			if (C != None)		
			{
				M = Spawn(C,Self);
				while (M != None && M.Group == 'ASARO')
				{
					// wait (consider timeout)
				}
				log("Completed config import from "$Package$Chr(i)$" ("$A$")",'ASARO');
				if (M != None)
					M.Destroy();
			}
			else
			{
				log("Failed to spawn class.",'ASARO');
			}
		}
		// Replay prior-existing history back into config
		for (i = 0; i< 254; i++)
		{
			if (Len(SpawnHistory[i]) > 0)
			{
				MapName = Left(SpawnHistory[i], InStr(SpawnHistory[i], ",")); // including comma
				for (j = 0; j < 254; j++)
				{
					bIgnore = false;
					if (Len(SavedSpawn[j]) > 0 && Left(SavedSpawn[j],Len(MapName)) ~= MapName)
					{
						bIgnore = true;
						SavedSpawn[j] = SpawnHistory[i];
					}
				}
				if (!bIgnore)
				{
					SavedSpawn[SavedSlot] = SpawnHistory[i];
					SavedSlot++;
				}
			}
		}
		SaveConfig();
	}
	log("Config migration complete.",'ASARO');
	return true;
}

function SpawnPlayerInterval(vector Location)
{
	local IntervalTrigger IT;
	local SpecialEvent SE, Handler;

	// Check for valid SE handler, spawn if needed.
	foreach AllActors(Class'SpecialEvent', Handler,'ASAROSEHandler')
	{
		SE = Handler;
	}
	if (SE == None)
	{
		if (bDebug)
			log("Spawning special event handler.",'ASARO');

		SE = Spawn(class'Engine.SpecialEvent',Self, , Location);
		if (SE != None)
		{
			SE.bBroadcast = bBroadcastIntervals;
			SE.Tag = 'ASAROSEHandler';
		}
	}
	
	if (bDebug)
		log("Spawning interval timer at"@string(Location),'ASARO');

	IT = Spawn(class'IntervalTrigger',Self, , Location);
	if (IT != None)
	{
		IT.bHidden = false;
		IT.bBroadcast = bBroadcastIntervals;
		if (SE != None)
			IT.SpecialEventHook = SE;

		if (bBroadcastIntervals)
			IT.Event = 'ASAROSEHandler';

		IT.bDebug = bDebug;
	}
}

function ReorderSavedPlayerIntervals()
{
	local int i, j;
	local string SPIs[254];
 	
 	SpawnedSlot = 0;

	for (i = 0; i < 254; i++)
	{
		if (Len(SpawnedIntervals[i]) > 0)
		{
			SPIs[j] = SpawnedIntervals[i];
			j++;
		}
	}
	for (i = 0; i < 254; i++)
	{
		if (Len(SPIs[i]) > 0)
		{
			SpawnedIntervals[i] = SPIs[i];
			SpawnedSlot = i+1;
		}
		else
		{
			SpawnedIntervals[i] = "";
		}
	}
}

function ClearPlayerIntervals(bool bDestroyCurrent)
{
	local string MapName;
	local int i;
	local IntervalTrigger IT;

	MapName = Left(Self, InStr(Self, "."));
	if (bDestroyCurrent)
	{
		foreach AllActors(Class'IntervalTrigger', IT)
		{
			IT.Event = '';
			IT.bHidden = true;
			IT.SetCollision(false,false,false);
			IT.Destroy();
		}
	}
	for (i = 0; i < SpawnedSlot; i++)
	{
		if (Left(SpawnedIntervals[i],(Len(MapName)+1)) ~= (MapName$",") || Left(SpawnedIntervals[i],(Len(MapName)+1)) ~= (MapName$";"))
		{
			if (bDebug)
				log("Clearing saved intervals in slot"@i,'ASARO');
			SpawnedIntervals[i] = "";
		}
	}
	ReorderSavedPlayerIntervals();
}

function StorePlayerIntervals()
{
	local string MapName, AllIntervalVects, StoredVect;
	local string IntervalVects[16];
	local int i, j, IVLength, SpawnedCounter;
	local bool bIsStored;
	local IntervalTrigger IT;
	// Save the last 64 intervals only (4 INI entries per map)
	
	ClearPlayerIntervals(false); // Clear out INI entries and re-save

	MapName = Left(Self, InStr(Self, "."));
	foreach AllActors(Class'IntervalTrigger', IT)
	{
		SpawnedCounter++;
		StoredVect = string(IT.Location);
		bIsStored = false;

		for (i = 0; i < SpawnedSlot; i++)
		{
			IVLength = -1;
			if (Left(SpawnedIntervals[i],(Len(MapName)+1)) ~= (MapName$","))
			{
				AllIntervalVects = Mid(SpawnedIntervals[i],Len(MapName)+1);
				for (j = 0; j < 16; j++)
				{
					IntervalVects[j] = "";
				}

				ParseToArray(AllIntervalVects,";",IntervalVects);
				
				for (j = 0; j < 16; j++)
				{
					if (Len(IntervalVects[j]) > 4)
					{
						if (IVLength == -1)
							IVLength = 0;
						IVLength++;
					}

				}
				if (IVLength < 16)
				{
					// Append to existing entry
					if (bDebug)
						log("Appending interval location #"$SpawnedCounter$" to existing saved entry at slot"@i$"; used places in this slot:"@IVLength,'ASARO');
					SpawnedIntervals[i] = SpawnedIntervals[i]$StoredVect$";";
					bIsStored = true;
					IVLength++;
					//SpawnedIntervals[i] = SpawnedIntervals[i]$";"$StoredVect$";";
				}
				else
				{
					if (bSuperDebug)
						log("Slot"@i@"is full ("$IVLength$"), waiting for next available slot...",'ASARO');
				}
			}
		}
		if (!bIsStored)
		{
			// New entry
			if (bDebug)
				log("Creating interval location #"$SpawnedCounter$" entry at slot"@SpawnedSlot,'ASARO');
			SpawnedIntervals[SpawnedSlot] = MapName$","$StoredVect$";";
			SpawnedSlot++;
			IVLength = 1;
			bIsStored = true;
		}
	}
	ReorderSavedPlayerIntervals();
	SaveConfig();
}

function RestorePlayerIntervals()
{
	local string AllIntervalVects;
	local vector ValidVector;
	local string IntervalVects[16]; // only hold a limited number of these per entry to keep string length down
	local string MapName;
	local int i, j;

	MapName = Left(Self, InStr(Self, "."));
	if (bDebug)
		log("Restoring Player Spawned Interval Timers",'ASARO');
	
	// Check for custom Interval triggers and restore 
	// e.g. SpawnedIntervals[0]=AS-Bridge,0.000000,0.000000,0.000000;0.000000,0.000000,0.000000;0.000000,0.000000,0.000000;0.000000,0.000000,0.000000;

	for (i = 0; i < SpawnedSlot; i++)
	{
	
		if (Left(SpawnedIntervals[i],(Len(MapName)+1)) ~= (MapName$","))
		{
			if (bDebug)
				log("Found interval timers for"@MapName,'ASARO');

			// Split vects and restore triggers
			AllIntervalVects = Mid(SpawnedIntervals[i],Len(MapName)+1);
			for (j = 0; j < 16; j++)
			{
				IntervalVects[j] = "";
			}

			ParseToArray(AllIntervalVects,";",IntervalVects);

			for (j = 0; j < 16; j++)
			{
				if (Len(IntervalVects[j]) > 0)
				{
					ValidVector = vector(IntervalVects[j]);
					if (bDebug)
						log("Interval vector found:"@IntervalVects[j]@"->"@string(ValidVector),'ASARO');
					
					if (ValidVector != vect(0,0,0))
						SpawnPlayerInterval(ValidVector);
				}
			}

		}
	}
	log("Completed Restoring Player Spawned Interval Timers",'ASARO');

}

function AddCustomFortStandards()
{
	// Attach custom objectives for better interval tracking
	local FortStandard F;
	local string MapName;

	MapName = Left(Self, InStr(Self, "."));
	if (Left(MapName,10)~="AS-AutoRIP")
	{

	}
	else if (Left(MapName,9)~="AS-Bridge")
	{

	}
	else if (Left(MapName,10)~="AS-Guardia")
	{

	}
	else if (Left(MapName,12)~="AS-TheScarab")
	{
		F = Spawn(class'FortStandard',Self, , vect(2140,-4880,-3433));
		if (F != None)
		{
			F.SetCollisionSize(150,80);
			F.FortName = "[SR] Sniper Nest";
			F.DestroyedMessage = "was breached.";
			F.bForceRadius = true;
			F.bTriggerOnly = true;
			F.Tag = 'custom1SniperNest';
		}
	}
}

function AttachFortStandards()
{
	// Attach a trigger variant to the fortstandards to call back to this mutator for time tracking in GRI
	local FortStandard F;
	local Counter C;

	foreach AllActors(Class'FortStandard',F)
	{
		C = Spawn( Class'Engine.Counter', F, , F.Location );
		if (bDebug)
			log("Spawned objective counter hook"@C.Name@"for"@F.Name@"("$F.FortName$"), using event handler '"$F.Event$"'",'ASARO');
		if (F.Event == '')
		{
			F.Event=GenerateFortEvent(F);
			if (bDebug)
				log(F.Name@" required a new Event handler, provided it with:"@F.Event,'ASARO');
		}
		C.Tag = F.Event;
		C.NumToCount = 1;
		C.bShowMessage = bDebug;
		C.CompleteMessage = "Hooked objective triggering ASARO logging.";
		C.bHidden = true;
		C.SetPhysics( PHYS_None );
		C.SetCollision( false, false, false );
		C.SetCollisionSize(0,0);
		C.Event = 'EndGame';
		
	}
 }

function OptimisePlayerStarts()
{

	local PlayerStart PS,ActivePS,NearestPSToFort,NextPS;
	local FortStandard NearestFort;
	local string MapName, SavedPS;
	local int i;

	MapName = Left(Self, InStr(Self, "."));

	// Disable known-bad, or badly placed playerstarts
	foreach AllActors(Class'PlayerStart',PS)
	{
		if (Left(MapName,9)~="AS-Bridge")
		{
			if( PS.Name == 'PlayerStart7' || PS.Name == 'PlayerStart8' || PS.Name == 'PlayerStart9' || PS.Name == 'PlayerStart21' || PS.Name == 'PlayerStart24' || PS.Name == 'PlayerStart30')
			{
				DisablePlayerStart(PS,false,false);
			}
		}
	}
	// Determine active attacker playerstarts
	foreach AllActors(Class'PlayerStart',PS)
	{
		if (PS.TeamNumber==1 && PS.bEnabled)
		{
			InitialStarts[ISCount] = PS;
			ISCount++;
			ActivePS = PS;
		}
	}
	if (ActivePS != None)
	{
		// Find nearest fort first
		NearestFort = NearestObj(ActivePS);
		if (NearestFort != None)
		{
			if (bDebug)
				log("Found closest objective to active PlayerStart:"@NearestFort.Name,'ASARO');
			// Now find the nearest active playerstart for this fort and disable the others
			NearestPSToFort = NearestPlayerStart(NearestFort,true,ActivePS.TeamNumber,ActivePS.Tag);
			if (NearestPSToFort != None)
			{
				FirstOptPS = NearestPSToFort; // Log this for later
				ChosenPS = NearestPSToFort; // Log this for later
				HighlightPlayerStart(NearestPSToFort,true);
				if (bDebug)
					log("Found closest PlayerStart to "@NearestFort.Name$":"@NearestPSToFort.Name,'ASARO');
				foreach AllActors(Class'PlayerStart',PS)
				{
					if (PS.TeamNumber==1 && PS.bEnabled)
					{
						if (PS.Name != NearestPSToFort.Name)
							DisablePlayerStart(PS,true,true);
						else
							if (bDebug)
								log("The most optimal PlayerStart to the closest objective is being used:"@PS.Name,'ASARO');	
					}
				}
			}
			else
			{
				if (bDebug)
					log("Could not find closest PlayerStart to FortStandard:"@NearestFort.Name,'ASARO');
			}
		}
	}
    // Check for a Saved PS and restore selection
	for (i = 0; i < SavedSlot; i++)
	{
		if (Left(SavedSpawn[i],(Len(MapName)+1)) ~= (MapName$","))
		{
			SavedPS = Mid(SavedSpawn[i],(Len(MapName)+1));
			if (string(ChosenPS.Name) != SavedPS)
			{
				NextPS = None;
				if (bDebug)
					log("Using Saved PlayerStart details:"@SavedPS,'ASARO');
				foreach AllActors(Class'PlayerStart',PS)
				{
					if (PS.TeamNumber==1 && PS.Tag=='ASAROSelectablePlayerStart' && string(PS.Name) == SavedPS)
					{
						NextPS = PS;
					}
				}
				if (NextPS != None)
				{
					if (bDebug)
						log("Preparing to switch to Saved PlayerStart:"@NextPS.Name,'ASARO');
					NextPS.Tag = ChosenPS.Tag;
					NextPS.bEnabled = true;
					HighlightPlayerStart(NextPS,true);
					DisablePlayerStart(ChosenPS,true,true);
					ChosenPS.Tag = 'ASAROSelectablePlayerStart';
					if (ASAROPlayer != None)
					{
						ASAROPlayer.SetLocation(NextPS.Location);
					}
					ChosenPS = NextPS;
					if (bDebug)
						log("Switched to Saved PlayerStart:"@ChosenPS.Name,'ASARO');
				}
			
			}
		}
	}

	// Repeat for inactive PlayerStarts, grouped by tag
	if (bDebug)
		log("Optimising future PlayerStarts (other than "$ChosenPS.Name$")...",'ASARO');
	foreach AllActors(Class'PlayerStart',PS)
	{
		if (PS.Name != ChosenPS.Name)
		{
			if (PS.TeamNumber==1 && !(PS.bEnabled) && PS.Tag != 'SlowAssPlayerStart' && PS.Tag != 'ASAROSelectablePlayerStart' && PS.Tag != '' && PS.Name != ChosenPS.Name)
			{
				ActivePS = PS;
				NearestFort = NearestObj(ActivePS);
				if (NearestFort != None)
				{
					if (bDebug) log("Found closest objective to inactive PlayerStart ("$ActivePS.Name$"):"@NearestFort.Name,'ASARO');
					NearestPSToFort = NearestPlayerStart(NearestFort,false,ActivePS.TeamNumber,ActivePS.Tag);
					foreach AllActors(Class'PlayerStart',PS,ActivePS.Tag)
					{
						if (PS.Name != ChosenPS.Name)
						{
							if (PS.Name != NearestPSToFort.Name)
							{
								DisablePlayerStart(PS,false,true);
							}
							else
							{
								if (bDebug)
									log("The most optimal future PlayerStart to the closest objective ("$NearestFort.Name$") is being used:"@PS.Name,'ASARO');	
							}
						}
						else
						{
							 if (bDebug)
								log("Ignoring primary spawn point ("$NearestFort.Name$")."@PS.Name,'ASARO');	
						}
					}
				}
			}
		}
		else
		{
			if (bDebug)
				log("Ignoring primary spawn point ("$NearestFort.Name$")."@PS.Name,'ASARO');	
		}
	}



}

function HighlightPlayerStart(PlayerStart PS,bool bEnabled)
{
	if (bEnabled)
		PS.Style = STY_Translucent;
	else
		PS.Style = STY_Modulated;
	
	PS.DrawType = DT_Mesh;
	PS.Mesh = Mesh'Botpack.PylonM';
	PS.DrawScale = 2.5;
	PS.bMeshEnviroMap = true;
	PS.bHidden = false;
}

function DisablePlayerStart (PlayerStart PS, bool bInitial, bool bOptimising)
{
	if (PS != None)
	{
		if (bInitial)
		{
			PS.Tag = 'ASAROSelectablePlayerStart';
			HighlightPlayerStart(PS,false);
		}
		else
			PS.Tag = 'SlowAssPlayerStart';

		PS.bEnabled = false;
		if (bDebug)
		{
			if (bOptimising)
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

function PlayerStart NearestPlayerStart (Actor A, bool bActiveOnly, int TeamNumber, name Tag)
{
	local float DistToNearestPS,ThisPSDist;
	local PlayerStart PS,NearestPS;

	DistToNearestPS = 0.0;
	foreach AllActors(Class'PlayerStart', PS, Tag)
	{
		if (PS.TeamNumber == TeamNumber)
		{
			if ((bActiveOnly && PS.bEnabled) || !bActiveOnly)
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
	local string MapName;
	MapName = Left(Self, InStr(Self, "."));
	MapName = Caps(Left(MapName,4))$Mid(MapName,4);

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
					PlayerPawn(P).GameReplicationInfo.GameEndedComments = MapName@GRIString@ReturnTimeStr(false,false,bFullTime,false);
			}
		}
	} else {
		if (!Assault(Level.Game).bAssaultWon)
			LeagueAS_GameReplicationInfo(Level.Game.GameReplicationInfo).GameEndedComments = GRIFString;
		else
			LeagueAS_GameReplicationInfo(Level.Game.GameReplicationInfo).GameEndedComments = MapName@GRIString@ReturnTimeStr(false,false,bFullTime,false);
	}

	bProcessedEndGame = true;
	SetTimer(0.05,true);
}

function string ReturnTimeStr(bool bLiveTimer, bool bRealTime, bool bShowFullTime, bool bIgnoreDebug)
{
	local int Minutes, Seconds;
	local string TimeResult,strSubTime, DataString;
	local float SubTime, ConquerTime, ConquerLife, fLT;

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

	if (!bIgnoreDebug && (bDebug || bSuperDebug)) {
		DataString = " [L:"$GDP(string(fLT),3);
		DataString = DataString$"|E:"$GDP(string(ElapsedTime),0);
		DataString = DataString$"|G:"$GDP(string(Assault(Level.Game).GameSpeed),2);
		DataString = DataString$"|D:"$GDP(string(Level.TimeDilation),2);
		DataString = DataString$"]";
	}
	else
		DataString = "";
		
	if (!bIgnoreDebug && (bSuperDebug || bDebug || bShowFullTime))
		strSubTime = strSubTime@"(Non-dilated:"$(ConquerTime)$DataString$")";
		
	TimeResult = TimeResult$"."$strSubTime;
	return TimeResult;
}


function Mutate(string MutateString, PlayerPawn Sender)
{
	local int i;
	local string GT, MapName;
	local PlayerStart PS,ActivePS,NextPS;
	local IntervalTrigger IT;
	local bool bSaved;

	GT=Level.Game.MapPrefix;
	MapName = Left(Self, InStr(Self, "."));
	MapName = Caps(Left(MapName,4))$Mid(MapName,4);

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
		else if (Left(MutateString,7) ~= "ar ini")
		{
			Sender.ClientMessage("Migrating config from all previous versions...");
			MigrateConfig(true);
			SaveConfig();
		}
		else if (Left(MutateString,7) ~= "ar init")
		{
			if (Len(CRCInfo) > 0) {
				Sender.ClientMessage("Current CRC info:");
				Sender.ClientMessage(""@CRCInfo);
			}
			Sender.ClientMessage("Using HP to calculate CRC data. Check log.");
			xxCheckCRCs(false);
		}
		else if (MutateString~="ar check" || Left(MutateString,6) ~= "ar crc")
		{
			if (Len(CRCInfo) > 0) {
				Sender.ClientMessage("Current CRC info:");
				Sender.ClientMessage(""@CRCInfo);
			}
			Sender.ClientMessage("Using HP to fetch CRC data. Check log.");
			xxCheckCRCs(true);
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
		else if (MutateString~="ar forts")
		{
			if (LeagueASGameReplicationInfo != None)
			{
				for (i = 0; i < 20; i++)
				{
					if (LeagueASGameReplicationInfo.FortName[i] != "")
					{
						Sender.ClientMessage(LeagueASGameReplicationInfo.FortName[i]@"->"@LeagueASGameReplicationInfo.FortCompleted[i]);
					}
				}
			}
			
		}
		else if (MutateString~="ar interval" || MutateString~="ar iv")
		{
			if (!bGotWorldStamp)
			{
				SpawnPlayerInterval(Sender.Location);
				if (bAutoStorePlayerIntervals)
					StorePlayerIntervals();
			}
			else
			{
				Sender.ClientMessage("Custom interval timers can only be spawned before the map starts.");
			}
		}
		else if (MutateString~="ar clearintervals" || Left(MutateString,10)~="ar cleariv")
		{
			ClearPlayerIntervals(true);
			Sender.ClientMessage("Cleared all custom interval triggers.");
			SaveConfig();
		}
		else if (MutateString~="ar saveintervals" || Left(MutateString,9)~="ar saveiv")
		{
			StorePlayerIntervals();
			Sender.ClientMessage("Saved all custom interval triggers.");
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
		else if (Left(MutateString,7)~="ar demo" || Left(MutateString,7)~="ar auto")
		{
			if (bAutoDemoRec)
			{
				bAutoDemoRec=False;
				Sender.ClientMessage("Demos will not automatically be recorded in future.");
			}
			else
			{
				bAutoDemoRec=True;
				Sender.ClientMessage("Demos will automatically be recorded.");
				RequestDemo();
			}
			SaveConfig();

		}
		else if (Left(MutateString,15)~="ar togglecustom" || Left(MutateString,9)~="ar custom")
		{
			bIncludeCustomForts = !bIncludeCustomForts;
			if (bIncludeCustomForts)
				Sender.ClientMessage("Custom objectives will be added on next map restart.");
			else
				Sender.ClientMessage("Custom objectives will not be added on next map restart.");
			SaveConfig();			
		}
		else if (MutateString~="ar toggleivbroadcast" || MutateString~="ar ivspam")
		{
			bBroadcastIntervals = !bBroadcastIntervals;
			foreach AllActors(Class'IntervalTrigger',IT)
			{
				IT.bBroadcast = bBroadcastIntervals;
				if (bBroadcastIntervals)
					IT.Event = 'ASAROSEHandler';
				else
					IT.Event = '';
			}
			if (bBroadcastIntervals)
				Sender.ClientMessage("Interval times will be broadcasted.");
			else
				Sender.ClientMessage("Interval times will only appear in the message box.");

			SaveConfig();
		}
		else if (MutateString~="ar togglenohud" || MutateString~="ar togglehud")
		{
			bHUDAlwaysVisible = !bHUDAlwaysVisible;
			if (ASAROHUD!=None)
			{
				if (bHUDAlwaysVisible)
					ChallengeHUD(ASAROHUD).bHideHUD = false;
				else
					ChallengeHUD(ASAROHUD).bHideHUD = true;
			}
			SaveConfig();
		}
		else if (Left(MutateString,7)~="ar list")
		{
    		for (i = 0; i < 32; i++)
    		{
    			if (InitialStarts[i]!=None)
    			{
    				Sender.ClientMessage("Initial PlayerStart - "$InitialStarts[i].Name);
    			}
    		}
		}
		else if (MutateString~="ar showps")
		{
				foreach AllActors(Class'PlayerStart',PS)
				{
					if (PS.TeamNumber==1 && (PS.Tag=='SlowAssPlayerStart' || PS.Tag == 'ASAROSelectablePlayerStart'))
					{
						HighlightPlayerStart(PS,false);
						if (bDebug)
							Sender.ClientMessage("Unhiding:"@PS.Name);
					}
					else
					{
						HighlightPlayerStart(PS,true);	
						if (bDebug)
							Sender.ClientMessage("Unhiding recommended/chosen spawn:"@PS.Name);
					}
				}
		}
		else if (Left(MutateString,9)~="ar change" || Left(MutateString,9)~="ar switch")
		{
			if (!bGotWorldStamp)
			{
				foreach AllActors(Class'PlayerStart',PS)
				{
					if (PS.TeamNumber==1 && PS.bEnabled)
					{
						ActivePS = PS;
					}
				}
				for (i = 0; i < 32; i++)
    			{
    				if (InitialStarts[i]!=None)
    				{
    					ISCount=i;
    					if (InitialStarts[i].Name == ActivePS.Name)
    						ISSlot = i;

    				}
    			}
				if (ISSlot==ISCount)
					ISSlot = 0;
				else
					ISSlot++;

				foreach AllActors(Class'PlayerStart',PS)
				{
					if (PS.TeamNumber==1 && PS.Name==InitialStarts[ISSlot].Name && NextPS==None)
					{
						NextPS = PS;
					}
				}
				NextPS.Tag = ActivePS.Tag;
				ActivePS.Tag = 'ASAROSelectablePlayerStart';
				HighlightPlayerStart(NextPS,true);
				NextPS.bEnabled = true;
				DisablePlayerStart(ActivePS,true,true);

				if (Left(MutateString,9)~="ar change")
				{
					Sender.SetLocation(NextPS.Location);
					Sender.SetRotation(NextPS.Rotation);
				}

				if (FirstOptPS==ActivePS)
					Sender.ClientMessage("("$(ISSlot+1)$"/"$(ISCount+1)$") Switched from auto-optimised "$ActivePS.Name$" to "$NextPS.Name);
				else if (FirstOptPS==NextPS)
					Sender.ClientMessage("("$(ISSlot+1)$"/"$(ISCount+1)$") Switched from manually selected "$ActivePS.Name$" to auto-optimised "$NextPS.Name);
				else
					Sender.ClientMessage("("$(ISSlot+1)$"/"$(ISCount+1)$") Switched from manually selected "$ActivePS.Name$" to "$NextPS.Name);
				ChosenPS = NextPS;

				for (i = 0; i < SavedSlot; i++)
				{
					if (Left(SavedSpawn[i],(Len(MapName)+1)) ~= (MapName$","))
					{
						SavedSpawn[i] = MapName$","$ChosenPS.Name;
						bSaved = true;
					}
				}
				if (!bSaved)
				{
					SavedSpawn[SavedSlot] = MapName$","$ChosenPS.Name;
					SavedSlot++;
					if (SavedSlot > 254)
						SavedSlot = 0;
				}
				SaveConfig();
			}
			else
			{
				Sender.ClientMessage("Game has already started; use 'mutate ar restart' to start a new game.");	
			}
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

function name GenerateFortEvent(Actor A)
{
	local int i;
	local name Event;
	// can't easily cast string to name in this silly engine

	if (Left(Right(A.Name,2),1)~="d" || Left(Right(A.Name,2),1)~="e" || Left(Right(A.Name,2),1)~="r")
		i = int(Right(A.Name,1));
	else
		i = int(Right(A.Name,2));

	Event = 'ASAROHookedEvent';

	switch(i)
    {
    	case 0:
    		Event = 'ASAROHookedEvent0';
    		break;
    	case 1:
    		Event = 'ASAROHookedEvent1';
    		break;
    	case 2:
    		Event = 'ASAROHookedEvent2';
    		break;
    	case 3:
    		Event = 'ASAROHookedEvent3';
    		break;
    	case 4:
    		Event = 'ASAROHookedEvent4';
    		break;
    	case 5:
    		Event = 'ASAROHookedEvent5';
    		break;
    	case 6:
    		Event = 'ASAROHookedEvent6';
    		break;
    	case 7:
    		Event = 'ASAROHookedEvent7';
    		break;
    	case 8:
    		Event = 'ASAROHookedEvent8';
    		break;
    	case 9:
    		Event = 'ASAROHookedEvent9';
    		break;
    	case 10:
    		Event = 'ASAROHookedEvent10';
    		break;
    	case 11:
    		Event = 'ASAROHookedEvent11';
    		break;
    	case 12:
    		Event = 'ASAROHookedEvent12';
    		break;
    	case 13:
    		Event = 'ASAROHookedEvent13';
    		break;
    	case 14:
    		Event = 'ASAROHookedEvent14';
    		break;
    	case 15:
    		Event = 'ASAROHookedEvent15';
    		break;
    	case 16:
    		Event = 'ASAROHookedEvent16';
    		break;
    	case 17:
    		Event = 'ASAROHookedEvent17';
    		break;
    	case 18:
    		Event = 'ASAROHookedEvent18';
    		break;
    	case 19:
    		Event = 'ASAROHookedEvent19';
    		break;
    	case 20:
    		Event = 'ASAROHookedEvent20';
    		break;
    }

    return Event;
}

function bool RequestDemo()
{
	if (bRecording==true)
		return false;

	ConsoleCommand("stopdemo");
	LastDemoFileName = Level.Year $ right("0" $ Level.Month,2) $ right("0" $ Level.Day,2) $ "-" $ right("0" $ Level.Hour,2) $ right("0" $ Level.Minute,2) $ right("0" $ Level.Second,2) $ "_" $ Left(Self, InStr(Self, "."));
	SaveConfig();
	ConsoleCommand("demorec " $ LastDemoFileName);
	bRecording = true;
	
	return bRecording;
}

function RestartMap()
{
	bIsRestarting = true;
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

function ParseToArray(string InputString, string Delimiter, out string SplitOutput[16])
{
	local int i;
	local int row;

	i = instr(InputString, Delimiter);
	while (i >= 0)
	{
		SplitOutput[row] = left(InputString, i);
		InputString = mid(InputString, i+1);
		i = instr(InputString, Delimiter);
		row++;
	}
	if (row < 16)
		SplitOutput[row] = InputString;

	if (row<(16-1))
		SplitOutput[row+1] = "";
}

function xxCheckCRCs(optional bool bUpdatesOnly)
{
	local HackProtection HP, FindHP;
	local int i, j, next;
	local string p1, p2;
	
	// Check self and map
	p1 = Left(string(self.class), InStr(string(self.class), "."));
	p2 = Left(Self, InStr(Self, "."));

	foreach AllActors(Class'HackProtection',FindHP)
	{
		HP = FindHP;
	}
	if (HP == None)
	{
		class'CSHPWebResponse'.default.ClientLog = bDebug;
		HP = Spawn(Class'HackProtection');
	}

	if (!bUpdatesOnly)
	{
		HP.bAllowBehindView = true;
		HP.bAdminWarn = 0;
		HP.bEnableCRCCheck = false; // Only observe using this mutator
		HP.bCRCClientLog = bDebug;

		for (i = 0; i < 7; i++)
		{
			if (HP.CRCPackagesReq[i] != "")
			{
				if (HP.CRCPackagesReq[i] ~= p1)
				{
					next = i;
					break;
				}
				else
				{
					next = i+1;
				}
			}
		}
		HP.CRCPackagesReq[next] = p1$";0;255;0;0";
		HP.CRCPackagesReq[next+1] = p2$";0;255;0;0";
	}

	if (!bUpdatesOnly)
		HP.InitCRCChecks();
	
	for (i = 0; i < 8; i++)
	{
		if (HP.zzCRCPackageData[i].PackageName ~= p1)
		{
			if (bDebug)
				log("LeagueAS has CRC data for"@p1,'ASARO');
			CRCInfo = "{";
			for (j = 0; j < 6; j++)
			{
				if (HP.zzCRCServerCRCs[i].Checksums[j] != 0)
					CRCInfo = CRCInfo$HP.zzCRCServerCRCs[i].Checksums[j]$",";
			}
			CRCInfo = Left(CRCInfo,Len(CRCInfo)-1);
		}
		if (HP.zzCRCPackageData[i].PackageName ~= p2)
		{
			if (bDebug)
				log("LeagueAS has CRC data for"@p2,'ASARO');
			if (Len(CRCInfo) == 0)
				CRCInfo = "{";
			else
				CRCInfo = CRCInfo$";";
			for (j = 0; j < 6; j++)
			{
				if (HP.zzCRCServerCRCs[i].Checksums[j] != 0)
					CRCInfo = CRCInfo$HP.zzCRCServerCRCs[i].Checksums[j]$",";
			}
			CRCInfo = Left(CRCInfo,Len(CRCInfo)-1);
		}
	}
	if (Len(CRCInfo) > 1)
	{
		CRCInfo = CRCInfo$";"$HP.CRCKey$"}";
	}
}

//=================================================================//

defaultproperties
{
     AppString="AssaultRunner Offline version 1.0j by timo@utassault.net"
     ShortAppString="AssaultRunner:"
     bEnabled=True
     bCheatsEnabled=False
     bAttackOnly=True
     bAllowRestart=True
     bHUDAlwaysVisible=True
     iResolution=3
     iTolerance=1
     bAutoDemoRec=True
     bUseFloatAlways=True
     bFullTime=True
     GRIString="completed in:"
     GRIFString="You're an absolute failure. You have no time worthy of display."
     bAlwaysRelevant=True
     bNetTemporary=True
     RemoteRole=ROLE_SimulatedProxy
     TimerPreRate=0.05
     TimerPostRate=0.10
     bBroadcastIntervals=True
     bAutoStorePlayerIntervals=True
     bMigrated=False
     bIncludeCustomForts=True
     Group='ASARO'
}
