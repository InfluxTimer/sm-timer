#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/zones>

#include <msharedutil/arrayvec>
#include <msharedutil/ents>
#include <msharedutil/misc>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <influx/zones_beams>
#include <influx/help>


//#define DEBUG
//#define DEBUG_CHECKZONES
//#define DEBUG_LOADZONES


// Exists for both CSS and CS:GO
#define BUILD_MAT                   "materials/sprites/laserbeam.vmt"
#define BUILD_SPRITE_MAT            "materials/sprites/glow01.vmt"
#define MAGIC_ZONE_MODEL            "models/props/cs_office/vending_machine.mdl"


#define ZONE_BUILDDRAW_INTERVAL     0.1

#define BUILD_DEF_DIST              512.0
#define BUILD_MAXDIST               2048.0
#define BUILD_MINDIST               64.0
#define BUILD_DIST_RATE             32.0


#define INF_PRIVCOM_CONFZONES       "sm_inf_configurezones"
#define INF_PRIVCOM_SAVEZONES       "sm_inf_savezones"


enum
{
    ZTYPE_NAME[MAX_ZONE_NAME] = 0,
    ZTYPE_SHORTNAME[MAX_ZONE_NAME],
    
    ZTYPE_TYPE,
    
    ZTYPE_HAS_SETTINGS,
    
    ZTYPE_SIZE
};



ZoneType_t g_iBuildingType[INF_MAXPLAYERS];
float g_vecBuildingStart[INF_MAXPLAYERS][3];
//int g_iBuildingZoneId[INF_MAXPLAYERS];
//int g_iBuildingRunId[INF_MAXPLAYERS];
int g_nBuildingGridSize[INF_MAXPLAYERS];
char g_szBuildingName[INF_MAXPLAYERS][MAX_ZONE_NAME];
bool g_bShowSprite[INF_MAXPLAYERS];
float g_flBuildDist[INF_MAXPLAYERS];



ArrayList g_hZones;
ArrayList g_hZoneTypes;

//int g_nNewZoneId;

int g_iBuildBeamMat;
int g_iBuildSprite;


bool g_bZonesLoaded = false;
bool g_bLate;


// CONVARS
ConVar g_ConVar_SaveZonesOnMapEnd;
ConVar g_ConVar_PreferDb;

ConVar g_ConVar_MinSize;
ConVar g_ConVar_HeightGrace;
ConVar g_ConVar_DefZoneHeight;

ConVar g_ConVar_CrosshairBuild;
ConVar g_ConVar_SpriteSize;


// FORWARDS
Handle g_hForward_OnZoneSettings;

Handle g_hForward_OnPostZoneLoad;
Handle g_hForward_OnZoneLoadPost;
Handle g_hForward_OnZoneLoad;
Handle g_hForward_OnZoneSavePost;
Handle g_hForward_OnZoneSave;

Handle g_hForward_OnZoneBuildAsk;

Handle g_hForward_OnZoneCreated;
Handle g_hForward_OnZoneDeleted;
Handle g_hForward_OnZoneSpawned;

Handle g_hForward_OnRequestZoneTypes;


// LIBRARIES
bool g_bLib_Zones_Beams;


// ADMIN MENU
TopMenu g_hTopMenu;


#include "influx_zones/db.sp"
#include "influx_zones/db_cb.sp"
#include "influx_zones/file.sp"
#include "influx_zones/menus.sp"
#include "influx_zones/menus_hndlrs.sp"
#include "influx_zones/timers.sp"
#include "influx_zones/natives.sp"

public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_ZONES );
    
    // NATIVES
    CreateNative( "Influx_GetZonesArray", Native_GetZonesArray );
    
    CreateNative( "Influx_FindZoneById", Native_FindZoneById );
    
    CreateNative( "Influx_GetZoneName", Native_GetZoneName );
    CreateNative( "Influx_SetZoneName", Native_SetZoneName );
    
    CreateNative( "Influx_GetZoneMinsMaxs", Native_GetZoneMinsMaxs );
    
    CreateNative( "Influx_BuildZone", Native_BuildZone );
    CreateNative( "Influx_DeleteZone", Native_DeleteZone );
    
    CreateNative( "Influx_CanUserModifyZones", Native_CanUserModifyZones );
    
    CreateNative( "Influx_RegZoneType", Native_RegZoneType );
    CreateNative( "Influx_RemoveZoneType", Native_RemoveZoneType );
    
    CreateNative( "Influx_IsValidZoneType", Native_IsValidZoneType );
    CreateNative( "Influx_GetZoneTypeName", Native_GetZoneTypeName );
    CreateNative( "Influx_GetZoneTypeShortName", Native_GetZoneTypeShortName );
    CreateNative( "Influx_GetZoneTypeByShortName", Native_GetZoneTypeByShortName );
    
    CreateNative( "Influx_SetDrawBuildingSprite", Native_SetDrawBuildingSprite );
    
    
    g_bLate = late;
}

