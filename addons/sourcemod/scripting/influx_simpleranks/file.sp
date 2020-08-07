stock void ReadRanks()
{
#if defined DEBUG
    PrintToServer( INF_DEBUG_PRE..."Reading ranks from file... (%s)", RANK_FILE_NAME );
#endif

    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "configs/"...RANK_FILE_NAME );

    KeyValues kv = new KeyValues( "Ranks" );
    kv.ImportFromFile( szPath );
    
    if ( !kv.GotoFirstSubKey() )
    {
        delete kv;
        return;
    }
    
    
    g_hRanks.Clear();
    
    
    decl String:szTemp[256];
    Rank_t rank;
    
    do
    {
        if ( !kv.GetSectionName( szTemp, sizeof( szTemp ) ) )
        {
            LogError( INF_CON_PRE..."Couldn't read rank name!" );
            continue;
        }
        
        if ( strlen( szTemp ) >= MAX_RANK_SIZE )
        {
            LogError( INF_CON_PRE..."Rank name length cannot exceed %i characters! (%s)", MAX_RANK_SIZE, szTemp );
            continue;
        }
        
        strcopy( rank.szRank, sizeof( Rank_t::szRank ), szTemp );
        
        
        int points = kv.GetNum( "points", -1 );
        
        if ( points < 0 )
        {
            LogError( INF_CON_PRE..."Invalid rank points %i! Must be above or equal to 0! (%s)", points, rank.szRank );
            continue;
        }
        
        
        rank.nPoints = points;
        rank.bUnlock = kv.GetNum( "unlock", 0 );
        
        kv.GetString( "flags", szTemp, sizeof( szTemp ), "" );
        
        rank.fAdminFlags = ReadFlagString( szTemp );
        
        
        g_hRanks.PushArray( rank );
    }
    while ( kv.GotoNextKey() );
    
    
    delete kv;
}

stock void ReadStyleModePoints()
{
    ReadPoints( g_hModePoints, "Modes", RANK_MODEPOINTFILE_NAME );
    ReadPoints( g_hStylePoints, "Styles", RANK_STYLEPOINTFILE_NAME );
}

stock void ReadPoints( ArrayList array, const char[] szKvName, const char[] szFileName )
{
    char szPath[PLATFORM_MAX_PATH];
    BuildPath( Path_SM, szPath, sizeof( szPath ), "configs/%s", szFileName );
    
    KeyValues kv = new KeyValues( szKvName );
    kv.ImportFromFile( szPath );
    
    if ( !kv.GotoFirstSubKey() )
    {
        delete kv;
        return;
    }
    
    
    array.Clear();
    
    
    decl String:szTemp[64];
    ModeNStyleReward_t reward;
    
    do
    {
        if ( !kv.GetSectionName( szTemp, sizeof( szTemp ) ) )
        {
            LogError( INF_CON_PRE..."Couldn't read multiplier target name!" );
            continue;
        }
        
        
        reward.iId = -1;
        reward.szSafeName[0] = 0;
        
        if ( IsCharNumeric( szTemp[0] ) )
        {
            reward.iId = StringToInt( szTemp );
        }
        else
        {
            strcopy( reward.szSafeName, sizeof( ModeNStyleReward_t::szSafeName ), szTemp );
        }
        
        
        reward.nPoints = kv.GetNum( "points", 0 );
        
#if defined DEBUG
        PrintToServer( INF_DEBUG_PRE..."%s reward: %i", szTemp, reward.nPoints );
#endif
        
        array.PushArray( reward );
    }
    while ( kv.GotoNextKey() );
    
    
    delete kv;
}