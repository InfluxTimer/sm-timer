#include <sourcemod>

#include <influx/core>
#include <influx/colorchat>



//#define TEST
//#define DEBUG


#define HEX_CHAR                '\x07'


#define DEF_PREFIX              "{GREY}[{PINK}"...INF_NAME..."{GREY}]"
#define DEF_CHATCLR             "{WHITE}"



#define CLR_NAME_SIZE               16
#define CLR_NAME_SIZE_CELL          CLR_NAME_SIZE / 4

#define CLR_COLOR_SIZE              8 // "\x07{HEX}" | "XFFFFFF"
#define CLR_COLOR_SIZE_CELL         CLR_COLOR_SIZE / 4

enum
{
    CLR_NAME[CLR_NAME_SIZE_CELL] = 0,
    
    CLR_COLOR[CLR_COLOR_SIZE_CELL],
    
    CLR_COLOR_CSGO,
    
    CLR_SIZE
};


bool g_bIsCSGO;

char g_szPrefix[64];
char g_szChatClr[12];


ArrayList g_hClrs;
int g_nClrLen;

// CONVARS
ConVar g_ConVar_Prefix;
ConVar g_ConVar_ChatClr;


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Chat",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_COLORCHAT );
    
    
    // NATIVES
    CreateNative( "Influx_Chat", Native_Chat );
}

public void OnPluginStart()
{
    g_hClrs = new ArrayList( CLR_SIZE );
    
    
    g_bIsCSGO = ( GetEngineVersion() == Engine_CSGO );
    
    
    // CMDS
#if defined TEST
    RegAdminCmd( "sm_testchat", Cmd_Test, ADMFLAG_ROOT );
#endif
    
    
    // CONVARS
    g_ConVar_Prefix = CreateConVar( "influx_colorchat_prefix", DEF_PREFIX, "Prefix for chat messages.", FCVAR_NOTIFY );
    g_ConVar_ChatClr = CreateConVar( "influx_colorchat_chatcolor", DEF_CHATCLR, "Default chat color.", FCVAR_NOTIFY );
    
    AutoExecConfig( true, "colorchat", "influx" );
}

public void OnMapStart()
{
    g_hClrs.Clear();
    
    AddColor( "DEF", "\x01" );
    AddColor( "TEAM", "\x03" );
    AddColor( "DEFGREEN", "\x04" );
    AddColor( "PINK", "C20095", "\x0E", true );
    AddColor( "WHITE", "FFFFFF", "\x01", true );
    AddColor( "GREY", "606060", "\x08", true );
    AddColor( "LIGHTRED", "FF5A5A", "\x07", true );
    AddColor( "LIGHTYELLOW", "FFFF80", "\x09", true );
    
    DeterminePrefix();
    DetermineChatClr();
}

public int Native_Chat( Handle hPlugin, int nParms )
{
    int author = GetNativeCell( 1 );
    
    
    int nClients = GetNativeCell( 3 );
    
    int[] clients = new int[nClients];
    GetNativeArray( 2, clients, nClients );
    
    
    decl String:buffer[512];
    GetNativeString( 4, buffer, sizeof( buffer ) );
    
    
    FormatColors( buffer, sizeof( buffer ) );
    
    
    if ( !strlen( buffer ) )
    {
        return 0;
    }
    
    // Do prefix?
    if ( GetNativeCell( 5 ) )
    {
        Format( buffer, sizeof( buffer ), "%s %s%s", g_szPrefix, g_szChatClr, buffer );
    }
    
    Inf_SendSayText2( author, clients, nClients, buffer );
    
    return 1;
}

stock void FormatColors( char[] sz, int len )
{
    int start = 0;
    
    decl index, j;
    decl pos, posstart, endpos;
    
    decl color[CLR_COLOR_SIZE_CELL];
    
    decl colorlen;
    
    
    while ( (pos = FindCharInString( sz[start], '{' )) != -1 )
    {
        pos += start;
        
        posstart = pos + 1;
        
        endpos = FindCharInString( sz[posstart], '}' );
        if ( endpos == -1 ) break;
        
        
        endpos += posstart;
        
        // {} was found.
        /*if ( posstart == endpos )
        {
            start = endpos + 1;
            continue;
        }*/
        
        sz[endpos] = '\0';
        
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."Found potential chat color '%s'", sz[posstart] );
#endif
        
        colorlen = 0;
        
        
        // Want a hex color.
        if ( sz[posstart] == '#' )
        {
            if ( !g_bIsCSGO )
            {
                sz[posstart] = HEX_CHAR;
                
                strcopy( view_as<char>( color ), CLR_COLOR_SIZE, sz[posstart] );
            }
            // CS:GO doesn't support hex colors.
            else
            {
                strcopy( view_as<char>( color ), CLR_COLOR_SIZE, "\x01" );
            }
            
            colorlen = strlen( view_as<char>( color ) );
        }
        else
        {
            index = FindColorByName( sz[posstart] );
            if ( index != -1 )
            {
                if ( !g_bIsCSGO )
                {
                    for ( j = 0; j < CLR_COLOR_SIZE_CELL; j++ )
                    {
                        color[j] = g_hClrs.Get( index, CLR_COLOR + j );
                    }
                }
                else
                {
                    color[0] = g_hClrs.Get( index, CLR_COLOR_CSGO );
                }
                
#if defined DEBUG
                PrintToServer( INF_DEBUG_PRE..."Match found! '%s'", color );
#endif
                
                colorlen = strlen( view_as<char>( color ) );
            }
            
            
            sz[pos] = '\0';
            
            if ( colorlen )
            {
                Format( sz, len, "%s%s%s", sz, color, sz[endpos + 1] );
                
                start = pos + colorlen;
            }
            else
            {
                Format( sz, len, "%s%s", sz, sz[endpos + 1] );
                
                start = pos;
            }
        }
        
        
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."String is now: '%s'", sz );
#endif
    }
}

