#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#include <influx/core>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>
#include <msharedutil/misc>


#undef REQUIRE_PLUGIN
#include <influx/help>
#include <influx/pause>
#include <influx/practise>
#include <influx/zones_freestyle>
#include <influx/runs_sql>
#include <influx/hud>
#include <influx/colorchat>


//#define DEBUG
//#define DEBUG_TIMER
//#define DEBUG_WEPSPD
//#define DEBUG_PARSESEARCH
//#define DEBUG_DB
//#define DEBUG_DB_CBRECS
//#define DEBUG_DB_MAPID


#define GAME_CONFIG_FILE      "influx.games"


// PLAYER STUFF
int g_iRunId[INF_MAXPLAYERS];
int g_iStyleId[INF_MAXPLAYERS];
int g_iModeId[INF_MAXPLAYERS];

int g_iRunStartTick[INF_MAXPLAYERS];
RunState_t g_iRunState[INF_MAXPLAYERS];


float g_flFinishedTime[INF_MAXPLAYERS];


// PLAYER DATABASE RELATED STUFF
int g_iClientId[INF_MAXPLAYERS];
bool g_bCachedTimes[INF_MAXPLAYERS];

// PLAYER CACHE
float g_cache_flPBTime[INF_MAXPLAYERS];
float g_cache_flBestTime[INF_MAXPLAYERS];
char g_cache_szBestName[INF_MAXPLAYERS][MAX_BEST_NAME];
char g_cache_szRunName[INF_MAXPLAYERS][MAX_RUN_NAME];
float g_cache_flMaxSpeed[INF_MAXPLAYERS];
//char g_cache_szModeName[INF_MAXPLAYERS][MAX_NAME_LENGTH];
//char g_cache_szStyleName[INF_MAXPLAYERS][MAX_NAME_LENGTH];


// PLAYER MISC.
float g_flNextStyleGroundCheck[INF_MAXPLAYERS];

float g_flFinishBest[INF_MAXPLAYERS];

float g_flJoinTime[INF_MAXPLAYERS];

float g_flNextMenuTime[INF_MAXPLAYERS];


// ANTI-SPAM
float g_flLastRecPrintTime[INF_MAXPLAYERS];
float g_flNextWepSpdPrintTime[INF_MAXPLAYERS];
float g_flLastValidWepSpd[INF_MAXPLAYERS];



ArrayList g_hRuns;
ArrayList g_hModes;
ArrayList g_hStyles;
ArrayList g_hRunResFlags;



// FORWARDS
Handle g_hForward_OnTimerStart;
Handle g_hForward_OnTimerStartPost;
Handle g_hForward_OnTimerFinish;
Handle g_hForward_OnTimerFinishPost;
Handle g_hForward_OnTimerResetPost;

Handle g_hForward_OnPreRunLoad;
Handle g_hForward_OnPostRunLoad;

Handle g_hForward_OnPostRecordsLoad;

Handle g_hForward_OnRunCreated;
Handle g_hForward_OnRunDeleted;
Handle g_hForward_OnRunLoad;
Handle g_hForward_OnRunSave;

Handle g_hForward_OnClientModeChange;
Handle g_hForward_OnClientModeChangePost;
Handle g_hForward_OnClientStyleChange;
Handle g_hForward_OnClientStyleChangePost;

//Handle g_hForward_OnRequestRuns;
Handle g_hForward_OnRequestModes;
Handle g_hForward_OnRequestStyles;
Handle g_hForward_OnRequestResultFlags;

Handle g_hForward_OnCheckClientStyle;

Handle g_hForward_OnSearchType;


// FUNCS
Handle g_hFunc_GetPlayerMaxSpeed;


// CONVARS
ConVar g_ConVar_AirAccelerate;
ConVar g_ConVar_EnableBunnyhopping;

ConVar g_ConVar_SaveRunsOnMapEnd;
ConVar g_ConVar_SuppressMaxSpdMsg;
ConVar g_ConVar_Admin_RemoveFlags;
ConVar g_ConVar_Admin_ModifyRunFlags;
ConVar g_ConVar_DefMode;
ConVar g_ConVar_DefStyle;
ConVar g_ConVar_DefMaxWeaponSpeed;

ConVar g_ConVar_LadderFreestyle;


// LIBRARIES
bool g_bLib_Pause;
bool g_bLib_Practise;
bool g_bLib_Zones_Fs;
bool g_bLib_Runs_SQL;
bool g_bLib_Hud;
bool g_bLib_ColorChat;


// MAP DATA
char g_szCurrentMap[128];
int g_iCurMapId;
bool g_bNewMapId;
//bool g_bRunsLoaded;
bool g_bBestTimesCached;

// Cached id.
int g_iRunId_Main;
int g_iRunId_Bonus1;
int g_iRunId_Bonus2;

int g_iDefMode;
int g_iDefStyle;

//bool g_bHasLoadedAllData;

