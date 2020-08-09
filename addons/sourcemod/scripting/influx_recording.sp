#include <sourcemod>
#include <cstrike>

#include <influx/core>
#include <influx/recording>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>
#include <msharedutil/misc>


#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <influx/help>
#include <influx/pause>
#include <influx/practise>


//#define DEBUG_BOT_MOVEMENT
//#define DEBUG_LOADRECORDINGS
//#define DEBUG_INSERTFRAME
//#define DEBUG
//#define DEBUG_REPLAY
//#define DEBUG_CVARS


#define DEF_REPLAYBOTNAME           "Replay Bot - !replay"


#define INF_PRIVCOM_CHANGEREPLAY    "sm_inf_changereplay"
#define INF_PRIVCOM_DELETERECS      "sm_inf_deleterecordings"


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
float g_flFinishedTime[INF_MAXPLAYERS] = { INVALID_RUN_TIME, ... };
int g_iFinishedRunId[INF_MAXPLAYERS] = { -1, ... };
int g_iFinishedMode[INF_MAXPLAYERS] = { MODE_INVALID, ... };
int g_iFinishedStyle[INF_MAXPLAYERS] = { STYLE_INVALID, ... };


// REPLAY
int g_iReplayBot;
ArrayList g_hReplay;

int g_iReplayRunId = -1;
int g_iReplayMode = MODE_INVALID;
int g_iReplayStyle = STYLE_INVALID;

int g_iReplayLastFindRun;
int g_iReplayLastFindMode;
int g_iReplayLastFindStyle;

char g_szReplayName[MAX_BEST_NAME];
float g_flReplayTime = INVALID_RUN_TIME;

int g_iReplayRequester;
bool g_bReplayedOnce;
bool g_bForcedReplay;


Handle g_hReplayActionTimer;
bool g_bReplayActionTimerClose;


// RECORDING
ArrayList g_hRunRec;

ArrayList g_hRec[INF_MAXPLAYERS];
bool g_bIsRec[INF_MAXPLAYERS];
int g_nCurRec[INF_MAXPLAYERS];

int g_fCurButtons[INF_MAXPLAYERS];
int g_iCurWep[INF_MAXPLAYERS];
char g_szWep_Prim[INF_MAXPLAYERS][32];
char g_szWep_Sec[INF_MAXPLAYERS][32];


// Pre-run stuff...
ArrayList g_hPreRec[INF_MAXPLAYERS];
int g_iCurPreRecStart[INF_MAXPLAYERS];
bool g_bPreRecFilled[INF_MAXPLAYERS];

int g_nMaxPreRecLength;


float g_flTeleportDistSq;

float g_flTickrate;


// FORWARDS
Handle g_hForward_OnRecordingStart;
Handle g_hForward_OnRecordingFinish;


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
ConVar g_ConVar_PreRunTime;
ConVar g_ConVar_IgnoreDifTickrate;
ConVar g_ConVar_KillBotWhenNoPlayersAlive;

ConVar g_ConVar_MaxVelocity;


int g_nMaxRecLength;


// LIBRARIES
bool g_bLib_Pause;
bool g_bLib_Practise;


// ADMIN MENU
TopMenu g_hTopMenu;


bool g_bRecordingsLoaded = false;
bool g_bLate;


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
    
    
    g_bLate = late;
}

