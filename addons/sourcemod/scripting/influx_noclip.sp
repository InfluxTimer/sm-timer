#include <sourcemod>

#include <influx/core>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>


#undef REQUIRE_PLUGIN
#include <influx/help>
#include <influx/practise>
#include <influx/pause>



ConVar g_ConVar_PauseTime;
ConVar g_ConVar_AutoPracticeMode;


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
    // CONVARS
    g_ConVar_PauseTime = CreateConVar( "influx_noclip_pausetime", "60", "How many seconds into the run do we pause the players run when starting to noclip. -1 = Disable", FCVAR_NOTIFY );
    g_ConVar_AutoPracticeMode = CreateConVar( "influx_noclip_setpracticemode", "1", "If the player starts noclipping, set them to practice mode (if not paused).", FCVAR_NOTIFY, true, 0.0 , true, 1.0 );

    AutoExecConfig( true, "noclip", "influx" );


    // CMDS
    RegConsoleCmd( "sm_noclip", Cmd_Noclip_Override );
    
    RegConsoleCmd( "sm_nc", Cmd_Noclip );
    RegConsoleCmd( "sm_fly", Cmd_Noclip );
    
    AddCommandListener( Lstnr_Noclip, "sm_noclip" );
    
    
    // LIBRARIES
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

public Action Lstnr_Noclip( int client, const char[] szCmd, int argc )
{
    // Attempting to use the funcommands noclip command.
    if ( argc )
    {
        return Plugin_Continue;
    }
    
    
    if ( client )
    {
        HandleNoclip( client );
    }
    
    return Plugin_Stop;
}

public Action Cmd_Noclip_Override( int client, int args )
{
    if ( args ) return Plugin_Continue;
    
    
    if ( client )
    {
        HandleNoclip( client );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Noclip( int client, int args )
{
    if ( client )
    {
        HandleNoclip( client );
    }
    
    return Plugin_Handled;
}
 
stock void HandleNoclip( int client )
{
    if ( !IsPlayerAlive( client ) )
    {
        Influx_PrintToChat( _, client, "You must be alive to use this command!" );
        return;
    }
    
    
    bool print = false;
    
    if ( GetEntityMoveType( client ) != MOVETYPE_NOCLIP )
    {
        // Were not in noclip right now.
        // Check if we should pause the run.
        
        RunState_t state = Influx_GetClientState( client );
        
        float time = ( state == STATE_RUNNING ) ? Influx_GetClientTime( client ) : INVALID_RUN_TIME;
        
        // If our run is long enough, just pause it instead of putting us to practise mode.
        float pausetime = g_ConVar_PauseTime.FloatValue;

        bool shouldpause = ( pausetime >= 0.0 && time >= pausetime );
        
        
        bool handled = false;
        
        // First check if we can pause.
        if ( shouldpause
        && g_bLib_Pause
        && !Influx_IsClientPaused( client )
        && !IS_PRAC( g_bLib_Practise, client ) )
        {
            Influx_PauseClientRun( client );
            
            handled = true;
            print = true;
        }
        
        // If that didn't work, just put us into practise mode.
        if (!handled
        &&  g_ConVar_AutoPracticeMode.BoolValue // If server wants this.
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
}

stock void ToggleNoclip( int client, bool bPrint = false )
{
    MoveType prevmove = GetEntityMoveType( client );
    
    SetEntityMoveType( client, ( prevmove == MOVETYPE_NOCLIP ) ? MOVETYPE_WALK : MOVETYPE_NOCLIP );
    
    
    // Don't let players cheat with noclip!
    if ( prevmove == MOVETYPE_NOCLIP && Influx_GetClientState( client ) == STATE_START )
    {
        Influx_InvalidateClientRun( client );
    }
    
    
    if ( bPrint )
    {
        Influx_PrintToChat( _, client, "Noclip: {MAINCLR1}%s",
            ( prevmove == MOVETYPE_NOCLIP ) ? "OFF" : "ON" );
    }
}
