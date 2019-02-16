#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_beams>

#include <msharedutil/arrayvec>

#undef REQUIRE_PLUGIN
#include <influx/hud>




//#define DEBUG
//#define DEBUG_DRAW


#define VALID_DISPLAYTYPE(%0)       ( %0 > DISPLAYTYPE_INVALID && %0 < DISPLAYTYPE_MAX )


#define DEF_FRAMERATE       30
#define DEF_SPEED           0
#define DEF_DISPLAYTYPE     DISPLAYTYPE_BEAMS
#define DEF_MAT             "materials/sprites/laserbeam.vmt"
#define DEF_WIDTH           1.0
#define DEF_BEAMCLR         { 255, 255, 255, 255 }



#define CONFIG_FILE         "influx_beams.cfg"


#define MAX_SHORTNAME           32
#define MAX_SHORTNAME_CELL      ( MAX_SHORTNAME / 4 )


enum
{
    DEFBEAM_SHORTNAME[MAX_SHORTNAME_CELL] = 0,
    
    DEFBEAM_ZONETYPE,
    
    DEFBEAM_DISPLAYTYPE,
    
    DEFBEAM_MATINDEX,
    
    DEFBEAM_WIDTH,
    DEFBEAM_FRAMERATE,
    DEFBEAM_SPEED,
    
    DEFBEAM_OFFSET,
    DEFBEAM_OFFSET_Z,
    
    DEFBEAM_CLR[4],
    
    DEFBEAM_SIZE
};

enum
{
    BEAM_ZONE_ID = 0,
    
    BEAM_DISPLAYTYPE,
    
    BEAM_MATINDEX,
    
    BEAM_WIDTH,
    BEAM_FRAMERATE,
    BEAM_SPEED,
    
    BEAM_CLR[4],
    
    BEAM_P1[3],
    BEAM_P2[3],
    BEAM_P3[3],
    BEAM_P4[3],
    
    BEAM_P5[3],
    BEAM_P6[3],
    BEAM_P7[3],
    BEAM_P8[3],
    
    BEAM_SIZE
};


float g_flShowBeams[INF_MAXPLAYERS];

Handle g_hTimer_Draw;

int g_iDefBeamMat;


ArrayList g_hBeams;

ArrayList g_hDef;


bool g_bShowHidden[INF_MAXPLAYERS];


// FORWARDS
Handle g_hForward_OnBeamAdd;


// CONVARS
ConVar g_ConVar_DrawInterval;
ConVar g_ConVar_TraceBeams;
ConVar g_ConVar_BeamDrawDist;


// LIBRARIES
bool g_bLib_Hud;


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Zones | Beams",
    description = "Draw beams of the zones.",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    g_bLate = late;
    
    
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_ZONES_BEAMS );
    
    
    // NATIVES
    CreateNative( "Influx_SetZoneBeamDisplayType", Native_SetZoneBeamDisplayType );
    CreateNative( "Influx_GetDefaultBeamOffsets", Native_GetDefaultBeamOffsets );
}

