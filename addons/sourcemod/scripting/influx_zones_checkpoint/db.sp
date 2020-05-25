enum
{
    PCB_USERID = 0,
    
    PCB_UID,
    PCB_MAPID,
    PCB_RUNID,
    PCB_MODE,
    PCB_STYLE,
    
    PCB_SIZE
};

enum
{
    PCBTOP_USERID = 0,
    
    PCBTOP_MODE,
    PCBTOP_STYLE,
    
    PCBTOP_SIZE
};


#define CUR_DB_VERSION          1


stock void FormatWhereClause( char[] sz, int len, const char[] table, int runid, int mode, int style, int cpnum )
{
    if ( runid > 0 ) FormatEx( sz, len, " AND %srunid=%i", table, runid );
    if ( VALID_MODE( mode ) ) Format( sz, len, "%s AND %smode=%i", sz, table, mode );
    if ( VALID_STYLE( style ) ) Format( sz, len, "%s AND %sstyle=%i", sz, table, style );
    if ( cpnum > 0 ) Format( sz, len, "%s AND %scpnum=%i", sz, table, cpnum );
}

public void DB_Init()
{
#if defined DISABLE_CREATE_SQL_TABLES
    DISABLE_CREATE_SQL_TABLES
#endif
	
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    SQL_TQuery( db, Thrd_Empty, QUERY_CREATETABLE_CPTIMES, _, DBPrio_High );
}

stock void DB_InitClientCPTimes( int client )
{
    int uid = Influx_GetClientId( client );
    if ( uid < 1 ) return;
    
    
    Handle db = Influx_GetDB();
    
    
    int mapid = Influx_GetCurrentMapId();
    
    
    static char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ), QUERY_INIT_USER_CPTIMES,
        uid,
        mapid );
    
    
    SQL_TQuery( db, Thrd_InitClientCPTimes, szQuery, GetClientUserId( client ), DBPrio_High );
}

stock void DB_InitCPTimes( int runid = -1, int mode = -1, int style = -1, int cpnum = -1 )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    int mapid = Influx_GetCurrentMapId();
    
    char szWhere[162];
    char szWhere2[162];
    char szWhere3[162];
    
    static char szQuery[1200];

    //
    // Get server record times.
    //
    FormatWhereClause( szWhere, sizeof( szWhere ), "", runid, mode, style, cpnum );
    FormatWhereClause( szWhere2, sizeof( szWhere2 ), "_t.", runid, mode, style, cpnum );
    FormatWhereClause( szWhere3, sizeof( szWhere3 ), "_cp.", runid, mode, style, cpnum );

    FormatEx( szQuery, sizeof( szQuery ), QUERY_INIT_SR_CPTIMES,
        mapid, szWhere,
        mapid, szWhere2,
        mapid, szWhere3 );
    
    SQL_TQuery( db, Thrd_GetCPSRTimes, szQuery, _, DBPrio_Normal );
    
    //
    // Get best times.
    //
    szWhere[0] = 0;
    szWhere2[0] = 0;
    FormatWhereClause( szWhere, sizeof( szWhere ), "", runid, mode, style, cpnum );
    FormatWhereClause( szWhere2, sizeof( szWhere2 ), "_cp.", runid, mode, style, cpnum );
    
    FormatEx( szQuery, sizeof( szQuery ), QUERY_INIT_BEST_CPTIMES,
        mapid, szWhere,
        mapid, szWhere2 );
    
    SQL_TQuery( db, Thrd_GetCPBestTimes, szQuery, _, DBPrio_Normal );
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
    
    // We only retrieve the times we have zones for so there is no reason to delete old times.
    // Also you never know if the db disconnects/something goes wrong and the new times never get updated to db.
    /*FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...INF_TABLE_CPTIMES..." WHERE uid=%i AND mapid=%i AND runid=%i AND mode=%i AND style=%i",
        uid,
        mapid,
        runid,
        mode,
        style );
    
    SQL_TQuery( db, Thrd_Update, szQuery, userid, DBPrio_Normal );*/
    
    
    
    decl cpnum;
    decl Float:time;
    
    
    bool bIsRecord = ( flags & RES_TIME_ISBEST || flags & RES_TIME_FIRSTREC );
    
    
    int len = g_hCPs.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hCPs.Get( i, CP_RUN_ID ) != runid ) continue;
        
        
        cpnum = g_hCPs.Get( i, CP_NUM );
        
        // Get our time.
        int index = FindClientCPByNum( client, cpnum );
        if ( index != -1 )
        {
            time = g_hClientCP[client].Get( index, CCP_TIME );
        }
        else
        {
            time = INVALID_RUN_TIME;
        }
        
        