public void OnPluginStart()
{
    // FORWARDS
    g_hForward_OnZoneCreated = CreateGlobalForward( "Influx_OnZoneCreated", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnZoneDeleted = CreateGlobalForward( "Influx_OnZoneDeleted", ET_Ignore, Param_Cell, Param_Cell );
    g_hForward_OnZoneSpawned = CreateGlobalForward( "Influx_OnZoneSpawned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    
    g_hForward_OnRequestZoneTypes = CreateGlobalForward( "Influx_OnRequestZoneTypes", ET_Ignore );
    
    
    g_hForward_OnPostZoneLoad = CreateGlobalForward( "Influx_OnPostZoneLoad", ET_Ignore );
    
    
    g_hForward_OnZoneLoad = CreateGlobalForward( "Influx_OnZoneLoad", ET_Hook, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnZoneLoadPost = CreateGlobalForward( "Influx_OnZoneLoadPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnZoneSave = CreateGlobalForward( "Influx_OnZoneSave", ET_Hook, Param_Cell, Param_Cell, Param_Cell );
    g_hForward_OnZoneSavePost = CreateGlobalForward( "Influx_OnZoneSavePost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
    
    g_hForward_OnZoneBuildAsk = CreateGlobalForward( "Influx_OnZoneBuildAsk", ET_Hook, Param_Cell, Param_Cell );
    
    g_hForward_OnZoneSettings = CreateGlobalForward( "Influx_OnZoneSettings", ET_Hook, Param_Cell, Param_Cell, Param_Cell );
    
    
    // EVENTS
    if ( GetEngineVersion() == Engine_CSGO )
    {
        HookEvent( "round_poststart", E_RoundRestart, EventHookMode_PostNoCopy );
    }
    else
    {
        HookEvent( "round_freeze_end", E_RoundRestart, EventHookMode_PostNoCopy );
    }
    
    
    // PRIVILEGE CMDS
    RegAdminCmd( INF_PRIVCOM_CONFZONES, Cmd_Empty, ADMFLAG_ROOT );
    RegAdminCmd( INF_PRIVCOM_SAVEZONES, Cmd_Empty, ADMFLAG_ROOT );
    
    
    // CMDS
#if defined DEBUG_CHECKZONES
    RegAdminCmd( "sm_checkzones", Cmd_Debug_CheckZones, ADMFLAG_ROOT );
#endif

#if defined DEBUG
    RegAdminCmd( "sm_printzonetypes", Cmd_Debug_PrintZoneTypes, ADMFLAG_ROOT );
#endif
    
    RegConsoleCmd( "sm_savezones", Cmd_SaveZones );
    
    RegConsoleCmd( "sm_zone", Cmd_ZoneMain );
    RegConsoleCmd( "sm_zones", Cmd_ZoneMain );
    
    RegConsoleCmd( "sm_createzone", Cmd_CreateZone );
    RegConsoleCmd( "sm_cancelzone", Cmd_CancelZone );
    RegConsoleCmd( "sm_endzone", Cmd_EndZone );
    RegConsoleCmd( "sm_deletezone", Cmd_DeleteZone );
    //RegConsoleCmd( "sm_beamsettings", Cmd_BeamSettings );
    RegConsoleCmd( "sm_zonesettings", Cmd_ZoneSettings );
    RegConsoleCmd( "sm_teletozone", Cmd_ZoneTele );
    
    
    // CONVARS
    g_ConVar_SaveZonesOnMapEnd = CreateConVar( "influx_zones_savezones", "0", "Do we automatically save zones on map end?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_PreferDb = CreateConVar( "influx_zones_preferdb", "1", "Is database preferred method of saving zones?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    
    
    g_ConVar_MinSize = CreateConVar( "influx_zones_minzonesize", "4", "Minimum size of a zone in X, Y and Z.", FCVAR_NOTIFY, true, 1.0 );
    g_ConVar_HeightGrace = CreateConVar( "influx_zones_heightgrace", "4", "If zone height is smaller than this, use default zone height. 0 = disable", FCVAR_NOTIFY, true, 0.0 );
    g_ConVar_DefZoneHeight = CreateConVar( "influx_zones_defzoneheight", "128", "Default zone height to use.", FCVAR_NOTIFY, true, 0.0 );
    
    g_ConVar_CrosshairBuild = CreateConVar( "influx_zones_crosshairbuild", "1", "Use crosshair to build instead of your position.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
    g_ConVar_SpriteSize = CreateConVar( "influx_zones_buildspritesize", "0.2", "Size of the sprite when lining the start of the zone.", FCVAR_NOTIFY, true, 0.0 );
    
    
    AutoExecConfig( true, "zones", "influx" );
    
    
    // LIBRARIES
    g_bLib_Zones_Beams = LibraryExists( INFLUX_LIB_ZONES_BEAMS );
    
    
    g_hZones = new ArrayList( ZONE_SIZE );
    g_hZoneTypes = new ArrayList( ZTYPE_SIZE );
    
    
    if ( g_bLate )
    {
        TopMenu topmenu;
        if ( LibraryExists( "adminmenu" ) && (topmenu = GetAdminTopMenu()) != null )
        {
            OnAdminMenuReady( topmenu );
        }
    }
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_ZONES_BEAMS ) ) g_bLib_Zones_Beams = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_ZONES_BEAMS ) ) g_bLib_Zones_Beams = false;
}

public void OnAllPluginsLoaded()
{
    if ( g_bLate )
    {
        g_hZoneTypes.Clear();
        
        Call_StartForward( g_hForward_OnRequestZoneTypes );
        Call_Finish();
    }
    
    
    DB_Init();
}

public void OnAdminMenuReady( Handle hTopMenu )
{
    TopMenu topmenu = TopMenu.FromHandle( hTopMenu );
    
    if ( topmenu == g_hTopMenu )
        return;
    
    TopMenuObject res = topmenu.FindCategory( INFLUX_ADMMENU );
    
    if ( res == INVALID_TOPMENUOBJECT )
    {
        return;
    }
    
    
    g_hTopMenu = topmenu;
    g_hTopMenu.AddItem( "sm_zones", AdmMenu_ZoneMenu, res, INF_PRIVCOM_CONFZONES, 0 );
}

public void AdmMenu_ZoneMenu( TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength )
{
    if ( action == TopMenuAction_DisplayOption )
    {
        strcopy( buffer, maxlength, "Zone Menu" );
    }
    else if ( action == TopMenuAction_SelectOption )
    {
        FakeClientCommand( client, "sm_zones" );
    }
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "zone", "Display zone menu.", true );
    Influx_AddHelpCommand( "savezones", "Saves all current zones.", true );
}

public void Influx_OnPreRunLoad()
{
    // OnMapStart but make sure to do it before loading files.
    PrecacheEverything();
}

public void OnMapStart()
{
    // If we're late-loaded the above may not be called.
    PrecacheEverything();
}

public void OnMapEnd()
{
    if ( g_ConVar_SaveZonesOnMapEnd.BoolValue )
    {
        SaveZones();
    }
    
    g_bZonesLoaded = false;
    g_hZones.Clear();
}

public void Influx_OnPostRunLoad()
{
    LoadZones();
    
    //g_nNewZoneId = FindZoneHighestId() + 1;
}

public void Influx_OnPostZoneLoad()
{
    SpawnZones();
}

public void OnClientPutInServer( int client )
{
    g_iBuildingType[client] = ZONETYPE_INVALID;
    g_nBuildingGridSize[client] = 8;
    g_szBuildingName[client][0] = '\0';
    g_bShowSprite[client] = false;
    g_flBuildDist[client] = BUILD_DEF_DIST;
    
    
    CheckZones();
}

public void E_RoundRestart( Event event, const char[] szEvent, bool bImUselessWhyDoIExist )
{
    CreateTimer( 0.2, T_RoundRestart_Delay, _, TIMER_FLAG_NO_MAPCHANGE );
}

public Action T_RoundRestart_Delay( Handle hTimer )
{
    CheckZones();
}

#if defined DEBUG_CHECKZONES
public Action Cmd_Debug_CheckZones( int client, int args )
{
    CheckZones( client, true );
    
    return Plugin_Handled;
}
#endif

#if defined DEBUG
public Action Cmd_Debug_PrintZoneTypes( int client, int args )
{
    if ( client ) return Plugin_Handled;
    
    
    decl data[ZTYPE_SIZE];
    
    int len = g_hZoneTypes.Length;
    for ( int i = 0; i < len; i++ )
    {
        g_hZoneTypes.GetArray( i, data );
        
        PrintToServer( "%i | %s | %s", data[ZTYPE_TYPE], data[ZTYPE_NAME], data[ZTYPE_SHORTNAME] );
    }
    
    if ( !len )
    {
        PrintToServer( "None!" );
    }
    
    return Plugin_Handled;
}
#endif

stock void CheckZones( int issuer = 0, bool bForcePrint = false )
{
    int num = 0;
    
    int len = g_hZones.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( FindZoneType( view_as<ZoneType_t>( g_hZones.Get( i, ZONE_TYPE ) ) ) == -1 )
            continue;
        
        
        if ( EntRefToEntIndex( g_hZones.Get( i, ZONE_ENTREF ) ) < 1 )
        {
            if ( CreateZoneEntityByIndex( i ) != -1 )
                ++num;
        }
    }
    
    if ( num || bForcePrint )
    {
        Inf_ReplyToClient( issuer, "Spawned {MAINCLR1}%i{CHATCLR} zones!", num );
    }
}

stock void RoundVector( float vec[3] )
{
    for ( int i = 0; i < 3; i++ ) vec[i] = float( RoundFloat( vec[i] ) );
}

stock void SnapToGrid( float vec[3], int grid, int axis = 2 )
{
    if ( axis < 0 ) axis = 0;
    else if ( axis > 3 ) axis = 3;
    
    for ( int i = 0; i < axis; i++ )
    {
        vec[i] = Inf_SnapTo( vec[i], grid );
    }
}

stock bool StartToBuild( int client, ZoneType_t zonetype, const char[] name = "" )
{
    // We don't need to show the sprite anymore.
    g_bShowSprite[client] = false;
    
    
    if ( !IsValidZoneType( zonetype ) ) return false;
    
    
    g_iBuildingType[client] = zonetype;
    
    float pos[3];
    
    if ( g_ConVar_CrosshairBuild.BoolValue )
    {
        GetEyeTrace( client, pos );
    }
    else
    {
        GetClientAbsOrigin( client, pos );
    }
    
    SnapToGrid( pos, g_nBuildingGridSize[client], 2 );
    RoundVector( pos );
    
    
    g_vecBuildingStart[client] = pos;
    
    
    CreateTimer( ZONE_BUILDDRAW_INTERVAL, T_DrawBuildBeams, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
    
    
    char szName[MAX_ZONE_NAME];
    
    if ( name[0] != '\0' )
    {
        strcopy( g_szBuildingName[client], sizeof( g_szBuildingName[] ), name );
        
        strcopy( szName, sizeof( szName ), name );
    }
    else
    {
        g_szBuildingName[client][0] = '\0';
        
        GetZoneTypeName( zonetype, szName, sizeof( szName ) );
    }
    
    
    Influx_PrintToChat( _, client, "Started building {MAINCLR1}%s{CHATCLR}!", szName );
    
    return true;
}

stock int GetZoneTypeCount( ZoneType_t zonetype )
{
    int count = 0;
    
    int len = g_hZones.Length;
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++  )
        {
            if ( view_as<ZoneType_t>( g_hZones.Get( i, ZONE_TYPE ) ) == zonetype )
            {
                ++count;
            }
        }
    }
    
    return count;
}

