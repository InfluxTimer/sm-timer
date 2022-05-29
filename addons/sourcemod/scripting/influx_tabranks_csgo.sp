#include influx/core
#include influx/simpleranks

#pragma newdecls required

#define MPL MAXPLAYERS+1
#define MNL MAX_NAME_LENGTH     // 128
#define CONFIG_PATH "configs/influx/tabranks.ini"

int comp_offset = -1;

bool sendToClient[MPL] = {true, ...};
char clientrank[MPL][MNL];

ArrayList tabranks;

public Plugin myinfo = 
{
	name = "[Influx] FakeRanks",
	author = "nullent?",
	description = "...",
	version = "1.0",
    url = "discord.gg/ChTyPUG"
};


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if(GetEngineVersion() != Engine_CSGO)
    {
        FormatEx(error, err_max, "Game engine is not supported");
        return APLRes_Failure;
    }

    CreateNative("influx_trank_SendToClient", Native_SendToClient);

    RegPluginLibrary("influx_tabranks");

    return APLRes_Success;
}

public int Native_SendToClient(Handle hPlugin, int args)
{
    int client = GetNativeCell(1);

    if(!client || !IsClientInGame(client) || IsFakeClient(client)){
        return false;
    }
    
    sendToClient[client] = view_as<bool>(GetNativeCell(2));

    _local_Influx_ChangeRights(client, !sendToClient[client], sendToClient[client], true);
    return true;
}

public void OnClientPutInServer(int client)
{
    sendToClient[client] = true;
    _local_Influx_ChangeRights(client, !sendToClient[client], sendToClient[client]);

    RequestFrame(OnFrameReq, client);
}

public void OnMapStart()
{
    char fullpath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, fullpath, sizeof(fullpath), CONFIG_PATH);

    if(!FileExists(fullpath)){
        SetFailState("Where is my config file: %s ?", fullpath);
    }

    parseConfig(fullpath);

    SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnThinkPost);
}

void parseConfig(const char[] config)
{
    tabranks.Clear();

    SMCParser parser = new SMCParser();
    parser.OnKeyValue = OnKeyValueRead;
    parser.OnEnd = OnParseEnd;

    int iLine;
    if(parser.ParseFile(config, iLine) != SMCError_Okay)
        LogError("Error on parse settings file: | %s | on | %d | line", config, iLine);
}

int IconType;

public SMCResult OnKeyValueRead(SMCParser SMC, const char[] sKey, const char[] sValue, bool bKey_quotes, bool bValue_quotes)
{
    if(!sValue[0] || !sKey[0]){
        return SMCParse_Continue;
    }
    
    if(!strcmp(sKey, "IconType"))
    {
        switch(StringToInt(sValue))
        {
            case 0: IconType = 0;
            case 1: IconType = 50;
            case 2: IconType = 70;
            case 3: IconType = 100;
        }

    }
    else
    {
        tabranks.PushString(sKey);
        tabranks.Push(StringToInt(sValue) + IconType);
    }

    return SMCParse_Continue;
}

public void OnParseEnd(SMCParser smc, bool halted, bool failed)
{
    char buffer[MNL]; int iIndex;

    for(int i = 1; i < tabranks.Length; i+=2)
    {
        iIndex = tabranks.Get(i);
        if(iIndex > 100)
        {
            FormatEx(buffer, sizeof(buffer), "materials/panorama/images/icons/skillgroups/skillgroup%i.svg", iIndex);
            AddFileToDownloadsTable(buffer);
        }
    }
}

public void OnFrameReq(any data)
{
    if(IsFakeClient(data)){
        return;
    }

    Influx_GetClientSimpleRank(data, clientrank[data], sizeof(clientrank[]));
}

public void OnThinkPost(int ent)
{
    static int i;
    i = 0;

    while(i++ < MaxClients)
    {
        if(!IsClientInGame(i) || IsFakeClient(i) || !sendToClient[i] || tabranks.FindString(clientrank[i]) == -1){
            continue;
        }

        SetEntData(ent, comp_offset + i * 4, tabranks.Get(tabranks.FindString(clientrank[i]) + 1));
    }
}

public void OnPlayerRunCmdPost(int client, int buttons)
{
    static int iOldButtons[MAXPLAYERS+1];

	if(buttons & IN_SCORE && !(iOldButtons[client] & IN_SCORE))
	{
		StartMessageOne("ServerRankRevealAll", client, USERMSG_BLOCKHOOKS);
		EndMessage();
	}

	iOldButtons[client] = buttons;
}

public void OnPluginStart()
{
    tabranks = new ArrayList(MNL, 0);
    comp_offset = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");

    CreateTimer(10.0, UpdateClientRank, _, TIMER_REPEAT);
}

public Action UpdateClientRank(Handle timer, any data)
{
    static int i;

    while(i++ < MaxClients)
    {
        if(!IsClientInGame(i) || IsFakeClient(i) || !sendToClient[i]){
            continue;
        }

        Influx_GetClientSimpleRank(i, clientrank[i], sizeof(clientrank[]));
        Influx_RemoveChatColors(clientrank[i], sizeof(clientrank[]));
        _local_Influx_OnRankGetting(i, clientrank[i], sizeof(clientrank[]));
    }

    i = 0;
}

void _local_Influx_OnRankGetting(int client, char[] rank, int size)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("Influx_trank_OnGetRank", ET_Ignore, Param_Cell, Param_String, Param_Cell);

    Call_StartForward(gf);
    Call_PushCell(client);
    Call_PushStringEx(rank, size, SM_PARAM_COPYBACK|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(size);
    Call_Finish();
}

void _local_Influx_ChangeRights(int client, bool oldVal, bool newVal, bool IsNative = false)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("Influx_trank_SendToClient", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

    Call_StartForward(gf);
    Call_PushCell(client);
    Call_PushCell(oldVal);
    Call_PushCell(newVal);
    Call_PushCell(IsNative);
    Call_Finish();
}
