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
        
        
        // We've retrieved the map id!
        Call_StartForward( g_hForward_OnMapIdRetrieved );
        Call_PushCell( g_iCurMapId );
        Call_PushCell( g_bNewMapId );
        Call_Finish();
        
        
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
    if ( !(client = GetClientOfUserId( client )) ) return;
    
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
        decl String:szSteam[64];
        if ( !Inf_GetClientSteam( client, szSteam, sizeof( szSteam ) ) ) return;
        
        
        decl String:szQuery[128];
        FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO "...INF_TABLE_USERS..." (steamid,joindate) VALUES ('%s',CURRENT_DATE)", szSteam );
        
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
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "inserting new user", client, "Couldn't create a new user record for you! Please reconnect!" );
        return;
    }
    
    
    DB_InitClient_Cb( client, Thrd_GetClientNewId );
}

public void Thrd_GetClientNewId( Handle db, Handle res, const char[] szError, int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
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
    if ( !(client = GetClientOfUserId( client )) ) return;
    
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

public void Thrd_GetBestRecords( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "getting best records" );
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
    
    g_bBestTimesCached = true;
    
    Call_StartForward( g_hForward_OnPostRecordsLoad );
    Call_Finish();
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
    if ( !(client = GetClientOfUserId( client )) ) return;
    
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