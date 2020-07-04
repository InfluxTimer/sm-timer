public void Thrd_Empty( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "inserting data into database", client ? GetClientOfUserId( client ) : 0, "An error occurred while saving your data!" );
    }
}

public void Thrd_CheckVersion( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "getting database version" );
        return;
    }
    
    
    if ( SQL_GetRowCount( res ) && SQL_FetchRow( res ) )
    {
        g_iCurDBVersion = SQL_FetchInt( res, 0 );
        
        if ( g_iCurDBVersion < INF_DB_CURVERSION )
        {
            Inf_Warning( 6, "Your database is outdated, please run the command 'sm_updateinfluxdb' through server console! (Current version: %i | Should be: %i)", g_iCurDBVersion, INF_DB_CURVERSION );
        }
        
        return;
    }
    
    
#if defined DEBUG_DB_VER
    PrintToServer( INF_DEBUG_PRE..."No database version found, adding new one." );
#endif
    
    // Update version in the database.
    char szQuery[192];
    FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...INF_TABLE_DBVER..." (id,version) VALUES (0,%i)", INF_DB_CURVERSION );
    
    SQL_TQuery( g_hDB, Thrd_Empty, szQuery, _, DBPrio_High );
}

public void Thrd_GetMapId( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "getting map id" );
        return;
    }
    
    
    if ( SQL_FetchRow( res ) )
    {
        g_iCurMapId = SQL_FetchInt( res, 0 );
        
        // We've retrieved the map id, send forward.
        PrintToServer( INF_CON_PRE..."Retrieved map id %i", g_iCurMapId );
        
        SendMapIdRetrieved();
        
        
        DB_InitRecords();
    }
    else
    {
        // We've already attempted to create a new map id!
        if ( g_bNewMapId )
        {
            // HACK: Can't set fail state in CS:GO, will call this twice for some reason.
            //SetFailState( INF_CON_PRE..."Couldn't create new id for map '%s'!", g_szCurrentMap );
#if defined DEBUG_DB_MAPID
            PrintToServer( INF_DEBUG_PRE..."Map '%s' has already been inserted into the database! Current id: %i", g_szCurrentMap, g_iCurMapId );
#endif
            
            return;
        }
        
        g_bNewMapId = true;
        
        
        LogMessage( INF_CON_PRE..."Creating a new map id for map %s!", g_szCurrentMap );

        
        decl String:szQuery[256];
        FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...INF_TABLE_MAPS..." (mapname) VALUES ('%s')", g_szCurrentMap );
        
        SQL_TQuery( g_hDB, Thrd_NewMapId, szQuery, _, DBPrio_High );
    }
}

public void Thrd_NewMapId( Handle db, Handle res, const char[] szError, any data )
{
    DB_InitMap();
}

public void Thrd_GetClientId( Handle db, Handle res, const char[] szError, int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "getting client id", client, "Couldn't retrieve your id! Please reconnect!" );
        return;
    }
    
    
    if ( g_iClientId[client] > 0 )
    {
        LogError( INF_CON_PRE..."Attempted to retrieve id but %N is already authorized! (ID: %i)",
            client,
            g_iClientId[client] );
    }
    
    // This should never happen.
    if ( SQL_GetRowCount( res ) > 1 )
    {
        decl String:szSteam[64];
        Inf_GetClientSteam( client, szSteam, sizeof( szSteam ) );
        
        LogError( INF_CON_PRE..."Found multiple records with same Steam ID!!! (%N - %s)",
            client,
            szSteam );
    }
    
    
    if ( !SQL_FetchRow( res ) )
    {
        static char szQuery[512];
        static char szName[MAX_DB_NAME_LENGTH];
        static char szSteam[64];

        if ( !Inf_GetClientSteam( client, szSteam, sizeof( szSteam ) ) )
        {
            LogError( INF_CON_PRE..."Failed to retrieve %N's Steam Id to insert new record!",
                client );
            return;
        }
        
        if ( !DB_GetClientNameSafe( client, szName, sizeof( szName ) ) )
        {
            strcopy( szName, sizeof( szName ), "N/A" );
        }
        
        
        
        FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...INF_TABLE_USERS..." (steamid,joindate,name) VALUES ('%s',CURRENT_DATE,'%s')",
            szSteam,
            szName );
        
        SQL_TQuery( g_hDB, Thrd_InsertNewUser, szQuery, GetClientUserId( client ), DBPrio_High );
    }
    else
    {
        SetClientId( client, SQL_FetchInt( res, 0 ) );
        
        DB_InitClientTimes( client );
    }
}

