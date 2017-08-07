#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <adminmenu>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#tryinclude <sourcebans>
#define REQUIRE_EXTENSIONS
#define REQUIRE_PLUGIN


#define PLUGIN_VERSION "1.2.0"

// Handles
new Handle:hDatabase = INVALID_HANDLE;
new Handle:DHhostname = INVALID_HANDLE;
new Handle:hAdminMenu = INVALID_HANDLE;

// Chaos up here, fuck that
new Handle:g_cVar_maxwarns = INVALID_HANDLE;
new Handle:g_cVar_max_punishment = INVALID_HANDLE;
new Handle:g_cVar_banlength = INVALID_HANDLE;
new Handle:g_cVar_punishment = INVALID_HANDLE;
new Handle:g_cVar_slapdamage = INVALID_HANDLE;
new Handle:g_cVar_PrintToAdmins = INVALID_HANDLE;
new Handle:g_cVar_LogWarnings = INVALID_HANDLE;
new Handle:g_cVar_warnsound = INVALID_HANDLE;
new Handle:g_cVar_warnsoundPath = INVALID_HANDLE;
new Handle:g_cVar_motdpanel = INVALID_HANDLE;
new Handle:g_cVar_warnpaneltitel = INVALID_HANDLE;
new Handle:g_cVar_warnpanelurl = INVALID_HANDLE;
new Handle:g_cVar_reset_warnings = INVALID_HANDLE;

// Bools
new bool:g_UseSourcebans = false;

new g_target[MAXPLAYERS+1];

// Paths
new String:pathwarn[PLATFORM_MAX_PATH];
new String:pathunwarn[PLATFORM_MAX_PATH];
new String:pathresetwarn[PLATFORM_MAX_PATH];
new String:pathagree[PLATFORM_MAX_PATH];

