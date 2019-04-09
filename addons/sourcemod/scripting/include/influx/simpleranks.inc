#if defined _influx_simpleranks_included
    #endinput
#endif
#define _influx_simpleranks_included


#define INFLUX_LIB_SIMPLERANKS      "influx_simpleranks"



native void Influx_GetClientSimpleRank( int client, char[] out, int len );
native int Influx_GetClientSimpleRankPoints( int client );
native bool Influx_AddClientSimpleRankPoints( int client, int iPoints );


public SharedPlugin __pl_influx_simpleranks =
{
    name = INFLUX_LIB_SIMPLERANKS,
    file = INFLUX_LIB_SIMPLERANKS...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_simpleranks_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetClientSimpleRank" );
    MarkNativeAsOptional( "Influx_GetClientSimpleRankPoints" );
    MarkNativeAsOptional( "Influx_AddClientSimpleRankPoints" );
}
#endif