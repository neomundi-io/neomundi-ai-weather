( function ( blocks, element, blockEditor, i18n ) {
	var el = element.createElement;
	var __ = i18n.__;
	var useBlockProps = blockEditor.useBlockProps;

	blocks.registerBlockType( 'ai-weather-preview/quiz-widget', {
		edit: function () {
			var blockProps = useBlockProps( { className: 'aw-quiz-widget-placeholder' } );
			return el(
				'div',
				blockProps,
				el( 'p', {}, __( 'AI Weather — live quiz widget (renders on the front end).', 'ai-weather-preview' ) )
			);
		},
		save: function () {
			return null; // Server-rendered — see inc/blocks.php render_callback.
		},
	} );
} )( window.wp.blocks, window.wp.element, window.wp.blockEditor, window.wp.i18n );
