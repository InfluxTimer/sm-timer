public void Thrd_GetCPTimes( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting cp times" );
        return;
    }
    
#if defined DEBUG_DB
    PrintToServer( INF_DEBUG_PRE..."Getting cp times..." );
#endif
    
    int lastrunid = -1;
    int uid, runid, mode, style;
    int cpnum;
    float time;
    //char szName[32];
    
    int index;
    
    while ( SQL_FetchRow( res ) )
    {
        if ( (runid = SQL_FetchInt( res, 1 )) != lastrunid )
        {
            if ( Influx_FindRunById( runid ) == -1 )
            {
                lastrunid = runid;
                continue;
            }
        }
        
        lastrunid = runid;
        
        
        
        mode = SQL_FetchInt( res, 2 );
        style = SQL_FetchInt( res, 3 );
        cpnum = SQL_FetchInt( res, 4 );
        
        
        if ( !VALID_MODE( mode ) ) continue;
        if ( !VALID_STYLE( style ) ) continue;
        if ( cpnum < 1 ) continue;
        
        
        time = SQL_FetchFloat( res, 5 );
        uid = SQL_FetchInt( res, 0 );
        
        //SQL_FetchString( res, 6, szName, sizeof( szName ) );
        
        
        if ( (index = AddCP( runid, cpnum )) != -1 )
        {
            SetBestTime( index, mode, style, time, uid );
            //SetBestName( index, mode, style, szName );
        }
    }
}

public void Thrd_Update( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "inserting player's checkpoint times", GetClientOfUserId( client ), "Something went wrong with your checkpoint times!" );
    }
}

public void Thrd_Empty( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "inserting cp data" );
    }
}