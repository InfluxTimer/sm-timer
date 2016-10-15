#include <sourcemod>


#include <influx/core>


public void OnPluginStart()
{
    // Print a message to client. No prefix.
    RegConsoleCmd( "sm_saysomething", Cmd_SaySomething );
    
    // Print a message to client.
    RegConsoleCmd( "sm_saysomethingtoall", Cmd_SaySomethingToAll );
    
    // Print a message to a select group of clients.
    RegConsoleCmd( "sm_saysomethingtoalive", Cmd_SaySomethingToAlive );
    
    // Print a message with no chat colors.
    RegConsoleCmd( "sm_saysomethingremove", Cmd_SaySomethingRemove );
    
    // Print a message that was formatted by Influx but sent with normal stocks.
    RegConsoleCmd( "sm_saysomethingformat", Cmd_SaySomethingFormatted );
}

public Action Cmd_SaySomething( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_PrintToChat( PRINTFLAGS_NOPREFIX, client, "Hello! {MAINCLR1}This is a message with no prefix! {LIGHTYELLOW}Bye{CHATCLR}!" );
    
    return Plugin_Handled;
}

public Action Cmd_SaySomethingToAll( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    // NOTE: Second argument is the author. (for team chat color)
    Influx_PrintToChatAll( _, client, "This is a {TEAM}message{CHATCLR} to everybody!" );
    
    return Plugin_Handled;
}

public Action Cmd_SaySomethingToAlive( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int nClients = 0;
    int[] clients = new int[MaxClients];
    
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        // Only print to alive players.
        if ( IsClientInGame( i ) && IsPlayerAlive( i ) )
        {
            clients[nClients++] = i;
        }
    }
    
    if ( !nClients ) return Plugin_Handled;
    
    
    // NOTE: Second argument is the author. (for team chat color)
    Influx_PrintToChatEx( _, client, clients, nClients, "This is an important announcement! {TEAM}You are alive{CHATCLR}!" );
    
    
    return Plugin_Handled;
}

public Action Cmd_SaySomethingRemove( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    char szMsg[256];
    strcopy( szMsg, sizeof( szMsg ), "This is not a {MAINCLR1}color message{CHATCLR}!" );
    
    
    Influx_RemoveChatColors( szMsg, sizeof( szMsg ) );
    
    
    PrintToChat( client, "%s", szMsg );
    
    
    return Plugin_Handled;
}

public Action Cmd_SaySomethingFormatted( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    char szMsg[256];
    strcopy( szMsg, sizeof( szMsg ), "This is a {MAINCLR1}message{CHATCLR}!" );
    
    
    Influx_FormatChatColors( szMsg, sizeof( szMsg ) );
    
    
    PrintToChat( client, "%s", szMsg );
    
    
    return Plugin_Handled;
}