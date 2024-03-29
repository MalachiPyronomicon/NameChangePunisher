/* Plugin Template generated by Pawn Studio */
#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <sourcebans>

#define VERSION "1.1.2"


public Plugin:myinfo = 
{
	name = "Name Change Punisher (by Map Mod)",
	author = "Powerlord (mods by Malachi)",
	description = "If a user changes names too many many times on a single map, kick or ban them.",
	version = VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=161320"
}


// These are synchronized arrays
new g_NameChangeCount[MAXPLAYERS+1];

new bool:g_UseSourcebans = false;

new Handle:g_Cvar_PunishMode = INVALID_HANDLE;
new Handle:g_Cvar_Detections = INVALID_HANDLE;
new Handle:g_Cvar_BanLength = INVALID_HANDLE;
new Handle:g_Cvar_Debug = INVALID_HANDLE;


public OnPluginStart()
{
	g_Cvar_Detections = CreateConVar("ncp_detections", "5", "Number of detections before taking action", FCVAR_NONE, true, 3.0, true, 20.0);
	g_Cvar_PunishMode = CreateConVar("ncp_punishmode", "1", "Punish mode. 0 is Kick, 1 is Ban.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_Cvar_BanLength = CreateConVar("ncp_banlength", "60", "If ncp_punishmode is 1, how many minutes to ban for? 0 means indefinitely.", FCVAR_NONE, true, 0.0);
	g_Cvar_Debug = CreateConVar("ncp_debug", "1", "Show debugging messages.", FCVAR_NONE, true, 0.0, true, 1.0);
	
	CreateConVar("ncp_version", VERSION, "Name Change Punisher version", FCVAR_REPLICATED | FCVAR_DONTRECORD | FCVAR_SPONLY);
	AutoExecConfig(true, "namechangepunisher");
	HookEvent("player_changename", OnNameChange);
	LoadTranslations("namechangepunisher.phrases");
}


// One of these two is necessary, the other is redundant.  However, do both just in case.
public OnClientPutInServer(client)
{
	ResetClient(client);
}


// One of these two is necessary, the other is redundant.  However, do both just in case.
public OnClientDisconnect(client)
{
	ResetClient(client);
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
}


ResetClient(client)
{
	g_NameChangeCount[client] = 0;
}


ResetAllClients()
{
	
	for (new i = 0; i < sizeof(g_NameChangeCount); i++)
	{
		g_NameChangeCount[i] = 0;
	}
}


// Every map we reset the name change counters.
public OnMapStart()
{
	ResetAllClients();
}


public Action:OnNameChange(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userId = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userId);

	if (IsClientInGame(client) && !IsFakeClient(client))
	{

		decl String:userName[MAX_NAME_LENGTH];
		GetEventString(event, "newname", userName, sizeof(userName));

		// Increment name change count
		++g_NameChangeCount[client];
		
		// Did player go over the limit?
		if (g_NameChangeCount[client] >= GetConVarInt(g_Cvar_Detections))
		{
			// The number of name changes is too great
			if (GetConVarBool(g_Cvar_PunishMode))
			{
				// Ban
				decl String:banReason[100];
				decl String:kickReason[100];
				Format(banReason, sizeof(banReason), "%T", "Ban Reason", LANG_SERVER);
				Format(kickReason, sizeof(kickReason), "%T", "Kick Reason", client);
				if (g_UseSourcebans)
				{
					SBBanPlayer(0, client, GetConVarInt(g_Cvar_BanLength), banReason);
				}
				else
				{
					BanClient(client, GetConVarInt(g_Cvar_BanLength), BANFLAG_AUTO, banReason, kickReason, "ncp");
				}
				
				if (GetConVarBool(g_Cvar_Debug))
				{
					LogMessage("Banned %s (%d) for having %d name changes.", userName, userId, g_NameChangeCount[client]);
				}


				// Tell admins about  ban
				for (new iAdm = 1; iAdm <= MaxClients; iAdm++)
				{
					if (IsClientInGame(iAdm))
					{
						// print only to admins
						if (GetUserAdmin(iAdm) != INVALID_ADMIN_ID)
						{
							PrintToChat(iAdm, "[NameChangePunisher] \x04(ADMINS) \x01Banned %s (%d) for having %d name changes.", userName, userId, g_NameChangeCount[client]);
						}	
					}

				}
				

			}
			else
			{
				// Kick
				KickClient(client, "%t", "Kick Reason");
				
				if (GetConVarBool(g_Cvar_Debug))
				{
					LogMessage("Kicked %s (%d) for having %d name changes.", userName, userId, g_NameChangeCount[client]);
				}
			
				// Tell admins about kick
				for (new iAdm = 1; iAdm <= MaxClients; iAdm++)
				{
					if (IsClientInGame(iAdm))
					{
						// print only to admins
						if (GetUserAdmin(iAdm) != INVALID_ADMIN_ID)
						{
							PrintToChat(iAdm, "[NameChangePunisher] \x04(ADMINS) \x01Kicked %s (%d) for having %d name changes.", userName, userId, g_NameChangeCount[client]);
						}	
					}
				}

			
			}
		}
		else
		{
			
			// Warn Player if he approaches the limit
			if ( (g_NameChangeCount[client]+1) == GetConVarInt(g_Cvar_Detections))
			{
				PrintToChat (client, "WARNING: Name change limit reached.");
			}
			
			if (GetConVarBool(g_Cvar_Debug))
			{
				LogMessage("%s (%d) changed names %d times.", userName, userId, g_NameChangeCount[client]);
			}
		}


	}

	return Plugin_Continue; // Not necessary as this is a Post Event, but good form
}
