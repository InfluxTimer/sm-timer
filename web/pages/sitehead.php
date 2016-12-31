<?php if ( !defined( '_INF' ) ) exit; ?>
<body>
	<div class="sitehead">
		<div class="sitehead-center-cont">
			<a href="index.php"><img class="sitehead-logo" src="img/inflogo.png"></a>
			<span class="search-container">
				<form class="search-form" action="search.php" method="get" required autocomplete="on">
					<input class="search-input" id="search-players" name="q" type="search" placeholder="Search for players"/>
					<button class="search-button">GO</button>
				</form>
			</span>
		</div>
	</div>
	<script type="text/javascript" src="js/search.js"></script>
	<div class="main-cont">