#if defined DEBUG_INSERTREC
        PrintToServer( INF_DEBUG_PRE..."Inserting cp %i time %.3f", cpnum, time );
#endif
        
        FormatEx( szQuery, sizeof( szQuery ), "REPLACE INTO "...INF_TABLE_CPTIMES..." (uid,mapid,runid,mode,style,cpnum,cptime) VALUES (%i,%i,%i,%i,%i,%i,%f)",
            uid,
            mapid,
            runid,
            mode,
            style,
            cpnum,
            time );
        
        SQL_TQuery( db, Thrd_Update, szQuery, userid, DBPrio_Normal );
        
        
        // Update server record time.
        if ( bIsRecord )
        {
            SetRecordTime( i, mode, style, time, uid );
        }
        
        // Update best time.
        if ( time != INVALID_RUN_TIME && time < GetBestTime( i, mode, style ) )
        {
            SetBestTime( i, mode, style, time, uid );
        }
        
        SetClientCPTime( i, client, mode, style, time );
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
        "FROM "...INF_TABLE_TIMES..." AS _t2 INNER JOIN "...INF_TABLE_CPTIMES..." AS _cp2 ON _cp2.uid=_t2.uid AND _cp2.mapid=_t2.mapid AND _cp2.runid=_t2.runid AND _cp2.mode=_t2.mode AND _cp2.style=_t2.style " ...
        "WHERE _t2.mapid=_t.mapid AND _t2.runid=_t.runid AND _t2.mode=_t.mode AND _t2.style=_t.style AND _cp2.cpnum=_cp.cpnum AND rectime=" ...
            "(SELECT MIN(rectime) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t2.mapid AND runid=_t2.runid AND mode=_t2.mode AND style=_t2.style)" ...
        ") AS cpsrtime" ...

        // Checkpoint's absolute best time.
        ",(SELECT MIN(cptime) " ...
        "FROM "...INF_TABLE_CPTIMES..." " ...
        "WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND cpnum=_cp.cpnum" ...
        ") AS cpbesttime " ...

        "FROM "...INF_TABLE_CPTIMES..." AS _cp INNER JOIN "...INF_TABLE_TIMES..." AS _t ON _cp.uid=_t.uid AND _cp.mapid=_t.mapid AND _cp.runid=_t.runid AND _cp.mode=_t.mode AND _cp.style=_t.style " ...
        "WHERE _t.uid=%i AND _t.mapid=%i AND _t.runid=%i AND _t.mode=%i AND _t.style=%i " ...
        "ORDER BY cpnum",
        uid,
        mapid,
        runid,
        mode,
        style );
    
    
    
    ArrayList array = new ArrayList( PCB_SIZE );
    
    decl data[PCB_SIZE];
    data[PCB_USERID] = GetClientUserId( client );
    data[PCB_UID] = uid;
    data[PCB_MAPID] = mapid;
    data[PCB_RUNID] = runid;
    data[PCB_MODE] = mode;
    data[PCB_STYLE] = style;
    
    array.PushArray( data );
    
    
    SQL_TQuery( db, Thrd_PrintCPTimes, szQuery, array, DBPrio_Normal );
}

