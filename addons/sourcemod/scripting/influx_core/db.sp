// Please note that the queries are designed for SQLite and MySQL compatibility.

Handle g_hDB;
bool g_bIsMySQL;
char g_szDriver[32];


#define MYSQL_CONFIG_NAME           "influx-mysql"
#define SQLITE_DB_NAME              "influx-sqlite"

#define MAX_DB_NAME_LENGTH          31 * 2 + 1 // 63

#define INF_DB_CURVERSION           2



// Threaded callbacks recide in db_cb.sp
// Queries written as preprocessors are in db_sql_queries.sp



stock bool DB_UpdateQuery( int ver, const char[] szQuery )
{
    if ( !SQL_FastQuery( g_hDB, szQuery ) )
    {
        char szError[256];
        SQL_GetError( g_hDB, szError, sizeof( szError ) );
        
        LogError( INF_CON_PRE..."Couldn't update database from version %i to %i! Error: %s", ver, INF_DB_CURVERSION, szError );
        
        return false;
    }
    
    return true;
}

stock void DB_Init()
{
    char szError[1024];
    g_bIsMySQL = false;
    Database db = null;
    
    
    // TODO: Threaded connection?
    if ( SQL_CheckConfig( MYSQL_CONFIG_NAME ) )
    {
        db = SQL_Connect( MYSQL_CONFIG_NAME, true, szError, sizeof( szError ) );
    }
    else
    {
        KeyValues kv = CreateKeyValues( "" );
        kv.SetString( "driver", "sqlite" );
        kv.SetString( "database", SQLITE_DB_NAME );
        
        db = SQL_ConnectCustom( kv, szError, sizeof( szError ), true );
        
        delete kv;
    }
    
    if ( db == null )
    {
        SetFailState( INF_CON_PRE..."Unable to establish connection to database! (Error: %s)",
            szError );
    }
    
    
    // Determine what kind of database we're using by checking the name.
    db.Driver.GetProduct( g_szDriver, sizeof( g_szDriver ) );
    char szIdent[64];
    db.Driver.GetIdentifier( szIdent, sizeof( szIdent ) );
    
    g_bIsMySQL = StrContains( szIdent, "mysql", false ) != -1;
    
    // SM only supports MySQL & SQLite currently, but you never know.
    if ( !g_bIsMySQL && StrContains( szIdent, "sqlite", false ) == -1 )
    {
        LogError( INF_CON_PRE..."Possibly invalid SQL driver %s (Identifier: %s)! Assuming SQLite.", g_szDriver, szIdent );
    }
    
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Driver: %s | Identifier: %s | Is MySQL: %i", g_szDriver, szIdent, g_bIsMySQL );
#endif
    
    
    g_hDB = db;
    
    
    DB_OnConnected();
}

stock void DB_OnConnected()
{
    PrintToServer( INF_CON_PRE..."Established connection to %s database!", g_szDriver );
    

    // Set the charset to utfmb4 for 4 byte utf-8 characters.
    // SQLite should automatically use whatever UTF-8 that support 4 byte chars.
    if ( g_bIsMySQL && !SQL_SetCharset( g_hDB, "utf8mb4" ) )
    {
       LogError( INF_CON_PRE..."Failed to set character set to 'utf8mb4'! Some player names may result in errors." );
    }

    
    DB_InitTables();
    
    
    // Tell other plugins we're ready!
    //OnConnectedDB();
}

