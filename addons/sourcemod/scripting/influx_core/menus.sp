
public Action Cmd_Credits( int client, int args )
{
    Inf_ReplyToClient( client, "Server is running {MAINCLR1}"...INF_NAME..."{CHATCLR} version {MAINCLR1}"...INF_VERSION..."{CHATCLR}!" );
    
    
    if ( !client ) return Plugin_Handled;
    
    
    if ( g_bLib_Hud_Draw )
    {
        Influx_SetNextMenuTime( client, GetEngineTime() + 5.0 );
    }
    
    Panel panel = new Panel();
    
    panel.SetTitle( INF_NAME..." version "...INF_VERSION..."\nCredits:" );
    panel.DrawItem( "", ITEMDRAW_SPACER );
    
    panel.DrawItem( "", ITEMDRAW_SPACER );
    panel.DrawText( "Mehis - Author" );
    panel.DrawItem( "", ITEMDRAW_SPACER );
    panel.DrawText( "Yeckoh - Game server, testing, moral support" );
    panel.DrawItem( "", ITEMDRAW_SPACER );
    panel.DrawText( "Kyle - Webhost, moral support" );
    panel.DrawItem( "", ITEMDRAW_SPACER );
    
    panel.DrawItem( "Exit", ITEMDRAW_CONTROL );
    
    panel.DrawItem( "", ITEMDRAW_SPACER );
    panel.Send( client, Hndlr_Panel_Empty, MENU_TIME_FOREVER );
    
    
    delete panel;
    
    return Plugin_Handled;
}

public Action Cmd_Change_Mode( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int len = g_hModes.Length;
    if ( len < 2 ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_Change_Mode );
    
    char szInfo[8];
    char szMode[MAX_MODE_NAME];
    
    GetModeName( g_iModeId[client], szMode, sizeof( szMode ) );
    menu.SetTitle( "Change Mode\nCurrent: %s\n ", szMode );
    
    
    int id;
    for ( int i = 0; i < len; i++ )
    {
        GetModeNameByIndex( i, szMode, sizeof( szMode ) );
        
        id = g_hModes.Get( i, MODE_ID );
        FormatEx( szInfo, sizeof( szInfo ), "%i", id );
        
        menu.AddItem( szInfo, szMode, ( g_iModeId[client] == id ) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_Change_Style( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int modelen = g_hModes.Length;
    int stylelen = g_hStyles.Length;
    if ( modelen < 2 && stylelen < 2 ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_Change_Style );
    
    int i;
    int id;
    
    char szInfo[12];
    char szDisplay[32];
    
    
    GetStyleName( g_iStyleId[client], szDisplay, sizeof( szDisplay ) );
    menu.SetTitle( "Change Style\nCurrent: %s\n ", szDisplay );
    
    if ( modelen > 1 )
    {
        for ( i = 0; i < modelen; i++ )
        {
            GetModeNameByIndex( i, szDisplay, sizeof( szDisplay ) );
            
            if ( i == (modelen - 1) )
            {
                Format( szDisplay, sizeof( szDisplay ), "%s\n ", szDisplay );
            }
            
            
            id = g_hModes.Get( i, MODE_ID );
            FormatEx( szInfo, sizeof( szInfo ), "m%i", id );
            
            menu.AddItem( szInfo, szDisplay, ( g_iModeId[client] == id ) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT );
        }
    }
    
    
    if ( stylelen > 1 )
    {
        for ( i = 0; i < stylelen; i++ )
        {
            GetStyleNameByIndex( i, szDisplay, sizeof( szDisplay ) );
            
            id = g_hStyles.Get( i, STYLE_ID );
            FormatEx( szInfo, sizeof( szInfo ), "s%i", id );
            
            menu.AddItem( szInfo, szDisplay, ( g_iStyleId[client] == id ) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT );
        }
    }
    
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}
