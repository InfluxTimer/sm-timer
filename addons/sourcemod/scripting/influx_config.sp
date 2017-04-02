#include <sourcemod>

#include <influx/core>



#define CONFIG_NAME         "influx.cfg"


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Config",
    description = "Simply executes "...CONFIG_NAME..." file.",
    version = INF_VERSION
};

public void OnConfigsExecuted()
{
    ServerCommand( "exec "...CONFIG_NAME );
}