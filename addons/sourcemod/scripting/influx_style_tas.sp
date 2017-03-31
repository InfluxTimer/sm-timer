#include <sourcemod>
#include <sdktools>

#include <influx/core>
#include <influx/recording>
#include <influx/style_tas>

#include <influx/stocks_strf>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>


#undef REQUIRE_PLUGIN
#include <influx/pause>
#include <influx/practise>



//#define DEBUG_THINK



#define FRM_CLASSNAME_SIZE          32
#define FRM_CLASSNAME_SIZE_CELL     FRM_CLASSNAME_SIZE / 4

#define FRM_TARGETNAME_SIZE         32
#define FRM_TARGETNAME_SIZE_CELL    FRM_TARGETNAME_SIZE / 4

enum
{
    FRM_POS[3] = 0,
    FRM_ANG[2],
    
    FRM_VEL[3],
    FRM_BASEVEL[3],
    
    FRM_MOVETYPE,
    FRM_GROUNDENT,
    FRM_ENTFLAGS,
    
    FRM_TARGETNAME[FRM_TARGETNAME_SIZE_CELL],
    FRM_CLASSNAME[FRM_CLASSNAME_SIZE_CELL],
    
    FRM_SIZE
};


ArrayList g_hFrames[INF_MAXPLAYERS];

bool g_bStopped[INF_MAXPLAYERS];
int g_iStoppedFrame[INF_MAXPLAYERS];

int g_iPlayback[INF_MAXPLAYERS];

float g_flTimescale[INF_MAXPLAYERS];

bool g_bAutoStrafe[INF_MAXPLAYERS];


// CONVARS
ConVar g_ConVar_Timescale;
ConVar g_ConVar_Cheats;


bool g_bLate;



#include "influx_style_tas/cmds.sp"
#include "influx_style_tas/menus.sp"
#include "influx_style_tas/natives.sp"


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - TAS",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    RegPluginLibrary( INFLUX_LIB_STYLE_TAS );
    
    
    g_bLate = late;
    
    
    // NATIVES
    CreateNative( "Influx_GetClientTASTime", Native_GetClientTASTime );
}

public void OnPluginStart()
{
    // CONVARS
    if ( (g_ConVar_Timescale = FindConVar( "host_timescale" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for host_timescale!" );
    }
    
    if ( (g_ConVar_Cheats = FindConVar( "sv_cheats" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_cheats!" );
    }
    
    g_ConVar_Timescale.Flags &= ~(FCVAR_REPLICATED | FCVAR_CHEAT);
    
    
    // CMDS
    RegConsoleCmd( "sm_tas", Cmd_Style_Tas, "Change your style to TAS (tool assisted speedrun)." );
    RegConsoleCmd( "sm_toolassisted", Cmd_Style_Tas );
    
    RegConsoleCmd( "sm_tas_continue", Cmd_Continue );
    RegConsoleCmd( "sm_tas_stop", Cmd_Stop );
    
    RegConsoleCmd( "sm_tas_fwd", Cmd_Forward );
    RegConsoleCmd( "sm_tas_bwd", Cmd_Backward );
    
    RegConsoleCmd( "sm_tas_nextframe", Cmd_NextFrame );
    RegConsoleCmd( "sm_tas_prevframe", Cmd_PrevFrame );
    
    RegConsoleCmd( "sm_tas_inctimescale", Cmd_IncTimescale );
    RegConsoleCmd( "sm_tas_dectimescale", Cmd_DecTimescale );
    RegConsoleCmd( "sm_tas_autostrafe", Cmd_AutoStrafe );
    
    
    // MENUS
    RegConsoleCmd( "sm_tas_menu", Cmd_TasMenu );
    RegConsoleCmd( "sm_tas_settings", Cmd_Settings );
    RegConsoleCmd( "sm_tas_listcmds", Cmd_ListCmds );
    
    
    // EVENTS
    HookEvent( "player_team", E_PlayerTeamNDeath );
    HookEvent( "player_death", E_PlayerTeamNDeath );
    
    
    if ( g_bLate )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) )
            {
                OnClientPutInServer( i );
            }
        }
    }
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_TAS, "Tool Assisted", "TAS" ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_TAS );
    
    
    g_ConVar_Timescale.FloatValue = 1.0;
    g_ConVar_Timescale.Flags |= (FCVAR_REPLICATED | FCVAR_CHEAT);
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return;
    
    
    delete g_hFrames[client];
    
    
    g_hFrames[client] = new ArrayList( FRM_SIZE );
    
    
    ResetClient( client );
}

