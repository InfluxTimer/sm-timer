//#define USE_LAGGEDMOVEMENTVALUE

// Changing host_timescale affects everybody but helps with laggy timescale (CSGO). Use in LAN only.
//#define USE_SERVER_TIMESCALE


#include "influx_style_tas/tas_shared.sp"
#include "influx_style_tas/cmds.sp"
#include "influx_style_tas/file.sp"
#include "influx_style_tas/menus.sp"
#include "influx_style_tas/menus_hndlrs.sp"
#include "influx_style_tas/natives.sp"

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    if ( GetEngineVersion() != Engine_CSGO )
    {
        FormatEx( szError, error_len, "Bad engine version!" );
        
        return APLRes_SilentFailure;
    }
    
    
    
    RegPluginLibrary( INFLUX_LIB_STYLE_TAS );
    
    
    g_bLate = late;
    
    
    // NATIVES
    CreateNative( "Influx_GetClientTASTime", Native_GetClientTASTime );
    
    return APLRes_Success;
}
