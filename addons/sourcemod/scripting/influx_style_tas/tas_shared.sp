#include <sourcemod>
#include <sdktools>

#include <influx/core>
#include <influx/style_tas>

#include <influx/stocks_strf>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>
#include <msharedutil/misc>


#undef REQUIRE_PLUGIN
#include <influx/ac_log>
#include <influx/recording>
#include <influx/strafes>
#include <influx/jumps>
#include <influx/pause>
#include <influx/practise>


//#define DEBUG
//#define DEBUG_THINK



#define PLAYBACK_SPD_LIMIT              16
#define PLAYBACK_SPD_START              0.25

#define MIN_TIMESCALE                   0.1
#define TIMESCALE_STEPS                 0.1



#define INF_PRIVCOM_LOADSAVETAS         "sm_inf_loadsavetas"
#define INF_PRIVCOM_USETIMESCALE        "sm_inf_tastimescale"



// 4 byte | "inft"
#define TASFILE_CURMAGIC                0x696e6674

// 4 byte | "v002"
#define TASFILE_VERSION_1               0x76303031
#define TASFILE_CURVERSION              0x76303032

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
    FRM_ANGREAL[2],
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
};

enum
{
    AIMLOCK_NONE = 0,
    
    AIMLOCK_FAKEANG,
    AIMLOCK_ANG,
    
    AIMLOCK_MAX
};

enum
{
    FRMCP_NUM = 0,
    FRMCP_FRMINDEX,
    
    FRMCP_SIZE
};

#define MAX_FRMCP       50


ArrayList g_hFrames[INF_MAXPLAYERS];

bool g_bStopped[INF_MAXPLAYERS];
int g_iStoppedFrame[INF_MAXPLAYERS];

float g_flPlayback[INF_MAXPLAYERS];
float g_flAccPlayback[INF_MAXPLAYERS];

float g_flTimescale[INF_MAXPLAYERS];

int g_iAutoStrafe[INF_MAXPLAYERS];

float g_vecLastWantedAngles[INF_MAXPLAYERS][3];

bool g_bAdvanceFrame[INF_MAXPLAYERS];

ArrayList g_hFrameCP[INF_MAXPLAYERS];
int g_iCurCP[INF_MAXPLAYERS];
int g_nCPs[INF_MAXPLAYERS];
int g_iLastUsedCP[INF_MAXPLAYERS];
int g_iLastCreatedCP[INF_MAXPLAYERS];

int g_iAimlock[INF_MAXPLAYERS];

#if defined USE_LAGGEDMOVEMENTVALUE
int g_nIgnoredCmds[INF_MAXPLAYERS];
int g_flLastProcessedButtons[INF_MAXPLAYERS];
float g_flLastProcessedYaw[INF_MAXPLAYERS];
float g_flLastProcessedVel[INF_MAXPLAYERS][3];
#endif


// CONVARS
ConVar g_ConVar_SilentStrafer;
ConVar g_ConVar_EnableTimescale;
ConVar g_ConVar_MOTDFix;

#if !defined USE_LAGGEDMOVEMENTVALUE
ConVar g_ConVar_Timescale;
#endif
ConVar g_ConVar_Cheats;


