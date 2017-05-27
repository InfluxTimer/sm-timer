#if defined _influx_hud_draw_included
    #endinput
#endif
#define _influx_hud_draw_included


#define INFLUX_LIB_HUD_DRAW		"influx_hud_draw"


native void Influx_GetSecondsFormat_Timer( char[] sz, int len );
native void Influx_GetSecondsFormat_Sidebar( char[] sz, int len );

native float Influx_GetNextMenuTime( int client );
native void Influx_SetNextMenuTime( int client, float time );


// Add separator to string.
#define ADD_SEPARATOR(%0,%1)       if ( %0[0] != '\0' ) Format( %0, sizeof( %0 ), "%s"...%1, %0 )

// Add new line if we've already added something.
#define NEWLINE_CHECK(%0)       ( %0[0] != '\0' ) ? "\n" : ""


enum HudType_t
{
    HUDTYPE_TIMER = 0, // HintText
    HUDTYPE_SIDEBAR, // KeyHintText
    HUDTYPE_MENU,
    HUDTYPE_HUDMSG, // HudMsg
	
    HUDTYPE_MISC
};

forward Action Influx_ShouldDrawHUD( int client, int target, HudType_t hudtype );
forward Action Influx_OnDrawHUD( int client, int target, HudType_t hudtype );


stock void Inf_ShowKeyHintText( int client, const char[] sz )
{
    Handle hMsg = StartMessageOne( "KeyHintText", client );
    
    if ( hMsg != null )
    {
        BfWriteByte( hMsg, 1 );
        BfWriteString( hMsg, sz );
        
        EndMessage();
    }
}


public SharedPlugin __pl_influx_hud_draw =
{
    name = INFLUX_LIB_HUD_DRAW,
    file = INFLUX_LIB_HUD_DRAW...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_hud_draw_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_GetSecondsFormat_Timer" );
    MarkNativeAsOptional( "Influx_GetSecondsFormat_Sidebar" );
    
    MarkNativeAsOptional( "Influx_GetNextMenuTime" );
    MarkNativeAsOptional( "Influx_SetNextMenuTime" );
}
#endif