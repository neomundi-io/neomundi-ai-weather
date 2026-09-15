<?php if (!defined('ABSPATH')) { exit; } get_header(); ?>
<?php if(have_posts()): while(have_posts()): the_post();
    $layout=aw_current_layout();
    if($layout){
        // The PHP template owns the visual composition. Gutenberg supplies values,
        // never the public list of editorial fields, even without its wrapper block.
        echo aw_render_layout($layout,parse_blocks(get_post_field('post_content',get_the_ID())));
    }else{the_content();}
endwhile; else: ?>
<main><h1><?php esc_html_e('Page unavailable','ai-weather'); ?></h1></main>
<?php endif; get_footer(); ?>
