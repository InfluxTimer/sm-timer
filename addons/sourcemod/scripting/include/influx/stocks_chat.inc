#if defined _influx_stocks_chat_included
    #endinput
#endif
#define _influx_stocks_chat_included


#include <sdktools>

#include <influx/stocks_core>


#define INF_CON_PRE             "["...INF_NAME..."] "
#define INF_DEBUG_PRE           "[INF-DEBUG] "
#define INF_CHAT_PRE            "\x03[\x04"...INF_NAME..."\x03] \x01"


//#define MAX_SAYTEXT2_LENGTH     254

/*
stock void Inf_RemoveColors( char[] sz, int len )
{
    int start = 0;
    
    decl pos, endpos;
    
    while ( (pos = FindCharInString( sz[start], '{' )) != -1 )
    {
        pos += start;
        
        endpos = FindCharInString( sz[pos + 1], '}' );
        if ( endpos == -1 ) break;
        
        
        endpos += pos + 2;
        
        sz[pos] = '\0';
        
        Format( sz, len, "%s%s", sz, sz[endpos] );
        
        start = pos;
    }
}
*/

stock void Inf_SendSayText2( int author, int[] clients, int nClients, const char[] msg )
{
    static UserMsg UserMsg_SayText2 = INVALID_MESSAGE_ID;
    
    if ( UserMsg_SayText2 == INVALID_MESSAGE_ID )
    {
        if ( (UserMsg_SayText2 = GetUserMessageId( "SayText2" )) == INVALID_MESSAGE_ID )
        {
            SetFailState( INF_CON_PRE..."Couldn't find usermessage id for SayText2! (chat printing)" );
        }
    }
    
    
    Handle hMsg = StartMessageEx( UserMsg_SayText2, clients, nClients, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS );
    
    if ( hMsg != null )
    {
        if ( GetUserMessageType() == UM_Protobuf )
        {
            PbSetInt( hMsg, "ent_idx", author );
            PbSetBool( hMsg, "chat", true );
            
            PbSetString( hMsg, "msg_name", msg );
            PbAddString( hMsg, "params", "" );
            PbAddString( hMsg, "params", "" );
            PbAddString( hMsg, "params", "" );
            PbAddString( hMsg, "params", "" );
            
            PbSetBool( hMsg, "textallchat", false );
        }
        else
        {
            BfWriteByte( hMsg, author );
            
            // false for no console print. If false, no chat sound is played.
            BfWriteByte( hMsg, true );
            
            BfWriteString( hMsg, msg );
        }
        
        EndMessage();
    }
}