enum struct ModeNStyleOverride_t
{
    char szSafeName[MAX_SAFENAME];

    int iId;

    int nOrder;

    char szOverrideName[64];
    char szOverrideShortName[64];

    bool bUseAdminFlags;
    int fAdminFlags;
}


ArrayList g_hModeOvers;
ArrayList g_hStyleOvers;


static void _Sort( int[] ids, int[] orders, int num )
{
    int i, j;
    
    bool bFinished = true;
    
    do
    {
        bFinished = true;
        
        for ( i = 0; i < num; i++ )
        {
            j = i + 1;
            
            if ( j >= num )
            {
                break;
            }
            
            if ( orders[j] > orders[i] )
            {
                int temp;

                temp = orders[j];
                orders[j] = orders[i];
                orders[i] = temp;
                
                temp = ids[j];
                ids[j] = ids[i];
                ids[i] = temp;
                
                
                bFinished = false;
            }
        }
    }
    while ( !bFinished );
}

static int _Find( ArrayList overs, int invalid_id, int id, const char[] sz = "", bool bUpdateId = false )
{
    int len = overs.Length;
    for ( int i = 0; i < len; i++ )
    {
        if ( id != invalid_id && overs.Get( i, ModeNStyleOverride_t::iId ) == id )
        {
            return i;
        }
        
        if ( sz[0] )
        {
            char temp[32];
            overs.GetString( i, temp, sizeof( temp ) );
            
            if ( StrEqual( sz, temp, false ) )
            {
                if ( bUpdateId ) overs.Set( i, id, ModeNStyleOverride_t::iId );
                
                return i;
            }
        }
    }

    return -1;
}

stock int FindModeOver( int id = MODE_INVALID, const char[] sz = "", bool bUpdateId = false )
{
    return _Find( g_hModeOvers, MODE_INVALID, id, sz, bUpdateId );
}

stock void SortModesArray()
{
    int nModes = g_hModes.Length;
    
    if ( nModes < 2 ) return;
    
    
    int[] ids = new int[nModes]; 
    
    SortModeIds( ids, nModes );
    
    
    for ( int i = 0; i < nModes; i++ )
    {
        int index = FindModeById( ids[i] );
        
        if ( index == -1 ) continue;
        
        if ( i == index ) continue;
        
        
        g_hModes.SwapAt( index, i );
    }
}

stock void SortModeIds( int[] ids, int nModes )
{
    int len = g_hModes.Length;
    
    if ( len != nModes ) return;
    
    
    int[] orders = new int[nModes];
    
    decl String:name[32];
    
    for ( int i = 0; i < len; i++ )
    {
        int id = g_hModes.Get( i, Mode_t::iId );
        
        GetModeSafeNameByIndex( i, name, sizeof( name ) );
        
        int j = FindModeOver( id, name, true );
        
        
        orders[i] = ( j != -1 ) ? g_hModeOvers.Get( j, ModeNStyleOverride_t::nOrder ) : 0;
        ids[i] = id;
    }
    
    _Sort( ids, orders, nModes );
}

stock void SetModeOverrides( int index )
{
    decl String:name[32];
    GetModeSafeNameByIndex( index, name, sizeof( name ) );
    
    int j = FindModeOver( g_hModes.Get( index, Mode_t::iId ), name, true );
    
    if ( j == -1 ) return;
    
    
    
    ModeNStyleOverride_t ovr;
    g_hModeOvers.GetArray( j, ovr );
    
    if ( ovr.szOverrideName[0] != 0 )
    {
        SetModeNameByIndex( index, ovr.szOverrideName );
    }
    
    if ( ovr.szOverrideShortName[0] != 0 )
    {
        SetModeShortNameByIndex( index, ovr.szOverrideShortName );
    }
    
    if ( ovr.bUseAdminFlags )
    {
        g_hModes.Set( index, ovr.fAdminFlags, Mode_t::fAdmFlags );
    }
}

stock int FindStyleOver( int id = STYLE_INVALID, const char[] sz = "", bool bUpdateId = false )
{
    return _Find( g_hStyleOvers, STYLE_INVALID, id, sz, bUpdateId );
}

stock void SortStyleIds( int[] ids, int nStyles )
{
    int len = g_hStyles.Length;
    
    if ( len != nStyles ) return;
    
    
    int[] orders = new int[nStyles];
    
    decl String:name[32];
    
    for ( int i = 0; i < len; i++ )
    {
        int id = g_hStyles.Get( i, Style_t::iId );
        
        GetStyleSafeNameByIndex( i, name, sizeof( name ) );
        
        int j = FindStyleOver( id, name, true );
        
        
        orders[i] = ( j != -1 ) ? g_hStyleOvers.Get( j, ModeNStyleOverride_t::nOrder ) : 0;
        ids[i] = id;
    }
    
    _Sort( ids, orders, nStyles );
}

stock void SortStylesArray()
{
    int nStyles = g_hStyles.Length;
    
    if ( nStyles < 2 ) return;
    
    
    int[] ids = new int[nStyles]; 
    
    SortStyleIds( ids, nStyles );
    
    
    for ( int i = 0; i < nStyles; i++ )
    {
        int index = FindStyleById( ids[i] );
        
        if ( index == -1 ) continue;
        
        if ( i == index ) continue;
        
        
        g_hStyles.SwapAt( index, i );
    }
}

stock void SetStyleOverrides( int index )
{
    decl String:name[32];
    GetStyleSafeNameByIndex( index, name, sizeof( name ) );
    
    int j = FindStyleOver( g_hStyles.Get( index, Style_t::iId ), name, true );
    
    if ( j == -1 ) return;
    
    
    ModeNStyleOverride_t ovr;
    g_hStyleOvers.GetArray( j, ovr );
    
    if ( ovr.szOverrideName[0] != 0 )
    {
        SetStyleNameByIndex( index, ovr.szOverrideName );
    }
    
    if ( ovr.szOverrideShortName[0] != 0 )
    {
        SetStyleShortNameByIndex( index, ovr.szOverrideShortName );
    }
    
    if ( ovr.bUseAdminFlags )
    {
        g_hStyles.Set( index, ovr.fAdminFlags, Style_t::fAdmFlags );
    }
}
