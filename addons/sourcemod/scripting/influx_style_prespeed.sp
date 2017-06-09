#include <sourcemod>

#include <influx/core>

#undef REQUIRE_PLUGIN
#include <influx/prespeed>


public Plugin myinfo =
{
    author = INF_AUTHOR,
    url = INF_URL,
    name = INF_NAME..." - Style - Prespeed",
    description = "",
    version = INF_VERSION
};

public void OnPluginStart()
{
    // CMDS
    RegConsoleCmd( "sm_prespeed", Cmd_Style_Prespeed, INF_NAME..." - Change your style to Prespeed." );
}

public void OnAllPluginsLoaded()
{
    if ( !Influx_AddStyle( STYLE_PRESPEED, "Prespeed", "Prespeed", "prespeed", true ) )
    {
        SetFailState( INF_CON_PRE..."Couldn't add style!" );
    }
}

public void OnPluginEnd()
{
    Influx_RemoveStyle( STYLE_PRESPEED );
}

public void Influx_OnRequestStyles()
{
    OnAllPluginsLoaded();
}

public Action Influx_OnSearchType( const char[] szArg, Search_t &type, int &value )
{
    if ( StrEqual( szArg, "prespeed", false ) )
    {
        value = STYLE_PRESPEED;
        type = SEARCH_STYLE;
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Cmd_Style_Prespeed( int client, int args )
{
    if ( !client ) return Plugin_Handled;
    
    
    Influx_SetClientStyle( client, STYLE_PRESPEED );
    
    return Plugin_Handled;
}

public Action Influx_OnCheckClientStyle( int client, int style, float vel[3] )
{
    if ( style != STYLE_PRESPEED ) return Plugin_Continue;
    
    return Plugin_Stop;
}

public Action Influx_OnLimitClientPrespeed( int client, bool bUsedNoclip )
{
    return ( Influx_GetClientStyle( client ) != STYLE_PRESPEED ) ? Plugin_Continue : Plugin_Stop;
}