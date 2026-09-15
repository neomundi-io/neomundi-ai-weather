<?php if (!defined('ABSPATH')) { exit; } get_header(); ?>
<?php if(have_posts()): while(have_posts()): the_post(); the_content(); endwhile; else: ?>
<main><h1><?php esc_html_e('Page unavailable','ai-weather'); ?></h1></main>
<?php endif; get_footer(); ?>
