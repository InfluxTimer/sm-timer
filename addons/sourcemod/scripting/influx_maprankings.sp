#include <sourcemod>

#include <influx/core>
#include <influx/maprankings>


#define DEBUG_DB


enum
{
    RANK_RUN_ID = 0,
    
    RANK_NUMRANKS[MAX_STYLES * MAX_MODES],
    RANK_PLYRANKS[MAX_STYLES * MAX_MODES * INF_MAXPLAYERS],
    
    RANK_SIZE
}



ArrayList g_hRunRanks;


//bool g_bCached[INF_MAXPLAYERS];
int g_nCurrentRank[INF_MAXPLAYERS];
int g_nCurrentRankCount[INF_MAXPLAYERS];


bool g_bCachedNumRecs;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Map Rankings",
    description = "Holds player rankings for current map.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_MAPRANKS );
    
    
    // NATIVES
    CreateNative( "Influx_GetClientMapRank", Native_GetClientMapRank );
    
    CreateNative( "Influx_GetClientCurrentMapRank", Native_GetClientCurrentMapRank );
    CreateNative( "Influx_GetClientCurrentMapRankCount", Native_GetClientCurrentMapRankCount );
    
    CreateNative( "Influx_GetRunMapRankCount", Native_GetRunMapRankCount );
}

public void OnPluginStart()
{
    g_hRunRanks = new ArrayList( RANK_SIZE );
}

public void OnClientPutInServer( int client )
{
    //g_bCached[client] = false;
    
    g_nCurrentRank[client] = 0;
    g_nCurrentRankCount[client] = 0;
    
    ResetClientRanks( client );
}

public void Influx_OnClientStatusChanged( int client )
{
    int irun = FindRunRankById( Influx_GetClientRunId( client ) );
    if ( irun == -1 ) return;
    
    
    int mode = Influx_GetClientMode( client );
    int style = Influx_GetClientStyle( client );
    
    g_nCurrentRank[client] = GetClientRank( irun, client, mode, style );
    g_nCurrentRankCount[client] = GetRunRankCount( irun, mode, style );
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    if ( flags & (RES_TIME_PB | RES_TIME_FIRSTOWNREC) )
    {
        DB_InitClientRanks( client, runid, mode, style );
        
        if ( flags & RES_TIME_FIRSTOWNREC )
        {
            DB_InitNumRecs( runid, mode, style );
        }
    }
}

public void Influx_OnPreRunLoad()
{
    g_bCachedNumRecs = false;
    
    g_hRunRanks.Clear();
}

public void Influx_OnRunLoad( int runid, KeyValues kv )
{
    if ( FindRunRankById( runid ) != -1 ) return;
    
    
    int data[RANK_SIZE];
    data[RANK_RUN_ID] = runid;
    
    g_hRunRanks.PushArray( data );
}

public void Influx_OnRunCreated( int runid )
{
    if ( FindRunRankById( runid ) != -1 ) return;
    
    
    int data[RANK_SIZE];
    data[RANK_RUN_ID] = runid;
    
    g_hRunRanks.PushArray( data );
}

public void Influx_OnRunDeleted( int runid )
{
    int index = FindRunRankById( runid );
    if ( index != -1 )
    {
        g_hRunRanks.Erase( index );
    }
}

public void Influx_OnMapIdRetrieved( int mapid, bool bNew )
{
    DB_InitNumRecs();
}

public void Influx_OnClientIdRetrieved( int client, int uid, bool bNew )
{
    DB_InitClientRanks( client );
}

stock void DB_InitNumRecs( int runid = -1, int mode = MODE_INVALID, int style = STYLE_INVALID )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    int mapid = Influx_GetCurrentMapId();
    
    
    static char szWhere[128];
    szWhere[0] = 0;
    
    FormatWhereClause( szWhere, sizeof( szWhere ), runid, mode, style );
    
    
    static char szQuery[512];
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT " ...
        "runid," ...
        "mode," ...
        "style," ...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style) AS numrecs " ...
        "FROM "...INF_TABLE_TIMES..." AS _t WHERE mapid=%i%s " ...
        "GROUP BY runid,mode,style " ...
        "ORDER BY runid",
        mapid,
        szWhere );
    
    SQL_TQuery( db, Thrd_InitNumRecs, szQuery, _, DBPrio_Low );
}
stock void DB_InitClientRanks( int client, int runid = -1, int mode = MODE_INVALID, int style = STYLE_INVALID )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    int mapid = Influx_GetCurrentMapId();
    int uid = Influx_GetClientId( client );
    
    
    static char szWhere[128];
    szWhere[0] = 0;
    
    FormatWhereClause( szWhere, sizeof( szWhere ), runid, mode, style );
    
    
    static char szQuery[512];
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT " ...
        "runid, " ...
        "mode, " ...
        "style, " ...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND rectime<_t.rectime) AS rank " ...
        "FROM "...INF_TABLE_TIMES..." AS _t WHERE uid=%i AND mapid=%i%s " ...
        "GROUP BY runid,mode,style " ...
        "ORDER BY runid",
        uid,
        mapid,
        szWhere );
    
    SQL_TQuery( db, Thrd_InitClientRanks, szQuery, GetClientUserId( client ), DBPrio_Low );
}

