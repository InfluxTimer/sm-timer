function getURLParamByName( name )
{
	var url = window.location.href;
	
	name = name.replace( /[\[\]]/g, '\\$&' );
	
	var regex = new RegExp( '[?&]' + name + '(=([^&#]*)|&|#|$)' );
	res = regex.exec( url );
	
	if ( !res ) return null;
	
	if ( !res[2] ) return '';
	
	return decodeURIComponent( res[2].replace( /\+/g, ' ' ) );
}

function timerFancyTxt( element, txt, rate, nexttime, stop )
{
	var opacity = parseFloat( element.style.opacity );
	
	if ( !stop && opacity <= 0.0 )
	{
		element.innerHTML = txt;
		
		stop = true;
		rate = -rate;
		
		// We're done. No need to set opacity.
		if ( txt == '' ) return;
	}
	
	opacity = opacity + rate;
	
	element.style.opacity = opacity + rate;
	
	
	if ( stop && opacity >= 1.0 )
	{
		return;
	}
	
	setTimeout( timerFancyTxt, nexttime, element, txt, rate, nexttime, stop );
}

function setElementTxtFancy( element, txt, time )
{
	// Elements by default may not have opacity set.
	element.style.opacity = '1.0';
	
	var framerate = ( 1.0 / 18.0 );
	var nexttime = framerate * 1000.0;
	
	var rate = -(framerate / time) * 2.0;
	
	setTimeout( timerFancyTxt, nexttime, element, txt, rate, nexttime, false );
}