public void OnPluginStart()
{
    g_hRunRec = new ArrayList( RUNREC_SIZE );
    
    
    // PHRASES
    LoadTranslations( INFLUX_PHRASES );
    
    
    // FORWARDS
    g_hForward_OnRecordingStart = CreateGlobalForward( "Influx_OnRecordingStart", ET_Event, Param_Cell );
    g_hForward_OnRecordingFinish = CreateGlobalForward( "Influx_OnRecordingFinish", ET_Event, Param_Cell, Param_Cell );
    
    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_CHANGEREPLAY, Cmd_Empty, ADMFLAG_ROOT );
    RegAdminCmd( INF_PRIVCOM_DELETERECS, Cmd_Empty, ADMFLAG_ROOT );
    
    
    // CMDS
    RegConsoleCmd( "sm_replay", Cmd_Replay );
    RegConsoleCmd( "sm_myreplay", Cmd_MyReplay );
    //RegConsoleCmd( "sm_test_replay", Cmd_Test_Replay );
    
    RegConsoleCmd( "sm_deleterecording", Cmd_DeleteRecordings );
    RegConsoleCmd( "sm_deleterecordings", Cmd_DeleteRecordings );
    
    
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
    g_ConVar_IgnoreDifTickrate = CreateConVar( "influx_recording_ignorediftickrate", "0", "0 = Log an error and stop loading recording, 1 = Log an error, 2 = Ignore completely.", FCVAR_NOTIFY, true, 0.0, true, 2.0 );
    
    g_ConVar_BotName = CreateConVar( "influx_recording_botname", DEF_REPLAYBOTNAME, "Replay bot's name.", FCVAR_NOTIFY );
    g_ConVar_BotName.AddChangeHook( E_CvarChange_BotName );
    
    g_ConVar_PreRunTime = CreateConVar( "influx_recording_prerunrecord", "0", "How many seconds we record before the player leaves the start. 0 = Disable", FCVAR_NOTIFY, true, 0.0, true, 1337.0 );
    g_ConVar_PreRunTime.AddChangeHook( E_CvarChange_PreRunTime );

    g_ConVar_KillBotWhenNoPlayersAlive = CreateConVar( "influx_recording_killbotwhennoplayersalive", "0", "Do we kill the replay bot when no players alive?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    AutoExecConfig( true, "recording", "influx" );


    if ( (g_ConVar_MaxVelocity = FindConVar( "sv_maxvelocity" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find cvar sv_maxvelocity!" );
    }
    g_ConVar_MaxVelocity.AddChangeHook( E_CvarChange_MaxVelocity );
    
    
    // LIBRARIES
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
    g_bLib_Practise = LibraryExists( INFLUX_LIB_PRACTISE );
    
    
    // EVENTS
    HookEvent( "player_spawn", E_PlayerSpawn );
    
    
    if ( g_bLate )
    {
        TopMenu topmenu;
        if ( LibraryExists( "adminmenu" ) && (topmenu = GetAdminTopMenu()) != null )
        {
            OnAdminMenuReady( topmenu );
        }
        
        
        // If core has already loaded runs
        // register runs ourselves.
        if ( Influx_HasLoadedRuns() )
        {
            Influx_OnPreRunLoad();
            
            ArrayList runs = Influx_GetRunsArray();
            int len = runs.Length;
            
            for ( int i = 0; i < len; i++ )
            {
                Influx_OnRunCreated( runs.Get( i, RUN_ID ) );
            }
            
            Influx_OnPostRunLoad();
        }


        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) )
            {
                OnClientPutInServer( i );
            }
        }
    }
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

public void OnAdminMenuReady( Handle hTopMenu )
{
    TopMenu topmenu = TopMenu.FromHandle( hTopMenu );
    
    if ( topmenu == g_hTopMenu )
        return;
    
    
    TopMenuObject res = topmenu.FindCategory( INFLUX_ADMMENU );
    
    if ( res == INVALID_TOPMENUOBJECT )
    {
        return;
    }
    
    
    g_hTopMenu = topmenu;
    g_hTopMenu.AddItem( "sm_deleterecordings", AdmMenu_DeleteRecordings, res, INF_PRIVCOM_DELETERECS, 0 );
}

public void AdmMenu_DeleteRecordings( TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength )
{
    if ( action == TopMenuAction_DisplayOption )
    {
        strcopy( buffer, maxlength, "Recording Deletion Menu" );
    }
    else if ( action == TopMenuAction_SelectOption )
    {
        FakeClientCommand( client, "sm_deleterecordings" );
    }
}

public void Influx_OnRequestHelpCmds()
{
    Influx_AddHelpCommand( "replay", "Open replay menu." );
    Influx_AddHelpCommand( "myreplay", "Play your own recording." );
    Influx_AddHelpCommand( "deleterecording", "Delete recordings.", true );
}

public void Influx_OnRequestResultFlags()
{
    Influx_AddResultFlag( "Don't save recording file", RES_RECORDING_DONTSAVE );
}

public void Influx_OnPreRunLoad()
{
    g_hRunRec.Clear();
}

