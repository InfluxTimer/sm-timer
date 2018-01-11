#include <sourcemod>
#include <sdkhooks>

#include <influx/core>
#include <influx/ac_log>

#include <msharedutil/misc>


#undef REQUIRE_PLUGIN
#include <influx/help>



#define DEBUG_DB


#define INF_PRIVCOM_PRINTLOG        "sm_inf_printaclog"
#define INF_PRIVCOM_CURRENTACT      "sm_inf_logactivity"
#define INF_PRIVCOM_MARKLOGSEEN     "sm_inf_marklogseen"



bool g_bDisableLogNotify[INF_MAXPLAYERS];


// CONVARS
ConVar g_ConVar_PunishType;
ConVar g_ConVar_NotifyUnseen;


// FORWARDS
Handle g_hForward_OnLogCheat;



#include "influx_ac_log/cmds.sp"
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
    
    
    // NATIVES
    CreateNative( "Influx_LogCheat", Native_LogCheat );
    CreateNative( "Influx_PunishCheat", Native_PunishCheat );
}

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_PunishType = CreateConVar( "influx_ac_log_defaultpunish", "-1", "-2 = Disable, -1 = Kick, 0 = Perma ban, >0 = Ban for this many minutes.", FCVAR_NOTIFY, true, -2.0 );
    g_ConVar_NotifyUnseen = CreateConVar( "influx_ac_log_notifyunseenwhenadminonline", "1", "Do we notify admin about unseen activity when joining the server?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    // FORWARDS
    g_hForward_OnLogCheat = CreateGlobalForward( "Influx_OnLogCheat", ET_Hook, Param_Cell, Param_String, Param_CellByRef, Param_CellByRef );
    
    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_PRINTLOG, Cmd_Empty, ADMFLAG_CONVARS );
    RegAdminCmd( INF_PRIVCOM_CURRENTACT, Cmd_Empty, ADMFLAG_CONVARS );
    RegAdminCmd( INF_PRIVCOM_MARKLOGSEEN, Cmd_Empty, ADMFLAG_CONVARS );
    
    
    // CMDS
    RegConsoleCmd( "sm_printaclog", Cmd_PrintLog );
    RegConsoleCmd( "sm_printcheatlog", Cmd_PrintLog );
    
    RegConsoleCmd( "sm_printunseenaclog", Cmd_PrintNewLog );
    RegConsoleCmd( "sm_printnewaclog", Cmd_PrintNewLog );
    RegConsoleCmd( "sm_printnewcheatlog", Cmd_PrintNewLog );
    
    RegConsoleCmd( "sm_togglelogactivity", Cmd_ToggleLogNotifications );
    RegConsoleCmd( "sm_togglelognotifications", Cmd_ToggleLogNotifications );
    RegConsoleCmd( "sm_togglelognotify", Cmd_ToggleLogNotifications );
    
    RegConsoleCmd( "sm_markaclogseen", Cmd_MarkLogSeen );
    RegConsoleCmd( "sm_markcheatlogseen", Cmd_MarkLogSeen );
}

public void OnAllPluginsLoaded()
{
    DB_Init();
}

public void Influx_OnRequestHelpCmds()
{
    Influx_AddHelpCommand( "printaclog <name>", "Print player's activity log.", true );
    Influx_AddHelpCommand( "printnewaclog", "Prints all new activity an admin hasn't seen.", true );
    Influx_AddHelpCommand( "markaclogseen", "Marks all unseen logs as seen.", true );
    Influx_AddHelpCommand( "togglelognotify", "Toggle log notification printing.", true );
}

public void OnClientPutInServer( int client )
{
    g_bDisableLogNotify[client] = false;
}

public void Influx_OnClientIdRetrieved( int client, int uid, bool bNew )
{
    if ( !g_ConVar_NotifyUnseen.BoolValue ) return;
    
    
    if ( CanUserSeeCurrentLog( client ) || CanUserPrintLog( client ) )
    {
        DB_PrintUnseenNum( client );
    }
}

stock bool LogCheat( int client, const char[] szReasonId, const char[] szReason, const char[] szKick = "", bool bPunish = false, int override_punishtime = ACLOG_NOPUNISH, bool bNotifyAdmin = false )
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
    
    
    bool log = SendLogCheat( client, szReasonId, punishtime, bNotifyAdmin );
    
    
    bool bNotified = false;
    
    if ( bNotifyAdmin )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( !IsClientInGame( i ) ) continue;
            
            if ( IsFakeClient( i ) ) continue;
            
            
            if ( CanUserSeeCurrentLog( i ) && !g_bDisableLogNotify[i] )
            {
                if ( i != client ) bNotified = true;
                
                
                Influx_PrintToChat( _, client, "Logged %N | %s", client, szReason );
            }
        }
    }
    
    
    bool res = true;

    if ( log )
    {
        res = DB_Log( client, szReasonId, szReason, punishtime, bNotifyAdmin, bNotifyAdmin && !bNotified );
    }
    
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
        LogError( INF_CON_PRE..."We we're unable to log player's %N activity.", client );
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

stock bool CanUserPrintLog( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_PRINTLOG, ADMFLAG_ROOT );
}

stock bool CanUserSeeCurrentLog( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_CURRENTACT, ADMFLAG_ROOT );
}

stock bool CanUserMarkLogSeen( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_MARKLOGSEEN, ADMFLAG_ROOT );
}

stock bool SendLogCheat( int client, const char[] szReasonId, int &punishtime, bool &bNotifyAdmin )
{
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnLogCheat );
    Call_PushCell( client );
    Call_PushString( szReasonId );
    Call_PushCellRef( punishtime );
    Call_PushCellRef( bNotifyAdmin );
    Call_Finish( res );
    
    return ( res == Plugin_Continue );
}
