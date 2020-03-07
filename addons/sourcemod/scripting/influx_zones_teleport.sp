#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_teleport>

#include <msharedutil/arrayvec>


#undef REQUIRE_PLUGIN
#include <influx/zones_beams>


//#define DEBUG


enum
{
    TELE_ZONE_ID = 0,
    
    TELE_ISSET,
    
    TELE_RESETVEL,
    
    TELE_POS[3],
    TELE_ANG[2],
    
    TELE_SIZE
};

ArrayList g_hTeles;


// LIBRARIES
bool g_bLib_Zones_Beams;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones | Teleport",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_ZONES_TELE );
}

public void OnPluginStart()
{
    g_hTeles = new ArrayList( TELE_SIZE );
    
    
    // CMDS
    RegConsoleCmd( "sm_zonesettings_tele", Cmd_ZoneSettings );
    
    
    // LIBRARIES
    g_bLib_Zones_Beams = LibraryExists( INFLUX_LIB_ZONES_BEAMS );
}

public void OnAllPluginsLoaded()
{
    AddZoneType();
}

public void Influx_OnRequestZoneTypes()
{
    AddZoneType();
}

stock void AddZoneType()
{
    if ( !Influx_RegZoneType( ZONETYPE_TELE, "Teleport", "teleport", true ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't register zone type!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveZoneType( ZONETYPE_TELE );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_ZONES_BEAMS ) ) g_bLib_Zones_Beams = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_ZONES_BEAMS ) ) g_bLib_Zones_Beams = false;
}

public void Influx_OnPreRunLoad()
{
    g_hTeles.Clear();
}

public Action Influx_OnZoneLoad( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_TELE ) return Plugin_Continue;
    
    
    float vec[3];
    decl data[TELE_SIZE];
    
    data[TELE_ZONE_ID] = zoneid;
    
    data[TELE_ISSET] = 1;
    
    data[TELE_RESETVEL] = kv.GetNum( "resetvel", 0 );
    
    
    kv.GetVector( "telepos", vec, ORIGIN_VECTOR );
    
    if ( SquareRoot( vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2] ) == 0.0 )
    {
        LogError( INF_CON_PRE..."Teleporter zone (id: %i) has no teleport location, loading anyway...",
            zoneid );
    }
    
    CopyArray( vec, data[TELE_POS], 3 );
    
    
    kv.GetVector( "teleangles", vec, ORIGIN_VECTOR );
    CopyArray( vec, data[TELE_ANG], 2 );
    
    g_hTeles.PushArray( data );
    
    return Plugin_Handled;
}

public Action Influx_OnZoneSave( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_TELE ) return Plugin_Continue;
    
    
    int index = FindTeleById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Teleporter zone (id: %i) is not registered with the plugin! Cannot save!",
            zoneid );
        return Plugin_Stop;
    }
    
    decl data[TELE_SIZE];
    g_hTeles.GetArray( index, data );
    
    if ( !data[TELE_ISSET] )
    {
        LogError( INF_CON_PRE..."Teleporter zone (id: %i) has no teleport location! Cannot save!",
            zoneid );
        return Plugin_Stop;
    }
    
    kv.SetNum( "resetvel", data[TELE_RESETVEL] );
    
    float vec[3];
    
    CopyArray( data[TELE_POS], vec, 3 );
    kv.SetVector( "telepos", vec );
    
    CopyArray( data[TELE_ANG], vec, 2 );
    vec[2] = 0.0; // Reset roll.
    kv.SetVector( "teleangles", vec );
    
    return Plugin_Handled;
}

public void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent )
{
    if ( zonetype != ZONETYPE_TELE ) return;

    
    int index = FindTeleById( zoneid );
    if ( index == -1 ) return;
    
    
    SDKHook( ent, SDKHook_StartTouchPost, E_StartTouchPost_Teleport );
    
    Inf_SetZoneProp( ent, zoneid );
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_TELE ) return;
    
    
    int data[TELE_SIZE];
    data[TELE_ZONE_ID] = zoneid;
    data[TELE_ISSET] = 0;
    
    g_hTeles.PushArray( data );
    
    
    if ( g_bLib_Zones_Beams )
    {
        Influx_SetZoneBeamDisplayType( zoneid, DISPLAYTYPE_BEAMS_FULL );
    }
}

public void Influx_OnZoneDeleted( int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_TELE ) return;
    
    
    int index = FindTeleById( zoneid );  
    if ( index != -1 )
    {
        g_hTeles.Erase( index );
    }
}

public Action Influx_OnZoneSettings( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_TELE ) return Plugin_Continue;
    
    
    FakeClientCommand( client, "sm_zonesettings_tele %i", zoneid );
    
    return Plugin_Stop;
}

