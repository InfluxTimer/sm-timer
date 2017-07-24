#if defined _influx_ac_log_included
    #endinput
#endif
#define _influx_ac_log_included



#define INFLUX_LIB_AC_LOG           "influx_ac_log"


#define INF_TABLE_ACLOG_LOG         "inf_aclog_log"
#define INF_TABLE_ACLOG_NOTIFY      "inf_aclog_notify"


#define ACLOG_NOPUNISH              -2 // This means let the logging module dictate what the punishment is.
#define ACLOG_KICK                  -1


native bool Influx_LogCheat( int client, const char[] szReasonId, bool bNotifyAdmin, const char[] szReasonFormat, any ... );
native bool Influx_PunishCheat( int client, const char[] szReasonId, int override_punishtime = ACLOG_NOPUNISH, const char[] kick_reason, const char[] szReasonFormat, any ... );


// Return != Plugin_Continue to not log.
// NOTE: It does not mean that the player is not punished/notified to admin. Edit the arguments.
// Reason id is a short string to identify reason.
forward Action Influx_OnLogCheat( int client, const char[] szReasonId, int &punishtime, bool &bNotifyAdmin );


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