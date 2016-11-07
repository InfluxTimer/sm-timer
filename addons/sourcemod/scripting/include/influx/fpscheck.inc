#if defined _influx_fpscheck_included
    #endinput
#endif
#define _influx_fpscheck_included


#define INFLUX_LIB_FPSCHECK         "influx_fpscheck"


enum FpsVal_t
{
    FPSVAL_NOTCACHED = 0,
    FPSVAL_INVALID,
    FPSVAL_CHEATED,
    FPSVAL_VALID
};


forward void Influx_OnRequestFpsChecks();

native void Influx_AddFpsCheck( int mode );
native bool Influx_RemoveFpsCheck( int mode );


public SharedPlugin __pl_influx_fpscheck =
{
    name = INFLUX_LIB_FPSCHECK,
    file = INFLUX_LIB_FPSCHECK...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_fpscheck_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_AddFpsCheck" );
    MarkNativeAsOptional( "Influx_RemoveFpsCheck" );
}
#endif