bool g_bValidSection;

void UpdatePalette()
{
    static char palettePath[PLATFORM_MAX_PATH] = "configs/influx_palette.ini";

    if(palettePath[0] == 'c')
        BuildPath(Path_SM, palettePath, sizeof(palettePath), palettePath);

    if(!FileExists(palettePath))
    {
        LogError("File is not exist: %s", palettePath);
        return;
    }

    SMCParser smParser = new SMCParser();
    smParser.OnKeyValue = OnKeyValue;
    smParser.OnEnterSection = OnEnterSection;
    smParser.OnEnd = OnCompReading;

    int iLine;
    if(smParser.ParseFile(palettePath, iLine) != SMCError_Okay)
        LogError("An error was detected on line '%i' while reading", iLine);    
}

SMCResult OnEnterSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    static char szGameFolder[64];

    if(!szGameFolder[0])
        GetGameFolderName(szGameFolder, sizeof(szGameFolder));

    g_bValidSection = StrEqual(name, szGameFolder, false);

    return SMCParse_Continue;
}

SMCResult OnKeyValue(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0] || !g_bValidSection)
        return SMCParse_Continue;

    static char szValue[16];
    szValue = NULL_STRING;

    int iBuffer = strlen(sValue);

    switch(iBuffer)
    {
        // Defined ASCII colors
        case 1, 2: FormatEx(szValue, sizeof(szValue), "%c", StringToInt(sValue));

        // Colors based RGB/RGBA into HEX format: #RRGGBB/#RRGGBBAA
        case 7, 9: FormatEx(szValue, sizeof(szValue), "%c%s", (iBuffer == 7) ? 7 : 8, sValue[1]);

        default: LogError("Invalid color length for value: %s", sValue);
    }

    g_hPalette.PushString(sKey);
    g_hPalette.PushString(szValue);

    return SMCParse_Continue;
}

public void OnCompReading(SMCParser smc, bool halted, bool failed)
{
    if(smc == INVALID_HANDLE)
        smc = null;

    delete smc;

    g_bValidSection = false;
}

void Influx_ReplaceColors(char[] szBuffer, int iSize, bool bRemove)
{
    static char szKey[16], szColor[16];
    szColor = NULL_STRING;
    szKey   = NULL_STRING;

    for(int i; i < g_hPalette.Length; i++)
    {
        g_hPalette.GetString(i, (bRemove || !(i%2)) ? szKey : szColor, sizeof(szKey));

        if(!bRemove && !(i%2))
            continue;

        ReplaceString(szBuffer, iSize, szKey, szColor, true);
    }

}