public Action Cmd_Empty( int client, int args ) { return Plugin_Handled; }


public Action Cmd_CustomRank( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserUseCustomRank( client ) ) return Plugin_Handled;
    
    if ( !args )
    {
        Influx_PrintToChat( _, client, "Usage: sm_customrank <rank>" );
        return Plugin_Handled;
    }
    
    
    decl String:szTemp[256];
    int len = GetCmdArgString( szTemp, sizeof( szTemp ) );
    
    if ( len >= MAX_RANK_SIZE )
    {
        Influx_PrintToChat( _, client, "Rank length cannot exceed %i characters!", MAX_RANK_SIZE );
        return Plugin_Handled;
    }
    
    SetClientRank( client, -1, true, szTemp, true );
    
    DB_UpdateClientChosenRank( client, g_szCurRank[client] );
    
    
    return Plugin_Handled;
}

public Action Cmd_SetMapReward( int client, int args )
{
    if ( !CanUserSetMapReward( client ) ) return Plugin_Handled;
    
    if ( !args )
    {
        Inf_ReplyToClient( client, "Usage: sm_setmapreward <mapname (optional)> <points>" );
        return Plugin_Handled;
    }
    
    
    decl String:szTemp[16];
    
    if ( args > 1 )
    {
        GetCmdArg( 2, szTemp, sizeof( szTemp ) );
        StripQuotes( szTemp );
        
        int reward = StringToInt( szTemp );
        
        if ( !IsValidReward( reward, client, true ) )
        {
            return Plugin_Handled;
        }
        
        decl String:szMap[64];
        GetCmdArg( 1, szMap, sizeof( szMap ) );
        StripQuotes( szMap );
        
        
        DB_SetMapRewardByName( client, MAIN_RUN_ID, reward, szMap );
    }
    else
    {
        GetCmdArgString( szTemp, sizeof( szTemp ) );
        
        SetCurrentMapReward( client, Influx_GetClientRunId( client ), StringToInt( szTemp ) );
    }
    
    
    return Plugin_Handled;
}

public Action Cmd_GivePoints( int client, int args )
{
    if ( !CanUserSetMapReward( client ) ) return Plugin_Handled;
    
    if ( !args )
    {
        Inf_ReplyToClient( client, "Usage: sm_givesimplepoints <target (optional)> <amount> (Note: can be negative)" );
        return Plugin_Handled;
    }
    
    
    // Attempt to find a name.
    int targets[INF_MAXPLAYERS];
    int nTargets = 0;
    int points = 0;
    
    char szArg[64];
    
    if ( args >= 2 )
    {
        GetCmdArg( 2, szArg, sizeof( szArg ) );
        points = StringToInt( szArg );
        
        GetCmdArg( 1, szArg, sizeof( szArg ) );
        
        char szTemp[1];
        bool bUseless;
        
        nTargets = ProcessTargetString(
            szArg,
            client,
            targets,
            sizeof( targets ),
            COMMAND_FILTER_NO_BOTS,
            szTemp,
            sizeof( szTemp ),
            bUseless );
    }
    else // We're targeting ourselves.
    {
        targets[0] = client;
        nTargets = 1;
        
        GetCmdArgString( szArg, sizeof( szArg ) );
        points = StringToInt( szArg );
    }
    
    if ( nTargets < 1 )
    {
        Inf_ReplyToClient( client, "No targets found!" );
        return Plugin_Handled;
    }
    
    if ( !points )
    {
        Inf_ReplyToClient( client, "You can't give zero points!" );
        return Plugin_Handled;
    }
    
    
    
    GivePoints( targets, nTargets, points, client );
    
    return Plugin_Handled;
}

/*public Action Cmd_Admin_RecalcRanks( int client, int args )
{
    DB_RecalcRanks( client );
    
    return Plugin_Handled;
}*/

