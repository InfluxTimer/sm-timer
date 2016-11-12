#if defined _influx_core_included
    #endinput
#endif
#define _influx_core_included


#include <convars>
#include <dbi>
#include <sdkhooks>
#include <sdktools>

#include <influx/stocks_core>
#include <influx/stocks_chat>


#define INFLUX_LIB_CORE         "influx_core"


#define INFLUX_PHRASES          "influx.phrases"


#define INFLUX_RUNDIR           "influxruns"



#define INVALID_RUN_TIME            0.0


// Since we cannot do this stuff runtime, we have to declare max limit.
// Increase these if needed. AND IF YOU DO, REMEMBER TO RECOMPILE EVERY PLUGIN SINCE ALOT OF THEM USE THESE LIMITS.
// NOTE: These cannot be more than 31 if you want to maintain compatibility!
// However, if you're fine with mode-specific runs, and freestyle and block zones breaking, go ahead.
#define MAX_RUNS                    31
#define MAX_MODES                   6
#define MAX_STYLES                  12

#define VALID_RUN(%0)               ( %0 > 0 && %0 < MAX_RUNS )
#define VALID_MODE(%0)              ( %0 > MODE_INVALID && %0 < MAX_MODES )
#define VALID_STYLE(%0)             ( %0 > STYLE_INVALID && %0 < MAX_STYLES )

enum
{
    STYLE_INVALID = -1,
    
    STYLE_NORMAL,
    STYLE_SW,
    STYLE_W,
    STYLE_AD,
    STYLE_HSW,
    STYLE_RHSW
};

enum
{
    MODE_INVALID = -1,
    
    MODE_SCROLL,
    MODE_AUTO,
    MODE_VELCAP,
    MODE_STOCKCAP
};



// RUN ID 1 SHOULD ALWAYS BE THE MAIN!!
#define MAIN_RUN_ID                 1


#define MAX_RUN_NAME                32
#define MAX_RUN_NAME_CELL           MAX_RUN_NAME / 4


#define MAX_BEST_NAME               16
#define MAX_BEST_NAME_CELL          MAX_BEST_NAME / 4

#define MAX_MODE_NAME               24
#define MAX_MODE_NAME_CELL          MAX_MODE_NAME / 4

#define MAX_MODE_SHORTNAME          12
#define MAX_MODE_SHORTNAME_CELL     MAX_MODE_SHORTNAME / 4


#define MAX_STYLE_NAME              24
#define MAX_STYLE_NAME_CELL         MAX_STYLE_NAME / 4

#define MAX_STYLE_SHORTNAME         12
#define MAX_STYLE_SHORTNAME_CELL    MAX_STYLE_SHORTNAME / 4


//
// Array offsets
//
#define OFFSET_MODESTYLE(%0,%1)             ( %0 * MAX_STYLES + %1 )


#define OFFSET_MODESTYLESIZE(%0,%1,%2)         ( (%0 * MAX_STYLES * %2) + (%1 * %2) )


#define OFFSET_MODESTYLECLIENT(%0,%1,%2)       ( (%0 * MAX_STYLES * INF_MAXPLAYERS) + (%1 * INF_MAXPLAYERS) + %2 )



enum
{
    // Strings need to be put first so we can use GetString on them.
    RUN_NAME[MAX_RUN_NAME_CELL] = 0,
    
    RUN_ID,
    
    
    RUN_RESFLAGS,
    
    RUN_MODEFLAGS, // Allow admins to disable some modes.
    
    
    RUN_TELEPOS[3],
    RUN_TELEYAW,
    
    
    // Multidimensional arrays don't work. :(
    
    RUN_BESTTIMES[MAX_MODES * MAX_STYLES],
    RUN_BESTTIMES_UID[MAX_MODES * MAX_STYLES],
    RUN_BESTTIMES_NAME[MAX_MODES * MAX_STYLES * MAX_BEST_NAME_CELL],
    
    //RUN_NUMRECORDS[MAX_MODES * MAX_STYLES],
    
    RUN_CLIENTTIMES[MAX_MODES * MAX_STYLES * INF_MAXPLAYERS],
    