#include "influx_core/cmds.sp"
#include "influx_core/db.sp"
#include "influx_core/events.sp"
#include "influx_core/file.sp"
#include "influx_core/menus.sp"
#include "influx_core/menus_admin.sp"
#include "influx_core/natives.sp"
#include "influx_core/natives_chat.sp"
#include "influx_core/runcmd.sp"
//#include "influx_core/timers.sp"


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Core",
    description = "Core of "...INF_NAME,
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    if ( late )
    {
        strcopy( szError, error_len, INF_NAME..." cannot be loaded late!" );
        return APLRes_Failure;
    }
    
    
    EngineVersion eng = GetEngineVersion();
    
    if ( eng != Engine_CSS && eng != Engine_CSGO )
    {
        char szFolder[32];
        GetGameFolderName( szFolder, sizeof( szFolder ) );
        
        FormatEx( szError, error_len, INF_NAME..." does not support %s!", szFolder );
        
        return APLRes_Failure;
    }
    
    
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_CORE );
    
    
    // NATIVES
    CreateNative( "Influx_GetDB", Native_GetDB );
    CreateNative( "Influx_IsMySQL", Native_IsMySQL );
    
    CreateNative( "Influx_GetPostRunLoadForward", Native_GetPostRunLoadForward );
    
    
    CreateNative( "Influx_PrintToChat", Native_PrintToChat );
    CreateNative( "Influx_PrintToChatAll", Native_PrintToChatAll );
    CreateNative( "Influx_PrintToChatEx", Native_PrintToChatEx );
    
    
    CreateNative( "Influx_StartTimer", Native_StartTimer );
    CreateNative( "Influx_FinishTimer", Native_FinishTimer );
    CreateNative( "Influx_ResetTimer", Native_ResetTimer );
    
    CreateNative( "Influx_TeleportToStart", Native_TeleportToStart );
    
    
    
    CreateNative( "Influx_IsClientCached", Native_IsClientCached );
    CreateNative( "Influx_GetClientId", Native_GetClientId );
    CreateNative( "Influx_GetCurrentMapId", Native_GetCurrentMapId );
    
    
    
    CreateNative( "Influx_InvalidateClientRun", Native_InvalidateClientRun );
    
    CreateNative( "Influx_GetClientRunId", Native_GetClientRunId );
    
    CreateNative( "Influx_GetClientMode", Native_GetClientMode );
    CreateNative( "Influx_SetClientMode", Native_SetClientMode );
    
    CreateNative( "Influx_GetClientStyle", Native_GetClientStyle );
    CreateNative( "Influx_SetClientStyle", Native_SetClientStyle );
    
    
    
    CreateNative( "Influx_GetClientState", Native_GetClientState );
    CreateNative( "Influx_SetClientState", Native_SetClientState );
    
    
    CreateNative( "Influx_GetClientTime", Native_GetClientTime );
    CreateNative( "Influx_GetClientFinishedTime", Native_GetClientFinishedTime );
    CreateNative( "Influx_GetClientFinishedBestTime", Native_GetClientFinishedBestTime );
    CreateNative( "Influx_GetClientStartTick", Native_GetClientStartTick );
    CreateNative( "Influx_SetClientStartTick", Native_SetClientStartTick );
    
    CreateNative( "Influx_GetClientPB", Native_GetClientPB );
    CreateNative( "Influx_GetClientCurrentPB", Native_GetClientCurrentPB );
    
    CreateNative( "Influx_GetClientCurrentBestTime", Native_GetClientCurrentBestTime );
    CreateNative( "Influx_GetClientCurrentBestName", Native_GetClientCurrentBestName );
    
    CreateNative( "Influx_GetRunBestTime", Native_GetRunBestTime );
    
    
    
    CreateNative( "Influx_FindRunById", Native_FindRunById );
    
    CreateNative( "Influx_GetRunsArray", Native_GetRunsArray );
    CreateNative( "Influx_GetModesArray", Native_GetModesArray );
    CreateNative( "Influx_GetStylesArray", Native_GetStylesArray );
    
    
    CreateNative( "Influx_GetRunName", Native_GetRunName );
    CreateNative( "Influx_GetModeName", Native_GetModeName );
    CreateNative( "Influx_GetModeShortName", Native_GetModeShortName );
    CreateNative( "Influx_GetStyleName", Native_GetStyleName );
    CreateNative( "Influx_GetStyleShortName", Native_GetStyleShortName );
    
    CreateNative( "Influx_ShouldModeDisplay", Native_ShouldModeDisplay );
    CreateNative( "Influx_ShouldStyleDisplay", Native_ShouldStyleDisplay );
    
    
    
    CreateNative( "Influx_AddRun", Native_AddRun );
    CreateNative( "Influx_AddStyle", Native_AddStyle );
    CreateNative( "Influx_AddMode", Native_AddMode );
    
    CreateNative( "Influx_AddResultFlag", Native_AddResultFlag );
    
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_hRuns = new ArrayList( RUN_SIZE );
    g_hModes = new ArrayList( MODE_SIZE );
    g_hStyles = new ArrayList( STYLE_SIZE );
    g_hRunResFlags = new ArrayList( RUNRES_SIZE );
    
    
    ReadGameConfig();
    
    
    // CONVAR CHANGES
    if ( (g_ConVar_AirAccelerate = FindConVar( "sv_airaccelerate" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_airaccelerate!" );
    }
    
    if ( (g_ConVar_EnableBunnyhopping = FindConVar( "sv_enablebunnyhopping" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_enablebunnyhopping!" );
    }
    
    g_ConVar_AirAccelerate.Flags &= ~(FCVAR_NOTIFY | FCVAR_REPLICATED);
    g_ConVar_EnableBunnyhopping.Flags &= ~(FCVAR_NOTIFY | FCVAR_REPLICATED);
    
    
    // FORWARDS
    g_hForward_OnTimerStart = CreateGlobalForward( "Influx_OnTimerStart", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_Cell );
    g_hForward_OnTimerStartPost = CreateGlobalForward( "Influx_OnTimerStartPost", ET_Ignore, Param_Cell, Param_Cell );
    
    g_hForward_OnTimerFinish = CreateGlobalForward( "Influx_OnTimerFinish", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell );
    g_hForward_OnTimerFinishPost = CreateGlobalForward( "Influx_OnTimerFinishPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell );
    
    g_hForward_OnTimerResetPost = CreateGlobalForward( "Influx_OnTimerResetPost", ET_Ignore, Param_Cell );
    
    
    g_hForward_OnPostRecordsLoad = CreateGlobalForward( "Influx_OnPostRecordsLoad", ET_Ignore );
    
    
    g_hForward_OnPreRunLoad = CreateGlobalForward( "Influx_OnPreRunLoad", ET_Ignore );
    g_hForward_OnPostRunLoad = CreateGlobalForward( "Influx_OnPostRunLoad", ET_Ignore );
    
    g_hForward_OnRunCreated = CreateGlobalForward( "Influx_OnRunCreated", ET_Ignore, Param_Cell );
    g_hForward_OnRunDeleted = CreateGlobalForward( "Influx_OnRunDeleted", ET_Ignore, Param_Cell );
    g_hForward_OnRunLoad = CreateGlobalForward( "Influx_OnRunLoad", ET_Ignore, Param_Cell, Param_Cell );
    g_hForward_OnRunSave = CreateGlobalForward( "Influx_OnRunSave", ET_Ignore, Param_Cell, Param_Cell );
    
    
    
    g_hForward_OnClientModeChange = CreateGlobalForward( "Influx_OnClientModeChange", ET_Event, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnClientModeChangePost = CreateGlobalForward( "Influx_OnClientModeChangePost", ET_Ignore, Param_Cell, Param_Cell );
    
    g_hForward_OnClientStyleChange = CreateGlobalForward( "Influx_OnClientStyleChange", ET_Event, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnClientStyleChangePost = CreateGlobalForward( "Influx_OnClientStyleChangePost", ET_Ignore, Param_Cell, Param_Cell );
    
    
    g_hForward_OnRequestModes = CreateGlobalForward( "Influx_OnRequestModes", ET_Ignore );
    g_hForward_OnRequestStyles = CreateGlobalForward( "Influx_OnRequestStyles", ET_Ignore );
    g_hForward_OnRequestResultFlags = CreateGlobalForward( "Influx_OnRequestResultFlags", ET_Ignore );
    
    
    g_hForward_OnCheckClientStyle = CreateGlobalForward( "Influx_OnCheckClientStyle", ET_Hook, Param_Cell, Param_Cell, Param_Array );
    
    g_hForward_OnSearchType = CreateGlobalForward( "Influx_OnSearchType", ET_Hook, Param_String, Param_CellByRef, Param_CellByRef );
    
    
    // CONVARS
    g_ConVar_SaveRunsOnMapEnd = CreateConVar( "influx_core_saveruns", "1", "Do we automatically save runs on map end?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    g_ConVar_SuppressMaxSpdMsg = CreateConVar( "influx_core_suppressmaxwepspdmsg", "0", "Suppress player max weapon speed warning messages?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    g_ConVar_Admin_RemoveFlags = CreateConVar( "influx_core_removeflags", "z", "Required flags to remove records and runs." );
    g_ConVar_Admin_ModifyRunFlags = CreateConVar( "influx_core_modifyrunflags", "z", "Required flags to modify runs (tele pos, etc)." );
    
    g_ConVar_DefMode = CreateConVar( "influx_defaultmode", "auto", "Default mode.", FCVAR_NOTIFY );
    HookConVarChange( g_ConVar_DefMode, E_ConVarChanged_DefMode );
    g_iDefMode = MODE_AUTO;
    
    g_ConVar_DefStyle = CreateConVar( "influx_defaultstyle", "normal", "Default style.", FCVAR_NOTIFY );
    HookConVarChange( g_ConVar_DefStyle, E_ConVarChanged_DefStyle );
    g_iDefStyle = STYLE_NORMAL;
    
    
    g_ConVar_DefMaxWeaponSpeed = CreateConVar( "influx_default_maxwepspd", "250", "Default maximum weapon speed. Max weapon speed is controlled by modes.", FCVAR_NOTIFY, true, 0.0 );
    g_ConVar_LadderFreestyle = CreateConVar( "influx_ladderfreestyle", "1", "Whether to allow freestyle on ladders.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    AutoExecConfig( true, "core", "influx" );
    
    
    // MENUS
    RegConsoleCmd( "sm_influx", Cmd_Credits );
    RegConsoleCmd( "sm_credits", Cmd_Credits );
    
    
    RegConsoleCmd( "sm_run", Cmd_Change_Run );
    RegConsoleCmd( "sm_runs", Cmd_Change_Run );
    
    RegConsoleCmd( "sm_mode", Cmd_Change_Mode );
    RegConsoleCmd( "sm_modes", Cmd_Change_Mode );
    
    RegConsoleCmd( "sm_style", Cmd_Change_Style );
    RegConsoleCmd( "sm_styles", Cmd_Change_Style );
    
    
    // CMDS
    RegConsoleCmd( "sm_version", Cmd_Version );
    
    
    RegConsoleCmd( "sm_r", Cmd_Restart );
    RegConsoleCmd( "sm_re", Cmd_Restart );
    RegConsoleCmd( "sm_restart", Cmd_Restart );
    RegConsoleCmd( "sm_start", Cmd_Restart );
    
    
    RegConsoleCmd( "sm_main", Cmd_Main );
    RegConsoleCmd( "sm_m", Cmd_Main );
    
    RegConsoleCmd( "sm_bonus", Cmd_BonusChoose );
    RegConsoleCmd( "sm_b", Cmd_BonusChoose );
    
    RegConsoleCmd( "sm_bonus1", Cmd_Bonus1 );
    RegConsoleCmd( "sm_b1", Cmd_Bonus1 );
    RegConsoleCmd( "sm_bonus2", Cmd_Bonus2 );
    RegConsoleCmd( "sm_b2", Cmd_Bonus2 );
    
    
    // RECORD CMDS
    RegConsoleCmd( "sm_top", Cmd_PrintRecords );
    RegConsoleCmd( "sm_wr", Cmd_PrintRecords );
    RegConsoleCmd( "sm_records", Cmd_PrintRecords );
    
    RegConsoleCmd( "sm_myrecords", Cmd_PrintMyRecords );
    RegConsoleCmd( "sm_myrec", Cmd_PrintMyRecords );
    RegConsoleCmd( "sm_mytop", Cmd_PrintMyRecords );
    
    RegConsoleCmd( "sm_wrmaps", Cmd_PrintMapsRecords );
    RegConsoleCmd( "sm_topmaps", Cmd_PrintMapsRecords );
    
    
    // ADMIN MENUS
    RegConsoleCmd( "sm_manageruns", Cmd_Admin_RunMenu );
    RegConsoleCmd( "sm_runmenu", Cmd_Admin_RunMenu );
    
    RegConsoleCmd( "sm_runsettings", Cmd_Admin_RunSettings );
    
    RegConsoleCmd( "sm_deleterecords", Cmd_Admin_DeleteRecords );
    
    
    // ADMIN CMDS
    RegConsoleCmd( "sm_saveruns", Cmd_Admin_SaveRuns );
    
    RegConsoleCmd( "sm_setrunname", Cmd_Admin_SetRunName );
    
    RegConsoleCmd( "sm_settelepos", Cmd_Admin_SetTelePos );
    
    RegConsoleCmd( "sm_deleterun", Cmd_Admin_DeleteRun );
    
    
    // EVENTS
    HookEvent( "player_spawn", E_PlayerSpawn );
    
    
    // LIBRARIES
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
    g_bLib_Practise = LibraryExists( INFLUX_LIB_PRACTISE );
    g_bLib_Zones_Fs = LibraryExists( INFLUX_LIB_ZONES_FS );
    g_bLib_Runs_SQL = LibraryExists( INFLUX_LIB_RUNS_SQL );
    g_bLib_Hud = LibraryExists( INFLUX_LIB_HUD );
    g_bLib_ColorChat = LibraryExists( INFLUX_LIB_COLORCHAT );
    
    
    DB_Init();
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = true;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = true;
    if ( StrEqual( lib, INFLUX_LIB_ZONES_FS ) ) g_bLib_Zones_Fs = true;
    if ( StrEqual( lib, INFLUX_LIB_RUNS_SQL ) ) g_bLib_Runs_SQL = true;
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = true;
    if ( StrEqual( lib, INFLUX_LIB_COLORCHAT ) ) g_bLib_ColorChat = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = false;
    if ( StrEqual( lib, INFLUX_LIB_ZONES_FS ) ) g_bLib_Zones_Fs = false;
    if ( StrEqual( lib, INFLUX_LIB_RUNS_SQL ) ) g_bLib_Runs_SQL = false;
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = false;
    if ( StrEqual( lib, INFLUX_LIB_COLORCHAT ) ) g_bLib_ColorChat = false;
}

public void OnAllPluginsLoaded()
{
    g_hModes.Clear();
    g_hStyles.Clear();
    g_hRunResFlags.Clear();
    
    
    AddResultFlag( "Don't save record", RES_TIME_DONTSAVE );
    
    
    // Request modes and styles.
    Call_StartForward( g_hForward_OnRequestModes );
    Call_Finish();
    
    Call_StartForward( g_hForward_OnRequestStyles );
    Call_Finish();
    
    Call_StartForward( g_hForward_OnRequestResultFlags );
    Call_Finish();
    
    
    if ( !g_hStyles.Length )
    {
        SetFailState( INF_CON_PRE..."No styles were found!" );
    }
    
    if ( !g_hModes.Length )
    {
        g_ConVar_AirAccelerate.Flags |= (FCVAR_NOTIFY | FCVAR_REPLICATED);
        g_ConVar_EnableBunnyhopping.Flags |= (FCVAR_NOTIFY | FCVAR_REPLICATED);
        
        AddMode( MODE_SCROLL, "Scroll", "SCRL" );
        
        LogError( INF_CON_PRE..."No modes were found! Assuming scroll as default mode!!! Freeing sv_airaccelerate and sv_enablebunnyhopping." );
    }
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "manageruns", "Run menu.", true );
    Influx_AddHelpCommand( "saveruns", "Saves all current runs.", true );
    
    Influx_AddHelpCommand( "setrunname <name>", "Set current run's name.", true );
    //Influx_AddHelpCommand( "settelepos", "Set current run's tele position and yaw.", true );
    Influx_AddHelpCommand( "deleterun <id>", "Delete a run.", true );
    Influx_AddHelpCommand( "deleterecords", "Delete a specific run's records.", true );
    
    
    Influx_AddHelpCommand( "wr/records <args>", "Display records.\nValid arguments are maps, players, styles, modes, etc." );
    Influx_AddHelpCommand( "myrecords", "Display your records." );
    Influx_AddHelpCommand( "wrmaps", "Display map selector for records." );
    
    Influx_AddHelpCommand( "restart/r", "Go back to start or respawn." );
    
    Influx_AddHelpCommand( "run", "Display run selector menu." );
    Influx_AddHelpCommand( "style", "Display style selector menu." );
    Influx_AddHelpCommand( "mode", "Display mode selector menu." );
}

public void Influx_OnPostRunLoad() // May be called from runs_sql...
{
    //g_bRunsLoaded = true;
    
    DetermineRuns();
}

public void OnMapStart()
{
    g_hRuns.Clear();
    
    
    if ( g_hFunc_GetPlayerMaxSpeed == null && !g_ConVar_SuppressMaxSpdMsg.BoolValue )
    {
        Inf_Warning( 3, "Weapon speed check cannot be made! Players are free to cheat with weapon speeds." );
    }
    
    
    GetCurrentMapSafe( g_szCurrentMap, sizeof( g_szCurrentMap ) );
    
    //g_bRunsLoaded = false;
    
    g_bNewMapId = false;
    g_bBestTimesCached = false;
    g_iCurMapId = 0;
    
    DB_InitMap();
    
    
    Call_StartForward( g_hForward_OnPreRunLoad );
    Call_Finish();
    
    if ( !g_bLib_Runs_SQL )
    {
        ReadMapFile();
        
        Call_StartForward( g_hForward_OnPostRunLoad );
        Call_Finish();
    }
}

public void OnMapEnd()
{
    if ( g_ConVar_SaveRunsOnMapEnd.BoolValue )
    {
        WriteMapFile();
    }
}

public void OnConfigsExecuted()
{
    // HACK: These shouldn't be here, gotta move that gear up!
    ConVar cvar;
    
    
    cvar = FindConVar( "mp_ignore_round_win_conditions" );
    if ( cvar != null )
    {
        cvar.SetBool( true );
        delete cvar;
    }
    
    cvar = FindConVar( "mp_autoteambalance" );
    if ( cvar != null )
    {
        cvar.SetBool( false );
        delete cvar;
    }
    
    cvar = FindConVar( "mp_limitteams" );
    if ( cvar != null )
    {
        cvar.SetInt( 0 );
        delete cvar;
    }
    
    cvar = FindConVar( "mp_spectators_max" );
    if ( cvar != null )
    {
        cvar.SetInt( 1337 );
        delete cvar;
    }
    
    cvar = FindConVar( "sv_staminajumpcost" );
    if ( cvar != null )
    {
        cvar.SetFloat( 0.0 );
        delete cvar;
    }
    
    cvar = FindConVar( "sv_staminalandcost" );
    if ( cvar != null )
    {
        cvar.SetFloat( 0.0 );
        delete cvar;
    }
}

public void OnClientPutInServer( int client )
{
    ResetClient( client );
    
    
    if ( !IsFakeClient( client ) )
    {
        InitClientModeStyle( client );
        
        
        ResetAllClientTimes( client );
        
        
        UpdateClientCachedByIndex( client, -1 );
        
        Inf_SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
    }
}

public void OnClientPostAdminCheck( int client )
{
    if ( !IsFakeClient( client ) )
    {
        DB_InitClient( client );
    }
}

public void OnClientDisconnect( int client )
{
    g_iClientId[client] = 0;
    g_bCachedTimes[client] = false;
    
    
    if ( !IsFakeClient( client ) )
    {
        SDKUnhook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
        
        DB_UpdateClient( client );
    }
}

public void E_PostThinkPost_Client( int client )
{
    if ( !IsPlayerAlive( client ) ) return;
    
    
    // Check for cheating.
    
    if ( g_iRunState[client] == STATE_RUNNING )
    {
        if ( GetEntityMoveType( client ) == MOVETYPE_NOCLIP && !IS_PAUSED( g_bLib_Pause, client ) && !IS_PRAC( g_bLib_Practise, client ) )
        {
            InvalidateClientRun( client );
        }
        
        
        CapWeaponSpeed( client );
    }
}

stock void CapWeaponSpeed( int client )
{
    // Make sure players don't cheat with weapons going over 250-260, depending on their mode.
    
    if ( IS_PRAC( g_bLib_Practise, client ) || IS_PAUSED( g_bLib_Pause, client ) ) return;
    
    
    float maxspd = GetPlayerMaxSpeed( client );
    
    if ( maxspd != 0.0 && maxspd > g_cache_flMaxSpeed[client] )
    {
        // HACK
        if ( GetEntityFlags( client ) & FL_ONGROUND )
        {
            decl Float:vel[3];
            GetEntityVelocity( client, vel );
            
            float spd = SquareRoot( vel[0] * vel[0] + vel[1] * vel[1] + vel[2] * vel[2] );
            
#define LIMIT_SPD       225.0
            
            if ( spd > LIMIT_SPD )
            {
                for ( int i = 0; i < 3; i++ )
                {
                    vel[i] = ( vel[i] / spd ) * LIMIT_SPD;
                }
                
                TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vel );
            }
        }
        
        if ((GetEngineTime() - g_flLastValidWepSpd[client]) > 0.2 // We have the invalid weapon out for more than this.
        &&  g_flNextWepSpdPrintTime[client] < GetEngineTime() )
        {
            Influx_PrintToChat( _, client, "Invalid weapon speed! Can be {TEAM}%.0f{CHATCLR} at most!", g_cache_flMaxSpeed[client] );
            
            g_flNextWepSpdPrintTime[client] = GetEngineTime() + 10.0;
        }
        
    }
    else
    {
        g_flLastValidWepSpd[client] = GetEngineTime();
    }
}

stock int FindRunById( int runid )
{
    int len = g_hRuns.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hRuns.Get( i, RUN_ID ) == runid )
        {
            return i;
        }
    }
    
    return -1;
}

stock float GetClientPB( int client, int runid, int modeid, int styleid )
{
    int irun = FindRunById( runid );
    if ( irun == -1 ) return INVALID_RUN_TIME;
    
    if ( FindModeById( modeid ) == -1 ) return INVALID_RUN_TIME;
    
    if ( FindStyleById( styleid ) == -1 ) return INVALID_RUN_TIME;
    
    
    return GetClientRunTime( irun, client, modeid, styleid );
}

stock bool TeleClientToStart_Safe( int client, int runid )
{
    if ( TeleClientToStart( client, runid ) ) return true;
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."(Safe) Failed to teleport client %i to run %i. Falling back.", client, runid );
#endif
    
    // If we have no main run, teleport to any run then.
    int def_target = MAIN_RUN_ID;
    
    if ( runid == def_target && g_hRuns.Length > 0 )
    {
        def_target = GetRunIdByIndex( 0 );
    }
    
    if ( TeleClientToStart( client, def_target ) ) return true;
    
    
    g_iRunState[client] = STATE_NONE;
    
    // Only throw an error if we have runs in the first place.
    if ( g_hRuns.Length > 0 )
    {
        LogError( INF_CON_PRE..."Couldn't teleport client %i to run %i or %i!", client, runid, def_target );
    }
    
    return false;
}

stock bool TeleClientToStart( int client, int runid )
{
    int irun = FindRunById( runid );
    
    if ( irun == -1 ) return false;
    
    
    // Set to none just in case something terrible happens.
    g_iRunState[client] = STATE_NONE;
    
    float pos[3];
    GetRunTelePos( irun, pos );
    
    float ang[3];
    ang[1] = GetRunTeleYaw( irun );
    
    TeleportEntity( client, pos, ang, ORIGIN_VECTOR );
    
    return true;
}

stock void GetRunTelePos( int irun, float out[3] )
{
    out[0] = g_hRuns.Get( irun, RUN_TELEPOS );
    out[1] = g_hRuns.Get( irun, RUN_TELEPOS + 1 );
    out[2] = g_hRuns.Get( irun, RUN_TELEPOS + 2 );
}

stock float GetRunTeleYaw( int irun )
{
    return view_as<float>( g_hRuns.Get( irun, RUN_TELEYAW ) );
}

// If we have only one choice, don't display.
stock bool ShouldModeDisplay( int mode )
{
    if ( g_hModes.Length == 1 ) return false;
    
    
    int i = FindModeById( mode );
    
    return ( i != -1 ) ? g_hModes.Get( i, MODE_DISPLAY ) : 0;
}

stock bool ShouldStyleDisplay( int style )
{
    if ( g_hStyles.Length == 1 ) return false;
    
    
    int i = FindStyleById( style );
    
    return ( i != -1 ) ? g_hStyles.Get( i, STYLE_DISPLAY ) : 0;
}

stock bool AddMode( int id, const char[] szName, const char[] szShortName, float flMaxSpeed = 0.0 )
{
    // This mode id is already taken!
    int index = FindModeById( id );
    if ( index != -1 )
    {
        char sz[64];
        GetModeNameByIndex( index, sz, sizeof( sz ) );
        
        LogError( INF_CON_PRE..."Attempted to add an already existing mode (%s - %i)!", sz, id );
        
        return false;
    }
    
    
    int data[MODE_SIZE];
    strcopy( view_as<char>( data[MODE_NAME] ), MAX_MODE_NAME, szName );
    strcopy( view_as<char>( data[MODE_SHORTNAME] ), MAX_MODE_SHORTNAME, szShortName );
    
    data[MODE_ID] = id;
    data[MODE_DISPLAY] = 1;
    
    
    float spd = flMaxSpeed;
    
    /*if ( spd <= 0.0 )
    {
        spd = g_ConVar_DefMaxWeaponSpeed.FloatValue;
    }*/
    
    data[MODE_MAXSPEED] = view_as<int>( spd );
    
    g_hModes.PushArray( data );
    
    return true;
}

stock bool AddStyle( int id, const char[] szName, const char[] szShortName, bool bDisplay = true )
{
    // This style id is already taken!
    int index = FindStyleById( id );
    if ( index != -1 )
    {
        char sz[64];
        GetStyleNameByIndex( index, sz, sizeof( sz ) );
        
        LogError( INF_CON_PRE..."Attempted to add an already existing style (%s - %i)!", sz, id );
        
        return false;
    }
    
    int data[STYLE_SIZE];
    strcopy( view_as<char>( data[STYLE_NAME] ), MAX_STYLE_NAME, szName );
    strcopy( view_as<char>( data[STYLE_SHORTNAME] ), MAX_STYLE_SHORTNAME, szShortName );
    
    data[STYLE_ID] = id;
    data[STYLE_DISPLAY] = bDisplay;
    
    g_hStyles.PushArray( data );
    
    return true;
}

stock bool IsValidResultFlag( int flag )
{
    if ( flag & RES_TIME_FIRSTREC ) return false;
    if ( flag & RES_TIME_ISBEST ) return false;
    if ( flag & RES_TIME_FIRSTOWNREC ) return false;
    if ( flag & RES_TIME_PB ) return false;
    
    return true;
}

stock bool AddResultFlag( const char[] szName, int flag )
{
    if ( !IsValidResultFlag( flag ) )
    {
        LogError( INF_CON_PRE..."Attempted to add invalid result flag (%i)!", flag );
        return false;
    }
    
    int len = g_hRunResFlags.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hRunResFlags.Get( i, RUNRES_FLAG ) & flag )
        {
            LogError( INF_CON_PRE..."Attempted to add an already existing result flag (%i)!", flag );
            return false;
        }
    }
    
    
    decl data[RUNRES_SIZE];
    
    data[RUNRES_FLAG] = flag;
    strcopy( view_as<char>( data[RUNRES_NAME] ), MAX_RUNRES_NAME, szName );
    
    g_hRunResFlags.PushArray( data );
    
    return true;
}

stock int GetRunIdByIndex( int index )
{
    return ( index != -1 ) ? g_hRuns.Get( index, RUN_ID ) : -1;
}

stock int GetModeIdByIndex( int index )
{
    return ( index != -1 ) ? g_hModes.Get( index, MODE_ID ) : MODE_INVALID;
}

stock int GetStyleIdByIndex( int index )
{
    return ( index != -1 ) ? g_hStyles.Get( index, STYLE_ID ) : STYLE_INVALID;
}

stock int FindModeById( int id )
{
    int len = g_hModes.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hModes.Get( i, MODE_ID ) == id )
            return i;
    }
    
    return -1;
}

