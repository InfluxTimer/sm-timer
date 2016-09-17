#include <sourcemod>

#include <influx/core>
#include <influx/hud>

#undef REQUIRE_PLUGIN
#include <influx/help>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - HUD | Record Sounds",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    RegConsoleCmd( "sm_recsounds", Cmd_Sounds );
}

public void Influx_OnRequestHUDMenuCmds()
{
    Influx_AddHUDMenuCmd( "sm_recsounds", "Record Sounds" );
}

public void Influx_RequestHelpCmds()
{
    Influx_AddHelpCommand( "recsounds", "Display sound options." );
}

public Action Cmd_Sounds( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    int hideflags = Influx_GetClientHideFlags( client );
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "Record Sounds:\n " );
    
    menu.AddItem( "", ( hideflags & HIDEFLAG_SND_PERSONAL )    ? "Personal: OFF" : "Personal: ON" );
    menu.AddItem( "", ( hideflags & HIDEFLAG_SND_BEST )        ? "Best: OFF" : "Best: ON" );
    menu.AddItem( "", ( hideflags & HIDEFLAG_SND_NORMAL )      ? "Other: OFF" : "Other: ON" );
    
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
            if ( hideflags & HIDEFLAG_SND_PERSONAL )
            {
                hideflags &= ~HIDEFLAG_SND_PERSONAL;
            }
            else
            {
                hideflags |= HIDEFLAG_SND_PERSONAL;
            }
        }
        case 1 :
        {
            if ( hideflags & HIDEFLAG_SND_BEST )
            {
                hideflags &= ~HIDEFLAG_SND_BEST;
            }
            else
            {
                hideflags |= HIDEFLAG_SND_BEST;
            }
        }
        case 2 :
        {
            if ( hideflags & HIDEFLAG_SND_NORMAL )
            {
                hideflags &= ~HIDEFLAG_SND_NORMAL;
            }
            else
            {
                hideflags |= HIDEFLAG_SND_NORMAL;
            }
        }
    }
    
    Influx_SetClientHideFlags( client, hideflags );
    
    FakeClientCommand( client, "sm_recsounds" );
    
    return 0;
}