public void Influx_OnTimerResetPost( int client )
{
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return;
    
    
    UnfreezeClient( client );
    
    ResetClient( client );
}

public Action Influx_OnClientPause( int client )
{
    if ( Influx_GetClientStyle( client ) == STYLE_TAS )
    {
        Influx_PrintToChat( _, client, "You cannot pause in TAS style!" );
        return Plugin_Stop;
    }
    
    
    return Plugin_Continue;
}

public Action Influx_OnClientPracticeStart( int client )
{
    if ( Influx_GetClientStyle( client ) == STYLE_TAS )
    {
        Influx_PrintToChat( _, client, "You cannot practice in TAS style!" );
        return Plugin_Stop;
    }
    
    
    return Plugin_Continue;
}

public Action Influx_OnRecordingStart( int client )
{
    return ( Influx_GetClientStyle( client ) == STYLE_TAS ) ? Plugin_Stop : Plugin_Continue;
}

public Action Influx_OnRecordingFinish( int client, ArrayList hRecording )
{
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Continue;
    
    if ( g_hFrames[client] == null ) return Plugin_Continue;
    
    if ( hRecording == null ) return Plugin_Continue;
    
    
    hRecording.Clear();
    
    decl framedata[FRM_SIZE];
    decl recdata[REC_SIZE];
    
    int len = g_hFrames[client].Length;
    for ( int i = 0; i < len; i++ )
    {
        g_hFrames[client].GetArray( i, framedata );
        
        CopyArray( framedata[FRM_POS], recdata[REC_POS], 3 );
        CopyArray( framedata[FRM_ANG], recdata[REC_ANG], 2 );
        
        
        recdata[REC_FLAGS] = 0;
        
        if ( framedata[FRM_ENTFLAGS] & FL_DUCKING )
        {
            recdata[REC_FLAGS] |= RECFLAG_CROUCH;
        }
        
        hRecording.PushArray( recdata );
    }
    
    
    return Plugin_Handled;
}

public Action Influx_OnClientStyleChange( int client, int style, int laststyle )
{
    if ( style == STYLE_TAS )
    {
        UnhookThinks( client );
        
        
        if ( !Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client ) )
        {
            return Plugin_Handled;
        }
        
        if ( !Inf_SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client ) )
        {
            UnhookThinks( client );
            return Plugin_Handled;
        }
    }
    else if ( laststyle == STYLE_TAS )
    {
        UnhookThinks( client );
        
        UnfreezeClient( client );
        
        SetTimescale( client, 1.0, false );
    }
    
    return Plugin_Continue;
}

stock void UnhookThinks( int client )
{
    SDKUnhook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
    SDKUnhook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
}

public void Influx_OnClientStyleChangePost( int client, int style, int laststyle )
{
    if ( style == STYLE_TAS )
    {
        OpenMenu( client );
    }
}

public void OnClientPutInServer( int client )
{
    ResetClient( client );
    
    
    SetTimescale( client, 1.0, false );
    
    g_bAutoStrafe[client] = false;
}