stock int FindStyleById( int id )
{
    int len = g_hStyles.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hStyles.Get( i, STYLE_ID ) == id )
            return i;
    }
    
    return -1;
}

stock void GetRunName( int id, char[] out, int len )
{
    GetRunNameByIndex( FindRunById( id ), out, len );
}

stock void GetRunNameByIndex( int index, char[] out, int len )
{
    if ( index != -1 )
    {
        decl name[MAX_RUN_NAME_CELL];
        
        for ( int i = 0; i < MAX_RUN_NAME_CELL; i++ )
        {
            name[i] = g_hRuns.Get( index, RUN_NAME + i );
        }
        
        strcopy( out, len, view_as<char>( name ) );
    }
    else
    {
        strcopy( out, len, "N/A" );
    }
}

stock void SetRunNameByIndex( int index, const char[] sz )
{
    if ( index == -1 ) return;
    
    
    decl name[MAX_RUN_NAME_CELL];
    strcopy( view_as<char>( name ), MAX_RUN_NAME, sz );
    
    for ( int i = 0; i < MAX_RUN_NAME_CELL; i++ )
    {
        g_hRuns.Set( index, name[i], RUN_NAME + i );
    }
}

stock void GetModeName( int id, char[] out, int len )
{
    GetModeNameByIndex( FindModeById( id ), out, len );
}