    RUN_SIZE
};

enum
{
    MODE_NAME[MAX_MODE_NAME_CELL] = 0,
    MODE_SHORTNAME[MAX_MODE_SHORTNAME_CELL],
    
    MODE_ID,
    MODE_DISPLAY,
    
    MODE_MAXSPEED,
    
    MODE_SIZE
};

enum
{
    STYLE_NAME[MAX_STYLE_NAME_CELL] = 0,
    STYLE_SHORTNAME[MAX_STYLE_SHORTNAME_CELL],
    
    STYLE_ID,
    STYLE_DISPLAY,
    
    STYLE_SIZE
};


#define INF_TABLE_USERS             "inf_users"
#define INF_TABLE_MAPS              "inf_maps"
#define INF_TABLE_TIMES             "inf_times"
#define INF_TABLE_DBVER             "inf_dbversion"

// Not using the sql type since it's missing features.
native Handle Influx_GetDB();
native bool Influx_IsMySQL();


// Argument will be -1 if all of that class was removed.
// Eg uid = 1337, runid = 3, mode = -1, style = -1 means user 1337's all run 3 records will be deleted.
// It is not guaranteed whether any record get/set will work (eg Influx_GetClientCurrentPB) in this forward.
forward void Influx_OnRecordRemoved( int issuer, int uid, int mapid, int runid, int mode, int style );


// When record info is being printed to client.
// Use this to add items onto the menu.
// Item list is max 64 characters. (incl null terminator)
// Look at strafe/jump counter plugin for an example how info is added.
// For button items, check the checkpoint plugin.
forward void Influx_OnPrintRecordInfo( int client, Handle dbres, ArrayList itemlist, Menu menu, int uid, int mapid, int runid, int mode, int style );

// We've pressed a button in the record info menu.
// Use this if you've added button items.
// For an example take a look into the checkpoint plugin.
forward Action Influx_OnRecordInfoButtonPressed( int client, const char[] szInfo );


// New if we inserted new record.
forward void Influx_OnClientIdRetrieved( int client, int uid, bool bNew );

// New if we inserted new record.
forward void Influx_OnMapIdRetrieved( int mapid, bool bNew );


// Will return 0 if map id hasn't been retrieved.
native int Influx_GetCurrentMapId();



// When we've retrieved our map id and records.
forward void Influx_OnPostRecordsLoad();


// Do we have client's times and user id?
native bool Influx_IsClientCached( int client );


// Will return 0 if it hasn't been retrieved.
// NOTE: This is not engine's user id.
native int Influx_GetClientId( int client );



forward void Influx_OnRequestModes();
forward void Influx_OnRequestStyles();

// If forward, OnRunCreated is called.
native bool Influx_AddRun( int id = -1, const char[] szName = "", const float vecTelePos[3], float flTeleYaw = 0.0, bool bDoForward = true );
native bool Influx_AddMode( int id, const char[] szName, const char[] szShortName, float flMaxSpeed = 0.0 );
native bool Influx_AddStyle( int id, const char[] szName, const char[] szShortName, bDisplay = true );

native bool Influx_RemoveMode( int id );
native bool Influx_RemoveStyle( int id );


native int Influx_FindRunById( int runid );
native bool Influx_GetRunName( int runid, char[] out, int len );


// Runs haven't been read from file/db yet.
// Called before anything is loaded. Good time to clear per-map dynamic arrays that rely on run ids. (eg. prespeed plugin)
forward void Influx_OnPreRunLoad();

// Runs array has been filled with all existing runs.
forward void Influx_OnPostRunLoad();

native Handle Influx_GetPostRunLoadForward();


forward void Influx_OnRunCreated( int runid ); // New run that wasn't loaded from file.
forward void Influx_OnRunDeleted( int runid );
forward void Influx_OnRunLoad( int runid, KeyValues kv );
forward void Influx_OnRunSave( int runid, KeyValues kv );

native ArrayList Influx_GetRunsArray();



