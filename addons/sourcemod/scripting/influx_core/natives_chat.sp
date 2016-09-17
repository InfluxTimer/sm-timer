stock void SendDefault( int argpos, int author, int[] clients, int nClients, bool prefix )
{
    decl String:buffer[512];
    
    FormatNativeString(
        0,
        argpos,
        argpos + 1,
        sizeof( buffer ),
        _,
        buffer );
    
    
    Inf_RemoveColors( buffer, sizeof( buffer ) );
    
    if ( !strlen( buffer ) ) return;
    
    
    if ( prefix )
    {
        Format( buffer, sizeof( buffer ), INF_CHAT_PRE..."%s", buffer );
    }
    
    Inf_SendSayText2( author, clients, nClients, buffer );
}

stock void SendPrint( int pos, int author, int[] clients, int nClients, bool prefix )
{
    if ( !IS_ENT_PLAYER( author ) || !IsClientInGame( author ) )
    {
        author = clients[0];
    }
    
    if ( g_bLib_ColorChat )
    {
        decl String:buffer[512];
        
        FormatNativeString(
            0,
            pos,
            pos + 1,
            sizeof( buffer ),
            _,
            buffer );
        
        Influx_Chat( author, clients, nClients, buffer, prefix );
    }
    else
    {
        SendDefault( pos, author, clients, nClients, prefix );
    }
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