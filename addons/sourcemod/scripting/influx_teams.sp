#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <influx/core>
#include <influx/teams>

#include <msharedutil/ents>


//#define DEBUG


ConVar g_ConVar_BalanceTeams;
ConVar g_ConVar_PreferredTeam;
ConVar g_ConVar_BlockTeamCmds;

ConVar g_ConVar_LimitTeams;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Teams",
    description = "Handles spawn commands.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_TEAMS );
    
    
    // NATIVES
    CreateNative( "Influx_GetPreferredTeam", Native_GetPreferredTeam );
    CreateNative( "Influx_SpawnPlayer", Native_SpawnPlayer );
}

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_BalanceTeams = CreateConVar( "influx_teams_balanceteams", "0", "0 = use mp_limitteams cvar's value. 1 = Balance teams. 2 = Always use preferred team first.", FCVAR_NOTIFY );
    g_ConVar_PreferredTeam = CreateConVar( "influx_teams_preferredteam", "0", "0 = CT, 1 = T", FCVAR_NOTIFY );
    g_ConVar_BlockTeamCmds = CreateConVar( "influx_teams_blockteamcmds", "1", "Whether to block the joinclass and jointeam commands. NOTE: If you disable this, the player may die. (CSS)", FCVAR_NOTIFY );
    
    AutoExecConfig( true, "teams", "influx" );
    
    
    g_ConVar_LimitTeams = FindConVar( "mp_limitteams" );

    
    
    // Blocked commands
    // So you can spawn without setting class.
    if ( GetEngineVersion() == Engine_CSS )
    {
        AddCommandListener( Lstnr_JoinClass, "joinclass" );
    }
    
    AddCommandListener( Lstnr_JoinTeam, "jointeam" );
}

public Action Lstnr_JoinClass( int client, const char[] command, int argc )
{
    return ( BlockTeamCmd( client ) ) ? Plugin_Handled : Plugin_Continue;
}

public Action Lstnr_JoinTeam( int client, const char[] command, int argc )
{
    return ( BlockTeamCmd( client ) ) ? Plugin_Handled : Plugin_Continue;
}

stock int GetPreferredTeam()
{
    bool balance = false;
    switch ( g_ConVar_BalanceTeams.IntValue )
    {
        case 0 : balance = ( g_ConVar_LimitTeams && g_ConVar_LimitTeams.BoolValue );
        case 1 : balance = true;
        case 2 : balance = false;
    }
    
    
    int iPreferredTeam = g_ConVar_PreferredTeam.IntValue == 0 ? CS_TEAM_CT : CS_TEAM_T;
    
    
    int spawns_ct, spawns_t;
    // Check for spawn points.
    int iBalancedTeam = Inf_GetPreferredTeam( spawns_ct, spawns_t, balance, iPreferredTeam );

    // No spawnpoints left. Assume preferred team.
    if ( iBalancedTeam == CS_TEAM_NONE )
    {
        LogError( INF_CON_PRE..."Map does not have enough spawnpoints for all players. Assuming cvar team." );
        return iPreferredTeam;
    }

    return iBalancedTeam;
}

stock void SpawnPlayer( int client )
{
    if ( IsPlayerAlive( client ) ) return;
    
    
    int team = GetPreferredTeam();
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Spawning client %i on team %i!", client, team );
#endif
    
    if ( GetClientTeam( client ) != team )
    {
        ChangeClientTeam( client, team );
    }
    
    if ( !IsPlayerAlive( client ) )
    {
        CS_RespawnPlayer( client );
    }
}

stock bool BlockTeamCmd( int client )
{
    if ( !g_ConVar_BlockTeamCmds.BoolValue )
        return false;
    
    return IsClientInGame( client ) && IsPlayerAlive( client );
}

// NATIVES
public int Native_GetPreferredTeam( Handle hPlugin, int nParms )
{
    return GetPreferredTeam();
}

public int Native_SpawnPlayer( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    SpawnPlayer( client );
    
    return 1;
}