public int Native_GetRunsArray( Handle hPlugin, int nParms ) { return view_as<int>( g_hRuns ); }

public int Native_GetModesArray( Handle hPlugin, int nParms ) { return view_as<int>( g_hModes ); }

public int Native_GetStylesArray( Handle hPlugin, int nParms ) { return view_as<int>( g_hStyles ); }

public int Native_GetDB( Handle hPlugin, int nParms ) { return view_as<int>( g_hDB ); }

public int Native_IsMySQL( Handle hPlugin, int nParms ) { return g_bIsMySQL; }

public int Native_GetPostRunLoadForward( Handle hPlugin, int nParms ) { return view_as<int>( g_hForward_OnPostRunLoad ); }

public int Native_GetCurrentMapId( Handle hPlugin, int nParms ) { return g_iCurMapId; }

public int Native_HasLoadedRuns( Handle hPlugin, int nParms ) { return g_bRunsLoaded; }

public int Native_HasLoadedBestTimes( Handle hPlugin, int nParms ) { return g_bBestTimesCached; }

public int Native_FindRunById( Handle hPlugin, int nParms ) { return FindRunById( GetNativeCell( 1 ) ); }

public int Native_InvalidateClientRun( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    InvalidateClientRun( client );
    
    return 1;
}

public int Native_GetClientRunId( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_iRunId[client];
}

public int Native_SetClientRun( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return SetClientRun( client, GetNativeCell( 2 ) );
}

public int Native_GetClientMode( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_iModeId[client];
}

public int Native_SetClientMode( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return SetClientMode( client, GetNativeCell( 2 ) );
}

public int Native_GetClientStyle( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_iStyleId[client];
}

public int Native_SetClientStyle( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return SetClientStyle( client, GetNativeCell( 2 ) );
}

public int Native_GetRunName( Handle hPlugin, int nParms )
{
    int len = GetNativeCell( 3 );
    char[] sz = new char[len];
    
    GetRunName( GetNativeCell( 1 ), sz, len );
    
    SetNativeString( 2, sz, len, true );
    
    return 1;
}

public int Native_GetModeName( Handle hPlugin, int nParms )
{
    int mode = GetNativeCell( 1 );
    int len = GetNativeCell( 3 );
    
    decl String:szMode[MAX_MODE_NAME];
    
    if ( GetNativeCell( 4 ) && !ShouldModeDisplay( mode ) )
    {
        SetNativeString( 2, "", len, true );
        return 1;
    }
    
    
    GetModeName( mode, szMode, sizeof( szMode ) );
    
    SetNativeString( 2, szMode, len, true );
    
    return 1;
}

public int Native_GetModeShortName( Handle hPlugin, int nParms )
{
    int mode = GetNativeCell( 1 );
    int len = GetNativeCell( 3 );
    
    decl String:szMode[MAX_MODE_SHORTNAME];
    
    if ( GetNativeCell( 4 ) && !ShouldModeDisplay( mode ) )
    {
        SetNativeString( 2, "", len, true );
        return 1;
    }
    
    
    GetModeShortName( mode, szMode, sizeof( szMode ) );
    
    SetNativeString( 2, szMode, len, true );
    
    return 1;
}

public int Native_GetModeSafeName( Handle hPlugin, int nParms )
{
    decl String:szSafe[MAX_SAFENAME];
    
    GetModeSafeName( GetNativeCell( 1 ), szSafe, sizeof( szSafe ) );
    
    SetNativeString( 2, szSafe, GetNativeCell( 3 ), true );
    
    return 1;
}

public int Native_GetStyleName( Handle hPlugin, int nParms )
{
    int style = GetNativeCell( 1 );
    int len = GetNativeCell( 3 );
    
    decl String:szStyle[MAX_STYLE_NAME];
    
    if ( GetNativeCell( 4 ) && !ShouldStyleDisplay( style ) )
    {
        SetNativeString( 2, "", len, true );
        return 1;
    }
    
    
    GetStyleName( style, szStyle, sizeof( szStyle ) );
    
    SetNativeString( 2, szStyle, len, true );
    
    return 1;
}

