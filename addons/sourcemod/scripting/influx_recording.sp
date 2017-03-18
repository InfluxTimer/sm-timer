#include <sourcemod>
#include <cstrike>

#include <influx/core>
#include <influx/recording>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>
#include <msharedutil/misc>


#undef REQUIRE_PLUGIN
#include <influx/help>
#include <influx/pause>
#include <influx/practise>


//#define DEBUG_LOADRECORDINGS
//#define DEBUG_INSERTFRAME
//#define DEBUG
//#define DEBUG_REPLAY


#define DEF_REPLAYBOTNAME           "Replay Bot - !replay"


#define INF_PRIVCOM_CHANGEREPLAY    "sm_inf_changereplay"


enum
{
    SLOT_PRIMARY = 0,
    SLOT_SECONDARY,
    SLOT_MELEE,
    
    SLOTS_SAVED
};


#define PLAYBACK_START      -1
#define PLAYBACK_END        -2



// ANTI-SPAM
float g_flLastReplayMenu[INF_MAXPLAYERS];


// FINISH STUFF
float g_flFinishedTime[INF_MAXPLAYERS];
int g_iFinishedRunId[INF_MAXPLAYERS];
int g_iFinishedMode[INF_MAXPLAYERS];
int g_iFinishedStyle[INF_MAXPLAYERS];


// REPLAY
int g_iReplayBot;
ArrayList g_hReplay;

int g_iReplayRunId;
int g_iReplayMode;
int g_iReplayStyle;

int g_iReplayLastFindRun;
int g_iReplayLastFindMode;
int g_iReplayLastFindStyle;

char g_szReplayName[MAX_BEST_NAME];
float g_flReplayTime;

int g_iReplayRequester;
bool g_bReplayedOnce;
bool g_bForcedReplay;


// RECORDING
ArrayList g_hRunRec;

ArrayList g_hRec[INF_MAXPLAYERS];
bool g_bIsRec[INF_MAXPLAYERS];
int g_nCurRec[INF_MAXPLAYERS];

int g_fCurButtons[INF_MAXPLAYERS];
int g_iCurWep[INF_MAXPLAYERS];
char g_szWep_Prim[INF_MAXPLAYERS][32];
char g_szWep_Sec[INF_MAXPLAYERS][32];


float g_flTeleportDistSq;

float g_flTickrate;


// CONVARS
ConVar g_ConVar_WeaponSwitch;
ConVar g_ConVar_WeaponAttack;
ConVar g_ConVar_WeaponAttack2;
ConVar g_ConVar_MaxLength;
ConVar g_ConVar_StartTime;
ConVar g_ConVar_EndTime;
ConVar g_ConVar_AutoPlayback;
ConVar g_ConVar_Repeat;
ConVar g_ConVar_BotName;


int g_nMaxRecLength;


// LIBRARIES
bool g_bLib_Pause;
bool g_bLib_Practise;


#include "influx_recording/cmds.sp"
#include "influx_recording/file.sp"
#include "influx_recording/menus.sp"
#include "influx_recording/menus_hndlrs.sp"
#include "influx_recording/runcmd.sp"


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Recording",
    description = "Records run and then plays them for your viewing pleasure!",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    RegPluginLibrary( INFLUX_LIB_RECORDING );
    
    // NATIVES
    CreateNative( "Influx_GetReplayBot", Native_GetReplayBot );
    CreateNative( "Influx_GetReplayRunId", Native_GetReplayRunId );
    CreateNative( "Influx_GetReplayMode", Native_GetReplayMode );
    CreateNative( "Influx_GetReplayStyle", Native_GetReplayStyle );
    CreateNative( "Influx_GetReplayTime", Native_GetReplayTime );
    CreateNative( "Influx_GetReplayName", Native_GetReplayName );
}

