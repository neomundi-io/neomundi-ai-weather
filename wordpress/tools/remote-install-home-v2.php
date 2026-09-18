<?php
/**
 * Run ONCE on neomundi.cloud, after upload-home-v2-plugin.py has put the
 * plugin's 6 files on the server. Activates ai-weather-blocks-preview,
 * then creates the /home-v2/ test page as a DRAFT — never published,
 * never touching the active front page, the active theme, or any menu.
 * Mirrors the safety guards already used by remote-install.php /
 * remote-activate.php (site/theme match check, single administrator
 * context, no destructive default).
 */
error_reporting(0);
$root = '/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud';
if (realpath('.') !== $root) exit(2);
$_SERVER['HTTP_HOST'] = 'neomundi.cloud';
$_SERVER['SERVER_NAME'] = 'neomundi.cloud';
$_SERVER['HTTPS'] = 'on';
$_SERVER['SERVER_PORT'] = '443';
$_SERVER['REQUEST_URI'] = '/';
$_SERVER['REQUEST_METHOD'] = 'GET';
define('DISABLE_WP_CRON', true);
define('WP_USE_THEMES', false);
require $root . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

if (home_url() !== 'https://neomundi.cloud' || site_url() !== 'https://neomundi.cloud' || get_option('stylesheet') !== 'ai-weather') {
    exit("STOP: site/theme mismatch.\n");
}
$admins = get_users(['role' => 'administrator', 'number' => 1, 'fields' => 'ID']);
if (!$admins) exit("STOP: no administrator.\n");
wp_set_current_user($admins[0]);

$plugin = 'ai-weather-blocks-preview/ai-weather-blocks-preview.php';
$installed = get_plugins();
if (!isset($installed[$plugin])) {
    exit("STOP: plugin files not found at wp-content/plugins/$plugin — run upload-home-v2-plugin.py first.\n");
}

if (get_page_by_path('home-v2')) {
    exit("STOP: a page with slug 'home-v2' already exists. Nothing created, nothing activated further.\n");
}

$was_active = is_plugin_active($plugin);
if (!$was_active) {
    $activation = activate_plugin($plugin);
    if (is_wp_error($activation)) exit('STOP: activation failed: ' . $activation->get_error_message() . "\n");
}

// Read the exact registered pattern content rather than re-parsing the
// plugin's PHP — guarantees this uses whatever the active plugin code
// actually registers, not a copy pasted into this script.
$registry = WP_Block_Patterns_Registry::get_instance();
if (!$registry->is_registered('ai-weather-preview/home-v2-full-page')) {
    exit("STOP: pattern not registered — plugin did not activate as expected.\n");
}
$content = $registry->get_registered('ai-weather-preview/home-v2-full-page')['content'];

$id = wp_insert_post([
    'post_type'    => 'page',
    'post_status'  => 'draft', // never auto-published, regardless of any other setting
    'post_title'   => 'AI Weather Home V2',
    'post_name'    => 'home-v2',
    'post_content' => wp_slash($content),
], true);
if (is_wp_error($id)) exit('STOP: page creation failed: ' . $id->get_error_message() . "\n");

$lang_set = null;
if (function_exists('pll_set_post_language')) {
    pll_set_post_language($id, 'en');
    $lang_set = 'en';
}

echo json_encode([
    'plugin_active'             => is_plugin_active($plugin),
    'plugin_was_already_active' => $was_active,
    'page_id'                   => $id,
    'page_status'               => get_post_status($id),
    'page_slug'                 => get_post_field('post_name', $id),
    'polylang_language_set'     => $lang_set,
    'front_page_untouched'      => get_option('page_on_front'),
    'show_on_front_untouched'   => get_option('show_on_front'),
], JSON_PRETTY_PRINT) . "\n";
