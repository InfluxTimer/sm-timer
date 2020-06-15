#include <sourcemod>

#include <influx/core>
#include <influx/practise>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>


#undef REQUIRE_PLUGIN
#include <influx/help>
#include <influx/pause>


enum
{
    PRAC_TIME = 0,
    PRAC_ID,
    
    PRAC_POS[3],
    PRAC_ANG[2],
    PRAC_VEL[3],
    
    PRAC_SIZE
};

#define MAX_CHECKPOINTS     50


ArrayList g_hPrac[INF_MAXPLAYERS];
bool g_bPractising[INF_MAXPLAYERS];
int g_iCurIndex[INF_MAXPLAYERS];
int g_nId[INF_MAXPLAYERS];
int g_iLastUsed[INF_MAXPLAYERS];


enum
{
    USEVEL_NORMAL = 0,
    USEVEL_INHERIT,
    USEVEL_NONE,
    
    USEVEL_MAX
};

enum
{
    USEANG_NORMAL = 0,
    USEANG_FACEVELOCITY,
    USEANG_INHERIT,
    
    USEANG_MAX
};

bool g_bUsePos[INF_MAXPLAYERS];
int g_iUseAng[INF_MAXPLAYERS];
int g_iUseVel[INF_MAXPLAYERS];



// FORWARDS
Handle g_hForward_OnClientPracticeStart;


// LIBRARIES
bool g_bLib_Pause;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Practice",
    description = "Practise with checkpoints.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_PRACTISE );
    
    // NATIVES
    CreateNative( "Influx_IsClientPractising", Native_IsClientPractising );
    CreateNative( "Influx_StartPractising", Native_StartPractising );
    CreateNative( "Influx_EndPractising", Native_EndPractising );
    
    
    g_bLate = late;
}

public void OnPluginStart()
{
    // PHRASES
    LoadTranslations( INFLUX_PHRASES );
    
    
    // FORWARDS
    g_hForward_OnClientPracticeStart = CreateGlobalForward( "Influx_OnClientPracticeStart", ET_Hook, Param_Cell );
    
    
    // CMDS
    RegConsoleCmd( "sm_practise", Cmd_Practise );
    RegConsoleCmd( "sm_practice", Cmd_Practise );
    RegConsoleCmd( "sm_prac", Cmd_Practise );
    
    RegConsoleCmd( "sm_pracmenu", Cmd_CPMenu );
    RegConsoleCmd( "sm_cpmenu", Cmd_CPMenu );
    RegConsoleCmd( "sm_addcp", Cmd_AddCP );
    RegConsoleCmd( "sm_lastcreatedcp", Cmd_LastCreatedCP );
    RegConsoleCmd( "sm_lastusedcp", Cmd_LastUsedCP );
    RegConsoleCmd( "sm_pracsettings", Cmd_CPSettings );
    RegConsoleCmd( "sm_cpsettings", Cmd_CPSettings );
    
    
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
    
    
    if ( g_bLate )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) ) OnClientPutInServer( i );
        }
    }
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
}

public void OnClientPutInServer( int client )
{
    g_bPractising[client] = false;
    
    g_bUsePos[client] = true;
    g_iUseAng[client] = USEANG_NORMAL;
    g_iUseVel[client] = USEVEL_NORMAL;
    
    delete g_hPrac[client];
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "practise", "Toggle practise mode." );
    Influx_AddHelpCommand( "cpmenu", "Opens checkpoint menu." );
    Influx_AddHelpCommand( "cpsettings", "Opens checkpoint setting menu." );
    Influx_AddHelpCommand( "addcp", "Add a practice checkpoint." );
    Influx_AddHelpCommand( "lastusedcp", "Teleport to last used practice checkpoint." );
    Influx_AddHelpCommand( "lastcreatedcp", "Teleport to last created practice checkpoint." );
}

