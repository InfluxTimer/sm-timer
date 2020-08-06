stock void ReadZoneFile()
{
#if defined DEBUG_LOADZONES
    PrintToServer( INF_DEBUG_PRE..."Attempting to load zone file with %i zonestypes.", g_hZoneTypes.Length );
#endif

    // We've already loaded zones for this map.
    if ( g_bZonesLoaded )
    {
#if defined DEBUG_LOADZONES
        PrintToServer( INF_DEBUG_PRE..."Zones are already loaded!" );
#endif
        return;
    }
    
    g_bZonesLoaded = true;
    
    
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "influxzones" );
    
    if ( !DirExistsEx( szPath ) )
    {
        LogError( INF_CON_PRE..."Couldn't build path to zone files '%s'!", szPath );
        return;
    }
    
    
    char szMap[64];
    GetCurrentMapSafe( szMap, sizeof( szMap ) );
    Format( szPath, sizeof( szPath ), "%s/%s.ini", szPath, szMap );
    
    
    KeyValues kv = new KeyValues( "Zones" );
    kv.ImportFromFile( szPath );
    
    if ( !kv.GotoFirstSubKey() )
    {
#if defined DEBUG_LOADZONES
        PrintToServer( INF_DEBUG_PRE..."No zone file exists '%s'!", szPath );
#endif
        delete kv;
        return;
    }
    
    
    
    do
    {
        LoadZoneFromKv( kv );
    }
    while( kv.GotoNextKey() );
    
    delete kv;
    
    
    PrintToServer( INF_CON_PRE..."Loaded %i zones from file!", g_hZones.Length );
    
    //CheckRuns();
}

stock int WriteZoneFile( ArrayList kvs )
{
    decl String:szMap[64];
    decl String:szPath[PLATFORM_MAX_PATH];
    GetCurrentMapSafe( szMap, sizeof( szMap ) );
    
    BuildPath( Path_SM, szPath, sizeof( szPath ), "influxzones/%s.ini", szMap );
    
    
    int num = 0;
    char szZoneName[64];
    
    
    KeyValues kv = new KeyValues( "Zones" );
    
    for ( int i = 0; i < kvs.Length; i++ )
    {
        KeyValues zonekv = view_as<KeyValues>( kvs.Get( i, 0 ) );
        
        zonekv.GetSectionName( szZoneName, sizeof( szZoneName ) );
        kv.JumpToKey( szZoneName, true );
        
        kv.Import( zonekv );
        kv.GoBack();
        
        ++num;
    }
    
    
    if ( num )
    {
        kv.Rewind();
        
        if ( !kv.ExportToFile( szPath ) )
        {
            LogError( INF_CON_PRE..."Can't save zone file '%s'!!", szPath );
        }
    }
    else if ( kvs.Length > 0 )
    {
        LogError( INF_CON_PRE..."No valid zones exist to save. Can't save zone file '%s'!", szPath );
    }
    
    
    delete kv;
    
    return num;
}