stock void GetModeNameByIndex( int index, char[] out, int len )
{
    if ( index != -1 )
    {
        decl name[MAX_MODE_NAME_CELL];
        
        for ( int i = 0; i < MAX_MODE_NAME_CELL; i++ )
        {
            name[i] = g_hModes.Get( index, MODE_NAME + i );
        }
        
        strcopy( out, len, view_as<char>( name ) );
    }
    else
    {
        strcopy( out, len, "N/A" );
    }
}

stock void GetModeShortName( int id, char[] out, int len )
{
    GetModeShortNameByIndex( FindModeById( id ), out, len );
}

stock void GetModeShortNameByIndex( int index, char[] out, int len )
{
    if ( index != -1 )
    {
        decl name[MAX_MODE_SHORTNAME_CELL];
        
        for ( int i = 0; i < MAX_MODE_SHORTNAME_CELL; i++ )
        {
            name[i] = g_hModes.Get( index, MODE_SHORTNAME + i );
        }
        
        strcopy( out, len, view_as<char>( name ) );
    }
    else
    {
        strcopy( out, len, "N/A" );
    }
}

stock void GetStyleName( int id, char[] out, int len )
{
    GetStyleNameByIndex( FindStyleById( id ), out, len );
}

stock void GetStyleNameByIndex( int index, char[] out, int len )
{
    if ( index != -1 )
    {
        decl name[MAX_STYLE_NAME_CELL];
        
        for ( int i = 0; i < MAX_STYLE_NAME_CELL; i++ )
        {
            name[i] = g_hStyles.Get( index, STYLE_NAME + i );
        }
        
        strcopy( out, len, view_as<char>( name ) );
    }
    else
    {
        strcopy( out, len, "N/A" );
    }
}