#define PRINTFLAGS_NOPREFIX         ( 1 << 0 )
#define PRINTFLAGS_CHATMSG          ( 1 << 1 ) // Sent by client. Currently not used.

// Use these if you want the correct prefix.
native void Influx_PrintToChat( int flags = 0, int client, const char[] format, any ... );
native void Influx_PrintToChatAll( int flags = 0, int author, const char[] format, any ... );
native void Influx_PrintToChatEx( int flags = 0, int author, const int[] clients, int nClients, const char[] format, any ... );
native void Influx_RemoveChatColors( char[] sz, int len );
native void Influx_FormatChatColors( char[] sz, int len );



native ArrayList Influx_GetModesArray();
native ArrayList Influx_GetStylesArray();

// If check, returned name may be empty. (don't want to display it.)
native void Influx_GetModeName( int mode, char[] out, int len, bool bCheckDisplay = false );
native void Influx_GetModeShortName( int mode, char[] out, int len, bool bCheckDisplay = false );
native void Influx_GetStyleName( int style, char[] out, int len, bool bCheckDisplay = false );
native void Influx_GetStyleShortName( int style, char[] out, int len, bool bCheckDisplay = false );

// Returns false if only mode/style or mode/style is set not to display.
native bool Influx_ShouldModeDisplay( int mode );
native bool Influx_ShouldStyleDisplay( int style );


#define MAX_RUNRES_NAME         64
#define MAX_RUNRES_NAME_CELL    ( MAX_RUNRES_NAME / 4 )

enum
{
    RUNRES_NAME[MAX_RUNRES_NAME_CELL] = 0,
    RUNRES_FLAG,
    
    RUNRES_SIZE
};

#define RES_TIME_FIRSTREC           ( 1 << 0 ) // Is very first record for that run, mode and style.
#define RES_TIME_ISBEST             ( 1 << 1 ) // Is new best record.
#define RES_TIME_FIRSTOWNREC        ( 1 << 2 ) // Player beat it for the first time.
#define RES_TIME_PB                 ( 1 << 3 ) // Is new personal best.
#define RES_TIME_DONTSAVE           ( 1 << 4 ) // Will not save record to database.
#define RES_RECORDING_DONTSAVE      ( 1 << 5 ) // Will not save recording file.
#define RES_CHAT_DONTPRINT          ( 1 << 6 ) // Will not print record chat message.
#define RES_SND_DONTPLAY            ( 1 << 7 ) // Will not play record sound.

forward void Influx_OnRequestResultFlags();

native bool Influx_AddResultFlag( const char[] szName, int flag );


// Always use -post forwards to make sure it was actually started/finished/reset.
forward Action Influx_OnTimerStart( int client, int runid, char[] errormsg, int error_len );
forward void Influx_OnTimerStartPost( int client, int runid );
forward Action Influx_OnTimerFinish( int client, int runid, int mode, int style, float time, int flags, char[] errormsg, int error_len );
forward void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags );
forward void Influx_OnTimerResetPost( int client );

native void Influx_StartTimer( int client, int runid );
native void Influx_FinishTimer( int client, int runid );
native void Influx_ResetTimer( int client, int runid );


enum RunState_t
{
    STATE_NONE = 0, // We don't have a run.
    STATE_START, // We have entered the start.
    STATE_RUNNING,
    STATE_FINISHED // Finished a valid run.
};

native RunState_t Influx_GetClientState( int client );
native void Influx_SetClientState( int client, RunState_t state );


// If safe and we are unable to teleport player to start, we stop them from running.
native void Influx_TeleportToStart( int client, bool bSafe = false );

// Something suspicious happens? Use me to turn off their timer! Best prank 2016!
native void Influx_InvalidateClientRun( int client );

native int Influx_GetClientRunId( int client );

native int Influx_GetClientMode( int client );
native bool Influx_SetClientMode( int client, int mode );

native int Influx_GetClientStyle( int client );
native bool Influx_SetClientStyle( int client, int style );


// When client's run, mode or style has changed.
forward void Influx_OnClientStatusChanged( int client );

