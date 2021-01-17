# AssaultRunner - Offline edition
Enhanced scoreboard timer for UT99 Assault speed runs

## Installation

Download the latest .u and .int files from the Releases section of this repo, placing them in your UnrealTournament\System folder.

### Prerequisites

This mod has a prerequisite of LeagueAS140 (including server files). This can be downloaded from https://utassault.net/leagueas/files/LeagueAS140.zip, with unpacked files placed in their respective System and Textures folders.

## Usage

### Starting ASARO via the User Interface

- Through the Unreal Tournament UI, select the Game menu then Start Practice Session.
- Select Unreal Tournament as the category.
- Select League Assault 140 as the Game Type.
- Pick your map
- Open the mutators window
- Select (double-click) the "Assault Runner - Offline" mutator (or ASARO if the localisation file is not present) to move it to the "Mutators Used" column.
- Close the mutators window
- Press Start

### Starting ASARO via command line

Either through the UT console, or as a command-line parameter in a shortcut when launching UT:
- `open AS-Bridge?game=LeagueAS140.LeagueAssault?mutator=ASARO1j.ASARO`

### Commands

The AssaultRunner mutator supports the following commands:

 - `mutate ar info` - Displays version info.
 - `mutate ar restart` - Restarts and resets the current map.
 - `mutate ar change` - Changes the current spawn point, can only be run while the map has not yet started and you are in "free-flight spectator" mode.
 - `mutate ar switch` - Per `mutate ar change`, but instead of moving the camera around while changing, this just switches the active spawn, so as a spectator, you can fly out and watch the spawn points cycle around.
 - `mutate ar demo` - Toggles automatic demo recording. Demos will be dropped into the System folder prefixed with a sortable date stamp.
 - `mutate ar cheat` - Cheats are disabled by default, using this command will unlock built in commands such as "god", "ghost", "fly", "summon"; however, toggling this or using any of those commands will "taint" the final screenshot to show that cheats have been used.
 - `mutate ar togglehud` - HUD Visibility is forced on by default, use this command to stop this behaviour.
 - `mutate ar togglecustomobjs` - Toggles custom speed-run specific objectives.

#### Personal interval flags

The mutator supports dynamic addition of custom interval flags, so you can keep track of particular areas of interest within your personal runs.

You can spawn as many of these as you wish, but the mutator will only store just over 4000 total (across all maps), if you fill up your INI with the co-ordinates of these, then no more will be saved, and you will need to start clearing out entries.

Use the following commands to control custom interval flags:
 - `mutate ar interval` (or `mutate ar iv`) - Spawns a custom interval flag.
 - `mutate ar toggleivbroadcast` - Toggles between central "broadcast" of interval capture, or simply logging in the chat box.
 - `mutate ar clearintervals` (or `mutate ar cleariv`) - Clears all custom interval flags from the current map.

#### Debug commands
 - `mutate ar debug` - Provides additional debug information.
 - `mutate ar forts` - Lists all known objectives (FortStandards) and their completion status.
 - `mutate ar list` - Lists all spawn points (PlayerStarts).
 - `mutate ar showps` - Unhides all spawn points (PlayerStarts), even after the map has started.
 - `mutate ar superdebug` - Very verbose debug information.
 
 
### Misc. Notes

The enhanced timer will only show when the HUD is visible; by default it will reset the visibility of the HUD at map start, so if you're used to clean-living with no HUD, you can override this behaviour with the `mutate ar togglehud` command.