stock void GetStyleShortName( int id, char[] out, int len )
{
    GetStyleShortNameByIndex( FindStyleById( id ), out, len );
}

stock void GetStyleShortNameByIndex( int index, char[] out, int len )
{
    if ( index != -1 )
    {
        decl name[MAX_STYLE_SHORTNAME_CELL];
        
        for ( int i = 0; i < MAX_STYLE_SHORTNAME_CELL; i++ )
        {
            name[i] = g_hStyles.Get( index, STYLE_SHORTNAME + i );
        }
        
        strcopy( out, len, view_as<char>( name ) );
    }
    else
    {
        strcopy( out, len, "N/A" );
    }
}

/*stock int GetRunNumRecords( int index, int mode, int style )
{
    return g_hRuns.Get( index, RUN_NUMRECORDS + OFFSET_MODESTYLE( mode, style ) );
}

stock void SetRunNumRecords( int index, int mode, int style, int num )
{
    g_hRuns.Set( index, num, RUN_NUMRECORDS + OFFSET_MODESTYLE( mode, style ) );
}*/

stock float GetRunBestTime( int index, int mode, int style )
{
    return view_as<float>( g_hRuns.Get( index, RUN_BESTTIMES + OFFSET_MODESTYLE( mode, style ) ) );
}

stock void SetRunBestTime( int index, int mode, int style, float time, int uid = 0 )
{
    int offset = OFFSET_MODESTYLE( mode, style );
    
    g_hRuns.Set( index, time, RUN_BESTTIMES + offset );
    g_hRuns.Set( index, uid, RUN_BESTTIMES_UID + offset );
}

