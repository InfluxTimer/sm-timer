#if defined _influx_silent_chatcmds_included
    #endinput
#endif
#define _influx_silent_chatcmds_included


#define INFLUX_LIB_SILENT_CHATCMDS      "influx_silent_chatcmds"


native bool Influx_ShouldSilenceCmd( const char[] szMsg );


public SharedPlugin __pl_influx_silent_chatcmds =
{
    name = INFLUX_LIB_SILENT_CHATCMDS,
    file = INFLUX_LIB_SILENT_CHATCMDS...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_silent_chatcmds_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_ShouldSilenceCmd" );
}
#endif
