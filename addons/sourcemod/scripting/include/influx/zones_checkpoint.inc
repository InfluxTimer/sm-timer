#if defined _influx_zones_checkpoint_included
    #endinput
#endif
#define _influx_zones_checkpoint_included


#define INFLUX_LIB_ZONES_CP         "influx_zones_checkpoint"


#define INF_TABLE_CPTIMES           "inf_cptimes"


#define MAX_CP_NAME                 32
#define MAX_CP_NAME_CELL            MAX_CP_NAME / 4


// Client has activated a checkpoint.
// Use natives below to access more info.
forward void Influx_OnClientCPSavePost( int client, int cpnum );


// Will return 0 if client hasn't touched a checkpoint yet.
native int Influx_GetClientLastCP( int client );

// Engine time we last touched cp.
native float Influx_GetClientLastCPTouch( int client );

// Actual times.
native float Influx_GetClientLastCPBestTime( int client ); // Absolute best time for cp (usually same as SR)
native float Influx_GetClientLastCPPBTime( int client );
native float Influx_GetClientLastCPSRTime( int client ); // Server record's time for cp
native float Influx_GetClientLastCPTime( int client );



native void Influx_AddCP( int runid, int cpnum, const char[] szName );

native void Influx_SaveClientCP( int client, int cpnum );



//native void Influx_PrintCPTimes( int client, int uid, int mapid, int runid, int mode, int style );


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
    MarkNativeAsOptional( "Influx_AddCP" );
    MarkNativeAsOptional( "Influx_GetClientLastCP" );
    MarkNativeAsOptional( "Influx_GetClientLastCPBestTime" );
    MarkNativeAsOptional( "Influx_GetClientLastCPPBTime" );
    MarkNativeAsOptional( "Influx_GetClientLastCPSRTime" );
    MarkNativeAsOptional( "Influx_GetClientLastCPTime" );
    MarkNativeAsOptional( "Influx_GetClientLastCPTouch" );
    //MarkNativeAsOptional( "Influx_PrintCPTimes" );
    MarkNativeAsOptional( "Influx_SaveClientCP" );
}
#endif