#include <sourcemod>

#include <influx/core>

//#undef REQUIRE_PLUGIN
//#include <influx/hud>


ConVar g_ConVar_WaitTime;
ConVar g_ConVar_MinRecords;


enum
{
    PCB_USERID = 0,
    
    PCB_RUNID,
    PCB_MODE,
    PCB_STYLE,
    
    PCB_SIZE
};


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Record Rank",
    description = "Displays record's rank in chat.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // PHRASES
    LoadTranslations( INFLUX_PHRASES );
    
    
    // CONVARS
    g_ConVar_WaitTime = CreateConVar( "influx_recrank_secstowait", "1.0", "Number of seconds to wait before printing the rank.", FCVAR_NOTIFY, true, 0.01 );
    g_ConVar_MinRecords = CreateConVar( "influx_recrank_minrecords", "1", "Number of records required before printing rank.", FCVAR_NOTIFY, true, 0.0 );
    
    
    AutoExecConfig( true, "recrank", "influx" );
}

stock bool ShouldPrint( int flags, float time, float prev_pb, float prev_best )
{
    // We don't get saved to db.
    if ( flags & RES_TIME_DONTSAVE ) return false;
    
    
    if ( time < prev_pb ) return true;
    
    if ( time < prev_best ) return true;
    
    if ( flags & (RES_TIME_ISBEST | RES_TIME_FIRSTREC | RES_TIME_FIRSTOWNREC) ) return true;
    
    
    return false;
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    if ( !ShouldPrint( flags, time, prev_pb, prev_best ) )
    {
        return;
    }
    
    
    ArrayList array = new ArrayList( PCB_SIZE );
    
    decl data[PCB_SIZE];
    data[PCB_USERID] = GetClientUserId( client );
    data[PCB_RUNID] = runid;
    data[PCB_MODE] = mode;
    data[PCB_STYLE] = style;
    
    
    array.PushArray( data );
    
    CreateTimer( g_ConVar_WaitTime.FloatValue, T_Display, array );
}

public Action T_Display( Handle hTimer, ArrayList array )
{
    decl data[PCB_SIZE];
    
    array.GetArray( 0, data );
    
    delete array;
    
    
    int client = GetClientOfUserId( data[PCB_USERID] );
    if ( client < 1 || !IsClientInGame( client ) ) return Plugin_Stop;
    
    
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    int mapid = Influx_GetCurrentMapId();
    
    
    decl String:szQuery[512];
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT " ...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style)," ...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND rectime<_t.rectime) " ...
        "FROM "...INF_TABLE_TIMES..." AS _t NATURAL JOIN "...INF_TABLE_USERS..." WHERE uid=%i AND mapid=%i AND runid=%i AND mode=%i AND style=%i",
        Influx_GetClientId( client ),
        mapid,
        data[PCB_RUNID],
        data[PCB_MODE],
        data[PCB_STYLE] );
        
    SQL_TQuery( db, Thrd_Display, szQuery, data[PCB_USERID], DBPrio_Normal );
    
    return Plugin_Stop;
}

public void Thrd_Display( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "displaying client's rank" );
        return;
    }
    
    if ( !SQL_FetchRow( res ) ) return;
    
    
    client = GetClientOfUserId( client );
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    
    decl String:szName[MAX_NAME_LENGTH];
    GetClientName( client, szName, sizeof( szName ) );
    
    Influx_RemoveChatColors( szName, sizeof( szName ) );
    
    
    int numrecs = SQL_FetchInt( res, 0 );
    int rank = SQL_FetchInt( res, 1 ) + 1;
    
    
    // Not enough records to print yet.
    if ( g_ConVar_MinRecords.IntValue > numrecs ) return;
    
    
    
    Influx_PrintToChatAll( _, client, "%T",
        "INF_RANKCHAT", LANG_SERVER,
        szName,
        rank,
        numrecs );
}