public void Influx_OnPostRunLoad()
{
    g_iReplayLastFindRun = 0;
    g_iReplayLastFindMode = 0;
    g_iReplayLastFindStyle = -1;
    
    
    // Set settings...
    // Round it just in case. Must be set OnMapStart.
    g_flTickrate = float( RoundFloat( 1.0 / GetTickInterval() ) );
    
    //SetTeleDistance( 3500.0, g_flTickrate );
    SetMaxRecordingLength( g_flTickrate );
    SetMaxPreRunLength();
    
    
    LoadAllRecordings();

    CreateTimer( 1.0, T_FindNewPlayback, _, TIMER_FLAG_NO_MAPCHANGE );
}

public void OnMapStart()
{
    CreateTimer( 1.0, T_CheckBot, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

public void OnMapEnd()
{
    g_bRecordingsLoaded = false;
    
    g_bReplayActionTimerClose = true;
    g_hReplayActionTimer = null;
    
    g_iReplayBot = 0;
    
    
    decl i, j, k;
    for ( i = 0; i < sizeof( g_hRec ); i++ )
    {
        FreeRecording( g_hRec[i] );
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
                    
                    FreeRecording( rec );
                }
    
    delete g_hReplay;
    
    g_hReplay = null;
    g_hRunRec.Clear();
}

public void E_PlayerSpawn( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client = GetClientOfUserId( event.GetInt( "userid" ) );
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( GetClientTeam( client ) <= CS_TEAM_SPECTATOR || !IsPlayerAlive( client ) ) return;
    
    
    if ( IsFakeClient( client ) )
    {
        RequestFrame( E_PlayerSpawn_Delay, GetClientUserId( client ) );
    }
}

public void E_PlayerSpawn_Delay( int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    if ( !IsPlayerAlive( client ) ) return;
    
    
    SetEntityCollisionGroup( client, 1 ); // Disable collisions with players and triggers.
    
    //SetEntityGravity( client, 0.0 );
    
    SetEntityMoveType( client, MOVETYPE_NOCLIP );
    
    SetEntProp( client, Prop_Data, "m_takedamage", 0 );
}

public void OnConfigsExecuted()
{
    // Playback stuff
    SetTeleDistance( g_ConVar_MaxVelocity.FloatValue, g_flTickrate );
    
    SetMaxRecordingLength( g_flTickrate );
}

// Determine our maximum position difference.
// If our playback's previous position and current position distance is larger than this (squared) we teleport the bot.
// And no, it is not the sv_maxvelocity value. That is only for per axis.
// Only map that you can even come close to this in is bhop_forest_trials where you can use the infinity room.
stock void SetTeleDistance( float maxvel, float tickrate )
{
    float maxtickspd = SquareRoot( maxvel * maxvel * 3 ) * ( 1.0 / tickrate );
    
    g_flTeleportDistSq = maxtickspd * maxtickspd;
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Max dist per tick: %.1f (sv_maxvelocity: %.0f | tickrate: %.0f)", maxtickspd, maxvel, tickrate );
#endif
}

public void E_CvarChange_MaxLength( ConVar convar, const char[] oldval, const char[] newval )
{
    SetMaxRecordingLength( g_flTickrate );
}

public void E_CvarChange_MaxVelocity( ConVar convar, const char[] oldval, const char[] newval )
{
    SetTeleDistance( g_ConVar_MaxVelocity.FloatValue, g_flTickrate );
}

public void E_CvarChange_BotName( ConVar convar, const char[] oldval, const char[] newval )
{
    SetBotName();
}

public void E_CvarChange_PreRunTime( ConVar convar, const char[] oldval, const char[] newval )
{
    SetMaxPreRunLength();
}

stock void SetMaxRecordingLength( float tickrate )
{
    g_nMaxRecLength = g_ConVar_MaxLength.IntValue * 60 * RoundFloat( tickrate );
}

stock void SetMaxPreRunLength()
{
    g_nMaxPreRecLength = RoundFloat( 1.0 / GetTickInterval() * g_ConVar_PreRunTime.FloatValue );
    
    for ( int i = 1; i < INF_MAXPLAYERS; i++ )
    {
        delete g_hPreRec[i];
        g_hPreRec[i] = null;
        
        
        if ( g_nMaxPreRecLength > 0 )
        {
            g_hPreRec[i] = new ArrayList( REC_SIZE, g_nMaxPreRecLength );
            
            
            ResetClientPreRun( i );
        }
    }
}

stock void ResetClientPreRun( int client )
{
    g_iCurPreRecStart[client] = 0;
    g_bPreRecFilled[client] = false;
}

public void OnClientPutInServer( int client )
{
    g_bIsRec[client] = false;
    
    
    if ( g_hRec[client] != null ) FreeRecording( g_hRec[client] );
    
    if ( !IsFakeClient( client ) )
    {
        ResetClientPreRun( client );
        
        Inf_SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
    }
    else
    {
        OnBotPutInServer( client );
    }
    
    
    g_flLastReplayMenu[client] = 0.0;
}

stock void OnBotPutInServer( int bot )
{
    // We already have a valid bot.
    if ( IsValidReplayBot() )
        return;
    
    
    if ( IsValidReplayBot( bot ) )
    {
        SetReplayBot( bot );
    }
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
        g_iReplayBot = 0;
    }
}

stock bool IsValidReplayBot( int bot = 0 )
{
    if ( bot < 1 )
        bot = g_iReplayBot;
    
    return ( IS_ENT_PLAYER( bot ) && IsClientInGame( bot ) && IsFakeClient( bot ) && !IsClientSourceTV( bot ) );
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
                    char szName[MAX_NAME_LENGTH];
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
    
    InsertPreRunFrame( client );
    
    
    if ( !g_bIsRec[client] ) return;
    
    // Practising
    if ( g_bLib_Practise && Influx_IsClientPractising( client ) ) return;
    
    // Paused
    if ( g_bLib_Pause && Influx_IsClientPaused( client ) ) return;
    
    
    InsertFrame( client );
}

stock void CreatePlaybackStart( int bot )
{
    if ( g_bReplayActionTimerClose )
    {
        delete g_hReplayActionTimer;
    }
    
    g_hReplayActionTimer = CreateTimer( g_ConVar_StartTime.FloatValue, T_PlaybackStart, GetClientUserId( bot ), TIMER_FLAG_NO_MAPCHANGE );
    
    
    g_nCurRec[bot] = PLAYBACK_START;
}

stock void CreatePlaybackEnd( int bot )
{
    if ( g_bReplayActionTimerClose )
    {
        delete g_hReplayActionTimer;
    }
    
    g_hReplayActionTimer = CreateTimer( g_ConVar_EndTime.FloatValue, T_PlaybackToStart, GetClientUserId( bot ), TIMER_FLAG_NO_MAPCHANGE );
    
    
    g_nCurRec[bot] = PLAYBACK_END;
}

public Action T_PlaybackToStart( Handle hTimer, int client )
{
    g_bReplayActionTimerClose = false;
    
    bool nulltimer = true;
    
    if ( (client = GetClientOfUserId( client )) > 0 && IsClientInGame( client ) )
    {
        if ( g_nCurRec[client] == PLAYBACK_END )
        {
            if ( !FindNewPlayback() )
            {
                // Couldn't find a new playback, repeat it if possible.
                if ( g_ConVar_Repeat.BoolValue )
                {
                    CreatePlaybackStart( client );
                    
                    nulltimer = false;
                }
                else
                {
                    ResetReplay();
                }
            }
            else
            {
                nulltimer = false;
            }
        }
    }
    
    if ( nulltimer )
    {
        g_hReplayActionTimer = null;
    }
    
    g_bReplayActionTimerClose = true;
}

public Action T_PlaybackStart( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) > 0 && IsClientInGame( client ) )
    {
        if ( g_nCurRec[client] == PLAYBACK_START )
        {
            g_nCurRec[client] = 0;
        }
    }
    
    g_hReplayActionTimer = null;
}