public Plugin:myinfo =
{
	name = "SM warn",
	author = "ecca",
	description = "Warn players when they are doing something wrong.",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
	// Translations
	LoadTranslations("common.phrases");
	LoadTranslations("warn.phrases");
	
	// ConVars
	CreateConVar("sm_warn_version", PLUGIN_VERSION, "SM_warn plugin version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	// Core cVars
	g_cVar_reset_warnings = CreateConVar("sm_warn_reset_warnings", "0", "Reset warnings when they reach the max warnings: 0 - Keep warnings, 1 - Delete warnings", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	// Punishment cVars
	g_cVar_maxwarns = CreateConVar("sm_warn_maxwarns", "3", "Set max warnings reached before action", FCVAR_PLUGIN, true, 1.0, true, 10.0); // Man i dont wanna create a own category for you.. :P
	g_cVar_punishment = CreateConVar("sm_warn_punishment", "4", "Action to set when a player gets a warning: 1 - message player, 2 - slap player and message, 3 - slay player and message, 4 - Popup agreement and message, 5 - kick player with reason, 6 - ban player with reason", FCVAR_PLUGIN, true, 1.0, true, 6.0);
	g_cVar_max_punishment = CreateConVar("sm_warn_max_punishment", "1", "Action to set when a player reach max warnings: 1 - kick, 2 - ban", FCVAR_PLUGIN, true, 1.0, true, 2.0);
	g_cVar_banlength = CreateConVar("sm_warn_banlength", "1", "Time to ban target: 0 - permanent", FCVAR_PLUGIN);
	g_cVar_slapdamage = CreateConVar("sm_warn_slapdamage", "0", "Slap player with damage: 0 - no damage", FCVAR_PLUGIN, true, 0.0, true, 100.0);
	
	// Sound cVars
	g_cVar_warnsound = CreateConVar("sm_warn_warnsound", "1", "Play a sound when a user receives a warning: 0 - disabled, 1 - enabled", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_cVar_warnsoundPath = CreateConVar("sm_warn_warnsoundpath", "buttons/weapon_cant_buy.wav", "Path to the sound that will play when a user receives a warning", FCVAR_PLUGIN);
	
	// Motd panel cVars
	g_cVar_motdpanel = CreateConVar("sm_warn_motdpanel", "0", "Show a motd panel to client on warn: 0 - disabled, 1 - enabled", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_cVar_warnpaneltitel = CreateConVar("sm_warn_motdpaneltitel", "SM warn panel titel", "Titel of the motd page that will popup", FCVAR_PLUGIN);
	g_cVar_warnpanelurl = CreateConVar("sm_warn_motdpanelurl", "", "Path to the motd panel that will popup", FCVAR_PLUGIN);
	
	// other cVars
	g_cVar_PrintToAdmins = CreateConVar("sm_warn_printtoadmins", "1", "Print previous warnings on connect to admins: 0 - disabled, 1 - enabled", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_cVar_LogWarnings = CreateConVar("sm_warn_logwarnings", "1", "Log the admin commands: 0 - disabled, 1 - enabled", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "SM_warn");
	
	// Commands
	RegAdminCmd("sm_warn", Command_WarnPlayer, ADMFLAG_BAN);
	RegAdminCmd("sm_unwarn", Command_UnWarnPlayer, ADMFLAG_BAN);
	RegAdminCmd("sm_checkwarn", Command_CheckWarnPlayer, ADMFLAG_BAN);
	RegAdminCmd("sm_resetwarn", Command_WarnReset, ADMFLAG_BAN);
	
	// Build paths
	BuildPath(Path_SM, pathwarn, sizeof(pathwarn), "configs/sm_warn_reasons.cfg");
	BuildPath(Path_SM, pathunwarn, sizeof(pathunwarn), "configs/sm_unwarn_reasons.cfg");
	BuildPath(Path_SM, pathresetwarn, sizeof(pathresetwarn), "configs/sm_resetwarn_reasons.cfg");
	BuildPath(Path_SM, pathagree, sizeof(pathagree), "configs/sm_warn_agreement.cfg");
	
	// Initialize database
	SetupDatabase();
	
	// Find hostname yarrr
	DHhostname = FindConVar("hostname");
	
	// Setup admin menu
	new Handle:topmenu;
	
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Warn natives
	CreateNative("smwarn_warn", Native_WarnPlayer);
	CreateNative("smwarn_unwarn", Native_UnWarnPlayer);
	CreateNative("smwarn_resetwarn", Native_ResetWarnPlayer);
	
	// Make this optional
	MarkNativeAsOptional("SBBanPlayer");
	
	RegPluginLibrary("smwarn");
	
	return APLRes_Success;
}

public OnAllPluginsLoaded()
{
	if (LibraryExists("sourcebans"))
	{
		g_UseSourcebans = true;
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual("sourcebans", name))
	{
		g_UseSourcebans = true;
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual("sourcebans", name))
	{
		g_UseSourcebans = false;
	}
	else if(StrEqual(name, "adminmenu")) 
	{
		hAdminMenu = INVALID_HANDLE;
	}
}

public Native_WarnPlayer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	new len;
	GetNativeStringLength(2, len);
	
	if (len <= 0)
	{
		return;
	}
	
	new String:Reason[len+1];
	GetNativeString(2, Reason, len+1);
	
	ServerCommand("sm_warn #%d \"%s\"", GetClientUserId(client), Reason);
}

public Native_UnWarnPlayer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	new len;
	GetNativeStringLength(2, len);
	
	if (len <= 0)
	{
		return;
	}
	
	new String:Reason[len+1];
	GetNativeString(2, Reason, len+1);
	
	ServerCommand("sm_unwarn #%d \"%s\"", GetClientUserId(client), Reason);
}

public Native_ResetWarnPlayer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	new len;
	GetNativeStringLength(2, len);
	
	if (len <= 0)
	{
		return;
	}
	
	new String:Reason[len+1];
	GetNativeString(2, Reason, len+1);
	
	ServerCommand("sm_resetwarn #%d \"%s\"", GetClientUserId(client), Reason);
}

public SetupDatabase()
{
	SQL_TConnect(SQL_OnConnect, "warn");
}

public OnMapStart()
{
	if(GetConVarBool(g_cVar_warnsound))
	{
		new String:g_Path[214];
		GetConVarString(g_cVar_warnsoundPath, g_Path, sizeof(g_Path));
		PrecacheSound(g_Path, true);
	}
}

public SQL_OnConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		SetFailState("[SM warn] Database failure: %s", error);
	}
	else
	{
		hDatabase = hndl;
		
		new String:buffer[1024];
		
		SQL_GetDriverIdent(SQL_ReadDriver(hDatabase), buffer, sizeof(buffer));
	
		new UseMySQL = StrEqual(buffer, "mysql", false) ? 1 : 0;

		if (UseMySQL == 1)
		{
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS `smwarn` (`target` VARCHAR(64), `tsteamid` VARCHAR(32), `admin` VARCHAR(64), `asteamid` VARCHAR(32), `reason` VARCHAR(64), `time` VARCHAR(64), `expired` VARCHAR(1), `hostname` VARCHAR(254))");
		}
		else
		{
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS smwarn (target TEXT, tsteamid TEXT, admin TEXT, asteamid TEXT, reason TEXT, time TEXT, expired TEXT, hostname TEXT);");
		}
		
		SQL_TQuery(hDatabase, SQL_EmptyCallback, buffer);
		
		if (UseMySQL == 1)
		{
			new String:dbQuery[254];
			Format(dbQuery, sizeof(dbQuery), "SET NAMES 'utf8'");
			
			SQL_TQuery(hDatabase, SQL_EmptyCallback, dbQuery);
		}
	}
}

public OnClientPostAdminCheck(client)
{
	if(!IsFakeClient(client))
	{
		new String:steamid[32];
		GetClientAuthString(client, steamid, sizeof(steamid));
		
		new String:dbQuery[254];
		FormatEx(dbQuery, sizeof(dbQuery),  "SELECT * FROM smwarn WHERE tsteamid='%s' AND expired != '1'", steamid);

		SQL_TQuery(hDatabase, SQL_CheckWarnings, dbQuery, client);
	}
}

