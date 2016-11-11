#include <sourcemod>

#include <influx/core>


#include <msharedutil/ents>


#undef REQUIRE_PLUGIN
#include <influx/help>


ConVar g_ConVar_NotifyAll;
ConVar g_ConVar_MinToNotifyAll;


float g_flLastCmd[INF_MAXPLAYERS];


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Spectator List",
    description = "Displays a list of spectators in chat.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_NotifyAll = CreateConVar( "influx_speclist_notifyall", "2", "0 = Only display to issuer, 1 = Always notify all, 2 = Notify all if there are more or equal spectators than the limit.", FCVAR_NOTIFY, true, 0.0, true, 2.0 );
    g_ConVar_MinToNotifyAll = CreateConVar( "influx_speclist_minttonotifyall", "2", "Minimum amount of spectators before printing the message for everybody.", FCVAR_NOTIFY );
    
    
    AutoExecConfig( true, "speclist", "influx" );
    
    
    // CMDS
    RegConsoleCmd( "sm_speclist", Cmd_SpecList );
    RegConsoleCmd( "sm_specslist", Cmd_SpecList );
    RegConsoleCmd( "sm_spectatorlist", Cmd_SpecList );
    RegConsoleCmd( "sm_listspecs", Cmd_SpecList );
    RegConsoleCmd( "sm_listspectators", Cmd_SpecList );
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "speclist", "List all your spectators." );
}

public void OnClientPutInServer( int client )
{
    g_flLastCmd[client] = 0.0;
}

public Action Cmd_SpecList( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Inf_HandleCmdSpam( client, 6.0, g_flLastCmd[client], true ) )
    {
        return Plugin_Handled;
    }
    
    
    int target = 0;
    
    if ( !IsPlayerAlive( client ) )
    {
        int newtarget = GetClientObserverTarget( client );
        
        if (IS_ENT_PLAYER( newtarget )
        &&  IsClientInGame( newtarget )
        &&  IsPlayerAlive( newtarget )
        &&  GetClientObserverMode( client ) != OBS_MODE_ROAMING)
        {
            target = newtarget;
        }
    }
    else
    {
        target = client;
    }
    
    
    if ( !target ) return Plugin_Handled;
    
    
    decl String:szMsg[512];
    szMsg[0] = 0;
    
    int num = 0;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( i == target ) continue;
        
        if ( !IsClientInGame( i ) ) continue;
        
        if ( IsFakeClient( i ) ) continue;
        
        if ( IsPlayerAlive( i ) ) continue;
        
        if ( GetClientObserverTarget( i ) == target && GetClientObserverMode( client ) != OBS_MODE_ROAMING )
        {
            ++num;
            
            Format( szMsg, sizeof( szMsg ), "%s%s{MAINCLR1}%N", szMsg, ( szMsg[0] ) ? "{CHATCLR}, " : "", i );
        }
    }
    
    
    if ( num )
    {
        Format( szMsg, sizeof( szMsg ), "People spectating {MAINCLR1}%N{CHATCLR} ({MAINCLR1}%i{CHATCLR}): %s", target, num, szMsg );
    }
    else
    {
        FormatEx( szMsg, sizeof( szMsg ), "Nobody is spectating {MAINCLR1}%N{CHATCLR}. :(", target );
    }
    
    
    switch ( g_ConVar_NotifyAll.IntValue )
    {
        case 0 : Influx_PrintToChat( _, client, szMsg );
        case 1 : Influx_PrintToChatAll( _, client, szMsg );
        case 2 :
        {
            if ( num >= g_ConVar_MinToNotifyAll.IntValue )
            {
                Influx_PrintToChatAll( _, client, szMsg );
            }
            else
            {
                Influx_PrintToChat( _, client, szMsg );
            }
        }
    }
    
    return Plugin_Handled;
}