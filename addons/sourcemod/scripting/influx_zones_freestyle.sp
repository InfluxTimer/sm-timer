#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_freestyle>

#include <msharedutil/arrayvec>


#undef REQUIRE_PLUGIN
#include <influx/zones_beams>


enum
{
    FS_ZONE_ID = 0,
    
    //FS_ENTREF,
    
    FS_MODEFLAGS,
    FS_STYLEFLAGS,
    
    FS_SIZE
};

enum
{
    FLAGTYPE_MODE = 0,
    FLAGTYPE_STYLE
};


bool g_bInFreestyle[INF_MAXPLAYERS];

int g_fModeFlags[INF_MAXPLAYERS];
int g_fStyleFlags[INF_MAXPLAYERS];


ArrayList g_hFreestyles;


// LIBRARIES
bool g_bLib_Zones_Beams;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones | Freestyle",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_ZONES_FS );
    
    // NATIVES
    CreateNative( "Influx_CanClientModeFreestyle", Native_CanClientModeFreestyle );
    CreateNative( "Influx_CanClientStyleFreestyle", Native_CanClientStyleFreestyle );
    
    CreateNative( "Influx_IsClientInFreestyle", Native_IsClientInFreestyle );
}

public void OnPluginStart()
{
    g_hFreestyles = new ArrayList( FS_SIZE );
    
    // MENUS
    RegConsoleCmd( "sm_zonesettings_fs", Cmd_ZoneSettings );
    
    
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
    if ( !Influx_RegZoneType( ZONETYPE_FS, "Freestyle", "freestyle", true ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't register zone type!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveZoneType( ZONETYPE_FS );
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
    g_hFreestyles.Clear();
}

public void OnClientPutInServer( int client )
{
    g_bInFreestyle[client] = false;
    
    g_fModeFlags[client] = 0;
    g_fStyleFlags[client] = 0;
}

public Action Influx_OnZoneLoad( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_FS ) return Plugin_Continue;
    
    
    decl data[FS_SIZE];
    
    data[FS_ZONE_ID] = zoneid;
    
    data[FS_MODEFLAGS] = kv.GetNum( "modeflags", 0 );
    data[FS_STYLEFLAGS] = kv.GetNum( "styleflags", 0 );
    
    g_hFreestyles.PushArray( data );
    
    return Plugin_Handled;
}

public Action Influx_OnZoneSave( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    if ( zonetype != ZONETYPE_FS ) return Plugin_Continue;
    
    
    int index = FindFreestyleById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Freestyle zone (id: %i) is not registered with the plugin! Cannot save!",
            zoneid );
        return Plugin_Stop;
    }
    
    decl data[FS_SIZE];
    g_hFreestyles.GetArray( index, data );
    
    if ( data[FS_MODEFLAGS] ) kv.SetNum( "modeflags", data[FS_MODEFLAGS] );
    if ( data[FS_STYLEFLAGS] ) kv.SetNum( "styleflags", data[FS_STYLEFLAGS] );
    
    return Plugin_Handled;
}

public void Influx_OnZoneSpawned( int zoneid, ZoneType_t zonetype, int ent )
{
    if ( zonetype != ZONETYPE_FS ) return;

    int index = FindFreestyleById( zoneid );
    if ( index == -1 )
    {
        LogError( INF_CON_PRE..."Freestyle zone (id: %i) is not registered with the plugin! Cannot register hooks!",
            zoneid );
        return;
    }
    
    SDKHook( ent, SDKHook_StartTouchPost, E_StartTouchPost_Freestyle );
    SDKHook( ent, SDKHook_EndTouchPost, E_EndTouchPost_Freestyle );
    
    Inf_SetZoneProp( ent, zoneid );
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_FS ) return;
    
    
    int data[FS_SIZE];
    data[FS_ZONE_ID] = zoneid;
    //data[FS_ENTREF] = INVALID_ENT_REFERENCE;
    
    g_hFreestyles.PushArray( data );
    
    
    if ( g_bLib_Zones_Beams )
    {
        Influx_SetZoneBeamDisplayType( zoneid, DISPLAYTYPE_BEAMS_FULL );
    }
}

public void Influx_OnZoneDeleted( int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_FS ) return;
    
    
    int index = FindFreestyleById( zoneid );
    
    if ( index != -1 )
    {
        g_hFreestyles.Erase( index );
    }
}

