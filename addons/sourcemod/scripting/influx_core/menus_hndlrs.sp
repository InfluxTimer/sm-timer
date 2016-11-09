enum
{
    //RECMENU_RECID = 0,
    RECMENU_UID = 0,
    RECMENU_MAPID,
    RECMENU_RUNID,
    RECMENU_MODE,
    RECMENU_STYLE,
    
    RECMENU_SIZE
};

stock bool GetRecMenuData( const char[] sz, int data[RECMENU_SIZE] )
{
    char buffer[RECMENU_SIZE][6];
    if ( ExplodeString( sz, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return false;
    }
    
    //data[RECMENU_RECID] = StringToInt( buffer[0] );
    data[RECMENU_UID] = StringToInt( buffer[0] );
    data[RECMENU_MAPID] = StringToInt( buffer[1] );
    data[RECMENU_RUNID] = StringToInt( buffer[2] );
    data[RECMENU_MODE] = StringToInt( buffer[3] );
    data[RECMENU_STYLE] = StringToInt( buffer[4] );
    
    return true;
}

stock bool GetRecMenuPageData( const char[] sz, any data[PCB_SIZE] )
{
    decl String:buffer[PCB_NUM_ELEMENTS][32];
    if ( ExplodeString( sz, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return false;
    }
    
    data[PCB_UID] = StringToInt( buffer[0] );
    data[PCB_MAPID] = StringToInt( buffer[1] );
    data[PCB_RUNID] = StringToInt( buffer[2] );
    data[PCB_MODE] = StringToInt( buffer[3] );
    data[PCB_STYLE] = StringToInt( buffer[4] );
    data[PCB_OFFSET] = StringToInt( buffer[5] );
    data[PCB_TOTALRECORDS] = StringToInt( buffer[6] );
    
    return true;
}

/*stock bool StringNumericOnly( const char[] sz )
{
    int len = strlen( sz );
    for ( int i = 0; i < len; i++ )
    {
        if ( sz[0] < '0' || sz[0] > '9' )
        {
            return false;
        }
    }
    
    return true;
}*/

/*public int Hndlr_Empty( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    return 0;
}*/

public int Hndlr_Panel_Empty( Menu menu, MenuAction action, int client, int param2 ) {}

public int Hndlr_Change_Run( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[8];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    SetClientRun( client, StringToInt( szInfo ) );
    
    return 0;
}

public int Hndlr_Change_Mode( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[8];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    SetClientMode( client, StringToInt( szInfo ) );
    
    return 0;
}

public int Hndlr_Change_Style( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[8];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int id = StringToInt( szInfo[1] );
    
    if ( szInfo[0] == 'm' )
    {
        SetClientMode( client, id );
    }
    else
    {
        SetClientStyle( client, id );
    }
    
    return 0;
}

public int Hndlr_MapList( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[6];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int mapid = StringToInt( szInfo );
    
    if ( mapid > 0 )
        DB_PrintRecords( client, _, mapid, MAIN_RUN_ID );
    
    return 0;
}

public int Hndlr_RecordList( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    // Don't let them spam these too fast.
    if ( Inf_HandleCmdSpam( client, 0.3, g_flLastRecPrintTime[client], true ) )
    {
        return 0;
    }
    
    
    
    char szInfo[64];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    // We just want to go to the last or next page!
    if ( szInfo[0] == 'l' || szInfo[0] == 'n' )
    {        
        decl data[PCB_SIZE];
        if ( !GetRecMenuPageData( szInfo[1], data ) ) return 0;
        
        
        int offset = data[PCB_OFFSET];
        
        if ( szInfo[0] == 'n' ) ++offset; // Add for next page.
        else --offset; // Subtract for last page.
        
        
        DB_PrintRecords(
            client,
            data[PCB_UID],
            data[PCB_MAPID],
            data[PCB_RUNID],
            data[PCB_MODE],
            data[PCB_STYLE],
            _,
            _,
            offset,
            data[PCB_TOTALRECORDS] );
    }
    // We want to show specific record's info.
    else
    {
        int data[RECMENU_SIZE];
        if ( !GetRecMenuData( szInfo, data ) ) return 0;
        
        
        DB_PrintRecordInfo(
            client,
            //data[RECMENU_RECID],
            data[RECMENU_UID],
            data[RECMENU_MAPID],
            data[RECMENU_RUNID],
            data[RECMENU_MODE],
            data[RECMENU_STYLE] );
    }
    
    return 0;
}

public int Hndlr_RecordInfo( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    
    char szInfo[32];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    switch ( szInfo[0] )
    {
        case 'c' : // We want checkpoint times.
        {
            int data[RECMENU_SIZE];
            if ( !GetRecMenuData( szInfo[1], data ) ) return 0;
            
            
            if ( g_bLib_Zones_CP )
            {
                Influx_PrintCPTimes( client, data[RECMENU_UID], data[RECMENU_MAPID], data[RECMENU_RUNID], data[RECMENU_MODE], data[RECMENU_STYLE] );
            }
        }
        case 'd' : // We want to delete
        {
            if ( !CanUserRemoveRecords( client ) )return 0;
            
            
            // Display confirmation menu.
            Menu menu = new Menu( Hndlr_Delete_Confirm );
            menu.SetTitle( "Sure you want to delete this record?\n " );
            
            menu.AddItem( szInfo[1], "Yes" );
            menu.AddItem( "", "No" );
            
            menu.ExitButton = false;
            
            menu.Display( client, MENU_TIME_FOREVER );
        }
    }
    
    return 0;
}

public int Hndlr_Delete_Confirm( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( index != 0 ) return 0;
    
    
    if ( !CanUserRemoveRecords( client ) )return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    int data[RECMENU_SIZE];
    if ( !GetRecMenuData( szInfo, data ) ) return 0;
    
    
    DB_DeleteRecords(   client,
                        data[RECMENU_MAPID],
                        data[RECMENU_UID],
                        data[RECMENU_RUNID],
                        data[RECMENU_MODE],
                        data[RECMENU_STYLE] );
    
    return 0;
}