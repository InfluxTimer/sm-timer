#include <sourcemod>

#include <influx/core>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Disable Radio",
    description = "Stops radio sounds.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // Disable radio menu cmds.
    AddCommandListener( Lstnr_Radio, "radio1" );
    AddCommandListener( Lstnr_Radio, "radio2" );
    AddCommandListener( Lstnr_Radio, "radio3" );
    
    AddCommandListener( Lstnr_Radio, "coverme" );
    AddCommandListener( Lstnr_Radio, "enemydown" );
    AddCommandListener( Lstnr_Radio, "enemyspot" );
    AddCommandListener( Lstnr_Radio, "fallback" );
    AddCommandListener( Lstnr_Radio, "followme" );
    AddCommandListener( Lstnr_Radio, "getout" );
    AddCommandListener( Lstnr_Radio, "go" );
    AddCommandListener( Lstnr_Radio, "holdpos" );
    AddCommandListener( Lstnr_Radio, "inposition" );
    AddCommandListener( Lstnr_Radio, "needbackup" );
    AddCommandListener( Lstnr_Radio, "negative" );
    AddCommandListener( Lstnr_Radio, "regroup" );
    AddCommandListener( Lstnr_Radio, "report" );
    AddCommandListener( Lstnr_Radio, "reportingin" );
    AddCommandListener( Lstnr_Radio, "roger" );
    AddCommandListener( Lstnr_Radio, "sectorclear" );
    AddCommandListener( Lstnr_Radio, "sticktog" );
    AddCommandListener( Lstnr_Radio, "stormfront" );
    AddCommandListener( Lstnr_Radio, "takepoint" );
    AddCommandListener( Lstnr_Radio, "takingfire" );
    
    // CS:GO
    AddCommandListener( Lstnr_Radio, "cheer" );
    AddCommandListener( Lstnr_Radio, "compliment" );
    AddCommandListener( Lstnr_Radio, "thanks" );
}

public Action Lstnr_Radio( int client, const char[] command, int argc )
{
    return Plugin_Handled;
}