public int Native_GetClientTASTime( Handle hPlugin, int nParms )
{
    return view_as<int>( GetClientApproxTime( GetNativeCell( 1 ) ) );
}