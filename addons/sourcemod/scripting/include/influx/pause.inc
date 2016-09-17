#if defined _influx_pause_included
    #endinput
#endif
#define _influx_pause_included


#define INFLUX_LIB_PAUSE      "influx_pause"


native bool Influx_IsClientPaused( int client );
native void Influx_PauseClientRun( int client );
native void Influx_ContinueClientRun( int client );

native float Influx_GetClientPausedTime( int client );


public SharedPlugin __pl_influx_pause =
{
	name = INFLUX_LIB_PAUSE,
	file = INFLUX_LIB_PAUSE...".smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_pause_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_IsClientPaused" );
    
    MarkNativeAsOptional( "Influx_PauseClientRun" );
    MarkNativeAsOptional( "Influx_ContinueClientRun" );
    
    MarkNativeAsOptional( "Influx_GetClientPausedTime" );
}
#endif