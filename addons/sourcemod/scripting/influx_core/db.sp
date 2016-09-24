// Please note that the queries are designed for SQLite and MySQL compatibility.

Handle g_hDB;
bool g_bIsMySQL;


#define MYSQL_CONFIG_NAME           "influx-mysql"
#define SQLITE_DB_NAME              "influx-sqlite"

#define MAX_DB_NAME_LENGTH          31 * 2 + 1 // 63

#define PRINTREC_QUERY_LIMIT        100
#define PRINTREC_MENU_LIMIT         19 // Radio menus allow for 7 items per page (-2 for last and next page items)


#define INF_DB_CURVERSION           1



// Threaded callbacks
#include "influx_core/db_cb.sp"


stock bool DB_GetEscaped( char[] out, int len, const char[] def = "" )
{
    if ( !SQL_EscapeString( g_hDB, out, out, len ) )
    {
        strcopy( out, len, def );
        
        return false;
    }
    
    return true;
}

stock void DB_Init()
{
    char szError[128], szDriver[32];
    g_bIsMySQL = false;
    
    
    if ( SQL_CheckConfig( MYSQL_CONFIG_NAME ) )
    {
        g_bIsMySQL = true;
        
        strcopy( szDriver, sizeof( szDriver ), "MySQL" );
        
        
        g_hDB = SQL_Connect( MYSQL_CONFIG_NAME, true, szError, sizeof( szError ) );
    }
    else
    {
        strcopy( szDriver, sizeof( szDriver ), "SQLite" );
        
        
        KeyValues kv = CreateKeyValues( "" );
        kv.SetString( "driver", "sqlite" );
        kv.SetString( "database", SQLITE_DB_NAME );
        
        g_hDB = SQL_ConnectCustom( kv, szError, sizeof( szError ), false );
        
        delete kv;
    }
    
    if ( g_hDB == null )
    {
        SetFailState( INF_CON_PRE..."Unable to establish connection to %s database! (Error: %s)",
            szDriver,
            szError );
    }
    
    
    PrintToServer( INF_CON_PRE..."Established connection to %s database!", szDriver );
    
    
    if ( g_bIsMySQL )
    {
        SQL_TQuery( g_hDB, Thrd_Empty,
            "CREATE TABLE IF NOT EXISTS "...INF_TABLE_USERS..." (" ...
            "uid INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY," ... // Only change
            "steamid VARCHAR(63) NOT NULL UNIQUE," ...
            "name VARCHAR(62) DEFAULT 'N/A')", _, DBPrio_High );
        
        SQL_TQuery( g_hDB, Thrd_Empty,
            "CREATE TABLE IF NOT EXISTS "...INF_TABLE_MAPS..." (" ...
            "mapid INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY," ... // Only change
            "mapname VARCHAR(127) NOT NULL UNIQUE)", _, DBPrio_High );
    }
    else
    {
        // NOTE: Must be INTEGER PRIMARY KEY.
        // https://www.sqlite.org/autoinc.html
        SQL_TQuery( g_hDB, Thrd_Empty,
            "CREATE TABLE IF NOT EXISTS "...INF_TABLE_USERS..." (" ...
            "uid INTEGER PRIMARY KEY," ...
            "steamid VARCHAR(63) NOT NULL UNIQUE," ...
            "name VARCHAR(62) DEFAULT 'N/A')", _, DBPrio_High );
        
        SQL_TQuery( g_hDB, Thrd_Empty,
            "CREATE TABLE IF NOT EXISTS "...INF_TABLE_MAPS..." (" ...
            "mapid INTEGER PRIMARY KEY," ...
            "mapname VARCHAR(127) NOT NULL UNIQUE)", _, DBPrio_High );
    }
    
    
    SQL_TQuery( g_hDB, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_TIMES..." (" ...
        "uid INT NOT NULL," ...
        "mapid INT NOT NULL," ...
        "runid INT NOT NULL," ...
        "mode INT NOT NULL," ...
        "style INT NOT NULL," ...
        "rectime REAL NOT NULL," ...
        "recdate DATE NOT NULL," ...
        "PRIMARY KEY(uid,mapid,runid,mode,style))", _, DBPrio_High );
    
    
    
    // Track our database's version since it'll become handy if we ever need to update the database structure.
    SQL_TQuery( g_hDB, Thrd_Empty,
        "CREATE TABLE IF NOT EXISTS "...INF_TABLE_DBVER..." (id INT NOT NULL UNIQUE, version INT NOT NULL)", _, DBPrio_High );
    
    
    DB_CheckVersion();
}