stock void DB_PrintTopCPTimes( int client, int mapid, int runid, int mode, int style, const char[] szMap = "" )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    static char szQuery[1200];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT mapname,cpnum" ...

        // Checkpoint's server record time.
        ",(SELECT cptime " ...
        "FROM "...INF_TABLE_TIMES..." AS _t2 INNER JOIN "...INF_TABLE_CPTIMES..." AS _cp2 ON _cp2.uid=_t2.uid AND _cp2.mapid=_t2.mapid AND _cp2.mode=_t2.mode AND _cp2.style=_t2.style " ...
        "WHERE _t2.mapid=_t.mapid AND _t2.runid=_t.runid AND _t2.mode=_t.mode AND _t2.style=_t.style AND _cp2.cpnum=_cp.cpnum AND rectime=" ...
            "(SELECT MIN(rectime) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t2.mapid AND runid=_t2.runid AND mode=_t2.mode AND style=_t2.style) " ...
        "LIMIT 1) AS cpsrtime" ...

        // Checkpoint's absolute best time.
        ",(SELECT MIN(cptime) " ...
        "FROM "...INF_TABLE_CPTIMES..." " ...
        "WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND cpnum=_cp.cpnum" ...
        ") AS cpbesttime " ...
        
        // Player's best.
        ",(SELECT MIN(cptime) " ...
        "FROM "...INF_TABLE_CPTIMES..." " ...
        "WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND cpnum=_cp.cpnum AND uid=%i" ...
        ") AS cppbtime " ...

        "FROM "...INF_TABLE_CPTIMES..." AS _cp INNER JOIN "...INF_TABLE_TIMES..." AS _t ON _cp.uid=_t.uid AND _cp.mapid=_t.mapid AND _cp.mode=_t.mode AND _cp.style=_t.style INNER JOIN "...INF_TABLE_MAPS..." AS _m ON _t.mapid=_m.mapid " ...
        "WHERE _t.mapid=",
        Influx_GetClientId( client ) );
    
    
    if ( mapid <= 0 && szMap[0] != 0 )
    {
        decl String:szSearch[64];
        strcopy( szSearch, sizeof( szSearch ), szMap );
        
        RemoveChars( szSearch, "`'\"%\\" );
        
        ReplaceString( szSearch, sizeof( szSearch ), "_", "\\_" );
        
        
        if ( szSearch[0] != 0 )
        {
#if defined DEBUG_DB
            PrintToServer( INF_DEBUG_PRE..."Searching for a map name: %s", szSearch );
#endif
            Format( szQuery, sizeof( szQuery ), "%s(SELECT mapid FROM "...INF_TABLE_MAPS..." WHERE mapname LIKE '%%%s%%' ESCAPE '%s' LIMIT 1)",
                szQuery,
                szSearch,
                Influx_IsMySQL() ? "\\\\" : "\\" );
        }
    }
    else
    {
        Format( szQuery, sizeof( szQuery ), "%s%i", szQuery, mapid );
    }
    
    
    Format( szQuery, sizeof( szQuery ),  "%s AND _t.runid=%i AND _t.mode=%i AND _t.style=%i GROUP BY cpnum ORDER BY cpnum",
        szQuery,
        runid,
        mode,
        style );
    
    
    static int data[PCBTOP_SIZE];
    ArrayList array = new ArrayList( PCBTOP_SIZE );
    
    data[PCBTOP_USERID] = GetClientUserId( client );
    data[PCBTOP_MODE] = mode;
    data[PCBTOP_STYLE] = style;
    
    array.PushArray( data );
    
    
    SQL_TQuery( db, Thrd_PrintTopCPTimes, szQuery, array, DBPrio_Normal );
}

stock void DB_PrintDeleteCPTimes( int client, int mapid )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    char szQuery[256];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT runid,cpnum,COUNT(*) FROM "...INF_TABLE_CPTIMES..." WHERE mapid=%i GROUP BY runid,cpnum ORDER BY runid,cpnum",
        mapid );
    
    SQL_TQuery( db, Thrd_PrintDeleteCpTimes, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_DeleteCPRecords( int issuer, int mapid, int uid = -1, int runid = -1, int cpnum = -1, int mode = MODE_INVALID, int style = STYLE_INVALID )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    if ( mapid < 1 ) return;
    
    
    char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...INF_TABLE_CPTIMES..." WHERE mapid=%i", mapid );
    
    if ( uid > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND uid=%i", szQuery, uid );
    }
    
    if ( runid > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND runid=%i", szQuery, runid );
    }
    
    if ( cpnum > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND cpnum=%i", szQuery, cpnum );
    }
    
    if ( VALID_MODE( mode ) )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND mode=%i", szQuery, mode );
    }
    
    if ( VALID_STYLE( style ) )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND style=%i", szQuery, style );
    }
    
    
    SQL_TQuery( db, Thrd_Empty, szQuery, issuer ? GetClientUserId( issuer ) : 0, DBPrio_High );
}