stock int GetRunBestTimeId( int index, int mode, int style )
{
    return g_hRuns.Get( index, RUN_BESTTIMES_UID + OFFSET_MODESTYLE( mode, style ) );
}

stock void GetRunBestName( int index, int mode, int style, char[] out, int len )
{
    decl name[MAX_BEST_NAME_CELL];
    
    
    int offset = OFFSET_MODESTYLESIZE( mode, style, MAX_BEST_NAME_CELL );
    
    for ( int i = 0; i < sizeof( name ); i++ )
    {
        name[i] = g_hRuns.Get( index, RUN_BESTTIMES_NAME + offset + i );
    }
    
    strcopy( out, len, view_as<char>( name ) );
}

stock void SetRunBestName( int index, int mode, int style, const char[] szName )
{
    decl String:sz[MAX_BEST_NAME + 1];
    decl name[MAX_BEST_NAME_CELL];
    
    strcopy( sz, sizeof( sz ), szName );
    
    
    LimitString( sz, sizeof( sz ), MAX_BEST_NAME );
    
    
    // We cannot use SetString and retrieving the whole array is only slow.
    // So we copy the name into a cell array and save it using Set.
    strcopy( view_as<char>( name ), MAX_BEST_NAME, sz );
    
    
    int offset = OFFSET_MODESTYLESIZE( mode, style, MAX_BEST_NAME_CELL );
    
    for ( int i = 0; i < sizeof( name ); i++ )
    {
        g_hRuns.Set( index, name[i], RUN_BESTTIMES_NAME + offset + i );
    }
}

stock float GetClientRunTime( int index, int client, int mode, int style )
{
    return view_as<float>( g_hRuns.Get( index, RUN_CLIENTTIMES + OFFSET_MODESTYLECLIENT( mode, style, client ) ) );
}

stock void SetClientRunTime( int index, int client, int mode, int style, float time )
{
    g_hRuns.Set( index, time, RUN_CLIENTTIMES + OFFSET_MODESTYLECLIENT( mode, style, client ) );
}

stock int FindValidModeFromFlags( int modeflags )
{
    int len = g_hModes.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( !(modeflags & (1 << GetModeIdByIndex( i ))) ) // Found a match!
        {
            return GetModeIdByIndex( i );
        }
    }
    
    return MODE_INVALID;
}

stock void PrintValidModes( int client, int modeflags )
{
    decl String:list[128];
    list[0] = '\0';
    
    decl String:mode[MAX_MODE_NAME];
    
    int len = g_hModes.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( !(modeflags & (1 << GetModeIdByIndex( i ))) )
        {
            GetModeNameByIndex( i, mode, sizeof( mode ) );
            
            Format( list, sizeof( list ), "%s%s{TEAM}%s{CHATCLR}",
                list,
                ( list[0] != '\0' ) ? ", " : "",
                mode );
        }
    }
    
    // No modes were added to the list!
    if ( list[0] == '\0' )
    {
        strcopy( list, sizeof( list ), "{TEAM}None{CHATCLR}!" );
    }
    
    Influx_PrintToChat( _, client, "Valid mode(s): %s", list );
}

