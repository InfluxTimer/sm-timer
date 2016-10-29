#include <sourcemod>
#include <cstrike>

#include <influx/core>
#include <influx/pause>

#include <msharedutil/arrayvec>
#include <msharedutil/misc>

#undef REQUIRE_PLUGIN
#include <influx/help>
#include <influx/practise>
#include <influx/teams>


float g_flPauseLimit[INF_MAXPLAYERS];
int g_nPauses[INF_MAXPLAYERS];

float g_vecContinuePos[INF_MAXPLAYERS][3];
float g_vecContinueAng[INF_MAXPLAYERS][3];
char g_szPausedTargetName[INF_MAXPLAYERS][128];
int g_nPausedTicks[INF_MAXPLAYERS];
bool g_bPaused[INF_MAXPLAYERS];


bool g_bLib_Practise;
bool g_bLib_Teams;


ConVar g_ConVar_MaxPausesPerRun;
ConVar g_ConVar_Cooldown;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Pause",
    description = "Pause your run and continue later.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_PAUSE );
    
    // NATIVES
    CreateNative( "Influx_IsClientPaused", Native_IsClientPaused );
    CreateNative( "Influx_PauseClientRun", Native_PauseClientRun );
    CreateNative( "Influx_ContinueClientRun", Native_ContinueClientRun );
    CreateNative( "Influx_GetClientPausedTime", Native_GetClientPausedTime );
}

public void OnPluginStart()
{
    LoadTranslations( INFLUX_PHRASES );
    
    
    // CMDS
    RegConsoleCmd( "sm_pause", Cmd_Practise_Pause );
    RegConsoleCmd( "sm_continue", Cmd_Practise_Continue );
    RegConsoleCmd( "sm_resume", Cmd_Practise_Continue );
    
    
    // CONVARS
    g_ConVar_MaxPausesPerRun = CreateConVar( "influx_pause_maxperrun", "-1", "Maximum pauses per run. -1 = disable limit, 0 = disable completely", FCVAR_NOTIFY, true, -1.0 );
    g_ConVar_Cooldown = CreateConVar( "influx_pause_cooldown", "10", "How many seconds the player has to wait before being able to pause again.", FCVAR_NOTIFY, true, 0.0 );
    
    AutoExecConfig( true, "pause", "influx" );
    
    
    g_bLib_Practise = LibraryExists( INFLUX_LIB_PRACTISE );
    g_bLib_Teams = LibraryExists( INFLUX_LIB_TEAMS );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = true;
    if ( StrEqual( lib, INFLUX_LIB_TEAMS ) ) g_bLib_Teams = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = false;
    if ( StrEqual( lib, INFLUX_LIB_TEAMS ) ) g_bLib_Teams = false;
}

public void OnClientPutInServer( int client )
{
    g_bPaused[client] = false;
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "pause", "Pause your run." );
    Influx_AddHelpCommand( "continue/resume", "Continue your paused run." );
}

public void Influx_OnTimerResetPost( int client )
{
    g_bPaused[client] = false;
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    g_bPaused[client] = false;
    
    g_flPauseLimit[client] = 0.0;
    g_nPauses[client] = 0;
}

