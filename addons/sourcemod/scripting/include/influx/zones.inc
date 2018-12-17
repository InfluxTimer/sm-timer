#if defined _influx_zones_included
    #endinput
#endif
#define _influx_zones_included


#define INFLUX_LIB_ZONES            "influx_zones"

#define INF_TABLE_ZONES             "inf_zones"


#define MAX_ZONE_NAME           32
#define MAX_ZONE_NAME_CELL      MAX_ZONE_NAME / 4


enum
{
    ZONE_NAME[MAX_ZONE_NAME_CELL] = 0,
    
    ZONE_TYPE,
    ZONE_ID,
    
    ZONE_ENTREF,
    
    ZONE_MINS[3],
    ZONE_MAXS[3],
    
    ZONE_SIZE
};

enum ZoneType_t
{
    ZONETYPE_INVALID = -1,
    
    ZONETYPE_START,
    ZONETYPE_END,
    
    ZONETYPE_FS,
    ZONETYPE_BLOCK,
    ZONETYPE_TELE,
    ZONETYPE_CP,
    ZONETYPE_STAGE,
    ZONETYPE_AUTOBHOP,
    ZONETYPE_VALIDATOR,
    
    ZONETYPE_MAX
};

// Deprecated
#define VALID_ZONETYPE(%0)          ( %0 > ZONETYPE_INVALID && %0 < ZONETYPE_MAX )


native ArrayList Influx_GetZonesArray();


native bool Influx_RegZoneType( ZoneType_t type, const char[] szName, const char[] szShortName, bool bHasSettings );
native bool Influx_RemoveZoneType( ZoneType_t type );

native bool Influx_IsValidZoneType( ZoneType_t type );
native bool Influx_GetZoneTypeName( ZoneType_t type, char[] sz, int len );
native bool Influx_GetZoneTypeShortName( ZoneType_t type, char[] sz, int len );
native ZoneType_t Influx_GetZoneTypeByShortName( char[] sz );


native int Influx_FindZoneById( int id );


native bool Influx_CanUserModifyZones( int client );


native bool Influx_GetZoneName( int id, char[] out, int len );
native bool Influx_SetZoneName( int id, const char[] sz );

native bool Influx_GetZoneMinsMaxs( int id, float mins[3], float maxs[3] );


native void Influx_SetDrawBuildingSprite( int client, bool show );



forward void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype );
forward void Influx_OnZoneDeleted( int zoneid, ZoneType_t zonetype );
forward void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent );

forward void Influx_OnRequestZoneTypes();


native bool Influx_DeleteZone( int id );


// These are called after runs have been loaded.

// Called after all zones have been loaded from file.
forward void Influx_OnPostZoneLoad();

// Return Plugin_Stop to give an error, Plugin_Handled if everything worked out.
// Plugin_Continue will silently stop load/save.
forward Action Influx_OnZoneLoad( int zoneid, ZoneType_t zonetype, KeyValues kv );
forward void Influx_OnZoneLoadPost( int zoneid, ZoneType_t zonetype, KeyValues kv );
forward Action Influx_OnZoneSave( int zoneid, ZoneType_t zonetype, KeyValues kv );
forward void Influx_OnZoneSavePost( int zoneid, ZoneType_t zonetype, KeyValues kv );

native void Influx_BuildZone( int client, ZoneType_t zonetype, const char[] szName = "" );

// Not called when using Influx_BuildZone!!
forward Action Influx_OnZoneBuildAsk( int client, ZoneType_t zonetype );

// Called when we want to display the zone settings menu.
forward Action Influx_OnZoneSettings( int client, int zoneid, ZoneType_t zonetype );


stock void Inf_SetZoneProp( int ent, int value )
{
    SetEntProp( ent, Prop_Data, "m_iHealth", value );
}

stock int Inf_GetZoneProp( int ent )
{
    return GetEntProp( ent, Prop_Data, "m_iHealth" );
}

stock bool Inf_IsZoneTypeTimer( ZoneType_t zonetype )
{
    return ( zonetype == ZONETYPE_START || zonetype == ZONETYPE_END );
}