stock bool SetClientRun( int client, int runid, bool bTele = true, bool bPrintToChat = true )
{
    int irun = FindRunById( runid );
    if ( irun == -1 ) return false;
    
    if ( bTele && !TeleClientToStart( client, runid ) ) return false;
    
    
    // Is our mode allowed on this run?
    if ( !IsClientModeValidForRun( client, FindModeById( g_iModeId[client] ), irun, bPrintToChat ) )
    {
        // Find valid mode for this run.
        int modeflags = g_hRuns.Get( irun, RUN_MODEFLAGS );
        
        if ( bPrintToChat )
        {
            PrintValidModes( client, modeflags );
        }
        
        
        int mode = FindValidModeFromFlags( modeflags );
        if ( mode != -1 )
        {
            if ( !SetClientMode( client, mode, false, bPrintToChat ) )
            {
                return false;
            }
        }
        else
        {
            return false;
        }
    }
    
    
    int lastrun = g_iRunId[client];
    g_iRunId[client] = runid;
    
    
    if ( lastrun != runid )
    {
        char sz[MAX_RUN_NAME];
        GetRunNameByIndex( irun, sz, sizeof( sz ) );
        
        
        strcopy( g_cache_szRunName[client], sizeof( g_cache_szRunName[] ), sz );
        
        if ( bPrintToChat )
        {
            Influx_PrintToChat( _, client, "Your run is now {TEAM}%s{CHATCLR}!", sz );
        }
    }
    
    UpdateClientCachedByIndex( client, irun );
    
    return true;
}

stock bool SetClientMode( int client, int mode, bool bTele = true, bool bPrintToChat = true, bool bNewIfNotValidRun = false )
{
    int imode = FindModeById( mode );
    if ( imode == -1 ) return false;
    
    if ( bTele && !ChangeTele( client ) ) return false;
    
    // Check if allowed for our run!
    int irun = FindRunById( g_iRunId[client] );
    if ( !IsClientModeValidForRun( client, imode, irun, bPrintToChat ) )
    {
        int modeflags = g_hRuns.Get( irun, RUN_MODEFLAGS );
        
        
        if ( bPrintToChat )
        {
            PrintValidModes( client, modeflags );
        }
        
        if ( bNewIfNotValidRun )
        {
            int newmode = FindValidModeFromFlags( modeflags );
            
            if ( newmode != MODE_INVALID )
            {
                mode = newmode;
                imode = FindModeById( mode );
            }
            else
            {
                return false;
            }
        }
        else
        {
            return false;
        }
    }
    
    
    int lastmode = g_iModeId[client];
    
    
    Action res;
    
    Call_StartForward( g_hForward_OnClientModeChange );
    Call_PushCell( client );
    Call_PushCell( mode );
    Call_PushCell( lastmode );
    Call_Finish( res );
    
    
    if ( res != Plugin_Continue )
    {
        if ( bPrintToChat )
        {
            Influx_PrintToChat( _, client, "Something went wrong when changing your mode!" );
        }
        
        // Fallback to last mode.
        mode = lastmode;
        imode = FindModeById( mode );
    }
    
    
    if ( bPrintToChat && lastmode != mode )
    {
        char sz[MAX_MODE_NAME];
        GetModeNameByIndex( imode, sz, sizeof( sz ) );
        
        Influx_PrintToChat( _, client, "Your mode is now {TEAM}%s{CHATCLR}!", sz );
    }
    
    
    g_iModeId[client] = mode;
    
    
    g_cache_flMaxSpeed[client] = GetModeMaxspeedByIndex( imode );
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Set client %i max speed to %.1f", client, g_cache_flMaxSpeed[client] );
#endif
    
    Call_StartForward( g_hForward_OnClientModeChangePost );
    Call_PushCell( client );
    Call_PushCell( mode );
    Call_Finish();
    
    
    UpdateClientCached( client );
    
    return true;
}

stock bool SetClientStyle( int client, int style, bool bTele = true, bool bPrintToChat = true )
{
    int istyle = FindStyleById( style );
    if ( istyle == -1 ) return false;
    
    if ( bTele && !ChangeTele( client ) ) return false;
    
    
    int laststyle = g_iStyleId[client];
    
    
    Action res;
    
    Call_StartForward( g_hForward_OnClientStyleChange );
    Call_PushCell( client );
    Call_PushCell( style );
    Call_PushCell( laststyle );
    Call_Finish( res );
    
    
    if ( res != Plugin_Continue )
    {
        Influx_PrintToChat( _, client, "Something went wrong when changing your style!" );
        
        // Fallback to last style.
        style = laststyle;
        istyle = FindStyleById( style );
    }
    
    
    if ( bPrintToChat && laststyle != style )
    {
        char sz[MAX_STYLE_NAME];
        GetStyleNameByIndex( istyle, sz, sizeof( sz ) );
        
        Influx_PrintToChat( _, client, "Your style is now {TEAM}%s{CHATCLR}!", sz );
    }
    
    g_iStyleId[client] = style;
    
    
    Call_StartForward( g_hForward_OnClientStyleChangePost );
    Call_PushCell( client );
    Call_PushCell( style );
    Call_Finish();
    
    
    UpdateClientCached( client );
    
    return true;
}

stock bool IsClientModeValidForRun( int client, int imode, int irun, bool bPrintToChat = true )
{
    if ( irun == -1 || imode == -1 )
        return true;
    
    
    if ( g_hRuns.Get( irun, RUN_MODEFLAGS ) & (1 << GetModeIdByIndex( imode )) )
    {
        if ( bPrintToChat )
        {
            char mode[MAX_MODE_NAME];
            char run[MAX_RUN_NAME];
            
            GetModeNameByIndex( imode, mode, sizeof( mode ) );
            GetRunNameByIndex( irun, run, sizeof( run ) );
            
            Influx_PrintToChat( _, client, "Sorry, mode {TEAM}%s{CHATCLR} is not allowed in {TEAM}%s{CHATCLR}!", mode, run );
        }
        
        return false;
    }
    
    return true;
}

// When changing mode/style
stock bool ChangeTele( int client )
{
    // Ignore if we're practising.
    // If we are paused at the same time, we have to get teleported.
    if ( IS_PRAC( g_bLib_Practise, client ) && !IS_PAUSED( g_bLib_Pause, client ) ) return true;
    
    // We successfully teleported
    if ( TeleClientToStart_Safe( client, g_iRunId[client] ) ) return true;
    
    // If we aren't running, it's fine.
    if ( g_iRunState[client] != STATE_RUNNING ) return true;
    
    
    
    g_iRunState[client] = STATE_NONE;
    
    
    LogError( INF_CON_PRE..."Couldn't teleport client %i when changing mode/style!", client );
    
    return false;
}