public void OnPluginStart()
{
    g_hBeams = new ArrayList( BEAM_SIZE );
    g_hDef = new ArrayList( DEFBEAM_SIZE );
    
    
    // FORWARDS
    g_hForward_OnBeamAdd = CreateGlobalForward( "Influx_OnBeamAdd", ET_Hook,
        Param_Cell, // id
        Param_Cell, // zone type
        Param_CellByRef, // display type
        Param_CellByRef, // material index
        Param_CellByRef, // width
        Param_CellByRef, // framerate
        Param_CellByRef, // speed
        Param_CellByRef, // offset
        Param_CellByRef, // z offset
        Param_Array ); // color
    
    
    // CONVARS
    g_ConVar_DrawInterval = CreateConVar( "influx_beams_drawinterval", "1.0", "Interval in seconds that zone beams get updated to players.", FCVAR_NOTIFY );
    g_ConVar_TraceBeams = CreateConVar( "influx_beams_tracedrawbeams", "0", "Do we check if the player can see the zone or not by tracing? May be expensive.", FCVAR_NOTIFY );
    g_ConVar_BeamDrawDist = CreateConVar( "influx_beams_drawdistance", "1500", "The distance in which we draw the zones to players no matter what.", FCVAR_NOTIFY );
    g_ConVar_DrawInterval.AddChangeHook( E_ConVarChanged_DrawInterval );
    
    AutoExecConfig( true, "beams", "influx" );
    
    
    // CMDS
    RegConsoleCmd( "sm_showhiddenzones", Cmd_ShowHidden );
    RegConsoleCmd( "sm_showhidden", Cmd_ShowHidden );
    RegConsoleCmd( "sm_hiddenzones", Cmd_ShowHidden );
    RegConsoleCmd( "sm_showzones", Cmd_ShowHidden );
    
    RegConsoleCmd( "sm_beamsettings", Cmd_BeamSettings );
    
    
    g_bLib_Hud = LibraryExists( INFLUX_LIB_HUD );
    
    
    if ( g_bLate )
    {
        Influx_OnPreRunLoad();
        
        
        ArrayList zones = Influx_GetZonesArray();
        for ( int i = 0; i < zones.Length; i++ )
        {
            float mins[3], maxs[3];
            
            int zoneid = zones.Get( i, ZONE_ID );
            ZoneType_t zonetype = view_as<ZoneType_t>( zones.Get( i, ZONE_TYPE ) );
            
            Influx_GetZoneMinsMaxs( zoneid, mins, maxs );
            
            InsertBeams(
                zoneid,
                zonetype,
                mins,
                maxs,
                _,
                _,
                _,
                _,
                _,
                _,
                _,
                _ );
        }
        
        
        for ( int client = 1; client <= MaxClients; client++ )
        {
            if ( IsClientInGame( client ) && !IsFakeClient( client ) )
            {
                OnClientPutInServer( client );
            }
        }
        
        StartBeams();
    }
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = false;
}

public Action Cmd_ShowHidden( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    g_bShowHidden[client] = !g_bShowHidden[client];
    
    Influx_PrintToChat( _, client, "Hidden beams are now %s.", g_bShowHidden[client] ? "enabled" : "disabled" );
    
    return Plugin_Handled;
}

public Action Cmd_BeamSettings( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !Influx_CanUserModifyZones( client ) ) return Plugin_Handled;
    
    
    ArrayList zones = Influx_GetZonesArray();
    if ( zones == null ) return Plugin_Handled;
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Beam Settings\n " );
    
    decl String:szInfo[32];
    decl String:szDisplay[64];
    
    decl String:szName[MAX_ZONE_NAME];
    decl String:szType[16];
    
    int zoneid;
    int ibeam;
    
    int len = zones.Length;
    for ( int i = 0; i < len; i++ )
    {
        zoneid = zones.Get( i, ZONE_ID );
        
        zones.GetString( i, szName, sizeof( szName ) );
        
        
        if ( (ibeam = FindBeamById( zoneid )) != -1 )
        {
            Inf_DisplayTypeToNameEx(
                view_as<DisplayType_t>( g_hBeams.Get( ibeam, BEAM_DISPLAYTYPE ) ),
                szType,
                sizeof( szType ) );
        }
        else
        {
            strcopy( szType, sizeof( szType ), "None" );
        }
        
        
        FormatEx( szDisplay, sizeof( szDisplay ), "%s: %s",
            szName,
            szType );
            
        FormatEx( szInfo, sizeof( szInfo ), "%i", zoneid );
        
        menu.AddItem( szInfo, szDisplay );
    }
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_Settings( Menu menu, MenuAction action, int client, int index )
{
    if ( action == MenuAction_End ) { delete menu; return 0; }
    if ( action != MenuAction_Select ) return 0;
    
    if ( !Influx_CanUserModifyZones( client ) ) return 0;
    
    
    decl String:szInfo[32];
    if ( !GetMenuItem( menu, index, szInfo, sizeof( szInfo ) ) ) return 0;
    
    
    int zoneid = StringToInt( szInfo );
    int izone = Influx_FindZoneById( zoneid );
    if ( izone == -1 )
    {
        return 0;
    }
    
    
    int ibeam = FindBeamById( zoneid );
    if ( ibeam != -1 )
    {
        DisplayType_t type = g_hBeams.Get( ibeam, BEAM_DISPLAYTYPE );
        
        ++type;
        if ( !VALID_DISPLAYTYPE( type ) )
        {
            type = DISPLAYTYPE_NONE;
        }
        
        g_hBeams.Set( ibeam, type, BEAM_DISPLAYTYPE );
    }
    else
    {
        ArrayList zones = Influx_GetZonesArray();
        if ( zones == null ) return 0;
        
        
        float mins[3], maxs[3];
        Influx_GetZoneMinsMaxs( zoneid, mins, maxs );
        
        InsertBeams( zoneid, view_as<ZoneType_t>( zones.Get( izone, ZONE_TYPE ) ), mins, maxs );
    }
    
    Inf_OpenBeamSettings( client );
    
    return 0;
}