public SQL_CheckWarnings(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (hndl == INVALID_HANDLE)
	{
		SetupDatabase();
		return;
	}
	
	if (SQL_FetchRow(hndl))
	{
		new warnings = SQL_GetRowCount(hndl);
		
		if (GetConVarBool(g_cVar_PrintToAdmins))
		{
			PrintToAdmins("\x03[Warn] \x01%t", "warn_warnconnect", client, warnings);
		}
	}
}

public Action:Command_WarnPlayer(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "\x03[Warn] \x01%t", "warn_arguments");
		return Plugin_Handled;
	}
	
	new String:argument[32], String:reason[64], String:buffer[100];
	GetCmdArg(1, argument, sizeof(argument));

	if(args >= 2)
	{
		for(new i = 2; i <= args; i++)
		{
			GetCmdArg(i, buffer, sizeof(buffer));
			Format(reason, sizeof(reason), "%s %s", reason, buffer);
		}
	}
	
	new target = FindTarget(client, argument, true, true);
	
	if (target > 0 && target <= MaxClients )
	{
		new String:csteamid[32], String:tsteamid[32], String:cip[32], String:tip[32];
		GetClientAuthString(target, tsteamid, sizeof(tsteamid));
		GetClientIP(target, tip, sizeof(tip));
		
		new Handle:datapack = CreateDataPack();
		
		if (client != 0)
		{
			GetClientAuthString(client, csteamid, sizeof(csteamid));
			GetClientIP(client, cip, sizeof(cip));
			WritePackCell(datapack, GetClientUserId(client));
			
		}
		else
		{
			Format(csteamid, sizeof(csteamid), "CONSOLE");
			Format(cip, sizeof(cip), "Unknown");
			WritePackCell(datapack, 0);
		}
		
		WritePackCell(datapack, GetClientUserId(target));
		WritePackString(datapack, reason);
		ResetPack(datapack);
		
		new String:dbQuery[254];
		FormatEx(dbQuery, sizeof(dbQuery),  "SELECT * FROM smwarn WHERE tsteamid='%s' AND expired != '1'", tsteamid);

		SQL_TQuery(hDatabase, SQL_WarnPlayer, dbQuery, datapack);
		
		ShowActivity2(client, "\x03[Warn] \x01", "%t", "warn_warnplayer", target, reason);
		
		if(GetConVarBool(g_cVar_LogWarnings))
		{
			LogWarnings("[SM warn] %t", "warn_warnlog", client, csteamid, cip, target, tsteamid, tip, reason);
		}
		
		if(GetConVarBool(g_cVar_warnsound))
		{
			new String:g_Path[214];
			GetConVarString(g_cVar_warnsoundPath, g_Path, sizeof(g_Path));
			
			EmitSoundToClient(target, g_Path);
		}
		
		if(GetConVarBool(g_cVar_motdpanel) && GetConVarInt(g_cVar_punishment) != 4)
		{
			new String:g_titel[214], String:g_url[214];
			GetConVarString(g_cVar_warnpaneltitel, g_titel, sizeof(g_titel));
			GetConVarString(g_cVar_warnpanelurl, g_url, sizeof(g_url));
			
			ShowMOTDPanel(target, g_titel, g_url, MOTDPANEL_TYPE_URL);
		}
	}
	return Plugin_Handled;
}

