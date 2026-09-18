<?php
if (!defined('ABSPATH')) { exit; }

/**
 * The one deliberately "encapsulated" piece: the live quiz widget iframe.
 * This is a dynamic (server-rendered) block, not a Custom HTML block with a
 * baked-in URL — its render_callback resolves the runtime path from
 * whichever theme is active via get_theme_file_uri('runtime'), exactly like
 * the current theme's own inc/setup.php does. That keeps it portable across
 * environments (staging today, production later) without hardcoding a host.
 *
 * Everything editorial around it (headings, paragraphs, links) is ordinary
 * core blocks — only this real embedded component stays a black box, per
 * the interoperability note already written for the US Station globe.
 */
add_action('init', function () {
    wp_register_script(
        'ai-weather-preview-editor',
        AWP_URL . 'assets/editor.js',
        ['wp-blocks', 'wp-element', 'wp-block-editor', 'wp-i18n'],
        AWP_VERSION,
        true
    );

    register_block_type('ai-weather-preview/quiz-widget', [
        'api_version'     => 3,
        'title'           => __('AI Weather — Quiz widget (live)', 'ai-weather-preview'),
        'category'        => 'embed',
        'icon'            => 'games',
        'supports'        => ['html' => false, 'customClassName' => true, 'multiple' => true],
        'editor_script'   => 'ai-weather-preview-editor',
        'render_callback' => 'awp_render_quiz_widget',
    ]);
});

function awp_render_quiz_widget() {
    $runtime = function_exists('get_theme_file_uri') ? get_theme_file_uri('runtime') : '';
    $src = esc_url($runtime . '/widgets/quiz-public/daily.html?theme=dark&lang=en');
    $fallback = esc_url($runtime . '/widgets/quiz-public/daily.html');
    return '<div class="aw-quiz-embed">'
        . '<iframe src="' . $src . '" loading="lazy" title="' . esc_attr__('Spot the drift: today\'s question', 'ai-weather-preview') . '" scrolling="no"></iframe>'
        . '<p class="aw-quiz-fallback">' . esc_html__('Quiz not loading?', 'ai-weather-preview') . ' '
        . '<a href="' . $fallback . '" target="_blank" rel="noopener">' . esc_html__('Try it here →', 'ai-weather-preview') . '</a></p>'
        . '</div>';
}
