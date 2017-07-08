stock void SendPrint( int pos, int author, int[] clients, int nClients, bool prefix )
{
    if ( !IS_ENT_PLAYER( author ) || !IsClientInGame( author ) )
    {
        author = clients[0];
    }
    
    
    decl String:buffer[512];
    
    FormatNativeString(
        0,
        pos,
        pos + 1,
        sizeof( buffer ),
        _,
        buffer );
    
    FormatColors( buffer, sizeof( buffer ) );
    
    
    // There's nothing to send!
    if ( buffer[0] == '\0' ) return;
    
    
    // Do prefix?
    if ( prefix )
    {
        Format( buffer, sizeof( buffer ), "%s %s%s", g_szChatPrefix, g_szChatClr, buffer );
    }
    
    
    // Add CSGO color fix.
    if ( g_bIsCSGO )
    {
        Format( buffer, sizeof( buffer ), " \x01\x0B%s", buffer );
    }
    
    
    Inf_SendSayText2( author, clients, nClients, buffer );
}

public int Native_PrintToChat( Handle hPlugin, int nParms )
{
    int flags = GetNativeCell( 1 );
    int client = GetNativeCell( 2 );
    
    decl clients[1];
    clients[0] = client;
    
    
    
    
    SendPrint( 3, client, clients, sizeof( clients ), ( flags & PRINTFLAGS_NOPREFIX ) ? false : true );
    
    return 1;
}

public int Native_PrintToChatEx( Handle hPlugin, int nParms )
{
    int flags = GetNativeCell( 1 );
    int author = GetNativeCell( 2 );
    int nClients = GetNativeCell( 4 );
    
    int[] clients = new int[nClients];
    GetNativeArray( 3, clients, nClients );
    
    SendPrint( 5, author, clients, nClients, ( flags & PRINTFLAGS_NOPREFIX ) ? false : true );
    
    return 1;
}

public int Native_PrintToChatAll( Handle hPlugin, int nParms )
{
    int flags = GetNativeCell( 1 );
    
    int[] clients = new int[MaxClients];
    int nClients = 0;
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame( i ) && !IsFakeClient( i ) )
        {
            /*if ( g_bLib_Hud )
            {
                if ( Influx_GetClientHideFlags( i ) &  )
                {
                    continue;
                }
            }*/
            
            clients[nClients++] = i;
        }
    }
    
    if ( nClients )
    {
        SendPrint( 3, GetNativeCell( 2 ), clients, nClients, ( flags & PRINTFLAGS_NOPREFIX ) ? false : true );
    }
    
    return 1;
}

public int Native_RemoveChatColors( Handle hPlugin, int nParms )
{
    int len = GetNativeCell( 2 );
    
    char[] sz = new char[len];
    
    GetNativeString( 1, sz, len );
    
    RemoveColors( sz, len );
    
    
    SetNativeString( 1, sz, len );
    
    return 1;
}

public int Native_FormatChatColors( Handle hPlugin, int nParms )
{
    int len = GetNativeCell( 2 );
    
    char[] sz = new char[len];
    
    GetNativeString( 1, sz, len );
    
    FormatColors( sz, len );
    
    
    SetNativeString( 1, sz, len );
    
    return 1;
}