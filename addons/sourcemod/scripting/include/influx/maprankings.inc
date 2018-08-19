#if defined _influx_maprankings_included
    #endinput
#endif
#define _influx_maprankings_included


#define INFLUX_LIB_MAPRANKS         "influx_maprankings"


forward void Influx_OnClientRankingsCached( int client );

native int Influx_GetClientCurrentMapRank( int client );
native int Influx_GetClientCurrentMapRankCount( int client );

native int Influx_GetClientMapRank( int client, int runid, int mode, int style );

native int Influx_GetRunMapRankCount( int runid, int mode, style );


public SharedPlugin __pl_influx_maprankings =
{
    name = INFLUX_LIB_MAPRANKS,
    file = INFLUX_LIB_MAPRANKS...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_maprankings_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetClientCurrentMapRank" );
    MarkNativeAsOptional( "Influx_GetClientCurrentMapRankCount" );
    MarkNativeAsOptional( "Influx_GetClientMapRank" );
    MarkNativeAsOptional( "Influx_GetRunMapRankCount" );
}
#endif