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
    
    if ( !SQL_FetchRow( res ) ) return;
    
    
    g_nMapReward = SQL_FetchInt( res, 0 );
}

public void Thrd_InitClient( Handle db, Handle res, const char[] szError, int client )
{
    if ( !(client = GetClientOfUserId( client )) ) return;
    
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
            
            if ( index != -1 )
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
            "INSERT INTO "...INF_TABLE_SIMPLERANKS..." (uid,points,chosenrank) VALUES (%i,0,'')", Influx_GetClientId( client ) );
        
        SQL_TQuery( db, Thrd_Empty, szQuery, GetClientUserId( client ), DBPrio_Normal );
    }
}

public void Thrd_CheckClientRecCount( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[4];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    
    int client = data[0];
    int reqrunid = data[1];
    int reqmode = data[2];
    int reqstyle = data[3];
    
    
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( res == null )
    {
        Inf_DB_LogError( db, "checking client record count for reward" );
        return;
    }
    
    // We never know which query gets executed first.
    // So... we'll check if this one record we have is the same one we are receiving the reward for.
    if ( SQL_GetRowCount( res ) > 1 ) return;
    
    
    if ( SQL_FetchRow( res ) )
    {
        int runid = SQL_FetchInt( res, 0 );
        int mode = SQL_FetchInt( res, 1 );
        int style = SQL_FetchInt( res, 2 );
        
        // We've already gotten points for this!
        if ( reqrunid != runid || reqmode != mode || reqstyle != style )
        {
            return;
        }
    }

    RewardClient( client, g_ConVar_NotifyReward.BoolValue, g_ConVar_NotifyNewRank.BoolValue );
}

public void Thrd_SetMapReward( Handle db, Handle res, const char[] szError, ArrayList array )
{
    decl data[2];
    
    array.GetArray( 0, data, sizeof( data ) );
    delete array;
    
    
    int client = data[0];
    int reward = data[1];
    
    
    if ( client && !(client = GetClientOfUserId( client )) ) return;
    
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
    
    DB_UpdateMapReward( mapid, reward );
    
    //Inf_ReplyToClient( client, "Successfully set map's '{MAINCLR1}%s{CHATCLR}' reward to {MAINCLR1}%i{CHATCLR}!", szMap, reward );
}

