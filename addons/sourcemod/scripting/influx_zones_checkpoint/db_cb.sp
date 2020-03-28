public void Thrd_Empty( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "inserting cp data", client ? GetClientOfUserId( client ) : 0, "Something went wrong." );
    }
}

public void Thrd_GetCPSRTimes( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting cp server record times" );
        return;
    }
    
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Getting cp server record times..." );
#endif
    
    int lastrunid = -1;
    int lastcpnum = -1;
    
    int uid, runid, mode, style;
    int cpnum;
    float time;
    
    int index = -1;
    
    while ( SQL_FetchRow( res ) )
    {
        uid = SQL_FetchInt( res, 0 );
        runid = SQL_FetchInt( res, 1 )
        mode = SQL_FetchInt( res, 2 );
        style = SQL_FetchInt( res, 3 );
        cpnum = SQL_FetchInt( res, 4 );
        time = SQL_FetchFloat( res, 5 );

#if defined DEBUG_DB
        PrintToServer( INF_DEBUG_PRE..."Db sr cp time: Run id: %i | Cp num: %i | Time: %.1f",
            runid,
            cpnum,
            time );
#endif

        if ( runid != lastrunid )
        {
            if ( Influx_FindRunById( runid ) == -1 ) continue;
        }

        if ( !VALID_MODE( mode ) ) continue;
        if ( !VALID_STYLE( style ) ) continue;
        if ( cpnum < 1 ) continue;
        
        
        if ((runid == lastrunid && cpnum == lastcpnum && index != -1)
        ||  ((index = FindCPByNum( runid, cpnum )) != -1) )
        {
            SetRecordTime( index, mode, style, time, uid );
            
            lastrunid = runid;
            lastcpnum = cpnum;
        }
    }
}

public void Thrd_InitClientCPTimes( Handle db, Handle res, const char[] szError, int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting client cp times" );
        return;
    }
    
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Getting client cp times..." );
#endif
    
    int lastrunid = -1;
    int lastcpnum = -1;
    
    int runid, mode, style;
    int cpnum;
    float time;
    
    int index = -1;
    
    while ( SQL_FetchRow( res ) )
    {
        runid = SQL_FetchInt( res, 0 );
        mode = SQL_FetchInt( res, 1 );
        style = SQL_FetchInt( res, 2 );
        cpnum = SQL_FetchInt( res, 3 );
        time = SQL_FetchFloat( res, 4 );

#if defined DEBUG_DB
        PrintToServer( INF_DEBUG_PRE..."Db client cp time: Run id: %i | Cp num: %i | Time: %.1f",
            runid,
            cpnum,
            time );
#endif

        if ( runid != lastrunid )
        {
            if ( Influx_FindRunById( runid ) == -1 ) continue;
        }
        
        if ( !VALID_MODE( mode ) ) continue;
        if ( !VALID_STYLE( style ) ) continue;
        if ( cpnum < 1 ) continue;
        
        
        if ((runid == lastrunid && cpnum == lastcpnum && index != -1)
        ||  ((index = FindCPByNum( runid, cpnum )) != -1) )
        {
            SetClientCPTime( index, client, mode, style, time );
            
            lastrunid = runid;
            lastcpnum = cpnum;
        }
    }
}

public void Thrd_GetCPBestTimes( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting cp best times" );
        return;
    }
    
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Getting cp best times..." );
#endif
    
    int lastrunid = -1;
    int lastcpnum = -1;
    
    int uid, runid, mode, style;
    int cpnum;
    float time;
    
    int index = -1;
    
    while ( SQL_FetchRow( res ) )
    {
        uid = SQL_FetchInt( res, 0 );
        runid = SQL_FetchInt( res, 1 )
        mode = SQL_FetchInt( res, 2 );
        style = SQL_FetchInt( res, 3 );
        cpnum = SQL_FetchInt( res, 4 );
        time = SQL_FetchFloat( res, 5 );

#if defined DEBUG_DB
        PrintToServer( INF_DEBUG_PRE..."Db best cp time: Run id: %i | Cp num: %i | Time: %.1f",
            runid,
            cpnum,
            time );
#endif

        if ( runid != lastrunid )
        {
            if ( Influx_FindRunById( runid ) == -1 ) continue;
        }

        if ( !VALID_MODE( mode ) ) continue;
        if ( !VALID_STYLE( style ) ) continue;
        if ( cpnum < 1 ) continue;
        
        
        
        
        
        
        if ((runid == lastrunid && cpnum == lastcpnum && index != -1)
        ||  ((index = FindCPByNum( runid, cpnum )) != -1) )
        {
            SetBestTime( index, mode, style, time, uid );
            
            lastrunid = runid;
            lastcpnum = cpnum;
        }
    }
}

