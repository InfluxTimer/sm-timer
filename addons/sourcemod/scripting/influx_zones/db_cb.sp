public void Thrd_Empty( Handle db, Handle res, const char[] szError, int client )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "inserting data into database", client ? GetClientOfUserId( client ) : 0, "An error occurred while saving your data!" );
    }
}

public void Thrd_GetZones( Handle db, Handle res, const char[] szError, any data )
{
    if ( res == null )
    {
        Inf_DB_LogError( db, "getting zones data" );
        return;
    }
    
    
    // Attempt to load em from file if we have none in db.
    if ( !SQL_GetRowCount( res ) )
    {
        LoadZones( true, false );
        return;
    }
    
    
    decl String:zonedata[1024];
    int zoneid;
    KeyValues kv;
    
    
    while ( SQL_FetchRow( res ) )
    {
        zoneid = SQL_FetchInt( res, 0 );
        SQL_FetchString( res, 1, zonedata, sizeof( zonedata ) );
        
        kv = new KeyValues( "" );
        if ( !kv.ImportFromString( zonedata, "" ) )
        {
            LogError( INF_CON_PRE..."Failed to import zone of id %i keyvalue data from database! Zone data:\n%s", zoneid, zonedata );

            delete kv;
            continue;
        }
        
        
        LoadZoneFromKv( kv );
        
        delete kv;
    }
    
    SendZonesLoadPost();
    
    PrintToServer( INF_CON_PRE..."Loaded %i zones from database!", g_hZones.Length );
}
