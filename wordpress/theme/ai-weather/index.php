<?php if (!defined('ABSPATH')) { exit; } get_header(); ?>
<?php $layout=aw_current_layout(); if($layout): echo aw_render_layout($layout,[]); else: ?>
<main><h1><?php esc_html_e('Page unavailable','ai-weather'); ?></h1></main>
<?php endif; get_footer(); ?>