public void OnPluginStart()
{
    g_hRunRec = new ArrayList( RUNREC_SIZE );
    
    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_CHANGEREPLAY, Cmd_Empty, ADMFLAG_ROOT );
    
    
    // CMDS
    RegConsoleCmd( "sm_replay", Cmd_Replay );
    RegConsoleCmd( "sm_myreplay", Cmd_MyReplay );
    //RegConsoleCmd( "sm_test_replay", Cmd_Test_Replay );
    
    
    // CONVARS
    g_ConVar_WeaponSwitch = CreateConVar( "influx_recording_wepswitching", "1", "Do weapon switching on replay.", FCVAR_NOTIFY );
    g_ConVar_WeaponAttack = CreateConVar( "influx_recording_attack", "1", "Do weapon shooting on replay.", FCVAR_NOTIFY );
    g_ConVar_WeaponAttack2 = CreateConVar( "influx_recording_attack2", "0", "Do right click on replay.", FCVAR_NOTIFY );
    
    g_ConVar_MaxLength = CreateConVar( "influx_recording_maxlength", "75", "Max recording length in minutes.", FCVAR_NOTIFY );
    g_ConVar_MaxLength.AddChangeHook( E_CvarChange_MaxLength );
    
    g_ConVar_StartTime = CreateConVar( "influx_recording_startwait", "1.5", "How long we wait at the start before starting playback.", FCVAR_NOTIFY );
    g_ConVar_EndTime = CreateConVar( "influx_recording_endwait", "1.5", "How long we wait at the end before teleporting to start.", FCVAR_NOTIFY );
    
    g_ConVar_AutoPlayback = CreateConVar( "influx_recording_autoplayback", "1", "Will automatically play replays if players haven't selected one.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    g_ConVar_Repeat = CreateConVar( "influx_recording_repeatplayback", "1", "If no new playback is set, do we keep repeating the same replay?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    g_ConVar_BotName = CreateConVar( "influx_recording_botname", DEF_REPLAYBOTNAME, "Replay bot's name.", FCVAR_NOTIFY );
    g_ConVar_BotName.AddChangeHook( E_CvarChange_BotName );
    
    
    AutoExecConfig( true, "recording", "influx" );
    
    
    // LIBRARIES
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
    g_bLib_Practise = LibraryExists( INFLUX_LIB_PRACTISE );
    
    
    // EVENTS
    HookEvent( "player_spawn", E_PlayerSpawn );
    
    
    // Round it just in case.
    g_flTickrate = float( RoundFloat( 1.0 / GetTickInterval() ) );
    
    SetTeleDistance( 3500.0, g_flTickrate );
    SetMaxRecordingLength( g_flTickrate );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = true;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = false;
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "replay", "Open replay menu." );
}

public void Influx_OnRequestResultFlags()
{
    Influx_AddResultFlag( "Don't save recording file", RES_RECORDING_DONTSAVE );
}

public void Influx_OnPostRunLoad()
{
    // Update our run array.
    g_hRunRec.Clear();
    
    ArrayList runs = Influx_GetRunsArray();
    
    int data[RUNREC_SIZE];
    int len = GetArrayLength_Safe( runs );
    for ( int i = 0; i < len; i++ )
    {
        data[RUNREC_RUN_ID] = runs.Get( i, RUN_ID );
        g_hRunRec.PushArray( data );
    }
    
    
    g_iReplayLastFindRun = 0;
    g_iReplayLastFindMode = 0;
    g_iReplayLastFindStyle = -1;
    
    
    LoadAllRecordings();
}

public void OnMapEnd()
{
    g_iReplayBot = -1;
    
    
    decl i, j, k;
    for ( i = 0; i < INF_MAXPLAYERS; i++ )
    {
        // null it from bot before we attempt to delete it.
        if ( g_hRec[i] == g_hReplay )
        {
            g_hReplay = null;
        }
        
        delete g_hRec[i];
    }
    
    ArrayList rec;
    for ( i = 0; i < g_hRunRec.Length; i++ )
        for ( j = 0; j < MAX_MODES; j++ )
            for ( k = 0; k < MAX_STYLES; k++ )
                if ( (rec = GetRunRec( i, j, k )) != null )
                {
#if defined DEBUG
                    PrintToServer( INF_DEBUG_PRE..."Deleting replay recording %x", rec );
#endif
                    
                    // null it from bot before we attempt to delete it.
                    if ( rec == g_hReplay )
                    {
                        g_hReplay = null;
                    }
                    
                    delete rec;
                }
    
    delete g_hReplay;
}

public void E_PlayerSpawn( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( !client ) return;
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    if ( IsFakeClient( client ) )
    {
        RequestFrame( E_PlayerSpawn_Delay, GetClientUserId( client ) );
    }
}

public void E_PlayerSpawn_Delay( int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( !IsPlayerAlive( client ) ) return;
    
    
    SetEntityCollisionGroup( client, 1 ); // Disable collisions with players and triggers.
    
    //SetEntityGravity( client, 0.0 );
    
    SetEntityMoveType( client, MOVETYPE_NOCLIP );
    
    SetEntProp( client, Prop_Data, "m_takedamage", 0 );
}

