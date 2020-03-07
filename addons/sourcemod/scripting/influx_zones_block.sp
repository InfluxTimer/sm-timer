#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_block>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>


#undef REQUIRE_PLUGIN
#include <influx/zones_beams>
#include <influx/pause>
#include <influx/practise>


enum PunishType_t
{
    PUNISH_INVALID = -1,
    
    PUNISH_PUSH,
    PUNISH_TELETOSTART,
    PUNISH_DISABLETIMER,
    
    PUNISH_MAX
};

#define DEF_PUNISHTYPE     PUNISH_PUSH

enum
{
    BLOCK_ZONE_ID = 0,
    
    //BLOCK_ENTREF,
    
    BLOCK_RUNFLAGS,
    BLOCK_ALLOWPRAC,
    BLOCK_PUNISHTYPE,
    
    BLOCK_SIZE
};

enum
{
    FLAGTYPE_RUN = 0,
    FLAGTYPE_PUNISHTYPE,
    FLAGTYPE_ALLOWPRAC
};


ArrayList g_hBlocks;

float g_flNextMsg[INF_MAXPLAYERS];

int g_iBlock[INF_MAXPLAYERS];


PunishType_t g_iDefPunishType;
ConVar g_ConVar_PunishType;


// LIBRARIES
bool g_bLib_Pause;
bool g_bLib_Practise;
bool g_bLib_Zones_Beams;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones | Block",
    description = "They block players, duh.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    RegPluginLibrary( INFLUX_LIB_ZONES_BLOCK );
}

public void OnPluginStart()
{
    g_hBlocks = new ArrayList( BLOCK_SIZE );
    
    
    // CONVARS
    g_ConVar_PunishType = CreateConVar( "influx_zones_block_punishtype", "push", "Default punish type for block zones. (push, teletostart, disabletimer)", FCVAR_NOTIFY );
    g_ConVar_PunishType.AddChangeHook( E_ConVarChanged_PunishType );
    
    
    AutoExecConfig( true, "zones_block", "influx" );
    
    
    SetDefPunish();
    
    
    // MENUS
    RegConsoleCmd( "sm_zonesettings_block", Cmd_ZoneSettings );
    
    
    // LIBRARIES
    g_bLib_Pause = LibraryExists( INFLUX_LIB_PAUSE );
    g_bLib_Practise = LibraryExists( INFLUX_LIB_PRACTISE );
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
    if ( !Influx_RegZoneType( ZONETYPE_BLOCK, "Block", "block", true ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't register zone type!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveZoneType( ZONETYPE_BLOCK );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = true;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = true;
    if ( StrEqual( lib, INFLUX_LIB_ZONES_BEAMS ) ) g_bLib_Zones_Beams = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_PAUSE ) ) g_bLib_Pause = false;
    if ( StrEqual( lib, INFLUX_LIB_PRACTISE ) ) g_bLib_Practise = false;
    if ( StrEqual( lib, INFLUX_LIB_ZONES_BEAMS ) ) g_bLib_Zones_Beams = false;
}

public void OnClientPutInServer( int client )
{
    g_flNextMsg[client] = 0.0;
    
    g_iBlock[client] = 0;
}

public void Influx_OnPreRunLoad()
{
    g_hBlocks.Clear();
}

public Action Influx_OnZoneLoad( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_BLOCK ) return Plugin_Continue;
    
    
    decl data[BLOCK_SIZE];
    
    data[BLOCK_ZONE_ID] = zoneid;
    
    data[BLOCK_RUNFLAGS] = kv.GetNum( "runflags", 0 );
    data[BLOCK_ALLOWPRAC] = kv.GetNum( "allowpracticemode", 1 );
    
    
    char szPunish[32];
    kv.GetString( "punishtype", szPunish, sizeof( szPunish ), "" );
    
    PunishType_t punishtype = PunishNameToType( szPunish );
    
    if ( szPunish[0] && punishtype == PUNISH_INVALID )
    {
        LogError( INF_CON_PRE..."Invalid punish type '%s'!", szPunish );
    }
    
    data[BLOCK_PUNISHTYPE] = view_as<int>( punishtype );
    
    //data[BLOCK_ENTREF] = INVALID_ENT_REFERENCE;
    
    g_hBlocks.PushArray( data );
    
    return Plugin_Handled;
}