public SQL_WarnPlayer(Handle:owner, Handle:hndl, const String:error[], any:datapack)
{
	new client;
	new target;
	new time = GetTime();
	new String:tempreason[64], String:dbQuery[1024], String:asteamid[32], String:tsteamid[64], String:nickname[64], String:nickname2[64], String:tempnick[64], String:tempnick2[64], String:Reason[64], String:hostname[1024], String:ehostname[1024];
	
	if(datapack != INVALID_HANDLE)
	{
		client = GetClientOfUserId(ReadPackCell(datapack));
		target = GetClientOfUserId(ReadPackCell(datapack));
		ReadPackString(datapack, tempreason, sizeof(tempreason));
		CloseHandle(datapack); 
	}
	
	if (hndl == INVALID_HANDLE)
	{
		SetupDatabase();
		return;
	}
	
	if (client != 0)
	{
		GetClientAuthString(client, asteamid, sizeof(asteamid));
		GetClientName(client, tempnick2, sizeof(tempnick2));
		SQL_EscapeString(hDatabase, tempnick2, nickname2, sizeof(nickname2));
	}
	else
	{
		Format(asteamid, sizeof(asteamid), "CONSOLE");
		Format(nickname2, sizeof(nickname2), "CONSOLE");
	}
	
	GetClientName(target, tempnick, sizeof(tempnick));
	GetConVarString(DHhostname, hostname, sizeof(hostname));
	ReplaceString(hostname, sizeof(hostname), "/", "");
	ReplaceString(hostname, sizeof(hostname), "'", "");
	SQL_EscapeString(hDatabase, tempnick, nickname, sizeof(nickname));
	SQL_EscapeString(hDatabase, tempreason, Reason, sizeof(Reason));
	SQL_EscapeString(hDatabase, hostname, ehostname, sizeof(ehostname));
	
	GetClientAuthString(target, tsteamid, sizeof(tsteamid));
	
	if (SQL_FetchRow(hndl))
	{
		new warnings = SQL_GetRowCount(hndl);
		warnings++;
		
		Format(dbQuery, sizeof(dbQuery), "INSERT INTO smwarn (target, tsteamid, admin, asteamid, reason, time, expired, hostname) VALUES ('%s', '%s', '%s', '%s', '%s', '%i', '0', '%s')", nickname, tsteamid, nickname2, asteamid, Reason, time, ehostname);
		SQL_TQuery(hDatabase, SQL_EmptyCallback, dbQuery);
		
		if (warnings >= GetConVarInt(g_cVar_maxwarns))
		{
			if(GetConVarBool(g_cVar_reset_warnings))
			{
				Format(dbQuery, sizeof(dbQuery), "DELETE FROM smwarn WHERE tsteamid = '%s'", tsteamid);
				SQL_TQuery(hDatabase, SQL_EmptyCallback, dbQuery);
			}
			else
			{
				Format(dbQuery, sizeof(dbQuery), "UPDATE smwarn SET expired = '1' WHERE tsteamid = '%s'", tsteamid);
				SQL_TQuery(hDatabase, SQL_EmptyCallback, dbQuery);
			}
			
			switch (GetConVarInt(g_cVar_max_punishment))
			{
				case 0:
				{
				}
				case 1:
				{
					KickClient(target, "[SM warn] %t", "warn_max_kickonly");
				}
				case 2:
				{
					new String:kickReason[100], String:banReason[100];
				
					Format(kickReason, sizeof(kickReason), "[SM warn] %t", "warn_max_kick");
					Format(banReason, sizeof(banReason), "[SM warn] %t", "warn_max_ban", Reason);
					
					if (g_UseSourcebans)
					{
						SBBanPlayer(0, target, GetConVarInt(g_cVar_banlength), banReason);
					}
					else
					{
						BanClient(target, GetConVarInt(g_cVar_banlength), BANFLAG_AUTO, banReason, kickReason, "warn");
					}
				}
			}
		}
	}
	else
	{
		Format(dbQuery, sizeof(dbQuery), "INSERT INTO smwarn (target, tsteamid, admin, asteamid, reason, time, expired, hostname) VALUES ('%s', '%s', '%s', '%s', '%s', '%i', '0', '%s')", nickname, tsteamid, nickname2, asteamid, Reason, time, hostname);
		SQL_TQuery(hDatabase, SQL_EmptyCallback, dbQuery);
	}
	
	if(IsClientInGame(target) && !IsFakeClient(target))
	{
		switch (GetConVarInt(g_cVar_punishment))
		{
			case 1:
			{
				// Aww, i want to punish them, aaarr
				PrintToChat(target, "\x03[Warn] \x01%t", "warn_message");
			}
			case 2:
			{
				SlapPlayer(target, GetConVarInt(g_cVar_slapdamage), true);
				PrintToChat(target, "[\x03[Warn] \x01%t", "warn_message");
			}
			case 3:
			{
				ForcePlayerSuicide(target);
				PrintToChat(target, "\x03[Warn] \x01%t", "warn_message");
			}
			case 4:
			{
				SetEntityMoveType(target, MOVETYPE_NONE);
				BuildAgreement(target);
				PrintToChat(target, "\x03[Warn] \x01%t", "warn_message");
			}
			case 5:
			{
				new String:kickreason[1024];
				Format(kickreason, sizeof(kickreason), "[SM warn] %t", "warn_punish_kick", Reason);
				
				KickClient(target, kickreason);
			}
			case 6:
			{
				new String:kickReason[1024], String:banReason[1024];
				
				Format(kickReason, sizeof(kickReason), "[SM warn] %t", "warn_punish_kickban", Reason);
				Format(banReason, sizeof(banReason), "[SM warn] %t", "warn_punish_ban", Reason);
				
				if (g_UseSourcebans)
				{
					SBBanPlayer(0, target, GetConVarInt(g_cVar_banlength), banReason);
				}
				else
				{
					BanClient(target, GetConVarInt(g_cVar_banlength), BANFLAG_AUTO, banReason, kickReason, "warn");
				}
			}
		}
	}
}

public Action:Command_UnWarnPlayer(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "\x03[Warn] \x01%t", "warn_arguments2");
		return Plugin_Handled;
	}
	
	new String:argument[32], String:reason[64], String:buffer[100];
	GetCmdArg(1, argument, sizeof(argument));
	
	if(args >= 2)
	{
		for(new i = 2; i <= args; i++)
		{
			GetCmdArg(i, buffer, sizeof(buffer));
			Format(reason, sizeof(reason), "%s %s", reason, buffer);
		}
	}
	
	new target = FindTarget(client, argument, true, true);
	
	if (target > 0 && target <= MaxClients )
	{
		new String:steamid[32];
		GetClientAuthString(target, steamid, sizeof(steamid));
		
		new String:dbQuery[254];
		FormatEx(dbQuery, sizeof(dbQuery),  "SELECT * FROM smwarn WHERE tsteamid='%s' AND expired != '1' ORDER BY time DESC LIMIT 1", steamid);
		
		new Handle:datapack = CreateDataPack();
		
		if (client != 0)
		{
			WritePackCell(datapack, GetClientUserId(client));
			
		}
		else
		{
			WritePackCell(datapack, 0);
		}
		
		WritePackCell(datapack, GetClientUserId(target));
		WritePackString(datapack, steamid);
		WritePackString(datapack, reason);
		ResetPack(datapack);

		SQL_TQuery(hDatabase, SQL_UnWarnPlayer, dbQuery, datapack);
	}
	return Plugin_Handled;
}