public int Native_GetStyleShortName( Handle hPlugin, int nParms )
{
    int style = GetNativeCell( 1 );
    int len = GetNativeCell( 3 );
    
    decl String:szStyle[MAX_STYLE_SHORTNAME];
    
    if ( GetNativeCell( 4 ) && !ShouldStyleDisplay( style ) )
    {
        SetNativeString( 2, "", len, true );
        return 1;
    }
    
    
    GetStyleShortName( style, szStyle, sizeof( szStyle ) );
    
    SetNativeString( 2, szStyle, len, true );
    
    return 1;
}

public int Native_GetStyleSafeName( Handle hPlugin, int nParms )
{
    decl String:szSafe[MAX_SAFENAME];
    
    GetStyleSafeName( GetNativeCell( 1 ), szSafe, sizeof( szSafe ) );
    
    SetNativeString( 2, szSafe, GetNativeCell( 3 ), true );
    
    return 1;
}

public int Native_ShouldModeDisplay( Handle hPlugin, int nParms )
{
    return ShouldModeDisplay( GetNativeCell( 1 ) );
}

public int Native_ShouldStyleDisplay( Handle hPlugin, int nParms )
{
    return ShouldStyleDisplay( GetNativeCell( 1 ) );
}

public int Native_IsClientCached( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_bCachedTimes[client];
}

public int Native_GetClientId( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return g_iClientId[client];
}

public int Native_GetClientCurrentBestTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_cache_flBestTime[client] );
}

public int Native_GetClientCurrentBestName( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    int len = GetNativeCell( 3 );
    
    SetNativeString( 2, g_cache_szBestName[client], len, true );
    
    return 1;
}

public int Native_AddRun( Handle hPlugin, int nParms )
{
    char szRun[MAX_RUN_NAME];
    GetNativeString( 2, szRun, sizeof( szRun ) );
    
    float pos[3];
    GetNativeArray( 3, pos, 3 );
    
    return AddRun( GetNativeCell( 1 ), szRun, pos, GetNativeCell( 4 ), 0, 0, GetNativeCell( 5 ) ? true : false, true );
}

public int Native_AddMode( Handle hPlugin, int nParms )
{
    char szName[MAX_MODE_NAME];
    GetNativeString( 2, szName, sizeof( szName ) );
    
    char szShortName[MAX_MODE_SHORTNAME];
    GetNativeString( 3, szShortName, sizeof( szShortName ) );
    
    char szSafeName[MAX_SAFENAME];
    GetNativeString( 4, szSafeName, sizeof( szSafeName ) );
    
    return AddMode( GetNativeCell( 1 ), szName, szShortName, szSafeName, GetNativeCell( 5 ) );
}

public int Native_RemoveMode( Handle hPlugin, int nParms )
{
    return RemoveMode( GetNativeCell( 1 ) );
}

public int Native_AddStyle( Handle hPlugin, int nParms )
{
    char szName[MAX_STYLE_NAME];
    GetNativeString( 2, szName, sizeof( szName ) );
    
    char szShortName[MAX_STYLE_SHORTNAME];
    GetNativeString( 3, szShortName, sizeof( szShortName ) );
    
    char szSafeName[MAX_SAFENAME];
    GetNativeString( 4, szSafeName, sizeof( szSafeName ) );
    
    return AddStyle( GetNativeCell( 1 ), szName, szShortName, szSafeName, GetNativeCell( 5 ) );
}

public int Native_RemoveStyle( Handle hPlugin, int nParms )
{
    return RemoveStyle( GetNativeCell( 1 ) );
}

public int Native_AddResultFlag( Handle hPlugin, int nParms )
{
    char szName[MAX_RUNRES_NAME];
    GetNativeString( 1, szName, sizeof( szName ) );
    
    return AddResultFlag( szName, GetNativeCell( 2 ) );
}