stock int GetZoneFromPos( int startindex, const float pos[3] )
{
    if ( startindex < 0 ) startindex = 0;
    
    
    int len = g_hZones.Length;
    if ( startindex >= len ) return -1;
    
    
    float mins[3], maxs[3];
    int data[ZONE_SIZE];
    
    for ( int i = startindex; i < len; i++ )
    {
        g_hZones.GetArray( i, data, sizeof( data ) );
        
        CopyArray( data[ZONE_MINS], mins, 3 );
        CopyArray( data[ZONE_MAXS], maxs, 3 );
        
        if ( IsInsideBounds( pos, mins, maxs ) )
        {
            return i;
        }
    }
    
    return -1;
}

stock int CreateZoneEntity( int zoneid )
{
    int index = FindZoneById( zoneid );
    if ( index == -1 ) return -1;
    
    
    return CreateZoneEntityByIndex( index );
}

stock int CreateZoneEntityByIndex( int index )
{
#if defined DEBUG
    char szName[32];
    GetZoneNameByIndex( index, szName, sizeof( szName ) );
    
    PrintToServer( INF_DEBUG_PRE..."Creating zone entity ('%s')...", szName );
#endif

    float mins[3], maxs[3];
    GetZoneMinsMaxsByIndex( index, mins, maxs );
    
    int ent = CreateTriggerEnt( mins, maxs );
    if ( ent < 1 ) return -1;
    
    g_hZones.Set( index, EntIndexToEntRef( ent ), ZONE_ENTREF );
    
    
    Call_StartForward( g_hForward_OnZoneSpawned );
    Call_PushCell( g_hZones.Get( index, ZONE_ID ) );
    Call_PushCell( g_hZones.Get( index, ZONE_TYPE ) );
    Call_PushCell( ent );
    Call_Finish();
    
    return ent;
}

