public void Thrd_DetermineRunMenu( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[4];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    int client = GetClientOfUserId( data[0] );
    
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "determining run menu type to client", client, "Something went wrong." );
        return;
    }
    
    
    int uid = data[1];
    int mapid = data[2];
    int runid = data[3];
    int otherruns = SQL_FetchRow( res ) ? SQL_FetchInt( res, 0 ) : 0;
    
    // Go straight to style select if our run is the only run with records.
    if ( !otherruns )
    {
        DB_DetermineStyleMenu( client, uid, mapid, runid );
    }
    else
    {
        DB_PrintRunSelect( client, uid, mapid );
    }
}

public void Thrd_DetermineStyleMenu( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[4];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    int client = GetClientOfUserId( data[0] );
    
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "determining style menu type to client", client, "Something went wrong." );
        return;
    }
    
    
    int uid = data[1];
    int mapid = data[2];
    int runid = data[3];
    int numrecs = SQL_FetchRow( res ) ? SQL_FetchInt( res, 0 ) : 0;
    
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Number of records (%i, %i, %i): %i", uid, mapid, runid, numrecs );
#endif
    
    // Display the list if our number of records is small.
    if ( numrecs <= g_ConVar_DisplayFullListMax.IntValue )
    {
        DB_PrintRecords( client, uid, mapid, runid );
    }
    else
    {
        DB_PrintStyleSelect( client, uid, mapid, runid );
    }
}