public void Influx_OnTimerResetPost( int client )
{
    g_bIsRec[client] = false;
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    // Practising
    if ( g_bLib_Practise && Influx_IsClientPractising( client ) ) return;
    

    if ( !StartRecording( client, true ) ) return;
    
    
    // Cache "finish" stuff here if we don't get to the end.
    g_flFinishedTime[client] = INVALID_RUN_TIME;
    
    g_iFinishedRunId[client] = runid;
    g_iFinishedMode[client] = Influx_GetClientMode( client );
    g_iFinishedStyle[client] = Influx_GetClientStyle( client );
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    bool bWasRecording = g_bIsRec[client];

    bool bIsNewRecord = ( flags & (RES_TIME_ISBEST | RES_TIME_FIRSTREC) ) != 0;


    if ( !FinishRecording( client, true ) ) return;
    
    if ( g_hRec[client].Length < 1 )
    {
        if ( bWasRecording )
        {
            LogError( INF_CON_PRE..."Player's %N recording has no size! New record: %i",
                client,
                bIsNewRecord );
        }
        
        return;
    }
    
    
    g_flFinishedTime[client] = time;
    
    g_iFinishedRunId[client] = runid;
    g_iFinishedMode[client] = mode;
    g_iFinishedStyle[client] = style;
    
    
    if ( bIsNewRecord )
    {
        // Make sure this run allows us to save the recording.
        if ( !(flags & RES_RECORDING_DONTSAVE) )
        {
            if ( SaveRecording( client, g_hRec[client], runid, mode, style, time ) )
            {
                Influx_PrintToChat( _, client, "%T", "INF_RECORDINGSAVED", client );
            }
            else
            {
                Influx_PrintToChat( _, client, "%T", "INF_RECORDINGSAVEFAILED", client );
            }
        }
        
        
        int irun = FindRunRecById( runid );
        if ( irun == -1 )
        {
            LogError( INF_CON_PRE..."Player %N finished a run but run rec data does not exist for run of id %i! Creating new one...",
                client,
                runid );
            
            irun = CreateRunRec( runid );
        }
        
        
        ArrayList rec = GetRunRec( irun, mode, style );
        
        if ( rec != null ) FreeRecording( rec );
        
        
        char szName[32];
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
    // Already exists.
    if ( FindRunRecById( runid ) != -1 ) return;
    
    
    CreateRunRec( runid );
}

//
// Always call this to make sure we don't replay deleted recording!
//
stock void FreeRecording( ArrayList &rec )
{
    // null from bot
    if ( rec == g_hReplay )
    {
        g_hReplay = null;
    }
    
    delete rec;
    rec = null;
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
    
    
    if ( !wasdead && requester && !CanUserChangeReplay( requester ) && g_hReplay == rec )
    {
        Influx_PrintToChat( 0, requester, "%T", "INF_RECORDINGALREADYPLAYING", requester );
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
    
    CreatePlaybackStart( g_iReplayBot );
    
    
    // Set tag.
    char szTag[32];
    char szRun[16];
    char szMode[16];
    char szStyle[16];
    
    
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
        Influx_PrintToChat( _, requester, "%T", "INF_RECORDINGNOWPLAYING", requester );
    }
}

stock void FinishPlayback()
{
    CreatePlaybackEnd( g_iReplayBot );
    
    
    if ( g_iReplayRequester > 0 || g_bForcedReplay )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) && IsObservingTarget( i, g_iReplayBot ) )
            {
                Influx_PrintToChat( _, i, "%T", "INF_REPLAYISFREENOW", i );
            }
        }
    }
    
    g_bReplayedOnce = true;
    g_bForcedReplay = false;
    
    g_iReplayRequester = -1;
}