stock int CreateZone( int client, const float mins[3], const float maxs[3], ZoneType_t zonetype )
{
    char szName[MAX_ZONE_NAME];
    
    if ( g_szBuildingName[client][0] == '\0' )
    {
        GetZoneTypeName( zonetype, szName, sizeof( szName ) );
        
        Format( szName, sizeof( szName ), "%s #%i", szName, GetZoneTypeCount( zonetype ) + 1 );
    }
    else
    {
        strcopy( szName, sizeof( szName ), g_szBuildingName[client] );
    }
    
    
    
    
    // Find unused zone id.
    int zoneid = 1;
    for ( int i = 0; i < g_hZones.Length; )
    {
        if ( g_hZones.Get( i, ZONE_ID ) == zoneid )
        {
            ++zoneid;
            i = 0;
        }
        else
        {
            ++i;
        }
    }
    
    //int zoneid = g_nNewZoneId++;
    
    int data[ZONE_SIZE];
    
    data[ZONE_TYPE] = view_as<int>( zonetype );
    data[ZONE_ID] = zoneid;
    CopyArray( mins, data[ZONE_MINS], 3 );
    CopyArray( maxs, data[ZONE_MAXS], 3 );
    
    int index = g_hZones.PushArray( data );
    
    SetZoneNameByIndex( index, szName );
    
    
    Call_StartForward( g_hForward_OnZoneCreated );
    Call_PushCell( client );
    Call_PushCell( zoneid );
    Call_PushCell( zonetype );
    Call_Finish();
    
    
    g_iBuildingType[client] = ZONETYPE_INVALID;
    
    // Get name again in case it was updated.
    GetZoneName( zoneid, szName, sizeof( szName ) );
    
    Influx_PrintToChat( _, client, "Created zone {MAINCLR1}%s{CHATCLR}!", szName );
    
    
    // May be changed above.
    return CreateZoneEntity( zoneid );
}

stock int GetZoneNameCount( const char[] szName )
{
    int num = 0;
    
    char szComp[32];
    
    int len = g_hZones.Length;
    for ( int i = 0; i < len; i++ )
    {
        GetZoneNameByIndex( i, szComp, sizeof( szComp ) )
        
        if ( StrContains( szComp, szName, false ) == 0 )
        {
            ++num;
        }
    }
    
    return num;
}

