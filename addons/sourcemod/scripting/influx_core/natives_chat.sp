public int Native_ReplaceChatColors(Handle hPlugin, int nParms)
{
    char szMessage[512];
    GetNativeString(1, szMessage, sizeof(szMessage));

    int maxsize = GetNativeCell(2);

    Influx_ReplaceColors(szMessage, maxsize, view_as<bool>(GetNativeCell(3)));

    SetNativeString(1, szMessage, maxsize);
}

public int Native_RemoveChatColors(Handle hPlugin, int nParms)
{
    char szMessage[512];
    GetNativeString(1, szMessage, sizeof(szMessage));

    int maxsize = GetNativeCell(2);

    Influx_ReplaceColors(szMessage, maxsize, true);

    SetNativeString(1, szMessage, maxsize);
}

public int Native_PrintToChat(Handle hPlugin, int nParms)
{
    int client = GetNativeCell( 1 );

    if( !client || !IsClientInGame( client ))
        return;

    char szMessage[512];
    SetGlobalTransTarget( client );
    FormatNativeString( 0, 2, 3, sizeof( szMessage ), _, szMessage );
    
    Influx_ReplaceColors(szMessage, sizeof(szMessage), false);

    PrintToChat( client, szMessage );
}

public int Native_PrintToChatAll(Handle hPlugin, int nParms)
{
    char szMessage[512];

    for( int i = 1; i <= MaxClients; i++ )
    {
        if( IsClientInGame( i ) )
        {
            SetGlobalTransTarget( i );
            FormatNativeString( 0, 1, 2, sizeof( szMessage ), _, szMessage );

            Influx_PrintToChat( i, szMessage );            
        }
    }
}

public int Native_ReplyToClient(Handle hPlugin, int nParms)
{
    int client = GetNativeCell( 1 );

    char szMessage[512];
    SetGlobalTransTarget( client );
    FormatNativeString( 0, 2, 3, sizeof( szMessage ), _, szMessage );

    if( client )
    {
        Influx_PrintToChat( client, szMessage );
    }

    else
    {
        Influx_ReplaceColors( szMessage, sizeof( szMessage ), true );
        PrintToServer( szMessage );
    }
}

public int Native_ClrSeparator(Handle hPlugin, int nParms)
{
    SetNativeString( 1, g_szClrSeparator, sizeof( g_szClrSeparator ) );
    SetNativeCellRef( 2, sizeof( g_szClrSeparator ) );
}