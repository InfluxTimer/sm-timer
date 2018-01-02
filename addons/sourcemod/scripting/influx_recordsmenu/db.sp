#define PRINTREC_QUERY_LIMIT        100
#define PRINTREC_MENU_LIMIT         19 // Radio menus allow for 7 items per page (-2 for last and next page items)


// Threaded callbacks
#include "influx_recordsmenu/db_cb.sp"


stock void DB_PrintMaps( int client )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    static char szQuery[512];
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT " ...
        "mapid," ...
        "mapname," ...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_m.mapid AND runid=%i) AS main_numrecs," ...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_m.mapid AND runid>%i) AS misc_numrecs " ...
        "FROM "...INF_TABLE_MAPS..." AS _m ORDER BY mapname",
        // This pissed me off...
        // WHERE main_numrecs>0 OR misc_numrecs>0
        MAIN_RUN_ID,
        MAIN_RUN_ID );
        
    SQL_TQuery( db, Thrd_PrintMaps, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_PrintRunSelect(
    int client,
    int mapid )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    // TODO: Hasn't been tested with MySQL!
    static char szQuery[512];
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT runid," ...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid) AS numrunrecs " ...
        "FROM "...INF_TABLE_TIMES..." AS _t WHERE mapid=%i GROUP BY runid ORDER BY numrunrecs DESC", mapid );
    
    
    decl data[2];
    ArrayList array = new ArrayList( sizeof( data ) );
    data[0] = GetClientUserId( client );
    data[1] = mapid;
    
    array.PushArray( data );
    
    SQL_TQuery( db, Thrd_PrintRunSelect, szQuery, array, DBPrio_Normal );
}

// Style AND mode select
stock void DB_PrintStyleSelect(
    int client,
    int mapid,
    int runid )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    // TODO: Hasn't been tested with MySQL!
    static char szQuery[512];
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT mode,style," ...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style) AS numrecs " ...
        "FROM "...INF_TABLE_TIMES..." AS _t WHERE mapid=%i AND runid=%i GROUP BY mode,style ORDER BY numrecs DESC", mapid, runid );
    
    
    decl data[3];
    ArrayList array = new ArrayList( sizeof( data ) );
    data[0] = GetClientUserId( client );
    data[1] = mapid;
    data[2] = runid;
    
    array.PushArray( data );
    
    SQL_TQuery( db, Thrd_PrintStyleSelect, szQuery, array, DBPrio_Normal );
}

stock void DB_PrintRecords(
    int client,
    int uid = -1,
    int mapid = -1,
    int runid,
    int mode = -1,
    int style = -1,
    const char[] szName = "",
    const char[] szMap = "",
    int offset = 0,
    int total_records = 0 )
{
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Printing records for %i (%i, %i, %i, %i, %i, '%s', '%s')",
        client,
        uid,
        mapid,
        runid,
        mode,
        style,
        szName,
        szMap );
#endif

    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    

    static char szQuery[1024];
    
    FormatEx( szQuery, sizeof( szQuery ), "SELECT _t.uid,_t.mapid,runid,mode,style,rectime,name,mapname," ...
    "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND rectime<_t.rectime) AS rank " ...
    "FROM "...INF_TABLE_TIMES..." AS _t INNER JOIN "...INF_TABLE_USERS..." AS _u ON _t.uid=_u.uid INNER JOIN "...INF_TABLE_MAPS..." AS _m ON _t.mapid=_m.mapid WHERE runid=%i", runid );
    
    if ( mapid > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND _t.mapid=%i", szQuery, mapid );
    }
    
    if ( uid > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND _t.uid=%i", szQuery, uid );
    }
    
    if ( VALID_MODE( mode ) )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND mode=%i", szQuery, mode );
    }
    
    if ( VALID_STYLE( style ) )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND style=%i", szQuery, style );
    }
    
    
    // TODO: Test this thoroughly
    
    // Map names and some players use underscore, so we'll have to escape them in the query.
    // The backslash is removed here since we use it to escape underscores.
    if ( uid <= 0 && szName[0] != '\0' )
    {
        decl String:szSearch[64];
        strcopy( szSearch, sizeof( szSearch ), szName );
        
        RemoveChars( szSearch, "`'\"\\" );
        
        ReplaceString( szSearch, sizeof( szSearch ), "_", "\\_" );
        ReplaceString( szSearch, sizeof( szSearch ), "%", "\\%" );
        
        
        if ( strlen( szSearch ) )
        {
#if defined DEBUG_DB
            PrintToServer( INF_DEBUG_PRE..."Searching for a player name: %s", szSearch );
#endif
            
            Format( szQuery, sizeof( szQuery ), "%s AND name LIKE '%%%s%%' ESCAPE '%s'",
                szQuery,
                szSearch,
                Influx_IsMySQL() ? "\\\\" : "\\" );
        }
    }
    
    if ( mapid <= 0 && szMap[0] != '\0' )
    {
        decl String:szSearch[64];
        strcopy( szSearch, sizeof( szSearch ), szMap );
        
        RemoveChars( szSearch, "`'\"%\\" );
        
        ReplaceString( szSearch, sizeof( szSearch ), "_", "\\_" );
        
        
        if ( strlen( szSearch ) )
        {
#if defined DEBUG_DB
            PrintToServer( INF_DEBUG_PRE..."Searching for a map name: %s", szSearch );
#endif
            Format( szQuery, sizeof( szQuery ), "%s AND _t.mapid=(SELECT mapid FROM "...INF_TABLE_MAPS..." WHERE mapname LIKE '%%%s%%' ESCAPE '%s' LIMIT 1)",
                szQuery,
                szSearch,
                Influx_IsMySQL() ? "\\\\" : "\\" );
                // MySQL escapes them.
        }
    }
    
    Format( szQuery, sizeof( szQuery ), "%s ORDER BY rectime LIMIT %i", szQuery, PRINTREC_QUERY_LIMIT );
    
    
    if ( offset > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s OFFSET %i", szQuery, offset * PRINTREC_MENU_LIMIT );
    }
    
    
    decl data[PCB_SIZE];
    ArrayList array = new ArrayList( sizeof( data ) );
    data[PCB_USERID] = GetClientUserId( client );
    data[PCB_UID] = uid;
    data[PCB_MAPID] = mapid;
    data[PCB_RUNID] = runid;
    data[PCB_MODE] = mode;
    data[PCB_STYLE] = style;
    data[PCB_OFFSET] = offset;
    data[PCB_TOTALRECORDS] = total_records;
    
    //strcopy( view_as<char>( data[PCB_PLYNAME] ), MAX_PCB_PLYNAME, szName );
    
    array.PushArray( data );
    
    
    
    SQL_TQuery( db, Thrd_PrintRecords, szQuery, array, DBPrio_Normal );
}

stock void DB_PrintRecordInfo( int client, int uid, int mapid, int runid, int mode, int style )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    static char szQuery[700];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT *," ...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style) AS numrecs," ...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND rectime<_t.rectime) AS rank " ...
        "FROM "...INF_TABLE_TIMES..." AS _t INNER JOIN "...INF_TABLE_USERS..." AS _u ON _t.uid=_u.uid WHERE _t.uid=%i AND mapid=%i AND runid=%i AND mode=%i AND style=%i",
        uid,
        mapid,
        runid,
        mode,
        style );
    
    SQL_TQuery( db, Thrd_PrintRecordInfo, szQuery, GetClientUserId( client ), DBPrio_Normal );
}
