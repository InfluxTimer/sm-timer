#define USE_LAGGEDMOVEMENTVALUE


#include "influx_style_tas/tas_shared.sp"

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