#if defined _influx_teams_included
    #endinput
#endif
#define _influx_teams_included


#define INFLUX_LIB_TEAMS            "influx_teams"


native int Influx_GetPreferredTeam();
native void Influx_SpawnPlayer( int client );


public SharedPlugin __pl_influx_teams =
{
    name = INFLUX_LIB_TEAMS,
    file = INFLUX_LIB_TEAMS...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_teams_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetPreferredTeam" );
    MarkNativeAsOptional( "Influx_SpawnPlayer" );
}
#endif