#if defined _influx_simpleranks_chat_included
    #endinput
#endif
#define _influx_simpleranks_chat_included


#define INFLUX_LIB_SIMPLERANKS_CHAT     "influx_simpleranks_chat"


public SharedPlugin __pl_influx_simpleranks_chat =
{
    name = INFLUX_LIB_SIMPLERANKS_CHAT,
    file = INFLUX_LIB_SIMPLERANKS_CHAT...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_simpleranks_chat_SetNTVOptional()
{
}
#endif
