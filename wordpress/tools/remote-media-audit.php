<?php
error_reporting(0);$root='/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud';if(realpath('.')!==$root)exit(2);
$_SERVER['HTTP_HOST']='neomundi.cloud';$_SERVER['SERVER_NAME']='neomundi.cloud';$_SERVER['HTTPS']='on';$_SERVER['SERVER_PORT']='443';$_SERVER['REQUEST_URI']='/';$_SERVER['REQUEST_METHOD']='GET';
define('DISABLE_WP_CRON',true);define('DISALLOW_FILE_MODS',true);define('WP_USE_THEMES',false);require $root.'/wp-load.php';
if(home_url()!=='https://neomundi.cloud'||site_url()!=='https://neomundi.cloud')exit(3);
$id=get_option('aw_retired_for_media_id');$sitemap=apply_filters('wp_sitemaps_posts_query_args',['post_type'=>'page'],'page');
$report=['version'=>wp_get_theme()->get('Version'),'retired_status'=>get_post_status($id),'removed_from_installer'=>!isset(aw_catalog()['for-media']),'removed_from_page_map'=>!isset(get_option('aw_page_ids')['for-media']),'sitemap_enabled'=>wp_sitemaps_get_server()->sitemaps_enabled(),'sitemap_explicitly_excludes_page'=>in_array($id,$sitemap['post__not_in']??[]),'staging_noindex'=>get_option('blog_public')==='0','editorial_screen_callback_available'=>function_exists('aw_readers_admin'),'field_count'=>count(aw_readers_defaults())*2+count(aw_readers_urls())];
echo wp_json_encode($report,JSON_PRETTY_PRINT)."\n";
if($report['retired_status']!=='trash'||!$report['removed_from_installer']||!$report['removed_from_page_map']||!$report['sitemap_explicitly_excludes_page'])exit(4);