public void OnMapEnd()
{
    g_hTimer_Draw = null;
}

public void Influx_OnPreRunLoad()
{
    PrecacheDefault();
    
    
    ClearBeams();
    
    
    ReadDefaultSettingsFile();
}

stock void ClearBeams()
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Clearing beams..." );
#endif

    g_hBeams.Clear();
}

stock void ReadDefaultSettingsFile()
{
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "configs/"...CONFIG_FILE );
    
    
    KeyValues kv = new KeyValues( "Beams" );
    kv.ImportFromFile( szPath );
    
    if ( !kv.GotoFirstSubKey() )
    {
        delete kv;
        return;
    }
    
    
    g_hDef.Clear();
    
    char szType[32];
    int clr[4];
    
    decl data[DEFBEAM_SIZE];
    
    decl String:szDownload[2048];
    decl String:szDlBuffer[8][256];
    decl String:szMat[PLATFORM_MAX_PATH];
    
    do
    {
        if ( !kv.GetSectionName( szType, sizeof( szType ) ) )
        {
            LogError( INF_CON_PRE..."Couldn't read zone type name for default beams!" );
            continue;
        }
        
        
        ZoneType_t zonetype = Influx_GetZoneTypeByShortName( szType );
        
        
        if ( FindDefByType( zonetype, szType ) != -1 )
        {
            LogError( INF_CON_PRE..."Zone type '%s' is already defined for default beams!", szType );
            continue;
        }
        
        
        decl String:szDisplay[32];
        kv.GetString( "displaytype", szDisplay, sizeof( szDisplay ), "beams" );
        
        DisplayType_t displaytype = Inf_DisplayNameToType( szDisplay );
        if ( displaytype == DISPLAYTYPE_INVALID )
        {
            LogError( INF_CON_PRE..."Invalid display type '%s'!", szDisplay );
            continue;
        }
        
        
        
        kv.GetString( "material", szMat, sizeof( szMat ), "" );
        kv.GetString( "download", szDownload, sizeof( szDownload ), "" );
        
        
        int mat = 0;
        
        if ( szMat[0] != 0 )
        {
            if ( FileExists( szMat, true ) )
            {
                if ( (mat = PrecacheModel( szMat )) < 1 )
                {
                    LogError( INF_CON_PRE..."Couldn't precache beam material '%s'!", szMat );
                }
            }
            else
            {
                LogError( INF_CON_PRE..."Beam material '%s' does not exist!", szMat );
            }
        }
        
        if ( szDownload[0] != 0 )
        {
            int dllen = ExplodeString( szDownload, ";", szDlBuffer, sizeof( szDlBuffer ), sizeof( szDlBuffer[] ), true );
            
            for ( int i = 0; i < dllen; i++ )
            {
                TrimString( szDlBuffer[i] );
                
                if ( szDlBuffer[i][0] == 0 ) continue;
                
                
                if ( FileExists( szDlBuffer[i], true ) )
                {
                    AddFileToDownloadsTable( szDlBuffer[i] );
                }
                else
                {
                    LogError( INF_CON_PRE..."Beam file '%s' does not exist! Can't add to downloads table.", szDlBuffer[i] );
                }
            }
        }
        
        
        data[DEFBEAM_ZONETYPE] = view_as<int>( zonetype );
        
        strcopy( view_as<char>( data[DEFBEAM_SHORTNAME] ), MAX_SHORTNAME, szType );
        
        data[DEFBEAM_DISPLAYTYPE] = view_as<int>( displaytype );
        
        data[DEFBEAM_MATINDEX] = mat;
        
        data[DEFBEAM_WIDTH] = view_as<int>( kv.GetFloat( "width", 0.0 ) );
        data[DEFBEAM_FRAMERATE] = kv.GetNum( "framerate", -1 );
        data[DEFBEAM_SPEED] = kv.GetNum( "speed", 0 );
        
        data[DEFBEAM_OFFSET] = view_as<int>( kv.GetFloat( "offset", 0.0 ) );
        data[DEFBEAM_OFFSET_Z] = view_as<int>( kv.GetFloat( "offset_z", 0.0 ) );
        
        
        FillArray( clr, 0, sizeof( clr ) );
        kv.GetColor4( "color", clr );
        
        if ( IsInvisibleColor( clr ) )
        {
            LogError( INF_CON_PRE..."Zone type '%s' has no/invalid color specified! Assuming default color.", szType );
        }
        
        
        CopyArray( clr, data[DEFBEAM_CLR], 4 );
        
        
        g_hDef.PushArray( data );
        
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."Added default zone type beams '%s' | Num: %i!", szType, zonetype );
#endif
    }
    while ( kv.GotoNextKey() );
    
    delete kv;
}