public void Thrd_InsertNewUser( Handle db, Handle res, const char[] szError, int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "inserting new user", client, "Couldn't create a new user record for you! Please reconnect!" );
        return;
    }
    
    
    DB_InitClient_Cb( client, Thrd_GetClientNewId );
}

public void Thrd_GetClientNewId( Handle db, Handle res, const char[] szError, int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null || !SQL_FetchRow( res ) )
    {
        Inf_DB_LogError( g_hDB, "getting new user id", client, "Couldn't retrieve new user id! Please reconnect!" );
        return;
    }
    
    
    SetClientId( client, SQL_FetchInt( res, 0 ), true );
    
    g_bCachedTimes[client] = true;
}

public void Thrd_GetClientRecords( Handle db, Handle res, const char[] szError, int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "getting client times", client, "Couldn't retrieve your personal records! Please reconnect!" );
        return;
    }
    
    
    int irun = -1;
    int lastrunid = -1;
    
    int runid, mode, style;
    float time;
    
    while ( SQL_FetchRow( res ) )
    {
        if ( (runid = SQL_FetchInt( res, 0 )) != lastrunid )
        {
            irun = FindRunById( runid );
        }
        
        lastrunid = runid;
        
        if ( irun == -1 ) continue;
        
        
        mode = SQL_FetchInt( res, 1 );
        style = SQL_FetchInt( res, 2 );
        time = SQL_FetchFloat( res, 3 );
        
#if defined DEBUG_DB_CBRECS
        PrintToServer( INF_DEBUG_PRE..."Found user's record: (Run ID: %i (%i)) (%i, %i) (Time: %.4f)",
            runid,
            irun,
            mode,
            style,
            time );
#endif
        
        if ( !VALID_MODE( mode ) ) continue;
        if ( !VALID_STYLE( style ) ) continue;
        if ( time <= INVALID_RUN_TIME ) continue;
        
        
        SetClientRunTime( irun, client, mode, style, time );
    }
    
    g_bCachedTimes[client] = true;
}

// Currently not used.
public void Thrd_GetBestRecords_1( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "getting best records times" );
        return;
    }

    if ( !SQL_GetRowCount( res ) )
    {
        PrintToServer( INF_CON_PRE..."No records to load from map. (%i)", g_iCurMapId );

        // Alright, we're ready to receive new best times.
        g_bBestTimesCached = true;

        return;
    }


    PrintToServer( INF_CON_PRE..."Retrieving %i best records from database for map...", SQL_GetRowCount( res ) );


    decl String:szQuery[512];
    int runid, mode, style;
    float time;

    // Count down to 1 so we know when we've finished retrieving all the records.
    int counter = SQL_GetRowCount( res );


    while ( SQL_FetchRow( res ) )
    {
        runid = SQL_FetchInt( res, 0 );
        mode = SQL_FetchInt( res, 1 );
        style = SQL_FetchInt( res, 2 );
        time = SQL_FetchFloat( res, 3 );
        
        // We now have the best time per runid, mode, style group for the map.
        // Now get the actual data we need.
        FormatEx( szQuery, sizeof( szQuery ), QUERY_INIT_RECORDS_2,
            g_iCurMapId,
            runid,
            mode,
            style,
            time );

        SQL_TQuery( g_hDB, Thrd_GetBestRecords_2, szQuery, counter--, DBPrio_Normal );
    }
}