stock void GetZoneName( int id, char[] sz, int len )
{
    GetZoneNameByIndex( FindZoneById( id ), sz, len );
}

stock void GetZoneNameByIndex( int index, char[] sz, int len )
{
    if ( index == -1 ) return;
    
    
    g_hZones.GetString( index, sz, len );
}

stock void GetZoneMinsMaxsByIndex( int index, float mins_out[3], float maxs_out[3] )
{
    mins_out[0] = g_hZones.Get( index, ZONE_MINS );
    mins_out[1] = g_hZones.Get( index, ZONE_MINS + 1 );
    mins_out[2] = g_hZones.Get( index, ZONE_MINS + 2 );
    
    maxs_out[0] = g_hZones.Get( index, ZONE_MAXS );
    maxs_out[1] = g_hZones.Get( index, ZONE_MAXS + 1 );
    maxs_out[2] = g_hZones.Get( index, ZONE_MAXS + 2 );
}

stock void DeleteZoneWithClient( int client, int index )
{
    if ( index <= -1 )
    {
        Influx_PrintToChat( _, client, "Couldn't find a zone!" );
        return;
    }
    
    
    decl String:szZone[MAX_ZONE_NAME];
    g_hZones.GetString( index, szZone, sizeof( szZone ) );
    
    if ( DeleteZoneByIndex( index ) )
    {
        Influx_PrintToChat( _, client, "Deleted {MAINCLR1}%s{CHATCLR}!", szZone );
    }
    else
    {
        Influx_PrintToChat( _, client, "Couldn't delete {MAINCLR1}%s{CHATCLR}!", szZone );
    }
}

stock bool DeleteZone( int id )
{
    int index = FindZoneById( id );
    
    return DeleteZoneByIndex( index );
}

stock bool DeleteZoneByIndex( int index )
{
    if ( !VALID_ARRAY_INDEX( g_hZones, index ) )
        return false;
    
    
    int ent = EntRefToEntIndex( g_hZones.Get( index, ZONE_ENTREF ) );
    
    if ( ent > 0 && !KillEntity( ent ) )
    {
        LogError( "Couldn't kill zone entity! (%i)", ent );
    }
    
    
    int zoneid = g_hZones.Get( index, ZONE_ID );
    ZoneType_t zonetype = view_as<ZoneType_t>( g_hZones.Get( index, ZONE_TYPE ) );
    
    
    g_hZones.Erase( index );
    
    Call_StartForward( g_hForward_OnZoneDeleted );
    Call_PushCell( zoneid );
    Call_PushCell( zonetype );
    Call_Finish();
    
    
    // HACK: Just force a database removal here, otherwise the zones will persistent forever.
    DB_RemoveZone( zoneid );
    
    return true;
}

stock int FindZoneHighestId()
{
    int highest = 0;
    
    int len = g_hZones.Length;
    
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hZones.Get( i, ZONE_ID ) > highest )
            {
                highest = g_hZones.Get( i, ZONE_ID );
            }
        }
    }
    
    return highest;
}

stock int FindZoneById( int zoneid )
{
    int len = g_hZones.Length;
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hZones.Get( i, ZONE_ID ) == zoneid )
            {
                return i;
            }
        }
    }
    
    return -1;
}

stock bool CanUserModifyZones( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_CONFZONES, ADMFLAG_ROOT );
}

stock bool CanUserSaveZones( int client )
{
    return CheckCommandAccess( client, INF_PRIVCOM_SAVEZONES, ADMFLAG_ROOT );
}

