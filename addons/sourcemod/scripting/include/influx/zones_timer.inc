#if defined _influx_zones_timer_included
    #endinput
#endif
#define _influx_zones_timer_included


#define INFLUX_LIB_ZONES_TIMER      "influx_zones_timer"


public SharedPlugin __pl_influx_zones_timer =
{
    name = INFLUX_LIB_ZONES_TIMER,
    file = INFLUX_LIB_ZONES_TIMER...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_zones_timer_SetNTVOptional()
{
}
#endif