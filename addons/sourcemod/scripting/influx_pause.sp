#include <sourcemod>
#include <cstrike>

#include <influx/core>
#include <influx/pause>

#include <msharedutil/arrayvec>
#include <msharedutil/misc>
#include <msharedutil/ents>

#undef REQUIRE_PLUGIN
#include <influx/help>
#include <influx/practise>
#include <influx/teams>


float g_flPauseLimit[INF_MAXPLAYERS];
int g_nPauses[INF_MAXPLAYERS];

float g_vecContinuePos[INF_MAXPLAYERS][3];
float g_vecContinueAng[INF_MAXPLAYERS][3];
float g_vecContinueVel[INF_MAXPLAYERS][3];
int g_iPausedRunId[INF_MAXPLAYERS] = { -1, ... };
int g_iPausedModeId[INF_MAXPLAYERS] = { MODE_INVALID, ... };
int g_iPausedStyleId[INF_MAXPLAYERS] = { STYLE_INVALID, ... };
char g_szPausedClassname[INF_MAXPLAYERS][128];
char g_szPausedTargetName[INF_MAXPLAYERS][128];
float g_flPausedTime[INF_MAXPLAYERS];
bool g_bPaused[INF_MAXPLAYERS];


bool g_bLib_Practise;
bool g_bLib_Teams;


// FORWARDS
Handle g_hForward_OnClientPause;
Handle g_hForward_OnClientPausePost;
Handle g_hForward_OnClientContinue;
Handle g_hForward_OnClientContinuePost;


// CONVARS
ConVar g_ConVar_MaxPausesPerRun;
ConVar g_ConVar_Cooldown;
ConVar g_ConVar_UseVel;
ConVar g_ConVar_ForceSpectator;

// Are we in the continue process? For player spawn checking.
bool g_bInContinueProcess = false;


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
    
    
    // FORWARDS
    g_hForward_OnClientPause = CreateGlobalForward( "Influx_OnClientPause", ET_Hook, Param_Cell );
    g_hForward_OnClientPausePost = CreateGlobalForward( "Influx_OnClientPausePost", ET_Ignore, Param_Cell );
    g_hForward_OnClientContinue = CreateGlobalForward( "Influx_OnClientContinue", ET_Hook, Param_Cell );
    g_hForward_OnClientContinuePost = CreateGlobalForward( "Influx_OnClientContinuePost", ET_Ignore, Param_Cell );
    
    
    // CMDS
    RegConsoleCmd( "sm_pause", Cmd_Practise_Pause );
    RegConsoleCmd( "sm_continue", Cmd_Practise_Continue );
    RegConsoleCmd( "sm_resume", Cmd_Practise_Continue );


    // HOOKS
    HookEvent( "player_spawn", E_PlayerSpawn );
    
    
    // CONVARS
    g_ConVar_MaxPausesPerRun = CreateConVar( "influx_pause_maxperrun", "-1", "Maximum pauses per run. -1 = disable limit, 0 = disable completely", FCVAR_NOTIFY, true, -1.0 );
    g_ConVar_Cooldown = CreateConVar( "influx_pause_cooldown", "10", "How many seconds the player has to wait before being able to pause again.", FCVAR_NOTIFY, true, 0.0 );
    g_ConVar_UseVel = CreateConVar( "influx_pause_usevelocity", "0", "When player resumes, will their velocity also be set?", FCVAR_NOTIFY, true, 0.0 , true, 1.0 );
    g_ConVar_ForceSpectator = CreateConVar( "influx_pause_forcespectator", "0", "Forces the player to move to spectator team when pausing.", FCVAR_NOTIFY, true, 0.0 , true, 1.0 );

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

