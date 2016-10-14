public Action Cmd_DeleteCpTimes( int client, int args )
{
    if ( !CanUserModifyCPTimes( client ) ) return Plugin_Handled;
    
    if ( !client ) return Plugin_Handled;
    
    
    DB_PrintDeleteCPTimes( client, Influx_GetCurrentMapId() );
    
    
    
    return Plugin_Handled;
}