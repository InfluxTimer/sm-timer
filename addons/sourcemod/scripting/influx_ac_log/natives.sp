public int Native_LogCheat( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    
    
    decl String:szReason[512];
    szReason[0] = 0;
    
    decl String:szId[64];
    szId[0] = 0;
    
    FormatNativeString(
        0,
        4,
        5,
        sizeof( szReason ),
        _,
        szReason );
    
    GetNativeString( 2, szId, sizeof( szId ) );
    
    return LogCheat( client, szId, szReason, _, _, _, GetNativeCell( 3 ) ? true : false );
}

public int Native_PunishCheat( Handle hPlugin, int nParms )
{
    int client = GetNativeCell( 1 );
    int punishtime = GetNativeCell( 3 );
    
    
    decl String:szReason[512];
    szReason[0] = 0;
    
    decl String:szKick[512];
    szKick[0] = 0;
    
    decl String:szId[64];
    szId[0] = 0;
    
    FormatNativeString(
        0,
        5,
        6,
        sizeof( szReason ),
        _,
        szReason );
        
    GetNativeString( 2, szId, sizeof( szId ) );
    GetNativeString( 4, szKick, sizeof( szKick ) );
    
    return LogCheat( client, szId, szReason, szKick, true, punishtime, true );
}