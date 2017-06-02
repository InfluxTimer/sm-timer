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
        
        
        Call_StartForward( g_hForward_OnRunLoad );
        Call_PushCell( runid );
        Call_PushCell( view_as<int>( kv ) );
        Call_Finish();
        
        
        int irun = g_hRuns.PushArray( data );
        
        
        SetRunTelePos( irun, telepos, true );
        SetRunTeleYaw( irun, teleyaw );
    }
    while ( kv.GotoNextKey() );
    
    delete kv;
}

stock int WriteMapFile()
{
    // Nothing to write.
    int len = g_hRuns.Length;
    if ( len < 1 ) return 0;
    
    
    // TODO: Change to .cfg instead of .ini?
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
    
    if ( !kv.ExportToFile( szPath ) )
    {
        LogError( INF_CON_PRE..."Can't save run file '%s'!!", szPath );
    }
    
    
    delete kv;
    
    return num;
}

stock void ReadModeOverrides()
{
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "configs/influx_mode_overrides.cfg" );
    
    KeyValues kv = new KeyValues( "Modes" );
    kv.ImportFromFile( szPath );
    
    if ( !kv.GotoFirstSubKey() )
    {
        delete kv;
        return;
    }
    
    
    int data[MOVR_SIZE];
    
    do
    {
        if ( !kv.GetSectionName( view_as<char>( data[MOVR_NAME_ID] ), MAX_MODE_NAME ) )
        {
            LogError( INF_CON_PRE..."Couldn't read mode override name!" );
            continue;
        }
        
        
        if ( IsCharNumeric( view_as<char>( data[MOVR_NAME_ID] ) ) )
        {
            data[MOVR_ID] = StringToInt( view_as<char>( data[MOVR_NAME_ID] ) );
            data[MOVR_NAME_ID] = 0;
            
            if ( !VALID_MODE( data[MOVR_ID] ) ) continue;
        }
        else
        {
            data[MOVR_ID] = MODE_INVALID;
        }
        
        if ( FindModeOver( data[MOVR_ID], view_as<char>( data[MOVR_NAME_ID] ) ) != -1 )
        {
            LogError( INF_CON_PRE..."Mode override already exists for '%s' (%i)!", data[MOVR_NAME_ID], data[MOVR_ID] );
            continue;
        }
        
        
        data[MOVR_ORDER] = kv.GetNum( "order", 0 );
        kv.GetString( "name_override", view_as<char>( data[MOVR_OVRNAME] ), MAX_MODE_NAME, "" );
        
        
        g_hModeOvers.PushArray( data );
    }
    while ( kv.GotoNextKey() );
    
    delete kv;
}

stock void ReadStyleOverrides()
{
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "configs/influx_style_overrides.cfg" );
    
    KeyValues kv = new KeyValues( "Styles" );
    kv.ImportFromFile( szPath );
    
    if ( !kv.GotoFirstSubKey() )
    {
        delete kv;
        return;
    }
    
    
    int data[SOVR_SIZE];
    
    do
    {
        if ( !kv.GetSectionName( view_as<char>( data[SOVR_NAME_ID] ), MAX_STYLE_NAME ) )
        {
            LogError( INF_CON_PRE..."Couldn't read style override name!" );
            continue;
        }
        
        
        if ( IsCharNumeric( view_as<char>( data[SOVR_NAME_ID] ) ) )
        {
            data[SOVR_ID] = StringToInt( view_as<char>( data[SOVR_NAME_ID] ) );
            data[SOVR_NAME_ID] = 0;
            
            if ( !VALID_STYLE( data[SOVR_ID] ) ) continue;
        }
        else
        {
            data[SOVR_ID] = STYLE_INVALID;
        }
        
        if ( FindStyleOver( data[SOVR_ID], view_as<char>( data[SOVR_NAME_ID] ) ) != -1 )
        {
            LogError( INF_CON_PRE..."Style override already exists for '%s' (%i)!", data[SOVR_NAME_ID], data[SOVR_ID] );
            continue;
        }
        
        
        data[SOVR_ORDER] = kv.GetNum( "order", 0 );
        kv.GetString( "name_override", view_as<char>( data[SOVR_OVRNAME] ), MAX_STYLE_NAME, "" );
        
        
        g_hStyleOvers.PushArray( data );
    }
    while ( kv.GotoNextKey() );
    
    delete kv;
}