public void OnConfigsExecuted()
{
    ConVar cvar;
    
    
    // Bot cvars
    cvar = FindConVar( "bot_stop" );
    if ( cvar != null )
    {
        cvar.SetBool( true );
        delete cvar;
    }
    
    cvar = FindConVar( "bot_quota_mode" );
    if ( cvar != null )
    {
        cvar.SetString( "normal" );
        delete cvar;
    }
    
    cvar = FindConVar( "bot_join_after_player" );
    if ( cvar != null )
    {
        cvar.SetBool( false );
        delete cvar;
    }
    
    cvar = FindConVar( "bot_chatter" );
    if ( cvar != null )
    {
        cvar.SetString( "off" );
        delete cvar;
    }
    
    cvar = FindConVar( "bot_join_team" );
    if ( cvar != null )
    {
        cvar.SetString( "any" );
        delete cvar;
    }
    
    cvar = FindConVar( "bot_quota" );
    if ( cvar != null )
    {
        cvar.SetInt( 1 );
        delete cvar;
    }
    
    
    // Playback stuff
    float maxvel = 3500.0;
    
    cvar = FindConVar( "sv_maxvelocity" );
    if ( cvar != null )
    {
        maxvel = cvar.FloatValue;
        delete cvar;
    }
    
    SetTeleDistance( maxvel, g_flTickrate );
    
    SetMaxRecordingLength( g_flTickrate );
}

// Determine our maximum position difference.
// If our playback's previous position and current position distance is larger than this (squared) we teleport the bot.
// And no, it is not the sv_maxvelocity value. That is only for per axis.
// Only map that you can even come close to this in is bhop_forest_trials where you can use the infinity room.
stock void SetTeleDistance( float maxvel, float tickrate )
{
    float maxtickspd = SquareRoot( maxvel * maxvel + maxvel * maxvel ) * ( 1.0 / tickrate );
    
    g_flTeleportDistSq = maxtickspd * maxtickspd;
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Max dist per tick: %.1f (sv_maxvelocity: %.0f | tickrate: %.0f)", maxtickspd, maxvel, tickrate );
#endif
}

public void E_CvarChange_MaxLength( ConVar convar, const char[] oldval, const char[] newval )
{
    SetMaxRecordingLength( g_flTickrate );
}

public void E_CvarChange_BotName( ConVar convar, const char[] oldval, const char[] newval )
{
    SetBotName();
}

stock void SetMaxRecordingLength( float tickrate )
{
    g_nMaxRecLength = g_ConVar_MaxLength.IntValue * 60 * RoundFloat( tickrate );
}

public void OnClientPutInServer( int client )
{
    g_bIsRec[client] = false;
    
    
    ArrayList rec = g_hRec[client];
    if ( rec != null ) DeleteRecording( rec );
    g_hRec[client] = null;
    
    if ( !IsFakeClient( client ) )
    {
        Inf_SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
    }
    else
    {
        if ( g_iReplayBot == client || !IsValidReplayBot() )
        {
            SetReplayBot( client );
        }
    }
    
    
    g_flLastReplayMenu[client] = 0.0;
}

stock void SetReplayBot( int bot )
{
    g_iReplayBot = bot;
    
    g_iReplayRunId = -1;
    g_iReplayMode = MODE_INVALID;
    g_iReplayStyle = STYLE_INVALID;
    g_flReplayTime = INVALID_RUN_TIME;
    g_szReplayName[0] = '\0';
    
    g_bForcedReplay = false;
    g_iReplayRequester = -1;
    
    
    SetBotName();
    
    
    CS_SetClientClanTag( bot, "NONE" );
    
    
    FindNewPlayback();
}

stock void OnClientDisconnect( int client )
{
    if ( client == g_iReplayRequester )
    {
        g_iReplayRequester = -1;
    }
    
    if ( client == g_iReplayBot )
    {
        g_iReplayBot = -1;
    }
}

stock bool IsValidReplayBot()
{
    return ( IS_ENT_PLAYER( g_iReplayBot ) && IsClientInGame( g_iReplayBot ) && IsFakeClient( g_iReplayBot ) );
}

