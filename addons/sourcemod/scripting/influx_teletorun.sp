#include <sourcemod>

#include <influx/core>




int g_iRunId_Main;
int g_iRunId_Bonus1;
int g_iRunId_Bonus2;


// CONVARS
ConVar g_ConVar_RestartToCurrent;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Teleport To Run",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_RestartToCurrent = CreateConVar( "influx_teletorun_restarttocurrent", "1", "If true, restart command will put player to their current run's start. Otherwise, teleport to main start.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    AutoExecConfig( true, "teletorun", "influx" );
    
    
    // MENUS
    RegConsoleCmd( "sm_run", Cmd_Change_Run );
    RegConsoleCmd( "sm_runs", Cmd_Change_Run );
    
    
    // CMDS
    RegConsoleCmd( "sm_r", Cmd_Restart );
    RegConsoleCmd( "sm_re", Cmd_Restart );
    RegConsoleCmd( "sm_rs", Cmd_Restart );
    RegConsoleCmd( "sm_restart", Cmd_Restart );
    RegConsoleCmd( "sm_start", Cmd_Restart );
    
    
    RegConsoleCmd( "sm_main", Cmd_Main );
    RegConsoleCmd( "sm_m", Cmd_Main );
    
    RegConsoleCmd( "sm_bonus", Cmd_BonusChoose );
    RegConsoleCmd( "sm_b", Cmd_BonusChoose );
    
    RegConsoleCmd( "sm_bonus1", Cmd_Bonus1 );
    RegConsoleCmd( "sm_b1", Cmd_Bonus1 );
    RegConsoleCmd( "sm_bonus2", Cmd_Bonus2 );
    RegConsoleCmd( "sm_b2", Cmd_Bonus2 );
}

public void Influx_OnPreRunLoad()
{
    g_iRunId_Main = -1;
    g_iRunId_Bonus1 = -1;
    g_iRunId_Bonus2 = -1;
}

public void Influx_OnRunCreated( int runid )
{
    char szRun[MAX_RUN_NAME];
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    if ( StrContains( szRun, "main", false ) == 0 )
    {
        g_iRunId_Main = runid;
    }
    else if ( StrContains( szRun, "bonus", false ) == 0 )
    {
        if ( StrContains( szRun, "2" ) != -1 )
        {
            g_iRunId_Bonus2 = runid;
        }
        else
        {
            g_iRunId_Bonus1 = runid;
        }
    }
}

public void Influx_OnRunDeleted( int runid )
{
    if ( g_iRunId_Main == runid ) g_iRunId_Main = -1;
    else if ( g_iRunId_Bonus1 == runid ) g_iRunId_Bonus1 = -1;
    else if ( g_iRunId_Bonus2 == runid ) g_iRunId_Bonus2 = -1;
}

public Action Cmd_Restart( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    // Let other plugins handle the spawning.
    if ( IsPlayerAlive( client ) )
    {
        int currunid = Influx_GetClientRunId( client );
        
        int runid = ( !g_ConVar_RestartToCurrent.BoolValue && Influx_FindRunById( MAIN_RUN_ID ) != -1 ) ? MAIN_RUN_ID : Influx_GetClientRunId( client );
        
        
        if ( currunid == runid )
        {
            Influx_TeleportToStart( client );
        }
        else
        {
            Influx_SetClientRun( client, runid );
        }
    }
    
    
    return Plugin_Handled;
}

stock bool AttemptToSet( int client, int runid )
{
    if ( Influx_FindRunById( runid ) == -1 )
    {
        Influx_PrintToChat( _, client, "That run does not exist!" );
        return false;
    }
    
    
    Influx_SetClientRun( client, runid );
    
    return true;
}

public Action Cmd_Main( int client, int args )
{
    if ( client ) AttemptToSet( client, g_iRunId_Main );
    return Plugin_Handled;
}

public Action Cmd_Bonus1( int client, int args )
{
    if ( client ) AttemptToSet( client, g_iRunId_Bonus1 );
    return Plugin_Handled;
}

public Action Cmd_Bonus2( int client, int args )
{
    if ( client ) AttemptToSet( client, g_iRunId_Bonus2 );
    return Plugin_Handled;
}

public Action Cmd_BonusChoose( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !args )
    {
        AttemptToSet( client, g_iRunId_Bonus1 );
        return Plugin_Handled;
    }
    
    
    char szArg[6];
    GetCmdArgString( szArg, sizeof( szArg ) );
    
    int value = StringToInt( szArg );
    
    if ( value == 1 )
    {
        AttemptToSet( client, g_iRunId_Bonus1 );
    }
    else if ( value == 2 )
    {
        AttemptToSet( client, g_iRunId_Bonus2 );
    }
    else
    {
        FakeClientCommand( client, "sm_run" );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Change_Run( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_Change_Run );
    
    char szInfo[8];
    char szRun[MAX_RUN_NAME];
    
    
    int currunid = Influx_GetClientRunId( client );
    
    Influx_GetRunName( currunid, szRun, sizeof( szRun ) );
    menu.SetTitle( "Change Run\nCurrent: %s\n ", szRun );
    
    
    ArrayList runs = Influx_GetRunsArray();
    
    int len = runs.Length;
    int id;
    for ( int i = 0; i < len; i++ )
    {
        id = runs.Get( i, RUN_ID );
        
        
        Influx_GetRunName( id, szRun, sizeof( szRun ) );
        
        
        FormatEx( szInfo, sizeof( szInfo ), "%i", id );
        
        Format( szRun, sizeof( szRun ), "%s (ID: %i)", szRun, id );
        
        menu.AddItem( szInfo, szRun, ( currunid == id ) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_Change_Run( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[8];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    Influx_SetClientRun( client, StringToInt( szInfo ) );
    
    return 0;
}
