#if defined _influx_zones_stage_included
    #endinput
#endif
#define _influx_zones_stage_included


#define INFLUX_LIB_ZONES_STAGE         "influx_zones_stage"


public SharedPlugin __pl_influx_zones_stage =
{
    name = INFLUX_LIB_ZONES_STAGE,
    file = INFLUX_LIB_ZONES_STAGE...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_zones_stage_SetNTVOptional()
{
}
#endif