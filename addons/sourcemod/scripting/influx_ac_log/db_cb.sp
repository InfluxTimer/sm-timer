public void Thrd_Empty( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "inserting log data" );
    }
}

public void Thrd_PrintLog( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing client cheat log" );
        return;
    }
    
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    
    char szDate[64];
    char szMap[64];
    char szReason[256];
    char szName[MAX_NAME_LENGTH];
    char szTime[32];
    
    int num = 0;
    
    while ( SQL_FetchRow( res ) )
    {
        PunishTimeToName( SQL_FetchInt( res, 1 ), szTime, sizeof( szTime ) );
        
        if ( szTime[0] != 0 ) Format( szTime, sizeof( szTime ), " | %s", szTime );
        
        
        SQL_FetchString( res, 2, szDate, sizeof( szDate ) );
        SQL_FetchString( res, 3, szMap, sizeof( szMap ) );
        SQL_FetchString( res, 4, szReason, sizeof( szReason ) );
        
        
        if ( szName[0] == 0 )
        {
            SQL_FetchString( res, 5, szName, sizeof( szName ) );
            
            PrintToConsole( client, "Player: %s\n_________________", szName );
        }
        
        
        PrintToConsole( client, "%s | %s%s | %s", szReason, szDate, szTime, szMap );
        
        ++num;
    }
    
    Influx_PrintToChat( _, client, "Printed %i logged activities to console." );
}
