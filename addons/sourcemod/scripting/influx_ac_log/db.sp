#include "influx_ac_log/db_cb.sp"


stock void DB_Init()
{
    Handle db = Influx_GetDB();
    
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    SQL_TQuery( db, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_ACLOG_LOG..." (" ...
        "uid INT NOT NULL," ...
        "punishlength INT NOT NULL," ...
        "logdate DATE NOT NULL," ...
        "mapname VARCHAR(127) NOT NULL," ...
        "reason VARCHAR(255) NOT NULL)", _, DBPrio_High );
}

stock bool DB_Log( int client, const char[] szReason, int punishlength )
{
    Handle db = Influx_GetDB();
    
    
    decl String:szMap[128];
    GetCurrentMapSafe( szMap, sizeof( szMap ) );
    
    
    int uid = Influx_GetClientId( client );
    if ( uid < 1 ) return false;
    
    
    decl String:szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "INSERT INTO "...INF_TABLE_ACLOG_LOG..." (uid,punishlength,logdate,mapname,reason) VALUES (%i,%i,CURRENT_DATE,'%s','%s')",
        uid,
        punishlength,
        szMap,
        szReason );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, _, DBPrio_Normal );
    
    return true;
}

stock void DB_PrintClientLogById( int client, int uid )
{
    Handle db = Influx_GetDB();
    
    
    char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT _l.uid,punishlength,logdate,mapname,reason,name FROM "...INF_TABLE_ACLOG_LOG..." AS _l INNER JOIN "...INF_TABLE_USERS..." AS _u ON _l.uid=_u.uid WHERE uid=%i ORDER BY logdate ASC",
        uid );
    
    
    SQL_TQuery( db, Thrd_PrintLog, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_PrintClientLogByName( int client, const char[] szName )
{
    Handle db = Influx_GetDB();
    
    
    char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT _l.uid,punishlength,logdate,mapname,reason,name FROM "...INF_TABLE_ACLOG_LOG..." AS _l INNER JOIN "...INF_TABLE_USERS..." AS _u ON _l.uid=_u.uid WHERE name LIKE '%s' ORDER BY logdate ASC",
        szName );
    
    
    SQL_TQuery( db, Thrd_PrintLog, szQuery, GetClientUserId( client ), DBPrio_Normal );
}