public SQL_UnWarnPlayer(Handle:owner, Handle:hndl, const String:error[], any:datapack)
{
	new client;
	new target;
	new String:tsteamid[32], String:reason[32];
	
	if(datapack != INVALID_HANDLE)
	{
		client = GetClientOfUserId(ReadPackCell(datapack));
		target = GetClientOfUserId(ReadPackCell(datapack));
		ReadPackString(datapack, tsteamid, sizeof(tsteamid));
		ReadPackString(datapack, reason, sizeof(reason));
		CloseHandle(datapack); 
	}
	
	if (hndl == INVALID_HANDLE)
	{
		SetupDatabase();
		return;
	}
	
	new String:dbQuery[500];
	
	if (SQL_FetchRow(hndl))
	{
		new String:csteamid[32], String:cip[32], String:tip[32], String:timestring[64];
		
		if (client != 0)
		{
			GetClientAuthString(client, csteamid, sizeof(csteamid));
			GetClientIP(client, cip, sizeof(cip));
		}
		else
		{
			Format(csteamid, sizeof(csteamid), "CONSOLE");
			Format(cip, sizeof(cip), "Unknown");
		}
		
		GetClientIP(target, tip, sizeof(tip));
		SQL_FetchString(hndl, 5, timestring, sizeof(timestring));
		
		Format(dbQuery, sizeof(dbQuery), "DELETE FROM smwarn WHERE time = '%s' AND tsteamid = '%s'", timestring, tsteamid);

		SQL_TQuery(hDatabase, SQL_EmptyCallback, dbQuery);
		
		ShowActivity2(client, "\x03[Warn] \x01", "%t", "warn_unwarn_player", target, reason);
		
		if(GetConVarBool(g_cVar_LogWarnings))
		{
			LogWarnings("[SM warn] %t", "warn_unwarn_log", client, csteamid, cip, target, tsteamid, tip, reason);
		}
	}
	else
	{
		PrintToChat(client, "\x03[Warn] \x01%t", "warn_notwarned", target);
	}
}

public Action:Command_WarnReset(client, args)
{
	if(!GetConVarBool(g_cVar_reset_warnings))
	{
		ReplyToCommand(client, "\x03[Warn] \x01You don't have access to this command");
		return Plugin_Handled;
	}
	
	if (args < 2)
	{
		ReplyToCommand(client, "\x03[Warn] \x01%t", "warn_arguments4");
		return Plugin_Handled;
	}
	
	new String:argument[32], String:reason[64], String:buffer[100];
	GetCmdArg(1, argument, sizeof(argument));
	
	if(args >= 2)
	{
		for(new i = 2; i <= args; i++)
		{
			GetCmdArg(i, buffer, sizeof(buffer));
			Format(reason, sizeof(reason), "%s %s", reason, buffer);
		}
	}
	
	new target = FindTarget(client, argument, true, true);
	
	if (target > 0 && target <= MaxClients )
	{
		new String:steamid[32];
		GetClientAuthString(target, steamid, sizeof(steamid));
		
		new String:dbQuery[254];
		FormatEx(dbQuery, sizeof(dbQuery),  "SELECT * FROM smwarn WHERE tsteamid='%s'", steamid);
		
		new Handle:dbpack = CreateDataPack(); 
		
		if (client != 0)
		{
			WritePackCell(dbpack, GetClientUserId(client));
		}
		else
		{
			WritePackCell(dbpack, 0);
		}
		
		WritePackCell(dbpack, GetClientUserId(target));
		WritePackString(dbpack, steamid);
		WritePackString(dbpack, reason);
		ResetPack(dbpack);

		SQL_TQuery(hDatabase, SQL_ResetWarnPlayer, dbQuery, dbpack);
	}
	return Plugin_Handled;
}