stock bool FindNewPlayback()
{
    if ( !g_ConVar_AutoPlayback.BoolValue ) return false;
    
    
    // I know, this is really messy.
    // Just leave it. JUST DON'T LOOK AT IT, ALRIGHT!
    
    int runlen = g_hRunRec.Length;
    if ( !runlen ) return false;
    
#if defined DEBUG_REPLAY
    PrintToServer( INF_DEBUG_PRE..."Finding a recording for replay! (%i)", runlen );
#endif

    int run_start = g_iReplayLastFindRun;
    int mode_start = g_iReplayLastFindMode;
    int style_start = g_iReplayLastFindStyle + 1;
    
    if ( style_start < 0 ) style_start = 0;
    else if ( style_start >= MAX_STYLES )
    {
        style_start = 0;
        mode_start++;
    }
    
    if ( mode_start < 0 ) mode_start = 0;
    else if ( mode_start >= MAX_MODES )
    {
        mode_start = 0;
        run_start++;
    }
    
    if ( run_start < 0 || run_start >= runlen ) run_start = 0;
    
    
    int run_end = run_start - 1;
    if ( run_end < 0 || run_end >= runlen ) run_end = runlen - 1;
    
    int mode_end = mode_start - 1;
    if ( mode_end < 0 || mode_end >= MAX_MODES ) mode_end = MAX_MODES - 1;
    
    decl style;
    
    int irun = run_start;
    int mode = mode_start;
    
    // Stops the annoying warning in the compiler.
    bool useless = true;
    
    while ( useless )
    {
        if ( irun >= runlen ) irun = 0;
        
        while ( useless )
        {
            if ( mode >= MAX_MODES ) mode = 0;
            
            for ( style = style_start; style < MAX_STYLES; style++ )
            {
                if ( GetRunRec( irun, mode, style ) != null )
                {
                    decl String:szName[MAX_NAME_LENGTH];
                    GetRunName( irun, mode, style, szName, sizeof( szName ) );
                    
                    StartPlayback(
                        GetRunRec( irun, mode, style ),
                        g_hRunRec.Get( irun, RUNREC_RUN_ID ),
                        mode,
                        style,
                        GetRunTime( irun, mode, style ),
                        szName );
                    
                    
                    g_iReplayLastFindRun = irun;
                    g_iReplayLastFindMode = mode;
                    g_iReplayLastFindStyle = style;
                    
                    return true;
                }
            }
            
            style_start = 0;
            
            
            if ( mode++ == mode_end ) break;
        }
        
        if ( irun++ == run_end ) break;
        
        mode_start = 0;
        mode_end = MAX_MODES - 1;
    }
    
    // Reset these if we didn't find any.
    g_iReplayLastFindRun = 0;
    g_iReplayLastFindMode = 0;
    g_iReplayLastFindStyle = -1;
    
    return false;
}

public void E_PostThinkPost_Client( int client )
{
    if ( !IsPlayerAlive( client ) ) return;
    
    if ( !g_bIsRec[client] ) return;
    
    if ( g_bLib_Practise && Influx_IsClientPractising( client ) ) return;
    
    if ( g_bLib_Pause && Influx_IsClientPaused( client ) ) return;
    
    
    InsertFrame( client );
}

public Action T_PlaybackToStart( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) != -1 )
    {
        if ( g_nCurRec[client] == PLAYBACK_END )
        {
            if ( !FindNewPlayback() )
            {
                // Couldn't find a new playback, repeat it if possible.
                if ( g_ConVar_Repeat.BoolValue )
                {
                    g_nCurRec[client] = PLAYBACK_START;
                    
                    CreateTimer( g_ConVar_StartTime.FloatValue, T_PlaybackStart, GetClientUserId( g_iReplayBot ), TIMER_FLAG_NO_MAPCHANGE );
                }
                else
                {
                    ResetReplay();
                }
            }
        }
    }
}

public Action T_PlaybackStart( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) != -1 )
    {
        if ( g_nCurRec[client] == PLAYBACK_START )
        {
            g_nCurRec[client] = 0;
        }
    }
}

public void Influx_OnTimerResetPost( int client )
{
    g_bIsRec[client] = false;
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    if ( g_bLib_Practise && Influx_IsClientPractising( client ) ) return;
    
    
    StartRecording( client, true );
    
    // Cache "finish" stuff here if we don't get to the end.
    g_flFinishedTime[client] = INVALID_RUN_TIME;
    
    g_iFinishedRunId[client] = runid;
    g_iFinishedMode[client] = Influx_GetClientMode( client );
    g_iFinishedStyle[client] = Influx_GetClientStyle( client );
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    if ( !g_bIsRec[client] ) return;
    
    
    g_flFinishedTime[client] = time;
    
    g_iFinishedRunId[client] = runid;
    g_iFinishedMode[client] = mode;
    g_iFinishedStyle[client] = style;
    
    FinishRecording( client, true );
    
    if ( flags & (RES_TIME_ISBEST | RES_TIME_FIRSTREC) )
    {
        // Make sure this run allows us to save the recording.
        if ( !(flags & RES_RECORDING_DONTSAVE) )
        {
            if ( SaveRecording( client, g_hRec[client], runid, mode, style, time ) )
            {
                Influx_PrintToChat( _, client, "Your run has been successfully saved!" );
            }
            else
            {
                Influx_PrintToChat( _, client, "We were unable to save your recording, sorry!" );
            }
        }
        
        
        int irun = FindRunRecById( runid );
        if ( irun == -1 ) return;
        
        
        ArrayList rec = GetRunRec( irun, mode, style );
        
        if ( rec != null ) DeleteRecording( rec );
        
        
        decl String:szName[32];
        GetClientName( client, szName, sizeof( szName ) );
        
        rec = g_hRec[client].Clone();
        
        SetRunName( irun, mode, style, szName );
        SetRunTime( irun, mode, style, time );
        SetRunRec( irun, mode, style, rec );
        
        if ( CanChangeReplay( 0, false ) )
        {
            GetRunName( irun, mode, style, szName, sizeof( szName ) );
            
            // Force this replay to play at least once unless admin doesn't like it.
            StartPlayback( rec, runid, mode, style, time, szName, _, true );
        }
    }
}

