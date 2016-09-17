#if defined _influx_colorchat_included
    #endinput
#endif
#define _influx_colorchat_included


#define INFLUX_LIB_COLORCHAT            "influx_colorchat"


native void Influx_Chat( int author, const int[] clients, int nClients, const char[] msg, bool prefix );


public SharedPlugin __pl_influx_colorchat =
{
    name = INFLUX_LIB_COLORCHAT,
    file = INFLUX_LIB_COLORCHAT...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_colorchat_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_Chat" );
}
#endif