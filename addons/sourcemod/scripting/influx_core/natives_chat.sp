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