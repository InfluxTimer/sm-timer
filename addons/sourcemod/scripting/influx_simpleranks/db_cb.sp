public void Thrd_Empty( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "inserting rank data into database", client ? GetClientOfUserId( client ) : 0, "An error occurred while saving your ranks!" );
    }
}

public void Thrd_InitMap( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting map rank reward" );
        return;
    }
    
    
    g_hMapRewards.Clear();
    
    while ( SQL_FetchRow( res ) )
    {
        SetMapReward( SQL_FetchInt( res, 0 ), SQL_FetchInt( res, 1 ) );
    }
}

public void Thrd_InitClient( Handle db, Handle res, const char[] szError, int client )
{
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting client rank" );
        return;
    }
    
    
    if ( SQL_FetchRow( res ) )
    {
        g_nPoints[client] = SQL_FetchInt( res, 0 );
        
        
        decl String:szRank[MAX_RANK_SIZE];
        SQL_FetchString( res, 1, szRank, sizeof( szRank ) );
        
        if ( szRank[0] != 0 )
        {
            int index = FindRankByName( szRank );
            
            if ( index != -1 && CanUseRankFlagsByIndex( client, index ) )
            {
                SetClientRank( client, index, true, szRank );
            }
            else if ( CanUserUseCustomRank( client ) )
            {
                SetClientRank( client, -1, true, szRank );
            }
            else
            {
                SetClientDefRank( client );
            }
        }
        else
        {
            SetClientDefRank( client );
        }
    }
    else
    {
        static char szQuery[256];
        FormatEx( szQuery, sizeof( szQuery ),
            "INSERT INTO "...INF_TABLE_SIMPLERANKS..." (uid,cachedpoints,chosenrank) VALUES (%i,0,NULL)", Influx_GetClientId( client ) );
        
        SQL_TQuery( db, Thrd_Empty, szQuery, GetClientUserId( client ), DBPrio_Normal );
        
        
        SetClientDefRank( client );
    }
}

public void Thrd_CheckClientRecCount( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[5];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    
    int client = data[0];
    int mapid = data[1];
    int reqrunid = data[2];
    int reqmode = data[3];
    int reqstyle = data[4];
    
    
    if ( mapid != Influx_GetCurrentMapId() ) return;
    
    if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "checking client record count for reward" );
        return;
    }
    
    
    // Check whether the server has updated this map's reward to be higher. If so, update ours!
    int override_reward = -1;
    
    bool bFirst = SQL_GetRowCount( res ) ? false : true;
    bool bGotPointsForSameModeNStyle = false;
    
    
    while ( SQL_FetchRow( res ) )
    {
        // Check if the reward has changed. If so, give us moar points!
        int mode = SQL_FetchInt( res, 0 );
        int style = SQL_FetchInt( res, 1 );
        
        if ( mode != reqmode || style != reqstyle ) continue;
        

        bGotPointsForSameModeNStyle = true;

        
        int oldreward = SQL_FetchInt( res, 2 );
        bool bOldFirst = SQL_FetchInt( res, 3 ) ? true : false;
        
        int curreward = CalcReward( reqrunid, mode, style, bOldFirst );
        
        // Hasn't changed.
        if ( oldreward >= curreward )
        {
            break;
        }
        
        override_reward = curreward - oldreward;
        bFirst = bOldFirst;
        
        break;
    }

    // Don't give points if we don't want to 
    // give points for the same mode n style combo.
    if ( bGotPointsForSameModeNStyle && !g_ConVar_GivePointsForSameModeNStyle.BoolValue )
    {
        return;
    }
    
    
    RewardClient(
        client,
        reqrunid,
        reqmode,
        reqstyle,
        override_reward,
        bFirst,
        override_reward != -1 );
}

public void Thrd_SetMapReward( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[3];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    
    int client = data[0];
    int runid = data[1];
    int reward = data[2];
    
    
    // Allow console to pass.
    if ( client )
    {
        if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) )
            return;
    }
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "setting map reward by name" );
        return;
    }
    
    // We never know which query gets executed first.
    // So... we'll check if this one record we have is the same one we are receiving the reward for.
    if ( SQL_GetRowCount( res ) > 1 )
    {
        Inf_ReplyToClient( client, "Found multiple maps with similar name! Try to be more specific." );
        return;
    }
    
    if ( !SQL_FetchRow( res ) )
    {
        Inf_ReplyToClient( client, "Couldn't find a similar map!" );
        return;
    }
    
    
    int mapid = SQL_FetchInt( res, 0 );
    
    decl String:szMap[64];
    SQL_FetchString( res, 1, szMap, sizeof( szMap ) );
    
    
    if ( mapid == Influx_GetCurrentMapId() )
    {
        SetCurrentMapReward( client, runid, reward );
    }
    
    
    DB_UpdateMapReward( mapid, runid, reward );
    
    Inf_ReplyToClient( client, "Setting {MAINCLR1}%s{CHATCLR}'s reward to {MAINCLR1}%i{CHATCLR}!",
        szMap,
        reward );
}

public void Thrd_DisplayTopRanks( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[2];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    
    int client = data[0];
    int nToPrint = data[1];
    
    
    // Allow console to pass.
    if ( client )
    {
        if ( (client = GetClientOfUserId( client )) < 1 || !IsClientInGame( client ) )
            return;
    }
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing top ranks to client", client, "Something went wrong." );
        return;
    }
    
    
    
    decl String:szDisplay[128];
    int num = 0;
    
    int points;
    decl String:szPlyName[64];
    decl String:szRankName[128];
    

    
    Menu menu = new Menu( Hndlr_TopRanks );
    menu.SetTitle( "Top %i ranked players\n ", nToPrint );
    
    
    while ( SQL_FetchRow( res ) )
    {
        ++num;
        
        points = SQL_FetchInt( res, 0 );
        SQL_FetchString( res, 1, szPlyName, sizeof( szPlyName ) );
        
        szRankName[0] = 0;
        GetRankName( GetRankClosest( points, false ), szRankName, sizeof( szRankName ) );
        if ( szRankName[0] != 0 )
        {
            Influx_RemoveChatColors( szRankName, sizeof( szRankName ) );
            Format( szRankName, sizeof( szRankName ), " %s", szRankName );
        }
        
        FormatEx( szDisplay, sizeof( szDisplay ), "#%i | %i - %s%s",
            num,
            points,
            szPlyName,
            szRankName );
        
        menu.AddItem(
            "",
            szDisplay,
            ITEMDRAW_DISABLED ); // ITEMDRAW_DEFAULT
    }
    
    if ( !num )
    {
        menu.AddItem( "", "No ranks :(", ITEMDRAW_DISABLED );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
}