stock void DB_CheckVersion()
{
    SQL_TQuery( g_hDB, Thrd_CheckVersion, "SELECT version FROM "...INF_TABLE_DBVER..." WHERE id=0", _, DBPrio_High );
}

stock bool DB_Update( int ver )
{
#if defined DEBUG_DB_VER
    PrintToServer( INF_DEBUG_PRE..."Checking database version %i. Current: %i", ver, INF_DB_CURVERSION );
#endif

    if ( ver == INF_DB_CURVERSION ) return false;
    
    
    return false;
}

stock void DB_InitMap()
{
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT mapid FROM "...INF_TABLE_MAPS..." WHERE mapname='%s'", g_szCurrentMap );
    
    SQL_TQuery( g_hDB, Thrd_GetMapId, szQuery, _, DBPrio_High );
}

stock void DB_InitRecords()
{
    if ( g_iCurMapId <= 0 )
    {
        SetFailState( INF_CON_PRE..."Couldn't init %s records. Faulty map id.", g_szCurrentMap );
    }
    
    
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT " ...
        "uid," ...
        "runid," ...
        "mode," ...
        "style," ...
        "rectime," ...
        "name " ...
        "FROM "...INF_TABLE_TIMES..." NATURAL JOIN "...INF_TABLE_USERS..." WHERE mapid=%i " ...
        "GROUP BY runid,mode,style " ...
        "ORDER BY MIN(rectime)",
        g_iCurMapId );
    
    SQL_TQuery( g_hDB, Thrd_GetBestRecords, szQuery, _, DBPrio_High );
    
    
    /*FormatEx( szQuery, sizeof( szQuery ), "SELECT " ...
        "runid," ...
        "mode," ...
        "style," ...
        "COUNT(runid) " ...
        "FROM "...INF_TABLE_TIMES..." WHERE mapid=%i " ...
        "GROUP BY runid,mode,style",
        g_iCurMapId );
    
    SQL_TQuery( g_hDB, Thrd_GetNumRecords, szQuery, _, DBPrio_High );*/
}

stock void DB_InitClient( int client )
{
    DB_InitClient_Cb( client, Thrd_GetClientId );
}

