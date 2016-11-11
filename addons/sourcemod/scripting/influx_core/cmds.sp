#include "influx_core/parsesearch.sp"

public Action Cmd_UpdateDB( int client, int args )
{
    if ( !client )
    {
        DB_Update( g_iCurDBVersion );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Version( int client, int args )
{
    if ( client )
    {
        Influx_PrintToChat( _, client, "Server is running {MAINCLR1}"...INF_NAME..."{CHATCLR} version {MAINCLR1}"...INF_VERSION..."{CHATCLR}!" );
    }
    else
    {
        PrintToServer( "Server is running "...INF_NAME..." version "...INF_VERSION..."!" );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Restart( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    // Let other plugins handle the spawning.
    if ( IsPlayerAlive( client ) )
    {
        TeleClientToStart_Safe( client, g_iRunId[client] );
    }
    
    
    return Plugin_Handled;
}

stock bool AttemptToSet( int client, int runid )
{
    int irun = FindRunById( runid );
    if ( irun == -1 )
    {
        Influx_PrintToChat( _, client, "That run does not exist!" );
        return false;
    }
    
    
    SetClientRun( client, runid );
    
    return true;
}

public Action Cmd_Main( int client, int args )
{
    if ( client ) AttemptToSet( client, g_iRunId_Main );
    return Plugin_Handled;
}

public Action Cmd_Bonus1( int client, int args )
{
    if ( client ) AttemptToSet( client, g_iRunId_Bonus1 );
    return Plugin_Handled;
}

public Action Cmd_Bonus2( int client, int args )
{
    if ( client ) AttemptToSet( client, g_iRunId_Bonus2 );
    return Plugin_Handled;
}

public Action Cmd_BonusChoose( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !args )
    {
        AttemptToSet( client, g_iRunId_Bonus1 );
        return Plugin_Handled;
    }
    
    
    char szArg[6];
    GetCmdArgString( szArg, sizeof( szArg ) );
    
    int value = StringToInt( szArg );
    
    if ( value == 1 )
    {
        AttemptToSet( client, g_iRunId_Bonus1 );
    }
    else if ( value == 2 )
    {
        AttemptToSet( client, g_iRunId_Bonus2 );
    }
    else
    {
        FakeClientCommand( client, "sm_run" );
    }
    
    return Plugin_Handled;
}

stock void ParseArgs( int args, int &uid, int &mapid, int &runid, int &mode, int &style, char[] szPlayerName, int player_len, char[] szMap, int map_len )
{
    if ( !args ) return;
    
    
    // We don't want too many arguments being parsed.
    if ( args > 3 ) args = 3;
    
    
    
    decl String:szArg[64];
    
    for ( int i = 1; i <= args; i++ )
    {
        GetCmdArg( i, szArg, sizeof( szArg ) );
        //StripQuotes( szArg );
        
        if ( szArg[0] == '\0' ) continue;
        
        
        int value = 0;
        Search_t search = ParseSearchArg( szArg, value );
        
        switch ( search )
        {
            case SEARCH_MAPID :
            {
                mapid = value;
                szMap[0] = '\0';
            }
            case SEARCH_UID : uid = value;
            case SEARCH_RUNID : runid = value;
            case SEARCH_MODE : mode = value;
            case SEARCH_STYLE : style = value;
            case SEARCH_MAPNAME :
            {
                strcopy( szMap, map_len, szArg[value] );
                mapid = -1;
            }
            case SEARCH_PLAYERNAME :
            {
                strcopy( szPlayerName, player_len, szArg[value] );
                uid = -1;
            }
        }
        
#if defined DEBUG_PARSESEARCH
        PrintToServer( INF_DEBUG_PRE..."Search type (%s): %i | value: %i", szArg, search, value );
#endif
    }
}

public Action Cmd_PrintMyRecords( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Inf_HandleCmdSpam( client, 3.0, g_flLastRecPrintTime[client], true ) )
    {
        return Plugin_Handled;
    }
    
    if ( g_iClientId[client] < 1 ) return Plugin_Handled;
    
    
    
    int runid = g_iRunId[client];
    if ( runid < 1 ) runid = MAIN_RUN_ID;
    
    
    if ( args )
    {
        char szUseless[1];
        int useless;
        
        
        decl String:szMap[64];
        szMap[0] = '\0'; 
        
        int mapid = g_iCurMapId;
        int mode = -1;
        int style = -1;
        
        
        ParseArgs( args, useless, mapid, runid, mode, style, szUseless, sizeof( szUseless ), szMap, sizeof( szMap ) );
        
        DB_PrintRecords( client, g_iClientId[client], mapid, runid, mode, style, _, szMap );
    }
    else
    {
        DB_PrintRecords( client, g_iClientId[client], g_iCurMapId, runid );
    }
    
    return Plugin_Handled;
}
public Action Cmd_PrintRecords( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( Inf_HandleCmdSpam( client, 3.0, g_flLastRecPrintTime[client], true ) )
    {
        return Plugin_Handled;
    }
    
    
    int runid = g_iRunId[client];
    if ( runid < 1 ) runid = MAIN_RUN_ID;
    
    
    if ( args )
    {
        decl String:szMap[64];
        szMap[0] = '\0';
        
        decl String:szName[64];
        szName[0] = '\0';
        
        int uid = -1;
        int mapid = g_iCurMapId;
        int mode = -1;
        int style = -1;
        
        ParseArgs( args, uid, mapid, runid, mode, style, szName, sizeof( szName ), szMap, sizeof( szMap ) );
        
        DB_PrintRecords( client, uid, mapid, runid, mode, style, szName, szMap );
    }
    else
    {
        DB_PrintRecords( client, _, g_iCurMapId, runid );
    }
    
    return Plugin_Handled;
}

public Action Cmd_PrintMapsRecords( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    DB_PrintMaps( client );
    
    return Plugin_Handled;
}

public Action Cmd_GotoEnd( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    
    int runid = g_iRunId[client];
    
    int irun = FindRunById( runid );
    if ( irun == -1 ) return Plugin_Handled;
    
    
    float pos[3];
    if ( SearchEnd( runid, pos ) )
    {
        g_iRunState[client] = STATE_NONE;
        
        TeleportEntity( client, pos, NULL_VECTOR, NULL_VECTOR );
    }
    else
    {
        char szRun[MAX_RUN_NAME];
        GetRunNameByIndex( irun, szRun, sizeof( szRun ) );
        
        
        Influx_PrintToChat( _, client, "Couldn't find end to {MAINCLR1}%s{CHATCLR}!", szRun );
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
        Influx_PrintToChat( _, client, "Run with an ID of {MAINCLR1}%i{CHATCLR} does not exist!", runid );
    }
    
    return Plugin_Handled;
}

public Action Cmd_Admin_SaveRuns( int client, int args )
{
    if ( !CanUserModifyRun( client ) ) return Plugin_Handled;
    
    
    int num = WriteMapFile();
    
    if ( client )
    {
        Influx_PrintToChat( _, client, "Wrote {MAINCLR1}%i{CHATCLR} runs to file!", num );
    }
    else
    {
        PrintToServer( INF_CON_PRE..."Wrote %i runs to file!", num );
    }
    
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
        
        
        Influx_PrintToChatAll( _, client, "Run {MAINCLR1}%s{CHATCLR} has been renamed to {MAINCLR1}%s{CHATCLR}!", szOld, szNew );
        
        
        if ( !client )
        {
            PrintToServer( INF_CON_PRE..."Run %s has been renamed to %s!", szOld, szNew );
        }
    }
    else
    {
        if ( client )
        {
            Influx_PrintToChat( _, client, "Run with an ID of {MAINCLR1}%i{CHATCLR} does not exist!", runid );
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
    if ( !args ) return Plugin_Handled;
    
    
    char szArg[6];
    GetCmdArgString( szArg, sizeof( szArg ) );
    
    int runid = StringToInt( szArg );
    
    int irun = FindRunById( runid );
    
    if ( irun != -1 )
    {
        char szRun[MAX_RUN_NAME];
        GetRunNameByIndex( irun, szRun, sizeof( szRun ) );
        
        
        g_hRuns.Erase( irun );
        
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame( i ) && g_iRunId[i] == runid )
            {
                
                TeleClientToStart_Safe( i, MAIN_RUN_ID );
            }
        }
        
        Call_StartForward( g_hForward_OnRunDeleted );
        Call_PushCell( runid );
        Call_Finish();
        
        
        if ( client )
        {
            Influx_PrintToChat( _, client, "Run {MAINCLR1}%s{CHATCLR} has been deleted!", szRun );
        }
        else
        {
            PrintToServer( INF_CON_PRE..."Run %s has been deleted!", szRun );
        }
    }
    else
    {
        if ( client )
        {
            Influx_PrintToChat( _, client, "Run with an ID of {MAINCLR1}%i{CHATCLR} does not exist!", runid );
        }
        else
        {
            PrintToServer( INF_CON_PRE..."Run with an ID of %i does not exist!", runid );
        }
    }
    
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