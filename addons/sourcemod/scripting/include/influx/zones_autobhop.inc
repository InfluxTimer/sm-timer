#if defined _influx_zones_autobhop_included
    #endinput
#endif
#define _influx_zones_autobhop_included


#define INFLUX_LIB_ZONES_AUTO       "influx_zones_autobhop"


public SharedPlugin __pl_influx_zones_autobhop =
{
    name = INFLUX_LIB_ZONES_AUTO,
    file = INFLUX_LIB_ZONES_AUTO...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_zones_autobhop_SetNTVOptional()
{
    //MarkNativeAsOptional( "" );
}
#endif