public int Native_ResetTimer( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    if ( !IS_ENT_PLAYER( client ) ) return;
    
    if ( !IsClientInGame( client ) ) return;
    
    if ( IsFakeClient( client ) ) return;
    
    
    int runid = GetNativeCell( 2 );
    
#if defined DEBUG_TIMER
    PrintToServer( INF_DEBUG_PRE..."OnReset(%i, %i)", client, runid );
#endif

    int irun = FindRunById( runid );
    if ( irun == -1 ) return;
    
    // Always stop them from running.
    g_iRunState[client] = STATE_START;
    
    
    if ( g_iRunId[client] != runid )
    {
        // Make sure we don't spam the chat when the player first connects.
        bool printtochat = ( GetEngineTime() > (g_flJoinTime[client] + 2.0) );
        
        SetClientRun( client, runid, false, printtochat );
    }
    
    
    ChangeToWantedStyles( client );
    
    
    Call_StartForward( g_hForward_OnTimerResetPost );
    Call_PushCell( client );
    Call_Finish();
}

public int Native_StartTimer( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    if ( !IS_ENT_PLAYER( client ) ) return;
    
    if ( !IsClientInGame( client ) ) return;
    
    if ( IsFakeClient( client ) ) return;
    
    // We need to be in the start zone to start the timer.
    // This stops people from activating the timer when teleporting out of the start zone. (not leaving it legit)
    // For other means of activating the timer (eg kz button), I'll have to figure something out.
    if ( g_iRunState[client] != STATE_START ) return;
    
    
    
    int runid = GetNativeCell( 2 );
    
#if defined DEBUG_TIMER
    PrintToServer( INF_DEBUG_PRE..."OnStart(%i, %i)", client, runid );
#endif
    
    int irun = FindRunById( runid );
    if ( irun == -1 ) return;
    
    // We must be reset first!
    if ( g_iRunId[client] != runid ) return;
    
    
    static char errormsg[192];
    errormsg[0] = '\0';
    
    Action res;
    
    Call_StartForward( g_hForward_OnTimerStart );
    Call_PushCell( client );
    Call_PushCell( runid );
    Call_PushStringEx( errormsg, sizeof( errormsg ), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK );
    Call_PushCell( sizeof( errormsg ) );
    int error = Call_Finish( res );
    
    if ( error != SP_ERROR_NONE )
    {
        LogError( INF_CON_PRE..."Error occured when finishing Influx_OnTimerStart forward!" );
    }
    
    if ( res != Plugin_Continue )
    {
        if ( errormsg[0] == '\0' )
        {
            strcopy( errormsg, sizeof( errormsg ), "You can't start this run!" );
        }
        
        Influx_PrintToChat( _, client, "%s", errormsg );
        
        // Reset the run so the hud is updated.
        g_iRunState[client] = STATE_NONE;
        
        return;
    }
    
    
#if defined DEBUG_TIMING
    PrintToServer( INF_DEBUG_PRE..."Starting timer on tick %i", GetGameTickCount() );
#endif
    // OnGameFrame isn't called for this frame. Start incrementing here.
    g_flRunTime[client] = GetGameFrameTime();
    
    g_iRunState[client] = STATE_RUNNING;
    
    
    Call_StartForward( g_hForward_OnTimerStartPost );
    Call_PushCell( client );
    Call_PushCell( runid );
    Call_Finish();
}

