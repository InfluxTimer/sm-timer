#if defined _influx_jumps_included
    #endinput
#endif
#define _influx_jumps_included


#define INFLUX_LIB_JUMPS          "influx_jumps"


forward Action Influx_ShouldCountJumps( int client );


native int Influx_GetClientJumpCount( int client );
native bool Influx_IsCountingJumps( int client );


public SharedPlugin __pl_influx_jumps =
{
    name = INFLUX_LIB_JUMPS,
    file = INFLUX_LIB_JUMPS...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_jumps_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetClientJumpCount" );
    MarkNativeAsOptional( "Influx_IsCountingJumps" );
}
#endif