stock int FindColorByName( const char[] clrname )
{
    static char name[CLR_NAME_SIZE];
    
    for ( int i = 0; i < g_nClrLen; i++ )
    {
        g_hClrs.GetString( i, name, sizeof( name ) );
        
        if ( StrEqual( clrname, name ) )
        {
            return i;
        }
    }
    
    return -1;
}

stock bool CheckNameLen( const char[] name )
{
    if ( strlen( name ) >= CLR_NAME_SIZE )
    {
        LogError( INF_CON_PRE..."Color name '%s' is too long! Maximum characters is %i.", name, CLR_NAME_SIZE - 1 );
        return false;
    }
    
    return true;
}

stock void AddColor( const char[] clrname, const char[] c, const char[] clrname_csgo = "", bool csgo_char = false )
{
    if ( !CheckNameLen( clrname ) ) return;
    
    
    if ( FindColorByName( clrname ) )
    {
        return;
    }
    
    
    char color[CLR_COLOR_SIZE];
    char color_csgo[4];
    
    
    strcopy( color, sizeof( color ), c );
    
    int colorlen = strlen( color );
    if ( colorlen != 1 )
    {
        int offset = ( color[0] == HEX_CHAR ) ? 1 : 0;
        if ( IsHexColor( color[offset] ) )
        {
            Format( color, sizeof( color ), "\x07%s", color[offset] );
        }
        else
        {
            LogError( INF_CON_PRE..."Invalid hex color '%s'", color );
            color[0] = '\x01';
        }
    }
    
    
    if ( clrname_csgo[0] != '\0' )
    {
        if ( !CheckNameLen( clrname_csgo ) ) return;
        
        
        if ( !csgo_char )
        {
            int index = FindColorByName( clrname_csgo );
            
            if ( index != -1 )
            {
                int temp[1];
                temp[0] = g_hClrs.Get( index, CLR_COLOR );
                
                strcopy( color_csgo, sizeof( color_csgo ), view_as<char>( temp ) );
            }
            else
            {
                LogError( INF_CON_PRE..."Color '%s' does not exist!", clrname_csgo );
            }
        }
        else
        {
            color_csgo[0] = clrname_csgo[0];
        }
    }
    
    if ( color_csgo[0] == '\0' )
    {
        if ( colorlen == 1 )
        {
            color_csgo[0] = color[0];
        }
        else
        {
            color_csgo[0] = '\x01';
        }
    }
    
    
    int data[CLR_SIZE];
    
    strcopy( view_as<char>( data[CLR_NAME] ), CLR_NAME_SIZE, clrname );
    strcopy( view_as<char>( data[CLR_COLOR] ), CLR_COLOR_SIZE, color );
    strcopy( view_as<char>( data[CLR_COLOR_CSGO] ), 4, color_csgo );
    
    
    g_hClrs.PushArray( data );
    g_nClrLen = g_hClrs.Length;
}

stock bool IsHexColor( const char[] sz )
{
    int len = strlen( sz );
    if ( len != 6 ) return false;
    
    for ( int i = 0; i < len; i++ )
    {
        if ( sz[i] >= 'A' && sz[i] <= 'F' ) continue;
        if ( sz[i] >= 'a' && sz[i] <= 'f' ) continue;
        if ( sz[i] >= '0' && sz[i] <= '9' ) continue;
        
        return false;
    }
    
    return true;
}

stock void DeterminePrefix()
{
    g_ConVar_Prefix.GetString( g_szPrefix, sizeof( g_szPrefix ) );
    
    
    // Add CSGO fix.
    if ( g_bIsCSGO )
    {
        Format( g_szPrefix, sizeof( g_szPrefix ), " \x01\x0B%s", g_szPrefix );
    }
    
    
    FormatColors( g_szPrefix, sizeof( g_szPrefix ) );
    
#if defined DEBUG
    PrintToServer( INF_CON_PRE..."Prefix: '%s'", g_szPrefix );
#endif
}

stock void DetermineChatClr()
{
    g_ConVar_ChatClr.GetString( g_szChatClr, sizeof( g_szChatClr ) );
    
    
    FormatColors( g_szChatClr, sizeof( g_szChatClr ) );
    
    int len = strlen( g_szChatClr );
    
    if ( len >= 2 && g_szChatClr[0] != HEX_CHAR )
    {
        LogError( INF_CON_PRE..."Chat color cannot be more than one color!" );
        return;
    }
    
    
    AddColor( "CHATCLR", g_szChatClr );
    
#if defined DEBUG
    PrintToServer( INF_CON_PRE..."Chat color: '%s'", g_szChatClr );
#endif
}

public Action Cmd_Test( int client, int args )
{
    if ( args && client )
    {
        decl String:szArg[512];
        GetCmdArgString( szArg, sizeof( szArg ) );
        StripQuotes( szArg );
        
        FormatColors( szArg, sizeof( szArg ) );
        
        Format( szArg, sizeof( szArg ), "%s %s%s", g_szPrefix, g_szChatClr, szArg );
        
        
        decl clients[1];
        clients[0] = client;
        
        Inf_SendSayText2( client, clients, sizeof( clients ), szArg );
    }
    
    return Plugin_Handled;
}