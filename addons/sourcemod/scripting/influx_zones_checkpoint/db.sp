// Callbacks
#include "influx_zones_checkpoint/db_cb.sp"


#define CUR_DB_VERSION          1


stock void FormatWhereClause( char[] sz, int len, int runid, int mode, int style, int cpnum )
{
    if ( runid > 0 ) FormatEx( sz, len, " AND runid=%i", runid );
    if ( VALID_MODE( mode ) ) Format( sz, len, "%s AND mode=%i", sz, mode );
    if ( VALID_STYLE( style ) ) Format( sz, len, "%s AND style=%i", sz, style );
    if ( cpnum > 0 ) Format( sz, len, "%s AND cpnum=%i", sz, cpnum );
}

public void DB_Init()
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    SQL_TQuery( db, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_CPTIMES..." (" ...
        "uid INT NOT NULL," ...
        "mapid INT NOT NULL," ...
        "runid INT NOT NULL," ...
        "mode INT NOT NULL," ...
        "style INT NOT NULL," ...
        "cpnum INT NOT NULL," ...
        "cptime REAL NOT NULL," ...
        "PRIMARY KEY(uid,mapid,runid,mode,style,cpnum))", _, DBPrio_High );
}

stock void DB_GetCPTimes( int runid = -1, int mode = -1, int style = -1, int cpnum = -1 )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    int mapid = Influx_GetCurrentMapId();
    
    
    // Format where clause.
    decl String:szWhere[128];
    szWhere[0] = '\0';
    FormatWhereClause( szWhere, sizeof( szWhere ), runid, mode, style, cpnum ); 
    
    
    // Base query.
    decl String:szQuery[512];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT " ...
        "_t.uid," ...
        "_t.runid," ...
        "_t.mode," ...
        "_t.style," ...
        "cpnum," ...
        "cptime " ...
        "FROM "...INF_TABLE_TIMES..." AS _t INNER JOIN "...INF_TABLE_CPTIMES..." AS _cp ON _t.uid=_cp.uid AND _t.runid=_cp.runid AND _t.mode=_cp.mode AND _t.style=_cp.style WHERE _t.mapid=%i%s " ...
        
        "AND rectime=(SELECT " ...
            "MIN(rectime) " ...
            "FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style" ...
        ") " ...
        
        "GROUP BY _t.runid,_t.mode,_t.style,cpnum " ...
        "ORDER BY _t.runid,cpnum",
        mapid,
        szWhere );
    
    SQL_TQuery( db, Thrd_GetCPTimes, szQuery, _, DBPrio_High );
}

stock bool DB_InsertClientTimes( int client, int runid, int mode, int style, int flags )
{
#if defined DEBUG_INSERTREC
    PrintToServer( INF_DEBUG_PRE..."Inserting client's %i cp times.", client );
#endif
    
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    int mapid = Influx_GetCurrentMapId();
    if ( mapid < 1 ) SetFailState( INF_CON_PRE..."Invalid map id." );
    
    
    
    decl String:szQuery[256];
    
    int uid = Influx_GetClientId( client );
    
    int userid = GetClientUserId( client );
    
#if defined DEBUG_INSERTREC
    PrintToServer( INF_DEBUG_PRE..."Deleting old cp times..." );
#endif
    
    FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...INF_TABLE_CPTIMES..." WHERE uid=%i AND mapid=%i AND runid=%i AND mode=%i AND style=%i",
        uid,
        mapid,
        runid,
        mode,
        style );
    
    SQL_TQuery( db, Thrd_Update, szQuery, userid, DBPrio_High );
    
    
    
    decl cpnum;
    decl Float:time;
    
    
    bool bIsRecord = ( flags & RES_TIME_ISBEST || flags & RES_TIME_FIRSTREC )
    
    
    int len = g_hCPs.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPs.Get( i, CP_RUN_ID ) != runid ) continue;
        
        
        cpnum = g_hCPs.Get( i, CP_NUM );
        
        // Get our time.
        // If we never entered this cp, insert an empty record.
        int index = FindClientCPByNum( client, cpnum );
        if ( index != -1 )
        {
            time = g_hClientCP[client].Get( index, CCP_TIME );
        }
        else
        {
            //time = INVALID_RUN_TIME;
            continue;
        }
        