public void E_ConVarChanged_DrawInterval( ConVar convar, const char[] oldValue, const char[] newValue )
{
    if ( g_hBeams.Length )
    {
        KillTimer( g_hTimer_Draw );
        StartBeams();
    }
}

public void OnConfigsExecuted()
{
    StartBeams();
}

public void OnClientPutInServer( int client )
{
    g_flShowBeams[client] = GetEngineTime() + 3.0;
}

public void OnClientDisconnect( int client )
{
    g_flShowBeams[client] = 0.0;
}

public void Influx_OnZoneLoadPost( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    // HACK
    // Let '_' slip by so we can add default display types.
    decl String:szDisplay[16];
    kv.GetString( "beam_displaytype", szDisplay, sizeof( szDisplay ), "_" );
    
    DisplayType_t displaytype = Inf_DisplayNameToType( szDisplay );
    
    if ( szDisplay[0] != '_' && displaytype == DISPLAYTYPE_INVALID )
    {
        LogError( INF_CON_PRE..."Found invalid beam display type '%s'!", szDisplay );
        displaytype = DISPLAYTYPE_BEAMS;
    }
    
    
    int clr[4];
    kv.GetColor4( "beam_color", clr );
    
    
    
    decl Float:mins[3], Float:maxs[3];
    kv.GetVector( "mins", mins );
    kv.GetVector( "maxs", maxs );
    
    InsertBeams(
        zoneid,
        zonetype,
        mins,
        maxs,
        displaytype,
        _,
        kv.GetFloat( "beam_width", 0.0 ),
        kv.GetNum( "beam_framerate", -1 ),
        kv.GetNum( "beam_speed", 0 ),
        _,
        _,
        clr );
}

public void Influx_OnZoneSavePost( int zoneid, ZoneType_t zonetype, KeyValues kv )
{
    int ibeam = FindBeamById( zoneid );
    if ( ibeam != -1 )
    {
        decl i, temp;
        decl String:sz[32];
        
        
        // Add display type.
        temp = g_hBeams.Get( ibeam, BEAM_DISPLAYTYPE );
        if ( view_as<DisplayType_t>( temp ) != DEF_DISPLAYTYPE )
        {
            Inf_DisplayTypeToName( view_as<DisplayType_t>( temp ), sz, sizeof( sz ) );
            kv.SetString( "beam_displaytype", sz );
        }
            
        
        
        // Add if not default.
        decl clr[4];
        for ( i = 0; i < 4; i++ )
        {
            clr[i] = g_hBeams.Get( ibeam, BEAM_CLR ) + i;
        }
        
        
        if ( !IsSameAsDefColor( zonetype, clr ) )
            kv.SetColor4( "beam_color", clr );
    }
}