public void Influx_OnRunCreated( int runid )
{
    int data[RUNREC_SIZE];
    data[RUNREC_RUN_ID] = runid;
    
    g_hRunRec.PushArray( data );
}

stock void DeleteRecording( ArrayList &rec )
{
    if ( rec == g_hReplay )
    {
        g_hReplay = null;
    }
    
    delete rec;
}

stock void StartPlayback( ArrayList rec, int runid, int mode, int style, float time, const char[] szName, int requester = 0, bool bForce = false )
{
    if ( !IsValidReplayBot() )
    {
#if defined DEBUG_REPLAY
        PrintToServer( INF_DEBUG_PRE..."Tried to start a playback with invalid replay bot!" );
#endif
        return;
    }
    
    // Make sure they are not dead! D:
    bool wasdead = false;
    if ( GetClientTeam( g_iReplayBot ) <= CS_TEAM_SPECTATOR )
    {
        ChangeClientTeam( g_iReplayBot, CS_TEAM_CT );
        
        wasdead = true;
    }
    
    if ( !IsPlayerAlive( g_iReplayBot ) )
    {
        CS_RespawnPlayer( g_iReplayBot );
        
        wasdead = true;
    }
    
    
    if ( !wasdead && requester && g_hReplay == rec )
    {
        Influx_PrintToChat( 0, requester, "That run is already being replayed!" );
        return;
    }
    
#if defined DEBUG_REPLAY
    PrintToServer( INF_DEBUG_PRE..."Starting playback requested by %i! (%i, %i, %i)", requester, runid, mode, style );
#endif
    
    
    g_iReplayRunId = runid;
    g_iReplayMode = mode;
    g_iReplayStyle = style;
    
    g_flReplayTime = time;
    
    strcopy( g_szReplayName, sizeof( g_szReplayName ), szName );
    
    g_bReplayedOnce = false;
    g_bForcedReplay = bForce;
    
    g_iReplayRequester = requester;
    
    
    g_hReplay = rec;
    
    g_nCurRec[g_iReplayBot] = PLAYBACK_START;
    
    CreateTimer( g_ConVar_StartTime.FloatValue, T_PlaybackStart, GetClientUserId( g_iReplayBot ), TIMER_FLAG_NO_MAPCHANGE );
    
    
    // Set tag.
    decl String:szTag[32];
    decl String:szRun[16];
    decl String:szMode[16];
    decl String:szStyle[16];
    
    
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    StringToUpper( szRun );
    
    
    // Ignore if possible.
    if ( Influx_ShouldModeDisplay( mode ) )
    {
        Influx_GetModeShortName( mode, szMode, sizeof( szMode ) );
    }
    else
    {
        szMode[0] = '\0';
    }
    
    if ( Influx_ShouldStyleDisplay( style ) )
    {
        Influx_GetStyleShortName( style, szStyle, sizeof( szStyle ) );
    }
    else
    {
        szStyle[0] = '\0';
    }
    
    
    FormatEx( szTag, sizeof( szTag ), "%s%s%s%s%s",
    szRun,
    ( szStyle[0] != '\0' ) ? " " : "",
    szStyle,
    ( szMode[0] != '\0' ) ? " " : "",
    szMode );
    
    CS_SetClientClanTag( g_iReplayBot, szTag );
    
    
    
    
    if ( IS_ENT_PLAYER( requester ) )
    {
        Influx_PrintToChat( _, requester, "Replay is now being played!" );
    }
}

stock void FinishPlayback()
{
    CreateTimer( g_ConVar_EndTime.FloatValue, T_PlaybackToStart, GetClientUserId( g_iReplayBot ), TIMER_FLAG_NO_MAPCHANGE );
    g_nCurRec[g_iReplayBot] = PLAYBACK_END;
    
    
    if ( g_iReplayRequester > 0 || g_bForcedReplay )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) && IsObservingTarget( i, g_iReplayBot ) )
            {
                Influx_PrintToChat( _, i, "You can now request a replay by typing {MAINCLR1}!replay{CHATCLR} in chat." );
            }
        }
    }
    
    g_bReplayedOnce = true;
    g_bForcedReplay = false;
    
    g_iReplayRequester = -1;
}