public SQL_ResetWarnPlayer(Handle:owner, Handle:hndl, const String:error[], any:dbpack)
{
	new client;
	new target;
	new String:tsteamid[32], String:reason[32];
	
	if(dbpack != INVALID_HANDLE)
	{
		client = GetClientOfUserId(ReadPackCell(dbpack));
		target = GetClientOfUserId(ReadPackCell(dbpack));
		ReadPackString(dbpack, tsteamid, sizeof(tsteamid));
		ReadPackString(dbpack, reason, sizeof(reason));
		CloseHandle(dbpack); 
	}
	
	if (hndl == INVALID_HANDLE)
	{
		SetupDatabase();
		return;
	}
	
	new String:dbQuery[254];
	
	if (SQL_FetchRow(hndl))
	{
		Format(dbQuery, sizeof(dbQuery), "DELETE FROM smwarn WHERE tsteamid = '%s'", tsteamid);
		SQL_TQuery(hDatabase, SQL_EmptyCallback, dbQuery);
		
		ShowActivity2(client, "\x03[Warn] \x01", "%t", "warn_resetplayer", target, reason);

		new String:csteamid[32], String:cip[32], String:tip[32];
		
		if (client != 0)
		{
			GetClientAuthString(client, csteamid, sizeof(csteamid));
			GetClientIP(client, cip, sizeof(cip));
		}
		else
		{
			Format(csteamid, sizeof(csteamid), "CONSOLE");
			Format(cip, sizeof(cip), "Unknown");
		}

		
		if(GetConVarBool(g_cVar_LogWarnings))
		{
			LogWarnings("[SM warn] %t", "warn_resetwarn_log", client, csteamid, cip, target, tsteamid, tip, reason);
		}
	}
	else
	{
		PrintToChat(client, "\x03[Warn] \x01%t", "warn_notwarned", target);
	}
}

public Action:Command_CheckWarnPlayer(client, args)
{
	if (client == 0)
	{
		PrintToServer("[SM warn] In-game command only!");
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "\x03[Warn] \x01%t", "warn_arguments3");
		return Plugin_Handled;
	}
	
	new String:argument[32];
	GetCmdArg(1, argument, sizeof(argument));
	new target = FindTarget(client, argument, true, true);
	
	if (target > 0 && target <= MaxClients )
	{
		new String:steamid[32];
		GetClientAuthString(target, steamid, sizeof(steamid));
		
		new String:dbQuery[254];
		FormatEx(dbQuery, sizeof(dbQuery),  "SELECT * FROM smwarn WHERE tsteamid='%s'", steamid);
		
		new Handle:datapacket = CreateDataPack(); 
		WritePackCell(datapacket, GetClientUserId(client));
		WritePackCell(datapacket, GetClientUserId(target));
		ResetPack(datapacket);

		SQL_TQuery(hDatabase, SQL_CheckPlayer, dbQuery, datapacket);
	}
	return Plugin_Handled;
}

public SQL_CheckPlayer(Handle:owner, Handle:hndl, const String:error[], any:datapacket)
{
	new client;
	new target;
	
	if(datapacket != INVALID_HANDLE)
	{
		client = GetClientOfUserId(ReadPackCell(datapacket));
		target = GetClientOfUserId(ReadPackCell(datapacket));
		CloseHandle(datapacket); 
	}
	
	if (hndl == INVALID_HANDLE)
	{
		SetupDatabase();
		return;
	}
	
	if (SQL_GetRowCount(hndl) == 0)
	{
		PrintToChat(client, "\x03[Warn] \x01%t", "warn_notwarned", target);
		return;
	}
	
	PrintToChat(client, "\x03[Warn] \x01Check console for output");
	
	new warnings = SQL_GetRowCount(hndl);
	new String:nickname[15], String:admin[15], String:Reason[32], String:Date[32], String:Expired[4], String:hostname[254];
	PrintToConsole(client, "");
	PrintToConsole(client, "");
	PrintToConsole(client, "[SM warn] %t", "warn_consoleoutput", target, warnings);
	PrintToConsole(client, "%-15s %-16s %-22s %-33s %-3s %s", "Player", "Admin", "Date", "Reason", "Expired", "Server");
	PrintToConsole(client, "----------------------------------------------------------------------------------------------------");
	
	while (SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 0, nickname, sizeof(nickname));
		SQL_FetchString(hndl, 2, admin, sizeof(admin));
		SQL_FetchString(hndl, 4, Reason, sizeof(Reason));
		SQL_FetchString(hndl, 5, Date, sizeof(Date));
		SQL_FetchString(hndl, 6, Expired, sizeof(Expired));
		SQL_FetchString(hndl, 7, hostname, sizeof(hostname));
		
		if(StrEqual(Expired, "0", false))
		{
			Format(Expired, sizeof(Expired), "No");
		}
		else
		{
			Format(Expired, sizeof(Expired), "Yes");
		}
		
		new buffer;
		buffer = StringToInt(Date);
		FormatTime(Date, sizeof(Date), "%Y-%m-%d %X", buffer);
		
		PrintToConsole(client, "%-15s %-16s %-22s %-33s %-3s %s", nickname, admin, Date, Reason, Expired, hostname);
	}
}
		
