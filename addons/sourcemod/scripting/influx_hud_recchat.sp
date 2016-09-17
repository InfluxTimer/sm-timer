#include <sourcemod>

#include <influx/core>
#include <influx/hud>

#undef REQUIRE_PLUGIN
#include <influx/help>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - HUD | Chat Records",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    RegConsoleCmd( "sm_recchat", Cmd_Chat );
}

public void Influx_OnRequestHUDMenuCmds()
{
    Influx_AddHUDMenuCmd( "sm_recchat", "Record Chat" );
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "recchat", "Display chat record options." );
}

public Action Cmd_Chat( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int hideflags = Influx_GetClientHideFlags( client );
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Chat Record Printing:\n " );
    
    menu.AddItem( "", ( hideflags & HIDEFLAG_CHAT_PERSONAL )    ? "Personal: OFF" : "Personal: ON" );
    menu.AddItem( "", ( hideflags & HIDEFLAG_CHAT_BEST )        ? "Best: OFF" : "Best: ON" );
    menu.AddItem( "", ( hideflags & HIDEFLAG_CHAT_NORMAL )      ? "Other: OFF" : "Other: ON" );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public int Hndlr_Settings( Menu menu, MenuAction action, int client, int index )
{
    MENU_HANDLE( menu, action )
    
    
    int hideflags = Influx_GetClientHideFlags( client );
    switch ( index )
    {
        case 0 :
        {
            if ( hideflags & HIDEFLAG_CHAT_PERSONAL )
            {
                hideflags &= ~HIDEFLAG_CHAT_PERSONAL;
            }
            else
            {
                hideflags |= HIDEFLAG_CHAT_PERSONAL;
            }
        }
        case 1 :
        {
            if ( hideflags & HIDEFLAG_CHAT_BEST )
            {
                hideflags &= ~HIDEFLAG_CHAT_BEST;
            }
            else
            {
                hideflags |= HIDEFLAG_CHAT_BEST;
            }
        }
        case 2 :
        {
            if ( hideflags & HIDEFLAG_CHAT_NORMAL )
            {
                hideflags &= ~HIDEFLAG_CHAT_NORMAL;
            }
            else
            {
                hideflags |= HIDEFLAG_CHAT_NORMAL;
            }
        }
    }
    
    Influx_SetClientHideFlags( client, hideflags );
    
    FakeClientCommand( client, "sm_recchat" );
    
    return 0;
}