#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_beams>

#include <msharedutil/arrayvec>

#undef REQUIRE_PLUGIN
#include <influx/hud>




#define VALID_DISPLAYTYPE(%0)       ( %0 > DISPLAYTYPE_INVALID && %0 < DISPLAYTYPE_MAX )


#define DEF_FRAMERATE       30
#define DEF_SPEED           0
#define DEF_DISPLAYTYPE     DISPLAYTYPE_BEAMS
#define DEF_MAT             "materials/sprites/laserbeam.vmt"
#define DEF_WIDTH           1.0


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


// FORWARDS
Handle g_hForward_OnBeamAdd;


// CONVARS
ConVar g_ConVar_DrawInterval;


// LIBRARIES
bool g_bLib_Hud;


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
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_ZONES_BEAMS );
    
    // NATIVES
    CreateNative( "Influx_SetZoneBeamDisplayType", Native_SetZoneBeamDisplayType );
}

public void OnPluginStart()
{
    g_hBeams = new ArrayList( BEAM_SIZE );
    
    
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
    g_ConVar_DrawInterval.AddChangeHook( E_ConVarChanged_DrawInterval );
    
    AutoExecConfig( true, "beams", "influx" );
    
    
    // CMDS
    RegConsoleCmd( "sm_beamsettings", Cmd_BeamSettings );
    
    
    g_bLib_Hud = LibraryExists( INFLUX_LIB_HUD );
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_HUD ) ) g_bLib_Hud = false;
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
    if ( !(g_iDefBeamMat = PrecacheModel( DEF_MAT )) )
    {
        SetFailState( INF_CON_PRE..."Couldn't precache default beam material '%s'!", DEF_MAT );
    }
    
    g_hBeams.Clear();
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
    if ( g_hBeams.Length )
    {
        StartBeams();
    }
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
    
    
    if ( displaytype != DISPLAYTYPE_NONE )
    {
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
        
        bool bIsDefClr = true;
        decl defclr[4];
        Inf_GetZoneTypeDefColor( zonetype, defclr );
        for ( i = 0; i < 4; i++ )
        {
            if ( clr[i] != defclr[i] )
            {
                bIsDefClr = false;
                break;
            }
        }
        
        if ( !bIsDefClr )
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
        g_hTimer_Draw = CreateTimer( g_ConVar_DrawInterval.FloatValue, T_DrawBeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
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
    
    
    if ( !SendBeamAdd( zoneid, zonetype, displaytype, beammat, width, framerate, speed, offset, offset_z, clr ) )
    {
        return;
    }
    
    
    // Make sure our settings are valid.
    if ( displaytype == DISPLAYTYPE_INVALID )
    {
        displaytype = DISPLAYTYPE_BEAMS;
    }
    
    if ( width < 1.0 ) width = DEF_WIDTH;
    
    // Inherit
    if ( offset < 1.0 ) offset = width / 2.0;
    if ( offset_z < 1.0 ) offset_z = width / 2.0;
    
    if ( framerate < 0 ) framerate = DEF_FRAMERATE;
    
    //if ( speed == -1 ) speed = DEF_SPEED;
    
    if ( clr[3] <= 0 ) Inf_GetZoneTypeDefColor( view_as<ZoneType_t>( zonetype ), clr );
    
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
        
        float engtime = GetEngineTime();
        
        decl Float:pos[3];
        decl clr[4];
        
        decl client, nClients;
        decl j;
        
        decl framerate, spd, matindex;
        decl Float:width;
        
        int[] clients = new int[MaxClients];
        
        for ( int i = 0; i < len; i++ )
        {
            if ( view_as<DisplayType_t>( g_hBeams.Get( i, BEAM_DISPLAYTYPE ) ) == DISPLAYTYPE_NONE )
            {
                continue;
            }
            
            
            static float p1[3], p2[3], p3[3], p4[3], p5[3], p6[3], p7[3], p8[3];
            
            
            static int data[BEAM_SIZE];
            g_hBeams.GetArray( i, data );
            
            
            
            CopyArray( data[BEAM_P1], p1, 3 );
            CopyArray( data[BEAM_P7], p7, 3 );
            
            nClients = 0;
            
            
            for ( client = 1; client <= MaxClients; client++ )
                if ( IsClientInGame( client ) && !IsFakeClient( client ) )
                {
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
                    
                    if ( GetVectorDistance( p2, pos, true ) < MAX_DIST_SQ )
                    {
                        clients[nClients++] = client;
                    }
                    else
                    {
                        TR_TraceRayFilter( p2, pos, CONTENTS_SOLID, RayType_EndPoint, TraceFilter_WorldOnly );
                        
                        if ( !TR_DidHit() )
                        {
                            clients[nClients++] = client;
                        }
                    }
                }
            
            
            if ( !nClients ) continue;
            
            
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
            
            if ( view_as<DisplayType_t>( data[BEAM_DISPLAYTYPE] ) == DISPLAYTYPE_BEAMS_FULL )
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



stock void StartBeams()
{
    g_hTimer_Draw = CreateTimer( g_ConVar_DrawInterval.FloatValue, T_DrawBeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
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