public void OnClientDisconnect( int client )
{
    delete g_hFrames[client];
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if ( StrEqual( szArg, "tas", false ) )
    {
        value = STYLE_TAS;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public void E_PreThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PreThinkPost - TAS (timescale: %.1f)", g_flTimescale[client] );
#endif

    if ( !IsPlayerAlive( client ) ) return;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return;
    
    
    g_ConVar_Timescale.FloatValue = g_flTimescale[client];
}

public void E_PostThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PostThinkPost - TAS (timescale: %.1f)", g_flTimescale[client] );
#endif

    if ( !IsPlayerAlive( client ) ) return;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return;
    
    
    if ( Influx_GetClientState( client ) == STATE_RUNNING )
    {
        InsertFrame( client );
        
        if ( g_iPlayback[client] && g_bStopped[client] )
        {
            SetFrame( client, g_iStoppedFrame[client] + g_iPlayback[client], false );
        }
    }
    
    g_ConVar_Timescale.FloatValue = 1.0;
    
    // HACK
    Influx_SetClientStartTick( client, GetGameTickCount() - (g_iStoppedFrame[client] + 1) );
}

public void E_PlayerTeamNDeath( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !client ) return;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return;
    
    
    SetTimescale( client, 1.0, false );
}

#define UPDATE_YAW      flLastYaw[client] = angles[1];

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3] )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    if ( !g_bAutoStrafe[client] ) return Plugin_Continue;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Continue;
    
    
    static float flLastYaw[INF_MAXPLAYERS];
    //static float flLastLegitYaw[INF_MAXPLAYERS];
    
    
    if (GetEntityFlags( client ) & FL_ONGROUND
    ||  vel[0] != 0.0
    ||  vel[1] != 0.0)
    {
        UPDATE_YAW
        //flLastLegitYaw[client] = angles[1];
        
        return Plugin_Continue;
    }
    
    
    
    Strafe_t strf = GetStrafe( angles[1], flLastYaw[client], 75.0 );
    
    
    decl Float:vec[3];
    GetEntityVelocity( client, vec );
    
    NormalizeVector( vec, vec );
    
    float yaw = RadToDeg( ArcTangent2( vec[1], vec[0] ) );
    
    
    if ( strf == STRF_RIGHT )
    {
        vel[1] = 400.0;
    }
    else
    {
        vel[1] = -400.0;
    }
    
    
    //flLastLegitYaw[client] = angles[1];
    
    
    angles[1] = yaw;
    
    
    UPDATE_YAW
    
    return Plugin_Continue;
}

stock void InsertFrame( int client )
{
    if ( g_hFrames[client] == null ) return;
    
    if ( g_bStopped[client] ) return;
    
    
    
    decl Float:vec[3];
    
    static int data[FRM_SIZE];
    
    GetClientAbsOrigin( client, vec );
    CopyArray( vec, data[FRM_POS], 3 );
    
    GetClientEyeAngles( client, vec );
    CopyArray( vec, data[FRM_ANG], 2 );
    
    GetEntityVelocity( client, vec );
    CopyArray( vec, data[FRM_VEL], 3 );
    
    GetEntityBaseVelocity( client, vec );
    CopyArray( vec, data[FRM_BASEVEL], 3 );
    
    
    data[FRM_MOVETYPE] = view_as<int>( GetEntityMoveType( client ) );
    data[FRM_GROUNDENT] = GetEntPropEnt( client, Prop_Data, "m_hGroundEntity" );
    data[FRM_ENTFLAGS] = GetEntityFlags( client );
    
    
    GetEntityName( client, view_as<char>( data[FRM_TARGETNAME] ), FRM_TARGETNAME_SIZE );
    GetEntityClassname( client, view_as<char>( data[FRM_CLASSNAME] ), FRM_CLASSNAME_SIZE );
    
    g_iStoppedFrame[client] = g_hFrames[client].PushArray( data );
}

