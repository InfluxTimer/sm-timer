#include <sourcemod>

#include <influx/core>
#include <influx/help>

#include <msharedutil/arrayvec>


#define MAX_CMD             32
#define MAX_CMD_CELL        MAX_CMD / 4

#define MAX_MSG             128
#define MAX_MSG_CELL        MAX_MSG / 4

enum
{
    C_CMD[MAX_CMD_CELL] = 0,
    C_MSG[MAX_MSG_CELL],
    C_ADMINONLY,
    
    C_SIZE
};


float g_flLastCmd[INF_MAXPLAYERS];


ArrayList g_hComs;


// CONVARS
ConVar g_ConVar_NotifyConnected;


// FORWARDS
Handle g_hForward_OnRequestHelpCmds;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Help",
    description = "Display a list of "...INF_NAME..."'s commands.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_HELP );
    
    
    // NATIVES
    CreateNative( "Influx_AddHelpCommand", Native_AddHelpCommand );
    CreateNative( "Influx_RemoveHelpCommand", Native_RemoveHelpCommand );
}

public void OnPluginStart()
{
    // FORWARDS
    g_hForward_OnRequestHelpCmds = CreateGlobalForward( "Influx_OnRequestHelpCmds", ET_Ignore );
    
    
    // CONVARS
    g_ConVar_NotifyConnected = CreateConVar( "influx_help_notifyconnected", "1", "Print notification to just connected player.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    AutoExecConfig( true, "help", "influx" );
    
    
    // CMDS
    RegConsoleCmd( "sm_help", Cmd_Help, "Displays a list of "...INF_NAME..."'s commands." );
    
    
    
    g_hComs = new ArrayList( C_SIZE );
}

public void OnAllPluginsLoaded()
{
    g_hComs.Clear();
    
    Call_StartForward( g_hForward_OnRequestHelpCmds );
    Call_Finish();
}

public void OnClientPutInServer( int client )
{
    g_flLastCmd[client] = 0.0;
}

public void OnClientPostAdminCheck( int client )
{
    if ( g_ConVar_NotifyConnected.BoolValue )
    {
        CreateTimer( 2.0, T_Show, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
    }
}

public Action T_Show( Handle hTimer, int client )
{
    if ( (client = GetClientOfUserId( client )) > 0 && IsClientInGame( client ) )
    {
        Influx_PrintToChat( _, client, "Type {MAINCLR1}!help{CHATCLR} to see a list of commands." );
    }
}

public Action Cmd_Help( int client, int args )
{
    decl data[C_SIZE];
    
    int len = GetArrayLength_Safe( g_hComs );
    int i;
    
    int num = 0;
    
    if ( IS_ENT_PLAYER( client ) )
    {
        if ( Inf_HandleCmdSpam( client, 3.0, g_flLastCmd[client], true ) )
        {
            return Plugin_Handled;
        }
        
        
        bool bIsAdmin = Inf_CanClientUseAdminFlags( client, ADMFLAG_GENERIC );
        
        decl String:szDisplay[128];
        
        
        Menu menu = new Menu( Hndlr_Empty );
        menu.SetTitle( "Commands:\n " );
        
        for ( i = 0; i < len; i++ )
        {
            g_hComs.GetArray( i, data );
            
            if ( !bIsAdmin && data[C_ADMINONLY] ) continue;
            
            FormatEx( szDisplay, sizeof( szDisplay ), "%s - %s%s",
                data[C_CMD],
                data[C_MSG],
                data[C_ADMINONLY] ? " (ADMIN)" : "" );
            
            // ITEMDRAW_DEFAULT ITEMDRAW_DISABLED
            menu.AddItem( "", szDisplay, ITEMDRAW_DISABLED );
            
            ++num;
        }
        
        if ( !num )
        {
            menu.AddItem( "", "No commands here :(", ITEMDRAW_DISABLED );
        }
        
        menu.Display( client, MENU_TIME_FOREVER );
    }
    else
    {
        for ( i = 0; i < len; i++ )
        {
            g_hComs.GetArray( i, data );
            
            PrintToServer( "%s | %s%s",
                data[C_CMD],
                data[C_MSG],
                data[C_ADMINONLY] ? " (ADMIN)" : "" );
            
            ++num;
        }
        
        if ( !num )
        {
            PrintToServer( INF_CON_PRE..."No commands here :(" );
        }
    }
    
    return Plugin_Handled;
}

public int Hndlr_Empty( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    return 0;
}

// NATIVES
public int Native_AddHelpCommand( Handle hPlugin, int nParms )
{
    if ( g_hComs == null ) return 0;
    
    
    int data[C_SIZE];
    
    GetNativeString( 1, view_as<char>( data[C_CMD] ), MAX_CMD );
    GetNativeString( 2, view_as<char>( data[C_MSG] ), MAX_MSG );
    data[C_ADMINONLY] = GetNativeCell( 3 );
    
    g_hComs.PushArray( data );
    
    return 1;
}

public int Native_RemoveHelpCommand( Handle hPlugin, int nParms )
{
    if ( g_hComs == null ) return 0;
    
    
    char szCmd[MAX_CMD], szCmd2[MAX_CMD];
    GetNativeString( 1, szCmd, sizeof( szCmd ) );
    
    int len = GetArrayLength_Safe( g_hComs );
    for ( int i = 0; i < len; i++ )
    {
        g_hComs.GetString( i, szCmd2, sizeof( szCmd2 ) );
        
        if ( StrEqual( szCmd, szCmd2, true ) )
        {
            g_hComs.Erase( i );
            return 1;
        }
    }
    
    return 0;
}