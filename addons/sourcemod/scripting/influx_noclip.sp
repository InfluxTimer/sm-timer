#include <sourcemod>

#include <influx/core>
#include <influx/practise>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>


#undef REQUIRE_PLUGIN
#include <influx/help>
#include <influx/practise>
#include <influx/pause>



#define MIN_TIME_TO_PAUSE       60.0



// LIBRARIES
bool g_bLib_Practise;
bool g_bLib_Pause;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Noclip",
    description = "Let players use noclip.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_noclip", Cmd_Noclip );
    RegConsoleCmd( "sm_fly", Cmd_Noclip );
    
    
    g_bLib_Practise = LibraryExists( INFLUX_LIB_PRACTISE );
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = true;
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = false;
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "noclip", "Noclip without admin powers." );
}

public Action Cmd_Noclip( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( args )
    {
        char szArg[32];
        GetCmdArg( 0, szArg, sizeof( szArg ) );
        
        // Attempting to use the funcommands noclip command.
        if ( StrEqual( szArg, "sm_noclip" ) )
        {
            return Plugin_Handled;
        }
    }
    
    if ( !IsPlayerAlive( client ) )
    {
        Influx_PrintToChat( _, client, "You must be alive to use this command!" );
        return Plugin_Handled;
    }
    
    
    bool print = false;
    
    if ( GetEntityMoveType( client ) != MOVETYPE_NOCLIP )
    {
        // Were not in noclip right now.
        // Check if we should pause the run.
        
        RunState_t state = Influx_GetClientState( client );
        
        float time = ( state == STATE_RUNNING ) ? Influx_GetClientTime( client ) : INVALID_RUN_TIME;
        
        // If our run is long enough, just pause it instead of putting us to practise mode.
        bool shouldpause = ( time > MIN_TIME_TO_PAUSE );
        
        
        bool handled = false;
        
        // First check if we can pause.
        if ( shouldpause && g_bLib_Pause && !Influx_IsClientPaused( client ) )
        {
            Influx_PauseClientRun( client );
            
            handled = true;
            print = true;
        }
        
        // If that didn't work, just put us into practise mode.
        if (!handled
        &&  state == STATE_RUNNING
        &&  g_bLib_Practise
        &&  !Influx_IsClientPractising( client ))
        {
            Influx_StartPractising( client );
            
            print = true;
        }
    }
    
    // And finally, toggle the noclip!
    ToggleNoclip( client, print );
    
    return Plugin_Handled;
 }
 
 stock void ToggleNoclip( int client, bool bPrint = false )
 {
    MoveType prevmove = GetEntityMoveType( client );
    
    SetEntityMoveType( client, ( prevmove == MOVETYPE_NOCLIP ) ? MOVETYPE_WALK : MOVETYPE_NOCLIP );
    
    if ( bPrint )
    {
        Influx_PrintToChat( _, client, "Noclip: {TEAM}%s",
            ( prevmove == MOVETYPE_NOCLIP ) ? "OFF" : "ON" );
    }
 }