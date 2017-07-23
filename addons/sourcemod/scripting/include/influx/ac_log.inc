#if defined _influx_ac_log_included
    #endinput
#endif
#define _influx_ac_log_included



#define INFLUX_LIB_AC_LOG           "influx_ac_log"


#define INF_TABLE_ACLOG_LOG         "inf_aclog_log"


#define ACLOG_NOPUNISH              -2 // This means let the logging module dictate what the punishment is.
#define ACLOG_KICK                  -1


native bool Influx_LogCheat( int client, const char[] format, any ... );
native bool Influx_PunishCheat( int client, int override_punishtime = ACLOG_NOPUNISH, const char[] kick_reason, const char[] format, any ... );


public SharedPlugin __pl_influx_ac_log =
{
    name = INFLUX_LIB_AC_LOG,
    file = INFLUX_LIB_AC_LOG...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_ac_log_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_LogCheat" );
    MarkNativeAsOptional( "Influx_PunishCheat" );
}
#endif