stock void StartRecording( int client, bool bInsertFrame = false )
{
    ArrayList rec = g_hRec[client];
    
    if ( rec != null )
    {
        DeleteRecording( rec );
    }
    
    
    g_hRec[client] = new ArrayList( REC_SIZE );
    
    g_bIsRec[client] = true;
    g_nCurRec[client] = 0;
    
    g_fCurButtons[client] = 0;
    g_iCurWep[client] = 0;
    
    g_szWep_Prim[client][0] = '\0';
    g_szWep_Sec[client][0] = '\0';
    
    if ( bInsertFrame )
    {
#if defined DEBUG_INSERTFRAME
        PrintToServer( INF_DEBUG_PRE..."Inserting starting frame! (%i) Frame: %i", client, GetGameTickCount() );
#endif
        InsertFrame( client );
        
        
        // Make sure we get the starting weapon right!
        if ( g_hRec[client].Length )
        {
            int wep = GetEntPropEnt( client, Prop_Data, "m_hActiveWeapon" );
            int flags = g_hRec[client].Get( 0, REC_FLAGS );
            
            switch ( FindSlotByWeapon( client, wep ) )
            {
                case SLOT_PRIMARY : g_hRec[client].Set( 0, flags | RECFLAG_WEP_SLOT1, REC_FLAGS );
                case SLOT_SECONDARY : g_hRec[client].Set( 0, flags | RECFLAG_WEP_SLOT2, REC_FLAGS );
                case SLOT_MELEE : g_hRec[client].Set( 0, flags | RECFLAG_WEP_SLOT3, REC_FLAGS );
            }
        }
    }
}

stock void FinishRecording( int client, bool bInsertFrame = false )
{
    g_bIsRec[client] = false;
    
    if ( bInsertFrame )
    {
#if defined DEBUG_INSERTFRAME
        PrintToServer( INF_DEBUG_PRE..."Inserting finishing frame! (%i) Frame: %i", client, GetGameTickCount() );
#endif
        InsertFrame( client );
    }
    
    //CopyToBot( g_hRec[client] );
}

stock void StopRecording( int client )
{
    g_nCurRec[client] = 0;
    g_bIsRec[client] = false;
}

stock InsertFrame( int client )
{
#if defined DEBUG_INSERTFRAME
    PrintToServer( INF_DEBUG_PRE..."(%i) | Frame: %i", client, GetGameTickCount() );
#endif
    
    static int data[REC_SIZE];
    static float temp[3];
    
    GetClientAbsOrigin( client, temp );
    CopyArray( temp, data[REC_POS], 3 );
    
    GetClientEyeAngles( client, temp );
    CopyArray( temp, data[REC_ANG], 2 );
    
    
    
    data[REC_FLAGS] = ( GetEntityFlags( client ) & FL_DUCKING ) ? RECFLAG_CROUCH : 0;
    
    
    if ( g_ConVar_WeaponAttack.BoolValue && g_fCurButtons[client] & IN_ATTACK )
    {
        data[REC_FLAGS] |= RECFLAG_ATTACK;
    }
    
    if ( g_ConVar_WeaponAttack2.BoolValue && g_fCurButtons[client] & IN_ATTACK2 )
    {
        data[REC_FLAGS] |= RECFLAG_ATTACK2;
    }
    
    
    if ( g_ConVar_WeaponSwitch.BoolValue && g_iCurWep[client] )
    {
        switch ( FindSlotByWeapon( client, g_iCurWep[client] ) )
        {
            case SLOT_PRIMARY :
            {
                data[REC_FLAGS] |= RECFLAG_WEP_SLOT1;
                
                if ( g_szWep_Prim[client][0] == '\0' ) // We haven't added a gun here yet.
                {
                    GetEntityClassname( g_iCurWep[client], g_szWep_Prim[client], sizeof( g_szWep_Prim[] ) );
                }
            }
            case SLOT_SECONDARY :
            {
                data[REC_FLAGS] |= RECFLAG_WEP_SLOT2;
                
                if ( g_szWep_Sec[client][0] == '\0' ) // We haven't added a gun here yet.
                {
                    GetEntityClassname( g_iCurWep[client], g_szWep_Sec[client], sizeof( g_szWep_Sec[] ) );
                }
            }
            case SLOT_MELEE : data[REC_FLAGS] |= RECFLAG_WEP_SLOT3;
        }
    }
    
    
    if ( g_hRec[client].PushArray( data ) > g_nMaxRecLength )
    {
        Influx_PrintToChat( _, client, "Stopped recording. Recordings cannot exceed %03i minutes!", g_ConVar_MaxLength.IntValue );
        StopRecording( client );
    }
}

stock int FindSlotByWeapon( int client, int weapon )
{
    for ( int i = 0; i < SLOTS_SAVED; i++ )
    {
        if ( weapon == GetPlayerWeaponSlot( client, i ) ) return i;
    }
    
    return -1;
}

stock bool CanReplayOwn( int client )
{
    return ( g_hRec[client] != null );
}

