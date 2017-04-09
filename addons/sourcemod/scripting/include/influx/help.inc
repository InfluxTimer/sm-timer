#if defined _influx_help_included
    #endinput
#endif
#define _influx_help_included


#define INFLUX_LIB_HELP             "influx_help"


// Waiting to be removed.
#define Influx_RequestHelpCmds      Influx_OnRequestHelpCmds

forward void Influx_OnRequestHelpCmds();


native bool Influx_AddHelpCommand( const char[] szCommand, const char[] szMsg, bool bAdminOnly = false );
native bool Influx_RemoveHelpCommand( const char[] szCommand );


public SharedPlugin __pl_influx_help =
{
    name = INFLUX_LIB_HELP,
    file = INFLUX_LIB_HELP...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_help_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_AddHelpCommand" );
    MarkNativeAsOptional( "Influx_RemoveHelpCommand" );
}
#endif