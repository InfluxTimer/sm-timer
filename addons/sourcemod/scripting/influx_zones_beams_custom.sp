#include <sourcemod>

#include <influx/core>
#include <influx/zones>
#include <influx/zones_beams>

#include <msharedutil/arrayvec>


//#define DEBUG


#define CONFIG_FILE         "influx_beams.cfg"


enum
{
    DEF_ZONETYPE = 0,
    
    DEF_DISPLAYTYPE,
    
    DEF_MATINDEX,
    
    DEF_WIDTH,
    DEF_FRAMERATE,
    DEF_SPEED,
    
    DEF_OFFSET,
    DEF_OFFSET_Z,
    
    DEF_CLR[4],
    
    DEF_SIZE
};


ArrayList g_hDef;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Beams | Default Settings",
    description = "Load custom beam settings.",
    version = INF_VERSION
};

public void OnPluginStart()
{
    g_hDef = new ArrayList( DEF_SIZE );
}

public void Influx_OnPreRunLoad()
{
    g_hDef.Clear();
    
    ReadBeamFile();
}

stock void ReadBeamFile()
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
    
    
    char szType[32];
    int clr[4];
    
    decl data[DEF_SIZE];
    
    do
    {
        if ( !kv.GetSectionName( szType, sizeof( szType ) ) )
        {
            LogError( INF_CON_PRE..."Couldn't read zone type for custom beams!" );
            continue;
        }
        
        
        ZoneType_t zonetype = Inf_ZoneNameToType( szType );
        
        if ( zonetype == ZONETYPE_INVALID )
        {
            LogError( INF_CON_PRE..."Invalid zone type '%s'!", szType );
            continue;
        }
        
        if ( FindDefByType( zonetype ) != -1 )
        {
            LogError( INF_CON_PRE..."Zone type '%s' is already defined!", szType );
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
        
        
        decl String:szTex[PLATFORM_MAX_PATH];
        kv.GetString( "texture", szTex, sizeof( szTex ), "" );
        
        decl String:szMat[PLATFORM_MAX_PATH];
        kv.GetString( "material", szMat, sizeof( szMat ), "" );
        
        
        int mat = 0;
        
        if ( szMat[0] != '\0' )
        {
            if ( FileExists( szMat, true ) )
            {
                if ( (mat = PrecacheModel( szMat )) > 0 )
                {
                    AddFileToDownloadsTable( szMat );
                }
                else
                {
                    LogError( INF_CON_PRE..."Couldn't precache beam material '%s'!", szMat );
                }
            }
            else
            {
                LogError( INF_CON_PRE..."Beam material '%s' does not exist!", szMat );
            }
        }
        
        if ( szTex[0] != '\0' )
        {
            if ( FileExists( szTex, true ) )
            {
                AddFileToDownloadsTable( szTex );
            }
            else
            {
                LogError( INF_CON_PRE..."Beam texture '%s' does not exist! Can't add to downloads table.", szTex );
            }
        }
        
        
        data[DEF_ZONETYPE] = view_as<int>( zonetype );
        
        data[DEF_DISPLAYTYPE] = view_as<int>( displaytype );
        
        data[DEF_MATINDEX] = mat;
        
        data[DEF_WIDTH] = view_as<int>( kv.GetFloat( "width", 0.0 ) );
        data[DEF_FRAMERATE] = kv.GetNum( "framerate", -1 );
        data[DEF_SPEED] = kv.GetNum( "speed", 0 );
        
        data[DEF_OFFSET] = view_as<int>( kv.GetFloat( "offset", 0.0 ) );
        data[DEF_OFFSET_Z] = view_as<int>( kv.GetFloat( "offset_z", 0.0 ) );
        
        
        FillArray( clr, 0, sizeof( clr ) );
        kv.GetColor4( "color", clr );
        
        CopyArray( clr, data[DEF_CLR], 4 );
        
        
        g_hDef.PushArray( data );
    }
    while ( kv.GotoNextKey() );
    
    delete kv;
}

public Action Influx_OnBeamAdd( int zoneid, ZoneType_t zonetype, DisplayType_t &displaytype, int &matindex, float &width, int &framerate, int &speed, float &offset, float &offset_z, int clr[4] )
{
    int index = FindDefByType( zonetype );
    if ( index == -1 ) return Plugin_Continue;
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Setting default beam settings to zone %i!", zoneid );
#endif

    decl data[DEF_SIZE];
    g_hDef.GetArray( index, data );
    
    if ( displaytype == DISPLAYTYPE_INVALID )
    {
        displaytype = view_as<DisplayType_t>( data[DEF_DISPLAYTYPE] );
    }
    
    if ( matindex < 1 )
    {
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."Setting default beam material to zone %i! (%i)", zoneid, data[DEF_MATINDEX] );
#endif
        matindex = data[DEF_MATINDEX];
    }
    
    if ( width == 0.0 )
    {
        width = view_as<float>( data[DEF_WIDTH] );
    }
    
    if ( framerate == -1 )
    {
        framerate = data[DEF_FRAMERATE];
    }
    
    //if ( speed == -1 )
    //{
    speed = data[DEF_SPEED];
    //}
    
    if ( offset == 0 )
    {
        offset = view_as<float>( data[DEF_OFFSET] );
    }
    
    if ( offset_z == 0 )
    {
        offset_z = view_as<float>( data[DEF_OFFSET_Z] );
    }
    
    if ( clr[3] == 0 )
    {
        CopyArray( data[DEF_CLR], clr, 4 );
    }
    
    return Plugin_Handled;
}

stock int FindDefByType( ZoneType_t zonetype )
{
    int len = g_hDef.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( view_as<ZoneType_t>( g_hDef.Get( i, DEF_ZONETYPE ) ) == zonetype )
        {
            return i;
        }
    }
    
    return -1;
}