stock bool SetFrame( int client, int i, bool bContinue, bool bPrint = false )
{
    if ( g_hFrames[client] == null ) return false;
    
    if ( i < 0 || i >= g_hFrames[client].Length ) return false;
    
    
    decl Float:pos[3];
    decl Float:ang[3];
    decl Float:vel[3];
    
    static int data[FRM_SIZE];
    
    g_hFrames[client].GetArray( i, data );
    
    CopyArray( data[FRM_POS], pos, 3 );
    CopyArray( data[FRM_ANG], ang, 2 );
    ang[2] = 0.0;
    CopyArray( data[FRM_VEL], vel, 3 );
    
    
    if ( !bContinue )
    {
        StopClient( client );
        
        TeleportEntity( client, pos, ang, vel );
    }
    else
    {
        SetEntityMoveType( client, view_as<MoveType>( data[FRM_MOVETYPE] ) );
        

        
        TeleportEntity( client, pos, ang, vel );
        
        
        CopyArray( data[FRM_BASEVEL], vel, 3 );
        SetEntityBaseVelocity( client, vel );
        
        
        g_bStopped[client] = false;
        
        
        for ( int j = g_hFrames[client].Length - 1; j > i; j-- )
        {
            g_hFrames[client].Erase( j );
        }
    }
    
    
    SetEntPropEnt( client, Prop_Data, "m_hGroundEntity", data[FRM_GROUNDENT] );
    SetEntityFlags( client, data[FRM_ENTFLAGS] );
    
    
    
    g_iStoppedFrame[client] = i;
    
    
    if ( bPrint )
    {
        PrintCenterText( client, "%i/%i", i + 1, g_hFrames[client].Length );
    }
    
    return true;
}

stock void StopClient( int client )
{
    g_bStopped[client] = true;
    
    SetEntityMoveType( client, MOVETYPE_NONE );
}

stock void OpenMenu( int client )
{
    FakeClientCommand( client, "sm_tas_menu" );
}

stock void OpenSettingsMenu( int client )
{
    FakeClientCommand( client, "sm_tas_settings" );
}

stock void OpenCmdListMenu( int client )
{
    FakeClientCommand( client, "sm_tas_listcmds" );
}

stock void IncreasePlayback( int client )
{
    if ( g_iPlayback[client] <= 0 )
    {
        g_iPlayback[client] = 1;
    }
    else if ( g_iPlayback[client] < 16 )
    {
        g_iPlayback[client] *= 2;
    }
}

stock void DecreasePlayback( int client )
{
    if ( g_iPlayback[client] >= 0 )
    {
        g_iPlayback[client] = -1;
    }
    else if ( g_iPlayback[client] > -16 )
    {
        g_iPlayback[client] *= 2;
    }
}

stock void ContinueOrStop( int client )
{
    SetFrame( client, g_iStoppedFrame[client], ShouldContinue( client ) );
    
    g_iPlayback[client] = 0;
}

stock void ResetClient( int client )
{
    g_bStopped[client] = false;
    g_iStoppedFrame[client] = -1;
    
    g_iPlayback[client] = 0;
}

stock bool ShouldContinue( int client )
{
    return ( g_bStopped[client] && !g_iPlayback[client] );
}

stock float GetClientApproxTime( int client )
{
    return ( (g_iStoppedFrame[client] + 1) * GetTickInterval() );
}

stock void UnfreezeClient( int client )
{
    if ( GetEntityMoveType( client ) == MOVETYPE_NONE )
    {
        SetEntityMoveType( client, MOVETYPE_WALK );
    }
}

stock void SetTimescale( int client, float value, bool bCheats = true )
{
    g_flTimescale[client] = value;
    
    if ( !IsFakeClient( client ) )
    {
        Inf_SendConVarValueBool( client, g_ConVar_Cheats, bCheats );
        Inf_SendConVarValueFloat( client, g_ConVar_Timescale, value, "%.2f" );
    }
}

stock void IncreaseTimescale( int client )
{
    float value = g_flTimescale[client];
    
    value *= 2;
    
    
    if ( value > 1.0 )
    {
        value = 1.0;
    }
    
    
    SetTimescale( client, value );
}

stock void DecreaseTimescale( int client )
{
    float value = g_flTimescale[client];
    
    value /= 2;
    
    
    if ( value < 0.25 )
    {
        value = 0.25;
    }
    
    
    SetTimescale( client, value );
}