// Deprecated
stock bool Inf_ZoneTypeToName( ZoneType_t type, char[] sz, int len )
{
    switch ( type )
    {
        case ZONETYPE_START : strcopy( sz, len, "Start" );
        case ZONETYPE_END : strcopy( sz, len, "End" );
        case ZONETYPE_FS : strcopy( sz, len, "Freestyle" );
        case ZONETYPE_BLOCK : strcopy( sz, len, "Block" );
        case ZONETYPE_TELE : strcopy( sz, len, "Teleport" );
        case ZONETYPE_CP : strcopy( sz, len, "Checkpoint" );
        case ZONETYPE_STAGE : strcopy( sz, len, "Stage" );
        default :
        {
            strcopy( sz, len, "N/A" );
            return false;
        }
    }
    
    return true;
}

// Deprecated
stock ZoneType_t Inf_ZoneNameToType( char[] sz )
{
    if ( StrEqual( sz, "start", false ) )
    {
        return ZONETYPE_START;
    }
    else if ( StrEqual( sz, "stop", false ) || StrEqual( sz, "end", false ) )
    {
        return ZONETYPE_END;
    }
    else if ( StrEqual( sz, "fs", false ) || StrEqual( sz, "freestyle", false ) )
    {
        return ZONETYPE_FS;
    }
    else if ( StrEqual( sz, "block", false ) )
    {
        return ZONETYPE_BLOCK;
    }
    else if ( StrEqual( sz, "teleport", false ) )
    {
        return ZONETYPE_TELE;
    }
    else if ( StrEqual( sz, "checkpoint", false ) )
    {
        return ZONETYPE_CP;
    }
    else if ( StrEqual( sz, "stage", false ) )
    {
        return ZONETYPE_STAGE;
    }
    
    return ZONETYPE_INVALID;
}

stock void Inf_GetZoneTypeDefColor( ZoneType_t zonetype, int clr[4] )
{
    switch ( zonetype )
    {
        case ZONETYPE_START : clr = { 0, 255, 0, 255 };
        case ZONETYPE_END : clr = { 255, 0, 0, 255 };
        case ZONETYPE_FS : clr = { 0, 255, 255, 255 };
        case ZONETYPE_BLOCK : clr = { 255, 128, 0, 255 };
        case ZONETYPE_TELE : clr = { 255, 255, 0, 255 };
        case ZONETYPE_CP : clr = { 255, 0, 255, 255 };
        case ZONETYPE_STAGE : clr = { 128, 255, 0, 255 };
        case ZONETYPE_AUTOBHOP : clr = { 255, 0, 162, 255 };
        default : clr = { 255, 255, 255, 255 };
    }
}


stock void Inf_OpenZoneMenu( int client ) { FakeClientCommand( client, "sm_zone" ); }

stock void Inf_OpenCreateZoneMenu( int client ) { FakeClientCommand( client, "sm_createzone" ); }

stock void Inf_OpenZoneSettingsMenu( int client ) { FakeClientCommand( client, "sm_zonesettings" ); }


stock bool Inf_ParseZoneSettings( const char[] sz, int &zoneid, int &type, int &id )
{
    char buffer[3][8];
    if ( ExplodeString( sz, "_", buffer, sizeof( buffer ), sizeof( buffer[] ) ) != sizeof( buffer ) )
    {
        return false;
    }
    
    zoneid = StringToInt( buffer[0] );
    type = StringToInt( buffer[1] );
    id = StringToInt( buffer[2] );
    
    
    if ( id >= 32 ) return false;
    
    return true;
}


public SharedPlugin __pl_influx_zones =
{
    name = INFLUX_LIB_ZONES,
    file = INFLUX_LIB_ZONES...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_zones_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_BuildZone" );
    MarkNativeAsOptional( "Influx_CanUserModifyZones" );
    MarkNativeAsOptional( "Influx_DeleteZone" );
    MarkNativeAsOptional( "Influx_FindZoneById" );
    MarkNativeAsOptional( "Influx_GetZoneMinsMaxs" );
    MarkNativeAsOptional( "Influx_GetZoneName" );
    MarkNativeAsOptional( "Influx_GetZoneTypeByShortName" );
    MarkNativeAsOptional( "Influx_GetZoneTypeName" );
    MarkNativeAsOptional( "Influx_GetZoneTypeShortName" );
    MarkNativeAsOptional( "Influx_GetZonesArray" );
    MarkNativeAsOptional( "Influx_IsValidZoneType" );
    MarkNativeAsOptional( "Influx_RegZoneType" );
    MarkNativeAsOptional( "Influx_RemoveZoneType" );
    MarkNativeAsOptional( "Influx_SetDrawBuildingSprite" );
    MarkNativeAsOptional( "Influx_SetZoneName" );
}
#endif