public Action Influx_OnZoneSettings( int client, int zoneid, ZoneType_t zonetype )
{
    if ( zonetype != ZONETYPE_FS ) return Plugin_Continue;
    
    
    FakeClientCommand( client, "sm_zonesettings_fs %i", zoneid );
    
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
    
    int index = FindFreestyleById( zoneid );
    if ( index == -1 ) return Plugin_Handled;
    
    
    ArrayList modes = Influx_GetModesArray();
    ArrayList styles = Influx_GetStylesArray();
    
    int modeslen = GetArrayLength_Safe( modes );
    int styleslen = GetArrayLength_Safe( styles );
    
    if ( modeslen < 1 && styleslen < 1 ) return Plugin_Handled;
    
    
    decl String:szZone[32];
    decl String:szType[32];
    Influx_GetZoneName( zoneid, szZone, sizeof( szZone ) );
    Inf_ZoneTypeToName( ZONETYPE_FS, szType, sizeof( szType ) );
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Zone Settings\n%s (%s)\n ", szZone, szType );
    
    
    int id;
    decl String:szName[32];
    decl String:szAdd[32];
    decl String:szDisplay[64];
    decl String:szInfo[32];
    
    
    int flags = g_hFreestyles.Get( index, FS_MODEFLAGS );
    for ( int i = 0; i < modeslen; i++ )
    {
        id = modes.Get( i, MODE_ID );
        
        modes.GetString( i, szName, sizeof( szName ) );
        
        szAdd[0] = '\0';
        
        // EXCEPTIONS
        if ( id == MODE_SCROLL ) continue;
        if ( id == MODE_AUTO ) continue;
        if ( id == MODE_STOCKCAP ) continue;
        
        if ( id == MODE_VELCAP )
        {
            strcopy( szAdd, sizeof( szAdd ), " (no cap)" );
        }

        
        FormatEx( szDisplay, sizeof( szDisplay ), "%s%s: %s",
            szName,
            szAdd,
            ( flags & (1 << id) ) ? "ENABLED" : "DISABLED" );
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i", zoneid, FLAGTYPE_MODE, id );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    
    flags = g_hFreestyles.Get( index, FS_STYLEFLAGS );
    for ( int i = 0; i < styleslen; i++ )
    {
        id = styles.Get( i, STYLE_ID );
        
        // EXCEPTIONS
        if ( id == STYLE_NORMAL ) continue;
        
        
        styles.GetString( i, szName, sizeof( szName ) );
        
        
        FormatEx( szDisplay, sizeof( szDisplay ), "%s: %s",
            szName,
            ( flags & (1 << id) ) ? "ENABLED" : "DISABLED" );
        
        FormatEx( szInfo, sizeof( szInfo ), "%i_%i_%i", zoneid, FLAGTYPE_STYLE, id );
        
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
    int izone = FindFreestyleById( zoneid );
    
    if ( izone != -1 )
    {
        // Finally, toggle our flag.
        int ourflag = ( 1 << id );
        
        int block_flags = ( type == FLAGTYPE_MODE ) ? FS_MODEFLAGS : FS_STYLEFLAGS;
        
        int flags = g_hFreestyles.Get( izone, block_flags );
        
        
        if ( flags & ourflag )
        {
            g_hFreestyles.Set( izone, flags & ~ourflag, block_flags );
        }
        else
        {
            g_hFreestyles.Set( izone, flags | ourflag, block_flags );
        }
        
        FakeClientCommand( client, "sm_zonesettings_fs %i", zoneid );
    }
    else
    {
        Inf_OpenZoneSettingsMenu( client );
    }
    
    return 0;
}

public void E_StartTouchPost_Freestyle( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    g_bInFreestyle[activator] = true;
    
    int index = FindFreestyleById( Inf_GetZoneProp( ent ) );
    if ( index == -1 ) return;
    
    int modeflags = g_hFreestyles.Get( index, FS_MODEFLAGS );
    int styleflags = g_hFreestyles.Get( index, FS_STYLEFLAGS );
    
    int mode = Influx_GetClientMode( activator );
    int style = Influx_GetClientStyle( activator );
    
    g_fModeFlags[activator] = modeflags;
    g_fStyleFlags[activator] = styleflags;
    
    
    bool allowmode = (modeflags & (1 << mode)) ? true : false;
    bool allowstyle = (styleflags & (1 << style)) ? true : false;
    
    if ( allowmode || allowstyle )
    {
        decl String:szMode[MAX_MODE_NAME];
        decl String:szStyle[MAX_STYLE_NAME];
        szMode[0] = '\0';
        szStyle[0] = '\0';
        
        if ( allowmode )
        {
            Influx_GetModeName( mode, szMode, sizeof( szMode ) );
        }
        
        if ( allowstyle )
        {
            Influx_GetStyleName( style, szStyle, sizeof( szStyle ) );
        }
        
        PrintCenterText( activator, "Freestyle\n%s%s%s%s%s",
            szStyle,
            ( szStyle[0] != '\0' ) ? ": OFF" : "",
            ( szStyle[0] != '\0' && szMode[0] != '\0' ) ? "\n" : "",
            szMode,
            ( szMode[0] != '\0' ) ? ": OFF" : "" );
    }
}

public void E_EndTouchPost_Freestyle( int ent, int activator )
{
    if ( !IS_ENT_PLAYER( activator ) ) return;
    
    if ( !IsPlayerAlive( activator ) ) return;
    
    
    g_bInFreestyle[activator] = false;
    
    g_fModeFlags[activator] = 0;
    g_fStyleFlags[activator] = 0;
}

public int Native_CanClientModeFreestyle( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    int mode = Influx_GetClientMode( client );

    return ( g_fModeFlags[client] & (1 << mode) );
}

public int Native_CanClientStyleFreestyle( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    int style = Influx_GetClientStyle( client );

    return ( g_fStyleFlags[client] & (1 << style) );
}

public int Native_IsClientInFreestyle( Handle hPlugin, int nParams )
{
    int client = GetNativeCell( 1 );
    
    return g_bInFreestyle[client];
}

stock int FindFreestyleById( int id )
{
    int len = g_hFreestyles.Length;
    if ( len > 0 )
    {
        for ( int i = 0; i < len; i++ )
        {
            if ( g_hFreestyles.Get( i, FS_ZONE_ID ) == id )
            {
                return i;
            }
        }
    }
    
    return -1;
}