public int Native_FinishTimer( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    if ( !IS_ENT_PLAYER( client ) ) return;
    
    if ( !IsClientInGame( client ) ) return;
    
    if ( IsFakeClient( client ) ) return;
    
    if ( g_iRunState[client] != STATE_RUNNING ) return;
    
    if ( g_flRunTime[client] <= 0.0 ) return;

    
    int runid = GetNativeCell( 2 );
    
#if defined DEBUG_TIMER
    PrintToServer( INF_DEBUG_PRE..."OnFinish(%i, %i)", client, runid );
#endif
    
    if ( runid <= 0 ) return;
    
    if ( runid != g_iRunId[client] ) return;
    
    float time = g_flRunTime[client];
    if ( time <= INVALID_RUN_TIME ) return;
    
    
    
    if ( !IsProperlyCached( client ) )
    {
        LogError( INF_CON_PRE..."Attempted to finish a run but client's and/or run's times haven't been cached yet! Check for SQL errors." );
        return;
    }
    
    
    int modeid = g_iModeId[client];
    int styleid = g_iStyleId[client];
    
    
    int irun = FindRunById( runid );
    if ( irun == -1 ) return;
    
    int imode = FindModeById( modeid );
    if ( imode == -1 )
    {
        LogError( INF_CON_PRE..."Client '%N' has no mode! Cannot finish timer.", client );
        return;
    }
    
    int istyle = FindStyleById( styleid );
    if ( istyle == -1 )
    {
        LogError( INF_CON_PRE..."Client '%N' has no style! Cannot finish timer.", client );
        return;
    }
    
    if ( !IsClientModeValidForRun( client, imode, irun, true ) )
    {
        return;
    }
    
    
    float prev_pb = GetClientRunTime( irun, client, modeid, styleid );
    bool bIsNewOwnRec = ( prev_pb <= INVALID_RUN_TIME );
    bool bIsNewPB = ( !bIsNewOwnRec && time < prev_pb );
    
    
    float prev_best = GetRunBestTime( irun, modeid, styleid );
    bool bIsFirst = ( bIsNewOwnRec && prev_best <= INVALID_RUN_TIME );
    bool bNewBest = ( time < prev_best );
    
    
    int resultflags =   ( bIsFirst      ? RES_TIME_FIRSTREC : 0 ) |
                        ( bNewBest      ? RES_TIME_ISBEST : 0 ) |
                        ( bIsNewOwnRec  ? RES_TIME_FIRSTOWNREC : 0 ) |
                        ( bIsNewPB      ? RES_TIME_PB : 0 );
    
    
    // Add run result flags.
    resultflags |= g_hRuns.Get( irun, RUN_RESFLAGS );
    
    
    decl String:errormsg[256];
    errormsg[0] = '\0';
    
    Action res;
    
    Call_StartForward( g_hForward_OnTimerFinish );
    Call_PushCell( client );
    Call_PushCell( runid );
    Call_PushCell( modeid );
    Call_PushCell( styleid );
    Call_PushCell( time );
    Call_PushCell( resultflags );
    Call_PushStringEx( errormsg, sizeof( errormsg ), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK );
    Call_PushCell( sizeof( errormsg ) );
    int error = Call_Finish( res );
    
    if ( error != SP_ERROR_NONE )
    {
        LogError( INF_CON_PRE..."Error occured when finishing Influx_OnTimerFinish forward!" );
    }
    
    if ( res != Plugin_Continue )
    {
        if ( errormsg[0] == '\0' )
        {
            strcopy( errormsg, sizeof( errormsg ), "You can't finish this run!" );
        }
        
        Influx_PrintToChat( _, client, "%s", errormsg );
        
        return;
    }
    
    
    g_iRunState[client] = STATE_FINISHED;
    
    
    g_flFinishedTime[client] = time;
    
    // Cache best finish time to display on hud.
    g_flFinishBest[client] = prev_best;
    
    
    if ( bIsNewOwnRec || bIsNewPB )
    {
        if ( !(resultflags & RES_TIME_DONTSAVE) )
        {
            DB_InsertRecord( client, g_iClientId[client], runid, modeid, styleid, time );
        }
        
        SetClientRunTime( irun, client, modeid, styleid, time );
    }
    
    
    decl String:szName[MAX_NAME_LENGTH];
    GetClientName( client, szName, sizeof( szName ) );
    
    if ( bNewBest || bIsFirst )
    {
        SetRunBestTime( irun, modeid, styleid, time, g_iClientId[client] );
        SetRunBestName( irun, modeid, styleid, szName );
    }
    
    UpdateAllClientsCached( runid, modeid, styleid );
    
    
    
#if defined DEBUG
    char szForm[10];
    Inf_FormatSeconds( time, szForm, sizeof( szForm ) );
    
    PrintToServer( INF_DEBUG_PRE..."%s finished with time %s (%i, %i) (UID: %i) %s%s%s%s",
        szName,
        szForm,
        g_iModeId[client],
        g_iStyleId[client],
        g_iClientId[client],
        bIsFirst ? " (FIRST REC)" : "",
        bNewBest ? " (WR)" : "",
        bIsNewPB ? " (PB)" : "",
        bIsNewOwnRec ? " (NEW REC)" : "" );
#endif
    
    
    Call_StartForward( g_hForward_OnTimerFinishPost );
    Call_PushCell( client );
    Call_PushCell( runid );
    Call_PushCell( modeid );
    Call_PushCell( styleid );
    Call_PushCell( time );
    Call_PushCell( prev_pb );
    Call_PushCell( prev_best );
    Call_PushCell( resultflags );
    Call_Finish();
    
    
    // Update name.
    DB_UpdateClient( client );
}

