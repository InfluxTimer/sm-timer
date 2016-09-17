#if defined _influx_zones_freestyle_included
    #endinput
#endif
#define _influx_zones_freestyle_included


#define INFLUX_LIB_ZONES_FS         "influx_zones_freestyle"


// We already check whether it is allowed or not.
native bool Influx_CanClientModeFreestyle( int client );
native bool Influx_CanClientStyleFreestyle( int client );

native bool Influx_IsClientInFreestyle( int client );


public SharedPlugin __pl_influx_zones_freestyle =
{
    name = INFLUX_LIB_ZONES_FS,
    file = INFLUX_LIB_ZONES_FS...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_zones_freestyle_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_CanClientModeFreestyle" );
    MarkNativeAsOptional( "Influx_CanClientStyleFreestyle" );
    
    MarkNativeAsOptional( "Influx_IsClientInFreestyle" );
}
#endif