public Action Influx_OnZoneSave( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_BLOCK ) return Plugin_Continue;
    
    
    int index = FindBlockById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Block zone (id: %i) is not registered with the plugin! Cannot save!",
            zoneid );
        return Plugin_Stop;
    }
    
    decl data[BLOCK_SIZE];
    g_hBlocks.GetArray( index, data );
    
    if ( data[BLOCK_RUNFLAGS] ) kv.SetNum( "runflags", data[BLOCK_RUNFLAGS] );
    if ( data[BLOCK_ALLOWPRAC] ) kv.SetNum( "allowpracticemode", data[BLOCK_ALLOWPRAC] );
    
    
    PunishType_t type = view_as<PunishType_t>( data[BLOCK_PUNISHTYPE] );
    
    if ( type != PUNISH_INVALID )
    {
        char szPunish[32];
        if ( PunishTypeToName( type, szPunish, sizeof( szPunish ) ) )
        {
            kv.SetString( "punishtype", szPunish );
        }
    }
    
    
    return Plugin_Handled;
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_BLOCK ) return;
    
    
    int data[BLOCK_SIZE];
    data[BLOCK_ZONE_ID] = zoneid;
    data[BLOCK_ALLOWPRAC] = 1;
    data[BLOCK_PUNISHTYPE] = view_as<int>( PUNISH_INVALID );
    
    g_hBlocks.PushArray( data );
    
    
    if ( g_bLib_Zones_Beams )
    {
        Influx_SetZoneBeamDisplayType( zoneid, DISPLAYTYPE_BEAMS_FULL );
    }
}

public void Influx_OnZoneDeleted( int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_BLOCK ) return;
    
    
    int index = FindBlockById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Couldn't find block zone with id %i to delete!", zoneid );
        return;
    }
    
    
    g_hBlocks.Erase( index );
}

public void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent )
{
    if ( zonetype != ZONETYPE_BLOCK ) return;
    
    
    // We only store the run id because that's all we need.
    SDKHook( ent, SDKHook_StartTouchPost, E_StartTouchPost_Block );
    SDKHook( ent, SDKHook_TouchPost, E_TouchPost_Block );
    
    Inf_SetZoneProp( ent, zoneid );
}

