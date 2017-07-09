#include <sourcemod>
#include <sdktools>

#include <influx/core>
#include <influx/recording>
#include <influx/style_tas>

#include <influx/stocks_strf>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>
#include <msharedutil/misc>


#undef REQUIRE_PLUGIN
#include <influx/strafes>
#include <influx/pause>
#include <influx/practise>



//#define DEBUG_THINK



#define PLAYBACK_SPD_LIMIT              16

#define MIN_TIMESCALE                   0.25



#define INF_PRIVCOM_LOADSAVETAS         "sm_inf_loadsavetas"



// 4 byte | "inft"
#define TASFILE_CURMAGIC                0x696e6674

// 4 byte | "v001"
#define TASFILE_CURVERSION              0x76303031

#define MAX_TASFILE_MAPNAME             64
#define MAX_TASFILE_MAPNAME_CELL        MAX_TASFILE_MAPNAME / 4

#define MAX_TASFILE_PLYNAME             32
#define MAX_TASFILE_PLYNAME_CELL        MAX_TASFILE_PLYNAME / 4

enum
{
    TASFILE_MAGIC = 0,
    TASFILE_VERSION,
    TASFILE_HEADERSIZE,
    
    TASFILE_TICKRATE,
    
    TASFILE_RUNID,
    TASFILE_MODE,
    TASFILE_STYLE,
    
    TASFILE_MAPNAME[MAX_TASFILE_MAPNAME_CELL],
    TASFILE_PLYNAME[MAX_TASFILE_PLYNAME_CELL],
    
    TASFILE_FRAMELEN
};

#define TASFILE_CURHEADERSIZE       TASFILE_FRAMELEN



#define FRM_CLASSNAME_SIZE          32
#define FRM_CLASSNAME_SIZE_CELL     FRM_CLASSNAME_SIZE / 4

#define FRM_TARGETNAME_SIZE         32
#define FRM_TARGETNAME_SIZE_CELL    FRM_TARGETNAME_SIZE / 4

enum
{
    FRM_POS[3] = 0,
    FRM_ANG[2],
    
    FRM_ABSVEL[3],
    FRM_BASEVEL[3],
    
    FRM_MOVETYPE,
    FRM_GROUNDENT,
    FRM_ENTFLAGS,
    
    FRM_TARGETNAME[FRM_TARGETNAME_SIZE_CELL],
    FRM_CLASSNAME[FRM_CLASSNAME_SIZE_CELL],
    
    FRM_SIZE
};


enum
{
    AUTOSTRF_OFF = 0,
    
    AUTOSTRF_CONTROL,
    AUTOSTRF_MAXSPEED,
    
    AUTOSTRF_MAX
}


ArrayList g_hFrames[INF_MAXPLAYERS];

bool g_bStopped[INF_MAXPLAYERS];
int g_iStoppedFrame[INF_MAXPLAYERS];

int g_iPlayback[INF_MAXPLAYERS];

float g_flTimescale[INF_MAXPLAYERS];

int g_iAutoStrafe[INF_MAXPLAYERS];


// CONVARS
ConVar g_ConVar_Timescale;
ConVar g_ConVar_Cheats;


// LIBRARIES
bool g_bLib_Practise;


bool g_bLate;



#include "influx_style_tas/cmds.sp"
#include "influx_style_tas/file.sp"
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
    
    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_LOADSAVETAS, Cmd_Empty, ADMFLAG_ROOT );
    
    
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
    
    RegConsoleCmd( "sm_tas_load", Cmd_LoadRun );
    RegConsoleCmd( "sm_tas_save", Cmd_SaveRun );
    
    
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
    
    // LIBRARIES
    g_bLib_Practise = LibraryExists( INFLUX_LIB_PRACTISE );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = false;
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_TAS, "Tool Assisted", "Tas", "tas" ) )
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

