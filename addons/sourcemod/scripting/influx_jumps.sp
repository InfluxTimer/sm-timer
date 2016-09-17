#include <sourcemod>

#include <influx/core>
#include <influx/stocks_core>
#include <influx/jumps>

#undef REQUIRE_PLUGIN
#include <influx/pause>


int g_nNumJumps[INF_MAXPLAYERS];

bool g_bLib_Pause;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Jumps",
    description = "Counts jumps.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_JUMPS );
    
    // NATIVES
    CreateNative( "Influx_GetClientJumpCount", Native_GetClientJumpCount );
}

public void OnPluginStart()
{
    // EVENTS
    HookEvent( "player_jump", E_PlayerJump );
    
    
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
}

public void OnAllPluginsLoaded()
{
    Handle db = Influx_GetDB();
    
    if ( db == null )
    {
        SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    }
    
    
    SQL_TQuery( db, Thrd_Empty, "ALTER TABLE "...INF_TABLE_TIMES..." ADD COLUMN jump_num INTEGER DEFAULT -1", _, DBPrio_High );
}

public void Thrd_Empty( Handle db, Handle res, const char[] szError, any data ) {}

public void Influx_OnTimerStartPost( int client, int runid )
{
    g_nNumJumps[client] = 0;
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    if ( flags & (RES_TIME_PB | RES_TIME_FIRSTOWNREC) )
    {
        Handle db = Influx_GetDB();
        if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
        
        
        decl String:szQuery[192];
        FormatEx( szQuery, sizeof( szQuery ), "UPDATE "...INF_TABLE_TIMES..." SET jump_num=%i WHERE uid=%i AND mapid=%i AND runid=%i AND mode=%i AND style=%i",
            g_nNumJumps[client],
            Influx_GetClientId( client ),
            Influx_GetCurrentMapId(),
            runid,
            mode,
            style );
        
        SQL_TQuery( db, Thrd_Update, szQuery, GetClientUserId( client ), DBPrio_High );
    }
}

public void Thrd_Update( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "updating player's record with jumps", GetClientOfUserId( client ), "Couldn't record your jumps!" );
    }
}

public void E_PlayerJump( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    int client;
    if ( !(client = GetClientOfUserId( GetEventInt( event, "userid" ) )) ) return;
    
    if ( !IsPlayerAlive( client ) ) return;
    
    // Only when running.
    if ( Influx_GetClientState( client ) != STATE_RUNNING ) return;
    
    // Don't count if paused.
    if ( g_bLib_Pause && Influx_IsClientPaused( client ) ) return;
    
    
    ++g_nNumJumps[client];
}

// NATIVES
public int Native_GetClientJumpCount( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    return g_nNumJumps[client];
}