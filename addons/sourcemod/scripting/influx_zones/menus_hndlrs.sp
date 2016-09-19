public int Hndlr_ZoneMain( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !CanUserModifyZones( client ) ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    if ( StrEqual( szInfo, "grid" ) )
    {
        if ( g_nBuildingGridSize[client] < 1 || g_nBuildingGridSize[client] >= 32 )
        {
            g_nBuildingGridSize[client] = 1;
        }
        else
        {
            g_nBuildingGridSize[client] *= 2;
        }
        
        Inf_OpenZoneMenu( client );
    }
    else
    {
        FakeClientCommand( client, szInfo );
    }
    
    return 0;
}

public int Hndlr_CreateZone( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !CanUserModifyZones( client ) ) return 0;
    
    
    char szInfo[6];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    ZoneType_t zonetype = view_as<ZoneType_t>( StringToInt( szInfo ) );
    if ( !VALID_ZONETYPE( zonetype ) )
    {
        FakeClientCommand( client, "sm_createzone" );
        return 0;
    }
    
    
    char szType[32];
    Inf_ZoneTypeToName( zonetype, szType, sizeof( szType ) );
    
    FakeClientCommand( client, "sm_createzone %s", szType );
    
    
    return 0;
}

public int Hndlr_DeleteZone( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !CanUserModifyZones( client ) ) return 0;
    
    
    char szInfo[16];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int zoneid = StringToInt( szInfo[1] );
    bool bFindZone = ( szInfo[0] != 'z' ) ? true : false;
    
    
    
    // We want to delete a specific zone.
    if ( !bFindZone )
    {
        int i = FindZoneById( zoneid );
        
        if ( i != -1 )
        {
            DeleteZoneWithClient( client, i );
        }
    }
    // Find zone we are currently in.
    else
    {
        float pos[3];
        GetClientAbsOrigin( client, pos );
        
        int i = -1;
        while ( (i = GetZoneFromPos( i, pos )) != -1 )
        {
            DeleteZoneWithClient( client, i );
        }
    }
    
    //FakeClientCommand( client, "sm_deletezone" );
    Inf_OpenZoneMenu( client );
    
    return 0;
}

public int Hndlr_ZoneSettings( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !CanUserModifyZones( client ) ) return 0;
    
    
    char szInfo[16];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int zoneid = StringToInt( szInfo[1] );
    bool bFindZone = ( szInfo[0] != 'z' ) ? true : false;
    
    int izone = -1;
    if ( bFindZone )
    {
        float pos[3];
        GetClientAbsOrigin( client, pos );
        
        izone = GetZoneFromPos( -1, pos );
    }
    else
    {
        izone = FindZoneById( zoneid );
    }
    
    
    if ( izone != -1 )
    {
        Action res;
        
        Call_StartForward( g_hForward_OnZoneSettings );
        Call_PushCell( client );
        Call_PushCell( g_hZones.Get( izone, ZONE_ID ) );
        Call_PushCell( g_hZones.Get( izone, ZONE_TYPE ) );
        Call_Finish( res );
        
        
        if ( res == Plugin_Continue )
        {
            Influx_PrintToChat( _, client, "Sorry, no settings can be set for this zone!" );
            Inf_OpenZoneMenu( client );
        }
    }
    else
    {
        Inf_OpenZoneMenu( client );
    }
    
    return 0;
}