<?php if ( !defined( '_INF' ) ) exit; ?>
			<div class="footer">
				<p>Influx Stats | <a target="_blank" href="https://influxtimer.com">www.influxtimer.com</a></p>
				<?php
				if ( INF_DEV && isset( $GLOBALS['inf_devfooter'] ) ) { echo "<p>{$GLOBALS['inf_devfooter']}</p>"; }
				?>
			</div>
		</div>
	</body>
</html>