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
    if ( mapid < 1 ) SetFailState( INF_CON_PRE..."Invalid map id." );
    
    
    // Format where clause.
    decl String:szWhere[128];
    szWhere[0] = '\0';
    FormatWhereClause( szWhere, sizeof( szWhere ), runid, mode, style, cpnum ); 
    
    
    // Base query.
    decl String:szQuery[512];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT " ...
        "uid," ...
        "runid," ...
        "mode," ...
        "style," ...
        "cpnum," ...
        "cptime " ...
        "FROM "...INF_TABLE_TIMES..." NATURAL JOIN "...INF_TABLE_CPTIMES..." WHERE mapid=%i%s " ...
        "GROUP BY runid,mode,style,cpnum " ...
        "ORDER BY MIN(rectime)",
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
    
    
    
    static char szQuery[800];
    
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT uid,mapid,runid,mode,style,cpnum,cptime,rectime," ...
            "(SELECT cptime " ...
                "FROM "...INF_TABLE_TIMES..." NATURAL JOIN "...INF_TABLE_CPTIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND cpnum=_cp.cpnum " ...
                "GROUP BY runid,mode,style " ...
                "ORDER BY MIN(rectime)" ...
            ") AS srtime," ...
            "(SELECT cptime " ...
                "FROM "...INF_TABLE_CPTIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND cpnum=_cp.cpnum " ...
                "GROUP BY runid,mode,style " ...
                "ORDER BY MIN(cptime)" ...
            ") AS besttime " ...
        "FROM "...INF_TABLE_CPTIMES..." AS _cp NATURAL JOIN "...INF_TABLE_TIMES..." AS _t WHERE uid=%i AND mapid=%i AND runid=%i AND mode=%i AND style=%i ORDER BY cpnum",
        uid,
        mapid,
        runid,
        mode,
        style );
    
    SQL_TQuery( db, Thrd_PrintCPTimes, szQuery, GetClientUserId( client ), DBPrio_Low );
}