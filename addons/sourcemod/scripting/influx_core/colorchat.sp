#define HEX_CHAR                    '\x07'

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



stock void InitColors()
{
    g_hChatClrs.Clear();
    g_nChatClrLen = -1;
    
    
    AddColor( "TEAM", "\x03" );
    
    
    AddColor( "RED", "FF0000", "\x02" );
    AddColor( "LIGHTRED", "FF5B5B", "\x07" );
    AddColor( "LIGHTERRED", "FF6A6A", "\x0F" );
    
    AddColor( "GREEN", "\x04" );
    AddColor( "LIGHTGREEN", "C0FFC0", "\x05" );
    AddColor( "LIMEGREEN", "89FF00", "\x06" );
    
    AddColor( "BLUE", "0000FF", "\x0C" );
    AddColor( "SKYBLUE", "00ABFF", "\x0B" );
    
    AddColor( "LIGHTYELLOW", "FFFF80", "\x09" );
    AddColor( "GOLD", "FFD700", "\x10" );
    
    
    AddColor( "WHITE", "FFFFFF", "\x01" );
    AddColor( "PINK", "C20095", "\x0E" );
    AddColor( "GREY", "606060", "\x08" );
    
    
    
    DetermineChatPrefix();
    DetermineChatClr();
    DetermineChatMainClr1();
    //DetermineChatMainClr2();
}

stock void RemoveColors( char[] sz, int len )
{
    int start = 0;
    
    decl pos, startpos, endpos;
    
    while ( (pos = FindCharInString( sz[start], '{' )) != -1 )
    {
        pos += start;
        
        
        startpos = pos + 1;
        
        endpos = FindCharInString( sz[startpos], '}' );
        if ( endpos == -1 ) break;
        
        
        endpos += startpos;
        
        sz[endpos] = '\0';
        
        
        bool match = false;
        
        if ( sz[startpos] == '#' )
        {
            match = true;
        }
        else
        {
            match = ( FindColorByName( sz[startpos] ) != -1 );
        }
        
        
        if ( match )
        {
            sz[pos] = '\0';
            
            Format( sz, len, "%s%s", sz, sz[endpos + 1] );
            
            start = pos;
        }
        else
        {
            sz[endpos] = '}';
            
            start = pos + 1;
        }
    }
}

stock void FormatColors( char[] sz, int len )
{
#if defined DEBUG_COLORCHAT
    PrintToServer( INF_DEBUG_COLORCHAT_PRE..."Formatting msg '%s'", sz );
#endif
    
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
        
        
        sz[endpos] = '\0';
        
#if defined DEBUG_COLORCHAT
        PrintToServer( INF_DEBUG_COLORCHAT_PRE..."Found potential chat color '%s'", sz[posstart] );
#endif
        
        
        // Want a hex color.
        if ( sz[posstart] == '#' )
        {
            if ( !g_bIsCSGO )
            {
                sz[posstart] = HEX_CHAR;
                
                strcopy( view_as<char>( color ), CLR_COLOR_SIZE, sz[posstart] );
                
                colorlen = strlen( view_as<char>( color ) );// + 1;
            }
            // CS:GO doesn't support hex colors.
            else
            {
                strcopy( view_as<char>( color ), CLR_COLOR_SIZE, "\x01" );
                
                colorlen = 1;
            }
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
                        color[j] = g_hChatClrs.Get( index, CLR_COLOR + j );
                    }
                }
                else
                {
                    color[0] = g_hChatClrs.Get( index, CLR_COLOR_CSGO );
                }
                
#if defined DEBUG_COLORCHAT
                PrintToServer( INF_DEBUG_COLORCHAT_PRE..."Match found! '%s'", color );
#endif
                
                colorlen = strlen( view_as<char>( color ) );
            }
            else
            {
                colorlen = 0;
                
#if defined DEBUG_COLORCHAT
                PrintToServer( INF_DEBUG_COLORCHAT_PRE..."Couldn't find match for '%s'", sz[posstart] );
#endif
            }
        }
        
        
        if ( colorlen )
        {
            sz[pos] = '\0';
            
            Format( sz, len, "%s%s%s", sz, color, sz[endpos + 1] );
            
            start = pos + colorlen;
        }
        else
        {
            // This isn't a color, just ignore it.
            sz[pos] = '{';
            sz[endpos] = '}';
            
            start = pos + 1;
        }

        
