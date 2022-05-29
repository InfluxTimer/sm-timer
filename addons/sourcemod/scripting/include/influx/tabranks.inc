#if defined _influx_tabranks_included
    #endinput
#endif
#define _influx_tabranks_included

/*
 *  On Client rank name already read
 *
 *  @param iClient      Client index
 *  @param szRankname   Client rankname with out colors (fl. copyback)    
 *  @param iSize        size of string
 *
 *
 *  @noreturn
*/
forward void Influx_trank_OnGetRank(int iClient, char[] szRankname, int iSize);

/*
 *  Status of send fake rank to client was changed
 *
 *  @param iClient      Client index
 *  @param oldVal       old Value
 *  @param newVal       new value
 *  @param IsNative     who changed
 *
 *
 *  @noreturn
*/
forward void Influx_trank_SendToClient(int iClient, bool oldVal, bool newVal, bool IsNative);


/*
 *  Change status of send fake rank to client
 *
 *  @param iClient      Client index
 *  @param value        True - send| false - otherwise
 *
 *  @return             true - changed success, false - invalid client index
*/
native bool influx_trank_SendToClient(int iClient, bool value);

public SharedPlugin __pl_influx_tabranks =
{
    name = "influx_tabranks",
    file = "influx_tabranks_csgo.smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_tabranks_SetNTVOptional()
{
    MarkNativeAsOptional("influx_trank_SendToClient");
}
#endif