public void Thrd_Update( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "inserting player's checkpoint times", GetClientOfUserId( client ), "Something went wrong with your checkpoint times!" );
    }
}

public void Thrd_PrintCPTimes( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[PCB_SIZE];
    
    array.GetArray( 0, data );
    delete array;
    
    
    int client = GetClientOfUserId( data[PCB_USERID] );
    if ( client < 1 || !IsClientInGame( client ) ) return;
    
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing cp times to client", client, "Sorry, something went wrong." );
        return;
    }
    
    
    decl String:szDisplay[128];
    decl String:szForm[16];
    decl String:szAdd[32];
    decl String:szSR[64];
    decl String:szBest[64];
    int numrecs = 0;
    
    
    Menu menu = new Menu( Hndlr_DeleteClientRecords );
    
    menu.SetTitle( "CP Times\n " );
    
    
    while ( SQL_FetchRow( res ) )
    {
        int cpnum = SQL_FetchInt( res, 5 );
        
        float cptime = SQL_FetchFloat( res, 6 );
        Inf_FormatSeconds( cptime, szForm, sizeof( szForm ) );
        
        
        float srtime = SQL_FetchFloat( res, 8 );
        
        float besttime = SQL_FetchFloat( res, 9 );
        
        
        szAdd[0] = '\0';
        
        if ( cptime != srtime )
        {
            FormatSeconds( cptime, srtime, szSR, sizeof( szSR ) );
            Format( szSR, sizeof( szSR ), "\n        SR CP: %s", szSR );
        }
        else
        {
            strcopy( szAdd, sizeof( szAdd ), " (SR)" );
            szSR[0] = '\0';
        }
        
        if ( cptime != besttime && besttime != srtime )
        {
            FormatSeconds( cptime, besttime, szBest, sizeof( szBest ) );
            Format( szBest, sizeof( szBest ), "\n        CP BEST: %s", szBest );
        }
        else
        {
            szBest[0] = '\0';
        }
        
        
        if ( cptime == besttime )
        {
            Format( szAdd, sizeof( szAdd ), "%s (BEST)", szAdd );
        }
        
        
        FormatEx( szDisplay, sizeof( szDisplay ), "CP %i | %s%s%s%s\n ",
            cpnum,
            szForm,
            szAdd,
            szSR,
            szBest );
        
        menu.AddItem( "", szDisplay, ITEMDRAW_DISABLED );
        
        ++numrecs;
    }
    
    
    if ( numrecs )
    {
        if ( CanUserModifyCPTimes( client ) )
        {
            decl String:szInfo[32];
            FormatEx( szInfo, sizeof( szInfo ), "d%i_%i_%i_%i_%i", data[PCB_UID], data[PCB_MAPID], data[PCB_RUNID], data[PCB_MODE], data[PCB_STYLE] );
            
            menu.AddItem( szInfo, "Delete these records" );
        }
    }
    else
    {
        menu.AddItem( "", "No checkpoint times found :(", ITEMDRAW_DISABLED );
    }
    
    
    menu.Display( client, MENU_TIME_FOREVER );
}