public Action Cmd_ZoneSettings( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !args ) return Plugin_Handled;
    
    if ( !Influx_CanUserModifyZones( client ) ) return Plugin_Handled;
    
    
    decl String:szArg[8];
    GetCmdArgString( szArg, sizeof( szArg ) );
    int zoneid = StringToInt( szArg );
    
    int index = FindTeleById( zoneid );
    if ( index == -1 ) return Plugin_Handled;
    
    
    decl data[TELE_SIZE];
    g_hTeles.GetArray( index, data );
    
    
    decl String:szZone[32];
    decl String:szType[32];
    Influx_GetZoneName( zoneid, szZone, sizeof( szZone ) );
    Inf_ZoneTypeToName( ZONETYPE_TELE, szType, sizeof( szType ) );
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Zone Settings\n%s (%s)\n ", szZone, szType );
    
    decl String:szDisplay[92];
    decl String:szInfo[32];
    
    FormatEx( szInfo, sizeof( szInfo ), "a%i", zoneid );
    FormatEx( szDisplay, sizeof( szDisplay ), "Go to teleport destination\nPos: (%.1f, %.1f, %.1f) | Ang: (%.1f, %.1f)\n ",
        data[TELE_POS],
        data[TELE_POS] + 1,
        data[TELE_POS] + 2,
        data[TELE_ANG],
        data[TELE_ANG + 1] );
    
    
    menu.AddItem( szInfo, szDisplay, data[TELE_ISSET] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
    
    
    FormatEx( szDisplay, sizeof( szDisplay ), "Reset Velocity: %s", data[TELE_RESETVEL] ? "ON" : "OFF" );
    FormatEx( szInfo, sizeof( szInfo ), "b%i", zoneid );
    menu.AddItem( szInfo, szDisplay );
    
    
    FormatEx( szInfo, sizeof( szInfo ), "c%i", zoneid );
    menu.AddItem( szInfo, "Set teleport destination" );
    
    
    FormatEx( szInfo, sizeof( szInfo ), "d%i", zoneid );
    menu.AddItem( szInfo, "Set teleport yaw\n " );
    
    
    FormatEx( szInfo, sizeof( szInfo ), "e%i", zoneid );
    menu.AddItem( szInfo, "Find closest teleport destination" );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_Settings( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !Influx_CanUserModifyZones( client ) ) return 0;
    
    
    decl String:szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int zoneid = StringToInt( szInfo[1] );
    
    int itele = FindTeleById( zoneid );
    if ( itele == -1 ) return 0;
    
    switch ( szInfo[0] )
    {
        case 'a' : // Teleport to position.
        {
            TeleportToIndex( itele, client );
        }
        case 'b' : // Set velocity reset
        {
            g_hTeles.Set( itele, !g_hTeles.Get( itele, TELE_RESETVEL ), TELE_RESETVEL );
        }
        case 'c' : // Set pos
        {
            float pos[3];
            GetClientAbsOrigin( client, pos );
            
            SetPosByIndex( itele, pos );
        }
        case 'd' : // Set ang
        {
            float ang[3];
            GetClientEyeAngles( client, ang );
            
            for ( int i = 0; i < 2; i++ ) ang[i] = Inf_SnapTo( ang[i] );
            
            SetAngByIndex( itele, ang );
        }
        case 'e' : // Find teleport destination
        {
            float plypos[3];
            GetClientAbsOrigin( client, plypos );
            
            float dist;
            float pos[3], ang[3];
            
#define DIST_TO_FIND    1024.0
            
            float closestdist = DIST_TO_FIND * DIST_TO_FIND;
            int closestent = -1;
            
            
            int ent = -1;
            while ( (ent = FindEntityByClassname( ent, "info_teleport_destination" )) != -1 )
            {
                GetEntityOrigin( ent, pos );
                
                if ( (dist = GetVectorDistance( pos, plypos, true )) < closestdist )
                {
                    closestdist = dist;
                    closestent = ent;
                }
            }
            
            if ( closestent != -1 )
            {
                GetEntityOrigin( closestent, pos );
                GetEntPropVector( closestent, Prop_Data, "m_angRotation", ang );
                
                SetPosByIndex( itele, pos );
                SetAngByIndex( itele, ang );
                
                Influx_PrintToChat( _, client, "Copying position and angles from entity {MAINCLR1}%i{CHATCLR}!", closestent );
            }
            else
            {
                Influx_PrintToChat( _, client, "Couldn't find a teleport destination within {MAINCLR1}%.0f{CHATCLR} units!", DIST_TO_FIND );
            }
        }
    }
    
    FakeClientCommand( client, "sm_zonesettings_tele %i", zoneid );
    
    return 0;
}

stock void SetPosByIndex( int index, const float pos[3] )
{
    for ( int i = 0; i < 3; i++ ) g_hTeles.Set( index, pos[i], TELE_POS + i );
    
    g_hTeles.Set( index, 1, TELE_ISSET );
}

stock void SetAngByIndex( int index, const float ang[3] )
{
    for ( int i = 0; i < 2; i++ ) g_hTeles.Set( index, ang[i], TELE_ANG + i );
}

public void E_StartTouchPost_Teleport( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    int index = FindTeleById( Inf_GetZoneProp( ent ) );
    if ( index == -1 ) return;
    
    
    if ( g_hTeles.Get( index, TELE_ISSET ) )
    {
        TeleportToIndex( index, activator );
    }
}

stock void TeleportToIndex( int index, int client )
{
    decl data[TELE_SIZE];
    g_hTeles.GetArray( index, data );
    
    decl Float:pos[3];
    CopyArray( data[TELE_POS], pos, 3 );
    
    decl Float:ang[3];
    CopyArray( data[TELE_ANG], ang, 2 );
    ang[2] = 0.0;
    
    TeleportEntity( client, pos, ang, data[TELE_RESETVEL] ? ORIGIN_VECTOR : NULL_VECTOR );
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Client %i was teleported to (%.1f, %.1f, %.1f)",
        client,
        pos[0],
        pos[1],
        pos[2] );
#endif
}

stock int FindTeleById( int id )
{
    int len = g_hTeles.Length;
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hTeles.Get( i, TELE_ZONE_ID ) == id )
            {
                return i;
            }
        }
    }
    
    return -1;
}