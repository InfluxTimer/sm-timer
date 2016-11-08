public Action Cmd_PrintCpTimes( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    DB_PrintTopCPTimes( client, Influx_GetCurrentMapId(), Influx_GetClientRunId( client ), Influx_GetClientMode( client ), Influx_GetClientStyle( client ) );
    
    return Plugin_Handled;
}