#include <sourcemod>
#include <sdkhooks>

#include <influx/core>
#include <influx/ac_log>

#include <msharedutil/misc>


// CONVARS
ConVar g_ConVar_PunishType;


#include "influx_ac_log/db.sp"
#include "influx_ac_log/natives.sp"

public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Anti-Cheat | Log",
    description = "Logs suspicious activity.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    RegPluginLibrary( INFLUX_LIB_AC_LOG );
    
    //g_bLate = late;
    
    // NATIVES
    CreateNative( "Influx_LogCheat", Native_LogCheat );
    CreateNative( "Influx_PunishCheat", Native_PunishCheat );
}

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_PunishType = CreateConVar( "influx_ac_log_defaultpunish", "-1", "-2 = Disable, -1 = Kick, 0 = Perma ban, >0 = Ban for this many minutes.", FCVAR_NOTIFY, true, -2.0 );
    
    
    // CMDS
    RegConsoleCmd( "sm_printcheatlog", Cmd_PrintCheatLog );
}

public void OnAllPluginsLoaded()
{
    DB_Init();
}

public Action Cmd_PrintCheatLog( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !args ) return Plugin_Handled;
    
    
    bool bFound = false;
    
    char szArg[64];
    GetCmdArgString( szArg, sizeof( szArg ) );
    
    int targets[1];
    char szTemp[1];
    bool bUseless;
    if ( ProcessTargetString(
        szArg,
        0,
        targets,
        sizeof( targets ),
        COMMAND_FILTER_NO_MULTI,
        szTemp,
        sizeof( szTemp ),
        bUseless ) )
    {
        int target = targets[0];
        
        if (target != client
        &&  IS_ENT_PLAYER( target )
        &&  IsClientInGame( target )
        &&  Influx_GetClientId( target ) > 0)
        {
            bFound = true;
            
            DB_PrintClientLogById( client, Influx_GetClientId( target ) );
        }
    }
    
    if ( !bFound )
    {
        DB_PrintClientLogByName( client, szArg );
    }
    
    return Plugin_Handled;
}

stock bool LogCheat( int client, const char[] szReason, const char[] szKick = "", bool bPunish = false, int override_punishtime = ACLOG_NOPUNISH )
{
    if ( !IsClientInGame( client ) ) return false;
    
    if ( IsFakeClient( client ) ) return false;
    
    
    int punishtime = override_punishtime;
    
    if ( bPunish )
    {
        if ( punishtime == ACLOG_NOPUNISH )
            punishtime = g_ConVar_PunishType.IntValue;
    }
    else
    {
        punishtime = ACLOG_NOPUNISH;
    }
    
    bool res = DB_Log( client, szReason, punishtime );
    
    if ( res && punishtime > ACLOG_NOPUNISH )
    {
        if ( punishtime == ACLOG_KICK )
        {
            KickClient( client, szKick );
        }
        else
        {
            BanClient( client, punishtime, BANFLAG_AUTO, szReason, szKick, INFLUX_LIB_AC_LOG );
        }
    }
    
    if ( !res )
    {
        LogError( INF_CON_PRE..."We we're unable to log player's %N cheating.", client );
    }
    
    return res;
}

stock void PunishTimeToName( int time, char[] out, int len )
{
    switch ( time )
    {
        case ACLOG_NOPUNISH : out[0] = 0;
        case ACLOG_KICK : strcopy( out, len, "Kick" );
        case 0 : strcopy( out, len, "Perma Ban" );
        default :
        {
            FormatEx( out, len, "Banned for %i minutes.", time );
        }
    }
}
