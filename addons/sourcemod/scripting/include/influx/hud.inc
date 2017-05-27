#if defined _influx_hud_included
    #endinput
#endif
#define _influx_hud_included


#define INFLUX_LIB_HUD      "influx_hud"


native bool Influx_AddHUDMenuCmd( const char[] szCmd, const char[] szName );

forward void Influx_OnRequestHUDMenuCmds();



#define HIDEFLAG_TIMER              ( 1 << 0 )
#define HIDEFLAG_SIDEBAR            ( 1 << 1 ) // CSS = KeyHint, CSGO = Menu
#define HIDEFLAG_TIME               ( 1 << 2 )
#define HIDEFLAG_SPEED              ( 1 << 3 )
#define HIDEFLAG_MODENSTYLE         ( 1 << 4 )
#define HIDEFLAG_RUNNAME            ( 1 << 5 )
#define HIDEFLAG_PB_TIME            ( 1 << 6 )
#define HIDEFLAG_WR_TIME            ( 1 << 7 )
#define HIDEFLAG_PRACMODE           ( 1 << 8 )
#define HIDEFLAG_PAUSEMODE          ( 1 << 9 )
#define HIDEFLAG_SND_NORMAL         ( 1 << 10 )
#define HIDEFLAG_SND_PERSONAL       ( 1 << 11 )
#define HIDEFLAG_SND_BEST           ( 1 << 12 )
#define HIDEFLAG_CHAT_NORMAL        ( 1 << 13 )
#define HIDEFLAG_CHAT_PERSONAL      ( 1 << 14 )
#define HIDEFLAG_CHAT_BEST          ( 1 << 15 )
#define HIDEFLAG_HIDE_PLAYERS       ( 1 << 16 )
#define HIDEFLAG_HIDE_BOTS          ( 1 << 17 )
#define HIDEFLAG_BEAMS              ( 1 << 18 )
#define HIDEFLAG_VIEWMODEL          ( 1 << 19 )
#define HIDEFLAG_STRFSYNC           ( 1 << 20 )

#define DEF_HIDEFLAGS               0


native int Influx_GetClientHideFlags( int client );
native void Influx_SetClientHideFlags( int client, int flags );


public SharedPlugin __pl_influx_hud =
{
    name = INFLUX_LIB_HUD,
    file = INFLUX_LIB_HUD...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_hud_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetClientHideFlags" );
    MarkNativeAsOptional( "Influx_SetClientHideFlags" );
    
    MarkNativeAsOptional( "Influx_AddHUDMenuCmd" );
}
#endif