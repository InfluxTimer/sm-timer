#if defined _influx_truevel_included
    #endinput
#endif
#define _influx_truevel_included


#define INFLUX_LIB_TRUEVEL      "influx_truevel"


native bool Influx_IsClientUsingTruevel( int client );


public SharedPlugin __pl_influx_truevel =
{
    name = INFLUX_LIB_TRUEVEL,
    file = INFLUX_LIB_TRUEVEL...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_truevel_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_IsClientUsingTruevel" );
}
#endif