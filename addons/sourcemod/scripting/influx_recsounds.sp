#include <sourcemod>
#include <sdktools>

#include <influx/core>

#undef REQUIRE_PLUGIN
#include <influx/hud>


//#define DEBUG


#define SOUNDS_FILE                 "influx_sounds.cfg"




#define PLATFORM_MAX_PATH_CELL      PLATFORM_MAX_PATH / 4


ArrayList g_hOtherSounds;
ArrayList g_hBestSounds;
ArrayList g_hPBSounds;

bool g_bLib_Hud;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Record Sounds",
    description = "Plays sound when finishing",
    version = INF_VERSION
};

public void OnPluginStart()
{
    g_hOtherSounds = new ArrayList( PLATFORM_MAX_PATH_CELL );
    g_hBestSounds = new ArrayList( PLATFORM_MAX_PATH_CELL );
    g_hPBSounds = new ArrayList( PLATFORM_MAX_PATH_CELL );
    
    
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

public void Influx_OnRequestResultFlags()
{
    Influx_AddResultFlag( "Don't play record sound", RES_SND_DONTPLAY );
}

public void OnMapStart()
{
    ReadSounds();
}

stock bool ReadSounds()
{
    g_hOtherSounds.Clear();
    g_hBestSounds.Clear();
    g_hPBSounds.Clear();
    
    char szFile[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szFile, sizeof( szFile ), "configs/"...SOUNDS_FILE );
    
    
    KeyValues kv = new KeyValues( "Sounds" );
    kv.ImportFromFile( szFile );
    
    if ( !kv.GotoFirstSubKey() )
    {
        delete kv;
        return false;
    }
    
    
    char szPath[PLATFORM_MAX_PATH], szDownload[PLATFORM_MAX_PATH];
    
    do
    {
        if ( !kv.GetSectionName( szPath, sizeof( szPath ) ) )
        {
            continue;
        }
        
        
        bool bAdded = false;
        
        int sounds_offset = 0;
        
        if (StrContains( szPath, "sound/", false ) == 0
        ||  StrContains( szPath, "sound\\", false ) == 0)
        {
            sounds_offset = 6;
            
            strcopy( szDownload, sizeof( szDownload ), szPath );
        }
        else
        {
            FormatEx( szDownload, sizeof( szDownload ), "sound/%s", szPath );
        }
        
        
#if defined DEBUG
            PrintToServer( INF_DEBUG_PRE..."Found sound: '%s' | Download path: '%s'",
                szPath[sounds_offset],
                szDownload );
#endif
        
        if ( !FileExists( szDownload, true ) )
        {
            LogError( INF_CON_PRE..."Sound file '%s' does not exist! Ignoring it.", szDownload );
            continue;
        }
        
        if ( PrecacheSound( szPath[sounds_offset] ) )
        {
            PrefetchSound( szPath[sounds_offset] );
            
            AddFileToDownloadsTable( szDownload );
        }
        else
        {
            LogError( INF_CON_PRE..."Couldn't precache record sound! Ignoring it. Sound: '%s'", szPath[sounds_offset] );
            
            continue;
        }
        
        
        if ( kv.GetNum( "pb", 0 ) )
        {
            g_hPBSounds.PushString( szPath[sounds_offset] );
            bAdded = true;
        }
        
        if ( kv.GetNum( "best", 0 ) )
        {
            g_hBestSounds.PushString( szPath[sounds_offset] );
            bAdded = true;
        }
        
        // If we have none just add to this.
        if ( kv.GetNum( "other", 0 ) || !bAdded )
        {
            g_hOtherSounds.PushString( szPath[sounds_offset] );
        }
        
        /*if ( kv.JumpToKey( "users", false ) )
        {
            kv.GoBack();
        }*/
    }
    while( kv.GotoNextKey() );
    
    delete kv;
    
    return true;
}

public void Influx_OnTimerFinishPost( int client, int runid, int mode, int style, float time, float prev_pb, float prev_best, int flags )
{
    // We don't want to play any sounds for this run!
    if ( flags & RES_SND_DONTPLAY ) return;
    
    
    decl String:szPath[PLATFORM_MAX_PATH];
    szPath[0] = '\0';
    
    if ( flags & (RES_TIME_FIRSTREC | RES_TIME_ISBEST) )
    {
        int len = g_hBestSounds.Length;
        
        if ( len )
        {
            g_hBestSounds.GetString( GetRandomInt( 0, len - 1 ), szPath, sizeof( szPath ) );
        }
    }
    else if ( flags & RES_TIME_PB )
    {
        int len = g_hPBSounds.Length;
        
        if ( len )
        {
            g_hPBSounds.GetString( GetRandomInt( 0, len - 1 ), szPath, sizeof( szPath ) );
        }
    }
    
    // Fallback to these sounds if others don't exist.
    if ( szPath[0] == '\0' )
    {
        int len = g_hOtherSounds.Length;
        
        if ( len )
        {
            g_hOtherSounds.GetString( GetRandomInt( 0, len - 1 ), szPath, sizeof( szPath ) );
        }
    }
    
    if ( szPath[0] != '\0' )
    {
        PlayRecordSound( szPath, client, flags );
    }
}

stock bool CanPlaySoundToClient( int client, int finisher, int flags )
{
    int hideflags = Influx_GetClientHideFlags( client );
    
    // Allow my own sounds.
    if ( finisher == client )
    {
        return ( hideflags & HIDEFLAG_SND_PERSONAL ) ? false : true;
    }
    
    // Allow new record sounds.
    if ( flags & (RES_TIME_FIRSTREC | RES_TIME_ISBEST) )
    {
        return ( hideflags & HIDEFLAG_SND_BEST ) ? false : true;
    }
    
    return ( hideflags & HIDEFLAG_SND_NORMAL ) ? false : true;
}

stock void PlayRecordSound( const char[] szSound, int finisher, int resflags )
{
    int[] clients = new int[MaxClients];
    int nClients = 0;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame( i ) && !IsFakeClient( i ) )
        {
            if ( g_bLib_Hud )
            {
                if ( !CanPlaySoundToClient( i, finisher, resflags ) )
                    continue;
            }
            
            clients[nClients++] = i;
        }
    }
    
    if ( nClients )
    {
        EmitSoundCompatible( clients, nClients, szSound );
    }
}

stock void EmitSoundCompatible( const int[] clients, int nClients, const char[] szSound )
{
    if ( GetEngineVersion() == Engine_CSGO )
    {
        decl String:szCommand[PLATFORM_MAX_PATH];
        FormatEx( szCommand, sizeof( szCommand ), "play */%s", szSound );
        
        for ( int i = 0; i < nClients; i++ )
        {
            ClientCommand( clients[i], szCommand );
        }
    }
    else
    {
        EmitSound( clients, nClients, szSound );
    }
}