stock bool StartRecording( int client, bool bInsertFrame = false )
{
    if ( g_hRec[client] != null )
    {
        FreeRecording( g_hRec[client] );
    }
    
    g_hRec[client] = new ArrayList( REC_SIZE );
    
    
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnRecordingStart );
    Call_PushCell( client );
    Call_Finish( res );
    
    if ( res != Plugin_Continue )
    {
        g_bIsRec[client] = false;
        return false;
    }
    
    
    
    
    g_bIsRec[client] = true;
    g_nCurRec[client] = 0;
    
    g_fCurButtons[client] = 0;
    g_iCurWep[client] = 0;
    
    g_szWep_Prim[client][0] = '\0';
    g_szWep_Sec[client][0] = '\0';
    
    
    bool preframes = AddPreRunFrames( client );
    
    
    if ( !preframes && bInsertFrame )
    {
#if defined DEBUG_INSERTFRAME
        PrintToServer( INF_DEBUG_PRE..."Inserting starting frame! (%i) Frame: %i", client, GetGameTickCount() );
#endif
        InsertFrame( client );
    }
    
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

    
    return true;
}

stock bool FinishRecording( int client, bool bInsertFrame = false )
{
    g_bIsRec[client] = false;
    
    // Create a dummy recording if we have none. OnTimerStart isn't guaranteed to be called (eg. with TAS)
    if ( g_hRec[client] == null )
        g_hRec[client] = new ArrayList( REC_SIZE );
    
    
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnRecordingFinish );
    Call_PushCell( client );
    Call_PushCell( g_hRec[client] );
    Call_Finish( res );
    
    if ( res == Plugin_Stop )
    {
        return false;
    }
    
    
    if ( res != Plugin_Continue && bInsertFrame )
    {
#if defined DEBUG_INSERTFRAME
        PrintToServer( INF_DEBUG_PRE..."Inserting finishing frame! (%i) Frame: %i", client, GetGameTickCount() );
#endif
        InsertFrame( client );
    }
    
    //CopyToBot( g_hRec[client] );
    
    return true;
}

