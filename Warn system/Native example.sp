#pragma semicolon 1

#include <sourcemod>
#include <smwarn>

public Plugin:myinfo = 
{
    name = "SM_Warn natives example",
    author = "ecca",
    description = "",
    version = "1.0",
    url = "www.alliedmodders.se"
};

public OnPluginStart() 
{
    RegConsoleCmd("sm_warnexample", Command_warnexample);
}
public Action:Command_warnexample(client, args) 
{
	// This will warn a player as a console with reason bad boy
    smwarn_warn(client, "Bad boy");
}
