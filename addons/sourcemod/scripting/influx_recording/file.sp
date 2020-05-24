stock void FormatRecordingPath( char[] sz, int len, int runid, int mode, int style, const char[] szArgMap = "" )
{
    decl String:szMode[MAX_SAFENAME];
    decl String:szStyle[MAX_SAFENAME];
    
    Influx_GetModeSafeName( mode, szMode, sizeof( szMode ) );
    //StringToLower( szMode );
    
    Influx_GetStyleSafeName( style, szStyle, sizeof( szStyle ) );
    //StringToLower( szStyle );
    
    
    decl String:szMap[64];
    
    if ( szArgMap[0] != 0 )
    {
        strcopy( szMap, sizeof( szMap ), szArgMap );
    }
    else
    {
        GetCurrentMapSafe( szMap, sizeof( szMap ) );
    }
    
    
    
    BuildPath( Path_SM, sz, len, RECORDS_DIR..."/%s/rec/%i_%s_%s.rec",
        szMap,
        runid,
        szMode,
        szStyle );
}

stock void LoadAllRecordings()
{
    if ( g_bRecordingsLoaded )
    {
        return;
    }
    
    g_bRecordingsLoaded = true;
    
    
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), RECORDS_DIR );

    if ( !DirExistsEx( szPath ) ) return;
    
    
    char szMap[64];
    GetCurrentMapSafe( szMap, sizeof( szMap ) );
    
    Format( szPath, sizeof( szPath ), "%s/%s", szPath, szMap );
    if ( !DirExistsEx( szPath ) ) return;
    
    
    Format( szPath, sizeof( szPath ), "%s/rec", szPath );
    if ( !DirExistsEx( szPath ) ) return;
    
    
    DirectoryListing dir = OpenDirectory( szPath );
    if ( dir == null )
    {
        LogError( INF_CON_PRE..."Couldn't open directory '%s' for reading!", szPath );
        return;
    }
    
    
    char szFile[PLATFORM_MAX_PATH];
    int len, dotpos;
    
    int runid, mode, style;
    int filerunid = -1;
    float time;
    char szName[MAX_BEST_NAME];
    
    int numrecs = 0;
    
    char bufs[3][16];
    
    while ( dir.GetNext( szFile, sizeof( szFile ) ) )
    {
        // . and ..
        if ( szFile[0] == '.' || szFile[0] == '\0' ) continue;
        
        // Check file extension.
        len = strlen( szFile );
        dotpos = 0;
        
        for ( int i = 0; i < len; i++ )
        {
            if ( szFile[i] == '.' ) dotpos = i;
        }

        if ( !StrEqual( szFile[dotpos], ".rec", false ) ) continue;
        
        
        if ( ExplodeString( szFile, "_", bufs, sizeof( bufs ), sizeof( bufs[] ) ) < sizeof( bufs ) )
        {
            LogError( INF_CON_PRE..."Found a .rec file (%s) but it does not have all the name components!", szFile );
            continue;
        }
        
        
        runid = StringToInt( bufs[0] );
        int irun;
        
        irun = FindRunRecById( runid );
        if ( irun == -1 )
        {
            LogError( INF_CON_PRE..."Recording file '%s' is of run that does not exist! Creating new one... (Run id: %i)",
                szFile,
                runid );

            irun = CreateRunRec( runid );
        }
        
        Format( szFile, sizeof( szFile ), "%s/%s", szPath, szFile );
        

        
        ArrayList rec = null;
        
        if ( LoadRecording( szFile, rec, filerunid, mode, style, time, szName, sizeof( szName ) ) && rec != null )
        {
            if ( filerunid != runid )
            {
                LogError( INF_CON_PRE..."Recording file's run id does not match name's! (%s) | %i - %i",
                    szFile,
                    runid,
                    filerunid );
            }

            // Duplicate recording. That's no good...
            if ( GetRunRec( irun, mode, style ) != null )
            {
                LogError( INF_CON_PRE..."Found a duplicate recording! (%s)", szFile );

                delete rec;
                continue;
            }
            
            SetRunRec( irun, mode, style, rec );
            SetRunTime( irun, mode, style, time );
            SetRunName( irun, mode, style, szName );
            
#if defined DEBUG_LOADRECORDINGS
            PrintToServer( INF_DEBUG_PRE..."Added recording %x (%i, %i, %i)!", rec, runid, mode, style );
#endif
        
            ++numrecs;
        }
    }
    
    delete dir;
    
    PrintToServer( INF_CON_PRE..."Loaded %i recordings!", numrecs );
}

