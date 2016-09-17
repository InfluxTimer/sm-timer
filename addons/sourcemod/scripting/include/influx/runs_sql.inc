#if defined _influx_runs_sql_included
    #endinput
#endif
#define _influx_runs_sql_included


#define INFLUX_LIB_RUNS_SQL         "influx_runs_sql"


#define INF_TABLE_RUNS              "inf_runs"


forward void Influx_OnRunLoad_SQL( int runid, Handle res );


public SharedPlugin __pl_influx_runs_sql =
{
    name = INFLUX_LIB_RUNS_SQL,
    file = INFLUX_LIB_RUNS_SQL...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_runs_sql_SetNTVOptional()
{
}
#endif