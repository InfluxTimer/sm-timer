#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <regex>

#include <influx/core>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>
#include <msharedutil/misc>


#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <influx/recordsmenu>
#include <influx/help>
#include <influx/pause>
#include <influx/practise>
#include <influx/zones_freestyle>
#include <influx/hud_draw>
//#include <influx/colorchat>


// Uncomment this to test out SQL performance on map start.
//#define DISABLE_CREATE_SQL_TABLES			bool _bUseless = true; if ( _bUseless ) return;


//#define DEBUG
//#define DEBUG_TIMING
//#define DEBUG_TIMER
//#define DEBUG_WEPSPD
//#define DEBUG_PARSESEARCH
//#define DEBUG_COLORCHAT
//#define DEBUG_DB
//#define DEBUG_DB_VER
//#define DEBUG_DB_CBRECS
//#define DEBUG_DB_MAPID
//#define DEBUG_DB_RUN
//#define TEST_REGEX
//#define TEST_MODESTYLES
//#define TEST_DB_NAMECHANGE


#define GAME_CONFIG_FILE      "influx.games"

#define INF_UPDATE_CMD          "sm_updateinfluxdb"

// Don't change these, change the cvars instead.
#define DEF_CHATPREFIX              "{GREY}[{PINK}"...INF_NAME..."{GREY}]"
#define DEF_CHATCLR                 "{WHITE}"

#define DEF_VALIDMAPNAMES           "^(surf\\_|bhop\\_|kz\\_)\\w+"



#define INVALID_MAXSPEED        -1.0





// PLAYER STUFF
int g_iRunId[INF_MAXPLAYERS] = { -1, ... };
int g_iStyleId[INF_MAXPLAYERS] = { STYLE_INVALID, ... };
int g_iModeId[INF_MAXPLAYERS] = { MODE_INVALID, ... };

float g_flRunTime[INF_MAXPLAYERS];
RunState_t g_iRunState[INF_MAXPLAYERS] = { STATE_NONE, ... };

int g_iWantedStyleId[INF_MAXPLAYERS] = { STYLE_INVALID, ... };
int g_iWantedModeId[INF_MAXPLAYERS] = { MODE_INVALID, ... };


float g_flFinishedTime[INF_MAXPLAYERS] = { INVALID_RUN_TIME, ... };


// PLAYER DATABASE RELATED STUFF
int g_iClientId[INF_MAXPLAYERS];
bool g_bCachedTimes[INF_MAXPLAYERS];

// PLAYER CACHE
float g_cache_flPBTime[INF_MAXPLAYERS] = { INVALID_RUN_TIME, ... };
float g_cache_flBestTime[INF_MAXPLAYERS] = { INVALID_RUN_TIME, ... };
char g_cache_szBestName[INF_MAXPLAYERS][MAX_BEST_NAME];
char g_cache_szRunName[INF_MAXPLAYERS][MAX_RUN_NAME];
float g_cache_flMaxSpeed[INF_MAXPLAYERS] = { INVALID_MAXSPEED, ... };
//char g_cache_szModeName[INF_MAXPLAYERS][MAX_NAME_LENGTH];
//char g_cache_szStyleName[INF_MAXPLAYERS][MAX_NAME_LENGTH];


// PLAYER MISC.
float g_flNextStyleGroundCheck[INF_MAXPLAYERS];

float g_flFinishBest[INF_MAXPLAYERS] = { INVALID_RUN_TIME, ... };

float g_flJoinTime[INF_MAXPLAYERS];

float g_flNextMenuTime[INF_MAXPLAYERS];


// ANTI-SPAM
float g_flNextWepSpdPrintTime[INF_MAXPLAYERS];
float g_flLastValidWepSpd[INF_MAXPLAYERS];


// CHAT COLOR
char g_szChatPrefix[128];
char g_szChatClr[64];

ArrayList g_hChatClrs;
int g_nChatClrLen;



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

Handle g_hForward_OnRecordRemoved;
Handle g_hForward_OnClientIdRetrieved;
Handle g_hForward_OnMapIdRetrieved;
Handle g_hForward_OnPostRecordsLoad;

Handle g_hForward_OnRunCreated;
Handle g_hForward_OnRunDeleted;
Handle g_hForward_OnRunLoad;
Handle g_hForward_OnRunSave;

Handle g_hForward_OnClientStatusChanged;

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
Handle g_hForward_OnSearchTelePos;


// FUNCS
Handle g_hFunc_GetPlayerMaxSpeed;


// CONVARS
ConVar g_ConVar_AirAccelerate;
#if !defined PRE_ORANGEBOX
ConVar g_ConVar_EnableBunnyhopping;
#endif

ConVar g_ConVar_ChatPrefix;
ConVar g_ConVar_ChatClr;
ConVar g_ConVar_ChatMainClr1;
ConVar g_ConVar_SaveRunsOnMapEnd;
ConVar g_ConVar_PreferDb;
ConVar g_ConVar_SuppressMaxSpdWarning;
ConVar g_ConVar_SuppressMaxSpdMsg;
ConVar g_ConVar_DefMode;
ConVar g_ConVar_DefStyle;
ConVar g_ConVar_DefMaxWeaponSpeed;

ConVar g_ConVar_LadderFreestyle;

ConVar g_ConVar_TeleToStart;
ConVar g_ConVar_TeleOnStyleChange;

ConVar g_ConVar_ModeActAsStyle;

ConVar g_ConVar_ValidMapNames;
Regex g_Regex_ValidMapNames;


// LIBRARIES
bool g_bLib_AdminMenu;
bool g_bLib_Pause;
bool g_bLib_Practise;
bool g_bLib_Zones_Fs;
bool g_bLib_Hud_Draw;


// MAP DATA
char g_szCurrentMap[128];
int g_iCurMapId;
bool g_bNewMapId;
bool g_bRunsLoaded = false;
bool g_bBestTimesCached = false;

// Cached id.
int g_iDefMode;
int g_iDefStyle;

//bool g_bHasLoadedAllData;


// MISC
bool g_bIsCSGO;
bool g_bLate;
int g_iCurDBVersion;


// ADMIN MENU
TopMenu g_hTopMenu;
TopMenuObject g_InfluxAdminMenu = INVALID_TOPMENUOBJECT;


#include "influx_core/modestyle_ovrs.sp"

