#include <sourcemod>

#include <influx/core>
#include <influx/silent_chatcmds>

#undef REQUIRE_PLUGIN
#include <influx/simpleranks_chat>


//#define DEBUG



#define MAX_CMDS        32
#define CMD_SIZE        64
#define CMD_SIZE_CELL   (CMD_SIZE / 4)

// CONVARS
ConVar g_ConVar_Cmds;


// LIBRARIES
bool g_bLib_SimpleRanksChat;


ArrayList g_hCmds;

char g_szPublicChatTrigger[32];


bool g_bLate;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Silent Chat Commands",
    description = "Hides certain public chat commands",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_SILENT_CHATCMDS );
    
    
    CreateNative( "Influx_ShouldSilenceCmd", Native_ShouldSilenceCmd );
    
    g_bLate = late;
}

public void OnPluginStart()
{
    // CONVARS
    g_ConVar_Cmds = CreateConVar( "influx_silent_chatcmds", "r,restart,rs,re,respawn,spawn", "These commands will not be shown in chat even when using public chat trigger. Separate with commas." );
    
    AutoExecConfig( true, "silent_chatcmds", "influx" );
    
    
    // LIBRARIES
    g_bLib_SimpleRanksChat = LibraryExists( INFLUX_LIB_SIMPLERANKS_CHAT );
    
    
    
    g_hCmds = new ArrayList( CMD_SIZE_CELL );
    
    
    // Just assume ! by default.
    strcopy( g_szPublicChatTrigger, sizeof( g_szPublicChatTrigger ), "!" );
    
    if ( g_bLate )
        ReadConfig();
}

public void OnLibraryAdded( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_SIMPLERANKS_CHAT ) ) g_bLib_SimpleRanksChat = true;
}

public void OnLibraryRemoved( const char[] lib )
{
    if ( StrEqual( lib, INFLUX_LIB_SIMPLERANKS_CHAT ) ) g_bLib_SimpleRanksChat = false;
}

public void OnConfigsExecuted()
{
    ReadCmds();
}

public void OnMapStart()
{
    ReadConfig();
}

public Action OnClientSayCommand( int client, const char[] szCommand, const char[] szMsg )
{
    // Only silence if other plugins aren't overriding this hook.
    if ( !IsHookOverridden() && IsChatTrigger() && ShouldSilence( szMsg ) )
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

stock void ReadCmds()
{
    // Populate the cmd array list
    g_hCmds.Clear();
    
    
    char szBuf[ MAX_CMDS * CMD_SIZE + MAX_CMDS - 1 ];
    char szCmds[MAX_CMDS][CMD_SIZE];
    g_ConVar_Cmds.GetString( szBuf, sizeof( szBuf ) );
    int nStrs = ExplodeString( szBuf, ",", szCmds, sizeof( szCmds ), sizeof( szCmds[] ) );
    
    for ( int i = 0; i < nStrs; i++ )
    {
        if ( szCmds[i][0] == 0 )
            continue;
        
        
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."Adding silent cmd: %s", szCmds[i] );
#endif
        
        g_hCmds.PushString( szCmds[i] );
    }
}

stock void ReadConfig()
{
    // Get the public chat trigger that we'll be listening for.
    // We can't use this for now because of the way core.cfg is formatted.
    /*
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "configs/core.cfg" );
    
    KeyValues kv = new KeyValues( "Core" );
    if ( !kv.ImportFromFile( szPath ) )
    {
        LogError( INF_CON_PRE..."Couldn't open core.cfg SourceMod config for read!" );
        
        delete kv;
        return;
    }
    
    
    char szTrigger[64];
    kv.GetString( "PublicChatTrigger", szTrigger, sizeof( szTrigger ) );
    if ( szTrigger[0] != 0 )
    {
        strcopy( g_szPublicChatTrigger, sizeof( g_szPublicChatTrigger ), szTrigger );
    }
    else
    {
        LogError( INF_CON_PRE..."No public chat trigger to listen to!" );
    }
    
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Public chat trigger is: %s", g_szPublicChatTrigger );
#endif
    
    delete kv;
    */
}

stock bool ShouldSilence( const char[] szMsg )
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Message %s", szMsg );
#endif
    if ( g_szPublicChatTrigger[0] == 0 )
        return false;
    
    if ( StrContains( szMsg, g_szPublicChatTrigger ) != 0 )
    {
        return false;
    }
    
    int len = strlen( g_szPublicChatTrigger );
    int msg_len = strlen( szMsg );
    if ( msg_len <= len )
        return false;
    
    
    // Only compare up to a space.
    int comp_len = FindCharInString( szMsg[len], ' ' );
    if ( comp_len <= 0 )
        comp_len = msg_len - len;
    
    char szTemp[CMD_SIZE];
    for ( int i = 0; i < g_hCmds.Length; i++ )
    {
        g_hCmds.GetString( i, szTemp, sizeof( szTemp ) );
        
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."Comparing %s with %s...", szMsg[len], szTemp );
#endif
        
        if ( strncmp( szMsg[len], szTemp, comp_len, true ) == 0 )
        {
            return true;
        }
    }
    
    return false;
}

stock bool IsHookOverridden()
{
    return g_bLib_SimpleRanksChat;
}

// NATIVES
public int Native_ShouldSilenceCmd( Handle hPlugin, int nParms )
{
    char szBuf[128];
    GetNativeString( 1, szBuf, sizeof( szBuf ) );
    return ShouldSilence( szBuf );
}
