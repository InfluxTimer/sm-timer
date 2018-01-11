public void Thrd_Empty( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "inserting log data", client ? GetClientOfUserId( client ) : 0, "An error occurred saving data!" );
    }
}

public void Thrd_PrintLog( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing cheat log" );
        return;
    }
    
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    
    char szDate[64];
    char szMap[64];
    char szReason[256];
    char szName[MAX_NAME_LENGTH];
    char szTime[32];
    
    int num = 0;
    
    int uid;
    int lastuid = -1;
    
    while ( SQL_FetchRow( res ) )
    {
        uid = SQL_FetchInt( res, 0 );
        
        PunishTimeToName( SQL_FetchInt( res, 1 ), szTime, sizeof( szTime ) );
        
        if ( szTime[0] != 0 ) Format( szTime, sizeof( szTime ), " | %s", szTime );
        
        
        SQL_FetchString( res, 2, szDate, sizeof( szDate ) );
        SQL_FetchString( res, 3, szMap, sizeof( szMap ) );
        SQL_FetchString( res, 4, szReason, sizeof( szReason ) );
        
        
        if ( lastuid != uid )
        {
            SQL_FetchString( res, 5, szName, sizeof( szName ) );
            
            PrintToConsole( client, "Player: %s\n_________________", szName );
        }
        
        
        PrintToConsole( client, "%s | %s%s | %s", szReason, szDate, szTime, szMap );
        
        
        lastuid = uid;
        ++num;
    }
    
    Influx_PrintToChat( _, client, "Printed {MAINCLR1}%i{CHATCLR} logged activities to console. (!markaclogseen)", num );
}

public void Thrd_PrintUnseenNum( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "printing unseen activity count" );
        return;
    }
    
    if ( !(client = GetClientOfUserId( client )) ) return;
    
    if ( !SQL_GetRowCount( res ) ) return;
    
    if ( !SQL_FetchRow( res ) ) return;
    
    
    int num = SQL_FetchInt( res, 0 );
    if ( num < 1 ) return;
    
    
    Influx_PrintToChat( _, client, "There are {MAINCLR1}%i{CHATCLR} unseen logged activities. (!printunseenaclog/!printaclog)", num );
}