public void Thrd_GetBestRecords_2( Handle db, Handle res, const char[] szError, int counter )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "getting best records data" );
        return;
    }
    
    
    int irun = -1;
    int lastrunid = -1;
    int uid, runid, mode, style;
    float time;
    char szName[32];
    
    while ( SQL_FetchRow( res ) )
    {
        if ( (runid = SQL_FetchInt( res, 1 )) != lastrunid )
        {
            irun = FindRunById( runid );
        }
        
        lastrunid = runid;
        
        if ( irun == -1 ) continue;
        
        
        mode = SQL_FetchInt( res, 2 );
        style = SQL_FetchInt( res, 3 );
        time = SQL_FetchFloat( res, 4 );
        
        if ( !VALID_MODE( mode ) ) continue;
        if ( !VALID_STYLE( style ) ) continue;
        if ( time <= INVALID_RUN_TIME ) continue;
        
        
        uid = SQL_FetchInt( res, 0 );
        
        SQL_FetchString( res, 5, szName, sizeof( szName ) );
        
#if defined DEBUG_DB_CBRECS
        PrintToServer( INF_DEBUG_PRE..."Found best record: (Name: %s) (Run ID: %i (%i)) (%i, %i, %i) (Time: %.4f)",
            szName,
            runid,
            irun,
            uid,
            mode,
            style,
            time );
#endif
        
        
        SetRunBestTime( irun, mode, style, time, uid );
        SetRunBestName( irun, mode, style, szName );
        
        // If we've already received times from the map start, update players' cached variables.
        if ( g_bBestTimesCached )
        {
            UpdateAllClientsCached( runid, mode, style );
        }
    }
    

    // We've reached the end of our queries. All our times should be cached now!
    if ( counter <= 1 )
    {
        PrintToServer( INF_CON_PRE..."Finished retrieving best records from database!" );


        g_bBestTimesCached = true;
        
        Call_StartForward( g_hForward_OnPostRecordsLoad );
        Call_Finish();
    }
}

public void Thrd_GetRuns( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting run data" );

        g_bRunsLoaded = true;
        return;
    }
    
    
    // Attempt to load em from file if we have none in db.
    if ( !SQL_GetRowCount( res ) )
    {
        LoadRuns( true, false, true );
        return;
    }
    
    
    int runid;
    decl String:rundata[1024];
    KeyValues kv;
    
    
    SendRunLoadPre();
    
    while ( SQL_FetchRow( res ) )
    {
        runid = SQL_FetchInt( res, 0 );
        SQL_FetchString( res, 1, rundata, sizeof( rundata ) );
        
        kv = new KeyValues( "" );
        if ( !kv.ImportFromString( rundata, "" ) )
        {
            LogError( INF_CON_PRE..."Failed to import run of id %i keyvalue data from database! Run data:\n%s", runid, rundata );

            delete kv;
            continue;
        }
        
        
        LoadRunFromKv( kv );
        
        delete kv;
    }
    
    SendRunLoadPost();

    g_bRunsLoaded = true;
}

/*public void Thrd_GetNumRecords( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "getting best records" );
        return;
    }
    
    
    int irun = -1;
    int lastrunid = -1;
    int runid, mode, style, num;
    while ( SQL_FetchRow( res ) )
    {
        if ( (runid = SQL_FetchInt( res, 0 )) != lastrunid )
        {
            irun = FindRunById( runid );
        }
        
        lastrunid = runid;
        
        if ( irun == -1 ) continue;
        
        
        mode = SQL_FetchInt( res, 1 );
        style = SQL_FetchInt( res, 2 );
        
        num = SQL_FetchInt( res, 3 );
        
#if defined DEBUG_DB_CBRECS
        PrintToServer( INF_DEBUG_PRE..."Found num records: (Run ID: %i (%i)) (%i, %i) (Num: %i)",
            runid,
            irun,
            mode,
            style,
            num );
#endif
        
        if ( !VALID_MODE( mode ) ) continue;
        if ( !VALID_STYLE( style ) ) continue;
        
        
        SetRunNumRecords( irun, mode, style, num );
    }
}*/

public void Thrd_PrintDeleteRecords( Handle db, Handle res, const char[] szError, int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "printing runs to client", client, "Something went wrong." );
        return;
    }
    
    
    char szInfo[32];
    char szDisplay[64];
    char szRun[MAX_RUN_NAME];
    
    int runid, numrecs;
    
    int num = 0;
    
    
    Menu menu = new Menu( Hndlr_DeleteRecords );
    menu.SetTitle( "Delete run's records\n " );
    
    while ( SQL_FetchRow( res ) )
    {
        runid = SQL_FetchInt( res, 0 );
        numrecs = SQL_FetchInt( res, 1 );
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i", runid, numrecs );
        
        GetRunName( runid, szRun, sizeof( szRun ) );
        
        FormatEx( szDisplay, sizeof( szDisplay ), "ID: %i (%s) - %i records",
            runid,
            szRun,
            numrecs );
        
        menu.AddItem( szInfo, szDisplay );
        
        ++num;
    }
    
    if ( !num )
    {
        menu.AddItem( "", "No records found! :(" );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
}