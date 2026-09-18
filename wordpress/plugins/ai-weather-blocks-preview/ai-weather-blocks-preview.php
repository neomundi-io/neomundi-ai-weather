<?php
/**
 * Plugin Name: AI Weather — Blocks Preview
 * Description: Native Gutenberg patterns, color palette and typography presets for the AI Weather redesign test page. Registers optional patterns/blocks only — never edits, includes, or extends the active "ai-weather" theme, and never touches existing pages or content.
 * Version: 0.1.0
 * Author: NeoMundi
 * Text Domain: ai-weather-preview
 * License: GPL-2.0-or-later
 *
 * Scope note: nothing in this plugin runs on a page unless an editor
 * explicitly inserts one of its patterns or blocks. It is safe to
 * activate alongside the production "ai-weather" theme.
 */
if (!defined('ABSPATH')) { exit; }

define('AWP_DIR', __DIR__);
define('AWP_URL', plugin_dir_url(__FILE__));
define('AWP_VERSION', '0.1.0');

require_once __DIR__ . '/inc/theme-support.php';
require_once __DIR__ . '/inc/blocks.php';
require_once __DIR__ . '/inc/patterns.php';