stock void DB_InitTables()
{
#if defined DISABLE_CREATE_SQL_TABLES
    DB_CheckVersion();
    DISABLE_CREATE_SQL_TABLES
#endif
	
    if ( g_bIsMySQL )
    {
        SQL_TQuery( g_hDB, Thrd_Empty, QUERY_CREATETABLE_USERS_MYSQL, _, DBPrio_High );
        
        SQL_TQuery( g_hDB, Thrd_Empty, QUERY_CREATETABLE_MAPS_MYSQL, _, DBPrio_High );
    }
    else
    {
        SQL_TQuery( g_hDB, Thrd_Empty, QUERY_CREATETABLE_USERS_SQLITE, _, DBPrio_High );
        
        SQL_TQuery( g_hDB, Thrd_Empty, QUERY_CREATETABLE_MAPS_SQLITE, _, DBPrio_High );
    }
    
    
    SQL_TQuery( g_hDB, Thrd_Empty, QUERY_CREATETABLE_TIMES, _, DBPrio_High );
    
    
    SQL_TQuery( g_hDB, Thrd_Empty, QUERY_CREATETABLE_RUNS, _, DBPrio_High );
    
    
    
    // Track our database's version since it'll become handy if we ever need to update the database structure.
    SQL_TQuery( g_hDB, Thrd_Empty, QUERY_CREATETABLE_DBVER, _, DBPrio_High );
    
    
    DB_CheckVersion();
}

stock void DB_CheckVersion()
{
    SQL_TQuery( g_hDB, Thrd_CheckVersion, "SELECT version FROM "...INF_TABLE_DBVER..." WHERE id=0", _, DBPrio_High );
}

stock void DB_Update( int ver )
{
#if defined DEBUG_DB_VER
    PrintToServer( INF_DEBUG_PRE..."Checking database version %i. Current: %i", ver, INF_DB_CURVERSION );
#endif

    if ( ver >= INF_DB_CURVERSION )
    {
        PrintToServer( INF_CON_PRE..."Your database is already up-to-date!" );
        return;
    }
    
    
    
    SQL_LockDatabase( g_hDB );
    
    bool successful = DB_PerformUpdateQueries( ver );
    
    SQL_UnlockDatabase( g_hDB );
    
    
    if ( successful )
    {
        PrintToServer( INF_CON_PRE..."Successfully updated database!" );
    }
    else
    {
        PrintToServer( INF_CON_PRE..."Something went wrong!" );
    }
}

stock bool DB_PerformUpdateQueries( int ver )
{
    char szQuery[1024];
    char szTempTable[64];
    
    
    if ( ver == 1 )
    {
        FormatEx( szTempTable, sizeof( szTempTable ), "_"...INF_TABLE_USERS..."%i", ver );
        
        
        FormatEx( szQuery, sizeof( szQuery ), "ALTER TABLE "...INF_TABLE_USERS..." RENAME TO %s", szTempTable );
        if ( !DB_UpdateQuery( ver, szQuery ) ) return false;
        
        
        PrintToServer( INF_CON_PRE..."Renamed old users table to %s. If everything goes smoothly you may want to delete it to free resources.", szTempTable );
        
        
        if ( !DB_UpdateQuery( ver, g_bIsMySQL ? QUERY_CREATETABLE_USERS_MYSQL : QUERY_CREATETABLE_USERS_SQLITE ) ) return false;
        
        
        PrintToServer( INF_CON_PRE..."Created new version of users table." );
        
        
        
        FormatEx( szQuery, sizeof( szQuery ),
            "INSERT INTO "...INF_TABLE_USERS..." (uid,steamid,name,joindate) SELECT uid,steamid,name,(SELECT COALESCE(MIN(recdate),CURRENT_DATE) FROM "...INF_TABLE_TIMES..." WHERE uid=_u.uid) FROM %s AS _u",
            szTempTable );
            
        if ( !DB_UpdateQuery( ver, szQuery ) ) return false;
        
        
        PrintToServer( INF_CON_PRE..."Inserted all data from %s to new users table", szTempTable );
        
        
        FormatEx( szQuery, sizeof( szQuery ), "REPLACE INTO "...INF_TABLE_DBVER..." (id,version) VALUES (0,%i)", INF_DB_CURVERSION );
        if ( !DB_UpdateQuery( ver, szQuery ) ) return false;
        
        
        PrintToServer( INF_CON_PRE..."Updated db version.", szTempTable );
        
        
        return true;
    }
    
    return false;
}