public Action Influx_OnZoneSettings( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_BLOCK ) return Plugin_Continue;
    
    
    FakeClientCommand( client, "sm_zonesettings_block %i", zoneid );
    
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
    
    int index = FindBlockById( zoneid );
    if ( index == -1 ) return Plugin_Handled;
    
    
    ArrayList runs = Influx_GetRunsArray();
    int runslen = GetArrayLength_Safe( runs );
    
    if ( runslen < 1 ) return Plugin_Handled;
    
    
    decl String:szZone[32];
    decl String:szType[32];
    Influx_GetZoneName( zoneid, szZone, sizeof( szZone ) );
    Inf_ZoneTypeToName( ZONETYPE_FS, szType, sizeof( szType ) );
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Zone Settings\n%s (%s)\n ", szZone, szType );
    
    
    int id;
    decl String:szName[64];
    decl String:szDisplay[64];
    decl String:szInfo[32];
    
    
    // Practice mode
    FormatEx( szDisplay, sizeof( szDisplay ), "Allow Practice Mode: %s",
        ( g_hBlocks.Get( index, BLOCK_ALLOWPRAC ) ) ? "Yes" : "No" );
    FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i", zoneid, FLAGTYPE_ALLOWPRAC, 0 );
    
    menu.AddItem( szInfo, szDisplay );
    
    
    // Punish type
    PunishType_t punish = view_as<PunishType_t>( g_hBlocks.Get( index, BLOCK_PUNISHTYPE ) );
    
    if ( punish == PUNISH_INVALID )
    {
        PunishTypeToNameEx( g_iDefPunishType, szName, sizeof( szName ) );
        Format( szName, sizeof( szName ), "Use default (%s)", szName );
    }
    else
    {
        PunishTypeToNameEx( punish, szName, sizeof( szName ) );
    }
    
    
    FormatEx( szDisplay, sizeof( szDisplay ), "Punish type: %s\n ", szName );
    FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i", zoneid, FLAGTYPE_PUNISHTYPE, 0 );
    
    menu.AddItem( szInfo, szDisplay );
    
    
    // Run flags.
    int flags = g_hBlocks.Get( index, BLOCK_RUNFLAGS );
    for ( int i = 0; i < runslen; i++ )
    {
        id = runs.Get( i, RUN_ID );
        
        runs.GetString( i, szName, sizeof( szName ) );
        
        
        FormatEx( szDisplay, sizeof( szDisplay ), "%s: %s",
            szName,
            ( flags & (1 << id) ) ? "PASS" : "BLOCK" );
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i", zoneid, FLAGTYPE_RUN, id );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_Settings( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    if ( !Influx_CanUserModifyZones( client ) ) return 0;
    
    
    decl String:szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    int zoneid = -1;
    int type, id;
    if ( !Inf_ParseZoneSettings( szInfo, zoneid, type, id ) ) return 0;
    
    
    // Get our zone index.
    int izone = FindBlockById( zoneid );
    
    if ( izone != -1 )
    {
        if ( type == FLAGTYPE_RUN )
        {
            // Toggle our flag.
            int ourflag = ( 1 << id );
            
            int flags = g_hBlocks.Get( izone, BLOCK_RUNFLAGS );
            
            if ( flags & ourflag )
            {
                g_hBlocks.Set( izone, flags & ~ourflag, BLOCK_RUNFLAGS );
            }
            else
            {
                g_hBlocks.Set( izone, flags | ourflag, BLOCK_RUNFLAGS );
            }
        }
        else if ( type == FLAGTYPE_PUNISHTYPE )
        {
            PunishType_t punishtype = view_as<PunishType_t>( g_hBlocks.Get( izone, BLOCK_PUNISHTYPE ) + 1 );
            
            if ( punishtype < PUNISH_INVALID || punishtype >= PUNISH_MAX )
            {
                punishtype = PUNISH_INVALID;
            }
            
            g_hBlocks.Set( izone, punishtype, BLOCK_PUNISHTYPE );
        }
        else
        {
            bool allow = !g_hBlocks.Get( izone, BLOCK_ALLOWPRAC );
            
            g_hBlocks.Set( izone, allow, BLOCK_ALLOWPRAC );
        }
        
        FakeClientCommand( client, "sm_zonesettings_block %i", zoneid );
    }
    else
    {
        Inf_OpenZoneSettingsMenu( client );
    }
    
    return 0;
}

public void E_ConVarChanged_PunishType( ConVar convar, const char[] oldValue, const char[] newValue )
{
    SetDefPunish();
}

public void E_StartTouchPost_Block( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    int index = FindBlockById( Inf_GetZoneProp( ent ) );
    if ( index == -1 ) return;
    
    
    int runid = Influx_GetClientRunId( activator );
    if ( runid < 1 )
    {
        ResetBlock( activator, ent );
        return;
    }
    
    // Is this run blocked?
    if ( runid > 0 && !(g_hBlocks.Get( index, BLOCK_RUNFLAGS ) & (1 << runid)) )
    {
        // Allow practice mode.
        if ( g_hBlocks.Get( index, BLOCK_ALLOWPRAC ) &&
        (
            (g_bLib_Practise && Influx_IsClientPractising( activator ))
        ||  (g_bLib_Pause && Influx_IsClientPaused( activator ))
        ) )
        {
            ResetBlock( activator, ent );
            return;
        }
        
        Punish( view_as<PunishType_t>( g_hBlocks.Get( index, BLOCK_PUNISHTYPE ) ), activator, ent );
        
        g_iBlock[activator] = ent;
    }
    else
    {
        ResetBlock( activator, ent );
    }
}

