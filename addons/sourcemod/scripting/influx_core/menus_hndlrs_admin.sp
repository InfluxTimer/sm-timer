public int Hndlr_RunMenu( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !CanUserModifyRun( client ) ) return 0;
    
    
    char szInfo[8];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int value = StringToInt( szInfo );
    
    switch ( value )
    {
        case -2 : FakeClientCommand( client, "sm_deleterunsmenu" );
        case -1 : FakeClientCommand( client, "sm_saveruns" );
        case 0 : FakeClientCommand( client, "sm_deleterecords" );
        default :
        {
            FakeClientCommand( client, "sm_runsettings %i", value );
        }
    }
    
    return 0;
}

public int Hndlr_RunSettings( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !CanUserModifyRun( client ) ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    char buffer[3][8];
    if ( ExplodeString( szInfo, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return 0;
    }
    
    
    int runid = StringToInt( buffer[0] );
    
    int irun = FindRunById( runid );
    if ( irun == -1 ) return 0;
    
    
    switch ( buffer[1][0] )
    {
        case 'a' :
        {
            // Pass the menu run id since our run id may be different.
            FakeClientCommand( client, "sm_settelepos %i", runid );
            return 0;
        }
        default : // Result and mode flags
        {
            // c = result
            // d = mode
            if ( buffer[1][0] != 'c' && buffer[1][0] != 'd' )
            {
                return 0;
            }
            
            int block = ( buffer[1][0] == 'c' ) ? RUN_RESFLAGS : RUN_MODEFLAGS;
            
            int value = StringToInt( buffer[2] );
            
            if ( block == RUN_MODEFLAGS && !VALID_MODE( value ) )
            {
                return 0;
            }
            
            int flag;
            if ( block == RUN_RESFLAGS )
            {
                flag = value;
                
                if ( !IsValidResultFlag( flag ) ) return 0;
            }
            else
            {
                flag = ( 1 << value );
            }
            
            int flags = g_hRuns.Get( irun, block );
            
            if ( flags & flag )
            {
                flags &= ~flag;
            }
            else
            {
                flags |= flag;
            }
            
            g_hRuns.Set( irun, flags, block );
        }
    }
    
    FakeClientCommand( client, "sm_runsettings %i", runid );
    
    return 0;
}

public int Hndlr_DeleteRecords( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    if ( !CanUserRemoveRecords( client ) ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    char buffer[2][6];
    if ( ExplodeString( szInfo, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return 0;
    }
    
    // Display confirmation menu.
    int runid = StringToInt( buffer[0] );
    int numrecs = StringToInt( buffer[1] );
    
    if ( runid > 0 )
    {
        FormatEx( szInfo, sizeof( szInfo ), "%i", runid );
        
        char szRun[MAX_RUN_NAME];
        GetRunName( runid, szRun, sizeof( szRun ) );
        
        Menu menu = new Menu( Hndlr_DeleteRecords_Confirm );
        
        menu.SetTitle( "Sure you want to delete all %i records?\n%s - ID: %i\n ",
            numrecs,
            szRun,
            runid );
            
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
    
    
    if ( !CanUserRemoveRecords( client ) )return 0;
    
    
    if ( index != 0 ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int runid = StringToInt( szInfo );
    
    if ( runid > 0 )
    {
        DB_DeleteRecords( client, g_iCurMapId, _, runid );
        
        
        ResetAllRunTimes( runid );
        
        UpdateAllClientsCached( runid );
    }
    
    return 0;
}

public int Hndlr_DeleteRunMenu( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    if ( !CanUserRemoveRecords( client ) ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    // Display confirmation menu.
    int runid = StringToInt( szInfo );
    
    int irun = FindRunById( runid );
    if ( irun == -1 ) return 0;
    
    
    FormatEx( szInfo, sizeof( szInfo ), "%i", runid );
    
    char szRun[MAX_RUN_NAME];
    GetRunNameByIndex( irun, szRun, sizeof( szRun ) );
    
    Menu menu = new Menu( Hndlr_DeleteRun_Confirm );
    
    menu.SetTitle( "Sure you want to delete %s (%i)\n ",
        szRun,
        runid );
        
    menu.AddItem( szInfo, "Yes" );
    menu.AddItem( "", "No" );
    
    menu.ExitButton = false;
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return 0;
}

public int Hndlr_DeleteRun_Confirm( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !CanUserRemoveRecords( client ) )return 0;
    
    
    if ( index != 0 ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int runid = StringToInt( szInfo );
    
    RemoveRunById( runid, client );
    
    return 0;
}
