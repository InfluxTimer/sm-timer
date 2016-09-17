// NATIVES
public int Native_GetZonesArray( Handle hPlugin, int nParms )
{
    return view_as<int>( g_hZones );
}

public int Native_FindZoneById( Handle hPlugin, int nParms )
{
    return FindZoneById( GetNativeCell( 1 ) );
}

public int Native_GetZoneName( Handle hPlugin, int nParms )
{
    int len = GetNativeCell( 3 );
    int index = FindZoneById( GetNativeCell( 1 ) );
    
    if ( index == -1 )
    {
        SetNativeString( 2, "N/A", len, true );
        return 0;
    }
    
    decl String:sz[MAX_ZONE_NAME];
    g_hZones.GetString( index, sz, sizeof( sz ) );
    
    SetNativeString( 2, sz, len, true );
    
    return 1;
}

public int Native_SetZoneName( Handle hPlugin, int nParms )
{
    int index = FindZoneById( GetNativeCell( 1 ) );
    if ( index == -1 ) return 0;
    
    
    decl String:szZone[MAX_ZONE_NAME];
    GetNativeString( 2, szZone, sizeof( szZone ) );
    
    g_hZones.SetString( index, szZone );
    
    return 1;
}

public int Native_GetZoneMinsMaxs( Handle hPlugin, int nParms )
{
    int index = FindZoneById( GetNativeCell( 1 ) );
    if ( index == -1 ) return 0;
    
    float mins[3], maxs[3];
    GetZoneMinsMaxsByIndex( index, mins, maxs );
    
    SetNativeArray( 2, mins, sizeof( mins ) );
    SetNativeArray( 3, maxs, sizeof( maxs ) );
    
    return 1;
}

public int Native_BuildZone( Handle hPlugin, int nParms )
{
    decl String:szName[MAX_ZONE_NAME];
    GetNativeString( 3, szName, sizeof( szName ) );
    
    StartToBuild( GetNativeCell( 1 ), GetNativeCell( 2 ), szName );
    
    return 1;
}

public int Native_DeleteZone( Handle hPlugin, int nParms )
{
    return DeleteZone( GetNativeCell( 1 ) );
}

public int Native_CanUserModifyZones( Handle hPlugin, int nParms )
{
    return CanUserModifyZones( GetNativeCell( 1 ) );
}