public Action Influx_ShouldCountStrafes( int client )
{
    return ( Influx_GetClientStyle( client ) == STYLE_TAS ) ? Plugin_Handled : Plugin_Continue;
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
        if ( g_bLib_Practise && Influx_IsClientPractising( client ) )
        {
            return Plugin_Handled;
        }
        
        
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
        
        if ( GetEngineVersion() == Engine_CSGO && laststyle != STYLE_TAS )
        {
            Influx_PrintToChat( _, client, "Make sure to use {MAINCLR1}cl_clock_correction_force_server_tick/cl_clockdrift_max_ms 0{CHATCLR} to decrease laggy timescale!" );
        }
    }
}

public void OnClientPutInServer( int client )
{
    ResetClient( client );
    
    
    SetTimescale( client, 1.0, false );
    
    g_iAutoStrafe[client] = AUTOSTRF_OFF;
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
        if ( g_iPlayback[client] && g_bStopped[client] )
        {
            SetFrame( client, g_iStoppedFrame[client] + g_iPlayback[client], false );
        }
        else
        {
            InsertFrame( client );
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

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3] )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    if ( g_iAutoStrafe[client] == AUTOSTRF_OFF ) return Plugin_Continue;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Continue;
    
    
    static float flLastLegitYaw[INF_MAXPLAYERS];
    
    if (GetEntityFlags( client ) & FL_ONGROUND
    ||  vel[0] != 0.0
    ||  vel[1] != 0.0)
    {
        flLastLegitYaw[client] = angles[1];
        return Plugin_Continue;
    }
    
    
// Default cl_sidespeed.
#define SIDESPD         400.0

// GetAirSpeedCap()
// wishspd will never really be < 30.0 so just hardcoded @ 30.0
#define AIRCAP          30.0 

// No reason to add more than this.
//#define MAX_YAWADD      90.0
    
    
    decl Float:vec[3];
    decl Float:yawadd;
    
    
    float wantedyaw = angles[1];
    
    
    //GetClientEyeAngles( client, vec );
    //float lastyaw = vec[1];
    
    
    GetEntityAbsVelocity( client, vec );
    float spd = SquareRoot( vec[0] * vec[0] + vec[1] * vec[1] );
    
    float lastmoveyaw = RadToDeg( ArcTangent2( vec[1], vec[0] ) );
    
    bool bAdd = true;
    
    bool bForce = ( g_iAutoStrafe[client] == AUTOSTRF_MAXSPEED );
    
    if ( !bForce && spd > 0.0 )
    {
        //yawadd = AIRCAP / spd * AIRCAP;
        
        
        decl Float:right[3];
        float ang[3];
        
        
        ang[1] = lastmoveyaw;
        
        GetAngleVectors( ang, NULL_VECTOR, right, NULL_VECTOR );
        
        vec[2] = 0.0;
        right[2] = 0.0;
        
        float addspeed = (AIRCAP - GetVectorDotProduct( vec, right ));// * GetTickInterval();
        
        for ( int i = 0; i < 2; i++ )
        {
            vec[i] += addspeed * right[i];
        }
        
        yawadd = FloatAbs( NormalizeAngle( RadToDeg( ArcTangent2( vec[1], vec[0] ) ) - lastmoveyaw ) );
    }
    else
    {
        bAdd = false; // No matter what we do we'll get aircap'd.
    }
    
    
    /*if ( yawadd > MAX_YAWADD )
    {
        yawadd = MAX_YAWADD;
    }*/
    
    
    // Is our real delta smaller than the best possible? (player doesn't want to strafe out more than we want.)
    if ( bForce || (bAdd && yawadd > FloatAbs( NormalizeAngle( angles[1] - lastmoveyaw ) )) )
    {
        if ( GetStrafe( angles[1], lastmoveyaw, 75.0 ) == STRF_RIGHT )
        {
            angles[1] = lastmoveyaw;// + yawadd;
            vel[1] = SIDESPD;
        }
        else
        {
            angles[1] = lastmoveyaw;// - yawadd;
            vel[1] = -SIDESPD;
        }
        
        angles[1] = NormalizeAngle( angles[1] );
    }
    else // Our delta was too high, just follow the mouse and hope the player knows he may be losing dat precious speed!
    {
        if ( GetStrafe( angles[1], flLastLegitYaw[client], 75.0 ) == STRF_RIGHT )
        {
            vel[1] = SIDESPD;
        }
        else
        {
            vel[1] = -SIDESPD;
        }
    }
    
    flLastLegitYaw[client] = wantedyaw;
    
    return Plugin_Continue;
}