stock bool CanUserRemoveRecords( int client )
{
    if ( client == 0 ) return true;
    
    
    char szFlags[32];
    g_ConVar_Admin_RemoveFlags.GetString( szFlags, sizeof( szFlags ) );
    
    int wantedflags = ReadFlagString( szFlags );
    
    return ( (GetUserFlagBits( client ) & wantedflags) == wantedflags );
}

stock bool CanUserModifyRun( int client )
{
    if ( client == 0 ) return true;
    
    
    char szFlags[32];
    g_ConVar_Admin_ModifyRunFlags.GetString( szFlags, sizeof( szFlags ) );
    
    int wantedflags = ReadFlagString( szFlags );
    
    return ( (GetUserFlagBits( client ) & wantedflags) == wantedflags );
}

// TODO: Make sure this is called every time times change.
stock void UpdateAllClientsCached( int runid, int mode, int style )
{
    int irun = FindRunById( runid );
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if (IsClientInGame( i )
        &&  !IsFakeClient( i )
        &&  g_iRunId[i] == runid
        &&  g_iModeId[i] == mode
        &&  g_iStyleId[i] == style)
        {
            UpdateClientCachedByIndex( i, irun );
        }
    }
}

stock void UpdateClientCached( int client )
{
    UpdateClientCachedByIndex( client, FindRunById( g_iRunId[client] ) );
}

stock void UpdateClientCachedByIndex( int client, int irun )
{
    int mode = g_iModeId[client];
    int style = g_iStyleId[client];
    
    if ( irun != -1 && VALID_MODE( mode ) && VALID_STYLE( style ) )
    {
        g_cache_flPBTime[client] = GetClientRunTime( irun, client, mode, style );
        g_cache_flBestTime[client] = GetRunBestTime( irun, mode, style );
        
        GetRunBestName( irun, mode, style, g_cache_szBestName[client], sizeof( g_cache_szBestName[] ) );
    }
    else
    {
        g_cache_flPBTime[client] = INVALID_RUN_TIME;
        g_cache_flBestTime[client] = INVALID_RUN_TIME;
        
        strcopy( g_cache_szBestName[client], sizeof( g_cache_szBestName[] ), "N/A" );
    }
}

stock float GetPlayerMaxSpeed( int client )
{
#if defined DEBUG_WEPSPD
    PrintToServer( INF_DEBUG_PRE..."GetPlayerMaxSpeed(%i): %.1f",
        client,
        ( g_hFunc_GetPlayerMaxSpeed != null ) ? SDKCall( g_hFunc_GetPlayerMaxSpeed, client ) : 0.0 );
#endif
    
    return ( g_hFunc_GetPlayerMaxSpeed != null ) ? SDKCall( g_hFunc_GetPlayerMaxSpeed, client ) : 0.0;
}

stock float GetModeMaxspeedByIndex( int index )
{
    if ( index != -1 )
    {
        float spd = g_hModes.Get( index, MODE_MAXSPEED );
        
        
        return ( spd > 0.0 ) ? spd : g_ConVar_DefMaxWeaponSpeed.FloatValue;
    }
    else
    {
        return g_ConVar_DefMaxWeaponSpeed.FloatValue;
    }
}

stock bool IsProperlyCached( int client )
{
    // Check if we are cached properly.
    return ( g_bBestTimesCached && g_bCachedTimes[client] );
}

stock void DetermineRuns()
{
    g_iRunId_Main = -1;
    g_iRunId_Bonus1 = -1;
    g_iRunId_Bonus2 = -1;
    
    char szRun[MAX_RUN_NAME];
    
    int len = g_hRuns.Length;
    for ( int i = 0; i < len; i++ )
    {
        GetRunNameByIndex( i, szRun, sizeof( szRun ) );
        
        int id = GetRunIdByIndex( i );
        
        if ( StrContains( szRun, "main", false ) != -1 )
        {
            g_iRunId_Main = id;
        }
        else if ( StrContains( szRun, "bonus", false ) != -1 )
        {
            if ( StrContains( szRun, "2" ) != -1 )
            {
                g_iRunId_Bonus2 = id;
            }
            else
            {
                g_iRunId_Bonus1 = id;
            }
        }
    }
    
    if ( g_iRunId_Main == -1 && FindRunById( MAIN_RUN_ID ) )
    {
        g_iRunId_Main = MAIN_RUN_ID;
    }
}

stock void InvalidateClientRun( int client )
{
    if ( g_iRunState[client] != STATE_NONE )
    {
        if ( g_iRunState[client] == STATE_RUNNING )
        {
            Influx_PrintToChat( _, client, "Your timer has been disabled!" );
        }
        
        g_iRunState[client] = STATE_NONE;
    }
}

stock void ResetClient( int client )
{
    g_flJoinTime[client] = GetEngineTime();
    
    
    g_flNextMenuTime[client] = 0.0;
    
    
    g_flLastRecPrintTime[client] = 0.0;
    g_flNextWepSpdPrintTime[client] = 0.0;
    g_flLastValidWepSpd[client] = 0.0;
    
    
    g_flNextStyleGroundCheck[client] = 0.0;
    
    g_flFinishBest[client] = INVALID_RUN_TIME;
    
    
    g_cache_flMaxSpeed[client] = g_ConVar_DefMaxWeaponSpeed.FloatValue;
    
    g_iClientId[client] = 0;
    g_bCachedTimes[client] = false;
    
    g_iRunState[client] = STATE_NONE;
    g_iRunStartTick[client] = -1;
    
    g_iRunId[client] = -1;
    g_iModeId[client] = MODE_INVALID;
    g_iStyleId[client] = STYLE_INVALID;
    
    
    g_flFinishedTime[client] = INVALID_RUN_TIME;
}

stock void InitClientModeStyle( int client )
{
    int defmode = g_iDefMode;
    int defstyle = g_iDefStyle;
    
    if ( FindModeById( defmode ) == -1 )
    {
        defmode = GetModeIdByIndex( 0 );
        LogError( INF_CON_PRE..."Invalid default mode %i!", g_iDefMode );
    }
    
    if ( FindStyleById( defstyle ) == -1 )
    {
        defstyle = g_hStyles.Get( 0, STYLE_ID );
        LogError( INF_CON_PRE..."Invalid default style %i!", g_iDefStyle );
    }
    
    SetClientMode( client, defmode, false, false, true );
    SetClientStyle( client, defstyle, false, false );
}

stock void ResetAllClientTimes( int client )
{
    // Messy but works.
    decl mode, style;
    
    for ( int run = 0; run < g_hRuns.Length; run++ )
    {
        for ( mode = 0; mode < MAX_MODES; mode++ )
        {
            for ( style = 0; style < MAX_STYLES; style++ )
            {
                SetClientRunTime( run, client, mode, style, INVALID_RUN_TIME );
            }
        }
    }
}

stock void SearchType( const char[] sz, Search_t &type, int &value )
{
    Call_StartForward( g_hForward_OnSearchType );
    Call_PushString( sz );
    Call_PushCellRef( view_as<int>( type ) );
    Call_PushCellRef( value );
    Call_Finish();
}