public void Influx_OnZoneCreated( int client, int zoneid, ZoneType_t zonetype )
{
    if ( FindBeamById( zoneid ) == -1 )
    {
        float mins[3], maxs[3];
        Influx_GetZoneMinsMaxs( zoneid, mins, maxs );
        
        InsertBeams( zoneid, zonetype, mins, maxs );
    }
    
    if ( g_hTimer_Draw == null && g_hBeams.Length )
    {
        StartBeams();
    }
}

public void Influx_OnZoneDeleted( int zoneid, ZoneType_t zonetype )
{
    DeleteBeamsById( zoneid );
}

stock void InsertBeams( int zoneid,
                        ZoneType_t zonetype,
                        const float mins[3],
                        const float maxs[3],
                        DisplayType_t displaytype = DISPLAYTYPE_INVALID,
                        int beammat = 0,
                        float width = 0.0,
                        int framerate = -1,
                        int speed = 0,
                        float offset = 0.0,
                        float offset_z = 0.0,
                        const int inclr[4] = { 0, 0, 0, 0 } )
{
    int clr[4];
    clr = inclr;
    
    
    SetDefaultBeamSettings( zoneid, zonetype, displaytype, beammat, width, framerate, speed, offset, offset_z, clr );
    
    if ( !SendBeamAdd( zoneid, zonetype, displaytype, beammat, width, framerate, speed, offset, offset_z, clr ) )
    {
        return;
    }
    
    
    // Make sure our settings are valid.
    if ( displaytype == DISPLAYTYPE_INVALID )
    {
        displaytype = DISPLAYTYPE_BEAMS;
    }
    
    if ( width < 0.01 ) width = DEF_WIDTH;
    
    // Inherit
    // Allow negative numbers.
    if ( offset == 0.0 ) offset = width / 2.0;
    if ( offset_z == 0.0 ) offset_z = width / 2.0;
    
    if ( framerate < 0 ) framerate = DEF_FRAMERATE;
    
    //if ( speed == -1 ) speed = DEF_SPEED;
    
    if ( IsInvisibleColor( clr ) ) clr = DEF_BEAMCLR;
    
    if ( beammat < 1 ) beammat = g_iDefBeamMat;
    
    
    
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Inserting beams (zone id: %i) [%i %i %i %i]",
        zoneid,
        clr[0],
        clr[1],
        clr[2],
        clr[3] );
#endif
    int data[BEAM_SIZE];
    
    float p1[3], p2[3], p3[3], p4[3];
    
    p1 = mins;
    p1[0] += offset;
    p1[1] += offset;
    p1[2] += offset_z;
    
    p2[0] = mins[0] + offset;
    p2[1] = maxs[1] - offset;
    p2[2] = p1[2];
    
    p3 = maxs;
    p3[0] -= offset;
    p3[1] -= offset;
    p3[2] = p1[2];
    
    p4[0] = maxs[0] - offset;
    p4[1] = mins[1] + offset;
    p4[2] = p1[2];
    
    CopyArray( p1, data[BEAM_P1], 3 );
    CopyArray( p2, data[BEAM_P2], 3 );
    CopyArray( p3, data[BEAM_P3], 3 );
    CopyArray( p4, data[BEAM_P4], 3 );
    
    p1[2] = maxs[2] - offset_z;
    p2[2] = maxs[2] - offset_z;
    p3[2] = maxs[2] - offset_z;
    p4[2] = maxs[2] - offset_z;
    
    CopyArray( p1, data[BEAM_P5], 3 );
    CopyArray( p2, data[BEAM_P6], 3 );
    CopyArray( p3, data[BEAM_P7], 3 );
    CopyArray( p4, data[BEAM_P8], 3 );
    
    data[BEAM_ZONE_ID] = zoneid;
    
    data[BEAM_MATINDEX] = beammat;
    
    data[BEAM_DISPLAYTYPE] = view_as<int>( displaytype );
    
    data[BEAM_WIDTH] = view_as<int>( width );
    data[BEAM_FRAMERATE] = framerate;
    data[BEAM_SPEED] = speed;
    
    
    CopyArray( clr, data[BEAM_CLR], 4 );
    
    g_hBeams.PushArray( data );
}

