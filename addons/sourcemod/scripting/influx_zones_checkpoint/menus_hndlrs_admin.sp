public int Hndlr_DeleteRecords( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    if ( !CanUserModifyCPTimes( client ) ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    char buffer[3][12];
    if ( ExplodeString( szInfo, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return 0;
    }
    
    // Display confirmation menu.
    int runid = StringToInt( buffer[0] );
    int cpnum = StringToInt( buffer[1] );
    int numrecs = StringToInt( buffer[2] );
    
    if ( runid > 0 )
    {
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i", runid, cpnum );
        
        char szRun[MAX_RUN_NAME];
        Influx_GetRunName( runid, szRun, sizeof( szRun ) );
        
        Menu menu = new Menu( Hndlr_DeleteRecords_Confirm );
        
        menu.SetTitle( "Sure you want to delete all %i checkpoint records?\n%s CP %i\n ",
            numrecs,
            szRun,
            cpnum );
            
        menu.AddItem( szInfo, "Yes" );
        menu.AddItem( "", "No" );
        
        menu.ExitButton = false;
        
        menu.Display( client, MENU_TIME_FOREVER );
    }
    
    return 0;
}

public int Hndlr_DeleteRecords_Confirm( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !CanUserModifyCPTimes( client ) ) return 0;
    
    
    if ( index != 0 ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    char buffer[2][6];
    if ( ExplodeString( szInfo, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return 0;
    }
    
    
    int runid = StringToInt( buffer[0] );
    int cpnum = StringToInt( buffer[1] );
    
    if ( runid > 0 )
    {
        DB_DeleteCPRecords( client, Influx_GetCurrentMapId(), _, runid, cpnum );
        
        
        ResetCPTimes( runid, cpnum );
        
        //UpdateAllClientsCached( runid );
    }
    
    return 0;
}

public int Hndlr_DeleteClientRecords( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    if ( !CanUserModifyCPTimes( client ) ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    if ( szInfo[0] != 'd' ) return 0;
    
    
    char buffer[5][12];
    if ( ExplodeString( szInfo[1], "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return 0;
    }
    
    
    // Display confirmation menu.
    Menu menu = new Menu( Hndlr_DeleteClientRecords_Confirm );
    
    menu.SetTitle( "Sure you want to delete these checkpoint records?\n "  );
        
    menu.AddItem( szInfo, "Yes" );
    menu.AddItem( "", "No" );
    
    menu.ExitButton = false;
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return 0;
}

public int Hndlr_DeleteClientRecords_Confirm( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !CanUserModifyCPTimes( client ) ) return 0;
    
    
    if ( index != 0 ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    char buffer[5][12];
    if ( ExplodeString( szInfo[1], "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return 0;
    }
    
    
    int uid = StringToInt( buffer[0] );
    int mapid = StringToInt( buffer[1] );
    int runid = StringToInt( buffer[2] );
    int mode = StringToInt( buffer[3] );
    int style = StringToInt( buffer[4] );
    
    
    DB_DeleteCPRecords( client, mapid, uid, runid, _, mode, style );
    
    
    if ( Influx_GetCurrentMapId() == mapid )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( !IsClientInGame( i ) ) continue;
            
            if ( Influx_GetClientId( client ) != uid ) continue;
            
            
            ResetClientRunCPTimes( client, runid, mode, style );
            break;
        }
        
        if ( ResetCPTimesByUId( uid, runid, mode, style ) )
        {
            DB_InitCPTimes( runid, mode, style );
        }
    }
    
    return 0;
}