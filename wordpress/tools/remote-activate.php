<?php
error_reporting(0);
$root='/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud';
if(realpath('.')!==$root)exit(2);
$_SERVER['HTTP_HOST']='neomundi.cloud';$_SERVER['SERVER_NAME']='neomundi.cloud';$_SERVER['HTTPS']='on';$_SERVER['SERVER_PORT']='443';$_SERVER['REQUEST_URI']='/';$_SERVER['REQUEST_METHOD']='GET';
define('DISABLE_WP_CRON',true);define('DISALLOW_FILE_MODS',true);define('WP_USE_THEMES',false);
require $root.'/wp-load.php';
if(home_url()!=='https://neomundi.cloud'||site_url()!=='https://neomundi.cloud')exit("STOP: site mismatch.\n");
$backup=dirname($root,2).'/aw-return-20260915-201008';
if(!is_file($backup.'/database.sql')||!is_file($backup.'/site-before.tar.gz'))exit(3);
$before=[];foreach(['template','stylesheet','show_on_front','page_on_front','permalink_structure','active_plugins','polylang'] as $key)$before[$key]=get_option($key);
if(file_exists($backup.'/options-before.json'))exit("STOP: already activated.\n");
file_put_contents($backup.'/options-before.json',json_encode($before,JSON_PRETTY_PRINT));chmod($backup.'/options-before.json',0600);
add_filter('flush_rewrite_rules_hard','__return_false',PHP_INT_MAX);
switch_theme('ai-weather');
echo json_encode(['stylesheet'=>get_option('stylesheet'),'template'=>get_option('template'),'permalinks_before'=>$before['permalink_structure'],'polylang_languages'=>function_exists('pll_languages_list')?pll_languages_list(['fields'=>'slug']):null,'polylang_default'=>function_exists('pll_default_language')?pll_default_language():null],JSON_PRETTY_PRINT)."\n";