public Action Influx_OnTimerFinish( int client, int runid, int mode, int style, float time, int flags, char[] errormsg, int error_len )
{
    if ( g_bPractising[client] )
    {
        strcopy( errormsg, error_len, "You cannot finish the run while practising!" );
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Cmd_Practise( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    if ( !g_bPractising[client] )
    {
        if(StartPractising( client ))
        {
        FakeClientCommand( client, "sm_pracmenu" );
        }
    }
    else
    {
        EndPractising( client );
    }
    
    return Plugin_Handled;
}

public Action Cmd_AddCP( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !g_bPractising[client] )
    {
        Influx_PrintToChat( _, client, "%T", "INF_MUSTBEPRACTISING", client );
        return Plugin_Handled;
    }
    
    
    AddClientCP( client );
    
    return Plugin_Handled;
}

public Action Cmd_LastUsedCP( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !g_bPractising[client] )
    {
        Influx_PrintToChat( _, client, "%T", "INF_MUSTBEPRACTISING", client );
        return Plugin_Handled;
    }
    
    
    TeleportClientToLastUsedCP( client );
    
    return Plugin_Handled;
}

public Action Cmd_LastCreatedCP( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !g_bPractising[client] )
    {
        Influx_PrintToChat( _, client, "%T", "INF_MUSTBEPRACTISING", client );
        return Plugin_Handled;
    }
    
    
    TeleportClientToLastCreatedCP( client );
    
    return Plugin_Handled;
}

public Action Cmd_CPMenu( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !g_bPractising[client] )
    {
        Influx_PrintToChat( _, client, "%T", "INF_MUSTBEPRACTISING", client );
        return Plugin_Handled;
    }
    
    
    Menu menu = new Menu( Hndlr_CP );
    
    menu.AddItem( "-3", "Last created (sm_lastcreatedcp)" );
    menu.AddItem( "-2", "Last used (sm_lastusedcp)", ( g_iLastUsed[client] != -1 ) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    menu.AddItem( "-1", "Add CP (sm_addcp)\n " );
    menu.AddItem( "0", "Settings\n " );
    
    char szInfo[6];
    char szDisplay[16];
    int c = 0;
    int id;
    
    int endindex = g_iCurIndex[client];
    
    for ( int i = g_iCurIndex[client] - 1;; i-- )
    {
        if ( i < 0 )
        {
            i = MAX_CHECKPOINTS - 1;
        }
        
        id = g_hPrac[client].Get( i, view_as<int>( PRAC_ID ) );
        if ( id <= 0 ) break;
        
        
        FormatEx( szInfo, sizeof( szInfo ), "%i", id );
        FormatEx( szDisplay, sizeof( szDisplay ), "CP %03i", id );
        menu.AddItem( szInfo, szDisplay );
        
        ++c;
        
        
        if ( i == endindex ) break;
    }
    
    
    menu.SetTitle( "Checkpoint Menu (%i cps)\n ", c );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_CP( Menu menu, MenuAction action, int client, int menuindex )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[6];
    if ( !GetMenuItem( menu, menuindex, szInfo, sizeof( szInfo ) ) ) return 0;
    
    if ( !g_bPractising[client] ) return 0;
    
    
    int id = StringToInt( szInfo );
    
    switch ( id )
    {
        case -3 :
        {
            TeleportClientToLastCreatedCP( client );
        }
        case -2 :
        {
            TeleportClientToLastUsedCP( client );
        }
        case -1 :
        {
            AddClientCP( client );
        }
        case 0 :
        {
            FakeClientCommand( client, "sm_cpsettings" );
            
            return 0;
        }
        default :
        {
            for ( int i = 0; i < MAX_CHECKPOINTS; i++ )
            {
                if ( id == g_hPrac[client].Get( i, view_as<int>( PRAC_ID ) ) )
                {
                    TeleportClientToCP( client, i );
                }
            }
        }
    }
    
    //int startindex = menuindex - 2;
    
    FakeClientCommand( client, "sm_cpmenu" );
    
    return 0;
}