public SQL_EmptyCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (!StrEqual(error, "", false))
	{
		LogError("Query failure: %s", error);
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	if (topmenu == hAdminMenu)
	{
		return;
	}
	
	hAdminMenu = topmenu;

	// new TopMenuObject:player_commands = FindTopMenuCategory(hAdminMenu, ADMINMENU_PLAYERCOMMANDS);
	new TopMenuObject:player_commands = FindTopMenuCategory(hAdminMenu, "warnmenu");
	
	
	if (player_commands == INVALID_TOPMENUOBJECT)
	{
		player_commands = AddToTopMenu(hAdminMenu, "warnmenu", TopMenuObject_Category, Handle_AdminCategory, INVALID_TOPMENUOBJECT, "sm_warnmenu", ADMFLAG_BAN);
	}
	
	AddToTopMenu(hAdminMenu, "sm_warn", TopMenuObject_Item, AdminMenu_Warn, player_commands, "sm_warn", ADMFLAG_BAN);
	AddToTopMenu(hAdminMenu, "sm_unwarn", TopMenuObject_Item, AdminMenu_UnWarn, player_commands, "sm_unwarn", ADMFLAG_BAN);
	AddToTopMenu(hAdminMenu, "sm_resetwarn", TopMenuObject_Item, AdminMenu_ResetWarn, player_commands, "sm_resetwarn", ADMFLAG_BAN);
	AddToTopMenu(hAdminMenu, "sm_checkwarn", TopMenuObject_Item, AdminMenu_CheckWarn, player_commands, "sm_checkwarn", ADMFLAG_BAN);
}

public Handle_AdminCategory( Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength )
{
	switch(action)
	{
		case TopMenuAction_DisplayTitle:
		{
			Format(buffer, maxlength, "Warning Commands");
		}
		case TopMenuAction_DisplayOption:
		{
			Format(buffer, maxlength, "Warnings Commands");
		}
	}
}

public AdminMenu_Warn(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%t", "warn_warn_adminmenu_title", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayWarnTargetMenu(param);
	}
}

public AdminMenu_UnWarn(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%t", "warn_unwarn_adminmenu_title", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayUnWarnTargetMenu(param);
	}
}

public AdminMenu_ResetWarn(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%t", "warn_resetwarn_adminmenu_title", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayRestetWarnTargetMenu(param);
	}
}

public AdminMenu_CheckWarn(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%t", "warn_checkwarn_adminmenu_title", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayCheckWarnTargetMenu(param);
	}
}

DisplayWarnTargetMenu(client) 
{
	new Handle:menu = CreateMenu(MenuHandler_Warn);
	
	new String:title[32];
	Format(title, sizeof(title), "%t", "warn_warn_targetmenutitle", client);
	
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

DisplayUnWarnTargetMenu(client) 
{
	new Handle:menu = CreateMenu(MenuHandler_UnWarn);
	
	new String:title[32];
	Format(title, sizeof(title), "%t", "warn_unwarn_targetmenutitle", client);
	
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

DisplayCheckWarnTargetMenu(client) 
{
	new Handle:menu = CreateMenu(MenuHandler_CheckWarn);
	
	new String:title[32];
	Format(title, sizeof(title), "%t", "warn_checkwarn_targetmenutitle", client);
	
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

DisplayRestetWarnTargetMenu(client) 
{
	new Handle:menu = CreateMenu(MenuHandler_ResetWarn);
	
	new String:title[32];
	Format(title, sizeof(title), "%t", "warn_resetwarn_targetmenutitle", client);
	
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Warn(Handle:menu, MenuAction:action, param1, param2) 
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select) 
	{
		
		new String:info[32];
		new userid, target;

		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "\x03[Warn] \x01%t", "warn_notavailable");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "\x03[Warn] \x01%t", "warn_canttarget");
		}
		else
		{
			g_target[param1] = userid;
			DisplayWarnReasons(param1);
		}
	}
}

public MenuHandler_UnWarn(Handle:menu, MenuAction:action, param1, param2) 
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select) 
	{
		
		new String:info[32];
		new userid, target;

		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "\x03[Warn] \x01%t", "warn_notavailable");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "\x03[Warn] \x01%t", "warn_canttarget");
		}
		else
		{
			g_target[param1] = userid;
			DisplayUnWarnReasons(param1);
		}
	}
}

public MenuHandler_CheckWarn(Handle:menu, MenuAction:action, param1, param2) 
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select) 
	{
		
		new String:info[32];
		new userid, target;

		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "\x03[Warn] \x01%t", "warn_notavailable");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "\x03[Warn] \x01%t", "warn_canttarget");
		}
		else
		{
			FakeClientCommand(param1, "sm_checkwarn \"#%d\"", userid);
		}
	}
}

public MenuHandler_ResetWarn(Handle:menu, MenuAction:action, param1, param2) 
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel) 
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select) 
	{
		
		new String:info[32];
		new userid, target;

		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "\x03[Warn] \x01%t", "warn_notavailable");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "\x03[Warn] \x01%t", "warn_canttarget");
		}
		else
		{
			g_target[param1] = userid;
			DisplayResetWarnReasons(param1);
		}
	}
}