public void Thrd_InitNumRecs( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting record count" );
        return;
    }
    
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Getting record count..." );
#endif
    
    int irun = -1;
    int lastrunid = -1;
    
    int runid, mode, style;
    int numrecs;
    
    while ( SQL_FetchRow( res ) )
    {
        if ( (runid = SQL_FetchInt( res, 0 )) != lastrunid )
        {
            irun = FindRunRankById( runid );
        }
        
        lastrunid = runid;
        
        if ( irun == -1 ) continue;
        
        
        mode = SQL_FetchInt( res, 1 );
        style = SQL_FetchInt( res, 2 );
        
        if ( !VALID_MODE( mode ) ) continue;
        if ( !VALID_STYLE( style ) ) continue;
        
        
        numrecs = SQL_FetchInt( res, 3 );
        
#if defined DEBUG_DB
        PrintToServer( INF_DEBUG_PRE..."Setting record count to %i (%i, %i, %i)...", numrecs, runid, mode, style );
#endif
        
        SetRunRankCount( irun, mode, style, numrecs );
    }
    
    
    if ( g_bCachedNumRecs )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) && !IsFakeClient( i ) )
            {
                Influx_OnClientStatusChanged( i );
            }
        }
    }
    
    g_bCachedNumRecs = true;
}

public void Thrd_InitClientRanks( Handle db, Handle res, const char[] szError, int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting client ranks", client, "Couldn't retrieve your ranks! Please try reconnecting." );
        return;
    }
    
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Getting client ranks..." );
#endif
    
    int irun = -1;
    int lastrunid = -1;
    
    int runid, mode, style;
    int rank;
    
    while ( SQL_FetchRow( res ) )
    {
        if ( (runid = SQL_FetchInt( res, 0 )) != lastrunid )
        {
            irun = FindRunRankById( runid );
        }
        
        lastrunid = runid;
        
        if ( irun == -1 ) continue;
        
        
        mode = SQL_FetchInt( res, 1 );
        style = SQL_FetchInt( res, 2 );
        
        if ( !VALID_MODE( mode ) ) continue;
        if ( !VALID_STYLE( style ) ) continue;
        
        
        rank = SQL_FetchInt( res, 3 ) + 1;
        
#if defined DEBUG_DB
        PrintToServer( INF_DEBUG_PRE..."Setting client ranks to %i (%i, %i, %i)...", rank, runid, mode, style );
#endif
        
        SetClientRank( irun, client, mode, style, rank );
    }
    
    
    Influx_OnClientStatusChanged( client );
}

stock void FormatWhereClause( char[] clause, int len, int runid, int mode, int style )
{
    if ( runid > 0 ) FormatEx( clause, len, " AND runid=%i", runid );
    if ( VALID_MODE( mode ) ) Format( clause, len, "%s AND mode=%i", clause, mode );
    if ( VALID_STYLE( style ) ) Format( clause, len, "%s AND style=%i", clause, style );
}

stock int FindRunRankById( int runid )
{
    int len = g_hRunRanks.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hRunRanks.Get( i, RANK_RUN_ID ) == runid )
        {
            return i;
        }
    }
    
    return -1;
}

stock int GetRunRankCount( int index, int mode, int style )
{
    return g_hRunRanks.Get( index, RANK_NUMRANKS + OFFSET_MODESTYLE( mode, style ) );
}

stock void SetRunRankCount( int index, int mode, int style, int rank )
{
    g_hRunRanks.Set( index, rank, RANK_NUMRANKS + OFFSET_MODESTYLE( mode, style ) );
}

stock int GetClientRank( int index, int client, int mode, int style )
{
    return g_hRunRanks.Get( index, RANK_PLYRANKS + OFFSET_MODESTYLECLIENT( mode, style, client ) );
}

stock void SetClientRank( int index, int client, int mode, int style, int rank )
{
    g_hRunRanks.Set( index, rank, RANK_PLYRANKS + OFFSET_MODESTYLECLIENT( mode, style, client ) );
}

stock void ResetClientRanks( int client )
{
    decl i, j, k;
    
    int len = g_hRunRanks.Length;
    for ( i = 0; i < len; i++ )
        for ( j = 0; j < MAX_MODES; j++ )
            for ( k = 0; k < MAX_STYLES; k++ )
            {
                SetClientRank( i, client, j, k, 0 );
            }
}

// NATIVES
public int Native_GetClientMapRank( Handle hPlugin, int nParms )
{
    int irun = FindRunRankById( GetNativeCell( 2 ) );
    if ( irun == -1 ) return 0;
    
    int mode = GetNativeCell( 3 );
    if ( !VALID_MODE( mode ) ) return 0;
    
    int style = GetNativeCell( 4 );
    if ( !VALID_STYLE( style ) ) return 0;
    
    int client = GetNativeCell( 1 );
    
    
    return GetClientRank( irun, client, mode, style );
}

public int Native_GetClientCurrentMapRank( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_nCurrentRank[client];
}

public int Native_GetClientCurrentMapRankCount( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_nCurrentRankCount[client];
}

public int Native_GetRunMapRankCount( Handle hPlugin, int nParms )
{
    int irun = FindRunRankById( GetNativeCell( 1 ) );
    if ( irun == -1 ) return 0;
    
    int mode = GetNativeCell( 2 );
    if ( !VALID_MODE( mode ) ) return 0;
    
    int style = GetNativeCell( 3 );
    if ( !VALID_STYLE( style ) ) return 0;
    
    
    return GetRunRankCount( irun, mode, style );
}