stock void ResetBlock( int client, int ent )
{
    if ( g_iBlock[client] == ent )
    {
        g_iBlock[client] = 0;
    }
}

public void E_TouchPost_Block( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    if ( g_iBlock[activator] == ent )
    {
        int index = FindBlockById( Inf_GetZoneProp( ent ) );
        if ( index == -1 ) return;
        
        
        Punish( g_hBlocks.Get( index, BLOCK_PUNISHTYPE ), activator, ent );
    }
}

stock void Punish( PunishType_t punishtype, int client, int ent )
{
    bool print = true;
    
    if ( punishtype == PUNISH_INVALID )
    {
        punishtype = g_iDefPunishType;
    }
    
    switch ( punishtype )
    {
        case PUNISH_DISABLETIMER :
        {
            if ( Influx_GetClientState( client ) == STATE_NONE )
            {
                print = false;
            }
            else
            {
                Influx_InvalidateClientRun( client );
            }
        }
        case PUNISH_TELETOSTART :
        {
            Influx_TeleportToStart( client, true );
        }
        default :
        {
            float spd = GetEntitySpeed( client ) * 0.5;
            
            if ( spd < 300.0 )
            {
                spd = 300.0;
            }
            
            decl Float:temp[3], Float:temp2[3];
            GetClientAbsOrigin( client, temp );
            GetEntityOrigin( ent, temp2 );
            
            float dist = GetVectorDistance( temp, temp2, false );
            for ( int i = 0; i < 3; i++ )
            {
                temp[i] = ( (temp[i] - temp2[i]) / dist ) * spd;
            }
            
            GetClientEyeAngles( client, temp2 );
            temp2[0] = GetRandomFloat( -89.0, 89.0 );
            temp2[1] = GetRandomFloat( -180.0, 180.0 );
            
            TeleportEntity( client, NULL_VECTOR, temp2, temp );
        }
    }
    
    if ( print && GetEngineTime() > g_flNextMsg[client] )
    {
        PrintCenterText( client, "You shouldn't be here!" );
        
        g_flNextMsg[client] = GetEngineTime() + 1.0;
    }
}

stock void SetDefPunish()
{
    char szName[32];
    g_ConVar_PunishType.GetString( szName, sizeof( szName ) );
    
    g_iDefPunishType = PunishNameToType( szName );
}

stock PunishType_t PunishNameToType( const char[] sz )
{
    if ( StrEqual( sz, "push", false ) )
    {
        return PUNISH_PUSH;
    }
    
    if ( StrEqual( sz, "teletostart", false ) )
    {
        return PUNISH_TELETOSTART;
    }
    
    if ( StrEqual( sz, "disabletimer", false ) )
    {
        return PUNISH_DISABLETIMER;
    }
    
    return PUNISH_INVALID;
}

stock void PunishTypeToNameEx( PunishType_t type, char[] sz, int len )
{
    switch ( type )
    {
        case PUNISH_TELETOSTART : strcopy( sz, len, "Teleport to start" );
        case PUNISH_DISABLETIMER : strcopy( sz, len, "Disable timer" );
        default : strcopy( sz, len, "Push away" );
    }
}

stock bool PunishTypeToName( PunishType_t type, char[] sz, int len )
{
    switch ( type )
    {
        case PUNISH_PUSH : strcopy( sz, len, "push" );
        case PUNISH_TELETOSTART : strcopy( sz, len, "teletostart" );
        case PUNISH_DISABLETIMER : strcopy( sz, len, "disabletimer" );
        default :
        {
            strcopy( sz, len, "push" );
            return false;
        }
    }
    
    return true;
}

stock int FindBlockById( int id )
{
    int len = g_hBlocks.Length;
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hBlocks.Get( i, BLOCK_ZONE_ID ) == id )
            {
                return i;
            }
        }
    }
    
    return -1;
}