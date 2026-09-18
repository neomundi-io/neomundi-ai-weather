<?php
if (!defined('ABSPATH')) { exit; }

/**
 * Centralized design tokens for the preview patterns (constraint: styles
 * centralized in one place, not scattered/hardcoded per block). Every color
 * used by assets/patterns.css references one of these slugs via the
 * `--wp--preset--color-{slug}` custom property WordPress generates
 * automatically for each entry below — so a value only ever lives here.
 *
 * Values are sourced from the live theme's own tokens:
 * runtime/styles/themes.css (--nm-judgment-*, --nm-accent, --nm-text*)
 * and the inline --path-accent values on templates/home.html's four
 * "Go Further" cards.
 */
add_action('after_setup_theme', function () {
    add_theme_support('editor-color-palette', [
        ['name' => __('Judgment — Standard (green)', 'ai-weather-preview'),    'slug' => 'judgment-green',  'color' => '#22c55e'],
        ['name' => __('Judgment — Heightened (yellow)', 'ai-weather-preview'), 'slug' => 'judgment-yellow', 'color' => '#facc15'],
        ['name' => __('Judgment — Reinforced (orange)', 'ai-weather-preview'), 'slug' => 'judgment-orange', 'color' => '#fb923c'],
        ['name' => __('Judgment — Critical (red)', 'ai-weather-preview'),      'slug' => 'judgment-red',    'color' => '#b91c1c'],
        ['name' => __('Accent — Sky', 'ai-weather-preview'),                   'slug' => 'accent-sky',      'color' => '#378add'],
        ['name' => __('Path — Blue', 'ai-weather-preview'),                    'slug' => 'path-blue',       'color' => '#2f7dd8'],
        ['name' => __('Path — Cyan', 'ai-weather-preview'),                    'slug' => 'path-cyan',       'color' => '#22b8cf'],
        ['name' => __('Path — Violet', 'ai-weather-preview'),                  'slug' => 'path-violet',     'color' => '#8b5cf6'],
        ['name' => __('Path — Pink', 'ai-weather-preview'),                    'slug' => 'path-pink',       'color' => '#d6469b'],
        ['name' => __('Ink', 'ai-weather-preview'),                            'slug' => 'ink',             'color' => '#1c2733'],
        ['name' => __('Ink — Dim', 'ai-weather-preview'),                      'slug' => 'ink-dim',         'color' => '#5b6b7a'],
        ['name' => __('Surface — Soft', 'ai-weather-preview'),                 'slug' => 'surface-soft',    'color' => '#f6f9fc'],
        ['name' => __('Navy — Dark section background', 'ai-weather-preview'),'slug' => 'navy-dark',       'color' => '#0c1117'],
        ['name' => __('Navy — Dark section text', 'ai-weather-preview'),      'slug' => 'navy-text',       'color' => '#eef2f6'],
    ]);

    add_theme_support('editor-font-sizes', [
        ['name' => __('Small', 'ai-weather-preview'),   'slug' => 'small',   'size' => 15],
        ['name' => __('Base', 'ai-weather-preview'),    'slug' => 'base',    'size' => 17],
        ['name' => __('Medium', 'ai-weather-preview'),  'slug' => 'medium',  'size' => 21],
        ['name' => __('Large', 'ai-weather-preview'),   'slug' => 'large',   'size' => 28],
        ['name' => __('X-Large', 'ai-weather-preview'), 'slug' => 'x-large', 'size' => 44],
    ]);

    add_theme_support('appearance-tools');
    add_theme_support('align-wide');
});

add_action('wp_enqueue_scripts', function () {
    wp_enqueue_style(
        'ai-weather-preview-fonts',
        'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=IBM+Plex+Mono:wght@500;600&display=swap',
        [],
        null
    );
    wp_enqueue_style('ai-weather-preview', AWP_URL . 'assets/patterns.css', [], AWP_VERSION);
});

add_action('enqueue_block_editor_assets', function () {
    wp_enqueue_style(
        'ai-weather-preview-fonts',
        'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=IBM+Plex+Mono:wght@500;600&display=swap',
        [],
        null
    );
    wp_enqueue_style('ai-weather-preview', AWP_URL . 'assets/patterns.css', [], AWP_VERSION);
});
