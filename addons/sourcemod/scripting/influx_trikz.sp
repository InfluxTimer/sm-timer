#include <sourcemod>
#include <sdktools>

#include <influx/core>

#include <msharedutil/ents>


#undef REQUIRE_PLUGIN
#include <influx/recording>


//#define DEBUG


int g_iPartner[INF_MAXPLAYERS];
bool g_bTouchedEnd[INF_MAXPLAYERS];
bool g_bInStart[INF_MAXPLAYERS];

bool g_bAutoFlash[INF_MAXPLAYERS];


// OFFSETS
int g_Offset_hMyWeapons;
int g_Offset_iAmmo;

bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Trikz",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    //RegPluginLibrary( INFLUX_LIB_TRIKZ );
    
    
    g_bLate = late;
    
    
    // NATIVES
    //CreateNative( "Influx_", Native_ );
}

public void OnPluginStart()
{
    if ( (g_Offset_hMyWeapons = FindSendPropInfo( "CBasePlayer", "m_hMyWeapons" )) == -1 )
    {
        SetFailState( INF_CON_PRE..."Couldn't find offset for m_hMyWeapons!" );
    }
    
    if ( (g_Offset_iAmmo = FindSendPropInfo( "CCSPlayer", "m_iAmmo" )) == -1 )
    {
        SetFailState( INF_CON_PRE..."Couldn't find offset for m_iAmmo!" );
    }
    
    
    // CMDS
    RegConsoleCmd( "sm_trikz", Cmd_Trikz );
    RegConsoleCmd( "sm_partner", Cmd_Partner );
    RegConsoleCmd( "sm_buddy", Cmd_Partner );
    RegConsoleCmd( "sm_trikzbuddy", Cmd_Partner );
    
    
    if ( g_bLate )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) )
            {
                OnClientPutInServer( i );
            }
        }
    }
}

public void OnClientPutInServer( int client )
{
    g_iPartner[client] = 0;
    g_bTouchedEnd[client] = false;
    g_bInStart[client] = false;
    
    g_bAutoFlash[client] = false;
    
    SDKHook( client, SDKHook_WeaponSwitchPost, E_WeaponSwitchPost );
}

public void OnClientDisconnect( int client )
{
    g_iPartner[client] = 0;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IsClientInGame( i ) ) continue;
        
        if ( g_iPartner[i] == client )
        {
            g_iPartner[i] = 0;
            
            SetEntityCollisionGroup( i, 2 );
        }
    }
    
    SDKUnhook( client, SDKHook_WeaponSwitchPost, E_WeaponSwitchPost );
    //SDKUnhook( client, SDKHook_PostThinkPost, E_PostThinkPost );
    
    //SDKUnhook( client, SDKHook_TraceAttack, E_TraceAttack );
}

public void E_WeaponSwitchPost( int client, int weapon )
{
#if defined DEBUG
    //PrintToServer( INF_DEBUG_PRE..."Client %i - Switch: %i", client, weapon );
#endif

    if ( !g_bAutoFlash[client] ) return;
    
    
    if ( GetClientFlashbangs( client ) < 2 )
    {
        GiveFlashbang( client );
        
        EquipFlashbang( client );
    }
}

stock int GetClientFlashbangs( int client )
{
    decl String:szWep[32];
    int weapon;
    
    for ( int i = 0; i <= 128; i += 4 )
    {
        weapon = GetEntDataEnt2( client, g_Offset_hMyWeapons + i );
        
        if ( weapon != -1 )
        {
            GetEntityClassname( weapon, szWep, sizeof( szWep ) );
            
            if ( StrEqual( szWep, "weapon_flashbang" ) )
            {
                return GetEntData( client, g_Offset_iAmmo + (GetEntProp( weapon, Prop_Send, "m_iPrimaryAmmoType" ) * 4) );
            }
        }
    }
    
    return 0;
}

stock void GiveFlashbang( int client )
{
    GivePlayerItem( client, "weapon_flashbang" );
}

stock void EquipFlashbang( int client )
{
    FakeClientCommand( client, "use weapon_flashbang" );
}

stock void OpenTrikzMenu( int client )
{
    FakeClientCommand( client, "sm_trikz" );
}

stock void OpenBuddyMenu( int client )
{
    FakeClientCommand( client, "sm_partner" );
}