stock void StopRecording( int client )
{
    g_nCurRec[client] = 0;
    g_bIsRec[client] = false;
}

stock bool AddPreRunFrames( int client )
{
    if ( !g_hPreRec[client] ) return false;
    
    if ( !g_nMaxPreRecLength ) return false;
    
    
    int curstart = g_iCurPreRecStart[client];
    
    
    if ( !g_bPreRecFilled[client] )
    {
        if ( !curstart ) return false;
        
        
        FreeRecording( g_hRec[client] );
        
        
        ArrayList rec = g_hPreRec[client].Clone();
        
        rec.Resize( curstart );
        
        
        g_hRec[client] = rec;
    }
    else
    {
        FreeRecording( g_hRec[client] );
        
        
        ArrayList rec = g_hPreRec[client].Clone();
        
        
        if ( curstart <= 0 )
        {
            g_hRec[client] = rec;
            return true;
        }
        
        
        rec.Resize( rec.Length + 1 );
        
        int lastindex = rec.Length - 1;
        
        //int len =  - 1;
        for ( int i = curstart; i < lastindex; i++ )
        {
            rec.ShiftUp( 0 );
            rec.SwapAt( 0, lastindex );
        }
        
        
        rec.Resize( g_nMaxPreRecLength );
        
        g_hRec[client] = rec;
    }

    
    return true;
}

stock void InsertPreRunFrame( int client )
{
    if ( !g_hPreRec[client] ) return;
    
    if ( !g_nMaxPreRecLength ) return;
    
    
    static int data[REC_SIZE];
    
    FillFrame( client, data );
    
    
    g_hPreRec[client].SetArray( g_iCurPreRecStart[client], data );
    
    if ( ++g_iCurPreRecStart[client] >= g_nMaxPreRecLength )
    {
        g_iCurPreRecStart[client] = 0;
        
        g_bPreRecFilled[client] = true;
    }
}

stock void FillFrame( int client, any data[REC_SIZE] )
{
    decl Float:temp[3];
    
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
}

