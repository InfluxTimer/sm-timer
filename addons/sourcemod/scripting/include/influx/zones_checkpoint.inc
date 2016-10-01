#if defined _influx_zones_checkpoint_included
    #endinput
#endif
#define _influx_zones_checkpoint_included


#define INFLUX_LIB_ZONES_CP         "influx_zones_checkpoint"


#define INF_TABLE_CPTIMES           "inf_cptimes"


#define MAX_CP_NAME                 32
#define MAX_CP_NAME_CELL            MAX_CP_NAME / 4


public SharedPlugin __pl_influx_zones_checkpoint =
{
    name = INFLUX_LIB_ZONES_CP,
    file = INFLUX_LIB_ZONES_CP...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_zones_checkpoint_SetNTVOptional()
{
}
#endif