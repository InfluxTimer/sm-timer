#if defined _influx_strfsync_included
    #endinput
#endif
#define _influx_strfsync_included


#define INFLUX_LIB_STRFSYNC         "influx_strfsync"


native float Influx_GetClientStrafeSync( int client );


public SharedPlugin __pl_influx_strfsync =
{
    name = INFLUX_LIB_STRFSYNC,
    file = INFLUX_LIB_STRFSYNC...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_strfsync_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetClientStrafeSync" );
}
#endif