stock float NormalizeAngle( float ang )
{
    if ( ang > 180.0 )
    {
        ang -= 360.0;
    }
    else if ( ang < -180.0 )
    {
        ang += 360.0;
    }
    
    return ang;
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
    
    GetEntityAbsVelocity( client, vec );
    CopyArray( vec, data[FRM_ABSVEL], 3 );
    
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
    CopyArray( data[FRM_ABSVEL], vel, 3 );
    
    
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
        
        
        if ( (i + 1) != g_hFrames[client].Length )
        {
            g_hFrames[client].Resize( i + 1 );
        }
    }
    
    
    int ent = data[FRM_GROUNDENT];
    int flags = data[FRM_ENTFLAGS];
    
    
    SetEntPropEnt( client, Prop_Data, "m_hGroundEntity", ent );
    
    SetEntityFlags( client, flags );
    
    
    // m_bDucked controls player's hull size, m_bDucking is the transition.
    if ( flags & FL_DUCKING )
    {
        SetEntProp( client, Prop_Data, "m_bDucked", 1 );
        SetEntProp( client, Prop_Data, "m_bDucking", 0 );
    }
    else
    {
        SetEntProp( client, Prop_Data, "m_bDucked", 0 );
        SetEntProp( client, Prop_Data, "m_bDucking", 0 );
    }
    
    
    SetEntityName( client, view_as<char>( data[FRM_TARGETNAME] ) );
    SetEntityClassname( client, view_as<char>( data[FRM_CLASSNAME] ) );
    
    
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

stock void OpenLoadMenu( int client )
{
    FakeClientCommand( client, "sm_tas_load" );
}

stock void OpenSaveMenu( int client )
{
    FakeClientCommand( client, "sm_tas_save" );
}

stock void IncreasePlayback( int client )
{
    if ( g_iPlayback[client] <= 0 )
    {
        g_iPlayback[client] = 1;
    }
    else if ( g_iPlayback[client] < PLAYBACK_SPD_LIMIT )
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
    else if ( g_iPlayback[client] > -PLAYBACK_SPD_LIMIT )
    {
        g_iPlayback[client] *= 2;
    }
}

stock void ContinueOrStop( int client )
{
    if ( !SetFrame( client, g_iStoppedFrame[client], ShouldContinue( client ) ) )
    {
        UnfreezeClient( client );
    }
    
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
    
    
    if ( value < MIN_TIMESCALE )
    {
        value = MIN_TIMESCALE;
    }
    
    
    SetTimescale( client, value );
}

stock bool CanUserLoadSaveTas( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_LOADSAVETAS, ADMFLAG_ROOT );
}

stock void SaveFramesMsg( int client )
{
    decl String:szPath[128];
    FormatTasPath( szPath, sizeof( szPath ), Influx_GetClientId( client ), Influx_GetClientRunId( client ), Influx_GetClientMode( client ), Influx_GetClientStyle( client ) );
    
    if ( SaveFrames( client ) )
    {
        Influx_PrintToChat( _, client, "Saved {MAINCLR1}%i{CHATCLR} frames to '{MAINCLR1}...%s{CHATCLR}'.", g_hFrames[client].Length, szPath[16] );
    }
    else
    {
        Influx_PrintToChat( _, client, "Couldn't save frames to disk!" );
    }
}

stock bool ValidFrames( int client )
{
    return ( g_hFrames[client] != null && g_hFrames[client].Length > 0 );
}

stock void ChangeAutoStrafe( int client )
{
    if ( ++g_iAutoStrafe[client] >= AUTOSTRF_MAX || g_iAutoStrafe[client] < 0 )
    {
        g_iAutoStrafe[client] = AUTOSTRF_OFF;
    }
}