stock void SetShowBuild( int client, bool show = true )
{
    if ( g_bShowSprite[client] )
    {
        g_bShowSprite[client] = show;
        
        return;
    }
    
    
    CreateTimer( ZONE_BUILDDRAW_INTERVAL, T_DrawBuildStart, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
    
    g_bShowSprite[client] = show;
}

stock void GetEyeTrace( int client, float pos[3] )
{
    decl Float:temp[3];
    
    GetClientEyePosition( client, pos );
    GetClientEyeAngles( client, temp );
    
    GetAngleVectors( temp, temp, NULL_VECTOR, NULL_VECTOR );
    
    for ( int i = 0; i < 3; i++ ) temp[i] = pos[i] + temp[i] * g_flBuildDist[client];
    
    TR_TraceRayFilter( pos, temp, MASK_SOLID, RayType_EndPoint, TraceFilter_Build );
    
    TR_GetEndPosition( pos );
}

public bool TraceFilter_Build( int ent, int mask )
{
    return ( ent == 0 || ent > MaxClients );
}

stock void HandleTraceDist( int client )
{
    // Poor man's version.
    int buttons = GetEntProp( client, Prop_Data, "m_nOldButtons" );
    
    if ( buttons & IN_ATTACK )
    {
        g_flBuildDist[client] += BUILD_DIST_RATE;
    }
    else if ( buttons & IN_ATTACK2 )
    {
        g_flBuildDist[client] -= BUILD_DIST_RATE;
    }
    
    if ( g_flBuildDist[client] > BUILD_MAXDIST )
    {
        g_flBuildDist[client] = BUILD_MAXDIST;
    }
    else if ( g_flBuildDist[client] < BUILD_MINDIST )
    {
        g_flBuildDist[client] = BUILD_MINDIST;
    }
}

stock int CreateTriggerEnt( const float mins[3], const float maxs[3] )
{
    PrecacheZoneModel();
    
    
    int ent = CreateEntityByName( "trigger_multiple" );
    
    if ( ent < 1 )
    {
        LogError( INF_CON_PRE..."Couldn't create trigger entity!" );
        return -1;
    }
    
    // 0 will set it to 0.1
    // wait-value should not affect the touch outputs, but just in case.
    DispatchKeyValue( ent, "wait", "0.001" );
    
#define SF_CLIENTS  1
#define SF_NOBOTS   4096
    
    char szSpawn[16];
    FormatEx( szSpawn, sizeof( szSpawn ), "%i", SF_CLIENTS | SF_NOBOTS );
    DispatchKeyValue( ent, "spawnflags", szSpawn ); 
    
    if ( !DispatchSpawn( ent ) )
    {
        LogError( INF_CON_PRE..."Couldn't spawn trigger entity!" );
        return -1;
    }
    
    
    float origin[3], newmins[3], newmaxs[3];
    
    ActivateEntity( ent );
    
    
    SetEntityModel( ent, MAGIC_ZONE_MODEL );
    
    
#define EF_NODRAW   32
    
    SetEntProp( ent, Prop_Send, "m_fEffects", EF_NODRAW );
    
    
    newmaxs[0] = ( maxs[0] - mins[0] ) * 0.5;
    newmaxs[1] = ( maxs[1] - mins[1] ) * 0.5;
    newmaxs[2] = ( maxs[2] - mins[2] ) * 0.5;
    
    origin[0] = mins[0] + newmaxs[0];
    origin[1] = mins[1] + newmaxs[1];
    origin[2] = mins[2] + newmaxs[2];
    
    
    TeleportEntity( ent, origin, NULL_VECTOR, NULL_VECTOR );
    
    
    newmins[0] = -newmaxs[0];
    newmins[1] = -newmaxs[1];
    newmins[2] = -newmaxs[2];
    
    SetEntPropVector( ent, Prop_Send, "m_vecMins", newmins );
    SetEntPropVector( ent, Prop_Send, "m_vecMaxs", newmaxs );
    SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // Essential! Use bounding box instead of model's bsp(?) for input.
    
    return ent;
}

stock bool AddZoneType( ZoneType_t type, const char[] szName, const char[] szShortName, bool bHasSettings )
{
    if ( FindZoneType( type ) != -1 ) return false;
    
    
    int data[ZTYPE_SIZE];
    
    strcopy( view_as<char>( data[ZTYPE_NAME] ), MAX_ZONE_NAME, szName );
    strcopy( view_as<char>( data[ZTYPE_SHORTNAME] ), MAX_ZONE_NAME, szShortName );
    
    data[ZTYPE_TYPE] = view_as<int>( type );
    data[ZTYPE_HAS_SETTINGS] = bHasSettings;
    
    g_hZoneTypes.PushArray( data );
    
    ImportantTypesToHead();
    
    return true;
}

stock bool RemoveZoneType( ZoneType_t type )
{
    int index = FindZoneType( type );
    
    if ( index != -1 )
    {
        g_hZoneTypes.Erase( index );
        return true;
    }
    
    return false;
}

stock int FindZoneType( ZoneType_t type )
{
    int len = g_hZoneTypes.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hZoneTypes.Get( i, ZTYPE_TYPE ) == view_as<int>( type ) )
        {
            return i;
        }
    }
    
    return -1;
}

stock void GetZoneTypeName( ZoneType_t type, char[] sz, int len )
{
    GetZoneTypeNameByIndex( FindZoneType( type ), sz, len );
}

stock void GetZoneTypeNameByIndex( int index, char[] sz, int len )
{
    if ( index != -1 )
    {
        g_hZoneTypes.GetString( index, sz, len );
    }
    else
    {
        strcopy( sz, len, "N/A" );
    }
}

stock void GetZoneTypeShortName( ZoneType_t type, char[] sz, int len )
{
    GetZoneTypeShortNameByIndex( FindZoneType( type ), sz, len );
}

stock void GetZoneTypeShortNameByIndex( int index, char[] sz, int len )
{
    if ( index != -1 )
    {
        decl name[MAX_ZONE_NAME_CELL];
        
        for ( int i = 0; i < MAX_ZONE_NAME_CELL; i++ )
        {
            name[i] = g_hZoneTypes.Get( index, ZTYPE_SHORTNAME + i ); 
        }
        
        strcopy( sz, len, view_as<char>( name ) );
    }
    else
    {
        strcopy( sz, len, "N/A" );
    }
}

stock ZoneType_t FindZoneTypeByShortName( const char[] sz )
{
    decl String:szName[32];
    
    int len = g_hZoneTypes.Length;
    for ( int i = 0; i < len; i++ )
    {
        GetZoneTypeShortNameByIndex( i, szName, sizeof( szName ) );
        
        if ( StrEqual( sz, szName ) )
        {
            return view_as<ZoneType_t>( g_hZoneTypes.Get( i, ZTYPE_TYPE ) );
        }
    }
    
    return ZONETYPE_INVALID;
}

