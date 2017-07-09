#if defined _influx_style_tas_included
    #endinput
#endif
#define _influx_style_tas_included


#define INFLUX_LIB_STYLE_TAS            "influx_style_tas"


native float Influx_GetClientTASTime( int client );


public SharedPlugin __pl_influx_style_tas =
{
    name = INFLUX_LIB_STYLE_TAS,
    file = INFLUX_LIB_STYLE_TAS...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_style_tas_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetClientTASTime" );
}
#endif