public Action Cmd_Trikz( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_TrikzMenu );
    menu.SetTitle( "Trikz Menu\n " );
    
    
    decl String:szDisplay[64];
    
    FormatEx( szDisplay, sizeof( szDisplay ), "Auto-Flash: %s", g_bAutoFlash[client] ? "ON" : "OFF" );
    
    menu.AddItem( "a", szDisplay );
    menu.AddItem( "b", "Give flashbang\n " );
    
    FormatEx( szDisplay, sizeof( szDisplay ), "Collision: %s\n ", (GetEntityCollisionGroup( client ) != 5) ? "OFF" : "ON" );
    menu.AddItem( "c", szDisplay );
    
    
    
    
    if ( g_iPartner[client] != 0 )
    {
        char szName[MAX_NAME_LENGTH];
        GetClientName( g_iPartner[client], szName, sizeof( szName ) );
        
        FormatEx( szDisplay, sizeof( szDisplay ), "Buddy: %s", szName );
        menu.AddItem( "", szDisplay, ITEMDRAW_DISABLED );
    }
    else
    {
        menu.AddItem( "d", "Choose a buddy" );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_TrikzMenu( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    char szInfo[2];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    switch ( szInfo[0] )
    {
        case 'a' :
        {
            g_bAutoFlash[client] = !g_bAutoFlash[client];
            
            if ( g_bAutoFlash[client] && GetClientFlashbangs( client ) < 2 )
            {
                GiveFlashbang( client ); GiveFlashbang( client );
                
                EquipFlashbang( client );
            }
        }
        case 'b' :
        {
            if ( GetClientFlashbangs( client ) < 2 )
            {
                GiveFlashbang( client );
                
                EquipFlashbang( client );
            }
        }
        case 'c' :
        {
            SetEntityCollisionGroup( client, (GetEntityCollisionGroup( client ) != 5) ? 5 : 3 );
        }
        case 'd' :
        {
            OpenBuddyMenu( client );
            return 0;
        }
    }
    
    OpenTrikzMenu( client );
    
    return 0;
}

public Action Cmd_Partner( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_PartnerMenu );
    menu.SetTitle( "Buddy Select Menu\n " );
    
    
    decl String:szInfo[32];
    decl String:szDisplay[64];
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( i == client ) continue;
        
        if ( !IsClientInGame( i ) ) continue;
        
        if ( IsFakeClient( i ) ) continue;
        
        if ( g_iPartner[i] != 0 ) continue;
        
        
        FormatEx( szInfo, sizeof( szInfo ), "%i", GetClientUserId( i ) );
        
        GetClientName( i, szDisplay, sizeof( szDisplay ) );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_PartnerMenu( Menu oldmenu, MenuAction action, int client, int index )
{
    MENU_HANDLE( oldmenu, action )
    
    
    if ( g_iPartner[client] != 0 ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( oldmenu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int target = GetClientOfUserId( StringToInt( szInfo ) );
    if ( !target ) return 0;
    
    if ( IsFakeClient( target ) ) return 0;
    
    if ( g_iPartner[target] != 0 ) return 0;
    
    
    decl String:szName[MAX_NAME_LENGTH];
    GetClientName( client, szName, sizeof( szName ) );
    
    Menu menu = new Menu( Hndlr_PartnerMenu_Confirm );
    menu.SetTitle( "%s wants to be your trikz buddy! Do you accept?\n ", szName );
    
    
    FormatEx( szInfo, sizeof( szInfo ), "%i", GetClientUserId( client ) );
    menu.AddItem( szInfo, "Sure!" );
    menu.AddItem( "", "No! :(" );
    
    menu.Display( target, MENU_TIME_FOREVER );
    
    return 0;
}

public int Hndlr_PartnerMenu_Confirm( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( index != 0 ) return 0;
    
    if ( g_iPartner[client] != 0 ) return 0;
    
    
    char szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int target = GetClientOfUserId( StringToInt( szInfo ) );
    if ( !target ) return 0;
    
    if ( IsFakeClient( target ) ) return 0;
    
    if ( g_iPartner[target] != 0 ) return 0;
    
    
    g_iPartner[target] = client;
    g_iPartner[client] = target;
    
    SetEntityCollisionGroup( client, 5 );
    SetEntityCollisionGroup( target, 5 );
    
    
    decl String:szName[MAX_NAME_LENGTH];
    
    GetClientName( target, szName, sizeof( szName ) );
    Influx_PrintToChat( _, client, "{MAINCLR1}%s{CHATCLR} is your trikz buddy now!", szName );
    
    GetClientName( client, szName, sizeof( szName ) );
    Influx_PrintToChat( _, target, "{MAINCLR1}%s{CHATCLR} is your trikz buddy now!", szName );
    
    return 0;
}

public void Influx_OnTimerResetPost( int client )
{
    g_bTouchedEnd[client] = false;
    g_bInStart[client] = true;
    
    // HACK
    int partner = g_iPartner[client];
    
    if ( partner != 0 && !g_bInStart[partner] && Influx_GetClientState( partner ) == STATE_RUNNING )
    {
        Influx_SetClientState( client, STATE_RUNNING );
        Influx_SetClientStartTick( client, Influx_GetClientStartTick( partner ) );
    }
}

public Action Influx_OnTimerStart( int client, int runid, char[] errormsg, int error_len )
{
    if ( g_iPartner[client] == 0 )
    {
        FormatEx( errormsg, error_len, "You do not have a trikz buddy! ({MAINCLR1}!buddy{CHATCLR})" );
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public void Influx_OnTimerStartPost( int client, int runid )
{
    g_bTouchedEnd[client] = false;
    g_bInStart[client] = false;
    
    
    int partner = g_iPartner[client];
    
    if ( Influx_GetClientState( partner ) != STATE_RUNNING )
    {
        Influx_SetClientState( partner, STATE_RUNNING );
        Influx_SetClientStartTick( partner, Influx_GetClientStartTick( client ) );
    }
}

public Action Influx_OnTimerFinish( int client, int runid, int mode, int style, float time, int flags, char[] errormsg, int error_len )
{
    g_bTouchedEnd[client] = true;
    
    
    int partner = g_iPartner[client];
    
    if ( partner != 0 && g_bTouchedEnd[partner] )
    {
        return Plugin_Continue;
    }
    
    
    FormatEx( errormsg, error_len, "You gotta wait for your trikz buddy!" );
    
    return Plugin_Handled;
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    int partner = g_iPartner[client];
    
    if ( partner != 0 && g_bTouchedEnd[partner] && Influx_GetClientState( client ) == STATE_RUNNING )
    {
        Influx_FinishTimer( partner, runid );
    }
}

public Action Influx_OnRecordingStart( int client )
{
    return Plugin_Stop;
}