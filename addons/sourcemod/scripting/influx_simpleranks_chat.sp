#define MAXNAME_LENGTH 128

// chat-processor.inc shared info
forward Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool & processcolors, bool & removecolors);

public SharedPlugin __pl_chat_processor =
{
	name = "chat-processor",
	file = "chat-processor.smx",
	required = 0

};
// chat-processor end

// scp.inc shared info
forward Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message);

public SharedPlugin:_pl_scp = 
{
	name = "scp",
	file = "simple-chatprocessor.smx",
	required = 0
};
// scp.inc end

// ccprocessor.inc shared info
enum
{
	eMsg_TEAM = 0,
	eMsg_ALL,
	eMsg_CNAME,

	/* The bind '{MSG}' is not called for this type*/
	eMsg_RADIO,	

	eMsg_SERVER,
	
	eMsg_MAX
};

forward void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize);
forward void cc_proc_MsgBroadType(const int iType);

public SharedPlugin __pl_ccprocessor= 
{
	name = "ccprocessor",
	file = "ccprocessor.smx",
	required = 0
};
// ccprocessor.inc end

#include <sourcemod>

#include <influx/core>
#include <influx/simpleranks>
#include <influx/simpleranks_chat>

public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Simple Ranks | Chat",
    description = "",
    version = INF_VERSION
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    // LIBRARIES
    RegPluginLibrary( INFLUX_LIB_SIMPLERANKS_CHAT );
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool & processcolors, bool & removecolors)
{
    if( !IsFakeClient( author ) )
    {
        char szRank[64];

        GetClientRank( author, szRank, sizeof( szRank ), false );

        if( szRank[0] )
        {   
            Format(name, MAXNAME_LENGTH, "%s %s", szRank, name );

            return Plugin_Changed;
        }
        
    }

    return Plugin_Continue;
}

public Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message)
{
    if( !IsFakeClient( author ) )
    {
        char szRank[64];

        GetClientRank( author, szRank, sizeof( szRank ), false );

        if( szRank[0] )
        {   
            Format(name, MAXNAME_LENGTH, "%s %s", szRank, name );

            return Plugin_Changed;
        }
        
    }

    return Plugin_Continue;
}

int MType;

public void cc_proc_MsgBroadType(const int iType)
{
    MType = iType;
}

public void cc_proc_RebuildString(int client, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
#define PLEVEL 1
    
    if(MType == eMsg_CNAME || MType == eMsg_SERVER)
        return;

    if(!StrEqual(szBind, "{PREFIX}"))
        return;
    
    char szRank[64];

    GetClientRank( client, szRank, sizeof( szRank ) );

    if( !szRank[0] )
        return;
    
    if(PLEVEL < pLevel)
        return;
    
    pLevel = PLEVEL;
    FormatEx( szBuffer, iSize, szRank );
}

stock void Influx_ClearParams(char[][] params, int count)
{
    for(int i; i < count; i++)
        params[i][0] = '\0';
}

void GetClientRank(int client, char[] name, int size, bool IsCCP = true)
{
    Influx_GetClientSimpleRank( client, name, size );

    if( !name[0] )
        return;
    
    if(!IsCCP)
        Influx_ReplaceChatColors(name, size, false);
    
}