// LIBRARIES
bool g_bLib_Practise;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - TAS",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CONVARS
#if !defined USE_LAGGEDMOVEMENTVALUE
    if ( (g_ConVar_Timescale = FindConVar( "host_timescale" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for host_timescale!" );
    }
#endif
    
    if ( (g_ConVar_Cheats = FindConVar( "sv_cheats" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_cheats!" );
    }
    
    
#if !defined USE_LAGGEDMOVEMENTVALUE && !defined USE_SERVER_TIMESCALE
    g_ConVar_Timescale.Flags &= ~(FCVAR_REPLICATED | FCVAR_CHEAT);
#endif
    
    
    g_ConVar_SilentStrafer = CreateConVar( "influx_style_tas_silentstrafer", "1", "Do we record the player's wanted angles to a replay?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_EnableTimescale = CreateConVar( "influx_style_tas_timescale", "1", "Is timescale enabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_MOTDFix = CreateConVar( "influx_style_tas_motdfix", "1", "Workaround to make MOTD display in CS:GO.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    AutoExecConfig( true, "style_tas", "influx" );
    
    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_LOADSAVETAS, Cmd_Empty, ADMFLAG_ROOT );
    RegConsoleCmd( INF_PRIVCOM_USETIMESCALE, Cmd_Empty );
    
    
    // CMDS
    RegConsoleCmd( "sm_tas", Cmd_Style_Tas, "Change your style to TAS (tool assisted speedrun)." );
    RegConsoleCmd( "sm_toolassisted", Cmd_Style_Tas );
    
    RegConsoleCmd( "sm_tas_continue", Cmd_Continue );
    RegConsoleCmd( "sm_tas_stop", Cmd_Stop );
    
    RegConsoleCmd( "sm_tas_fwd", Cmd_Forward );
    RegConsoleCmd( "sm_tas_bwd", Cmd_Backward );
    
    RegConsoleCmd( "sm_tas_advanceframe", Cmd_AdvanceFrame );
    
    RegConsoleCmd( "sm_tas_nextframe", Cmd_NextFrame );
    RegConsoleCmd( "sm_tas_prevframe", Cmd_PrevFrame );
    
    RegConsoleCmd( "sm_tas_inctimescale", Cmd_IncTimescale );
    RegConsoleCmd( "sm_tas_dectimescale", Cmd_DecTimescale );
    RegConsoleCmd( "sm_tas_autostrafe", Cmd_AutoStrafe );
    
    RegConsoleCmd( "sm_tas_cp_add", Cmd_CPAdd );
    RegConsoleCmd( "sm_tas_cp_lastused", Cmd_CPLastUsed );
    RegConsoleCmd( "sm_tas_cp_lastcreated", Cmd_CPLastCreated );
    
    
    // MENUS
    RegConsoleCmd( "sm_tas_menu", Cmd_TasMenu );
    RegConsoleCmd( "sm_tas_cpmenu", Cmd_TasCPMenu );
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
    
#if !defined USE_LAGGEDMOVEMENTVALUE
    g_ConVar_Timescale.FloatValue = 1.0;
    g_ConVar_Timescale.Flags |= (FCVAR_REPLICATED | FCVAR_CHEAT);
#endif
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public Action Influx_OnLogCheat( int client, const char[] szReasonId, int &punishtime, bool &bNotifyAdmin )
{
    if ( Influx_GetClientStyle( client ) == STYLE_TAS )
    {
        punishtime = ACLOG_NOPUNISH;
        bNotifyAdmin = false;
        
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
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

public Action Influx_ShouldCountJumps( int client )
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
    
    
    int ang_index = g_ConVar_SilentStrafer.BoolValue ? FRM_ANG : FRM_ANGREAL;
    
    
    int len = g_hFrames[client].Length;
    for ( int i = 0; i < len; i++ )
    {
        g_hFrames[client].GetArray( i, framedata );
        
        CopyArray( framedata[FRM_POS], recdata[REC_POS], 3 );
        CopyArray( framedata[ang_index], recdata[REC_ANG], 2 );
        
        
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
        
        /*
        if ( !Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client ) )
        {
            return Plugin_Handled;
        }
        */
        
        if ( !Inf_SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client ) )
        {
            UnhookThinks( client );
            return Plugin_Handled;
        }
    }
    
    return Plugin_Continue;
}

stock void UnhookThinks( int client )
{
    //SDKUnhook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
    SDKUnhook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
}

public void Influx_OnClientStyleChangePost( int client, int style, int laststyle )
{
    if ( style == STYLE_TAS )
    {
        SetClientCheats( client, true );
        
        
        OpenMenu( client );
        
#if !defined USE_LAGGEDMOVEMENTVALUE
        if ( laststyle != STYLE_TAS && GetEngineVersion() == Engine_CSGO )
        {
            Influx_PrintToChat( _, client, "Make sure to use {MAINCLR1}cl_clock_correction_force_server_tick/cl_clockdrift_max_ms 0{CHATCLR} to decrease laggy timescale!" );
        }
#endif
    }
    else if ( laststyle == STYLE_TAS )
    {
        DisableTas( client );
    }
}

public void Influx_OnClientModeChangePost( int client, int mode, int lastmode )
{
    // Reset timescale when we change mode.
    if ( Influx_GetClientStyle( client ) == STYLE_TAS )
        SetTimescale( client, 1.0 );
}

public void OnClientPutInServer( int client )
{
    ResetClient( client );
    
    // HACK: Client doesn't like when cheats cvar gets updated before displaying the MOTD.
    if ( GetEngineVersion() == Engine_CSGO && g_ConVar_MOTDFix.BoolValue )
    {
        // The MOTD gets automatically shown after 5 seconds.
        CreateTimer( 6.0, T_MotdFix, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
    }
    else
    {
        SetClientCheats( client, false );
    }
    
    
    g_iAutoStrafe[client] = AUTOSTRF_OFF;
    g_iAimlock[client] = AIMLOCK_FAKEANG;
    g_flTimescale[client] = 1.0;
}

public Action T_MotdFix( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) > 0 && IsClientInGame( client ) )
    {
        if ( Influx_GetClientStyle( client ) != STYLE_TAS || g_flTimescale[client] == 1.0 )
            SetClientCheats( client, false );
    }
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

public void E_PostThinkPost_Client( int client )
{
#if defined DEBUG_THINK
    PrintToServer( INF_DEBUG_PRE..."PostThinkPost - TAS (timescale: %.1f)", g_flTimescale[client] );
#endif

    if ( !IsPlayerAlive( client ) ) return;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS )
    {
        DisableTas( client );
        return;
    }
    
#if defined USE_LAGGEDMOVEMENTVALUE
    if ( g_nIgnoredCmds[client] ) return;
    
    g_flLastProcessedButtons[client] = GetClientButtons( client );
#endif
    
    if ( Influx_GetClientState( client ) == STATE_RUNNING )
    {
        if ( g_flPlayback[client] != 0.0 && g_bStopped[client] )
        {
            Playback( client );
        }
        else if ( g_bStopped[client] )
        {
            FreezeAim( client );
        }
        else
        {
            InsertFrame( client );
        }
    }
    
    // HACK
    Influx_SetClientTime( client, TickCountToTime( (g_iStoppedFrame[client] + 1) ) );
}

public void E_PlayerTeamNDeath( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return;
    
    
    SetTimescale( client, 1.0 );
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3] )
{
    if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Continue;
    
    
    g_vecLastWantedAngles[client] = angles;
    
    
#if defined USE_LAGGEDMOVEMENTVALUE
    int ignore_cmds = RoundFloat( 1.0 / g_flTimescale[client] );
    
    if ( ++g_nIgnoredCmds[client] < ignore_cmds )
    {
        buttons = g_flLastProcessedButtons[client];
        vel = g_flLastProcessedVel[client];
        angles[1] = g_flLastProcessedYaw[client];
        return Plugin_Continue;
    }
    
    g_nIgnoredCmds[client] = 0;
    
    g_flLastProcessedVel[client] = vel;
    g_flLastProcessedYaw[client] = angles[1];
#endif
    
    
    if ( g_iAutoStrafe[client] == AUTOSTRF_OFF )
    {
        return Plugin_Continue;
    }
    
    
    
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
    
    
    float wantedyaw = angles[1];
    
    
    decl Float:vec[3];
    GetEntityAbsVelocity( client, vec );
    
    float lastmoveyaw = RadToDeg( ArcTangent2( vec[1], vec[0] ) );
    
    bool bForce = true;
    
    // Only force if our yaw hasn't changed.
    if ( g_iAutoStrafe[client] == AUTOSTRF_CONTROL )
    {
        bForce = ( wantedyaw == flLastLegitYaw[client] );
    }
    
    if ( bForce )
    {
        float lastyaw = ( flLastLegitYaw[client] == wantedyaw || g_iAutoStrafe[client] == AUTOSTRF_MAXSPEED ) ? lastmoveyaw : flLastLegitYaw[client];
        
        if ( GetStrafe( wantedyaw, lastyaw, 75.0 ) == STRF_RIGHT )
        {
            angles[1] = lastmoveyaw;
            vel[1] = SIDESPD;
        }
        else
        {
            angles[1] = lastmoveyaw;
            vel[1] = -SIDESPD;
        }
        
        
        angles[1] = NormalizeAngle( angles[1] );
    }
    else
    {
        // Just follow the mouse.
        if ( GetStrafe( wantedyaw, flLastLegitYaw[client], 75.0 ) == STRF_RIGHT )
        {
            vel[1] = SIDESPD;
        }
        else
        {
            vel[1] = -SIDESPD;
        }
    }
    
    
#if defined USE_LAGGEDMOVEMENTVALUE
    g_flLastProcessedVel[client] = vel;
    g_flLastProcessedYaw[client] = angles[1];
#endif
    
    flLastLegitYaw[client] = wantedyaw;
    
    return Plugin_Continue;
}

stock void Playback( int client )
{
    if ( !g_hFrames[client] ) return;
    
    if ( g_hFrames[client].Length < 1 ) return;
    
    
    int skip = RoundFloat( g_flPlayback[client] );
    
    if ( !skip )
    {
        g_flAccPlayback[client] += g_flPlayback[client];
        
        skip = RoundFloat( g_flAccPlayback[client] );
        
        
        if ( skip ) g_flAccPlayback[client] = 0.0;
    }
    
    if ( skip != 0 )
    {
        int nextframe = g_iStoppedFrame[client] + skip;
        
        if ( nextframe >= g_hFrames[client].Length )
        {
            nextframe = g_hFrames[client].Length - 1;
        }
        else if ( nextframe < 0 )
        {
            nextframe = 0;
        }
        
        SetFrame( client, nextframe, false );
    }
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
    CopyArray( vec, data[FRM_ANGREAL], 2 );
    
    CopyArray( g_vecLastWantedAngles[client], data[FRM_ANG], 2 );
    
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
    
    
    if ( g_bAdvanceFrame[client] )
    {
        g_bAdvanceFrame[client] = false;
        
        SetFrame( client, g_iStoppedFrame[client], false, true );
        
        OpenMenu( client );
    }
}

stock bool SetFrame( int client, int i, bool bContinue, bool bPrint = false )
{
    if ( g_hFrames[client] == null ) return false;
    
    if ( i < 0 || i >= g_hFrames[client].Length ) return false;
    
    
    decl Float:pos[3];
    //decl Float:angreal[3];
    decl Float:ang[3];
    decl Float:vel[3];
    
    static int data[FRM_SIZE];
    
    g_hFrames[client].GetArray( i, data );
    
    CopyArray( data[FRM_POS], pos, 3 );
    //CopyArray( data[FRM_ANGREAL], angreal, 2 );
    //angreal[2] = 0.0;
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
        
        
        TeleportEntity( client, pos, NULL_VECTOR, vel );
        
        
        CopyArray( data[FRM_BASEVEL], vel, 3 );
        SetEntityBaseVelocity( client, vel );
        
        
        g_bStopped[client] = false;
        
        
        if ( (i + 1) != g_hFrames[client].Length )
        {
            g_hFrames[client].Resize( i + 1 );
        }
        
        EraseFutureCPs( client, i );
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

stock void FreezeAim( int client )
{
    if ( g_iAimlock[client] == AIMLOCK_NONE ) return;
    
    
    if ( g_hFrames[client] == null ) return;
    
    
    int i = g_iStoppedFrame[client];
    
    if ( i < 0 || i >= g_hFrames[client].Length ) return;
    
    
    int offset = ( g_iAimlock[client] == AIMLOCK_FAKEANG ) ? FRM_ANG : FRM_ANGREAL;
    
    float ang[3];
    ang[0] = g_hFrames[client].Get( i, offset );
    ang[1] = g_hFrames[client].Get( i, offset + 1 );
    ang[2] = 0.0;
    
    TeleportEntity( client, NULL_VECTOR, ang, NULL_VECTOR );
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

stock void OpenCPMenu( int client )
{
    FakeClientCommand( client, "sm_tas_cpmenu" );
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
    if ( g_flPlayback[client] <= 0.0 )
    {
        g_flPlayback[client] = PLAYBACK_SPD_START;
    }
    else if ( g_flPlayback[client] < PLAYBACK_SPD_LIMIT )
    {
        g_flPlayback[client] *= 2.0;
    }
}

stock void DecreasePlayback( int client )
{
    if ( g_flPlayback[client] >= 0.0 )
    {
        g_flPlayback[client] = -PLAYBACK_SPD_START;
    }
    else if ( g_flPlayback[client] > -PLAYBACK_SPD_LIMIT )
    {
        g_flPlayback[client] *= 2.0;
    }
}

stock void ContinueOrStop( int client )
{
    if ( !SetFrame( client, g_iStoppedFrame[client], ShouldContinue( client ) ) )
    {
        UnfreezeClient( client );
    }
    
    StopPlayback( client );
}

stock void ResetClient( int client )
{
    g_bStopped[client] = false;
    g_iStoppedFrame[client] = -1;
    
    
    delete g_hFrameCP[client];
    g_iCurCP[client] = 0;
    
    
    StopPlayback( client );
    
    g_bAdvanceFrame[client] = false;
}

stock bool ShouldContinue( int client )
{
    return ( g_bStopped[client] && g_flPlayback[client] == 0.0 );
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

stock void SetTimescale( int client, float value )
{
    g_flTimescale[client] = value;
    
    if ( !IsFakeClient( client ) )
    {
#if defined USE_LAGGEDMOVEMENTVALUE
        SetEntPropFloat( client, Prop_Send, "m_flLaggedMovementValue", value );
#else
    

#if defined USE_SERVER_TIMESCALE
        g_ConVar_Timescale.FloatValue = value;
#else
        Inf_SendConVarValueFloat( client, g_ConVar_Timescale, value, "%.2f" );
#endif // USE_SERVER_TIMESCALE
        
        
#endif // USE_LAGGEDMOVEMENTVALUE
    }

}

stock void IncreaseTimescale( int client )
{
    float value = g_flTimescale[client];
    
    value += TIMESCALE_STEPS;
    
    
    if ( value > 1.0 )
    {
        value = 1.0;
    }
    
    
    SetTimescale( client, value );
}

stock void DecreaseTimescale( int client )
{
    float value = g_flTimescale[client];
    
    value -= TIMESCALE_STEPS;
    
    
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

stock bool CanUserUseTimescale( int client )
{
    if ( !g_ConVar_EnableTimescale.BoolValue )
        return false;
    
    
    int flags;
    if ( !GetCommandOverride( INF_PRIVCOM_USETIMESCALE, Override_Command, flags ) )
    {
        return true; // No override, just allow.
    }
    
    return CheckCommandAccess( client, INF_PRIVCOM_USETIMESCALE, flags, true );
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

stock void ChangeAimlock( int client )
{
    if ( ++g_iAimlock[client] >= AIMLOCK_MAX || g_iAimlock[client] < 0 )
    {
        g_iAimlock[client] = AIMLOCK_NONE;
    }
}

stock void SetClientCheats( int client, bool bAllow )
{
    if ( IsFakeClient( client ) ) return;
    
    
    if ( !bAllow )
    {
        SetTimescale( client, 1.0 );
    }
    
    Inf_SendConVarValueBool( client, g_ConVar_Cheats, bAllow );
}

stock bool CanAdvanceFrame( int client )
{
    return ( ShouldContinue( client ) && g_hFrames[client] && (g_iStoppedFrame[client] + 1) >= g_hFrames[client].Length );
}

stock void AdvanceFrame( int client )
{
    g_bAdvanceFrame[client] = true;
    
    ContinueOrStop( client );
}

stock void StopPlayback( int client )
{
    g_flPlayback[client] = 0.0;
    g_flAccPlayback[client] = 0.0;
}

stock void EraseFutureCPs( int client, int index )
{
    if ( g_hFrameCP[client] == null ) return;
    
    
    int len = GetFrameCPLength( client );
    for ( int i = 0; i < len; i++ )
    {
        if ( index < g_hFrameCP[client].Get( i, FRMCP_FRMINDEX ) )
        {
            g_hFrameCP[client].Set( i, 0, FRMCP_NUM );
        }
    }
    
    g_iCurCP[client] = FindHighestCPNum( client ) + 1;
    if ( g_iCurCP[client] >= MAX_FRMCP ) // Our highest CP is the last one, loop back to start.
        g_iCurCP[client] = 0;
}

stock int FindHighestCPNum( int client )
{
    int index;
    
    int highest = 0;
    int highest_index = -1;
    
    
    for ( int i = 0; i < MAX_FRMCP; i++ )
    {
        if ( g_hFrameCP[client].Get( i, FRMCP_NUM ) < 1 ) continue;
        
        
        index = g_hFrameCP[client].Get( i, FRMCP_FRMINDEX );
        
        if ( highest < index )
        {
            highest_index = i;
            highest = index;
        }
    }
    
    return highest_index;
}

stock int FindFrameCPByNum( int client, int num )
{
    if ( g_hFrameCP[client] == null ) return -1;
    
    
    int len = GetFrameCPLength( client );
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hFrameCP[client].Get( i, FRMCP_NUM ) == num )
        {
            return i;
        }
    }
    
    return -1;
}

stock int FindFrameCPByIndex( int client, int index )
{
    if ( g_hFrameCP[client] == null ) return -1;
    
    
    int len = GetFrameCPLength( client );
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hFrameCP[client].Get( i, FRMCP_FRMINDEX ) == index )
        {
            return i;
        }
    }
    
    return -1;
}

stock int GetFrameCPLength( int client )
{
    if ( g_hFrameCP[client] == null ) return -1;
    
    int len = g_hFrameCP[client].Length;
    
    if ( g_nCPs[client] < len ) len = g_nCPs[client];
    
    return len;
}

stock void AddCP( int client )
{
    if ( g_hFrames[client] == null ) return;
    
    
    if ( g_hFrameCP[client] == null ) CreateFrameCP( client );
    
    
    int index = -1;
    
    if ( g_bStopped[client] ) index = g_iStoppedFrame[client];
    else index = g_hFrames[client].Length - 1;
    
    
    if ( index < 0 || index >= g_hFrames[client].Length ) return;
    
    if ( FindFrameCPByIndex( client, index ) != -1 ) return;
    
    
    decl data[FRMCP_SIZE];
    data[FRMCP_FRMINDEX] = index;
    data[FRMCP_NUM] = ++g_nCPs[client];
    
    g_hFrameCP[client].SetArray( g_iCurCP[client]++, data );
    
    if ( g_iCurCP[client] >= MAX_FRMCP ) g_iCurCP[client] = 0;
    
    
    g_iLastCreatedCP[client] = data[FRMCP_NUM];
}

stock void CreateFrameCP( int client )
{
    delete g_hFrameCP[client];
    
    g_hFrameCP[client] = new ArrayList( FRMCP_SIZE, MAX_FRMCP );
    
    
    for ( int i = 0; i < MAX_FRMCP; i++ )
    {
        g_hFrameCP[client].Set( i, 0, FRMCP_NUM );
    }
    
    g_iCurCP[client] = 0;
    g_nCPs[client] = 0;
    
    g_iLastUsedCP[client] = 0;
    g_iLastCreatedCP[client] = 0;
}

stock void GotoCP( int client, int num )
{
    if ( num < 1 ) return;
    
    
    int i = FindFrameCPByNum( client, num );
    
    if ( i != -1 )
    {
        SetFrame( client, g_hFrameCP[client].Get( i, FRMCP_FRMINDEX ), false, true );
        
        g_iLastUsedCP[client] = num;
    }
}

stock void DisableTas( int client )
{
    RequestFrame( UnhookThinksCb, GetClientUserId( client ) );
    
    UnfreezeClient( client );
    
    
    SetClientCheats( client, false );
}

public void UnhookThinksCb( int userid ) // Can't unhook inside hook
{
    int client = GetClientOfUserId( userid );
    if ( client <= 0 || !IsClientInGame( client ) )
        return;


    UnhookThinks( client );
}
