#include <sourcemod>

#define PLUGIN_VERSION "1.2"

new Handle:db = INVALID_HANDLE;
new Handle:table_prefix = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name	= "MySQL Mapcycle",
	author	= "ecca",
	description	= "Allows you to control your mapcycle trough MySQL",
	version	= PLUGIN_VERSION,
	url		= "http://alliedmodders.se"
};

public OnPluginStart()
{
	CreateConVar("sm_mysql_mapcycle_version", PLUGIN_VERSION,  "The version of the SourceMod plugin MySQL Mapcycle, by ecca", FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_PLUGIN|FCVAR_NOTIFY);
	
	RegAdminCmd("sm_reloadmapcycle", ReloadMapcycleCallback, ADMFLAG_ROOT);
	
	table_prefix = CreateConVar("sm_mysql_mapcycle_table", "mapcycle", "Set the table name that plugin will use for the mapcycle", FCVAR_PLUGIN);
	
	AutoExecConfig(true, "sm_mysql_mapcycle");
	
	SQL_TConnect(SQL_OnConnect, "mapcycle");
}

public SQL_OnConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("[MySQL Mapcycle] Unable to connect to MySQL database, error: %s", error);
		
	} 
	else 
	{
		db = hndl;
		DownLoadTheMapCycle();
	}
}

public Action:ReloadMapcycleCallback(client, args)
{
	if(client > 0)
	{
		if(IsClientInGame(client))
		{
			new String:auth[64];
			GetClientAuthString(client, auth, sizeof(auth))
			LogMessage("%N (%s) started a download of the mapcycle", client, auth);
		}
	}
	else
	{
		LogMessage("Download of the mapcycle were started through a rcon command");
	}
	
	DownLoadTheMapCycle();
}

public SQL_LoadMaps(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("[MySQL Mapcycle] MySQL connection not found, loading current mapcycle.txt");
		return;
	}
	
	decl String:map[255];
	new TotalMaps = 0;
	
	if (SQL_GetRowCount(hndl) == 0)
	{
		PrintToServer("[MySQL Mapcycle] Unable to find any maps");
		return;
	}
	
	DeleteFile("mapcycle.txt");
	
	new Handle:file = OpenFile("mapcycle.txt", "a");
	
	while (SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 0, map, sizeof(map));
		
		TotalMaps++
		
		WriteFileLine(file, "%s", map);
	}
	
	PrintToServer("[MySQL Mapcycle] Loaded %d maps from MySQL", TotalMaps);
	
	CloseHandle(file);
}

public DownLoadTheMapCycle()
{
	decl String:table[256], String:query[255];

	GetConVarString(table_prefix, table, sizeof(table));
	
	Format(query,sizeof(query),"SELECT * from %s", table);
	
	SQL_TQuery(db, SQL_LoadMaps, query);
}