#if defined DEBUG_INSERTREC
        PrintToServer( INF_DEBUG_PRE..."Inserting cp %i time %.3f", cpnum, time );
#endif
        
        FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...INF_TABLE_CPTIMES..." (uid,mapid,runid,mode,style,cpnum,cptime) VALUES (%i,%i,%i,%i,%i,%i,%f)",
            uid,
            mapid,
            runid,
            mode,
            style,
            cpnum,
            time );
        
        SQL_TQuery( db, Thrd_Update, szQuery, userid, DBPrio_High );
        
        
        if ( bIsRecord )
        {
            SetBestTime( i, mode, style, time, uid );
        }
    }
    
    return true;
}

stock void DB_PrintCPTimes( int client, int uid, int mapid, int runid, int mode, int style )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    
    static char szQuery[1024];
    
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT _t.uid,_t.mapid,_t.runid,_t.mode,_t.style,cpnum,cptime,rectime" ...

        // Checkpoint's server record time.
        ",(SELECT cptime " ...
        "FROM inf_times AS _t2 INNER JOIN "...INF_TABLE_CPTIMES..." AS _cp2 ON _cp2.uid=_t2.uid AND _cp2.mapid=_t2.mapid AND _cp2.mode=_t2.mode AND _cp2.style=_t2.style " ...
        "WHERE _t2.mapid=_t.mapid AND _t2.runid=_t.runid AND _t2.mode=_t.mode AND _t2.style=_t.style AND _cp2.cpnum=_cp.cpnum AND rectime=" ...
            "(SELECT MIN(rectime) FROM inf_times WHERE mapid=_t2.mapid AND runid=_t2.runid AND mode=_t2.mode AND style=_t2.style)" ...
        ") AS cpsrtime" ...

        // Checkpoint's absolute best time.
        ",(SELECT MIN(cptime) " ...
        "FROM "...INF_TABLE_CPTIMES..." " ...
        "WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND cpnum=_cp.cpnum" ...
        ") AS cpbesttime " ...

        "FROM "...INF_TABLE_CPTIMES..." AS _cp INNER JOIN inf_times AS _t ON _cp.uid=_t.uid AND _cp.mapid=_t.mapid AND _cp.mode=_t.mode AND _cp.style=_t.style " ...
        "WHERE _t.uid=%i AND _t.mapid=%i AND _t.runid=%i AND _t.mode=%i AND _t.style=%i " ...
        "ORDER BY cpnum",
        uid,
        mapid,
        runid,
        mode,
        style );
    
    SQL_TQuery( db, Thrd_PrintCPTimes, szQuery, GetClientUserId( client ), DBPrio_Low );
}

stock void DB_PrintDeleteCPTimes( int client, int mapid )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    char szQuery[256];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT runid,cpnum,COUNT(*) FROM "...INF_TABLE_CPTIMES..." WHERE mapid=%i GROUP BY runid,cpnum ORDER BY runid,cpnum",
        mapid );
    
    SQL_TQuery( db, Thrd_PrintDeleteCpTimes, szQuery, GetClientUserId( client ), DBPrio_Low );
}

stock void DB_DeleteCPTimes( int issuer, int mapid, int runid, int cpnum )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    char szQuery[256];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "DELETE FROM "...INF_TABLE_CPTIMES..." WHERE mapid=%i AND runid=%i AND cpnum=%i",
        mapid,
        runid,
        cpnum );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, issuer ? GetClientUserId( issuer ) : 0, DBPrio_High );
}