#if defined _influx_zones_checkpoint_included
    #endinput
#endif
#define _influx_zones_checkpoint_included


#define INFLUX_LIB_ZONES_CP         "influx_zones_checkpoint"


#define INF_TABLE_CPTIMES           "inf_cptimes"


#define MAX_CP_NAME                 32
#define MAX_CP_NAME_CELL            MAX_CP_NAME / 4


// Client has activated a checkpoint.
forward void Influx_OnClientCPSavePost( int client, int cpnum );


native void Influx_SaveClientCP( int client, int cpnum );
native void Influx_AddCP( int runid, int cpnum, const char[] szName );

// Engine time we last touched cp.
native float Influx_GetClientLastCPTouch( int client );

// Actual times.
native float Influx_GetClientLastCPTime( int client );
native float Influx_GetClientLastCPBestTime( int client );


native void Influx_PrintCPTimes( int client, int uid, int mapid, int runid, int mode, int style );


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
    MarkNativeAsOptional( "Influx_GetClientLastCPTouch" );
    MarkNativeAsOptional( "Influx_GetClientLastCPTime" );
    MarkNativeAsOptional( "Influx_GetClientLastCPBestTime" );
    MarkNativeAsOptional( "Influx_PrintCPTimes" );
    MarkNativeAsOptional( "Influx_SaveClientCP" );
}
#endif