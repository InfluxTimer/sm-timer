#if defined _influx_zones_beams_included
    #endinput
#endif
#define _influx_zones_beams_included


#define INFLUX_LIB_ZONES_BEAMS      "influx_zones_beams"

#define INF_CMD_BEAM                "sm_beamsettings"
#define INF_CMD_BEAM_SHOWHIDDEN     "sm_showhiddenzones"


enum DisplayType_t
{
    DISPLAYTYPE_INVALID = -1,
    
    DISPLAYTYPE_NONE,
    DISPLAYTYPE_BEAMS,
    DISPLAYTYPE_BEAMS_FULL,
    //DISPLAYTYPE_LIGHTS,
    
    DISPLAYTYPE_MAX
};


// return Plugin_Stop to stop us from adding it.
forward Action Influx_OnBeamAdd( int zoneid, ZoneType_t zonetype, DisplayType_t &displaytype, int &matindex, float &width, int &framerate, int &speed, float &offset, float &offset_z, int clr[4] );


native bool Influx_SetZoneBeamDisplayType( int zoneid, DisplayType_t displaytype );

// First is XY offset, Second is Z offset.
native bool Influx_GetDefaultBeamOffsets( ZoneType_t zonetype, float offsets[2] );


stock DisplayType_t Inf_DisplayNameToType( const char[] sz )
{
    if ( StrEqual( sz, "beams", false ) )
    {
        return DISPLAYTYPE_BEAMS;
    }
    
    if ( StrEqual( sz, "fullbeams", false ) )
    {
        return DISPLAYTYPE_BEAMS_FULL;
    }
    
    if ( StrEqual( sz, "none", false ) )
    {
        return DISPLAYTYPE_NONE;
    }
    
    return DISPLAYTYPE_INVALID;
}

stock bool Inf_DisplayTypeToName( DisplayType_t type, char[] sz, int len )
{
    switch ( type )
    {
        case DISPLAYTYPE_BEAMS : strcopy( sz, len, "beams" );
        case DISPLAYTYPE_BEAMS_FULL : strcopy( sz, len, "fullbeams" );
        case DISPLAYTYPE_NONE : strcopy( sz, len, "none" );
        default :
        {
            strcopy( sz, len, "beams" );
            return false;
        }
    }
    
    return true;
}

stock bool Inf_DisplayTypeToNameEx( DisplayType_t type, char[] sz, int len )
{
    switch ( type )
    {
        case DISPLAYTYPE_BEAMS : strcopy( sz, len, "Normal" );
        case DISPLAYTYPE_BEAMS_FULL : strcopy( sz, len, "Full" );
        case DISPLAYTYPE_NONE : strcopy( sz, len, "None" );
        default :
        {
            strcopy( sz, len, "N/A" );
            return false;
        }
    }
    
    return true;
}

stock void Inf_OpenBeamSettings( int client )
{
    FakeClientCommand( client, INF_CMD_BEAM );
}


public SharedPlugin __pl_influx_zones_beams =
{
    name = INFLUX_LIB_ZONES_BEAMS,
    file = INFLUX_LIB_ZONES_BEAMS...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_zones_beams_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetDefaultBeamOffsets" );
    MarkNativeAsOptional( "Influx_SetZoneBeamDisplayType" );
}
#endif