stock void InsertFrame( int client )
{
#if defined DEBUG_INSERTFRAME
    PrintToServer( INF_DEBUG_PRE..."(%i) | Frame: %i", client, GetGameTickCount() );
#endif
    
    static int data[REC_SIZE];

    FillFrame( client, data );
    
    if ( g_hRec[client].PushArray( data ) > g_nMaxRecLength )
    {
        Influx_PrintToChat( _, client, "%T", "INF_RECORDINGEXCEEDEDLIMIT", client, g_ConVar_MaxLength.IntValue );
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
    char szName[MAX_NAME_LENGTH];
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
    // No replay in the first place, just change.
    if ( g_hReplay == null || g_hReplay.Length < 1 )
        return true;
    // We're at the end of the replay, sure.
    if ( IsValidReplayBot() && g_nCurRec[g_iReplayBot] == PLAYBACK_END )
        return true;
    
    
    if ( g_bForcedReplay && (!bCanAdminOverride || !CanUserChangeReplay( issuer )) )
    {
        if ( issuer )
        {
            Influx_PrintToChat( _, issuer, "%T", "INF_REPLAYISNEW", issuer );
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
                Influx_PrintToChat( _, issuer, "%T", "INF_REPLAYALREADYREQUESTED", issuer );
            }
            else
            {
                char szName[32];
                GetClientName( g_iReplayRequester, szName, sizeof( szName ) );
                
                Influx_PrintToChat( _, issuer, "%T", "INF_REPLAYISBEINGWATCHED", issuer, szName );
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

stock bool CanUserDeleteRecordings( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_DELETERECS, ADMFLAG_ROOT );
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
    
    SetClientName( g_iReplayBot, szName );
}

// Set the value and log if it was changed.
stock void SetCvarValueWarn( const char[] szCvar, const char[] szValue )
{
    ConVar cvar = FindConVar( szCvar );
    if ( cvar != null )
    {
        char szPrevValue[64];
        cvar.GetString( szPrevValue, sizeof( szPrevValue ) );

        if ( !StrEqual( szValue, szPrevValue, false ) )
        {
            cvar.SetString( szValue );

            LogMessage( INF_CON_PRE..."Changed replay bot related cvar '%s' to '%s'! Previous: '%s'", szCvar, szValue, szPrevValue );
        }
        
    }
    else
    {
        LogError( INF_CON_PRE..."Failed to find cvar %s!", szCvar );
    }
}

stock void CheckCvarChanges()
{
#if defined DEBUG_CVARS
    PrintToServer( INF_DEBUG_PRE..."Resetting replay bot related cvars..." );
#endif

    SetCvarValueWarn( "bot_quota", "1" );
    SetCvarValueWarn( "bot_quota_mode", "normal" );
    SetCvarValueWarn( "bot_stop", "1" );
    SetCvarValueWarn( "bot_join_after_player", "0" );
    SetCvarValueWarn( "bot_chatter", "off" );
    SetCvarValueWarn( "bot_join_team", "any" );
}

stock void CheckBot()
{
    bool bHasValidBot = IsValidReplayBot();

    bool bKillBotWhenNoPlayersAlive = g_ConVar_KillBotWhenNoPlayersAlive.BoolValue;

    int nPlayersAlive = 0;

    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) )
            continue;

        if ( !bHasValidBot && IsValidReplayBot( i ) )
        {
            g_iReplayBot = i;
            bHasValidBot = true;
        }

        if ( !IsFakeClient( i ) && IsPlayerAlive( i ) )
        {
            ++nPlayersAlive;
        }
    }


    if ( !bHasValidBot )
    {
        return;
    }


    SetBotName();


    if ( bKillBotWhenNoPlayersAlive && nPlayersAlive < 1 )
    {
        if ( IsPlayerAlive( g_iReplayBot ) )
        {
            ChangeClientTeam( g_iReplayBot, CS_TEAM_SPECTATOR );

            LogMessage( INF_CON_PRE..."Set replay bot team to spectator due to no players alive..." );
        }
    }
    else
    {
        if ( GetClientTeam( g_iReplayBot ) <= CS_TEAM_SPECTATOR )
        {
            ChangeClientTeam( g_iReplayBot, CS_TEAM_CT );
        }

        if ( !IsPlayerAlive( g_iReplayBot ) )
        {
            CS_RespawnPlayer( g_iReplayBot );

            LogMessage( INF_CON_PRE..."Respawned replay bot..." );
        }
    }
}

public Action T_CheckBot( Handle hTimer )
{
    CheckCvarChanges();

    CheckBot();

    return Plugin_Continue;
}

// Find new playback if we don't have one already.
public Action T_FindNewPlayback( Handle hTimer )
{
    if ( IsValidReplayBot() && g_hReplay == null )
    {
        FindNewPlayback();
    }

    return Plugin_Continue;
}

stock int CreateRunRec( int runid )
{
    if ( FindRunRecById( runid ) != -1 )
    {
        LogError( INF_CON_PRE..."Attempted to create a run rec data for run of id %i that already exists!", runid );
        return -1;
    }
    

    int data[RUNREC_SIZE];
    data[RUNREC_RUN_ID] = runid;
    
    return g_hRunRec.PushArray( data );
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