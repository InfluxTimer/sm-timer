stock void ReadGameConfig()
{
    // Check if our config file exists. For some reason LoadGameConfigFile crashes the server if no file exists.
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "gamedata/"...GAME_CONFIG_FILE...".txt" );
    
    if ( !FileExists( szPath ) )
    {
        LogError( INF_CON_PRE..."Missing gamedata/"...GAME_CONFIG_FILE...".txt file! Please download the file." );
        return;
    }
    
    
    Handle config = LoadGameConfigFile( GAME_CONFIG_FILE );

    if ( config == null )
    {
        LogError( INF_CON_PRE..."Invalid gamedata file @ gamedata/"...GAME_CONFIG_FILE...".txt!!" );
        return;
    }
    
    
#define F_MAXSPD      "GetPlayerMaxSpeed"

    StartPrepSDKCall( SDKCall_Player );
    
    if ( PrepSDKCall_SetFromConf( config, SDKConf_Virtual, F_MAXSPD ) )
    {
        PrepSDKCall_SetReturnInfo( SDKType_Float, SDKPass_Plain );
        g_hFunc_GetPlayerMaxSpeed = EndPrepSDKCall();
        
        if ( g_hFunc_GetPlayerMaxSpeed == null )
        {
            LogError( INF_CON_PRE..."Couldn't finalize SDKCall for "...F_MAXSPD..."!" );
        }
    }
    else
    {
        LogError( INF_CON_PRE..."Couldn't find "...F_MAXSPD..." offset from gamedata/"...GAME_CONFIG_FILE...".txt!" );
    }

    
    delete config;
}

stock void ReadMapFile()
{
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), INFLUX_RUNDIR );
    
    if ( !DirExistsEx( szPath ) ) return;
    
    
    Format( szPath, sizeof( szPath ), "%s/%s.ini", szPath, g_szCurrentMap );
    
    
    KeyValues kv = new KeyValues( "Runs" );
    kv.ImportFromFile( szPath );
    
    if ( !kv.GotoFirstSubKey() )
    {
        delete kv;
        return;
    }
    
    
    int data[RUN_SIZE];
    
    float telepos[3];
    float teleyaw;
    int runid;
    
    do
    {
        runid = kv.GetNum( "id", -1 );
        if ( !VALID_RUN( runid ) )
        {
            LogError( INF_CON_PRE..."Found invalid run id %i! (0-%i)", runid, MAX_RUNS );
            continue;
        }
        
        if ( FindRunById( runid ) != -1 )
        {
            LogError( INF_CON_PRE..."Found duplicate run id %i!", runid );
            continue;
        }
        
        if ( !kv.GetSectionName( view_as<char>( data[RUN_NAME] ), MAX_RUN_NAME ) )
        {
            LogError( INF_CON_PRE..."Couldn't read run name!" );
            continue;
        }
        
        
        data[RUN_ID] = runid;
        
        
        data[RUN_RESFLAGS] = kv.GetNum( "resflags", 0 );
        data[RUN_MODEFLAGS] = kv.GetNum( "modeflags", 0 );
        
        
        kv.GetVector( "telepos", telepos, ORIGIN_VECTOR );
        teleyaw = kv.GetFloat( "teleyaw", 0.0 );
        
        
        CopyArray( telepos, data[RUN_TELEPOS], 3 );
        data[RUN_TELEYAW] = view_as<int>( teleyaw );
        
        
        Call_StartForward( g_hForward_OnRunLoad );
        Call_PushCell( runid );
        Call_PushCell( view_as<int>( kv ) );
        Call_Finish();
        
        
        g_hRuns.PushArray( data );
    }
    while ( kv.GotoNextKey() );
    
    delete kv;
}

stock int WriteMapFile()
{
    // Nothing to write.
    int len = g_hRuns.Length;
    if ( len < 1 ) return 0;
    
    
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "influxruns/%s.ini", g_szCurrentMap );
    
    
    KeyValues kv = new KeyValues( "Runs" );
    
    
    int num = 0;
    
    
    decl data[RUN_SIZE];
    float vec[3];
    
    
    for ( int i = 0; i < len; i++ )
    {
        g_hRuns.GetArray( i, data );
        
        CopyArray( data[RUN_TELEPOS], vec, 3 );
        
        
        kv.JumpToKey( view_as<char>( data[RUN_NAME] ), true );
        
        kv.SetNum( "id", data[RUN_ID] );
        
        
        kv.SetNum( "resflags", data[RUN_RESFLAGS] );
        kv.SetNum( "modeflags", data[RUN_MODEFLAGS] );
        
        
        kv.SetVector( "telepos", vec );
        kv.SetFloat( "teleyaw", view_as<float>( data[RUN_TELEYAW] ) );
        
        
        Call_StartForward( g_hForward_OnRunSave );
        Call_PushCell( data[RUN_ID] );
        Call_PushCell( view_as<int>( kv ) );
        Call_Finish();
        
        kv.GoBack();
        
        
        ++num;
    }
    
    
    kv.Rewind();
    kv.ExportToFile( szPath );
    
    delete kv;
    
    return num;
}