stock bool LoadRecording( const char[] szPath, ArrayList &rec, int &runid, int &mode, int &style, float &time, char[] szName, int namelen )
{
    File file = OpenFile( szPath, "rb" );
    
    if ( file == null )
    {
        LogError( INF_CON_PRE..."Couldn't open recording file for reading '%s'!", szPath );
        return false;
    }
    
    int temp;
    
    file.ReadInt32( temp );
    if ( temp != INF_MAGIC )
    {
#if defined DEBUG_LOADRECORDINGS
        PrintToServer( INF_DEBUG_PRE..."Invalid magic number %x!", temp );
#endif
        delete file;
        return false;
    }
    
    
    file.ReadInt32( temp );
    if ( temp != INF_RECFILE_CURVERSION )
    {
        LogError( INF_CON_PRE..."Recording file '%s' had wrong version '%x'!",
            szPath,
            temp );
        delete file;
        return false;
    }
    
    file.ReadInt32( temp );
    if ( temp != INF_CURHEADERSIZE )
    {
        LogError( INF_CON_PRE..."Recording file '%s' had invalid header size '%i'!",
            szPath,
            temp );
        delete file;
        return false;
    }
    
    
    float flTemp;
    
    file.ReadInt32( view_as<int>( flTemp ) );
    if ( flTemp != g_flTickrate )
    {
        int action = g_ConVar_IgnoreDifTickrate.IntValue;
        
        if ( action <= 1 )
        {
            LogError( INF_CON_PRE..."Found recording file '%s' with different tickrate! (Current: %.0f | File: %.0f)",
                szPath,
                g_flTickrate,
                flTemp );
        }
        
        if ( action == 0 )
        {
            delete file;
            return false;
        }
    }
    
    
    file.ReadInt32( view_as<int>( flTemp ) ); // time
    if ( flTemp <= INVALID_RUN_TIME )
    {
        LogError( INF_CON_PRE..."Found recording file '%s' with invalid time! (%.0f)",
            szPath,
            flTemp );
        
        delete file;
        return false;
    }
    
    time = flTemp;
    
    
    file.ReadInt32( runid ); // runid
    
    
    file.ReadInt32( temp ); // mode
    if ( !VALID_MODE( temp ) )
    {
        LogError( INF_CON_PRE..."Found recording file '%s' with invalid mode: %i!",
            szPath,
            temp );
        
        delete file;
        return false;
    }
    
    mode = temp;
    
    
    file.ReadInt32( temp ); // style
    if ( !VALID_STYLE( temp ) )
    {
        LogError( INF_CON_PRE..."Found recording file '%s' with invalid style: %i!",
            szPath,
            temp );
        
        delete file;
        return false;
    }
    
    style = temp;
    
    decl tempd[128];
    file.Read( tempd, MAX_RECFILE_MAPNAME_CELL, 4 );
    file.Read( tempd, MAX_RECFILE_PLYNAME_CELL, 4 );
    
    strcopy( szName, namelen, view_as<char>( tempd ) );
    
    int len;
    file.ReadInt32( len );
    
    if ( len < 1 )
    {
        LogError( INF_CON_PRE..."Found recording file '%s' with invalid frame data length: %i!",
            szPath,
            len );
        delete file;
        return false;
    }
    
    
    rec = new ArrayList( REC_SIZE );
    
    int data[REC_SIZE];
    for ( int i = 0; i < len; i++ )
    {
        if ( file.Read( data, REC_SIZE, 4 ) == -1 )
        {
            LogError( INF_CON_PRE..."Encountered a sudden end of file!" );
            
            delete file;
            return false;
        }
        

        FixAngles( view_as<float>( data[REC_ANG] ), view_as<float>( data[REC_ANG + 1] ) );
        
        rec.PushArray( data, REC_SIZE );
    }
    
    delete file;
    
    return true;
}

stock bool DeleteRecording( int runid, int mode, int style, const char[] szMap = "" )
{
    decl String:szPath[PLATFORM_MAX_PATH];
    FormatRecordingPath( szPath, sizeof( szPath ), runid, mode, style, szMap );
    
    
    if ( !FileExists( szPath ) )
    {
        LogError( INF_CON_PRE..."Recording file '%s' does not exist. Cannot remove!", szPath );
        return false;
    }
    
    
    return DeleteFile( szPath );
}

stock bool SaveRecording( int client, ArrayList rec, int runid, int mode, int style, float time )
{
    if ( rec == null || rec.Length < 1 )
    {
        LogError( INF_CON_PRE..."Can't save a recording file with no frames!" );
        return false;
    }
    
    
    decl String:szMap[64];
    GetCurrentMapSafe( szMap, sizeof( szMap ) );
    
    decl String:szPath[PLATFORM_MAX_PATH];
    FormatRecordingPath( szPath, sizeof( szPath ), runid, mode, style, szMap );

    
    
    File file = OpenFile( szPath, "wb" );
    if ( file == null )
    {
        LogError( INF_CON_PRE..."Couldn't open recording file for writing '%s'!", szPath );
        return false;
    }
    
    file.WriteInt32( INF_MAGIC );
    file.WriteInt32( INF_RECFILE_CURVERSION );
    file.WriteInt32( INF_CURHEADERSIZE );
    
    file.WriteInt32( view_as<int>( g_flTickrate ) );
    
    file.WriteInt32( view_as<int>( time ) );
    file.WriteInt32( runid );
    file.WriteInt32( mode );
    file.WriteInt32( style );
    
    
    
    decl mapname[MAX_RECFILE_MAPNAME_CELL];
    strcopy( view_as<char>( mapname ), MAX_RECFILE_MAPNAME, szMap );
    
    decl plyname[MAX_RECFILE_PLYNAME_CELL];
    GetClientName( client, view_as<char>( plyname ), MAX_RECFILE_PLYNAME );
    
    file.Write( mapname, sizeof( mapname ), 4 );
    file.Write( plyname, sizeof( plyname ), 4 );
    
    
    decl data[REC_SIZE];
    
    int len = rec.Length;
    file.WriteInt32( len );
    
    for ( int i = 0; i < len; i++ )
    {
        rec.GetArray( i, data );
        
        FixAngles( view_as<float>( data[REC_ANG] ), view_as<float>( data[REC_ANG + 1] ) );
        
        file.Write( data, sizeof( data ), 4 );
    }
    
    delete file;
    
    return true;
}