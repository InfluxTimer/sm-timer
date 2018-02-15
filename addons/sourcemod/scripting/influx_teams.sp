#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <influx/core>
#include <influx/teams>

#include <msharedutil/ents>

#undef REQUIRE_PLUGIN
#include <influx/pause>


//#define DEBUG


bool g_bLib_Pause;


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
    
    
    // Blocked commands
    // So you can spawn without setting class.
    if ( GetEngineVersion() == Engine_CSS )
    {
        AddCommandListener( Lstnr_JoinClass, "joinclass" );
    }
    
    AddCommandListener( Lstnr_JoinTeam, "jointeam" );
    
    
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
}

public void OnAllPluginsLoaded()
{
    ListenToSpawnCommand( "sm_r" );
    ListenToSpawnCommand( "sm_re" );
    ListenToSpawnCommand( "sm_rs" );
    ListenToSpawnCommand( "sm_restart" );
    ListenToSpawnCommand( "sm_start" );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
}

public Action Cmd_Spec( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( g_bLib_Pause && IsPlayerAlive( client ) && Influx_GetClientState( client ) == STATE_RUNNING )
    {
        Influx_PauseClientRun( client );
    }
    
    
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

stock int GetPreferredTeam()
{
    int spawns_ct, spawns_t;
    return Inf_GetPreferredTeam( spawns_ct, spawns_t );
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

stock void ListenToSpawnCommand( const char[] cmd )
{
    // Reason why we use a listener is so that we hook before influx_teletorun restart commands.
    // This makes sure we have the intended behavior: spawn the player -> tele to run.
    // NOTE: Does no support late-loading.
    if ( CommandExists( cmd ) )
        AddCommandListener( Lstnr_Spawn, cmd );
    else
        RegConsoleCmd( cmd, Cmd_Spawn );
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