#include "influx_core/cmds.sp"
#include "influx_core/colorchat.sp"
#include "influx_core/db_sql_queries.sp"
#include "influx_core/db.sp"
#include "influx_core/db_cb.sp"
#include "influx_core/events.sp"
#include "influx_core/file.sp"
#include "influx_core/menus.sp"
#include "influx_core/menus_hndlrs.sp"
#include "influx_core/menus_admin.sp"
#include "influx_core/menus_hndlrs_admin.sp"
#include "influx_core/natives.sp"
#include "influx_core/natives_chat.sp"
#include "influx_core/runcmd.sp"


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
    EngineVersion eng = GetEngineVersion();
    
    if ( eng != Engine_CSS && eng != Engine_CSGO )
    {
        char szFolder[32];
        GetGameFolderName( szFolder, sizeof( szFolder ) );
        
        FormatEx( szError, error_len, INF_NAME..." does not support %s!", szFolder );
        
        return APLRes_Failure;
    }
    
    
    g_bLate = late;
    
    
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_CORE );
    
    
    // NATIVES
    CreateNative( "Influx_GetDB", Native_GetDB );
    CreateNative( "Influx_IsMySQL", Native_IsMySQL );
    
    CreateNative( "Influx_GetPostRunLoadForward", Native_GetPostRunLoadForward );
    
    
    // In natives_chat.sp
    CreateNative( "Influx_PrintToChat", Native_PrintToChat );
    CreateNative( "Influx_PrintToChatAll", Native_PrintToChatAll );
    CreateNative( "Influx_PrintToChatEx", Native_PrintToChatEx );
    CreateNative( "Influx_RemoveChatColors", Native_RemoveChatColors );
    CreateNative( "Influx_FormatChatColors", Native_FormatChatColors );
    
    
    CreateNative( "Influx_StartTimer", Native_StartTimer );
    CreateNative( "Influx_FinishTimer", Native_FinishTimer );
    CreateNative( "Influx_ResetTimer", Native_ResetTimer );
    
    CreateNative( "Influx_TeleportToStart", Native_TeleportToStart );
    
    
    
    CreateNative( "Influx_IsClientCached", Native_IsClientCached );
    CreateNative( "Influx_GetClientId", Native_GetClientId );
    CreateNative( "Influx_GetCurrentMapId", Native_GetCurrentMapId );
    
    CreateNative( "Influx_HasLoadedRuns", Native_HasLoadedRuns );
    CreateNative( "Influx_HasLoadedBestTimes", Native_HasLoadedBestTimes );
    
    
    CreateNative( "Influx_InvalidateClientRun", Native_InvalidateClientRun );
    
    CreateNative( "Influx_GetClientRunId", Native_GetClientRunId );
    CreateNative( "Influx_SetClientRun", Native_SetClientRun );
    
    CreateNative( "Influx_GetClientMode", Native_GetClientMode );
    CreateNative( "Influx_SetClientMode", Native_SetClientMode );
    
    CreateNative( "Influx_GetClientStyle", Native_GetClientStyle );
    CreateNative( "Influx_SetClientStyle", Native_SetClientStyle );
    
    
    
    CreateNative( "Influx_GetClientState", Native_GetClientState );
    CreateNative( "Influx_SetClientState", Native_SetClientState );
    
    
    CreateNative( "Influx_GetClientTime", Native_GetClientTime );
    CreateNative( "Influx_SetClientTime", Native_SetClientTime );
    CreateNative( "Influx_GetClientFinishedTime", Native_GetClientFinishedTime );
    CreateNative( "Influx_GetClientFinishedBestTime", Native_GetClientFinishedBestTime );
    
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
    CreateNative( "Influx_GetModeSafeName", Native_GetModeSafeName );
    CreateNative( "Influx_GetStyleName", Native_GetStyleName );
    CreateNative( "Influx_GetStyleShortName", Native_GetStyleShortName );
    CreateNative( "Influx_GetStyleSafeName", Native_GetStyleSafeName );
    
    CreateNative( "Influx_ShouldModeDisplay", Native_ShouldModeDisplay );
    CreateNative( "Influx_ShouldStyleDisplay", Native_ShouldStyleDisplay );
    
    
    
    CreateNative( "Influx_AddRun", Native_AddRun );
    CreateNative( "Influx_AddStyle", Native_AddStyle );
    CreateNative( "Influx_AddMode", Native_AddMode );
    
    CreateNative( "Influx_AddResultFlag", Native_AddResultFlag );
    
    CreateNative( "Influx_RemoveMode", Native_RemoveMode );
    CreateNative( "Influx_RemoveStyle", Native_RemoveStyle );
    
    CreateNative( "Influx_SearchType", Native_SearchType );
    CreateNative( "Influx_SearchTelePos", Native_SearchTelePos );
    
    CreateNative( "Influx_IsValidMapName", Native_IsValidMapName );
    
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_bIsCSGO = ( GetEngineVersion() == Engine_CSGO );
    
    
    g_hRuns = new ArrayList( RUN_SIZE );
    g_hModes = new ArrayList( MODE_SIZE );
    g_hStyles = new ArrayList( STYLE_SIZE );
    g_hRunResFlags = new ArrayList( RUNRES_SIZE );
    g_hChatClrs = new ArrayList( CLR_SIZE );
    
    g_hModeOvers = new ArrayList( MOVR_SIZE );
    g_hStyleOvers = new ArrayList( SOVR_SIZE );
    
    
    ReadGameConfig();
    
    ReadModeOverrides();
    ReadStyleOverrides();
    
    
    // CONVAR CHANGES
    if ( (g_ConVar_AirAccelerate = FindConVar( "sv_airaccelerate" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_airaccelerate!" );
    }
    
#if !defined PRE_ORANGEBOX
    if ( (g_ConVar_EnableBunnyhopping = FindConVar( "sv_enablebunnyhopping" )) == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't find handle for sv_enablebunnyhopping!" );
    }
#endif

    
    // FORWARDS
    g_hForward_OnTimerStart = CreateGlobalForward( "Influx_OnTimerStart", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_Cell );
    g_hForward_OnTimerStartPost = CreateGlobalForward( "Influx_OnTimerStartPost", ET_Ignore, Param_Cell, Param_Cell );
    
    g_hForward_OnTimerFinish = CreateGlobalForward( "Influx_OnTimerFinish", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell );
    g_hForward_OnTimerFinishPost = CreateGlobalForward( "Influx_OnTimerFinishPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell );
    
    g_hForward_OnTimerResetPost = CreateGlobalForward( "Influx_OnTimerResetPost", ET_Ignore, Param_Cell );
    
    
    
    
    g_hForward_OnRecordRemoved = CreateGlobalForward( "Influx_OnRecordRemoved", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell );
    
    g_hForward_OnClientIdRetrieved = CreateGlobalForward( "Influx_OnClientIdRetrieved", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    
    g_hForward_OnMapIdRetrieved = CreateGlobalForward( "Influx_OnMapIdRetrieved", ET_Ignore, Param_Cell, Param_Cell );
    
    g_hForward_OnPostRecordsLoad = CreateGlobalForward( "Influx_OnPostRecordsLoad", ET_Ignore );
    
    
    g_hForward_OnPreRunLoad = CreateGlobalForward( "Influx_OnPreRunLoad", ET_Ignore );
    g_hForward_OnPostRunLoad = CreateGlobalForward( "Influx_OnPostRunLoad", ET_Ignore );
    
    g_hForward_OnRunCreated = CreateGlobalForward( "Influx_OnRunCreated", ET_Ignore, Param_Cell );
    g_hForward_OnRunDeleted = CreateGlobalForward( "Influx_OnRunDeleted", ET_Ignore, Param_Cell );
    g_hForward_OnRunLoad = CreateGlobalForward( "Influx_OnRunLoad", ET_Ignore, Param_Cell, Param_Cell );
    g_hForward_OnRunSave = CreateGlobalForward( "Influx_OnRunSave", ET_Ignore, Param_Cell, Param_Cell );
    
    
    
    g_hForward_OnClientStatusChanged = CreateGlobalForward( "Influx_OnClientStatusChanged", ET_Ignore, Param_Cell );
    
    
    g_hForward_OnClientModeChange = CreateGlobalForward( "Influx_OnClientModeChange", ET_Event, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnClientModeChangePost = CreateGlobalForward( "Influx_OnClientModeChangePost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    
    g_hForward_OnClientStyleChange = CreateGlobalForward( "Influx_OnClientStyleChange", ET_Event, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnClientStyleChangePost = CreateGlobalForward( "Influx_OnClientStyleChangePost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    
    
    g_hForward_OnRequestModes = CreateGlobalForward( "Influx_OnRequestModes", ET_Ignore );
    g_hForward_OnRequestStyles = CreateGlobalForward( "Influx_OnRequestStyles", ET_Ignore );
    g_hForward_OnRequestResultFlags = CreateGlobalForward( "Influx_OnRequestResultFlags", ET_Ignore );
    
    
    g_hForward_OnCheckClientStyle = CreateGlobalForward( "Influx_OnCheckClientStyle", ET_Hook, Param_Cell, Param_Cell, Param_Array );
    
    g_hForward_OnSearchType = CreateGlobalForward( "Influx_OnSearchType", ET_Hook, Param_String, Param_CellByRef, Param_CellByRef );
    
    g_hForward_OnSearchTelePos = CreateGlobalForward( "Influx_OnSearchTelePos", ET_Hook, Param_Array, Param_CellByRef, Param_Cell, Param_Cell );
    
    
    
    // PHRASES
    LoadTranslations( INFLUX_PHRASES );
    
    
    
    // CONVARS
    CreateConVar( "influx_version", INF_VERSION, "Version of Influx. Do not change.", FCVAR_NOTIFY );
    
    g_ConVar_ChatPrefix = CreateConVar( "influx_chatprefix", DEF_CHATPREFIX, "Prefix for chat messages.", FCVAR_NOTIFY );
    g_ConVar_ChatPrefix.AddChangeHook( E_ConVarChanged_Prefix );
    
    g_ConVar_ChatClr = CreateConVar( "influx_chatcolor", DEF_CHATCLR, "Default chat color.", FCVAR_NOTIFY );
    g_ConVar_ChatClr.AddChangeHook( E_ConVarChanged_ChatClr );
    
    g_ConVar_ChatMainClr1 = CreateConVar( "influx_chatmainclr1", "{SKYBLUE}", "Override main color. This is used to highlight text. Eg Noclip: \"ON\"", FCVAR_NOTIFY );
    g_ConVar_ChatMainClr1.AddChangeHook( E_ConVarChanged_ChatMainClr1 );
    
    
    g_ConVar_SaveRunsOnMapEnd = CreateConVar( "influx_core_saveruns", "1", "Do we automatically save runs on map end?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_PreferDb = CreateConVar( "influx_core_preferdb", "1", "Is database preferred method of saving runs?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    g_ConVar_SuppressMaxSpdMsg = CreateConVar( "influx_core_suppressmaxwepspdmsg", "0", "Suppress player max weapon speed message? (one printed to client)", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_SuppressMaxSpdWarning = CreateConVar( "influx_core_suppressmaxwepspdwarning", "0", "Suppress player max weapon speed warning? (one printed to console)", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    g_ConVar_DefMode = CreateConVar( "influx_defaultmode", "auto", "Default mode. Recommended to not change.", FCVAR_NOTIFY );
    g_ConVar_DefMode.AddChangeHook( E_ConVarChanged_DefMode );
    g_iDefMode = MODE_AUTO;
    
    g_ConVar_DefStyle = CreateConVar( "influx_defaultstyle", "normal", "Default style. Recommended to not change.", FCVAR_NOTIFY );
    g_ConVar_DefStyle.AddChangeHook( E_ConVarChanged_DefStyle );
    g_iDefStyle = STYLE_NORMAL;
    
    
    g_ConVar_DefMaxWeaponSpeed = CreateConVar( "influx_default_maxwepspd", "250", "Default maximum weapon speed. Max weapon speed is controlled by modes. 0 = Disable check", FCVAR_NOTIFY, true, 0.0 );
    g_ConVar_LadderFreestyle = CreateConVar( "influx_ladderfreestyle", "1", "Whether to allow freestyle on ladders.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    g_ConVar_TeleToStart = CreateConVar( "influx_teletostartonspawn", "1", "0 = Never teleport when spawning, 1 = Only teleport if no spawnpoints are found, 2 = Always teleport to start.", FCVAR_NOTIFY, true, 0.0, true, 2.0 );
    g_ConVar_TeleOnStyleChange = CreateConVar( "influx_teleonstylechange", "1", "Do we teleport player to start on style/mode change?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    g_ConVar_ModeActAsStyle = CreateConVar( "influx_modeactstyle", "0", "If true, changing your mode/style will set your mode/style to default, effectively making all modes into a style. (working like other timers where you can't have 400vel hsw, etc.)", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    g_ConVar_ValidMapNames = CreateConVar( "influx_core_validmapnames", DEF_VALIDMAPNAMES, "Regular expression of all valid map names. Players can only search for these maps." );
    g_ConVar_ValidMapNames.AddChangeHook( E_ConVarChanged_ValidMapNames );
    SetMapNameRegex();
    
    
    AutoExecConfig( true, "core", "influx" );
    
    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_REMOVERECORDS, Cmd_Empty, ADMFLAG_ROOT );
    RegAdminCmd( INF_PRIVCOM_RUNSETTINGS, Cmd_Empty, ADMFLAG_ROOT );
    
    
    // MENUS
    RegConsoleCmd( "sm_influx", Cmd_Credits );
    //RegConsoleCmd( "sm_credits", Cmd_Credits );
    
    
    RegConsoleCmd( "sm_mode", Cmd_Change_Mode );
    RegConsoleCmd( "sm_modes", Cmd_Change_Mode );
    
    RegConsoleCmd( "sm_style", Cmd_Change_Style );
    RegConsoleCmd( "sm_styles", Cmd_Change_Style );
    
    
    // ADMIN MENUS
    RegConsoleCmd( "sm_manageruns", Cmd_Admin_RunMenu );
    RegConsoleCmd( "sm_runmenu", Cmd_Admin_RunMenu );
    
    RegConsoleCmd( "sm_runsettings", Cmd_Admin_RunSettings );
    
    RegConsoleCmd( "sm_deleterecords", Cmd_Admin_DeleteRecords );
    
    RegConsoleCmd( "sm_deleterunsmenu", Cmd_Admin_DeleteRunMenu );
    RegConsoleCmd( "sm_deleterunmenu", Cmd_Admin_DeleteRunMenu );
    
    
    // ADMIN CMDS
    RegAdminCmd( INF_UPDATE_CMD, Cmd_UpdateDB, ADMFLAG_ROOT );
    
    RegAdminCmd( "sm_reloadoverrides", Cmd_ReloadOverrides, ADMFLAG_ROOT );
    
    
    RegConsoleCmd( "sm_saveruns", Cmd_Admin_SaveRuns );
    
    RegConsoleCmd( "sm_setrunname", Cmd_Admin_SetRunName );
    
    RegConsoleCmd( "sm_settelepos", Cmd_Admin_SetTelePos );
    
    RegConsoleCmd( "sm_deleteruns", Cmd_Admin_DeleteRun );
    RegConsoleCmd( "sm_deleterun", Cmd_Admin_DeleteRun );
    
    
#if defined TEST_MODESTYLES
    RegAdminCmd( "sm_printstyles", Cmd_TestPrintStyles, ADMFLAG_ROOT );
#endif

    
#if defined TEST_COLORCHAT
    RegAdminCmd( "sm_testchat", Cmd_TestColor, ADMFLAG_ROOT );
    
    RegAdminCmd( "sm_testchatremove", Cmd_TestColorRemove, ADMFLAG_ROOT );
#endif

#if defined TEST_REGEX
    RegAdminCmd( "sm_testmapname", Cmd_TestMapName, ADMFLAG_ROOT );
#endif

#if defined TEST_DB_NAMECHANGE
    RegAdminCmd( "sm_changenamedb", Cmd_Change_Name_Db, ADMFLAG_ROOT );
#endif
    
    
    
    // EVENTS
    HookEvent( "player_spawn", E_PlayerSpawn );
    
    
    // LIBRARIES
    g_bLib_AdminMenu = LibraryExists( "adminmenu" );
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
    g_bLib_Practise = LibraryExists( INFLUX_LIB_PRACTISE );
    g_bLib_Zones_Fs = LibraryExists( INFLUX_LIB_ZONES_FS );
    g_bLib_Hud_Draw = LibraryExists( INFLUX_LIB_HUD_DRAW );
    
    
    DB_Init();
    
    
    if ( g_bLate )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) )
            {
                ResetClient( i );
            }
        }
        
        // Register admin menu late.
        TopMenu topmenu;
        if ( g_bLib_AdminMenu && (topmenu = GetAdminTopMenu()) != null )
        {
            OnAdminMenuCreated( topmenu );
            
            OnAdminMenuReady( topmenu );
        }
    }
}

public void OnPluginEnd()
{
    UpdateCvars( true );
    
    if ( g_bLib_AdminMenu && g_hTopMenu != null && g_InfluxAdminMenu != INVALID_TOPMENUOBJECT )
    {
        g_hTopMenu.Remove( g_InfluxAdminMenu );
    }
    
    g_hTopMenu = null;
    g_InfluxAdminMenu = INVALID_TOPMENUOBJECT;
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, "adminmenu" ) ) g_bLib_AdminMenu = true;
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = true;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = true;
    if ( StrEqual( lib, INFLUX_LIB_ZONES_FS ) ) g_bLib_Zones_Fs = true;
    if ( StrEqual( lib, INFLUX_LIB_HUD_DRAW ) ) g_bLib_Hud_Draw = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, "adminmenu" ) ) g_bLib_AdminMenu = false;
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = false;
    if ( StrEqual( lib, INFLUX_LIB_ZONES_FS ) ) g_bLib_Zones_Fs = false;
    if ( StrEqual( lib, INFLUX_LIB_HUD_DRAW ) ) g_bLib_Hud_Draw = false;
}

public void OnAllPluginsLoaded()
{
    //g_hModes.Clear();
    //g_hStyles.Clear();
    g_hRunResFlags.Clear();
    
    
    AddResultFlag( "Don't save record", RES_TIME_DONTSAVE );
    
    
    // Request modes and styles.
    if ( g_bLate )
    {
        Call_StartForward( g_hForward_OnRequestModes );
        Call_Finish();
        
        Call_StartForward( g_hForward_OnRequestStyles );
        Call_Finish();
    }
    
    Call_StartForward( g_hForward_OnRequestResultFlags );
    Call_Finish();
    
    /*
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
    */
}

public void OnAdminMenuCreated( Handle hTopMenu )
{
    TopMenu topmenu = TopMenu.FromHandle( hTopMenu );
    
    if ( topmenu == g_hTopMenu )
        return;
    
    
    g_InfluxAdminMenu = topmenu.FindCategory( INFLUX_ADMMENU );
    
    if ( g_InfluxAdminMenu == INVALID_TOPMENUOBJECT )
    {
        g_InfluxAdminMenu = topmenu.AddCategory( INFLUX_ADMMENU, Hndlr_AdminMenu );
    }
}

public void Hndlr_AdminMenu(TopMenu topmenu, 
                            TopMenuAction action,
                            TopMenuObject object_id,
                            int param,
                            char[] buffer,
                            int maxlength)
{
    if ( object_id != g_InfluxAdminMenu )
        return;
    
    
    if ( action == TopMenuAction_DisplayTitle )
    {
        strcopy( buffer, maxlength, "Influx Commands" );
    }
    else if ( action == TopMenuAction_DisplayOption )
    {
        strcopy( buffer, maxlength, "Influx Commands" );
    }
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
    g_InfluxAdminMenu = res;
    
    
    g_hTopMenu.AddItem( "sm_manageruns", AdmMenu_ManageRuns, res, INF_PRIVCOM_RUNSETTINGS, 0 );
    g_hTopMenu.AddItem( "sm_runsettings", AdmMenu_RunSettings, res, INF_PRIVCOM_RUNSETTINGS, 0 );
}

public void AdmMenu_ManageRuns( TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength )
{
    if ( action == TopMenuAction_DisplayOption )
    {
        strcopy( buffer, maxlength, "Manage Runs" );
    }
    else if ( action == TopMenuAction_SelectOption )
    {
        FakeClientCommand( client, "sm_manageruns" );
    }
}

public void AdmMenu_RunSettings( TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength )
{
    if ( action == TopMenuAction_DisplayOption )
    {
        strcopy( buffer, maxlength, "Run Settings" );
    }
    else if ( action == TopMenuAction_SelectOption )
    {
        FakeClientCommand( client, "sm_runsettings" );
    }
}

public void Influx_OnClientStatusChanged( int client )
{
    UpdateClientCached( client );
}

public void Influx_OnRecordRemoved( int issuer, int uid, int mapid, int runid, int mode, int style )
{
    if ( mapid != Influx_GetCurrentMapId() ) return;
    
    
    int irun = FindRunById( runid );
    if ( irun == -1 ) return;
    
    
    bool bDeletedBest = false;
    
    
    for ( int client = 1; client <= MaxClients; client++ )
    {
        if ( !IsClientInGame( client ) ) continue
        
        if ( IsFakeClient( client ) ) continue
        
        
        if ( uid == -1 || g_iClientId[client] == uid )
        {
            bool res = RemoveClientTimes( client, irun, mode, style, true );
            
            if ( res )
            {
                bDeletedBest = true;
            }
        }
        
        break;
    }
    
    
    if ( bDeletedBest )
    {
        DB_InitRecords( runid, mode, style );
    }
}

public void Influx_OnMapIdRetrieved( int mapid, bool bNew )
{
    LoadRuns();
    
    
    if ( g_bLate )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) )
            {
                OnClientPutInServer( i );
                
                if ( IsClientAuthorized( i ) )
                {
                    OnClientPostAdminCheck( i );
                }
            }
        }
    }
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "manageruns", "Run menu.", true );
    Influx_AddHelpCommand( "saveruns", "Saves all current runs.", true );
    
    Influx_AddHelpCommand( "setrunname <name>", "Set current run's name.", true );
    //Influx_AddHelpCommand( "settelepos", "Set current run's tele position and yaw.", true );
    Influx_AddHelpCommand( "deleterun <id>", "Delete a run.", true );
    Influx_AddHelpCommand( "deleterunmenu", "Run deletion menu.", true );
    Influx_AddHelpCommand( "deleterecords", "Delete a specific run's records.", true );
    
    
    Influx_AddHelpCommand( "wr/records <args>", "Display records.\nValid arguments are maps, players, styles, modes, etc." );
    Influx_AddHelpCommand( "myrecords", "Display your records." );
    Influx_AddHelpCommand( "wrmaps", "Display map selector for records." );
    
    Influx_AddHelpCommand( "restart/r", "Go back to start or respawn." );
    
    Influx_AddHelpCommand( "run", "Display run selector menu." );
    Influx_AddHelpCommand( "style", "Display style selector menu." );
    Influx_AddHelpCommand( "mode", "Display mode selector menu." );
}