stock void DB_InitClient_Cb( int client, SQLTCallback cb )
{
#if defined AUTH_BYNAME
    decl String:szName[MAX_NAME_LENGTH];
    if ( !GetClientName( client, szName, sizeof( szName ) ) ) return;
    
    
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT uid FROM "...INF_TABLE_USERS..." WHERE name='%s'", szName );
    
    PrintToServer( INF_DEBUG_PRE..."Searching for name %s", szName );
#else
    decl String:szSteam[64];
    if ( !Inf_GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return;
    
    
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT uid FROM "...INF_TABLE_USERS..." WHERE steamid='%s'", szSteam );
#endif
    
    SQL_TQuery( g_hDB, cb, szQuery, GetClientUserId( client ), DBPrio_Low );
}

stock void DB_InitClientTimes( int client )
{
    if ( g_iClientId[client] <= 0 ) return;
    
    
    decl String:szQuery[192];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT runid,mode,style,rectime FROM "...INF_TABLE_TIMES..." WHERE mapid=%i AND uid=%i ORDER BY runid", g_iCurMapId, g_iClientId[client] );
    
    SQL_TQuery( g_hDB, Thrd_GetClientRecords, szQuery, GetClientUserId( client ), DBPrio_High );
}

stock void DB_UpdateClient( int client )
{
    if ( g_iClientId[client] <= 0 ) return;
    
    
    decl String:szName[MAX_DB_NAME_LENGTH];
    if ( !GetClientName( client, szName, sizeof( szName ) ) )
    {
        strcopy( szName, sizeof( szName ), "N/A" );
    }
    else
    {
        RemoveChars( szName, "`'\"" );
        
        DB_GetEscaped( szName, sizeof( szName ), "N/A" ); // Just in case.
    }
    
    decl String:szQuery[128];
    FormatEx( szQuery, sizeof( szQuery ), "UPDATE "...INF_TABLE_USERS..." SET name='%s' WHERE uid=%i",
        szName,
        g_iClientId[client] );
    
    SQL_TQuery( g_hDB, Thrd_Empty, szQuery, _, DBPrio_Low );
}

stock void DB_InsertRecord( int client, int uid, int runid, int mode, int style, float time )
{
    if ( g_iCurMapId <= 0 )
    {
        LogError( INF_CON_PRE..."Can't insert record for '%N' because map's id is invalid!", client );
        return;
    }
    
    if ( g_iClientId[client] <= 0 )
    {
        LogError( INF_CON_PRE..."Can't insert record for '%N' because their id is invalid!", client );
        return;
    }
    
    
    decl String:szQuery[512];
    FormatEx( szQuery, sizeof( szQuery ), "REPLACE INTO "...INF_TABLE_TIMES..." " ...
    "(uid,mapid,runid,mode,style,rectime,recdate) VALUES (%i,%i,%i,%i,%i,%f,CURRENT_DATE)",
        uid,
        g_iCurMapId,
        runid,
        mode,
        style,
        time );
    
    SQL_TQuery( g_hDB, Thrd_Empty, szQuery, GetClientUserId( client ), DBPrio_High );
}

stock void DB_PrintMaps( int client )
{
    decl String:szQuery[512];
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
        
    SQL_TQuery( g_hDB, Thrd_PrintMaps, szQuery, GetClientUserId( client ), DBPrio_Low );
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

    static char szQuery[1024];
    
    FormatEx( szQuery, sizeof( szQuery ), "SELECT uid,mapid,runid,mode,style,rectime,name,mapname," ...
    "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND rectime<_t.rectime) AS rank " ...
    "FROM "...INF_TABLE_TIMES..." AS _t NATURAL JOIN "...INF_TABLE_USERS..." NATURAL JOIN "...INF_TABLE_MAPS..." WHERE runid=%i", runid );
    
    if ( mapid > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND mapid=%i", szQuery, mapid );
    }
    
    if ( uid > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND uid=%i", szQuery, uid );
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
            // AND uid=(SELECT uid FROM "...INF_TABLE_USERS..." WHERE name LIKE '%%%s%%' ESCAPE '\\' LIMIT 1)
            Format( szQuery, sizeof( szQuery ), "%s AND name LIKE '%%%s%%' ESCAPE '\\'", szQuery, szSearch );
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
            Format( szQuery, sizeof( szQuery ), "%s AND mapid=(SELECT mapid FROM "...INF_TABLE_MAPS..." WHERE mapname LIKE '%%%s%%' ESCAPE '\\' LIMIT 1)", szQuery, szSearch );
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
    
    
    
    SQL_TQuery( g_hDB, Thrd_PrintRecords, szQuery, array, DBPrio_Low );
}

stock void DB_PrintRecordInfo( int client, int uid, int mapid, int runid, int mode, int style )
{
    static char szQuery[700];
    
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT *,"...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style) AS numrecs,"...
        "(SELECT COUNT(*) FROM "...INF_TABLE_TIMES..." WHERE mapid=_t.mapid AND runid=_t.runid AND mode=_t.mode AND style=_t.style AND rectime<_t.rectime) AS rank "...
        "FROM "...INF_TABLE_TIMES..." AS _t NATURAL JOIN "...INF_TABLE_USERS..." WHERE uid=%i AND mapid=%i AND runid=%i AND mode=%i AND style=%i",
        uid,
        mapid,
        runid,
        mode,
        style );
    
    SQL_TQuery( g_hDB, Thrd_PrintRecordInfo, szQuery, GetClientUserId( client ), DBPrio_Low );
}

stock void DB_DeleteRecord( int issuer, int uid, int mapid, int runid, int mode, int style )
{
    decl String:szQuery[300];
    
    int irun = FindRunById( runid );
    
    
    if ( irun != -1 && g_iCurMapId == mapid )
    {
        for ( int client = 1; client <= MaxClients; client++ )
        {
            if ( !IsClientInGame( client ) ) continue
            
            if ( IsFakeClient( client ) ) continue;
            
            if ( g_iClientId[client] != uid ) continue;
            
            
            float prevtime = GetClientRunTime( irun, client, mode, style );
            
            if ( prevtime != INVALID_RUN_TIME )
            {
                SetClientRunTime( irun, client, mode, style, INVALID_RUN_TIME );
                
                decl String:szMode[MAX_MODE_NAME];
                decl String:szStyle[MAX_STYLE_NAME];
                decl String:szTime[10];
                
                Inf_FormatSeconds( prevtime, szTime, sizeof( szTime ) );
                
                GetModeName( mode, szMode, sizeof( szMode ) );
                GetStyleName( style, szStyle, sizeof( szStyle ) );
                
                Influx_PrintToChat( _, client, "Your %s %s (%s) run has been deleted!", szStyle, szMode, szTime );
                
                if (runid == g_iRunId[client]
                &&  mode == g_iModeId[client]
                &&  style == g_iStyleId[client])
                {
                    UpdateClientCachedByIndex( client, irun );
                }
            }
            
            break;
        }
        
        // Find new best.
        if ( uid == GetRunBestTimeId( irun, mode, style ) )
        {
            FormatEx( szQuery, sizeof( szQuery ), "SELECT " ...
                "uid," ...
                "runid," ...
                "mode," ...
                "style," ...
                "rectime," ...
                "name " ...
                "FROM "...INF_TABLE_TIMES..." NATURAL JOIN "...INF_TABLE_USERS..." " ...
                "WHERE uid!=%i AND mapid=%i AND runid=%i AND mode=%i AND style=%i " ...
                "GROUP BY runid,mode,style " ...
                "ORDER BY MIN(rectime)",
                uid,
                mapid,
                runid,
                mode,
                style );
            
            SQL_TQuery( g_hDB, Thrd_GetBestRecords, szQuery, _, DBPrio_High );
            
            // Reset our time in the meantime.
            // It is technically possible to get a record while we are waiting for the database to respond.
            SetRunBestTime( irun, mode, style, INVALID_RUN_TIME );
            
            UpdateAllClientsCached( runid, mode, style );
        }
    }
    
    
    FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...INF_TABLE_TIMES..." WHERE uid=%i AND mapid=%i AND runid=%i AND mode=%i AND style=%i",
        uid,
        mapid,
        runid,
        mode,
        style );
    
    SQL_TQuery( g_hDB, Thrd_Empty, szQuery, issuer ? GetClientUserId( issuer ) : 0, DBPrio_Low );
}

stock void DB_PrintDeleteRecords( int client, int mapid )
{
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT " ...
        "runid," ...
        "COUNT(*) AS num " ...
        "FROM "...INF_TABLE_TIMES..." " ...
        "WHERE mapid=%i " ...
        "GROUP BY runid "...
        "ORDER BY num DESC",
        mapid );
    
    SQL_TQuery( g_hDB, Thrd_PrintDeleteRecords, szQuery, GetClientUserId( client ), DBPrio_Low );
}

stock void DB_DeleteMapRecords( int issuer, int mapid, int runid = -1 )
{
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...INF_TABLE_TIMES..." WHERE mapid=%i", mapid );
        
    if ( runid != -1 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND runid=%i", szQuery, runid );
    }
    
    SQL_TQuery( g_hDB, Thrd_Empty, szQuery, issuer ? GetClientUserId( issuer ) : 0, DBPrio_Low );
}