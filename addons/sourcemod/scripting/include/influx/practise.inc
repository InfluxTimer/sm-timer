#if defined _influx_practise_included
    #endinput
#endif
#define _influx_practise_included


#define INFLUX_LIB_PRACTISE      "influx_practise"


// Return != Plugin_Continue to stop practice mode.
forward Action Influx_OnClientPracticeStart( int client );


native bool Influx_IsClientPractising( int client );

// Return whether we were successful.
native bool Influx_StartPractising( int client );

native void Influx_EndPractising( int client );


#define IS_PRAC(%0,%1)      ( %0 && Influx_IsClientPractising(%1) )


public SharedPlugin __pl_influx_practise =
{
    name = INFLUX_LIB_PRACTISE,
    file = INFLUX_LIB_PRACTISE...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_practise_SetNTVOptional()
{
    MarkNativeAsOptional( "Influx_IsClientPractising" );
    
    MarkNativeAsOptional( "Influx_StartPractising" );
    MarkNativeAsOptional( "Influx_EndPractising" );
}
#endif