public Action Influx_OnTimerFinish( int client, int runid, int mode, int style, float time, int flags, char[] errormsg, int error_len )
{
    if ( g_bPaused[client] )
    {
        strcopy( errormsg, error_len, "You cannot finish the run while paused!" );
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Cmd_Practise_Continue( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( Influx_GetClientState( client ) == STATE_RUNNING && g_bPaused[client] )
    {
        ContinueRun( client );
    }
    else
    {
        Influx_PrintToChat( _, client, "%T", "NOTPAUSED", client );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Practise_Pause( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Influx_GetClientState( client ) != STATE_RUNNING )
    {
        Influx_PrintToChat( _, client, "%T", "MUSTBERUNNING", client );
        return Plugin_Handled;
    }
    
    
    if ( g_bPaused[client] )
    {
        ContinueRun( client );
    }
    else if ( !g_bLib_Practise || !Influx_IsClientPractising( client ) )
    {
        PauseRun( client );
    }
    else
    {
        Influx_PrintToChat( _, client, "%T", "CANTPAUSE_PRAC", client );
    }
    
    return Plugin_Handled;
}

stock void PauseRun( int client )
{
    if ( g_bPaused[client] ) return;
	
    if ( Influx_GetClientState( client ) != STATE_RUNNING )
    {
        Influx_PrintToChat( _, client, "%T", "MUSTBERUNNING", client );
        return;
    }
    
    
    if ( !IsPlayerAlive( client ) )
    {
        Influx_PrintToChat( _, client, "You must be alive to pause!" );
        return;
    }
    
    
    if ( g_flPauseLimit[client] > GetEngineTime() )
    {
        Influx_PrintToChat( _, client, "You cannot pause so soon! Please wait {MAINCLR1}%.1f{CHATCLR} seconds!", g_flPauseLimit[client] - GetEngineTime() );
        return;
    }
    
    
    int maxpauses = g_ConVar_MaxPausesPerRun.IntValue;
    
    if ( !maxpauses )
    {
        Influx_PrintToChat( _, client, "Pauses aren't allowed!" );
        return;
    }
    
    if ( maxpauses > 0 && g_nPauses[client] >= maxpauses )
    {
        Influx_PrintToChat( _, client, "You cannot pause more than %i time(s) every run!", maxpauses );
        return;
    }
    
    if ( g_bLib_Practise && Influx_IsClientPractising( client ) )
    {
        return;
    }
    
    
    g_nPauses[client]++;
    
    g_bPaused[client] = true;
    
    
    g_nPausedTicks[client] = GetGameTickCount() - Influx_GetClientStartTick( client );
    
    GetClientAbsOrigin( client, g_vecContinuePos[client] );
    GetClientEyeAngles( client, g_vecContinueAng[client] );
    
    g_vecContinueAng[client][2] = 0.0;
    
    GetEntPropString( client, Prop_Data, "m_iName", g_szPausedTargetName[client], sizeof( g_szPausedTargetName[] ) );

    Influx_PrintToChat( _, client, "Your run is now paused. Type {MAINCLR1}!continue{CHATCLR} to resume." );
}

stock void ContinueRun( int client )
{
    if ( !g_bPaused[client] ) return;
    
    
    // Spawn them if they are dead.
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR )
    {
        int team = ( g_bLib_Teams ) ? Influx_GetPreferredTeam() : CS_TEAM_CT;
        
        ChangeClientTeam( client, team );
    }
    
    if ( !IsPlayerAlive( client ) )
    {
        CS_RespawnPlayer( client );
    }
    
    
    // Spawning failed.
    if ( !IsPlayerAlive( client ) ) return;
    
    
    if ( g_bLib_Practise )
    {
        Influx_EndPractising( client );
    }
    
    
    g_bPaused[client] = false;
    
    
    // Make sure to reset our noclip so our timer don't stop.
    if ( GetEntityMoveType( client ) == MOVETYPE_NOCLIP )
    {
        SetEntityMoveType( client, MOVETYPE_WALK );
    }
    
    
    Influx_SetClientStartTick( client, GetGameTickCount() - g_nPausedTicks[client] );
    
    TeleportEntity( client, g_vecContinuePos[client], g_vecContinueAng[client], ORIGIN_VECTOR );
    
    
    g_flPauseLimit[client] = GetEngineTime() + g_ConVar_Cooldown.FloatValue;
    
    SetEntPropString( client, Prop_Data, "m_iName", g_szPausedTargetName[client] );

    Influx_PrintToChat( _, client, "Your run is no longer paused." );
}

public int Native_IsClientPaused( Handle hPlugin, int nParams )
{
    return g_bPaused[GetNativeCell( 1 )];
}

public int Native_PauseClientRun( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    PauseRun( client );
    
    return 1;
}

public int Native_ContinueClientRun( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    ContinueRun( client );
    
    return 1;
}

public int Native_GetClientPausedTime( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    
    if ( !g_bPaused[client] ) return view_as<int>( INVALID_RUN_TIME );
    
    
    return view_as<int>( TickCountToTime( g_nPausedTicks[client] ) );
}
