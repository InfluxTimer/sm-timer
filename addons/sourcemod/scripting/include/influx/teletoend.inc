#if defined _influx_teletoend_included
    #endinput
#endif
#define _influx_teletoend_included


#define INFLUX_LIB_TELETOEND      "influx_teletoend"


// Searching for ending position.
forward Action Influx_OnSearchEnd( int runid, float pos[3] );


public SharedPlugin __pl_influx_teletoend =
{
    name = INFLUX_LIB_TELETOEND,
    file = INFLUX_LIB_TELETOEND...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_teletoend_SetNTVOptional()
{
}
#endif