public int Native_LogCheat( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    
    decl String:buffer[512];
    buffer[0] = 0;
    
    FormatNativeString(
        0,
        2,
        3,
        sizeof( buffer ),
        _,
        buffer );
    
    return LogCheat( client, buffer );
}

public int Native_PunishCheat( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    int punishtime = GetNativeCell( 2 );
    
    
    decl String:szReason[512];
    szReason[0] = 0;
    
    decl String:szKick[512];
    szKick[0] = 0;
    
    FormatNativeString(
        0,
        4,
        5,
        sizeof( szReason ),
        _,
        szReason );
        
    GetNativeString( 3, szKick, sizeof( szKick ) );
    
    return LogCheat( client, szReason, szKick, true, punishtime );
}