public int Native_TeleportToStart( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    if ( !TeleClientToStart_Safe( client, g_iRunId[client] ) && GetNativeCell( 2 ) )
    {
        g_iRunState[client] = STATE_NONE;
    }
    
    return 1;
}

public int Native_GetClientState( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_iRunState[client] );
}

public int Native_SetClientState( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    g_iRunState[client] = view_as<RunState_t>( GetNativeCell( 2 ) );
    
    return 1;
}

public int Native_GetClientTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );

    if ( g_flRunTime[client] <= 0.0 )
        return view_as<int>( INVALID_RUN_TIME );
    
    return view_as<int>( g_flRunTime[client] );
}

public int Native_SetClientTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    float time = GetNativeCell( 2 );

    g_flRunTime[client] = time;

    return 1;
}

public int Native_GetClientFinishedTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flFinishedTime[client] );
}

public int Native_GetClientFinishedBestTime( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( g_flFinishBest[client] );
}

public int Native_GetClientPB( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( GetClientPB( client, GetNativeCell( 2 ), GetNativeCell( 3 ), GetNativeCell( 4 ) ) );
}

public int Native_GetClientCurrentPB( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    return view_as<int>( GetClientPB( client, g_iRunId[client], g_iModeId[client], g_iStyleId[client] ) );
}

public int Native_GetRunBestTime( Handle hPlugin, int nParms )
{
    int irun = FindRunById( GetNativeCell( 1 ) );
    if ( irun == -1 ) return 0;
    
    int mode = GetNativeCell( 2 );
    if ( !VALID_MODE( mode ) ) return 0;
    
    int style = GetNativeCell( 3 );
    if ( !VALID_STYLE( style ) ) return 0;
    
    if ( nParms == 4 )
    {
        SetNativeCellRef( 4, GetRunBestTimeId( irun, mode, style ) );
    }
    
    return view_as<int>( GetRunBestTime( irun, mode, style ) );
}

public int Native_SearchType( Handle hPlugin, int nParms )
{
    decl String:szType[32];
    GetNativeString( 1, szType, sizeof( szType ) );
    
    Search_t search = SEARCH_INVALID;
    int value = 0;
    
    SearchType( szType, search, value );
    
    SetNativeCellRef( 2, value );
    
    return view_as<int>( search );
}

public int Native_SearchTelePos( Handle hPlugin, int nParms )
{
    decl Float:pos[3];
    GetNativeArray( 1, pos, sizeof( pos ) );
    
    
    float yaw = GetNativeCellRef( 2 );
    
    bool ret = SearchTelePos( pos, yaw, GetNativeCell( 3 ), GetNativeCell( 4 ) );
    
    if ( ret )
    {
        SetNativeArray( 1, pos, sizeof( pos ) );
        SetNativeCellRef( 2, yaw );
    }
    
    return ret;
}

public int Native_IsValidMapName( Handle hPlugin, int nParms )
{
    decl String:szMap[128];
    GetNativeString( 1, szMap, sizeof( szMap ) );
    
    
    return IsValidMapName( szMap );
}