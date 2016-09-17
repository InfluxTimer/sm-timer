#if defined _influx_zones_block_included
    #endinput
#endif
#define _influx_zones_block_included


#define INFLUX_LIB_ZONES_BLOCK      "influx_zones_block"


public SharedPlugin __pl_influx_zones_block =
{
    name = INFLUX_LIB_ZONES_BLOCK,
    file = INFLUX_LIB_ZONES_BLOCK...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_zones_block_SetNTVOptional()
{
    //MarkNativeAsOptional( "" );
}
#endif