stock bool SetDefaultBeamSettings( int zoneid, ZoneType_t zonetype, DisplayType_t &displaytype, int &mat, float &width, int &framerate, int &speed, float &offset, float &offset_z, int clr[4] )
{
    char szType[32];
    Influx_GetZoneTypeShortName( zonetype, szType, sizeof( szType ) );
    
    int index = FindDefByType( zonetype, szType );
    if ( index == -1 ) return false;
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Setting default beam settings to zone %i!", zoneid );
#endif

    decl data[DEFBEAM_SIZE];
    g_hDef.GetArray( index, data );
    
    if ( displaytype == DISPLAYTYPE_INVALID )
    {
        displaytype = view_as<DisplayType_t>( data[DEFBEAM_DISPLAYTYPE] );
    }
    
    if ( mat < 1 )
    {
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."Setting default beam material to zone %i! (%i)", zoneid, data[DEFBEAM_MATINDEX] );
#endif
        mat = data[DEFBEAM_MATINDEX];
    }
    
    if ( width == 0.0 )
    {
        width = view_as<float>( data[DEFBEAM_WIDTH] );
    }
    
    if ( framerate == -1 )
    {
        framerate = data[DEFBEAM_FRAMERATE];
    }
    
    //if ( speed == -1 )
    //{
    speed = data[DEFBEAM_SPEED];
    //}
    
    if ( offset == 0 )
    {
        offset = view_as<float>( data[DEFBEAM_OFFSET] );
    }
    
    if ( offset_z == 0 )
    {
        offset_z = view_as<float>( data[DEFBEAM_OFFSET_Z] );
    }
    
    if ( clr[3] == 0 )
    {
        CopyArray( data[DEFBEAM_CLR], clr, 4 );
    }
    
    return true;
}

stock int FindDefByType( ZoneType_t zonetype = ZONETYPE_INVALID, const char[] szInName = "" )
{
    // Find by zonetype or shortname.
    ZoneType_t myzonetype;
    
    char szMyName[32];
    char szShortName[32];
    
    if ( szInName[0] != 0 )
    {
        strcopy( szShortName, sizeof( szShortName ), szInName );
    }
    else
    {
        Influx_GetZoneTypeShortName( zonetype, szShortName, sizeof( szShortName ) );
    }
    
    int len = g_hDef.Length;
    for ( int i = 0; i < len; i++ )
    {
        myzonetype = view_as<ZoneType_t>( g_hDef.Get( i, DEFBEAM_ZONETYPE ) );
        
        if ( myzonetype != ZONETYPE_INVALID && zonetype != ZONETYPE_INVALID )
        {
            if ( myzonetype == zonetype ) return i;
        }
        else
        {
            g_hDef.GetString( i, szMyName, sizeof( szMyName ) );
            
            if ( StrEqual( szMyName, szShortName, false ) )
            {
                g_hDef.Set( i, zonetype, DEFBEAM_ZONETYPE );
                
                return i;
            }
        }
    }
    
    return -1;
}

stock int FindBeamById( int zoneid )
{
    int len = g_hBeams.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( g_hBeams.Get( i, BEAM_ZONE_ID ) == zoneid )
        {
            return i;
        }
    }
    
    return -1;
}

stock bool DeleteBeamsById( int zoneid )
{
    int i = FindBeamById( zoneid );
    
    if ( i != -1 )
    {
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."Removing beams of zone %i", zoneid );
#endif
        g_hBeams.Erase( i );
        
        return true;
    }
    
    return false;
}

