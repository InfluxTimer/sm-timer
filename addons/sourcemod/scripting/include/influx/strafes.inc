#if defined _influx_strafes_included
    #endinput
#endif
#define _influx_strafes_included


#define INFLUX_LIB_STRAFES          "influx_strafes"


forward Action Influx_ShouldCountStrafes( int client );

native int Influx_GetClientStrafeCount( int client );
native bool Influx_IsCountingStrafes( int client );


public SharedPlugin __pl_influx_strafes =
{
    name = INFLUX_LIB_STRAFES,
    file = INFLUX_LIB_STRAFES...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_strafes_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetClientStrafeCount" );
    MarkNativeAsOptional( "Influx_IsCountingStrafes" );
}
#endif