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

stock bool LoadSharedModeNStyleOverride( KeyValues kv, ModeNStyleOverride_t ovr, int invalid_id )
{
    if ( !kv.GetSectionName( ovr.szSafeName, sizeof( ModeNStyleOverride_t::szSafeName ) ) )
    {
        LogError( INF_CON_PRE..."Couldn't read override name!" );
        return false;
    }
    
    
    if ( IsCharNumeric( ovr.szSafeName[0] ) )
    {
        ovr.iId = StringToInt( ovr.szSafeName );
        ovr.szSafeName[0] = 0;
    }
    else
    {
        ovr.iId = invalid_id;
    }
    
    
    ovr.nOrder = kv.GetNum( "order", 0 );
    kv.GetString( "name_override", ovr.szOverrideName, sizeof( ModeNStyleOverride_t::szOverrideName ), "" );
    kv.GetString( "shortname_override", ovr.szOverrideShortName, sizeof( ModeNStyleOverride_t::szOverrideShortName ), "" );
    
    
    char szTemp[32];
    kv.GetString( "flags", szTemp, sizeof( szTemp ), "" );
    
    if ( szTemp[0] != 0 )
    {
        ovr.bUseAdminFlags = true;
        ovr.fAdminFlags = ReadFlagString( szTemp );
    }
    else
    {
        ovr.bUseAdminFlags = false;
        ovr.fAdminFlags = 0;
    }

    return true;
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
    
    ModeNStyleOverride_t ovr;
    
    do
    {
        if ( !LoadSharedModeNStyleOverride( kv, ovr, MODE_INVALID ) )
        {
            continue;
        }

        if ( FindModeOver( ovr.iId, ovr.szSafeName ) != -1 )
        {
            LogError( INF_CON_PRE..."Mode override already exists for '%s' (%i)!", ovr.szSafeName, ovr.iId );
            continue;
        }
        
        g_hModeOvers.PushArray( ovr );
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
    
    ModeNStyleOverride_t ovr;
    
    do
    {
        if ( !LoadSharedModeNStyleOverride( kv, ovr, STYLE_INVALID ) )
        {
            continue;
        }

        if ( FindStyleOver( ovr.iId, ovr.szSafeName ) != -1 )
        {
            LogError( INF_CON_PRE..."Style override already exists for '%s' (%i)!", ovr.szSafeName, ovr.iId );
            continue;
        }
        
        
        g_hStyleOvers.PushArray( ovr );
    }
    while ( kv.GotoNextKey() );
    
    delete kv;
}