#if defined DEBUG_COLORCHAT
        PrintToServer( INF_DEBUG_COLORCHAT_PRE..."String is now: '%s'", sz );
#endif
    }
}

stock void AddColor( const char[] clrname, const char[] c, const char[] c_csgo = "" )
{
    if ( !CheckNameLen( clrname ) ) return;
    
    
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
    
    
    if ( c_csgo[0] != '\0' )
    {
        color_csgo[0] = c_csgo[0];
    }
    else
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
    
    int index = FindColorByName( clrname );
    
    strcopy( view_as<char>( data[CLR_NAME] ), CLR_NAME_SIZE, clrname );
    strcopy( view_as<char>( data[CLR_COLOR] ), CLR_COLOR_SIZE, color );
    strcopy( view_as<char>( data[CLR_COLOR_CSGO] ), 4, color_csgo );
    
    
    // Replace existing one.
    if ( index != -1 )
    {
        g_hChatClrs.SetArray( index, data );
    }
    else // Add new one.
    {
        g_hChatClrs.PushArray( data );
        g_nChatClrLen = g_hChatClrs.Length;
    }
    
    
#if defined DEBUG_COLORCHAT
    PrintToServer( INF_DEBUG_COLORCHAT_PRE..."%s color %s ('%s', '%s')", ( index != -1 ) ? "Replaced" : "Added", clrname, color, color_csgo );
#endif
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


stock int FindColorByName( const char[] clrname )
{
    static char name[CLR_NAME_SIZE];
    
    for ( int i = 0; i < g_nChatClrLen; i++ )
    {
        g_hChatClrs.GetString( i, name, sizeof( name ) );
        
        if ( StrEqual( clrname, name, true ) )
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

stock void DetermineChatPrefix()
{
#if defined DEBUG_COLORCHAT
    PrintToServer( INF_DEBUG_COLORCHAT_PRE..."Formatting chat prefix..." );
#endif

    decl String:szPrefix[256];
    g_ConVar_ChatPrefix.GetString( szPrefix, sizeof( szPrefix ) );
    
    
    FormatColors( szPrefix, sizeof( szPrefix ) );
    
    
    strcopy( g_szChatPrefix, sizeof( g_szChatPrefix ), szPrefix );
    
#if defined DEBUG_COLORCHAT
    PrintToServer( INF_CON_PRE..."Prefix: '%s'", g_szChatPrefix );
#endif
}

stock void DetermineChatClr()
{
#if defined DEBUG_COLORCHAT
    PrintToServer( INF_DEBUG_COLORCHAT_PRE..."Formatting chat color..." );
#endif
    
    decl String:szChatClr[256];
    g_ConVar_ChatClr.GetString( szChatClr, sizeof( szChatClr ) );
    
    
    FormatColors( szChatClr, sizeof( szChatClr ) );
    
    int len = strlen( szChatClr );
    
    // Don't allow chat color that is more than one color or not a color in the first place.
    if ( len >= 2 && (szChatClr[0] != HEX_CHAR || g_bIsCSGO) )
    {
        LogError( INF_CON_PRE..."Chat color cannot be more than one color!" );
        return;
    }
    
    
    AddColor( "CHATCLR", szChatClr );
    
    
    strcopy( g_szChatClr, sizeof( g_szChatClr ), szChatClr );
    
#if defined DEBUG_COLORCHAT
    PrintToServer( INF_CON_PRE..."Chat color: '%s'", g_szChatClr );
#endif
}

stock void DetermineChatMainClr1()
{
    char szClr[128];
    g_ConVar_ChatMainClr1.GetString( szClr, sizeof( szClr ) );
    
    
    FormatColors( szClr, sizeof( szClr ) );
    
    AddColor( "MAINCLR1", szClr );
}

/*
stock void DetermineChatMainClr2()
{
    char szClr[128];
    g_ConVar_ChatMainClr2.GetString( szClr, sizeof( szClr ) );
    
    
    FormatColors( szClr, sizeof( szClr ) );
    
    AddColor( "MAINCLR2", szClr );
}
*/