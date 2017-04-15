#define TAS_DIR     "influxtas"


stock void FormatTasPath( char[] sz, int len, int uid, int runid, int mode, style, const char[] szArgMap = "" )
{
    decl String:szMode[MAX_MODE_SHORTNAME];
    decl String:szStyle[MAX_STYLE_SHORTNAME];
    
    Influx_GetModeShortName( mode, szMode, sizeof( szMode ) );
    StringToLower( szMode );
    
    Influx_GetStyleShortName( style, szStyle, sizeof( szStyle ) );
    StringToLower( szStyle );
    
    
    decl String:szMap[64];
    
    if ( szArgMap[0] != 0 )
    {
        strcopy( szMap, sizeof( szMap ), szArgMap );
    }
    else
    {
        GetCurrentMapSafe( szMap, sizeof( szMap ) );
    }
    
    
    BuildPath( Path_SM, sz, len, TAS_DIR..."/%s/%i/%i_%s_%s.tas",
        szMap,
        uid,
        runid,
        szMode,
        szStyle );
}

stock bool LoadFrames( int client, ArrayList &frames, int runid, int mode, int style )
{
    int uid = Influx_GetClientId( client );
    if ( uid < 1 ) return false;
    
    
    decl String:szPath[PLATFORM_MAX_PATH];
    
    decl String:szMap[64];
    GetCurrentMapSafe( szMap, sizeof( szMap ) );
    
    
    FormatTasPath( szPath, sizeof( szPath ), uid, runid, mode, style, szMap );
    
    
    File file = OpenFile( szPath, "rb" );
    
    if ( file == null )
    {
        return false;
    }
    
    
    int temp;
    float flTemp;
    
    file.ReadInt32( temp );
    if ( temp != TASFILE_CURMAGIC )
    {
        delete file;
        return false;
    }
    
    file.ReadInt32( temp );
    if ( temp != TASFILE_CURVERSION )
    {
        delete file;
        return false;
    }
    
    file.ReadInt32( temp );
    if ( temp != TASFILE_CURHEADERSIZE )
    {
        delete file;
        return false;
    }
    
    
    float curtickrate = float( RoundFloat( 1.0 / GetTickInterval() ) );
    
    file.ReadInt32( view_as<int>( flTemp ) );
    if ( curtickrate != flTemp )
    {
        LogError( INF_CON_PRE..."Found TAS file '%s' with different tickrate! (Current: %.0f | File: %.0f)",
            szPath,
            curtickrate,
            flTemp );
        
        delete file;
        return false;
    }
    
    file.ReadInt32( temp );
    if ( temp != runid )
    {
        delete file;
        return false;
    }
    
    file.ReadInt32( temp );
    if ( temp != mode )
    {
        delete file;
        return false;
    }
    
    file.ReadInt32( temp );
    if ( temp != style )
    {
        delete file;
        return false;
    }
    
    
    decl mapname[MAX_TASFILE_MAPNAME_CELL];
    decl plyname[MAX_TASFILE_PLYNAME_CELL];
    
    file.Read( mapname, sizeof( mapname ), 4 );
    file.Read( plyname, sizeof( plyname ), 4 );
    
    
    int len;
    file.ReadInt32( len );
    if ( len < 1 )
    {
        delete file;
        return false;
    }
    
    
    decl data[FRM_SIZE];
    
    delete frames;
    
    frames = new ArrayList( FRM_SIZE );
    
    
    for ( int i = 0; i < len; i++ )
    {
        if ( file.Read( data, sizeof( data ), 4 ) == -1 )
        {
            LogError( INF_CON_PRE..."Encountered a sudden end of file!" );
            
            delete frames;
            delete file;
            
            return false;
        }
        
        frames.PushArray( data );
    }
    
    
    delete file;
    
    return true;
}

stock bool SaveFrames( int client )
{
    int uid = Influx_GetClientId( client );
    if ( uid < 1 ) return false;
    
    
    ArrayList frames = g_hFrames[client];
    
    if ( frames == null ) return false;
    
    if ( frames.Length < 1 ) return false;
    
    
    decl String:szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), TAS_DIR );
    
    if ( !DirExistsEx( szPath ) ) return false;
    
    
    decl String:szMap[64];
    GetCurrentMapSafe( szMap, sizeof( szMap ) );
    
    Format( szPath, sizeof( szPath ), "%s/%s", szPath, szMap );
    
    if ( !DirExistsEx( szPath ) ) return false;
    
    
    Format( szPath, sizeof( szPath ), "%s/%i", szPath, uid );
    
    if ( !DirExistsEx( szPath ) ) return false;
    
    
    int runid = Influx_GetClientRunId( client );
    int mode = Influx_GetClientMode( client );
    int style = Influx_GetClientStyle( client );
    
    
    decl String:szMode[MAX_MODE_SHORTNAME];
    decl String:szStyle[MAX_STYLE_SHORTNAME];
    
    Influx_GetModeShortName( mode, szMode, sizeof( szMode ) );
    StringToLower( szMode );
    
    Influx_GetStyleShortName( style, szStyle, sizeof( szStyle ) );
    StringToLower( szStyle );
    
    
    Format( szPath, sizeof( szPath ), "%s/%i_%s_%s.tas",
        szPath,
        runid,
        szMode,
        szStyle );
    
    
    File file = OpenFile( szPath, "wb" );
    
    if ( file == null )
    {
        return false;
    }
    
    
    file.WriteInt32( TASFILE_CURMAGIC );
    file.WriteInt32( TASFILE_CURVERSION );
    file.WriteInt32( TASFILE_CURHEADERSIZE );
    
    file.WriteInt32( view_as<int>( float( RoundFloat( 1.0 / GetTickInterval() ) ) ) );
    
    file.WriteInt32( runid );
    file.WriteInt32( mode );
    file.WriteInt32( style );
    
    
    
    decl mapname[MAX_TASFILE_MAPNAME_CELL];
    strcopy( view_as<char>( mapname ), MAX_TASFILE_MAPNAME, szMap );
    
    decl plyname[MAX_TASFILE_PLYNAME_CELL];
    GetClientName( client, view_as<char>( plyname ), MAX_TASFILE_PLYNAME );
    
    file.Write( mapname, sizeof( mapname ), 4 );
    file.Write( plyname, sizeof( plyname ), 4 );
    
    
    decl data[FRM_SIZE];
    
    
    
    int len = frames.Length;
    file.WriteInt32( len );
    
    for ( int i = 0; i < len; i++ )
    {
        frames.GetArray( i, data );
        
        file.Write( data, sizeof( data ), 4 );
    }
    
    delete file;
    
    return true;
}