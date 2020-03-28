#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include <influx/core>
#include <influx/teams>

#undef REQUIRE_PLUGIN
#include <influx/pause>


//#define DEBUG


// LIBRARIES
bool g_bLib_Pause;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Teams | Spawn Commands",
    description = "Handle spawn commands.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_spec", Cmd_Spec );
    RegConsoleCmd( "sm_spectate", Cmd_Spec );
    RegConsoleCmd( "sm_spectator", Cmd_Spec );
    
    RegConsoleCmd( "sm_spawn", Cmd_Spawn );
    RegConsoleCmd( "sm_respawn", Cmd_Spawn );
    
    
    // LIBRARIES
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
}

public void OnAllPluginsLoaded()
{
    //
    // HACK: Register with a delay, so we can make sure
    // the influx_teletorun cmds exist.
    //
    CreateTimer( 0.1, T_RegisterSpawnCmds );
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
    
    
    // Pause the run.
    if ( g_bLib_Pause && IsPlayerAlive( client ) && Influx_GetClientState( client ) == STATE_RUNNING )
    {
        Influx_PauseClientRun( client );
    }
    
    
    ChangeClientTeam( client, CS_TEAM_SPECTATOR );
    
    // They want to spectate somebody specific.
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
    if ( client && IsClientInGame( client ) && !IsPlayerAlive( client ) )
    {
#if defined DEBUG
        char szCmd[32];
        GetCmdArg( 0, szCmd, sizeof( szCmd ) );

        PrintToServer( INF_DEBUG_PRE..."Spawning player %N from cmd '%s'.",
            client,
            szCmd );
#endif

        Influx_SpawnPlayer( client );
    }

    return Plugin_Handled;
}

public Action Lstnr_Spawn( int client, const char[] command, int argc )
{
    if ( client && IsClientInGame( client ) && !IsPlayerAlive( client ) )
    {
#if defined DEBUG
        char szCmd[32];
        GetCmdArg( 0, szCmd, sizeof( szCmd ) );

        PrintToServer( INF_DEBUG_PRE..."Spawning player %N from cmd listener '%s'.",
            client,
            szCmd );
#endif

        Influx_SpawnPlayer( client );
    }
    
    return Plugin_Continue;
}

stock void ListenToSpawnCommand( const char[] cmd )
{
    // Reason why we use a listener is so that we hook before influx_teletorun restart commands.
    // This makes sure we have the intended behavior: spawn the player -> tele to run.
    // NOTE: Does no support late-loading.
    if ( CommandExists( cmd ) )
    {
        PrintToServer( INF_CON_PRE..."Listening for spawn command: %s", cmd );

        AddCommandListener( Lstnr_Spawn, cmd );
    }
    else
    {
        PrintToServer( INF_CON_PRE..."Registering possible restart cmd as spawn command: %s", cmd );

        RegConsoleCmd( cmd, Cmd_Spawn );
    }
}

stock void RegisterSpawnCmds()
{
    ListenToSpawnCommand( "sm_r" );
    ListenToSpawnCommand( "sm_re" );
    ListenToSpawnCommand( "sm_rs" );
    ListenToSpawnCommand( "sm_restart" );
    ListenToSpawnCommand( "sm_start" );
}

public Action T_RegisterSpawnCmds( Handle hTimer )
{
    RegisterSpawnCmds();
}
