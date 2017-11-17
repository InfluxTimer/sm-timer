'use strict';
const input = document.getElementById( 'search-players' );

if ( input )
{
	input.value = getURLParamByName( 'q' );
}