stock void DB_InitMap()
{
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT mapid FROM "...INF_TABLE_MAPS..." WHERE mapname='%s'", g_szCurrentMap );
    
    SQL_TQuery( g_hDB, Thrd_GetMapId, szQuery, _, DBPrio_High );
}

stock void FormatWhereClause( char[] sz, int len, const char[] table, int runid, int mode, int style )
{
    if ( runid > 0 ) FormatEx( sz, len, " AND %srunid=%i", table, runid );
    if ( VALID_MODE( mode ) ) Format( sz, len, "%s AND %smode=%i", sz, table, mode );
    if ( VALID_STYLE( style ) ) Format( sz, len, "%s AND %sstyle=%i", sz, table, style );
}

stock void DB_InitRecords( int runid = -1, int mode = MODE_INVALID, int style = STYLE_INVALID )
{
    if ( g_iCurMapId <= 0 )
    {
        SetFailState( INF_CON_PRE..."Couldn't init %s records. Faulty map id.", g_szCurrentMap );
    }
    
    
    char szWhere[128];
    char szWhere2[128];
    
    FormatWhereClause( szWhere, sizeof( szWhere ), "", runid, mode, style );
    FormatWhereClause( szWhere2, sizeof( szWhere2 ), "_t.", runid, mode, style );
    
    
    
    char szQuery[700];
    FormatEx( szQuery, sizeof( szQuery ), QUERY_INIT_RECORDS,
        g_iCurMapId, szWhere,
        g_iCurMapId, szWhere2 );
    
    SQL_TQuery( g_hDB, Thrd_GetBestRecords_2, szQuery, 1, DBPrio_Normal );
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
    if ( !Inf_GetClientSteam( client, szSteam, sizeof( szSteam ) ) )
    {
        LogError( INF_CON_PRE..."Failed to retrieve %N's Steam Id to init their data!",
            client );
        return;
    }
    
    
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT uid FROM "...INF_TABLE_USERS..." WHERE steamid='%s'", szSteam );
#endif
    
    SQL_TQuery( g_hDB, cb, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_InitClientTimes( int client )
{
    if ( g_iClientId[client] <= 0 ) return;
    
    
    decl String:szQuery[192];
    FormatEx( szQuery, sizeof( szQuery ), QUERY_INIT_PLAYER_RECORDS, g_iCurMapId, g_iClientId[client] );
    
    SQL_TQuery( g_hDB, Thrd_GetClientRecords, szQuery, GetClientUserId( client ), DBPrio_High );
}

stock void DB_UpdateClient( int client )
{
    if ( g_iClientId[client] <= 0 ) return;
    
    
    static char szName[MAX_DB_NAME_LENGTH];
    static char szQuery[256];


    if ( !DB_GetClientNameSafe( client, szName, sizeof( szName ) ) )
    {
        LogError( INF_CON_PRE..."Failed to update player's '%N' name in database!", client );
        return;
    }
    

    SQL_FormatQuery( g_hDB, szQuery, sizeof( szQuery ), "UPDATE "...INF_TABLE_USERS..." SET name='%s' WHERE uid=%i",
        szName,
        g_iClientId[client] );
    
    SQL_TQuery( g_hDB, Thrd_Empty, szQuery, _, DBPrio_Normal );


#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Updated player's %i name to '%s'", client, szName );
#endif
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
    
    SQL_TQuery( g_hDB, Thrd_Empty, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_PrintDeleteRecords( int client, int mapid )
{
    Handle db = Influx_GetDB();
    if ( db == null ) SetFailState( INF_CON_PRE..."Couldn't retrieve database handle!" );
    
    
    decl String:szQuery[256];
    FormatEx( szQuery, sizeof( szQuery ), "SELECT " ...
        "runid," ...
        "COUNT(*) AS num " ...
        "FROM "...INF_TABLE_TIMES..." " ...
        "WHERE mapid=%i " ...
        "GROUP BY runid "...
        "ORDER BY num DESC",
        mapid );
    
    SQL_TQuery( db, Thrd_PrintDeleteRecords, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

stock void DB_DeleteRecords( int issuer, int mapid, int uid = -1, int runid = -1, int mode = MODE_INVALID, int style = STYLE_INVALID )
{
    if ( mapid < 1 ) return;
    
    
    char szQuery[512];
    
    FormatEx( szQuery, sizeof( szQuery ), "DELETE FROM "...INF_TABLE_TIMES..." WHERE mapid=%i", mapid );
    
    if ( uid > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND uid=%i", szQuery, uid );
    }
    
    if ( runid > 0 )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND runid=%i", szQuery, runid );
    }
    
    if ( VALID_MODE( mode ) )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND mode=%i", szQuery, mode );
    }
    
    if ( VALID_STYLE( style ) )
    {
        Format( szQuery, sizeof( szQuery ), "%s AND style=%i", szQuery, style );
    }
    
    
    SQL_TQuery( g_hDB, Thrd_Empty, szQuery, issuer ? GetClientUserId( issuer ) : 0, DBPrio_Normal );
    
    
    Call_StartForward( g_hForward_OnRecordRemoved );
    Call_PushCell( issuer );
    Call_PushCell( uid );
    Call_PushCell( mapid );
    Call_PushCell( runid );
    Call_PushCell( mode );
    Call_PushCell( style );
    Call_Finish();
}

stock void DB_LoadRuns()
{
    decl String:szQuery[192];
    FormatEx( szQuery, sizeof( szQuery ),
        "SELECT " ...
        "runid,rundata " ...
        "FROM "...INF_TABLE_RUNS..." " ...
        "WHERE mapid=%i " ...
        "ORDER BY runid ASC",
        g_iCurMapId );
        
    SQL_TQuery( g_hDB, Thrd_GetRuns, szQuery, _, DBPrio_High );
}

stock void DB_RemoveRun( int runid )
{
    decl String:szQuery[192];
    FormatEx( szQuery, sizeof( szQuery ),
        "DELETE FROM "...INF_TABLE_RUNS..." WHERE mapid=%i AND runid=%i",
        g_iCurMapId,
        runid );
        
    SQL_TQuery( g_hDB, Thrd_Empty, szQuery, _, DBPrio_Normal );
}

stock int DB_SaveRuns( ArrayList kvs )
{
    static char szQuery[2048];
    
    decl String:szRunData[1024];
    
    int num = 0;
    
    for ( int i = 0; i < kvs.Length; i++ )
    {
        KeyValues rundata = view_as<KeyValues>( kvs.Get( i, 0 ) );
        int runid = kvs.Get( i, 1 );
        
        
        rundata.ExportToString( szRunData, sizeof( szRunData ) );
        
#if defined DEBUG_DB_RUN
        PrintToServer( INF_DEBUG_PRE..."Saving run data:\n%s", szRunData );
#endif
        
        if ( !Inf_DB_GetEscaped( g_hDB, szRunData, sizeof( szRunData ), "" ) )
        {
            LogError( INF_CON_PRE..."Failed to escape run data string! (%i)", runid );
            continue;
        }
        
#if defined DEBUG_DB_RUN
        PrintToServer( INF_DEBUG_PRE..."Escaped:\n%s", szRunData );
#endif
        
        
        FormatEx(
            szQuery,
            sizeof( szQuery ),
            "REPLACE INTO "...INF_TABLE_RUNS..." (mapid,runid,rundata) VALUES (%i,%i,'%s')",
            g_iCurMapId,
            runid,
            szRunData );
            
        SQL_TQuery( g_hDB, Thrd_Empty, szQuery, _, DBPrio_Normal );
        
        ++num;
    }
    
    return num;
}

stock bool DB_GetClientNameSafe( int client, char[] szName, int len )
{
    if ( !GetClientName( client, szName, len ) )
    {
        szName[0] = 0;
    }
    else
    {
        RemoveChars( szName, "`'\"" );
        
        Inf_DB_GetEscaped( g_hDB, szName, len, "" );
    }

    return szName[0] != 0;
}