public void Thrd_PrintTopCPTimes( Handle db, Handle res, const char[] szError, ArrayList array )
{
    static int data[PCBTOP_SIZE];
    array.GetArray( 0, data );
    
    delete array;
    
    int client = data[PCBTOP_USERID];
    
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing top cp times to client", client, "Sorry, something went wrong." );
        return;
    }
    
    
    decl String:szDisplay[128];
    decl String:szSR[64];
    decl String:szBest[64];
    decl String:szPB[64];
    int numrecs = 0;
    
    decl String:szMap[64];
    szMap[0] = 0;
    
    decl String:szModeStyle[64];
    szModeStyle[0] = 0;
    
    
    int reqmode = data[PCBTOP_MODE];
    int reqstyle = data[PCBTOP_STYLE];
    
    
    Menu menu = new Menu( Hndlr_Empty );
    
    
    while ( SQL_FetchRow( res ) )
    {
        if ( szMap[0] == 0 )
        {
            SQL_FetchString( res, 0, szMap, sizeof( szMap ) );
        }
        
        int cpnum = SQL_FetchInt( res, 1 );
        
        float srtime = SQL_FetchFloat( res, 2 );
        
        float besttime = SQL_FetchFloat( res, 3 );
        
        float pbtime = SQL_FetchFloat( res, 4 );
        
        
        Inf_FormatSeconds( srtime, szSR, sizeof( szSR ) );
        Format( szSR, sizeof( szSR ), "\n        SR: %s", szSR );
        
        
        if ( besttime != INVALID_RUN_TIME && besttime != srtime )
        {
            Inf_FormatSeconds( besttime, szBest, sizeof( szBest ) );
            Format( szBest, sizeof( szBest ), "\n        BEST: %s", szBest );
        }
        else
        {
            szBest[0] = '\0';
        }
        
        if ( pbtime != INVALID_RUN_TIME && pbtime != srtime )
        {
            Inf_FormatSeconds( pbtime, szPB, sizeof( szPB ) );
            Format( szPB, sizeof( szPB ), "\n        PB: %s", szPB );
        }
        else
        {
            szPB[0] = 0;
        }
        
        
        FormatEx( szDisplay, sizeof( szDisplay ), "CP %i%s%s%s\n ",
            cpnum,
            szSR,
            szBest,
            szPB );
        
        menu.AddItem( "", szDisplay, ITEMDRAW_DISABLED );
        
        ++numrecs;
    }
    
    
    if ( szMap[0] == 0 ) strcopy( szMap, sizeof( szMap ), "N/A" );
    
    if ( Influx_ShouldModeDisplay( reqmode ) )
    {
        Influx_GetModeName( reqmode, szModeStyle, sizeof( szModeStyle ) );
    }
    
    if ( Influx_ShouldStyleDisplay( reqstyle ) )
    {
        decl String:szTemp[32];
        Influx_GetStyleName( reqstyle, szTemp, sizeof( szTemp ) );
        
        Format( szModeStyle, sizeof( szModeStyle ), "%s %s", szTemp, szModeStyle );
    }
    
    
    menu.SetTitle( "Top CP Times | %s%s%s\n─────────────────────────────────\n ",
        ( szModeStyle[0] != 0 ) ? szModeStyle : "",
        ( szModeStyle[0] != 0 ) ? " | " : "",
        szMap );
    
    if ( !numrecs )
    {
        menu.AddItem( "", "No checkpoint times found :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
}

stock void FormatSeconds( float time, float besttime, char[] sz, int len )
{
    int c;
    float dif = Inf_GetTimeDif( time, besttime, c );
    
    
    Inf_FormatSeconds( dif, sz, len );
    
    Format( sz, len, "%c%s", c, sz );
}


public void Thrd_PrintDeleteCpTimes( Handle db, Handle res, const char[] szError, int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing cp deletion to client", client, "Sorry, something went wrong." );
        return;
    }
    
    
    char szDisplay[64];
    char szInfo[32];
    
    char szRun[MAX_RUN_NAME];
    
    int numrecs = 0;
    
    
    char szMap[32];
    GetCurrentMap( szMap, sizeof( szMap ) );
    
    
    Menu menu = new Menu( Hndlr_DeleteRecords );
    
    menu.SetTitle( "Checkpoints - %s\n ", szMap );
    
    
    while ( SQL_FetchRow( res ) )
    {
        int runid = SQL_FetchInt( res, 0 );
        int cpnum = SQL_FetchInt( res, 1 );
        
        int count = SQL_FetchInt( res, 2 );
        
        
        Influx_GetRunName( runid, szRun, sizeof( szRun ) );
        
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i", runid, cpnum, count );
        FormatEx( szDisplay, sizeof( szDisplay ), "%s CP %i (%i records)", szRun, cpnum, count );
        
        menu.AddItem( szInfo, szDisplay );
        
        ++numrecs;
    }
    
    if ( !numrecs )
    {
        menu.AddItem( "", "No checkpoints found :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
}

public int Hndlr_Empty( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    return 0;
}