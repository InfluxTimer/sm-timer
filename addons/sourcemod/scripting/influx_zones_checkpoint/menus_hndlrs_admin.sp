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
        DB_DeleteCPTimes( client, Influx_GetCurrentMapId(), runid, cpnum );
        
        
        ResetCPTimes( runid, cpnum );
        
        //UpdateAllClientsCached( runid );
    }
    
    return 0;
}