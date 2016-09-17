#if defined _msharedutil_misc_included
    #endinput
#endif
#define _msharedutil_misc_included


#include <sourcemod>


//#define _DEBUG_MAP


stock float TickCountToTime( int ticks )
{
    return ticks * GetTickInterval();
}

stock void GetCurrentMapSafe( char[] sz, int len )
{
    decl String:map[128];
    GetCurrentMapLower( map, sizeof( map ) );
    
#if defined _DEBUG_MAP
    PrintToServer( "Found map: '%s'", map );
#endif
    
    // GetMapDisplayName seems to require that the map is in mapcycle file(?)
    // I never got it to work. This is why we're doing this.
    int lastpos = -1;
    
    int start = 0;
    int pos = -1;
    
    while ( (pos = FindCharInString( map[start], '/' )) != -1 )
    {
        lastpos = pos + start + 1;
        
        start += pos + 1;
    }
    
    if ( lastpos != -1 && map[lastpos] != '\0' )
    {
        strcopy( sz, len, map[lastpos] );
    }
    else
    {
        strcopy( sz, len, map );
    }
    
#if defined _DEBUG_MAP
    PrintToServer( "Returning map: '%s'", sz );
#endif
}

stock void GetCurrentMapLower( char[] sz, int len )
{
    GetCurrentMap( sz, len );
    
    StringToLower( sz );
}

stock void StringToLower( char[] sz )
{
    int len = strlen( sz );
    
    for ( int i = 0; i < len; i++ )
        if ( IsCharUpper( sz[i] ) )
            sz[i] = CharToLower( sz[i] );
}

stock void StringToUpper( char[] sz )
{
    int len = strlen( sz );
    
    for ( int i = 0; i < len; i++ )
        if ( IsCharLower( sz[i] ) )
            sz[i] = CharToUpper( sz[i] );
}

stock void LimitString( char[] out, int len, int numchars )
{
    if ( numchars >= len ) return;
    
    if ( numchars <= 3 ) return;
    
    
    if ( strlen( out ) > numchars )
    {
        out[numchars] = '\0';
        out[numchars - 1] = '.';
        out[numchars - 2] = '.';
        out[numchars - 3] = '.';
    }
}

stock int RemoveChars( char[] out, const char[] matches )
{
    int out_len = strlen( out );
    if ( !out_len ) return 0;
    
    int match_len = strlen( matches );
    if ( !match_len ) return 0;
    
    
    int numreplaced = 0;
    
    decl j, k;
    for ( int i = 0; i < match_len; i++ )
    {
        for ( j = 0; j < out_len; )
        {
            // Found a match.
            if ( out[j] == matches[i] )
            {
                for ( k = j; k < out_len; k++ )
                {
                    out[k] = out[k + 1];
                }
                
                --out_len;
                
                ++numreplaced;
            }
            else
            {
                ++j;
            }
        }
    }
    
    return numreplaced;
}

stock bool DirExistsEx( const char[] szPath )
{
    if ( !DirExists( szPath ) )
    {
        CreateDirectory( szPath, 511 );
        
        if ( !DirExists( szPath ) )
        {
            LogError( "Couldn't create folder! (%s)", szPath );
            return false;
        }
    }
    
    return true;
}