stock void ReplayOwn( int client )
{
    decl String:szName[MAX_NAME_LENGTH];
    GetClientName( client, szName, sizeof( szName ) );
    
    StartPlayback(
        g_hRec[client],
        g_iFinishedRunId[client],
        g_iFinishedMode[client],
        g_iFinishedStyle[client],
        g_flFinishedTime[client],
        szName,
        client );
}

stock bool CanChangeReplay( int issuer = 0, bool bCanAdminOverride = true )
{
    if ( g_bForcedReplay && (!bCanAdminOverride || !CanUserChangeReplay( issuer )) )
    {
        if ( issuer )
        {
            Influx_PrintToChat( _, issuer, "Replaying a new record. Please wait." );
        }
        
        return false;
    }
    
    
    if ( !IS_ENT_PLAYER( g_iReplayRequester ) ) return true;
    
    if (!IsClientInGame( g_iReplayRequester )
    ||  IsFakeClient( g_iReplayRequester )
    ||  !IsObservingTarget( g_iReplayRequester, g_iReplayBot ) )
    {
        g_iReplayRequester = -1;
        return true;
    }
    
    if ( g_hReplay == null ) return true;
    
    
    if ( !g_bReplayedOnce )
    {
        if ( bCanAdminOverride && CanUserChangeReplay( issuer ) )
            return true;
        
        
        if ( issuer )
        {            
            if ( issuer == g_iReplayRequester )
            {
                Influx_PrintToChat( _, issuer, "You've already requested a replay!" );
            }
            else
            {
                Influx_PrintToChat( _, issuer, "Replay is being watched by {MAINCLR1}%N{CHATCLR}. Please wait for the recording to finish.", g_iReplayRequester );
            }
        }
        
        return false;
    }
    
    
    return true;
}

stock bool IsObservingTarget( int client, int target )
{
    return ( !IsPlayerAlive( client ) && GetClientObserverTarget( client ) == target && GetClientObserverMode( client ) != OBS_MODE_ROAMING );
}

stock bool ObserveTarget( int client, int target )
{
    // Can't spectate a dead player!
    if ( !IsPlayerAlive( target ) ) return false;
    
    
    if ( IsPlayerAlive( client ) )
    {
        ChangeClientTeam( client, CS_TEAM_SPECTATOR );
    }
    else if ( GetClientObserverTarget( client ) == target )
    {
        return true; // We're already spectating the target!
    }
    
    
    SetClientObserverMode( client, OBS_MODE_IN_EYE );
    SetClientObserverTarget( client, target );
    
    return true;
}

stock int FindRunRecById( int id )
{
    if ( g_hRunRec != null ) 
    {
        int len = g_hRunRec.Length;
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hRunRec.Get( i, RUNREC_RUN_ID ) == id )
                return i;
        }
    }
    
    return -1;
}

stock ArrayList GetRunRec( int index, int mode, int style )
{
    return view_as<ArrayList>( g_hRunRec.Get( index, RUNREC_REC + OFFSET_MODESTYLE( mode, style ) ) );
}

stock void SetRunRec( int index, int mode, int style, ArrayList rec )
{
    g_hRunRec.Set( index, rec, RUNREC_REC + OFFSET_MODESTYLE( mode, style ) );
}

/*stock int GetRunTimeId( int index, int mode, int style )
{
    return g_hRunRec.Get( index, RUNREC_REC_UID + OFFSET_MODESTYLE( mode, style ) );
}*/

stock float GetRunTime( int index, int mode, int style )
{
    return g_hRunRec.Get( index, RUNREC_REC_TIME + OFFSET_MODESTYLE( mode, style ) );
}

stock void SetRunTime( int index, int mode, int style, float time )//, int uid = 0 )
{
    int offset = OFFSET_MODESTYLE( mode, style );
    
    g_hRunRec.Set( index, time, RUNREC_REC_TIME + offset );
    //g_hRunRec.Set( i, uid, RUNREC_REC_UID + offset );
}

stock void GetRunName( int index, int mode, int style, char[] out, int len )
{
    decl name[MAX_BEST_NAME_CELL];
    
    
    int offset = OFFSET_MODESTYLESIZE( mode, style, MAX_BEST_NAME_CELL );
    
    for ( int i = 0; i < sizeof( name ); i++ )
    {
        name[i] = g_hRunRec.Get( index, RUNREC_REC_NAME + offset + i );
    }
    
    strcopy( out, len, view_as<char>( name ) );
}