// This stock name is giving me cancer.
stock bool ZoneTypeHasSettings( ZoneType_t type )
{
    int i = FindZoneType( type );
    if ( i == -1 ) return false;
    
    return g_hZoneTypes.Get( i, ZTYPE_HAS_SETTINGS );
}

stock void SetZoneName( int zoneid, const char[] szName )
{
    SetZoneNameByIndex( FindZoneById( zoneid ), szName );
}

stock void SetZoneNameByIndex( int index, const char[] szName )
{
    if ( index == -1 ) return;
    
    
    char sz[MAX_ZONE_NAME];
    
    strcopy( sz, sizeof( sz ), szName );
    
    
    // Make sure our name isn't already taken.
    int num = GetZoneNameCount( sz );
    if ( num )
    {
        Format( sz, sizeof( sz ), "%s (%i)", sz, num + 1 );
    }
    
    
    g_hZones.SetString( index, sz );
}

stock bool IsValidZoneType( ZoneType_t zonetype )
{
    return ( FindZoneType( zonetype ) != -1 ) ? true : false;
}

stock void ImportantTypesToHead()
{
    // HACK: Display start and end types at the start of the menus.
    int i, k;
    ZoneType_t type;
    
    int j = 0;
    
    int len = g_hZoneTypes.Length;
    
    ZoneType_t important[] = { ZONETYPE_START, ZONETYPE_END };
    
    for ( i = 0; i < len; i++ )
    {
        type = view_as<ZoneType_t>( g_hZoneTypes.Get( i, ZTYPE_TYPE ) );
        
        
        for ( k = 0; k < sizeof( important ); k++ )
        {
            if ( type != important[k] ) continue;
            
            if ( j != i )
                g_hZoneTypes.SwapAt( i, j );
            
            ++j;
        }
    }
}