public void Thrd_PrintMaps( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[2];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    int client = GetClientOfUserId( data[0] );
    
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing maps to client", client, "Something went wrong." );
        return;
    }
    
    
    Menu menu = new Menu( Hndlr_MapList );
    menu.SetTitle( "Maps\n " );
    
    
    int uid = data[1];
    int num = 0;
    
    char szMap[64];
    
    char szInfo[32];
    char szDisplay[64];
    
    int main_recs, misc_recs;
    
    while ( SQL_FetchRow( res ) )
    {
        main_recs = SQL_FetchInt( res, 2 );
        misc_recs = SQL_FetchInt( res, 3 );
        
        if ( main_recs <= 0 && misc_recs <= 0 ) continue;
        
        
        SQL_FetchString( res, 1, szMap, sizeof( szMap ) );
        
        // I was unable to use REGEXP on MySQL.
        // TODO: Change queries to use REGEXP instead.
        if ( !Influx_IsValidMapName( szMap ) ) continue;
        
        int mapid = SQL_FetchInt( res, 0 );
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i", uid, mapid );
        
        FormatEx( szDisplay, sizeof( szDisplay ), "%s - %0i records (%i misc.)",
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

public void Thrd_PrintRunSelect( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[3];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    int client = GetClientOfUserId( data[0] );
    
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing records menu, run select to client", client, "Something went wrong." );
        return;
    }
    
    
    decl String:szInfo[32];
    decl String:szDisplay[64];
    
    decl String:szRun[MAX_RUN_NAME];
    
    int uid = data[1];
    int mapid = data[2];
    int runid;
    int numrecs;
    
    int num = 0;
    
    Menu menu = new Menu( Hndlr_RecordRunSelect );
    
    while ( SQL_FetchRow( res ) )
    {
        runid = SQL_FetchInt( res, 0 );
        numrecs = SQL_FetchInt( res, 1 );
        
        
        RunIdToName( runid, mapid, szRun, sizeof( szRun ) );
        
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i", uid, mapid, runid );
        FormatEx( szDisplay, sizeof( szDisplay ), "%s (%i)", szRun, numrecs );
        
        menu.AddItem( szInfo, szDisplay );
        
        ++num;
    }
    
    // We only had one valid run. Just go straight to it.
    if ( num == 1 )
    {
        delete menu;
        
        DB_DetermineStyleMenu( client, uid, mapid, runid );
        return;
    }
    
    
    menu.SetTitle( "Records - Run Select\n " );
    
    if ( !num )
    {
        menu.AddItem( "", "No records were found! :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
}

public void Thrd_PrintStyleSelect( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[4];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    int client = GetClientOfUserId( data[0] );
    
    if ( !client ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing records menu, style select to client", client, "Something went wrong." );
        return;
    }
    
    
    decl String:szInfo[32];
    decl String:szDisplay[64];
    
    decl String:szRun[MAX_RUN_NAME];
    decl String:szMode[MAX_MODE_NAME];
    decl String:szStyle[MAX_STYLE_NAME];
    
    int uid = data[1];
    int mapid = data[2];
    int runid = data[3];
    int mode, style;
    int numrecs;
    
    int num = 0;
    
    RunIdToName( runid, mapid, szRun, sizeof( szRun ) );
    
    
    Menu menu = new Menu( Hndlr_RecordStyleSelect );
    
    while ( SQL_FetchRow( res ) )
    {
        mode = SQL_FetchInt( res, 0 );
        style = SQL_FetchInt( res, 1 );
        numrecs = SQL_FetchInt( res, 2 );
        
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i_%i_%i", uid, mapid, runid, mode, style );
        
        
        if ( Influx_ShouldModeDisplay( mode ) )
        {
            Influx_GetModeName( mode, szMode, sizeof( szMode ) );
        }
        else
        {
            szMode[0] = 0;
        }
        
        if ( szMode[0] == 0 || Influx_ShouldStyleDisplay( style ) )
        {
            Influx_GetStyleName( style, szStyle, sizeof( szStyle ) );
        }
        else
        {
            szStyle[0] = 0;
        }
        
        
        
        FormatEx( szDisplay, sizeof( szDisplay ), "%s%s%s (%i)",
            szStyle,
            ( szStyle[0] != 0 && szMode[0] != 0 ) ? " " : "",
            szMode,
            numrecs );
        
        menu.AddItem( szInfo, szDisplay );
        
        ++num;
    }
    
    // We only had one style and mode combo. Just go straight to it.
    if ( num == 1 )
    {
        delete menu;
        
        DB_PrintRecords( client, uid, mapid, runid, mode, style );
        return;
    }
    
    
    menu.SetTitle( "Records - Style Select | %s\n ", szRun );
    
    if ( !num )
    {
        menu.AddItem( "", "No records were found! :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
}

public void Thrd_PrintRecords( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[PCB_SIZE];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    int client = GetClientOfUserId( data[PCB_USERID] );
    
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing records to client", client, "Something went wrong." );
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
    decl String:szPages[32];
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
            if ( IsClientInGame( i ) && !IsFakeClient( i ) && Influx_GetClientId( i ) == requid )
            {
                GetClientName( i, szName, sizeof( szName ) );
                break;
            }
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
        uid = SQL_FetchInt( res, 0 );
        mapid = SQL_FetchInt( res, 1 );
        runid = SQL_FetchInt( res, 2 );
        modeid = SQL_FetchInt( res, 3 );
        styleid = SQL_FetchInt( res, 4 );
        
        
        if ( reqmapid == -1 )
        {
            reqmapid = mapid; 
        }
        
        // Get the map name once.
        if ( szMap[0] == '\0' )
        {
            SQL_FetchString( res, 7, szMap, sizeof( szMap ) );
        }
        
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i_%i_%i", uid, mapid, runid, modeid, styleid );
        
        Inf_FormatSeconds( SQL_FetchFloat( res, 5 ), szTime, sizeof( szTime ) );
        
        
        if ( reqmode == -1 && modeid != -1 && Influx_ShouldModeDisplay( modeid ) )
        {
            Influx_GetModeName( modeid, szMode, sizeof( szMode ) );
        }
        else
        {
            szMode[0] = '\0';
        }
        
        if ( reqstyle == -1 && styleid != -1 && Influx_ShouldStyleDisplay( styleid ) )
        {
            Influx_GetStyleName( styleid, szStyle, sizeof( szStyle ) );
        }
        else
        {
            szStyle[0] = '\0';
        }
        
        
        // Just estimate the rank from offset we had + records in current menu + 1
        rank = (offset * PRINTREC_MENU_LIMIT) + numrecsprinted + 1;
        
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
    
    
    
    // Find run name.
    RunIdToName( runid, reqmapid, szRun, sizeof( szRun ) );
    
    if ( reqmode != -1 && Influx_ShouldModeDisplay( reqmode ) )
    {
        Influx_GetModeName( reqmode, szMode, sizeof( szMode ) );
    }
    else
    {
        szMode[0] = '\0';
    }
    
    if ( reqstyle != -1 && Influx_ShouldStyleDisplay( reqstyle ) )
    {
        Influx_GetStyleName( reqstyle, szStyle, sizeof( szStyle ) );
    }
    else
    {
        szStyle[0] = '\0';
    }
    
    
    if ( szMap[0] == '\0' ) strcopy( szMap, sizeof( szMap ), "N/A" );
    
    
    if ( curpage == lastpage )
    {
        FormatEx( szPages, sizeof( szPages ), "%i/%i", curpage, totalpages );
    }
    else
    {
        FormatEx( szPages, sizeof( szPages ), "%i-%i/%i", curpage, lastpage, totalpages );
    }
    
    
    menu.SetTitle( "%s%sRecords | %s%s%s%s%s%s | %s\n \nPages: %s\n---------------------------------\n ",
        ( requid != -1 && szName[0] != '\0' ) ? szName : "",
        ( requid != -1 && szName[0] != '\0' ) ? "'s " : "",
        szRun,
        ( szMode[0] != '\0' || szStyle[0] != '\0' ) ? " |" : "",
        ( szStyle[0] != '\0' ) ? " " : "",
        szStyle,
        ( szMode[0] != '\0' ) ? " " : "",
        szMode,
        szMap,
        szPages );
    
    if ( !numrecsprinted )
    {
        menu.AddItem( "", "No records were found! :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
}

public void Thrd_PrintRecordInfo( Handle db, Handle res, const char[] szError, int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null || !SQL_FetchRow( res ) )
    {
        Inf_DB_LogError( db, "printing record info to client", client, "Something went wrong." );
        return;
    }
    
    
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
    
    
    
    if ( Influx_ShouldModeDisplay( mode ) )
    {
        Influx_GetModeName( mode, szMode, sizeof( szMode ) );
    }
    else
    {
        szMode[0] = '\0';
    }
    
    
    if ( Influx_ShouldStyleDisplay( style ) )
    {
        Influx_GetStyleName( style, szStyle, sizeof( szStyle ) );
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
    
    if ( SQL_FieldNameToNum( res, "plyrank", field ) )
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

    
    menu.Display( client, MENU_TIME_FOREVER );
}