DisplayWarnReasons(client) 
{
	new Handle:menu = CreateMenu(MenuHandler_PreformWarn);
	
	new String:title[32];
	Format(title, sizeof(title), "%t", "warn_warn_reasontitle", client);

	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	new Handle:g_FilePath = OpenFile(pathwarn, "rt");
	
	if (g_FilePath == INVALID_HANDLE)
	{
		LogWarnings("Could not find the config file (addons/sourcemod/configs/sm_unwarn_reasons.cfg)");
		return;
	}
 	
	new String:reason[255];
	
	while (!IsEndOfFile(g_FilePath) && ReadFileLine(g_FilePath, reason, sizeof(reason)))
	{
		AddMenuItem(menu, reason, reason);
	}
	
	CloseHandle(g_FilePath);

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

DisplayUnWarnReasons(client) 
{
	new Handle:menu = CreateMenu(MenuHandler_PreformUnWarn);

	new String:title[32];
	Format(title, sizeof(title), "%t", "warn_unwarn_reasontitle", client);

	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	new Handle:g_FilePath = OpenFile(pathunwarn, "rt");
	
	if (g_FilePath == INVALID_HANDLE)
	{
		LogWarnings("Could not find the config file (addons/sourcemod/configs/sm_unwarn_reasons.cfg)");
		return;
	}

	new String:reason[255];
	
	while (!IsEndOfFile(g_FilePath) && ReadFileLine(g_FilePath, reason, sizeof(reason)))
	{
		AddMenuItem(menu, reason, reason);
	}
	
	CloseHandle(g_FilePath);

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

DisplayResetWarnReasons(client) 
{
	new Handle:menu = CreateMenu(MenuHandler_PreformResetWarn);

	new String:title[32];
	Format(title, sizeof(title), "%t", "warn_restwarn_reasontitle", client);

	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	new Handle:g_FilePath = OpenFile(pathresetwarn, "rt");
	
	if (g_FilePath == INVALID_HANDLE)
	{
		LogWarnings("Could not find the config file (addons/sourcemod/configs/sm_resetwarn_reasons.cfg)");
		return;
	}

	new String:reason[255];
	
	while (!IsEndOfFile(g_FilePath) && ReadFileLine(g_FilePath, reason, sizeof(reason)))
	{
		AddMenuItem(menu, reason, reason);
	}
	
	CloseHandle(g_FilePath);

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_PreformWarn(Handle:menu, MenuAction:action, param1, param2) 
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		new String:info[64];

		GetMenuItem(menu, param2, info, sizeof(info));

		FakeClientCommand(param1, "sm_warn #%d %s", g_target[param1], info);
	}
}

public MenuHandler_PreformUnWarn(Handle:menu, MenuAction:action, param1, param2) 
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		new String:info[64];

		GetMenuItem(menu, param2, info, sizeof(info));

		FakeClientCommand(param1, "sm_unwarn #%d %s", g_target[param1], info);
	}
}

public MenuHandler_PreformResetWarn(Handle:menu, MenuAction:action, param1, param2) 
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		new String:info[64];

		GetMenuItem(menu, param2, info, sizeof(info));

		FakeClientCommand(param1, "sm_unwarn #%d %s", g_target[param1], info);
	}
}

BuildAgreement(client)
{
	new Handle:g_FilePath = OpenFile(pathagree, "rt");
	
	if (g_FilePath == INVALID_HANDLE)
	{
		LogWarnings("Could not find the config file (addons/sourcemod/configs/sm_warn_agreement.cfg)");
		return;
	}
 	
	new String:title[32], String:agree[32], String:g_Data[128];
	Format(title, sizeof(title), "[SM warn] %t", "warn_agreement_title");
	Format(agree, sizeof(agree), "%t", "warn_agreement_agree");

	new Handle:g_Menu = CreatePanel();
	
	SetPanelTitle(g_Menu, title);
	DrawPanelItem(g_Menu, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	while(!IsEndOfFile(g_FilePath) && ReadFileLine(g_FilePath, g_Data, sizeof(g_Data)))
	{
		DrawPanelText(g_Menu, g_Data);
	}

	DrawPanelItem(g_Menu, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	DrawPanelItem(g_Menu, agree);

	SendPanelToClient(g_Menu, client, MenuHandler_WarnAgreement, MENU_TIME_FOREVER);

	CloseHandle(g_Menu);

	CloseHandle(g_FilePath);
}

public MenuHandler_WarnAgreement(Handle:hMenu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		if(param2 == 1)
		{
			PrintToChat(param1, "\x03[Warn] \x01%t", "warn_agreement_message");
			SetEntityMoveType(param1, MOVETYPE_WALK);
		}
	}
}

PrintToAdmins(const String:format[], any:...)
{
	new String:g_Buffer[256];
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (CheckCommandAccess(i, "sm_warn_printtoadmins", ADMFLAG_BAN) && IsClientInGame(i))
		{
			VFormat(g_Buffer, sizeof(g_Buffer), format, 2);
			
			PrintToChat(i, "%s", g_Buffer);
		}
	}
}

LogWarnings(const String:format[], any:...)
{
	new String:g_Buffer[256], String:g_Path[100];
	
	VFormat(g_Buffer, sizeof(g_Buffer), format, 2);
	BuildPath(Path_SM, g_Path, sizeof(g_Path), "logs/SM_warn.log");

	LogToFileEx(g_Path, "%s", g_Buffer);
}