stock void PrecacheZoneModel()
{
    if ( IsModelPrecached( MAGIC_ZONE_MODEL ) )
        return;
    
    
    if ( !PrecacheModel( MAGIC_ZONE_MODEL ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't precache zone model '%s'!", MAGIC_ZONE_MODEL );
    }
}

stock void PrecacheEverything()
{
    PrecacheZoneModel();
    
    if ( !(g_iBuildBeamMat = PrecacheModel( BUILD_MAT )) )
    {
        SetFailState( INF_CON_PRE..."Couldn't precache building beam material '%s'!", BUILD_MAT );
    }
    
    if ( !(g_iBuildSprite = PrecacheModel( BUILD_SPRITE_MAT )) )
    {
        SetFailState( INF_CON_PRE..."Couldn't precache building sprite material '%s'!", BUILD_SPRITE_MAT );
    }
}

stock void ReloadZones()
{
    g_bZonesLoaded = false;
    g_hZones.Clear();
    
    ReadZoneFile();
}

stock void SpawnZones()
{
    for ( int i = 0; i < g_hZones.Length; i++ )
    {
        CreateZoneEntityByIndex( i );
    }
}

stock bool LoadZoneFromKv( KeyValues kv )
{
    decl data[ZONE_SIZE];
    
    float mins[3], maxs[3];
    ZoneType_t zonetype;
    int zoneid;
    
    char szType[32];
    bool bInvalidZoneType;
    char szZoneName[MAX_ZONE_NAME];
    
    
    kv.GetString( "type", szType, sizeof( szType ), "" );
    
    if ( IsCharNumeric( szType[0] ) )
    {
        zonetype = view_as<ZoneType_t>( StringToInt( szType ) );
    }
    else
    {
        zonetype = FindZoneTypeByShortName( szType );
    }
    
    bInvalidZoneType = zonetype == ZONETYPE_INVALID || FindZoneType( zonetype ) == -1;
    
    if ( bInvalidZoneType )
    {
        if ( !g_bLate )
        {
            //LogError( INF_CON_PRE..."Found invalid zone type %i!", zonetype );
        }
        
        return false;
    }
    
    zoneid = kv.GetNum( "id", -1 );
    if ( zoneid < 1 )
    {
        LogError( INF_CON_PRE..."Found invalid zone id value! (id: %i)", zoneid );
        return false;
    }
    
    
    if ( FindZoneById( zoneid ) != -1 )
    {
        LogError( INF_CON_PRE..."Found duplicate zone id! (id: %i)", zoneid );
        return false;
    }
    
    kv.GetVector( "mins", mins, ORIGIN_VECTOR );
    kv.GetVector( "maxs", maxs, ORIGIN_VECTOR );
    
    if ( GetVectorDistance( mins, maxs, false ) < 1.0 )
    {
        LogError( INF_CON_PRE..."Invalid zone mins and maxs! (id: %i)", zoneid );
        return false;
    }
    
    
    kv.GetString( "name", szZoneName, sizeof( szZoneName ), "" );
    if ( szZoneName[0] == 0 )
    {
        // Fallback to section name.
        if ( !kv.GetSectionName( szZoneName, sizeof( szZoneName ) ) )
        {
            LogError( INF_CON_PRE..."Couldn't find zone name! (id: %i)", zoneid );
        }
    }
    
    strcopy( view_as<char>( data[RUN_NAME] ), MAX_ZONE_NAME, szZoneName );
    
    
    // Ask other plugins what to load.
    Action res = Plugin_Continue;
    
    Call_StartForward( g_hForward_OnZoneLoad );
    Call_PushCell( zoneid );
    Call_PushCell( zonetype );
    Call_PushCell( view_as<int>( kv ) );
    Call_Finish( res );
    
    if ( res == Plugin_Stop )
    {
        LogError( INF_CON_PRE..."Couldn't load zone %s with type %i from file! (id: %i)", data[ZONE_NAME], zonetype, zoneid );
        return false;
    }
    
    // Post load (this zone will be loaded)
    Call_StartForward( g_hForward_OnZoneLoadPost );
    Call_PushCell( zoneid );
    Call_PushCell( zonetype );
    Call_PushCell( view_as<int>( kv ) );
    Call_Finish();
    
    
    
    data[ZONE_ID] = zoneid;
    data[ZONE_TYPE] = view_as<int>( zonetype );
    
    CopyArray( mins, data[ZONE_MINS], 3 );
    CopyArray( maxs, data[ZONE_MAXS], 3 );
    
    
    g_hZones.PushArray( data );
    
    return true;
}

stock void LoadZones( bool bForceType = false, bool bUseDb = false )
{
    bool usedb = (bForceType && bUseDb) || (!bForceType && WantsZonesToDb());
    
    
    PrintToServer( INF_CON_PRE..."Loading zones from %s...", usedb ? "database" : "file" );
    
    
    if ( usedb )
    {
        DB_LoadZones();
    }
    else
    {
        ReadZoneFile();
        SendZonesLoadPost();
    }
}

stock void SendZonesLoadPost()
{
    Call_StartForward( g_hForward_OnPostZoneLoad );
    Call_Finish();
}

stock int SaveZones( bool bForceType = false, bool bUseDb = false )
{
    ArrayList kvs = new ArrayList( 2 );
    
    BuildZoneKvs( kvs );
    
    
    bool usedb = (bForceType && bUseDb) || (!bForceType && WantsZonesToDb());
    
    int num = 0;
    
    
    if ( usedb )
    {
        num = DB_SaveZones( kvs );
    }
    else
    {
        num = WriteZoneFile( kvs );
    }
    
    
    // Free the kvs
    for ( int i = 0; i < kvs.Length; i++ )
        delete view_as<KeyValues>( kvs.Get( i, 0 ) );
    
    delete kvs;
    
    return num;
}

stock void BuildZoneKvs( ArrayList kvs )
{
    char szBuffer[256];
    char szKeyValueName[64];
    
    decl data[ZONE_SIZE];
    
    
    for ( int i = 0; i < g_hZones.Length; i++ )
    {
        g_hZones.GetArray( i, data, sizeof( data ) );
        
        
        int zoneid = data[ZONE_ID];
        if ( zoneid < 1 ) continue;
        
        
        ZoneType_t zonetype = view_as<ZoneType_t>( data[ZONE_TYPE] );
        
        int itype = FindZoneType( zonetype );
        if ( itype == -1 )
        {
            continue;
        }
        


        FormatEx( szKeyValueName, sizeof( szKeyValueName ), "Zone%i", zoneid );
        KeyValues kv = new KeyValues( szKeyValueName );
        

        kv.SetNum( "id", zoneid );
        
        
        GetZoneTypeShortNameByIndex( itype, szBuffer, sizeof( szBuffer ) );
        kv.SetString( "type", szBuffer );
        
        
        FormatEx( szBuffer, sizeof( szBuffer ), "%.1f %.1f %.1f",
            data[ZONE_MINS],
            data[ZONE_MINS + 1],
            data[ZONE_MINS + 2] );
        kv.SetString( "mins", szBuffer );
        
        FormatEx( szBuffer, sizeof( szBuffer ), "%.1f %.1f %.1f",
            data[ZONE_MAXS],
            data[ZONE_MAXS + 1],
            data[ZONE_MAXS + 2] );
        kv.SetString( "maxs", szBuffer );


        strcopy( szBuffer, sizeof( szBuffer ), view_as<char>( data[ZONE_NAME] ) );
        kv.SetString( "name", szBuffer );



        
        
        // Ask other plugins what to save.
        Action res;
        
        Call_StartForward( g_hForward_OnZoneSave );
        Call_PushCell( zoneid );
        Call_PushCell( zonetype );
        Call_PushCell( view_as<int>( kv ) );
        Call_Finish( res );
        
        if ( res == Plugin_Stop )
        {
            LogError( INF_CON_PRE..."Couldn't save zone %s (id: %i) with type %i!", data[ZONE_NAME], zoneid, zonetype );
            
            kv.DeleteThis();
            //kv.GoBack();
            continue;
        }
        
        // Post save (this zone will be saved)
        Call_StartForward( g_hForward_OnZoneSavePost );
        Call_PushCell( zoneid );
        Call_PushCell( zonetype );
        Call_PushCell( view_as<int>( kv ) );
        Call_Finish();
        
        
        decl arr[2];
        arr[0] = view_as<int>( kv );
        arr[1] = zoneid;
        
        kvs.PushArray( arr );
    }
}

stock bool WantsZonesToDb()
{
    return g_ConVar_PreferDb.BoolValue;
}