forward Action Influx_OnClientModeChange( int client, int mode, int lastmode );
forward void Influx_OnClientModeChangePost( int client, int mode );
forward Action Influx_OnClientStyleChange( int client, int style, int laststyle );
forward void Influx_OnClientStyleChangePost( int client, int style );

// This is where we make sure the player is abiding the style rules.
// Look at style plugins for an example.
forward Action Influx_OnCheckClientStyle( int client, int style, float vel[3] );


native float Influx_GetClientTime( int client );
native float Influx_GetClientFinishedTime( int client );
native float Influx_GetClientFinishedBestTime( int client );
native int Influx_GetClientStartTick( int client );
native void Influx_SetClientStartTick( int client, int tick );

native float Influx_GetClientPB( int client, int runid, int mode, int style );
native float Influx_GetClientCurrentPB( int client );

native float Influx_GetClientCurrentBestTime( int client );
native void Influx_GetClientCurrentBestName( int client, char[] out, int len );

// Optionally get id too.
native float Influx_GetRunBestTime( int runid, int mode, int style, int &id );


enum Search_t
{
    SEARCH_INVALID = -1,
    SEARCH_MAPID,
    SEARCH_UID,
    SEARCH_RUNID,
    SEARCH_MODE,
    SEARCH_STYLE,
    
    // value is an offset.
    SEARCH_MAPNAME,
    SEARCH_PLAYERNAME
};

// Look at mode/style plugins for an example.
forward Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value );


// Searching for ending position.
forward Action Influx_OnSearchEnd( int runid, float pos[3] );



stock bool Inf_SDKHook( int entity, SDKHookType type, SDKHookCB callback )
{
    if ( !SDKHookEx( entity, type, callback ) )
    {
        LogError( INF_CON_PRE..."Couldn't hook entity with SDKHook (ent: %i)!", entity );
        return false;
    }
    
    return true;
}

stock bool Inf_SendConVarValueFloat( int client, Handle convar, float value, const char[] szFormat = "%.0f" )
{
    char szValue[6];
    FormatEx( szValue, sizeof( szValue ), szFormat, value );
    
    if ( !SendConVarValue( client, convar, szValue ) )
    {
        LogError( INF_CON_PRE..."Couldn't send float convar value (%s)!", szValue );
        return false;
    }
    
    return true;
}

stock bool Inf_SendConVarValueBool( int client, Handle convar, bool value )
{
    if ( !SendConVarValue( client, convar, value ? "1" : "0" ) )
    {
        LogError( INF_CON_PRE..."Couldn't send bool convar value!" );
        return false;
    }
    
    return true;
}

stock bool Inf_GetClientSteam( int client, char[] out, int len )
{
    if ( !GetClientAuthId( client, AuthId_Steam3, out, len, true ) )
    {
        LogError( INF_CON_PRE..."Couldn't retrieve client's \"%N\" Steam Id!", client );
        
        
        if ( IsClientInGame( client ) )
        {
            Influx_PrintToChat( _, client, "Couldn't retrieve your Steam Id. Please reconnect and make sure you are connected to Steam!!" );
        }
        
        return false;
    }
    
    return true;
}

stock void Inf_DB_LogError( Handle db, const char[] szAdd, int client = 0, const char[] szClientMsg = "" )
{
    if ( db == null ) return;
    
    
    char szError[128];
    SQL_GetError( db, szError, sizeof( szError ) );
    
    LogError( INF_CON_PRE..."SQL Error: %s (%s)", szError, szAdd );
    
    
    if ( IS_ENT_PLAYER( client ) && IsClientInGame( client ) && szClientMsg[0] != '\0' )
    {
        Influx_PrintToChat( _, client, szClientMsg );
    }
}

stock bool Inf_HandleCmdSpam( int client, float delay = 1.0, float &lasttime, bool bPrint = false )
{
    float dif = (lasttime + delay) - GetEngineTime();
    
    if ( dif > 0.0 )
    {
        if ( bPrint )
            Influx_PrintToChat( _, client, "Please wait {MAINCLR1}%.1f{CHATCLR} seconds before using this command!", dif );
        
        return true;
    }
    
    lasttime = GetEngineTime();
    
    return false;
}