stock void SetRunName( int index, int mode, int style, const char[] szName )
{
    decl String:sz[MAX_BEST_NAME + 1];
    decl name[MAX_BEST_NAME_CELL];
    
    strcopy( sz, sizeof( sz ), szName );
    
    
    LimitString( sz, sizeof( sz ), MAX_BEST_NAME );
    
    
    strcopy( view_as<char>( name ), MAX_BEST_NAME, sz );
    
    
    int offset = OFFSET_MODESTYLESIZE( mode, style, MAX_BEST_NAME_CELL );
    
    for ( int i = 0; i < sizeof( name ); i++ )
    {
        g_hRunRec.Set( index, name[i], RUNREC_REC_NAME + offset + i );
    }
}

/*stock void GetRunWeapons( int index, int mode, int style, char[] szPrim, int prim_len, char[] szSec, int sec_len )
{
    decl wep[MAX_RUNREC_WEPNAME_CELL];
    decl i;
    
    
    int offset = OFFSET_MODESTYLESIZE( mode, style, MAX_RUNREC_WEPNAME_CELL );
    
    
    
    for ( i = 0; i < sizeof( wep ); i++ )
    {
        wep[i] = g_hRunRec.Get( index, RUNREC_REC_START_PRIMWEP + offset + i );
    }
    
    strcopy( szPrim, prim_len, view_as<char>( wep ) );
    
    
    for ( i = 0; i < sizeof( wep ); i++ )
    {
        wep[i] = g_hRunRec.Get( index, RUNREC_REC_START_SECWEP + offset + i );
    }
    
    strcopy( szSec, sec_len, view_as<char>( wep ) );
}


stock void SetRunWeapons( int index, int mode, int style, const char[] szPrim, const char[] szSec )
{
    decl wep[MAX_RUNREC_WEPNAME_CELL];
    decl i;
    
    
    int offset = OFFSET_MODESTYLESIZE( mode, style, MAX_RUNREC_WEPNAME_CELL );
    
    
    
    strcopy( view_as<char>( wep ), MAX_RUNREC_WEPNAME, szPrim );
    
    for ( i = 0; i < sizeof( wep ); i++ )
    {
        g_hRunRec.Set( index, wep[i], RUNREC_REC_START_PRIMWEP + offset + i );
    }
    
    
    strcopy( view_as<char>( wep ), MAX_RUNREC_WEPNAME, szSec );
    
    for ( i = 0; i < sizeof( wep ); i++ )
    {
        g_hRunRec.Set( index, wep[i], RUNREC_REC_START_SECWEP + offset + i );
    }
}*/

// Malicious ucmd angles will crash the server.
stock void FixAngles( float &pitch, float &yaw )
{
    if ( pitch > 90.0 )
    {
        pitch = 90.0;
    }
    else if ( pitch < -90.0 )
    {
        pitch = -90.0;
    }
    
    if ( yaw > 180.0 )
    {
        yaw = 180.0;
    }
    else if ( yaw < -180.0 )
    {
        yaw = -180.0;
    }
}

stock bool CanUserChangeReplay( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_CHANGEREPLAY, ADMFLAG_ROOT );
}

stock void ResetReplay()
{
    // Try to teleport the bot to start.
    if ( IsValidReplayBot() && g_hReplay != null && g_hReplay.Length > 0 )
    {
        float pos[3];
        float angles[3];
        
        int data[REC_SIZE];
        
        g_hReplay.GetArray( 0, data );
        
        CopyArray( data[REC_POS], pos, 3 );
        CopyArray( data[REC_ANG], angles, 2 );
        
        TeleportEntity( g_iReplayBot, pos, angles, ORIGIN_VECTOR );
    }
    
    
    g_hReplay = null;
    
    g_iReplayRunId = -1;
    g_iReplayMode = -1;
    g_iReplayStyle = -1;
    g_flReplayTime = INVALID_RUN_TIME;
}

stock void SetBotName()
{
    if ( !IsValidReplayBot() ) return;
    
    
    char szName[MAX_NAME_LENGTH];
    g_ConVar_BotName.GetString( szName, sizeof( szName ) );
    
    if ( szName[0] == '\0' )
    {
        strcopy( szName, sizeof( szName ), DEF_REPLAYBOTNAME );
    }
    
    SetClientInfo( g_iReplayBot, "name", szName );
}

// NATIVES
public int Native_GetReplayBot( Handle hPlugin, int nParms ) { return g_iReplayBot; }
public int Native_GetReplayRunId( Handle hPlugin, int nParms ) { return g_iReplayRunId; }
public int Native_GetReplayMode( Handle hPlugin, int nParms ) { return g_iReplayMode; }
public int Native_GetReplayStyle( Handle hPlugin, int nParms ) { return g_iReplayStyle; }
public int Native_GetReplayTime( Handle hPlugin, int nParms ) { return view_as<int>( g_flReplayTime ); }

public int Native_GetReplayName( Handle hPlugin, int nParms )
{
    SetNativeString( 1, g_szReplayName, GetNativeCell( 2 ), true );
    
    return 1;
}