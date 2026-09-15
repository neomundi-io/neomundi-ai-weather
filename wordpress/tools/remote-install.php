<?php
error_reporting(0);
$root='/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud';
if(realpath('.')!==$root)exit(2);
$_SERVER['HTTP_HOST']='neomundi.cloud';$_SERVER['SERVER_NAME']='neomundi.cloud';$_SERVER['HTTPS']='on';$_SERVER['SERVER_PORT']='443';$_SERVER['REQUEST_URI']='/';$_SERVER['REQUEST_METHOD']='GET';
define('DISABLE_WP_CRON',true);define('DISALLOW_FILE_MODS',true);define('WP_USE_THEMES',false);
require $root.'/wp-load.php';
if(home_url()!=='https://neomundi.cloud'||site_url()!=='https://neomundi.cloud'||get_option('stylesheet')!=='ai-weather')exit("STOP: site/theme mismatch.\n");
add_filter('flush_rewrite_rules_hard','__return_false',PHP_INT_MAX);
$admins=get_users(['role'=>'administrator','number'=>1,'fields'=>'ID']);if(!$admins)exit("STOP: no administrator.\n");wp_set_current_user($admins[0]);
update_option('permalink_structure','/%postname%/');
$result=aw_install_content();if(is_wp_error($result)){echo 'STOP: '.$result->get_error_message()."\n";exit(3);}
flush_rewrite_rules(false);
$cache='not available';if(function_exists('wp_cache_clear_cache')){wp_cache_clear_cache();$cache='purged via wp_cache_clear_cache';}
$pages=[];foreach($result as $key=>$id)$pages[$key]=['id'=>$id,'url'=>get_permalink($id),'status'=>get_post_status($id),'language'=>function_exists('pll_get_post_language')?pll_get_post_language($id):null];
echo json_encode(['pages'=>$pages,'front'=>get_option('page_on_front'),'show_on_front'=>get_option('show_on_front'),'permalink_structure'=>get_option('permalink_structure'),'cache'=>$cache,'polylang_active'=>function_exists('pll_languages_list'),'blog_public'=>get_option('blog_public')],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES)."\n";
