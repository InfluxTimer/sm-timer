public int Hndlr_Rank( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    char szInfo[16];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int i = StringToInt( szInfo );
    
    if ( i <= -1 )
    {
        SetClientDefRank( client );
        DB_UpdateClientChosenRank( client, "" );
    }
    else
    {
        if ( i < g_hRanks.Length && g_nPoints[client] >= GetRankPoints( i ) && CanUseRankByIndex( client, i ) )
        {
            SetClientRank( client, i, true, _, true );
            
            DB_UpdateClientChosenRank( client, g_szCurRank[client] );
        }
    }
    
    
    return 0;
}

public int Hndlr_TopRanks( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    return 0;
}