public void OnMapStart()
{
    g_bInContinueProcess = false;
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
    
    
    if ( g_bPaused[client] )
    {
        ContinueRun( client );
    }
    else
    {
        Influx_PrintToChat( _, client, "%T", "INF_NOTPAUSED", client );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Practise_Pause( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Influx_GetClientState( client ) != STATE_RUNNING )
    {
        Influx_PrintToChat( _, client, "%T", "INF_MUSTBERUNNING", client );
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
        Influx_PrintToChat( _, client, "%T", "INF_CANTPAUSE_PRAC", client );
    }
    
    return Plugin_Handled;
}

stock bool PauseRun( int client )
{
    if ( g_bPaused[client] ) return true;
	
    if ( Influx_GetClientState( client ) != STATE_RUNNING )
    {
        Influx_PrintToChat( _, client, "%T", "INF_MUSTBERUNNING", client );
        return false;
    }
    
    
    if ( !IsPlayerAlive( client ) )
    {
        Influx_PrintToChat( _, client, "%T", "INF_MUSTBEALIVE", client );
        return false;
    }
    
    
    if ( g_flPauseLimit[client] > GetEngineTime() )
    {
        Influx_PrintToChat( _, client, "%T",
            "INF_PAUSENOTSOFAST",
            client,
            RoundFloat( g_flPauseLimit[client] - GetEngineTime() ) );
        return false;
    }
    
    
    int maxpauses = g_ConVar_MaxPausesPerRun.IntValue;
    
    if ( !maxpauses )
    {
        Influx_PrintToChat( _, client, "%T", "INF_PAUSENOTALLOWED", client );
        return false;
    }
    
    if ( maxpauses > 0 && g_nPauses[client] >= maxpauses )
    {
        Influx_PrintToChat( _, client, "%T", "INF_PAUSELIMIT", client, maxpauses );
        return false;
    }
    
    if ( g_bLib_Practise && Influx_IsClientPractising( client ) )
    {
        return false;
    }
    

    int runid = Influx_GetClientRunId( client );
    int modeid = Influx_GetClientMode( client );
    int styleid = Influx_GetClientStyle( client );

    if ( Influx_FindRunById( runid ) == -1 || modeid == MODE_INVALID || styleid == STYLE_INVALID )
    {
        return false;
    }

    
    // Ask other plugins if we should allow pausing.
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnClientPause );
    Call_PushCell( client );
    Call_Finish( res );
    
    if ( res != Plugin_Continue )
    {
        return false;
    }
    
    

    


    
    g_nPauses[client]++;
    
    g_bPaused[client] = true;

    g_iPausedRunId[client] = runid;
    g_iPausedModeId[client] = modeid;
    g_iPausedStyleId[client] = styleid;
    
    
    g_flPausedTime[client] = Influx_GetClientTime( client );
    
    GetClientAbsOrigin( client, g_vecContinuePos[client] );
    GetClientEyeAngles( client, g_vecContinueAng[client] );
    
    g_vecContinueAng[client][2] = 0.0;
    
    GetEntityAbsVelocity( client, g_vecContinueVel[client] );
    
    GetEntPropString( client, Prop_Data, "m_iName", g_szPausedTargetName[client], sizeof( g_szPausedTargetName[] ) );
    GetEntityClassname( client, g_szPausedClassname[client], sizeof( g_szPausedClassname[] ) );

    Influx_PrintToChat( _, client, "%T", "INF_NOWPAUSED", client );
    
    
    // Send success post.
    Call_StartForward( g_hForward_OnClientPausePost );
    Call_PushCell( client );
    Call_Finish();


    if ( g_ConVar_ForceSpectator.BoolValue )
    {
        ChangeClientTeam( client, CS_TEAM_SPECTATOR );
    }
    
    return true;
}

stock bool ContinueRun( int client )
{
    if ( !g_bPaused[client] ) return true;
    
    
    // Ask other plugins if we should allow continuing.
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnClientContinue );
    Call_PushCell( client );
    Call_Finish( res );
    
    if ( res != Plugin_Continue )
    {
        return false;
    }
    
    
    // This is for the player spawn check.
    g_bInContinueProcess = true;

    
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
    

    g_bInContinueProcess = false;
    
    // Spawning failed.
    if ( !IsPlayerAlive( client ) ) return false;
    
    
    if ( g_bLib_Practise )
    {
        Influx_EndPractising( client );
    }
    
    
    g_bPaused[client] = false;

    if (    !Influx_SetClientRun( client, g_iPausedRunId[client] )
        ||  !Influx_SetClientMode( client, g_iPausedModeId[client] )
        ||  !Influx_SetClientStyle( client, g_iPausedStyleId[client] ))
    {
        LogError( INF_CON_PRE..."Failed to set client's run/mode/style when continuing a previous run!" );
        return false;
    }

    
    
    // Make sure to reset our noclip so our timer don't stop.
    if ( GetEntityMoveType( client ) == MOVETYPE_NOCLIP )
    {
        SetEntityMoveType( client, MOVETYPE_WALK );
    }
    
    
    Influx_SetClientState( client, STATE_RUNNING );
    
    Influx_SetClientTime( client, g_flPausedTime[client] );
    
    
    float vel[3];
    vel = ( g_ConVar_UseVel.BoolValue ) ? g_vecContinueVel[client] : ORIGIN_VECTOR;
    
    
    TeleportEntity( client, g_vecContinuePos[client], g_vecContinueAng[client], vel );
    
    
    g_flPauseLimit[client] = GetEngineTime() + g_ConVar_Cooldown.FloatValue;
    
    SetEntPropString( client, Prop_Data, "m_iName", g_szPausedTargetName[client] );
    SetEntityClassname( client, g_szPausedClassname[client] );

    Influx_PrintToChat( _, client, "%T", "INF_NOLONGERPAUSED", client );
    
    
    // Send success post.
    Call_StartForward( g_hForward_OnClientContinuePost );
    Call_PushCell( client );
    Call_Finish();
    
    return true;
}

public void E_PlayerSpawn( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    if ( !g_ConVar_ForceSpectator.BoolValue )
        return;

    // We are currently being continued. Ignore.
    if ( g_bInContinueProcess )
        return;

    if ( g_bPaused[client] )
    {
        g_bPaused[client] = false;

        Influx_PrintToChat( _, client, "%T", "INF_NOLONGERPAUSED", client );
    }
}

public int Native_IsClientPaused( Handle hPlugin, int nParams )
{
    return g_bPaused[GetNativeCell( 1 )];
}

public int Native_PauseClientRun( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    return PauseRun( client );
}

public int Native_ContinueClientRun( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    return ContinueRun( client );
}

public int Native_GetClientPausedTime( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    
    if ( !g_bPaused[client] ) return view_as<int>( INVALID_RUN_TIME );
    
    
    return view_as<int>( g_flPausedTime[client] );
}