public void Influx_OnPrintRecordInfo( int client, Handle dbres, ArrayList itemlist, Menu menu, int uid, int mapid, int runid, int mode, int style )
{
    // Add item to delete this record.
    if ( CanUserRemoveRecords( client ) )
    {
        // Note: first character will determine the action.
        decl String:szInfo[64];
        FormatEx( szInfo, sizeof( szInfo ), "d%i_%i_%i_%i_%i", uid, mapid, runid, mode, style );
        
        menu.AddItem( szInfo, "Delete this record" );
    }
}

public Action Influx_OnRecordInfoButtonPressed( int client, const char[] szInfo )
{
    if ( szInfo[0] == 'd' ) // We want to delete
    {
        if ( !CanUserRemoveRecords( client ) ) return Plugin_Stop;
        
        
        // Display confirmation menu.
        Menu menu = new Menu( Hndlr_Delete_Confirm );
        menu.SetTitle( "Sure you want to delete this record?\n " );
        
        menu.AddItem( szInfo[1], "Yes" );
        menu.AddItem( "", "No" );
        
        menu.ExitButton = false;
        
        menu.Display( client, MENU_TIME_FOREVER );
        
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public void OnMapStart()
{
    g_hRuns.Clear();
    
    
    if ( g_hFunc_GetPlayerMaxSpeed == null && !g_ConVar_SuppressMaxSpdWarning.BoolValue )
    {
        Inf_Warning( 3, "Weapon speed check cannot be made! Players are free to cheat with weapon speeds." );
    }
    
    
    GetCurrentMapSafe( g_szCurrentMap, sizeof( g_szCurrentMap ) );
    
    g_bNewMapId = false;
    g_bRunsLoaded = false;
    g_bBestTimesCached = false;
    g_iCurMapId = 0;
    
    DB_InitMap();
    
    
    //LoadRuns();
    
    
    InitColors();
}

public void OnMapEnd()
{
    if ( g_ConVar_SaveRunsOnMapEnd.BoolValue )
    {
        SaveRuns();
    }
}

public void OnClientPutInServer( int client )
{
    ResetClient( client );
    
    
    if ( !IsFakeClient( client ) )
    {
        InitClientModeStyle( client );
        
        // Send status update to other plugins.
        g_iRunId[client] = -1; // We didn't have a run before this.
        SetClientRun( client, GetDefaultRun(), false, false );
        
        
        ResetAllClientTimes( client );
        
        
        UpdateClientCached( client );
        
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

public void OnGameFrame()
{
    float frametime = GetGameFrameTime();

    for ( int client = 1; client <= MaxClients; client++ )
    {
        if ( !IsClientInGame( client ) )
            continue;

        
        if ( g_iRunState[client] != STATE_RUNNING )
            continue;

        if ( g_bLib_Pause && Influx_IsClientPaused( client ) )
            continue;

#if defined DEBUG_TIMING
        PrintToServer( INF_DEBUG_PRE..."Incrementing player time on frame %i", GetGameTickCount() );
#endif

        // TODO: Account for tas.
        g_flRunTime[client] += frametime;
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
    float cvarval = g_ConVar_DefMaxWeaponSpeed.FloatValue;
    
    float modemaxspd = ( g_cache_flMaxSpeed[client] == INVALID_MAXSPEED ) ? cvarval : g_cache_flMaxSpeed[client];
    
    if ( cvarval > 0.0 && maxspd != 0.0 && maxspd > modemaxspd )
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
        
        if (!g_ConVar_SuppressMaxSpdMsg.BoolValue
        &&  (GetEngineTime() - g_flLastValidWepSpd[client]) > 0.2 // We have the invalid weapon out for more than this.
        &&  g_flNextWepSpdPrintTime[client] < GetEngineTime() )
        {
            Influx_PrintToChat( _, client, "%T", "INF_INVALIDWEAPONSPD", client, RoundFloat( modemaxspd ) );
            
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
    int def_target = GetDefaultRun();
    
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
    
    
    if ( !TeleClientToSpawn( client ) )
    {
        LogError( INF_CON_PRE..."Couldn't teleport client %i to spawn as a fallback!", client );
    }
    
    return false;
}

stock bool TeleClientToStart( int client, int runid )
{
    int irun = FindRunById( runid );
    
    if ( irun == -1 ) return false;
    
    
    // Only reset our run state if we're actually running.
    // Prevents timer not working when leaving start zone if player got teleported to start while their state was start already.
    if ( g_iRunState[client] == STATE_RUNNING )
    {
        g_iRunState[client] = STATE_NONE;
    }
    
    float pos[3];
    GetRunTelePos( irun, pos );
    
    float ang[3];
    ang[1] = GetRunTeleYaw( irun );
    
    
    // Make sure our teleport location is ok.
    // If not, ask other plugins to tell it to us and save it.
    bool ok = true;

    if ( !Inf_IsValidTelePos( pos ) )
    {
        ok = ResetRunTelePosByIndex( irun, pos, ang[1] );
    }
    else if ( !Inf_IsValidTeleAngle( ang[1] ) )
    {
        // Tele yaw is not critical.
        ResetRunTeleYawByIndex( irun, ang[1] );
    }


    if ( !ok )
    {
        return false;
    }
    
    
    TeleportEntity( client, pos, ang, ORIGIN_VECTOR );
    
    return true;
}

stock bool TeleClientToSpawn( int client )
{
    int ent;
    char szSpawn[32];
    char szFallbackSpawn[32];
    
    strcopy( szSpawn, sizeof( szSpawn ), ( GetClientTeam( client ) == CS_TEAM_CT ) ? "info_player_counterterrorist" : "info_player_terrorist" );
    strcopy( szFallbackSpawn, sizeof( szFallbackSpawn ), ( GetClientTeam( client ) != CS_TEAM_CT ) ? "info_player_counterterrorist" : "info_player_terrorist" );
    
    ent = FindEntityByClassname( -1, szSpawn );
    if ( ent == -1 )
    {
        ent = FindEntityByClassname( -1, szFallbackSpawn );
    }
    
    if ( ent != -1 )
    {
        float pos[3];
        GetEntityOrigin( ent, pos );
        
        float ang[3];
        GetEntPropVector( ent, Prop_Data, "m_angRotation", ang );
        
        
        TeleportEntity( client, pos, ang, ORIGIN_VECTOR );
        
        return true;
    }
    
    return false;
}

stock bool IsValidTeleLocation( const float pos[3] )
{
    float end[3];
    end = pos;
    
    if ( TR_PointOutsideWorld( end ) ) return false;
    
    

    
    end[2] += 72.0;
    
    TR_TraceHullFilter( pos, end, PLYHULL_MINS, PLYHULL_MAXS_NOZ, MASK_PLAYERSOLID, TraceFilter_AnythingButThoseFilthyPlayersEww );
    
    
    return ( !TR_DidHit() );
}

public bool TraceFilter_AnythingButThoseFilthyPlayersEww( int ent, int mask )
{
    return ( ent == 0 || ent > MaxClients );
}

stock void GetRunTelePos( int irun, float out[3] )
{
    out[0] = g_hRuns.Get( irun, RUN_TELEPOS );
    out[1] = g_hRuns.Get( irun, RUN_TELEPOS + 1 );
    out[2] = g_hRuns.Get( irun, RUN_TELEPOS + 2 );
}

stock bool SetRunTelePos( int irun, const float pos[3], bool bForce = false )
{
    if ( irun == -1 ) return false;
    
    
    if ( !IsValidTeleLocation( pos ) )
    {
        if ( bForce )
        {
            char szRunName[MAX_RUN_NAME];
            GetRunNameByIndex( irun, szRunName, sizeof( szRunName ) );
            LogError( INF_CON_PRE..."Run %s (%i) teleport destination is not valid! (%.1f, %.1f, %.1f)",
                szRunName,
                GetRunIdByIndex( irun ),
                pos[0], pos[1], pos[2] );
        }
        else
        {
            return false;
        }
    }
    
    for ( int i = 0; i < 3; i++ )
    {
        g_hRuns.Set( irun, pos[i], RUN_TELEPOS + i );
    }
    
    return true;
}

stock float GetRunTeleYaw( int irun )
{
    return view_as<float>( g_hRuns.Get( irun, RUN_TELEYAW ) );
}

stock void SetRunTeleYaw( int irun, float yaw )
{
    if ( irun == -1 ) return;
    
    
    g_hRuns.Set( irun, yaw, RUN_TELEYAW );
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

stock bool AddMode( int id, const char[] szName, const char[] szShortName, const char[] szSafeName, float flMaxSpeed = 0.0 )
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
    strcopy( view_as<char>( data[MODE_SAFENAME] ), MAX_SAFENAME, szSafeName );
    
    data[MODE_ID] = id;
    data[MODE_DISPLAY] = 1;
    
    data[MODE_ADMFLAGS] = 0;
    
    
    float spd = flMaxSpeed;
    
    /*if ( spd <= 0.0 )
    {
        spd = g_ConVar_DefMaxWeaponSpeed.FloatValue;
    }*/
    
    data[MODE_MAXSPEED] = view_as<int>( spd );
    
    index = g_hModes.PushArray( data );
    
    
    UpdateCvars();
    
    
    UpdateModeOverrides();
    
    return true;
}

stock bool RemoveMode( int id )
{
    int index = FindModeById( id );
    
    if ( index != -1 )
    {
        g_hModes.Erase( index );
        
        
        // Reset clients with this mode.
        int def_id = GetDefaultMode();
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( !IsClientInGame( i ) ) continue;
            
            if ( g_iModeId[i] != id ) continue;
            
            
            if ( !SetClientMode( i, def_id ) )
            {
                ResetClientMode( i );
            }
        }
        
        
        UpdateCvars();
        
        return true;
    }
    
    return false;
}

stock bool AddStyle( int id, const char[] szName, const char[] szShortName, const char[] szSafeName, bool bDisplay = true )
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
    strcopy( view_as<char>( data[STYLE_SAFENAME] ), MAX_SAFENAME, szSafeName );
    
    data[STYLE_ID] = id;
    data[STYLE_DISPLAY] = bDisplay;
    
    data[STYLE_ADMFLAGS] = 0;
    
    
    index = g_hStyles.PushArray( data );
    

    UpdateStyleOverrides( index );
    
    return true;
}

stock bool RemoveStyle( int id )
{
    int index = FindStyleById( id );
    
    if ( index != -1 )
    {
        g_hStyles.Erase( index );
        
        
        // Reset clients with this style.
        int def_id = GetDefaultStyle();
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( !IsClientInGame( i ) ) continue;
            
            if ( g_iStyleId[i] != id ) continue;
            
            
            if ( !SetClientStyle( i, def_id ) )
            {
                g_iStyleId[i] = -1;
            }
        }
        
        return true;
    }
    
    return false;
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

stock void GetModeSafeName( int id, char[] out, int len )
{
    GetModeSafeNameByIndex( FindModeById( id ), out, len );
}

stock void GetModeSafeNameByIndex( int index, char[] out, int len )
{
    if ( index != -1 )
    {
        decl name[MAX_SAFENAME_CELL];
        
        for ( int i = 0; i < MAX_SAFENAME_CELL; i++ )
        {
            name[i] = g_hModes.Get( index, MODE_SAFENAME + i );
        }
        
        strcopy( out, len, view_as<char>( name ) );
    }
    else
    {
        strcopy( out, len, "" );
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

stock void GetStyleSafeName( int id, char[] out, int len )
{
    GetStyleSafeNameByIndex( FindStyleById( id ), out, len );
}

stock void GetStyleSafeNameByIndex( int index, char[] out, int len )
{
    if ( index != -1 )
    {
        decl name[MAX_SAFENAME_CELL];
        
        for ( int i = 0; i < MAX_SAFENAME_CELL; i++ )
        {
            name[i] = g_hStyles.Get( index, STYLE_SAFENAME + i );
        }
        
        strcopy( out, len, view_as<char>( name ) );
    }
    else
    {
        strcopy( out, len, "" );
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
            
            Format( list, sizeof( list ), "%s%s{MAINCLR1}%s{CHATCLR}",
                list,
                ( list[0] != '\0' ) ? ", " : "",
                mode );
        }
    }
    
    // No modes were added to the list!
    if ( list[0] == '\0' )
    {
        strcopy( list, sizeof( list ), "{MAINCLR1}None{CHATCLR}!" );
    }
    
    Influx_PrintToChat( _, client, "%T", "INF_VALIDMODES", client, list );
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
            Influx_PrintToChat( _, client, "%T", "INF_RUNISNOW", client, sz );
        }
    }
    
    
    if ( runid != lastrun )
    {
        SendStatusChanged( client );
    }
    
    return true;
}

stock bool SetClientMode( int client, int mode, bool bTele = true, bool bPrintToChat = true, bool bNewIfNotValidRun = false )
{
    int imode = FindModeById( mode );
    if ( imode == -1 ) return false;
    
    if ( bTele && !ChangeTele( client ) )
    {
        g_iWantedModeId[client] = mode;
        return false;
    }
    
    
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
    
    
    if ( !Inf_CanClientUseAdminFlags( client, GetModeFlagsByIndex( imode ) ) )
    {
        if ( bPrintToChat )
        {
            Influx_PrintToChat( _, client, "%T", "INF_NOACCESSTO", client, "INF_WORD_MODE" );
        }
        
        return false;
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
            Influx_PrintToChat( _, client, "%T", "INF_WENTWRONGCHANGING", client, "INF_WORD_MODE" );
        }
        
        // Fallback to last mode.
        mode = lastmode;
        imode = FindModeById( mode );
    }
    
    
    if ( bPrintToChat && lastmode != mode )
    {
        char sz[MAX_MODE_NAME];
        GetModeNameByIndex( imode, sz, sizeof( sz ) );
        
        Influx_PrintToChat( _, client, "%T", "INF_MODEORSTYLEISNOW", client, "INF_WORD_MODE", sz );
    }
    
    
    g_iModeId[client] = mode;
    
    
    
    g_cache_flMaxSpeed[client] = GetModeMaxspeedByIndex( imode );
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Set client %i max speed to %.1f", client, g_cache_flMaxSpeed[client] );
#endif
    
    Call_StartForward( g_hForward_OnClientModeChangePost );
    Call_PushCell( client );
    Call_PushCell( mode );
    Call_PushCell( lastmode );
    Call_Finish();
    
    
    if ( mode != lastmode )
    {
        SendStatusChanged( client );
    }
    
    
    if ( g_ConVar_ModeActAsStyle.BoolValue && mode != GetDefaultMode() && g_iStyleId[client] != GetDefaultStyle() )
    {
        SetClientStyle( client, GetDefaultStyle(), false, false );
    }
    
    
    return true;
}

stock bool SetClientStyle( int client, int style, bool bTele = true, bool bPrintToChat = true )
{
    int istyle = FindStyleById( style );
    if ( istyle == -1 ) return false;
    
    if ( bTele && !ChangeTele( client ) )
    {
        g_iWantedStyleId[client] = style;
        return false;
    }
    
    
    if ( !Inf_CanClientUseAdminFlags( client, GetStyleFlagsByIndex( istyle ) ) )
    {
        if ( bPrintToChat )
        {
            Influx_PrintToChat( _, client, "%T", "INF_NOACCESSTO", client, "INF_WORD_STYLE" );
        }
        
        return false;
    }
    
    
    int laststyle = g_iStyleId[client];
    
    
    Action res;
    
    Call_StartForward( g_hForward_OnClientStyleChange );
    Call_PushCell( client );
    Call_PushCell( style );
    Call_PushCell( laststyle );
    Call_Finish( res );
    
    
    if ( res != Plugin_Continue )
    {
        Influx_PrintToChat( _, client, "%T", "INF_WENTWRONGCHANGING", client, "INF_WORD_STYLE" );
        
        // Fallback to last style.
        style = laststyle;
        istyle = FindStyleById( style );
    }
    
    
    if ( bPrintToChat && laststyle != style )
    {
        char sz[MAX_STYLE_NAME];
        GetStyleNameByIndex( istyle, sz, sizeof( sz ) );
        
        Influx_PrintToChat( _, client, "%T", "INF_MODEORSTYLEISNOW", client, "INF_WORD_STYLE", sz );
    }
    
    g_iStyleId[client] = style;
    
    
    Call_StartForward( g_hForward_OnClientStyleChangePost );
    Call_PushCell( client );
    Call_PushCell( style );
    Call_PushCell( laststyle );
    Call_Finish();
    
    
    if ( style != laststyle )
    {
        SendStatusChanged( client );
    }
    
    
    if ( g_ConVar_ModeActAsStyle.BoolValue && style != GetDefaultStyle() && g_iModeId[client] != GetDefaultMode() )
    {
        SetClientMode( client, GetDefaultMode(), false, false, true );
    }
    
    
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
            
            Influx_PrintToChat( _, client, "%T", "INF_MODEORSTYLENOTALLOWEDINRUN", client, "INF_WORD_MODE", mode, run );
        }
        
        return false;
    }
    
    return true;
}

