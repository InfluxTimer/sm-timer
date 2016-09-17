stock Search_t ParseSearchArg( const char[] szArg, int &value )
{
    decl char_offset;
    decl tempval;
    
    
    if ( (char_offset = StrContains( szArg, "mapid=", false )) != -1 )
    {
        tempval = StringToInt( szArg[char_offset + 6] );
        
        if ( tempval <= 0 )
        {
            return SEARCH_INVALID;
        }
        
        value = tempval;
        return SEARCH_MAPID;
    }
    else if ( (char_offset = StrContains( szArg, "runid=", false )) != -1 )
    {
        tempval = StringToInt( szArg[char_offset + 6] );
        
        if ( tempval <= 0 )
        {
            return SEARCH_INVALID;
        }
        
        value = tempval;
        return SEARCH_RUNID;
    }
    else if ( (char_offset = StrContains( szArg, "map=", false )) != -1 )
    {
        if ( strlen( szArg ) > 4 )
        {
            value = char_offset + 4;
            
            return SEARCH_MAPNAME;
        }
        
        return SEARCH_INVALID;
    }
    else if ( (char_offset = StrContains( szArg, "name=", false )) != -1 )
    {
        if ( strlen( szArg ) > 5 )
        {
            value = char_offset + 5;
            
            return SEARCH_PLAYERNAME;
        }
        
        return SEARCH_INVALID;
    }
    
    // If nothing specific is found and it's a number, make it a run id.
    tempval = StringToInt( szArg );
    
    if ( tempval > 0 )
    {
        value = tempval;
        return SEARCH_RUNID;
    }
    
    // Attempt to find a name.
    int targets[1];
    char szTemp[1];
    bool bUseless;
    if ( ProcessTargetString(
        szArg,
        0,
        targets,
        sizeof( targets ),
        COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_BOTS,
        szTemp,
        sizeof( szTemp ),
        bUseless ) )
    {
        int client = targets[0];
        
        if ( IS_ENT_PLAYER( client ) && IsClientInGame( client ) && g_iClientId[client] > 0 )
        {
            value = g_iClientId[client];
            return SEARCH_UID;
        }
    }
    
    // Still didn't find anything. Ask other plugins for an answer.
    Search_t search = SEARCH_INVALID;
    value = 0;
    
    SearchType( szArg, search, value );
    
    if ( search != SEARCH_INVALID )
    {
        return search;
    }
    
    // Didn't find anything. Check for map prefixes.
    if (StrContains( szArg, "bhop_", false ) == 0
    ||  StrContains( szArg, "surf_", false ) == 0
    ||  StrContains( szArg, "kz_", false ) == 0 )
    {
        value = 0;
        return SEARCH_MAPNAME;
    }
    
    
    return SEARCH_INVALID;
}