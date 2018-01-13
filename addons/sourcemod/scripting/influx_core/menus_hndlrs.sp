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