// When changing mode/style
stock bool ChangeTele( int client )
{
    // We don't need to teleport a dead player.
    if ( !IsPlayerAlive( client ) )
        return true;
    
    
    // We don't want teleporting on change.
    if ( g_ConVar_TeleOnStyleChange.IntValue == 0 )
    {
        // If we're in start, it's all good.
        if ( g_iRunState[client] == STATE_START )
        {
            return true;
        }
        
        
        Influx_PrintToChat( _, client, "%T", "INF_WAITTILLSPAWN", client );
        return false;
    }
    
    
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

stock bool ChangeToWantedStyles( int client )
{
    // Player wanted to change their mode/style, nows the chance to do it SAFELY.
    bool ret = false;
    
    
    if ( g_iWantedModeId[client] != MODE_INVALID )
    {
        ret = SetClientMode( client, g_iWantedModeId[client], false );
        
        g_iWantedModeId[client] = MODE_INVALID;
    }
    
    if ( g_iWantedStyleId[client] != STYLE_INVALID )
    {
        ret = SetClientStyle( client, g_iWantedStyleId[client], false ) || ret;
        
        g_iWantedStyleId[client] = STYLE_INVALID;
    }
    
    return ret;
}

stock bool CanUserRemoveRecords( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_REMOVERECORDS, ADMFLAG_ROOT );
}