/*public Action Cmd_AddCP( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !g_bPractising[client] )
    {
        Influx_PrintToChat( _, client, "%T", "INF_MUSTBEPRACTISING", client );
        return Plugin_Handled;
    }
    
    
    AddClientCP( client );
    
    return Plugin_Handled;
}*/

public Action Cmd_CPSettings( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    char szDisplay[64];
    char szType[24];
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Checkpoint Settings\n " );
    
    
    FormatEx( szDisplay, sizeof( szDisplay ), "Use Position: %s", g_bUsePos[client] ? "On" : "Off" );
    menu.AddItem( "", szDisplay );
    
    switch ( g_iUseAng[client] )
    {
        case USEANG_NORMAL : strcopy( szType, sizeof( szType ), "Normal" );
        case USEANG_FACEVELOCITY : strcopy( szType, sizeof( szType ), "Face Velocity" );
        case USEANG_INHERIT : strcopy( szType, sizeof( szType ), "Inherit" );
        default : strcopy( szType, sizeof( szType ), "N/A" );
    }
    
    FormatEx( szDisplay, sizeof( szDisplay ), "Use Angles: %s", szType );
    menu.AddItem( "", szDisplay );
    
    
    switch ( g_iUseVel[client] )
    {
        case USEVEL_NORMAL : strcopy( szType, sizeof( szType ), "Normal" );
        case USEVEL_INHERIT : strcopy( szType, sizeof( szType ), "Inherit" );
        case USEVEL_NONE : strcopy( szType, sizeof( szType ), "None" );
        default : strcopy( szType, sizeof( szType ), "N/A" );
    }
    
    FormatEx( szDisplay, sizeof( szDisplay ), "Use Velocity: %s\n ", szType );
    menu.AddItem( "", szDisplay );
    
    menu.AddItem( "", "Back to CP Menu" );
    
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_Settings( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    switch( index )
    {
        case 0 : g_bUsePos[client] = !g_bUsePos[client];
        case 1 :
        {
            if ( g_iUseAng[client] < USEANG_NORMAL || ++g_iUseAng[client] >= USEANG_MAX )
            {
                g_iUseAng[client] = USEANG_NORMAL;
            }
        }
        case 2 :
        {
            if ( g_iUseVel[client] < USEVEL_NORMAL || ++g_iUseVel[client] >= USEVEL_MAX )
            {
                g_iUseVel[client] = USEVEL_NORMAL;
            }
        }
        case 3 :
        {
            FakeClientCommand( client, "sm_cpmenu" );
            
            return 0;
        }
    }
    
    FakeClientCommand( client, "sm_cpsettings" );
    
    return 0;
}

stock bool TeleportClientToLastUsedCP( int client )
{
    int index = g_iLastUsed[client];
    
    if ( g_hPrac[client].Get( index, view_as<int>( PRAC_ID ) ) > 0 )
    {
        return TeleportClientToCP( client, index );
    }
    
    return false;
}

stock bool TeleportClientToLastCreatedCP( int client )
{
    int index = g_iCurIndex[client] - 1;
    
    if ( index < 0 ) index = MAX_CHECKPOINTS - 1;
    
    
    if ( g_hPrac[client].Get( index, view_as<int>( PRAC_ID ) ) > 0 )
    {
        return TeleportClientToCP( client, index );
    }
    
    return false;
}

stock bool TeleportClientToCP( int client, int index )
{
    g_iLastUsed[client] = index;
    
    decl data[PRAC_SIZE];
    g_hPrac[client].GetArray( index, data );
    
    decl Float:pos[3], Float:ang[3], Float:vel[3];
    CopyArray( data[PRAC_POS], pos, 3 );
    CopyArray( data[PRAC_ANG], ang, 2 );
    CopyArray( data[PRAC_VEL], vel, 3 );
    
    ang[2] = 0.0; // Don't tilt me bro
    
    
    // If we're not paused, change our time.
    if ( !g_bLib_Pause || !Influx_IsClientPaused( client ) )
    {
        float practime = view_as<float>( data[PRAC_TIME] );

        if ( practime > 0.0 )
        {
            Influx_SetClientState( client, STATE_RUNNING );
            
            Influx_SetClientTime( client, practime );
        }
        else
        {
            Influx_SetClientState( client, STATE_NONE );
        }
    }
    
    switch ( g_iUseAng[client] )
    {
        case USEANG_FACEVELOCITY :
        {
            ang[1] = RadToDeg( ArcTangent2( vel[1], vel[0] ) );
        }
    }
    
    switch ( g_iUseVel[client] )
    {
        case USEVEL_NONE : vel = ORIGIN_VECTOR;
    }
    
    TeleportEntity(
        client,
        g_bUsePos[client]                   ? pos : NULL_VECTOR,
        g_iUseAng[client] != USEANG_INHERIT ? ang : NULL_VECTOR,
        g_iUseVel[client] != USEVEL_INHERIT ? vel : NULL_VECTOR );
    
    return true;
}

stock bool AddClientCP( int client )
{
    decl Float:pos[3], Float:ang[3], Float:vel[3];
    GetClientAbsOrigin( client, pos );
    GetClientEyeAngles( client, ang );
    GetEntityVelocity( client, vel );
    
    decl data[PRAC_SIZE];
    
    if ( Influx_GetClientState( client ) == STATE_RUNNING )
    {
        data[PRAC_TIME] = view_as<int>( Influx_GetClientTime( client ) );
    }
    else
    {
        data[PRAC_TIME] = view_as<int>( 0.0 );
    }
    
    data[PRAC_ID] = ++g_nId[client];
    CopyArray( pos, data[PRAC_POS], 3 );
    CopyArray( ang, data[PRAC_ANG], 2 );
    CopyArray( vel, data[PRAC_VEL], 3 );
    
    g_hPrac[client].SetArray( g_iCurIndex[client]++, data );
    
    if ( g_iCurIndex[client] >= MAX_CHECKPOINTS )
    {
        g_iCurIndex[client] = 0;
    }
    
    /*if ( g_nId[client] >= 1337 )
    {
        g_nId[client] = 0;
    }*/
    
    return true;
}

stock bool StartPractising( int client )
{
    if ( g_bPractising[client] ) return true;
    
    
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnClientPracticeStart );
    Call_PushCell( client );
    Call_Finish( res );
    
    if ( res != Plugin_Continue )
    {
        return false;
    }
    
    
    g_bPractising[client] = true;
    
    delete g_hPrac[client];
    g_hPrac[client] = new ArrayList( PRAC_SIZE, MAX_CHECKPOINTS );
    g_iCurIndex[client] = 0;
    g_nId[client] = 0;
    
    g_iLastUsed[client] = -1;
    
    // Reset ids, since creating an array with start size has garbage in it.
    for ( int i = 0; i < MAX_CHECKPOINTS; i++ )
    {
        g_hPrac[client].Set( i, 0, view_as<int>( PRAC_ID ) );
    }
    
    
    Influx_PrintToChat( _, client, "%T", "INF_PRACTICEMODECHANGE", client, "ON" );
    
    return true;
}

stock void EndPractising( int client )
{
    if ( !g_bPractising[client] ) return;
    
    
    g_bPractising[client] = false;
    
    // Continue our run, otherwise teleport to start.
    if ( g_bLib_Pause && Influx_IsClientPaused( client ) )
    {
        Influx_ContinueClientRun( client );
    }
    // Don't let people prespeed.
    else// if ( Influx_GetClientState( client ) == STATE_RUNNING )
    {
        Influx_TeleportToStart( client, true );
    }
    
    Influx_PrintToChat( _, client, "%T", "INF_PRACTICEMODECHANGE", client, "OFF" );
}

public int Native_IsClientPractising( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    return g_bPractising[client];
}

public int Native_StartPractising( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    return StartPractising( client );
}

public int Native_EndPractising( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    EndPractising( client );
    
    return 1;
}
