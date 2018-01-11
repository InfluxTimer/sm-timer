#include "influx_ac_log/db_cb.sp"


stock void DB_Init()
{
    Handle db = Influx_GetDB();
    
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    SQL_TQuery( db, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_ACLOG_LOG..." (" ...
        "uid INT NOT NULL," ...
        "punishlength INT NOT NULL," ...
        "notifyadmin INT NOT NULL," ...
        "logdate DATE NOT NULL," ...
        "mapname VARCHAR(63) NOT NULL," ...
        "reasonid VARCHAR(127) NOT NULL," ...
        "reason VARCHAR(255) NOT NULL)", _, DBPrio_High );
        
    SQL_TQuery( db, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_ACLOG_NOTIFY..." (" ...
        "uid INT NOT NULL," ...
        "logdate DATE NOT NULL," ...
        "unseen INT NOT NULL," ...
        "PRIMARY KEY(uid))", _, DBPrio_High );
}

stock bool DB_Log( int client, const char[] szReasonId, const char[] szReason, int punishlength, bool bNotifyAdmin, bool bUnseen )
{
    Handle db = Influx_GetDB();
    
    
    char szMap[128];
    GetCurrentMapSafe( szMap, sizeof( szMap ) );
    
    
    int uid = Influx_GetClientId( client );
    if ( uid < 1 ) return false;
    
    
    char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "INSERT INTO "...INF_TABLE_ACLOG_LOG..." (uid,punishlength,notifyadmin,logdate,mapname,reasonid,reason) VALUES (%i,%i,%i,CURRENT_DATE,'%s','%s','%s')",
        uid,
        punishlength,
        bNotifyAdmin ? 1 : 0,
        szMap,
        szReasonId,
        szReason );
    
    SQL_TQuery( db, Thrd_Empty, szQuery, _, DBPrio_Normal );
    
    
    if ( bUnseen )
    {
        FormatEx( szQuery, sizeof( szQuery ),
            "REPLACE INTO "...INF_TABLE_ACLOG_NOTIFY..." (uid,logdate,unseen) VALUES (%i,CURRENT_DATE,1)",
            uid );
        
        SQL_TQuery( db, Thrd_Empty, szQuery, _, DBPrio_Normal );
    }

    
    return true;
}

stock void DB_PrintUnseenNum( int client )
{
    Handle db = Influx_GetDB();
    
    
    char szQuery[256];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT COUNT(*) FROM "...INF_TABLE_ACLOG_NOTIFY..." WHERE unseen=1" );
    
    
    SQL_TQuery( db, Thrd_PrintUnseenNum, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_PrintClientLogById( int client, int uid )
{
    Handle db = Influx_GetDB();
    
    
    char szQuery[256];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT _l.uid,punishlength,logdate,mapname,reason,name FROM "...INF_TABLE_ACLOG_LOG..." AS _l INNER JOIN "...INF_TABLE_USERS..." AS _u ON _l.uid=_u.uid WHERE uid=%i ORDER BY logdate ASC",
        uid );
    
    
    SQL_TQuery( db, Thrd_PrintLog, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_PrintClientLogByName( int client, const char[] szName )
{
    Handle db = Influx_GetDB();
    
    
    char szSearch[64];
    strcopy( szSearch, sizeof( szSearch ), szName );
    
    RemoveChars( szSearch, "`'\"\\" );
    
    ReplaceString( szSearch, sizeof( szSearch ), "_", "\\_" );
    ReplaceString( szSearch, sizeof( szSearch ), "%", "\\%" );
    
    if ( szSearch[0] == 0 ) return;
    
    
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Searching for name '%s'!", szSearch );
#endif
    
    char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT _l.uid,punishlength,logdate,mapname,reason,name FROM "...INF_TABLE_ACLOG_LOG..." AS _l INNER JOIN "...INF_TABLE_USERS..." AS _u ON _l.uid=_u.uid WHERE name LIKE '%s' ESCAPE '%s' ORDER BY logdate ASC",
        szSearch,
        Influx_IsMySQL() ? "\\\\" : "\\" );
    
    
    SQL_TQuery( db, Thrd_PrintLog, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_PrintUnseenLog( int client )
{
    Handle db = Influx_GetDB();
    
    
    //char szQuery[512];
    
    SQL_TQuery( db, Thrd_PrintLog,
        "SELECT _l.uid,punishlength,_l.logdate,mapname,reason,name FROM "...INF_TABLE_ACLOG_LOG..." AS _l " ...
        "INNER JOIN "...INF_TABLE_USERS..." AS _u ON _l.uid=_u.uid " ...
        "INNER JOIN "...INF_TABLE_ACLOG_NOTIFY..." AS _n ON _l.uid=_n.uid WHERE notifyadmin=1 AND unseen=1 ORDER BY _n.uid,_n.logdate ASC",
        GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_MarkAllSeen( int issuer )
{
    Handle db = Influx_GetDB();
    
    
    SQL_TQuery( db, Thrd_Empty,
        "UPDATE "...INF_TABLE_ACLOG_NOTIFY..." SET unseen=0 WHERE unseen=1",
        issuer ? GetClientUserId( issuer ) : 0, DBPrio_Normal );
}