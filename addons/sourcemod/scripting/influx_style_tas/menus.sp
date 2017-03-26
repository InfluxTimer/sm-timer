#include "influx_style_tas/menus_hndlrs.sp"


public Action Cmd_TasMenu( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    decl String:szDisplay[32];
    
    
    Menu menu = new Menu( Hndlr_TasMenu );
    menu.SetTitle( "TAS Menu (!tas_menu)\n " );
    
    menu.AddItem( "c", ShouldContinue( client ) ? "Continue\n " : "Stop\n " );
    
    
    // Fast forward
    strcopy( szDisplay, sizeof( szDisplay ), ">>| Forward" );
    
    if ( g_iPlayback[client] > 0 )
    {
        Format( szDisplay, sizeof( szDisplay ), "%s (%ix)", szDisplay, g_iPlayback[client] );
    }
    
    menu.AddItem( "d", szDisplay );
    
    
    // Rewind
    strcopy( szDisplay, sizeof( szDisplay ), "<<| Rewind" );
    
    if ( g_iPlayback[client] < 0 )
    {
        Format( szDisplay, sizeof( szDisplay ), "%s (%ix)", szDisplay, -g_iPlayback[client] );
    }
    
    Format( szDisplay, sizeof( szDisplay ), "%s\n ", szDisplay );
    
    menu.AddItem( "e", szDisplay );
    
    menu.AddItem( "a", "> Next Frame" );
    menu.AddItem( "b", "< Previous Frame\n " );
    
    menu.AddItem( "f", "Settings\n " );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_Settings( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    if ( !IsPlayerAlive( client ) ) return Plugin_Handled;
    
    if ( Influx_GetClientStyle( client ) != STYLE_TAS ) return Plugin_Handled;
    
    
    decl String:szDisplay[32];
    
    
    Menu menu = new Menu( Hndlr_Settings );
    menu.SetTitle( "TAS Settings (!tas_settings)\n " );
    
    FormatEx( szDisplay, sizeof( szDisplay ), "Timescale: %.2fx", g_flTimescale[client] );
    menu.AddItem( "a", szDisplay );
    
    FormatEx( szDisplay, sizeof( szDisplay ), "Auto-strafe: %s\n ", g_bAutoStrafe[client] ? "ON" : "OFF" );
    menu.AddItem( "b", szDisplay );
    
    menu.AddItem( "c", "Display Commands\n " );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}

public Action Cmd_ListCmds( int client, int args )
{
    if ( !client ) return Plugin_Handled;
   
   
    Menu menu = new Menu( Hndlr_Empty );
    menu.SetTitle( "TAS Commands (!tas_listcmds)\n " );
    
    menu.AddItem( "", "sm_tas_continue", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_stop", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_fwd", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_bwd", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_nextframe", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_prevframe", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_autostrafe", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_inctimescale", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_dectimescale", ITEMDRAW_DISABLED );
    
    menu.AddItem( "", "sm_tas_menu", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_settings", ITEMDRAW_DISABLED );
    menu.AddItem( "", "sm_tas_listcmds", ITEMDRAW_DISABLED );
    
    menu.Display( client, MENU_TIME_FOREVER );
    
    return Plugin_Handled;
}
