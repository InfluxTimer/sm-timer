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

stock void ReadRunFile()
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
    
    
    
    
    do
    {
        LoadRunFromKv( kv );
    }
    while ( kv.GotoNextKey() );
    
    delete kv;
}

stock int WriteRunFile( ArrayList kvs )
{
    // TODO: Change to .cfg instead of .ini?
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), INFLUX_RUNDIR..."/%s.ini", g_szCurrentMap );
    
    
    KeyValues kv = new KeyValues( "Runs" );
    
    
    char szRunName[64];
    
    int len = kvs.Length;
    
    for ( int i = 0; i < len; i++ )
    {
        KeyValues runkv = view_as<KeyValues>( kvs.Get( i, 0 ) );
        
        runkv.GetSectionName( szRunName, sizeof( szRunName ) );
        kv.JumpToKey( szRunName, true );
        
        kv.Import( runkv );
        kv.GoBack();
    }
    
    
    kv.Rewind();
    
    if ( !kv.ExportToFile( szPath ) )
    {
        LogError( INF_CON_PRE..."Can't save run file '%s'!!", szPath );
    }
    
    
    delete kv;
    
    return len;
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
    
    
    g_hModeOvers.Clear();
    
    int data[MOVR_SIZE];
    
    decl String:szTemp[32];
    
    do
    {
        if ( !kv.GetSectionName( view_as<char>( data[MOVR_NAME_ID] ), MAX_SAFENAME ) )
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
        kv.GetString( "shortname_override", view_as<char>( data[MOVR_OVRSHORTNAME] ), MAX_MODE_SHORTNAME, "" );
        
        
        kv.GetString( "flags", szTemp, sizeof( szTemp ), "" );
        
        if ( szTemp[0] != 0 )
        {
            data[MOVR_USEADMFLAGS] = 1;
            data[MOVR_ADMFLAGS] = ReadFlagString( szTemp );
        }
        else
        {
            data[MOVR_USEADMFLAGS] = 0;
        }
        
        
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
    
    
    g_hStyleOvers.Clear();
    
    int data[SOVR_SIZE];
    
    decl String:szTemp[32];
    
    do
    {
        if ( !kv.GetSectionName( view_as<char>( data[SOVR_NAME_ID] ), MAX_SAFENAME ) )
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
        kv.GetString( "shortname_override", view_as<char>( data[SOVR_OVRSHORTNAME] ), MAX_STYLE_SHORTNAME, "" );
        
        
        kv.GetString( "flags", szTemp, sizeof( szTemp ), "" );
        
        if ( szTemp[0] != 0 )
        {
            data[SOVR_USEADMFLAGS] = 1;
            data[SOVR_ADMFLAGS] = ReadFlagString( szTemp );
        }
        else
        {
            data[SOVR_USEADMFLAGS] = 0;
        }
        
        
        g_hStyleOvers.PushArray( data );
    }
    while ( kv.GotoNextKey() );
    
    delete kv;
}