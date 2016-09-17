#if defined _influx_zones_teleport_included
    #endinput
#endif
#define _influx_zones_teleport_included


#define INFLUX_LIB_ZONES_TELE         "influx_zones_teleport"


public SharedPlugin __pl_influx_zones_teleport =
{
    name = INFLUX_LIB_ZONES_TELE,
    file = INFLUX_LIB_ZONES_TELE...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_zones_teleport_SetNTVOptional()
{
}
#endif