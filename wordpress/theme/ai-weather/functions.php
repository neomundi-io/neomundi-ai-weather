<?php
if (!defined('ABSPATH')) { exit; }
require_once __DIR__ . '/inc/content.php';
require_once __DIR__ . '/inc/setup.php';
require_once __DIR__ . '/inc/readers.php';
// The canonical page router overrides inherited page templates and never exposes
// post_content. Gutenberg remains stored for a later, separately validated phase.
add_filter('template_include',function($template){return aw_current_layout()?get_theme_file_path('index.php'):$template;},PHP_INT_MAX);
add_action('template_redirect',function(){if(aw_current_layout()){status_header(200);header('X-AI-Weather-Renderer: canonical-0.2.0');}},999);
add_filter('the_content',function($content){
    if(!is_admin()&&aw_current_layout())return aw_render_layout(aw_current_layout(),[]);
    return $content;
},PHP_INT_MAX);
function aw_csp_nonce(){static $nonce=null;if($nonce===null)$nonce=base64_encode(random_bytes(18));return $nonce;}
add_action('template_redirect',function(){
    if(aw_current_layout()!=='us-station')return;
    header("Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-".aw_csp_nonce()."'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: blob: https://secure.gravatar.com; connect-src 'self' https://api.open-meteo.com https://api.controltowerai.io; worker-src 'self' blob:; frame-src 'self' https://www.youtube-nocookie.com; object-src 'none'; base-uri 'self'; form-action 'self'");
});
add_filter('wp_inline_script_attributes',function($attrs){if(aw_current_layout()==='us-station')$attrs['nonce']=aw_csp_nonce();return $attrs;});
add_action('after_setup_theme', function () {
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
    add_theme_support('html5', ['search-form', 'gallery', 'caption', 'style', 'script']);
    add_theme_support('responsive-embeds');
});
add_action('init', function () {
    register_post_type('aw_shared', ['label'=>'AI Weather — Navigation / Footer','public'=>false,'show_ui'=>true,'show_in_menu'=>'themes.php','show_in_rest'=>true,'supports'=>['title','editor','revisions'],'capability_type'=>'page','map_meta_cap'=>true]);
    wp_register_script('aw-editor', get_theme_file_uri('assets/editor.js'), ['wp-blocks','wp-element','wp-block-editor','wp-components','wp-hooks'], '0.1.0', true);
    register_block_type('ai-weather/layout', [
        'api_version'=>3,'title'=>'AI Weather — contenu éditorial protégé','category'=>'design',
        'attributes'=>['layout'=>['type'=>'string','default'=>'home']],
        'supports'=>['html'=>false,'multiple'=>false,'reusable'=>false,'inserter'=>false],
        'editor_script'=>'aw-editor',
        'render_callback'=>function($attrs,$content,$block){ return aw_render_layout($attrs['layout'] ?? 'home', $block->parsed_block['innerBlocks'] ?? []); }
    ]);
});
add_filter('register_block_type_args', function($args,$name){
    if(in_array($name,['core/paragraph','core/heading','core/button','core/image'],true)){$args['attributes']['awField']=['type'=>'string'];}
    return $args;
},10,2);
add_filter('block_editor_settings_all', function($settings,$context){
    if(!empty($context->post) && (get_post_meta($context->post->ID,'_aw_layout',true) || $context->post->post_type==='aw_shared')){
        $settings['canLockBlocks']=false;$settings['codeEditingEnabled']=false;$settings['templateLock']='all';
    }
    return $settings;
},10,2);
add_action('wp_enqueue_scripts',function(){
    $key=aw_current_layout(); if(!$key)return;
    $schema=aw_catalog()[$key];
    $version=wp_get_theme()->get('Version');
    foreach($schema['styles'] as $i=>$file){
        $url=str_contains($file,'@@')?aw_urls($file):(str_starts_with($file,'https://')?$file:get_theme_file_uri($file));
        // Google Fonts repeats the family parameter. Appending ver via older
        // WordPress query helpers drops Inter and silently changes typography.
        wp_enqueue_style('aw-page-'.$i,$url,[],str_starts_with($file,'https://')?null:$version);
    }
    wp_enqueue_style('aw-theme',get_stylesheet_uri(),[],$version);
    $prev=[];
    foreach($schema['scripts'] as $i=>$script){$handle='aw-script-'.$i;
        if(isset($script['src'])){wp_enqueue_script($handle,aw_urls($script['src']),$prev,'0.1.0',true);}
        else{wp_enqueue_script($handle,get_theme_file_uri('assets/page.js'),$prev,'0.1.0',true);wp_add_inline_script($handle,aw_urls(file_get_contents(get_theme_file_path($script['file']))));}
        $prev=[$handle];
    }
    wp_enqueue_script('aw-site-context',get_theme_file_uri('assets/site-context.js'),$prev,'0.1.0',true);
    wp_add_inline_script('aw-site-context','window.AW_SITE='.wp_json_encode(['home'=>home_url('/'),'runtime'=>get_theme_file_uri('runtime/'),'quiz'=>aw_page_url('quiz')]).';','before');
});
add_filter('pre_get_document_title',function($title){$key=aw_current_layout();if(!$key)return $title;$s=aw_catalog()[$key];$v=aw_page_values();return $v[$s['seoTitle']]??$s['title'];});
add_action('wp_head',function(){
    $key=aw_current_layout();if(!$key)return;$s=aw_catalog()[$key];$v=aw_page_values();$title=$v[$s['seoTitle']]??$s['title'];$desc=$v[$s['seoDescription']]??$s['description'];
    echo '<meta name="description" content="'.esc_attr($desc).'">' . "\n";
    echo '<meta property="og:title" content="'.esc_attr($title).'"><meta property="og:description" content="'.esc_attr($desc).'"><meta property="og:type" content="website"><meta property="og:url" content="'.esc_url(get_permalink()).'">' . "\n";
    echo '<link rel="icon" href="'.esc_url(get_theme_file_uri('runtime/assets/favicon.ico')).'">' . "\n";
});
