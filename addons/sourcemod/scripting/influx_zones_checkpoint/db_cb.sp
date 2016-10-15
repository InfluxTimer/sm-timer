public void Thrd_GetCPTimes( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting cp times" );
        return;
    }
    
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Getting cp times..." );
#endif
    
    int lastrunid = -1;
    int uid, runid, mode, style;
    int cpnum;
    float time;
    //char szName[32];
    
    int index;
    
    while ( SQL_FetchRow( res ) )
    {
        if ( (runid = SQL_FetchInt( res, 1 )) != lastrunid )
        {
            if ( Influx_FindRunById( runid ) == -1 )
            {
                lastrunid = runid;
                continue;
            }
        }
        
        lastrunid = runid;
        
        
        
        mode = SQL_FetchInt( res, 2 );
        style = SQL_FetchInt( res, 3 );
        cpnum = SQL_FetchInt( res, 4 );
        
        
        if ( !VALID_MODE( mode ) ) continue;
        if ( !VALID_STYLE( style ) ) continue;
        if ( cpnum < 1 ) continue;
        
        
        time = SQL_FetchFloat( res, 5 );
        uid = SQL_FetchInt( res, 0 );
        
        //SQL_FetchString( res, 6, szName, sizeof( szName ) );
        
        
        if ( (index = FindCPByNum( runid, cpnum )) != -1 )
        {
            SetBestTime( index, mode, style, time, uid );
            //SetBestName( index, mode, style, szName );
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

public void Thrd_Empty( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "inserting cp data" );
    }
}

public void Thrd_PrintCPTimes( Handle db, Handle res, const char[] szError, int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    
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
    
    
    Menu menu = new Menu( Hndlr_Empty );
    
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
    
    if ( !numrecs )
    {
        menu.AddItem( "", "No checkpoint times found :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
}

stock void FormatSeconds( float time, float besttime, char[] sz, int len )
{
    float dif;
    int pre;
    
    if ( time < besttime )
    {
        dif = besttime - time;
        pre = '-';
    }
    else
    {
        dif = time - besttime;
        pre = '+';
    }
    
    Inf_FormatSeconds( dif, sz, len );
    
    Format( sz, len, "%c%s", pre, sz );
}


public void Thrd_PrintDeleteCpTimes( Handle db, Handle res, const char[] szError, int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    
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