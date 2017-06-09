#if defined _influx_prespeed_included
    #endinput
#endif
#define _influx_prespeed_included


#define INFLUX_LIB_PRESPEED		"influx_prespeed"


// Return != Plugin_Continue to not limit prespeed.
forward Action Influx_OnLimitClientPrespeed( int client, bool bUsedNoclip );


public SharedPlugin __pl_influx_prespeed =
{
    name = INFLUX_LIB_PRESPEED,
    file = INFLUX_LIB_PRESPEED...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_influx_prespeed_SetNTVOptional()
{
}
#endif