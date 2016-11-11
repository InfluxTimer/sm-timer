public void Thrd_Empty( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "inserting data into database", GetClientOfUserId( client ), "An error occurred while saving your data!" );
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

public void Thrd_PrintMaps( Handle db, Handle res, const char[] szError, int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "printing maps to client", client, "Something went wrong." );
        return;
    }
    
    
    Menu menu = new Menu( Hndlr_MapList );
    menu.SetTitle( "Maps\n " );
    
    
    int num = 0;
    
    char szMap[64];
    
    char szInfo[6];
    char szDisplay[64];
    
    int main_recs, misc_recs;
    
    while ( SQL_FetchRow( res ) )
    {
        main_recs = SQL_FetchInt( res, 2 );
        misc_recs = SQL_FetchInt( res, 3 );
        
        if ( main_recs <= 0 && misc_recs <= 0 ) continue;
        
        
        FormatEx( szInfo, sizeof( szInfo ), "%i", SQL_FetchInt( res, 0 ) );
        
        SQL_FetchString( res, 1, szMap, sizeof( szMap ) );
        FormatEx( szDisplay, sizeof( szDisplay ), "%s - %02i records (%02i misc.)",
            szMap,
            main_recs,
            misc_recs );
        
        menu.AddItem( szInfo, szDisplay );
        
        ++num;
    }
    
    if ( !num )
    {
        menu.AddItem( "", "No maps were found :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
}

public void Thrd_PrintRecords( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[PCB_SIZE];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    int client = GetClientOfUserId( data[PCB_USERID] );
    
    if ( !client ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "printing records to client", client, "Something went wrong." );
        return;
    }
    
    
    int requid = data[PCB_UID];
    int reqmapid = data[PCB_MAPID];
    int runid = data[PCB_RUNID]; // Runid is always requested.
    int reqmode = data[PCB_MODE];
    int reqstyle = data[PCB_STYLE];
    int offset = data[PCB_OFFSET];
    int totalrecords = data[PCB_TOTALRECORDS];
    
    
    // This is the first query, this will be our number.
    if ( !totalrecords )
    {
        totalrecords = SQL_GetRowCount( res );
    }
    
    
    int curpage = RoundToCeil( (PRINTREC_MENU_LIMIT * offset) / 7.0 ) + 1;
    int lastpage = curpage + RoundToFloor( PRINTREC_MENU_LIMIT / 7.0 );
    
    
    int totalpages = RoundToCeil( totalrecords / 7.0 );
    
    if ( lastpage > totalpages )
    {
        lastpage = totalpages;
    }
    
    
    
    Menu menu = new Menu( Hndlr_RecordList );
    
    int numrecsprinted = 0;
    //decl recid;
    decl uid, mapid, modeid, styleid, rank;
    decl String:szTime[10];
    decl String:szInfo[64];
    decl String:szMap[64];
    decl String:szName[64];
    decl String:szDisplay[128];
    decl String:szRun[MAX_RUN_NAME];
    decl String:szMode[MAX_MODE_NAME];
    decl String:szStyle[MAX_STYLE_NAME];
    
    szRun[0] = '\0';
    szMap[0] = '\0';
    szName[0] = '\0';
    
    
    // Our requested uid may be in the server.
    if ( requid != -1 )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) && !IsFakeClient( i ) && g_iClientId[i] == requid )
            {
                GetClientName( i, szName, sizeof( szName ) );
                break;
            }
        }
    }
    
    
    // Find run name.
    if ( reqmapid == g_iCurMapId )
    {
        strcopy( szMap, sizeof( szMap ), g_szCurrentMap );
        
        int irun = FindRunById( runid );
        if ( irun != -1 )
        {
            GetRunNameByIndex( irun, szRun, sizeof( szRun ) );
        }
    }
    
    if ( szRun[0] == '\0' )
    {
        // Display the id at least.
        if ( runid == MAIN_RUN_ID )
        {
            strcopy( szRun, sizeof( szRun ), "Main" );
        }
        else
        {
            FormatEx( szRun, sizeof( szRun ), "ID: %i", runid );
        }
    }
    
    
    
    // We can go back to other pages. Display an option for it.
    if ( curpage > 1 )
    {
        // Please note the 'l' at the start
        FormatEx( szInfo, sizeof( szInfo ), "l%i_%i_%i_%i_%i_%i_%i", requid, reqmapid, runid, reqmode, reqstyle, offset, totalrecords );
        
        menu.AddItem( szInfo, "<< Last page" );
    }
    
    
    
    while ( SQL_FetchRow( res ) && numrecsprinted < PRINTREC_MENU_LIMIT )
    {
        // Get the map name once.
        if ( szMap[0] == '\0' )
        {
            SQL_FetchString( res, 7, szMap, sizeof( szMap ) );
        }
        
        uid = SQL_FetchInt( res, 0 );
        mapid = SQL_FetchInt( res, 1 );
        runid = SQL_FetchInt( res, 2 );
        modeid = SQL_FetchInt( res, 3 );
        styleid = SQL_FetchInt( res, 4 );
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i_%i_%i", uid, mapid, runid, modeid, styleid );
        
        Inf_FormatSeconds( SQL_FetchFloat( res, 5 ), szTime, sizeof( szTime ) );
        
        
        
        if ( reqmode == -1 && modeid != -1 && ShouldModeDisplay( modeid ) )
        {
            GetModeName( modeid, szMode, sizeof( szMode ) );
        }
        else
        {
            szMode[0] = '\0';
        }
        
        if ( reqstyle == -1 && styleid != -1 && ShouldStyleDisplay( styleid ) )
        {
            GetStyleName( styleid, szStyle, sizeof( szStyle ) );
        }
        else
        {
            szStyle[0] = '\0';
        }
        
        
        rank = SQL_FetchInt( res, 8 ) + 1;
        
        if ( requid != -1 )
        {
            // Get the name once if only searching for one uid.
            if ( szName[0] == '\0' )
            {
                SQL_FetchString( res, 6, szName, sizeof( szName ) );
            }
            
            FormatEx( szDisplay, sizeof( szDisplay ), "#%02i | %s%s%s%s%s%s",
                rank,
                szTime,
                ( szMode[0] != '\0' || szStyle[0] != '\0' ) ? " |" : "",
                ( szStyle[0] != '\0' ) ? " " : "",
                ( szStyle[0] != '\0' ) ? szStyle : "",
                ( szMode[0] != '\0' ) ? " " : "",
                ( szMode[0] != '\0' ) ? szMode : "" );
        }
        else
        {
            SQL_FetchString( res, 6, szName, sizeof( szName ) );
            
            FormatEx( szDisplay, sizeof( szDisplay ), "#%02i | %s - %s%s%s%s%s%s",
                rank,
                szTime,
                szName,
                ( szMode[0] != '\0' || szStyle[0] != '\0' ) ? " |" : "",
                ( szStyle[0] != '\0' ) ? " " : "",
                szStyle,
                ( szMode[0] != '\0' ) ? " " : "",
                szMode );
        }

        menu.AddItem( szInfo, szDisplay );
        
        ++numrecsprinted;
    }
    
    
    // We have more records to go, display a button to query the next set.
    if ( numrecsprinted >= PRINTREC_MENU_LIMIT )
    {
        // Please note the 'n' at the start
        FormatEx( szInfo, sizeof( szInfo ), "n%i_%i_%i_%i_%i_%i_%i", requid, reqmapid, runid, reqmode, reqstyle, offset, totalrecords );
        
        menu.AddItem( szInfo, ">> Next page" );
    }
    
    
    
    if ( reqmode != -1 && ShouldModeDisplay( reqmode ) )
    {
        GetModeName( reqmode, szMode, sizeof( szMode ) );
    }
    else
    {
        szMode[0] = '\0';
    }
    
    if ( reqstyle != -1 && ShouldStyleDisplay( reqstyle ) )
    {
        GetStyleName( reqstyle, szStyle, sizeof( szStyle ) );
    }
    else
    {
        szStyle[0] = '\0';
    }
    
    
    if ( szMap[0] == '\0' ) strcopy( szMap, sizeof( szMap ), "N/A" );
    
    
    menu.SetTitle( "%s%sRecords | %s%s%s%s%s%s | %s\n \nPages: %i-%i/%i\n----------------------------------------------\n ",
        ( requid != -1 && szName[0] != '\0' ) ? szName : "",
        ( requid != -1 && szName[0] != '\0' ) ? "'s " : "",
        szRun,
        ( szMode[0] != '\0' || szStyle[0] != '\0' ) ? " |" : "",
        ( szStyle[0] != '\0' ) ? " " : "",
        szStyle,
        ( szMode[0] != '\0' ) ? " " : "",
        szMode,
        szMap,
        curpage,
        lastpage,
        totalpages );
    
    if ( !numrecsprinted )
    {
        menu.AddItem( "", "No records were found! :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
}

public void Thrd_PrintRecordInfo( Handle db, Handle res, const char[] szError, int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( g_hDB, "printing record info to client", client, "Something went wrong." );
        return;
    }
    
    if ( !SQL_FetchRow( res ) ) return;
    
    
    decl String:szRank[24];
    decl String:szName[MAX_NAME_LENGTH];
    decl String:szSteam[64];
    decl String:szTime[10];
    decl String:szDate[12];
    decl String:szAdd[256];
    decl String:szMode[MAX_MODE_NAME];
    decl String:szStyle[MAX_STYLE_NAME];
    decl String:szItem[64];
    
    decl field;
    
    
    if ( !SQL_FieldNameToNum( res, "uid", field ) ) return;
    int uid = SQL_FetchInt( res, field );
    
    if ( !SQL_FieldNameToNum( res, "mapid", field ) ) return;
    int mapid = SQL_FetchInt( res, field );
    
    if ( !SQL_FieldNameToNum( res, "runid", field ) ) return;
    int runid = SQL_FetchInt( res, field );
    
    if ( !SQL_FieldNameToNum( res, "mode", field ) ) return;
    int mode = SQL_FetchInt( res, field );
    
    if ( !SQL_FieldNameToNum( res, "style", field ) ) return;
    int style = SQL_FetchInt( res, field );
    
    
    Menu menu = new Menu( Hndlr_RecordInfo );
    
    
    // Call our forward.
    ArrayList itemlist = new ArrayList( 64 / 4 );
    
    Call_StartForward( g_hForward_OnPrintRecordInfo );
    Call_PushCell( client );
    Call_PushCell( res );
    Call_PushCell( itemlist );
    Call_PushCell( menu );
    Call_PushCell( uid );
    Call_PushCell( mapid );
    Call_PushCell( runid );
    Call_PushCell( mode );
    Call_PushCell( style );
    Call_Finish();
    
    
    szAdd[0] = '\0';
    
    // Print the item list.
    for ( int i = 0; i < itemlist.Length; i++ )
    {
        itemlist.GetString( i, szItem, sizeof( szItem ) );
        
        Format( szAdd, sizeof( szAdd ), "%s\n%s", szAdd, szItem );
    }
    
    delete itemlist;
    
    
    
    if ( ShouldModeDisplay( mode ) )
    {
        GetModeName( mode, szMode, sizeof( szMode ) );
    }
    else
    {
        szMode[0] = '\0';
    }
    
    
    if ( ShouldStyleDisplay( style ) )
    {
        GetStyleName( style, szStyle, sizeof( szStyle ) );
    }
    else
    {
        szStyle[0] = '\0';
    }
    
    
    int numrecs, rank;
    
    if ( SQL_FieldNameToNum( res, "numrecs", field ) )
    {
        numrecs = SQL_FetchInt( res, field );
    }
    
    if ( SQL_FieldNameToNum( res, "rank", field ) )
    {
        rank = SQL_FetchInt( res, field );
    }
    
    szRank[0] = '\0';
    if ( rank >= 0 && numrecs > 0 )
    {
        FormatEx( szRank, sizeof( szRank ), "Rank: %i/%i", rank + 1, numrecs );
    }
    
    
    SQL_FieldNameToNum( res, "name", field );
    SQL_FetchString( res, field, szName, sizeof( szName ) );
    
    SQL_FieldNameToNum( res, "steamid", field );
    SQL_FetchString( res, field, szSteam, sizeof( szSteam ) );
    
    SQL_FieldNameToNum( res, "rectime", field );
    Inf_FormatSeconds( SQL_FetchFloat( res, field ), szTime, sizeof( szTime ), "%06.3f" );
    
    SQL_FieldNameToNum( res, "recdate", field );
    SQL_FetchString( res, field, szDate, sizeof( szDate ) );
    ReplaceString( szDate, sizeof( szDate ), "-", "." );
    
    
    
    menu.SetTitle( "%s%s%s - %s\n \n%s - %s\n \nTime: %s%s%s%s%s\n ",
        szStyle,
        ( szStyle[0] != '\0' ) ? " " : "",
        szMode,
        szDate,
        szName,
        szSteam,
        szTime,
        ( szRank[0] != '\0' ) ? "\n" : "",
        szRank,
        ( szAdd[0] != '\0' ) ? "\n \n" : "",
        szAdd );
    
    
    

    
    
    
    if ( CanUserRemoveRecords( client ) )
    {
        // Note: first character will determine the action.
        decl String:szInfo[64];
        FormatEx( szInfo, sizeof( szInfo ), "d%i_%i_%i_%i_%i", uid, mapid, runid, mode, style );
        
        menu.AddItem( szInfo, "Delete this record" );
    }


    menu.Display( client, MENU_TIME_FOREVER );
}

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