stock bool CanUserModifyRun( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_RUNSETTINGS, ADMFLAG_ROOT );
}

// TODO: Make sure this is called every time times change.
stock void UpdateAllClientsCached( int runid, int mode = MODE_INVALID, int style = STYLE_INVALID )
{
    int irun = FindRunById( runid );
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if (IsClientInGame( i )
        &&  !IsFakeClient( i )
        &&  g_iRunId[i] == runid
        &&  (mode == MODE_INVALID || g_iModeId[i] == mode)
        &&  (style == STYLE_INVALID || g_iStyleId[i] == style))
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
        
        
        return ( spd > 0.0 ) ? spd : INVALID_MAXSPEED;
    }
    else
    {
        return INVALID_MAXSPEED;
    }
}

stock bool IsProperlyCached( int client = 0 )
{
    // Check if we are cached properly.
    
    if ( !client ) return g_bBestTimesCached;
    
    
    return ( g_bBestTimesCached && g_bCachedTimes[client] );
}

stock void InvalidateClientRun( int client )
{
    if ( g_iRunState[client] != STATE_NONE )
    {
        if ( g_iRunState[client] == STATE_RUNNING )
        {
            Influx_PrintToChat( _, client, "%T", "INF_TIMERDISABLED", client );
        }
        
        g_iRunState[client] = STATE_NONE;
    }
}

