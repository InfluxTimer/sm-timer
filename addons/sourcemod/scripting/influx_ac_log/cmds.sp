public Action Cmd_Empty( int client, int args ) { return Plugin_Handled; }

public Action Cmd_PrintLog( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserPrintLog( client ) ) return Plugin_Handled;
    
    if ( !args )
    {
        Influx_PrintToChat( _, client, "Usage: sm_printcheatlog <name>" );
        return Plugin_Handled;
    }
    
    
    bool bFound = false;
    
    char szArg[64];
    GetCmdArgString( szArg, sizeof( szArg ) );
    
    int targets[1];
    char szTemp[1];
    bool bUseless;
    if ( ProcessTargetString(
        szArg,
        0,
        targets,
        sizeof( targets ),
        COMMAND_FILTER_NO_MULTI,
        szTemp,
        sizeof( szTemp ),
        bUseless ) )
    {
        int target = targets[0];
        
        if (target != client
        &&  IS_ENT_PLAYER( target )
        &&  IsClientInGame( target )
        &&  Influx_GetClientId( target ) > 0)
        {
            bFound = true;
            
            DB_PrintClientLogById( client, Influx_GetClientId( target ) );
        }
    }
    
    if ( !bFound )
    {
        DB_PrintClientLogByName( client, szArg );
    }
    
    return Plugin_Handled;
}

public Action Cmd_PrintNewLog( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserPrintLog( client ) ) return Plugin_Handled;
    
    
    DB_PrintUnseenLog( client );
    
    
    Influx_PrintToChat( _, client, "Use {MAINCLR1}!markaclogseen{CHATCLR} once done." );
    
    return Plugin_Handled;
}

public Action Cmd_ToggleLogNotifications( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !CanUserSeeCurrentLog( client ) ) return Plugin_Handled;
    
    
    g_bDisableLogNotify[client] = !g_bDisableLogNotify[client];
    
    Influx_PrintToChat( _, client, "%s logging notifications.", g_bDisableLogNotify[client] ? "Disabled" : "Enabled" );
    
    return Plugin_Handled;
}

public Action Cmd_MarkLogSeen( int client, int args )
{
    if ( !CanUserMarkLogSeen( client ) ) return Plugin_Handled;
    
    
    DB_MarkAllSeen( client );
    
    return Plugin_Handled;
}