public Action T_DrawBeams( Handle hTimer )
{
    int len = g_hBeams.Length;
    if ( len > 0 )
    {
        float drawinterval = g_ConVar_DrawInterval.FloatValue;
        
        
        float drawdistsqr = g_ConVar_BeamDrawDist.FloatValue;
        drawdistsqr *= drawdistsqr;
        
        
        float engtime = GetEngineTime();
        
        decl Float:pos[3];
        decl clr[4];
        
        decl client, nClients;
        decl j;
        
        decl framerate, spd, matindex;
        decl Float:width;
        
        DisplayType_t displaytype;
        
        int[] clients = new int[MaxClients];
        
        for ( int i = 0; i < len; i++ )
        {
            displaytype = view_as<DisplayType_t>( g_hBeams.Get( i, BEAM_DISPLAYTYPE ) );
            
            
            static float p1[3], p2[3], p3[3], p4[3], p5[3], p6[3], p7[3], p8[3];
            
            
            static int data[BEAM_SIZE];
            g_hBeams.GetArray( i, data );
            
            
            
            CopyArray( data[BEAM_P1], p1, 3 );
            CopyArray( data[BEAM_P7], p7, 3 );
            
            nClients = 0;
            
            
            for ( client = 1; client <= MaxClients; client++ )
                if ( IsClientInGame( client ) && !IsFakeClient( client ) )
                {
                    if ( displaytype == DISPLAYTYPE_NONE && !g_bShowHidden[client] )
                        continue;
                    
                    if ( g_flShowBeams[client] == 0.0 || g_flShowBeams[client] > engtime )
                        continue;
                    
                    if ( g_bLib_Hud )
                    {
                        if ( Influx_GetClientHideFlags( client ) & HIDEFLAG_BEAMS )
                            continue;
                    }
                    
                    // Check if player is too far away.
                    // We can't draw too many beams to the client.
                    GetClientEyePosition( client, p2 );
                    
                    
                    for ( j = 0; j < 3; j++ ) pos[j] = p1[j] + ( p7[j] - p1[j] ) * 0.5;
                    
                    

#define MAX_DIST        1536.0
#define MAX_DIST_SQ     MAX_DIST * MAX_DIST
                    
                    if ( GetVectorDistance( p2, pos, true ) < drawdistsqr )
                    {
                        clients[nClients++] = client;
                    }
                    else if ( g_ConVar_TraceBeams.BoolValue )
                    {
                        TR_TraceRayFilter( p2, pos, CONTENTS_SOLID, RayType_EndPoint, TraceFilter_WorldOnly );
                        
                        if ( !TR_DidHit() )
                        {
                            clients[nClients++] = client;
                        }
                    }
                }
            
            
            if ( !nClients ) continue;
            
            
#if defined DEBUG_DRAW
            PrintToServer( INF_DEBUG_PRE..."Drawing beam of zone %i to %i clients!",
                data[BEAM_ZONE_ID],
                nClients );
#endif
            
            framerate = data[BEAM_FRAMERATE];
            spd = data[BEAM_SPEED];
            width = view_as<float>( data[BEAM_WIDTH] );
            
            matindex = data[BEAM_MATINDEX];
            
            CopyArray( data[BEAM_P2], p2, 3 );
            CopyArray( data[BEAM_P3], p3, 3 );
            CopyArray( data[BEAM_P4], p4, 3 );
            
            CopyArray( data[BEAM_CLR], clr, 4 );
            
#define BEAM_FADE       1
            
            
            TE_SetupBeamPoints( p1, p2, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
            TE_Send( clients, nClients, 0.0 );
            TE_SetupBeamPoints( p2, p3, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
            TE_Send( clients, nClients, 0.0 );
            TE_SetupBeamPoints( p3, p4, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
            TE_Send( clients, nClients, 0.0 );
            TE_SetupBeamPoints( p4, p1, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
            TE_Send( clients, nClients, 0.0 );
            
            if ( displaytype == DISPLAYTYPE_BEAMS_FULL || displaytype == DISPLAYTYPE_NONE)
            {
                CopyArray( data[BEAM_P5], p5, 3 );
                CopyArray( data[BEAM_P6], p6, 3 );
                
                CopyArray( data[BEAM_P8], p8, 3 );
                
                TE_SetupBeamPoints( p5, p6, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
                TE_Send( clients, nClients, 0.0 );
                TE_SetupBeamPoints( p6, p7, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
                TE_Send( clients, nClients, 0.0 );
                TE_SetupBeamPoints( p7, p8, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
                TE_Send( clients, nClients, 0.0 );
                TE_SetupBeamPoints( p8, p5, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
                TE_Send( clients, nClients, 0.0 );
                
                
                
                TE_SetupBeamPoints( p5, p1, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
                TE_Send( clients, nClients, 0.0 );
                TE_SetupBeamPoints( p6, p2, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
                TE_Send( clients, nClients, 0.0 );
                TE_SetupBeamPoints( p7, p3, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
                TE_Send( clients, nClients, 0.0 );
                TE_SetupBeamPoints( p8, p4, matindex, 0, 0, framerate, drawinterval, width, width, BEAM_FADE, 0.0, clr, spd );
                TE_Send( clients, nClients, 0.0 );
            }
        }
    }
}

public bool TraceFilter_WorldOnly( int ent, int mask )
{
    return ( ent == 0 );
}

stock bool IsSameAsDefColor( ZoneType_t zonetype, const int clr[4] )
{
    decl defclr[4];
    if ( !GetZoneTypeDefColor( zonetype, defclr ) )
    {
        return false;
    }
    
    for ( int i = 0; i < 4; i++ )
    {
        if ( clr[i] != defclr[i] )
        {
            return false;
        }
    }
    
    return true;
}

stock bool GetZoneTypeDefColor( ZoneType_t zonetype, int clr[4] )
{
    int index = FindDefByType( zonetype );
    
    if ( index == -1 ) return false;
    
    
    for ( int i = 0; i < sizeof( clr ); i++ )
    {
        clr[i] = g_hDef.Get( index, DEFBEAM_CLR + i );
    }
    
    return true;
}

stock void StartBeams()
{
    if ( g_hTimer_Draw == null )
    {
        g_hTimer_Draw = CreateTimer( g_ConVar_DrawInterval.FloatValue, T_DrawBeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
    }
}

stock bool SendBeamAdd( int zoneid, ZoneType_t zonetype, DisplayType_t &displaytype, int &mat, float &width, int &framerate, int &speed, float &offset, float &offset_z, int clr[4] )
{
    Action res;
    
    Call_StartForward( g_hForward_OnBeamAdd );
    Call_PushCell( zoneid );
    Call_PushCell( zonetype );
    Call_PushCellRef( displaytype );
    Call_PushCellRef( mat );
    Call_PushCellRef( width );
    Call_PushCellRef( framerate );
    Call_PushCellRef( speed );
    Call_PushCellRef( offset );
    Call_PushCellRef( offset_z );
    Call_PushArrayEx( clr, sizeof( clr ), SM_PARAM_COPYBACK );
    Call_Finish( res );
    
    return ( res == Plugin_Stop ) ? false : true;
}

stock bool IsInvisibleColor( const int clr[4] )
{
    if ( clr[3] <= 0 ) return true;
    
    
    return ( (clr[0] + clr[1] + clr[2]) <= 0 );
}

stock void PrecacheDefault()
{
    if ( !(g_iDefBeamMat = PrecacheModel( DEF_MAT )) )
    {
        SetFailState( INF_CON_PRE..."Couldn't precache default beam material '%s'!", DEF_MAT );
    }
}

// NATIVES
public int Native_SetZoneBeamDisplayType( Handle hPlugin, int nParms )
{
    int index = FindBeamById( GetNativeCell( 1 ) );
    if ( index == -1 ) return 0;
    
    
    DisplayType_t displaytype = view_as<DisplayType_t>( GetNativeCell( 2 ) );
    if ( !VALID_DISPLAYTYPE( displaytype ) ) return 0;
    
    
    g_hBeams.Set( index, displaytype, BEAM_DISPLAYTYPE );
    
    return 1;
}

public int Native_GetDefaultBeamOffsets( Handle hPlugin, int nParms )
{
    int index = FindDefByType( GetNativeCell( 1 ) );
    if ( index == -1 ) return 0;
    
    
    decl offsets[2];
    offsets[0] = g_hDef.Get( index, DEFBEAM_OFFSET )
    offsets[1] = g_hDef.Get( index, DEFBEAM_OFFSET_Z );
    
    SetNativeArray( 2, offsets, sizeof( offsets ) );
    
    return 1;
}
