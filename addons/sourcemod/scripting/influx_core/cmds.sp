public Action Cmd_Empty( int client, int args ) { return Plugin_Handled; }

public Action Cmd_UpdateDB( int client, int args )
{
    if ( !client )
    {
        DB_Update( g_iCurDBVersion );
    }
    
    return Plugin_Handled;
}

public Action Cmd_ReloadOverrides( int client, int args )
{
    ReadModeOverrides();
    ReadStyleOverrides();
    
    UpdateModeOverrides();
    UpdateStyleOverrides();
    
    if ( client )
    {
        Influx_PrintToChat( _, client, "Reloaded mode/style overrides." );
    }
    else
    {
        PrintToServer( INF_CON_PRE..."Reloaded mode/style overrides." );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Admin_SetTelePos( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserModifyRun( client ) ) return Plugin_Handled;
    
    
    int runid = -1;
    if ( args )
    {
        char szArg[8];
        GetCmdArgString( szArg, sizeof( szArg ) );
        
        runid = StringToInt( szArg );
    }
    else
    {
        runid = g_iRunId[client];
    }
    
    int irun = FindRunById( runid );
    if ( irun != -1 )
    {
        float vec[3], ang[3];
        
        GetClientAbsOrigin( client, vec );
        vec[2] += 2.0;
        
        for ( int i = 0; i < 3; i++ ) vec[i] = float( RoundFloat( vec[i] ) );
        
        
        GetClientEyeAngles( client, ang );
        
        float yaw = Inf_SnapTo( ang[1] );
        
        bool success = SetRunTelePos( irun, vec );
        
        if ( success )
        {
            SetRunTeleYaw( irun, yaw );
            
            char szRun[MAX_RUN_NAME];
            GetRunNameByIndex( irun, szRun, sizeof( szRun ) );
            
            Influx_PrintToChat( _, client, "Updated run's {MAINCLR1}%s{CHATCLR} teleport position and angle!", szRun );
        }
        else
        {
            Influx_PrintToChat( _, client, "That position isn't a valid teleport destination!" );
        }
    }
    else
    {
        Influx_PrintToChat( _, client, "%T", "INF_RUNIDNOTEXIST", client, runid );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Admin_SaveRuns( int client, int args )
{
    if ( !CanUserModifyRun( client ) ) return Plugin_Handled;
    
    
    int num = SaveRuns();
    
    Inf_ReplyToClient( client, "Wrote {MAINCLR1}%i{CHATCLR} runs to %s!", num, WantsRunsToDb() ? "database" : "file" );
    
    return Plugin_Handled;
}

public Action Cmd_Admin_SetRunName( int client, int args )
{
    if ( !CanUserModifyRun( client ) ) return Plugin_Handled;
    
    if ( !args ) return Plugin_Handled;
    
    
    char szNew[MAX_RUN_NAME];
    GetCmdArgString( szNew, sizeof( szNew ) );
    StripQuotes( szNew );
    
    if ( strlen( szNew ) < 1 ) return Plugin_Handled;
    
    
    int runid = g_iRunId[client];
    
    int index = FindRunById( runid );
    if ( index != -1 )
    {
        char szOld[MAX_RUN_NAME];
        GetRunNameByIndex( index, szOld, sizeof( szOld ) );
        
        
        SetRunNameByIndex( index, szNew );
        
        
        Influx_PrintToChatAll( _, client, "%T", "INF_RUN_RENAMED", LANG_SERVER, szOld, szNew );
        
        
        if ( !client )
        {
            PrintToServer( INF_CON_PRE..."Run %s has been renamed to %s!", szOld, szNew );
        }
    }
    else
    {
        if ( client )
        {
            Influx_PrintToChat( _, client, "%T", "INF_RUNIDNOTEXIST", client, runid );
        }
        else
        {
            PrintToServer( INF_CON_PRE..."Run with an ID of %i does not exist!", runid );
        }
    }
    
    return Plugin_Handled;
}

public Action Cmd_Admin_DeleteRun( int client, int args )
{
    if ( !CanUserRemoveRecords( client ) ) return Plugin_Handled;
    
    if ( !args )
    {
        if ( client )
        {
            FakeClientCommand( client, "sm_deleterunsmenu" );
        }
        
        return Plugin_Handled;
    }
    
    
    char szArg[6];
    GetCmdArgString( szArg, sizeof( szArg ) );
    
    int runid = StringToInt( szArg );
    
    RemoveRunById( runid, client );
    
    return Plugin_Handled;
}

public Action Cmd_TestColor( int client, int args )
{
    if ( args )
    {
        char szArg[512];
        GetCmdArgString( szArg, sizeof( szArg ) );
        StripQuotes( szArg );
        
        FormatColors( szArg, sizeof( szArg ) );
        
        if ( client && szArg[0] != '\0' )
        {
            Format( szArg, sizeof( szArg ), "%s %s%s", g_szChatPrefix, g_szChatClr, szArg );
            
            decl clients[1];
            clients[0] = client;
            
            Inf_SendSayText2( client, clients, sizeof( clients ), szArg );
        }
    }
    
    return Plugin_Handled;
}

public Action Cmd_TestColorRemove( int client, int args )
{
    if ( args )
    {
        char szArg[512];
        GetCmdArgString( szArg, sizeof( szArg ) );
        StripQuotes( szArg );
        
        RemoveColors( szArg, sizeof( szArg ) );
        
        if ( client && szArg[0] != '\0' )
        {
            Format( szArg, sizeof( szArg ), "%s %s%s", g_szChatPrefix, g_szChatClr, szArg );
            
            decl clients[1];
            clients[0] = client;
            
            Inf_SendSayText2( client, clients, sizeof( clients ), szArg );
        }
    }
    
    return Plugin_Handled;
}

public Action Cmd_TestMapName( int client, int args )
{
    char szArg[128];
    GetCmdArgString( szArg, sizeof( szArg ) );
    
    
    PrintToServer( "Arg: %s | Is Valid: %i | Regex handle: %x", szArg, Influx_IsValidMapName( szArg ), g_Regex_ValidMapNames );
    
    return Plugin_Handled;
}

public Action Cmd_TestPrintStyles( int client, int args )
{
    if ( client ) return Plugin_Handled;
    
    
    decl mode[MODE_SIZE];
    decl style[STYLE_SIZE];
    
    for ( int i = 0; i < g_hModes.Length; i++ )
    {
        g_hModes.GetArray( i, mode );
        PrintToServer( INF_DEBUG_PRE..."Mode | Index: %i | Name: %s", mode[MODE_ID], mode[MODE_NAME] );
    }
    
    for ( int i = 0; i < g_hStyles.Length; i++ )
    {
        g_hStyles.GetArray( i, style );
        PrintToServer( INF_DEBUG_PRE..."Style | Index: %i | Name: %s", style[STYLE_ID], style[STYLE_NAME] );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Change_Name_Db( int client, int args )
{
    if ( !client ) return Plugin_Handled;


    if ( g_iClientId[client] <= 0 ) return Plugin_Handled;
    
    
    char szName[128];
    char szQuery[256];


    GetCmdArgString( szName, sizeof( szName ) );


    if (szName[0] == 0 )
    {
        DB_UpdateClient( client );
    }
    else
    {
        RemoveChars( szName, "`'\"" );
        
        Inf_DB_GetEscaped( Influx_GetDB(), szName, sizeof( szName ), "N/A" );
        

        FormatEx( szQuery, sizeof( szQuery ), "UPDATE "...INF_TABLE_USERS..." SET name='%s' WHERE uid=%i",
            szName,
            g_iClientId[client] );
        
        SQL_TQuery( Influx_GetDB(), Thrd_Empty, szQuery, _, DBPrio_Normal );


        Inf_ReplyToClient( client, "Set your name to '%s' in database!", szName );
    }

    return Plugin_Handled;
}

