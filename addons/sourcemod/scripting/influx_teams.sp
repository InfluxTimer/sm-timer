#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <influx/core>
#include <influx/teams>

#include <msharedutil/ents>

//#undef REQUIRE_PLUGIN
//#include <influx/help>


//#define DEBUG
//#define USE_LEVELINIT

int g_nSpawns_CT;
int g_nSpawns_T;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Teams",
    description = "Handle teams and spawn commands.",
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
    // CMDS
    RegConsoleCmd( "sm_spec", Cmd_Spec );
    RegConsoleCmd( "sm_spectate", Cmd_Spec );
    RegConsoleCmd( "sm_spectator", Cmd_Spec );
    
    RegConsoleCmd( "sm_spawn", Cmd_Spawn );
    RegConsoleCmd( "sm_respawn", Cmd_Spawn );
    
    
    AddCommandListener( Lstnr_Spawn, "sm_r" );
    AddCommandListener( Lstnr_Spawn, "sm_re" );
    AddCommandListener( Lstnr_Spawn, "sm_rs" );
    AddCommandListener( Lstnr_Spawn, "sm_restart" );
    AddCommandListener( Lstnr_Spawn, "sm_start" );
    
    
    
    // Blocked commands
    // So you can spawn without setting class.
    if ( GetEngineVersion() == Engine_CSS )
    {
        AddCommandListener( Lstnr_JoinClass, "joinclass" );
    }
    
    AddCommandListener( Lstnr_JoinTeam, "jointeam" );
}

#if defined USE_LEVELINIT
public Action OnLevelInit( const char[] mapName, char mapEntities[2097152] )
#else
public void OnMapStart()
#endif
{
    GetSpawnCounts();
    
#if defined USE_LEVELINIT
    return Plugin_Continue;
#endif
}

public Action Cmd_Spec( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    ChangeClientTeam( client, CS_TEAM_SPECTATOR );
    
    if ( args )
    {
        // Attempt to find a name.
        char szArg[32];
        GetCmdArgString( szArg, sizeof( szArg ) );
        
        int targets[1];
        char szTemp[1];
        bool bUseless;
        if ( ProcessTargetString(
            szArg,
            0,
            targets,
            sizeof( targets ),
            COMMAND_FILTER_NO_MULTI,
            szTemp,
            sizeof( szTemp ),
            bUseless ) )
        {
            int target = targets[0];
            
            if (target != client
            &&  IS_ENT_PLAYER( target )
            &&  IsClientInGame( target )
            &&  IsPlayerAlive( target ) )
            {
                if ( GetClientObserverTarget( client ) != target )
                {
                    SetClientObserverTarget( client, target );
                    
                    Influx_PrintToChat( _, client, "You are now spectating {MAINCLR1}%N{CHATCLR}!", target );
                }
                
                SetClientObserverMode( client, OBS_MODE_IN_EYE );
            }
        }
    }
    
    return Plugin_Handled;
}

public Action Cmd_Spawn( int client, int args )
{
    if ( client )
    {
        SpawnPlayer( client );
    }
    
    return Plugin_Handled;
}

public Action Lstnr_Spawn( int client, const char[] command, int argc )
{
    if ( client && IsClientInGame( client ) )
    {
        SpawnPlayer( client );
    }
    
    return Plugin_Continue;
}

public Action Lstnr_JoinClass( int client, const char[] command, int argc )
{
    return ( IsPlayerAlive( client ) ) ? Plugin_Handled : Plugin_Continue;
}

public Action Lstnr_JoinTeam( int client, const char[] command, int argc )
{
    return ( IsPlayerAlive( client ) ) ? Plugin_Handled : Plugin_Continue;
}

stock void GetSpawnCounts()
{
    g_nSpawns_CT = 0;
    g_nSpawns_T = 0;
    
    int ent = -1;
    while ( (ent = FindEntityByClassname( ent, "info_player_counterterrorist" )) != -1 ) g_nSpawns_CT++;
    ent = -1;
    while ( (ent = FindEntityByClassname( ent, "info_player_terrorist" )) != -1 ) g_nSpawns_T++;
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Found %i CT and %i T spawns!", g_nSpawns_CT, g_nSpawns_T );
#endif
}

stock int GetPreferredTeam()
{
    if ( g_nSpawns_CT <= 0 && g_nSpawns_T <= 0 )
    {
        GetSpawnCounts();
    }
    
    if ( GetTeamClientCount( CS_TEAM_CT ) < g_nSpawns_CT )
    {
        return CS_TEAM_CT;
    }
    else if ( GetTeamClientCount( CS_TEAM_T ) < g_nSpawns_T )
    {
        return CS_TEAM_T;
    }
    else // Our spawns are full!
    {
        // Check if there are any bots to take over.
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) && GetClientTeam( i ) > CS_TEAM_SPECTATOR && IsFakeClient( i ) )
            {
                return GetClientTeam( i );
            }
        }
    }
    
    LogError( INF_CON_PRE..."Couldn't find optimal team to join! Assuming CT." );
    
    // Else, return default.
    return CS_TEAM_CT;
}

stock void SpawnPlayer( int client )
{
    if ( IsPlayerAlive( client ) ) return;
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Spawning client %i!", client );
#endif
    
    int team = GetPreferredTeam();
    
    if ( GetClientTeam( client ) != team )
    {
        ChangeClientTeam( client, team );
    }
    
    if ( !IsPlayerAlive( client ) )
    {
        CS_RespawnPlayer( client );
    }
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