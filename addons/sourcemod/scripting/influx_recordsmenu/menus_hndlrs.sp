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

public int Hndlr_MapList( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    char buffer[2][16];
    if ( ExplodeString( szInfo, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return 0;
    }
    
    
    int uid = StringToInt( buffer[0] );
    int mapid = StringToInt( buffer[1] );
    
    DB_DetermineRunMenu( client, uid, mapid );
    
    return 0;
}

public int Hndlr_RecordRunSelect( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    char buffer[3][16];
    if ( ExplodeString( szInfo, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return 0;
    }
    
    
    int uid = StringToInt( buffer[0] );
    int mapid = StringToInt( buffer[1] );
    int runid = StringToInt( buffer[2] );
    
    DB_DetermineStyleMenu( client, uid, mapid, runid );
    
    return 0;
}

public int Hndlr_RecordStyleSelect( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    char buffer[5][16];
    if ( ExplodeString( szInfo, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return 0;
    }
    
    
    int uid = StringToInt( buffer[0] );
    int mapid = StringToInt( buffer[1] );
    int runid = StringToInt( buffer[2] );
    int mode = StringToInt( buffer[3] );
    int style = StringToInt( buffer[4] );
    
    DB_PrintRecords( client, uid, mapid, runid, mode, style );
    
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
    
    
    
    decl String:szInfo[64];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    Call_StartForward( g_hForward_OnRecordInfoButtonPressed );
    Call_PushCell( client );
    Call_PushString( szInfo );
    Call_Finish();
    
    return 0;
}