stock void Inf_Warning( int num = 1, const char[] format, any ... )
{
    decl String:msg[512];
    VFormat( msg, sizeof( msg ), format, 3 );
    
    Format( msg, sizeof( msg ), INF_CON_PRE..."WARNING: %s", msg );
    
    
    for ( int i = 0; i < num; i++ ) PrintToServer( msg );
}

public SharedPlugin __pl_influx_core =
{
    name = INFLUX_LIB_CORE,
    file = INFLUX_LIB_CORE...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_core_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_AddMode" );
    MarkNativeAsOptional( "Influx_AddRun" );
    MarkNativeAsOptional( "Influx_AddResultFlag" );
    MarkNativeAsOptional( "Influx_AddStyle" );
    MarkNativeAsOptional( "Influx_FindRunById" );
    MarkNativeAsOptional( "Influx_FinishTimer" );
    MarkNativeAsOptional( "Influx_FormatChatColors" );
    MarkNativeAsOptional( "Influx_GetClientCurrentBestName" );
    MarkNativeAsOptional( "Influx_GetClientCurrentBestTime" );
    MarkNativeAsOptional( "Influx_GetClientCurrentPB" );
    MarkNativeAsOptional( "Influx_GetClientFinishedBestTime" );
    MarkNativeAsOptional( "Influx_GetClientFinishedTime" );
    MarkNativeAsOptional( "Influx_GetClientId" );
    MarkNativeAsOptional( "Influx_GetClientMode" );
    MarkNativeAsOptional( "Influx_GetClientPB" );
    MarkNativeAsOptional( "Influx_GetClientRunId" );
    MarkNativeAsOptional( "Influx_GetClientStartTick" );
    MarkNativeAsOptional( "Influx_GetClientState" );
    MarkNativeAsOptional( "Influx_GetClientStyle" );
    MarkNativeAsOptional( "Influx_GetClientTime" );
    MarkNativeAsOptional( "Influx_GetCurrentMapId" );
    MarkNativeAsOptional( "Influx_GetDB" );
    MarkNativeAsOptional( "Influx_GetModeName" );
    MarkNativeAsOptional( "Influx_GetModesArray" );
    MarkNativeAsOptional( "Influx_GetModeShortName" );
    MarkNativeAsOptional( "Influx_GetNextMenuTime" );
    MarkNativeAsOptional( "Influx_GetPostRunLoadForward" );
    MarkNativeAsOptional( "Influx_GetRunBestTime" );
    MarkNativeAsOptional( "Influx_GetRunName" );
    MarkNativeAsOptional( "Influx_GetRunsArray" );
    MarkNativeAsOptional( "Influx_GetStyleName" );
    MarkNativeAsOptional( "Influx_GetStylesArray" );
    MarkNativeAsOptional( "Influx_GetStyleShortName" );
    MarkNativeAsOptional( "Influx_InvalidateClientRun" );
    MarkNativeAsOptional( "Influx_IsClientCached" );
    MarkNativeAsOptional( "Influx_IsMySQL" );
    MarkNativeAsOptional( "Influx_PrintToChat" );
    MarkNativeAsOptional( "Influx_PrintToChatAll" );
    MarkNativeAsOptional( "Influx_PrintToChatEx" );
    MarkNativeAsOptional( "Influx_RemoveChatColors" );
    MarkNativeAsOptional( "Influx_ResetTimer" );
    MarkNativeAsOptional( "Influx_SetClientMode" );
    MarkNativeAsOptional( "Influx_SetClientStartTick" );
    MarkNativeAsOptional( "Influx_SetClientState" );
    MarkNativeAsOptional( "Influx_SetClientStyle" );
    MarkNativeAsOptional( "Influx_SetNextMenuTime" );
    MarkNativeAsOptional( "Influx_ShouldModeDisplay" );
    MarkNativeAsOptional( "Influx_ShouldStyleDisplay" );
    MarkNativeAsOptional( "Influx_StartTimer" );
    MarkNativeAsOptional( "Influx_TeleportToStart" );
}
#endif