stock void ResetClient( int client )
{
    g_flJoinTime[client] = GetEngineTime();
    
    
    g_flNextMenuTime[client] = 0.0;
    
    
    g_flNextWepSpdPrintTime[client] = 0.0;
    g_flLastValidWepSpd[client] = 0.0;
    
    
    g_flNextStyleGroundCheck[client] = 0.0;
    
    g_flFinishBest[client] = INVALID_RUN_TIME;
    
    
    g_iClientId[client] = 0;
    g_bCachedTimes[client] = false;
    
    g_iRunState[client] = STATE_NONE;
    g_flRunTime[client] = 0.0;
    
    
    g_iRunId[client] = -1;
    
    ResetClientMode( client );
    
    g_iStyleId[client] = STYLE_INVALID;
    
    
    g_iWantedModeId[client] = MODE_INVALID;
    g_iWantedStyleId[client] = STYLE_INVALID;
    
    
    g_flFinishedTime[client] = INVALID_RUN_TIME;
}

stock void InitClientModeStyle( int client )
{
    int defmode = GetDefaultMode();
    int defstyle = GetDefaultStyle();
    
    if ( FindModeById( defmode ) == -1 )
    {
        defmode = ( g_hModes.Length ) ? GetModeIdByIndex( 0 ) : MODE_INVALID;
        
        if ( g_hModes.Length )
        {
            LogError( INF_CON_PRE..."Invalid default mode %i!", g_iDefMode );
        }
    }
    
    if ( FindStyleById( defstyle ) == -1 )
    {
        defstyle = ( g_hStyles.Length ) ? GetStyleIdByIndex( 0 ) : STYLE_INVALID;
        
        if ( g_hStyles.Length )
        {
            LogError( INF_CON_PRE..."Invalid default style %i!", g_iDefStyle );
        }
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

stock void ResetAllRunTimes( int runid )
{
    int irun = FindRunById( runid );
    if ( irun == -1 ) return;
    
    
    decl mode, style;
    decl i;
    
    int[] clients = new int[MaxClients];
    int nClients = 0;
    
    for ( i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) ) continue;
        
        if ( IsFakeClient( i ) ) continue;
        
        
        clients[nClients++] = i;
    }
    
    for ( mode = 0; mode < MAX_MODES; mode++ )
    {
        for ( style = 0; style < MAX_STYLES; style++ )
        {
            SetRunBestTime( irun, mode, style, INVALID_RUN_TIME );
            
            
            for ( i = 0; i < nClients; i++ )
            {
                SetClientRunTime( irun, clients[i], mode, style, INVALID_RUN_TIME );
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

stock bool SearchTelePos( float pos[3], float &yaw, int runid, int telepostype )
{
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnSearchTelePos );
    Call_PushArrayEx( pos, sizeof( pos ), SM_PARAM_COPYBACK );
    Call_PushCellRef( view_as<int>( yaw ) );
    Call_PushCell( runid );
    Call_PushCell( telepostype );
    Call_Finish( res );
    
    return res != Plugin_Continue;
}

stock int GetDefaultRun()
{
    if ( FindRunById( MAIN_RUN_ID ) != -1 )
    {
        return MAIN_RUN_ID;
    }
    
    if ( g_hRuns.Length > 0 ) return GetRunIdByIndex( 0 );
    
    return -1;
}

stock int GetDefaultMode()
{
    if ( FindModeById( g_iDefMode ) != -1 )
    {
        return g_iDefMode;
    }
    
    if ( g_hModes.Length > 0 ) return GetModeIdByIndex( 0 );
    
    return MODE_INVALID;
}

stock int GetDefaultStyle()
{
    if ( FindStyleById( g_iDefStyle ) != -1 )
    {
        return g_iDefStyle;
    }
    
    if ( g_hStyles.Length > 0 ) return GetStyleIdByIndex( 0 );
    
    return STYLE_INVALID;
}

stock void UpdateCvars( bool bForceReset = false )
{
    // If we remove all modes, aa and enablebunnyhopping should be reset back to normal.
    if ( bForceReset || !g_hModes || g_hModes.Length == 0 )
    {
        g_ConVar_AirAccelerate.Flags |= (FCVAR_NOTIFY | FCVAR_REPLICATED);
        
#if !defined PRE_ORANGEBOX
        g_ConVar_EnableBunnyhopping.Flags |= (FCVAR_NOTIFY | FCVAR_REPLICATED);
#endif
    }
    // Let modes change these cvars.
    else
    {
        g_ConVar_AirAccelerate.Flags &= ~(FCVAR_NOTIFY | FCVAR_REPLICATED);
        
#if !defined PRE_ORANGEBOX
        g_ConVar_EnableBunnyhopping.Flags &= ~(FCVAR_NOTIFY | FCVAR_REPLICATED);
#endif
    }
}

// When invalidating player's mode, we need to update our cached max speed back to the default max speed.
stock void ResetClientMode( int client )
{
    g_iModeId[client] = MODE_INVALID;
    
    g_cache_flMaxSpeed[client] = INVALID_MAXSPEED;
}

stock void TeleportOnSpawn( int client )
{
    // We're paused, don't teleport to start.
    if ( g_bLib_Pause && Influx_IsClientPaused( client ) )
    {
        return;
    }
    
    
    bool teleport = false;

    //
    // IMPORTANT
    //
    // Theory:
    // CS:GO is a piece of shit and will refuse to move the player to a spawnpoint
    // if the initial spawnpoint count isn't enough.
    // So we have to check if they were moved to a valid spot or not.
    //
    float pos[3];
    GetEntityOrigin( client, pos );

    if ( !IsValidTeleLocation( pos ) )
    {
        teleport = true;

        LogMessage( INF_CON_PRE... "Player spawned in solid (%.1f %.1f %.1f)! Moving them to start...", pos[0], pos[1], pos[2] );    
    }
    // Only if no spawn found.
    else if ( g_ConVar_TeleToStart.IntValue == 1 )
    {
        char szSpawn[32];
        
        if ( GetClientTeam( client ) == CS_TEAM_CT ) strcopy( szSpawn, sizeof( szSpawn ), "info_player_counterterrorist" );
        else strcopy( szSpawn, sizeof( szSpawn ), "info_player_terrorist" );
        
        
        teleport = ( FindEntityByClassname( -1, szSpawn ) == -1 );
    }
    // Always
    else if ( g_ConVar_TeleToStart.IntValue == 2 )
    {
        teleport = true;
    }
    
    
    if ( teleport )
    {
        TeleClientToStart_Safe( client, g_iRunId[client] );
    }
}

stock void SetClientId( int client, int id, bool bNew = false, bool bForward = true )
{
    g_iClientId[client] = id;
    
    if ( bForward )
    {
        Call_StartForward( g_hForward_OnClientIdRetrieved );
        Call_PushCell( client );
        Call_PushCell( id );
        Call_PushCell( bNew );
        Call_Finish();
    }
}

stock void SendStatusChanged( int client )
{
    Call_StartForward( g_hForward_OnClientStatusChanged );
    Call_PushCell( client );
    Call_Finish();
}

// Return true if deleted some best times.
stock bool RemoveClientTimes( int client, int irun, int mode, int style, bool bPrintToChat = true )
{
    decl String:szRun[MAX_RUN_NAME];
    GetRunNameByIndex( irun, szRun, sizeof( szRun ) );
    
    
    bool deleted_best = false;
    
    int found = 0;
    
    
    int uid = Influx_GetClientId( client );
    
    
    // Delete client's all times.
    if ( mode == MODE_INVALID && style == STYLE_INVALID )
    {
        decl j, k;
        
        for ( j = 0; j < MAX_MODES; j++ )
            for ( k = 0; k < MAX_STYLES; k++ )
            {
                if ( GetClientRunTime( irun, client, j, k ) != INVALID_RUN_TIME ) ++found;
                
                
                SetClientRunTime( irun, client, j, k, INVALID_RUN_TIME );
                
                if ( GetRunBestTimeId( irun, j, k ) == uid )
                {
                    SetRunBestTime( irun, j, k, INVALID_RUN_TIME );
                    
                    deleted_best = true;
                }
            }
    }
    else if ( VALID_MODE( mode ) && style == STYLE_INVALID )
    {
        decl j;
        
        
        for ( j = 0; j < MAX_STYLES; j++ )
        {
            if ( GetClientRunTime( irun, client, mode, j ) != INVALID_RUN_TIME ) ++found;
            
            
            SetClientRunTime( irun, client, mode, j, INVALID_RUN_TIME );
            
            
            if ( GetRunBestTimeId( irun, mode, j ) == uid )
            {
                SetRunBestTime( irun, mode, j, INVALID_RUN_TIME );
                
                deleted_best = true;
            }
        }
    }
    else if ( mode == MODE_INVALID && VALID_STYLE( style ) )
    {
        decl j;
        
        for ( j = 0; j < MAX_MODES; j++ )
        {
            if ( GetClientRunTime( irun, client, j, style ) != INVALID_RUN_TIME ) ++found;
            
            
            SetClientRunTime( irun, client, j, style, INVALID_RUN_TIME );
            
            
            if ( GetRunBestTimeId( irun, j, style ) == uid )
            {
                SetRunBestTime( irun, j, style, INVALID_RUN_TIME );
                
                deleted_best = true;
            }
        }
    }
    else if ( VALID_MODE( mode ) && VALID_STYLE( style ) )
    {
        float time = GetClientRunTime( irun, client, mode, style );
        
        SetClientRunTime( irun, client, mode, style, INVALID_RUN_TIME );
        
        
        if ( GetRunBestTimeId( irun, mode, style ) == uid )
        {
            SetRunBestTime( irun, mode, style, INVALID_RUN_TIME );
            
            deleted_best = true;
        }
        
        
        if ( time != INVALID_RUN_TIME )
        {
            char szTime[16];
            Inf_FormatSeconds( time, szTime, sizeof( szTime ) );
            
            
            Influx_PrintToChat( _, client, "%T", "INF_RUNS_DELETED", client, szRun, szTime );
        }
    }
    
    UpdateClientCachedByIndex( client, irun );
    
    
    if ( found )
    {
        Influx_PrintToChat( _, client, "%T", "INF_RUN_RUNS_DELETED", client, szRun );
    }
    
    
    return deleted_best;
}

stock void SetMapNameRegex()
{
    char szRegex[256];
    char szError[256];
    
    
    delete g_Regex_ValidMapNames;
    
    
    g_ConVar_ValidMapNames.GetString( szRegex, sizeof( szRegex ) );
    
    g_Regex_ValidMapNames = new Regex( szRegex, _, szError, sizeof( szError ) );
    
    
    if ( g_Regex_ValidMapNames == null )
    {
        LogError( INF_CON_PRE..."Couldn't compile valid map name regex! Error: '%s'", szError );
    }
}

stock bool IsValidMapName( const char[] szMap )
{
    if ( g_Regex_ValidMapNames == null )
    {
        return false;
    }
    
    return ( g_Regex_ValidMapNames.Match( szMap ) > 0 ) ? true : false;
}

stock void SetModeNameByIndex( int index, const char[] szName )
{
    if ( index == -1 ) return;
    
    
    decl name[MAX_MODE_NAME_CELL];
    
    strcopy( view_as<char>( name ), MAX_MODE_NAME, szName );
    
    for ( int i = 0; i < MAX_MODE_NAME_CELL; i++ )
    {
        g_hModes.Set( index, name[i], MODE_NAME + i );
    }
}

stock void SetModeShortNameByIndex( int index, const char[] szName )
{
    if ( index == -1 ) return;
    
    
    decl name[MAX_MODE_SHORTNAME_CELL];
    
    strcopy( view_as<char>( name ), MAX_MODE_SHORTNAME, szName );
    
    for ( int i = 0; i < MAX_MODE_SHORTNAME_CELL; i++ )
    {
        g_hModes.Set( index, name[i], MODE_SHORTNAME + i );
    }
}

stock void SetStyleNameByIndex( int index, const char[] szName )
{
    if ( index == -1 ) return;
    
    
    decl name[MAX_STYLE_NAME_CELL];
    
    strcopy( view_as<char>( name ), MAX_STYLE_NAME, szName );
    
    for ( int i = 0; i < MAX_STYLE_NAME_CELL; i++ )
    {
        g_hStyles.Set( index, name[i], STYLE_NAME + i );
    }
}

stock void SetStyleShortNameByIndex( int index, const char[] szName )
{
    if ( index == -1 ) return;
    
    
    decl name[MAX_STYLE_SHORTNAME_CELL];
    
    strcopy( view_as<char>( name ), MAX_STYLE_SHORTNAME, szName );
    
    for ( int i = 0; i < MAX_STYLE_SHORTNAME_CELL; i++ )
    {
        g_hStyles.Set( index, name[i], STYLE_SHORTNAME + i );
    }
}

stock void UpdateModeOverrides( int index = -1 )
{
    if ( index != -1 )
    {
        SetModeOverrides( index );
    }
    else
    {
        int len = g_hModes.Length;
        for ( int i = 0; i < len; i++ )
        {
            SetModeOverrides( i );
        }
    }
    
    // Always sort last.
    SortModesArray();
}

stock void UpdateStyleOverrides( int index = -1 )
{
    if ( index != -1 )
    {
        SetStyleOverrides( index );
    }
    else
    {
        int len = g_hStyles.Length;
        for ( int i = 0; i < len; i++ )
        {
            SetStyleOverrides( i );
        }
    }
    
    // Always sort last.
    SortStylesArray();
}

stock int GetModeFlags( int id )
{
    return GetModeFlagsByIndex( FindModeById( id ) );
}

stock int GetModeFlagsByIndex( int index )
{
    return ( index != -1 ) ? g_hModes.Get( index, MODE_ADMFLAGS ) : 0;
}

stock int GetStyleFlags( int id )
{
    return GetStyleFlagsByIndex( FindStyleById( id ) );
}

stock int GetStyleFlagsByIndex( int index )
{
    return ( index != -1 ) ? g_hStyles.Get( index, STYLE_ADMFLAGS ) : 0;
}

stock int AddRun(   int runid,
                    const char[] szInRun = "",
                    const float telepos[3],
                    float teleyaw,
                    int resflags,
                    int modeflags,
                    bool bDoForward = true,
                    bool bPrint = false )
{
    if ( g_hRuns == null ) return -1;
    
    
    // If they didn't request a specific id, find one that doesn't exist.
    if ( runid == -1 )
    {
        int highest = -1;
        
        int len = g_hRuns.Length;
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hRuns.Get( i, RUN_ID ) > highest )
            {
                highest = g_hRuns.Get( i, RUN_ID );
            }
        }
        
        if ( highest == -1 )
        {
            runid = MAIN_RUN_ID;
        }
        else
        {
            runid = highest + 1;
        }
    }
    
    
    if ( runid < 1 ) return -1;
    
    // That run already exists!
    if ( FindRunById( runid ) != -1 )
    {
        char szOldRunName[MAX_RUN_NAME];
        GetRunName( runid, szOldRunName, sizeof( szOldRunName ) );
        LogError( INF_CON_PRE..."Attempted to add an already existing run! (%s (%i))", szOldRunName, runid );
        return -1;
    }
    
    if ( runid > MAX_RUNS )
    {
        LogError( INF_CON_PRE..."Attempted to add more than %i runs! (%i)", MAX_RUNS, runid );
        return -1;
    }
    
    
    char szRun[MAX_RUN_NAME];
    
    
    int data[RUN_SIZE];
    
    
    if ( strlen( szInRun ) )
    {
        strcopy( szRun, sizeof( szRun ), szInRun );
    }
    else
    {
        // Determine our run name if they didn't give it to us.
        if ( runid == MAIN_RUN_ID )
        {
            strcopy( szRun, sizeof( szRun ), "Main" );
        }
        else
        {
            int len = g_hRuns.Length;
            FormatEx( szRun, sizeof( szRun ), "Bonus #%i", len );
        }
    }
    
    
    data[RUN_ID] = runid;
    strcopy( view_as<char>( data[RUN_NAME] ), MAX_RUN_NAME, szRun );
    
    
    data[RUN_RESFLAGS] = resflags;
    data[RUN_MODEFLAGS] = modeflags;
    
    int irun = g_hRuns.PushArray( data );
    
    
    SetRunTelePos( irun, telepos, true );
    SetRunTeleYaw( irun, teleyaw != INVALID_TELEANG ? Inf_SnapTo( teleyaw ) : teleyaw );
    
    
    if ( bDoForward )
    {
        Call_StartForward( g_hForward_OnRunCreated );
        Call_PushCell( runid );
        Call_Finish();
    }
    
    if ( bPrint )
        Influx_PrintToChatAll( _, 0, "%T", "INF_RUN_CREATED", LANG_SERVER, szRun );
    
    
    return runid;
}

stock void RemoveRunById( int runid, int client = 0 )
{
    int irun = FindRunById( runid );
    
    if ( irun == -1 )
    {
        Inf_ReplyToClient( client, "%T", "INF_RUNIDNOTEXIST", client, runid );
        return;
    }
    
    
    char szRun[MAX_RUN_NAME];
    GetRunNameByIndex( irun, szRun, sizeof( szRun ) );
    
    TeleportClientsOutOfRun( runid );
    
    g_hRuns.Erase( irun );

    
    Call_StartForward( g_hForward_OnRunDeleted );
    Call_PushCell( runid );
    Call_Finish();
    
    
    // HACK: Just force a database removal here, otherwise the runs will persistent forever.
    DB_RemoveRun( runid );
    
    
    Inf_ReplyToClient( client, "%T", "INF_RUN_DELETED", client, szRun );
}

stock void TeleportClientsOutOfRun( int runid )
{
    int reset_run = GetDefaultRun();
    
    if ( reset_run == runid )
    {
        
    }
    
    for ( int client = 1; client <= MaxClients; client++ )
    {
        if ( IsClientInGame( client ) && g_iRunId[client] == runid )
        {
            if ( reset_run != -1 )
            {
                TeleClientToStart_Safe( client, reset_run );
            }
            else
            {
                InvalidateClientRun( client );
            }
        }
    }
}

stock bool ResetRunTelePosByIndex( int irun, float pos[3], float &yaw )
{
    int runid = g_hRuns.Get( irun, RUN_ID );

    LogMessage( INF_CON_PRE..."Resetting run's %i teleport location.", runid );


    if ( SearchTelePos(
            pos,
            yaw,
            runid,
            TELEPOSTYPE_START ) )
    {
        SetRunTelePos( irun, pos, true );
        SetRunTeleYaw( irun, yaw );

        return true;
    }
    else
    {
        LogError( INF_CON_PRE..."Failed to find a suitable teleport location for run %i on reset!", runid );

        return false;
    }
}

stock bool ResetRunTeleYawByIndex( int irun, float &yaw )
{
    int runid = g_hRuns.Get( irun, RUN_ID );

    LogMessage( INF_CON_PRE..."Resetting run's %i teleport angle.", runid );


    float pos[3];
    if ( SearchTelePos(
            pos,
            yaw,
            runid,
            TELEPOSTYPE_START ) )
    {
        SetRunTeleYaw( irun, yaw );

        return true;
    }
    else
    {
        LogError( INF_CON_PRE..."Failed to find a suitable teleport angle for run %i on reset!", runid );

        return false;
    }
}

stock void SendRunLoadPre()
{
    Call_StartForward( g_hForward_OnPreRunLoad );
    Call_Finish();
}

stock void SendRunLoadPost()
{
    Call_StartForward( g_hForward_OnPostRunLoad );
    Call_Finish();
}

stock void SendRunLoad( int runid, KeyValues kv )
{
    Call_StartForward( g_hForward_OnRunLoad );
    Call_PushCell( runid );
    Call_PushCell( view_as<int>( kv ) );
    Call_Finish();
}

stock void SendMapIdRetrieved()
{
    Call_StartForward( g_hForward_OnMapIdRetrieved );
    Call_PushCell( g_iCurMapId );
    Call_PushCell( g_bNewMapId );
    Call_Finish();
}

stock bool LoadRunFromKv( KeyValues kv )
{
    char szRun[MAX_RUN_NAME];
    
    float telepos[3];
    int runid;
    
    
    runid = kv.GetNum( "id", -1 );
    if ( !VALID_RUN( runid ) )
    {
        LogError( INF_CON_PRE..."Found invalid run id %i! (0-%i)", runid, MAX_RUNS );
        return false;
    }
    
    if ( FindRunById( runid ) != -1 )
    {
        LogError( INF_CON_PRE..."Found duplicate run id %i!", runid );
        return false;
    }


    kv.GetString( "name", szRun, sizeof( szRun ), "" );
    if ( szRun[0] == 0 )
    {
        // Fallback to section name.
        if ( !kv.GetSectionName( szRun, sizeof( szRun ) ) )
        {
            LogError( INF_CON_PRE..."Couldn't read run name from kv!" );
            return false;
        }
    }
    
    
    SendRunLoad( runid, kv );
    
    
    kv.GetVector( "telepos", telepos, INVALID_TELEPOS );
    
    AddRun( runid,
            szRun,
            telepos,
            kv.GetFloat( "teleyaw", INVALID_TELEANG ),
            kv.GetNum( "resflags", 0 ),
            kv.GetNum( "modeflags", 0 ),
            true,
            false );

    return true;
}

stock void BuildRunKvs( ArrayList kvs )
{
    char szRun[MAX_RUN_NAME];
    char szKeyValueName[64];
    decl data[RUN_SIZE];
    float vec[3];
    
    
    for ( int i = 0; i < g_hRuns.Length; i++ )
    {
        g_hRuns.GetArray( i, data );
        

        int runid = data[RUN_ID];

        FormatEx( szKeyValueName, sizeof( szKeyValueName ), "run%i", runid );
        KeyValues kv = new KeyValues( szKeyValueName );
        
        
        kv.SetNum( "id", runid );
        
        
        kv.SetNum( "resflags", data[RUN_RESFLAGS] );
        kv.SetNum( "modeflags", data[RUN_MODEFLAGS] );
        
        
        CopyArray( data[RUN_TELEPOS], vec, 3 );
        // Make sure we're not saving invalid teleport locations
        if ( Inf_IsValidTelePos( vec ) )
        {
            kv.SetVector( "telepos", vec );
        }
        else
        {
            LogError( INF_CON_PRE..."Run of id %i had invalid teleport location. No location will be saved.", data[RUN_ID] );
        }

        float teleyaw = view_as<float>( data[RUN_TELEYAW] );
        if ( Inf_IsValidTeleAngle( teleyaw ) )
        {
            kv.SetFloat( "teleyaw", view_as<float>( data[RUN_TELEYAW] ) );
        }
        else
        {
            LogError( INF_CON_PRE..."Run of id %i had invalid teleport yaw. No yaw will be saved.", data[RUN_ID] );
        }

        strcopy( szRun, sizeof( szRun ), view_as<char>( data[RUN_NAME] ) );
        kv.SetString( "name", szRun );
        

        // Ask other plugins if they want to save some data.
        Call_StartForward( g_hForward_OnRunSave );
        Call_PushCell( runid );
        Call_PushCell( view_as<int>( kv ) );
        Call_Finish();
        
        
        decl arr[2];
        arr[0] = view_as<int>( kv );
        arr[1] = runid;
        
        kvs.PushArray( arr );
    }
}

stock void LoadRuns( bool bForceType = false, bool bUseDb = false, bool bFallback = false )
{
    bool usedb = (bForceType && bUseDb) || (!bForceType && WantsRunsToDb());
    
    PrintToServer( INF_CON_PRE..."Loading runs from %s %s...",
        usedb ? "database" : "file",
        bFallback ? "as a fallback" : "first time" );
    
    if ( usedb )
    {
        DB_LoadRuns();
    }
    else
    {
        SendRunLoadPre();
        ReadRunFile();
        SendRunLoadPost();

        g_bRunsLoaded = true;
    }
}

stock int SaveRuns( bool bForceType = false, bool bUseDb = false )
{
    int num = 0;
    
    ArrayList kvs = new ArrayList( 2 );
    
    BuildRunKvs( kvs );
    
    bool usedb = (bForceType && bUseDb) || (!bForceType && WantsRunsToDb());
    
    
    if ( usedb )
    {
        num = DB_SaveRuns( kvs );
    }
    else
    {
        num = WriteRunFile( kvs );
    }
    
    
    // Free the kvs
    for ( int i = 0; i < kvs.Length; i++ )
        delete view_as<KeyValues>( kvs.Get( i, 0 ) );
    
    delete kvs;
    
    return num;
}

stock bool WantsRunsToDb()
{
    return g_ConVar_PreferDb.BoolValue;
}
