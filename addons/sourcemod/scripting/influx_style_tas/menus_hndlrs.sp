public int Hndlr_TasMenu( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return 0;
    
    
    char szInfo[2];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    switch ( szInfo[0] )
    {
        case 'a' :
        {
            SetFrame( client, g_iStoppedFrame[client] + 1, false, true );
            
            g_iPlayback[client] = 0;
        }
        case 'b' :
        {
            SetFrame( client, g_iStoppedFrame[client] - 1, false, true );
            
            g_iPlayback[client] = 0;
        }
        case 'c' :
        {
            ContinueOrStop( client );
        }
        case 'd' :
        {
            StopClient( client );
            IncreasePlayback( client );
        }
        case 'e' :
        {
            StopClient( client );
            DecreasePlayback( client );
        }
        case 'f' :
        {
            OpenSettingsMenu( client );
            return 0;
        }
    }
    
    OpenMenu( client );
    
    return 0;
}

public int Hndlr_Settings( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return 0;
    
    
    char szInfo[2];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    switch ( szInfo[0] )
    {
        case 'a' :
        {
            if ( g_flTimescale[client] >= 1.0 )
            {
                SetTimescale( client, 0.25 );
            }
            else
            {
                IncreaseTimescale( client );
            }
        }
        case 'b' :
        {
            g_bAutoStrafe[client] = !g_bAutoStrafe[client];
        }
        case 'c' :
        {
            OpenCmdListMenu( client );
            return 0;
        }
        case 'd' :
        {
            OpenMenu( client );
            return 0;
        }
    }
    
    OpenSettingsMenu( client );
    
    return 0;
}

public int Hndlr_ListCmds( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    char szInfo[2];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    switch ( szInfo[0] )
    {
        case 'a' :
        {
            OpenMenu( client );
            return 0;
        }
    }
    
    return 0;
}