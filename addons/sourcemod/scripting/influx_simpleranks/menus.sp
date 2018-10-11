
public Action Cmd_Menu_Rank( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    decl String:szDisplay[192];
    decl String:szInfo[32];
    
    
    strcopy( szDisplay, sizeof( szDisplay ), g_szCurRank[client] );
    
    Influx_RemoveChatColors( szDisplay, sizeof( szDisplay ) );
    
    
    Menu menu = new Menu( Hndlr_Rank );
    menu.SetTitle( "| Ranks |\n \nCurrent rank: '%s'\nYou have %i points.\n ",
        ( szDisplay[0] != 0 ) ? szDisplay : "N/A",
        g_nPoints[client] );
    
    
    menu.AddItem( "-1", "Default rank\n ", ( g_bChose[client] ) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    
    
    decl data[RANK_SIZE];
    
    int len = g_hRanks.Length;
    for ( int i = 0; i < len; i++ )
    {
        g_hRanks.GetArray( i, data );
        
        if ( !ShouldDisplayRank( client, data ) )
            continue;
        
        FormatEx( szDisplay, sizeof( szDisplay ), "%s (%i)", data[RANK_NAME], data[RANK_POINTS] );
        FormatEx( szInfo, sizeof( szInfo ), "%i", i );
        
        Influx_RemoveChatColors( szDisplay, sizeof( szDisplay ) );
        
        menu.AddItem(
            szInfo,
            szDisplay,
            ( !CanUseRank( client, data ) || g_iCurRank[client] == i ) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_Menu_TopRank( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int num = g_ConVar_TopRankNumToPrint.IntValue;
    
    if ( num > 0 )
    {
        DB_DisplayTopRanks( client, g_ConVar_TopRankNumToPrint.IntValue );
    }
    
    return Plugin_Handled;
}


