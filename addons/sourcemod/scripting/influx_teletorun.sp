#include <sourcemod>

#include <influx/core>



enum
{
    BONUS_NUM = 0,
    BONUS_RUN_ID,
    
    BONUS_SIZE
};


int g_iRunId_Main;

ArrayList g_hBonuses;


// CONVARS
ConVar g_ConVar_RestartToCurrent;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Teleport To Run",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    g_bLate = late;
}

public void OnPluginStart()
{
    g_hBonuses = new ArrayList( BONUS_SIZE );
    
    
    // PHRASES
    LoadTranslations( INFLUX_PHRASES );
    
    
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
    
    RegConsoleCmd( "sm_bonus", Cmd_Bonus );
    RegConsoleCmd( "sm_b", Cmd_Bonus );
    
    
    
    if ( g_bLate )
    {
        // If core has already loaded runs
        // register runs ourselves.
        if ( Influx_HasLoadedRuns() )
        {
            Influx_OnPreRunLoad();
            
            
            ArrayList runs = Influx_GetRunsArray();
            int len = runs.Length;
            
            for ( int i = 0; i < len; i++ )
            {
                Influx_OnRunCreated( runs.Get( i, RUN_ID ) );
            }
        }
    }
}

public void Influx_OnPreRunLoad()
{
    g_iRunId_Main = -1;
    
    g_hBonuses.Clear();
}

public void Influx_OnRunCreated( int runid )
{
    decl String:szRun[MAX_RUN_NAME];
    szRun[0] = 0;
    
    Influx_GetRunName( runid, szRun, sizeof( szRun ) );
    
    if ( StrContains( szRun, "main", false ) == 0 )
    {
        g_iRunId_Main = runid;
    }
    else if ( StrContains( szRun, "bonus", false ) == 0 )
    {
        int pos = FindCharInString( szRun, '#' ) + 1;
        
        int val = StringToInt( szRun[pos] );
        
        if ( val < 1 ) return;
        
        
        AddBonus( val, runid );
    }
}

public void Influx_OnRunDeleted( int runid )
{
    if ( g_iRunId_Main == runid )
    {
        g_iRunId_Main = -1;
    }
    else
    {
        int index = FindBonusById( runid );
        
        if ( index != -1 )
        {
            g_hBonuses.Erase( index );
        }
    }
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
        Influx_PrintToChat( _, client, "%T", "INF_RUNNOTEXIST", client );
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

public Action Cmd_Bonus( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int num = 1;
    
    if ( args )
    {
        char szArg[32];
        GetCmdArgString( szArg, sizeof( szArg ) );
        
        num = StringToInt( szArg );
        
        if ( !num ) GetBonusNumFromCmd();
    }
    else
    {
        num = GetBonusNumFromCmd();
    }
    
    
    if ( !num ) num = 1;
    
    
    int index = FindBonusByNum( num );
    
    
    if ( index != -1 )
    {
        AttemptToSet( client, g_hBonuses.Get( index, BONUS_RUN_ID ) );
    }
    else
    {
        OpenRunMenu( client );
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

stock int FindBonusByNum( int num )
{
    int len = g_hBonuses.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hBonuses.Get( i, BONUS_NUM ) == num )
            return i;
    }
    
    return -1;
}

stock int FindBonusById( int runid )
{
    int len = g_hBonuses.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hBonuses.Get( i, BONUS_RUN_ID ) == runid )
            return i;
    }
    
    return -1;
}

stock int AddBonus( int num, int runid )
{
    int index;
    
    index = FindBonusByNum( num );
    if ( index != -1 ) return index;
    
    
    int data[BONUS_SIZE];
    
    data[BONUS_NUM] = num;
    data[BONUS_RUN_ID] = runid;
    
    index = g_hBonuses.PushArray( data );
    
    
    char szCmdName[32];
    
    
    FormatEx( szCmdName, sizeof( szCmdName ), "sm_bonus%i", num );
    if ( !CommandExists( szCmdName ) )
    {
        RegConsoleCmd( szCmdName, Cmd_Bonus );
    }
    
    
    FormatEx( szCmdName, sizeof( szCmdName ), "sm_b%i", num );
    if ( !CommandExists( szCmdName ) )
    {
        RegConsoleCmd( szCmdName, Cmd_Bonus );
    }
    
    return index;
}

stock void OpenRunMenu( int client )
{
    FakeClientCommand( client, "sm_runs" );
}

stock int GetBonusNumFromCmd()
{
    char szArg[32];
    GetCmdArg( 0, szArg, sizeof( szArg ) );
    
    int pos = 0;
    
    // "sm_bonus1"
    if ( StrContains( szArg, "sm_bonus" ) == 0 )
    {
        pos = 8;
    }
    // "sm_b1"
    else if ( StrContains( szArg, "sm_b" ) == 0 )
    {
        pos = 4;
    }
    
    
    return StringToInt( szArg[pos] );
}
