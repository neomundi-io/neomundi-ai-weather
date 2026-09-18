<?php
if (!defined('ABSPATH')) { exit; }

/**
 * Six section patterns rebuilding the home page ("home" key in
 * theme/ai-weather/inc/catalog.json") as plain, fully editable core
 * blocks — no data-en/data-fr attributes, no custom render_callback
 * holding text, no templateLock. Each is independently insertable,
 * movable, duplicable and removable. English copy only, taken verbatim
 * from the live theme's catalog.json / templates/home.html so the /en/
 * test page is visually faithful.
 *
 * "AI Weather — Home v2 (full page, EN)" below is a convenience pattern
 * that concatenates all six in order for a one-shot insert when the test
 * page is first created; every section remains a separate, ordinary
 * block afterwards.
 */
add_action('init', function () {

    register_block_pattern_category('ai-weather', ['label' => __('AI Weather', 'ai-weather-preview')]);

    $hero = <<<'HTML'
<!-- wp:group {"className":"aw-hero","align":"full"} -->
<div class="wp-block-group alignfull aw-hero"><!-- wp:paragraph {"className":"aw-eyebrow"} -->
<p class="aw-eyebrow">GLOBAL AI WEATHER STATION · CONTROLTOWER AI</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":1} -->
<h1 class="wp-block-heading">AI Weather™ is the daily weather report for AI behavior.</h1>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Every day, the ControlTower AI instrument asks the same challenging question 23 times, followed by a second question 7 times, to each of the 12 AI systems in the panel. It then compares their responses with one another and over time.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph -->
<p>AI Weather™ publishes a simple reading of their current condition, stability, variations and observed behavioral drift.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"className":"aw-alert"} -->
<p class="aw-alert">An AI system can change, drift or make mistakes without it being immediately visible.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph -->
<p>We created AI Weather™ to help everyone read these changes more clearly, strengthen their judgment and use AI systems with greater discernment.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"className":"aw-rigor-note"} -->
<p class="aw-rigor-note">We observe and measure. We do not certify, guarantee or predict anything that has not been demonstrated.</p>
<!-- /wp:paragraph -->

<!-- wp:buttons -->
<div class="wp-block-buttons"><!-- wp:button -->
<div class="wp-block-button"><a class="wp-block-button__link wp-element-button" href="#">View today's AI Weather™ →</a></div>
<!-- /wp:button --></div>
<!-- /wp:buttons --></div>
<!-- /wp:group -->
HTML;

    $levels = <<<'HTML'
<!-- wp:group {"className":"aw-levels","align":"full"} -->
<div class="wp-block-group alignfull aw-levels"><!-- wp:paragraph {"className":"aw-eyebrow aw-center"} -->
<p class="aw-eyebrow aw-center">READ THE WEATHER</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":2,"textAlign":"center"} -->
<h2 class="wp-block-heading has-text-align-center">Four levels to guide attention. Never replace judgment.</h2>
<!-- /wp:heading -->

<!-- wp:paragraph {"className":"aw-levels-intro","align":"center"} -->
<p class="aw-levels-intro has-text-align-center">Each color indicates the level of behavioral variation observed. It helps people understand where to focus their attention without making the decision for them.</p>
<!-- /wp:paragraph -->

<!-- wp:columns {"className":"aw-levels-grid"} -->
<div class="wp-block-columns aw-levels-grid"><!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"className":"aw-level-card"} -->
<div class="wp-block-group aw-level-card"><!-- wp:paragraph {"className":"aw-dot aw-dot-green"} -->
<p class="aw-dot aw-dot-green">●</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Standard</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Observed behavior remains within its expected range for this period.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"className":"aw-level-card"} -->
<div class="wp-block-group aw-level-card"><!-- wp:paragraph {"className":"aw-dot aw-dot-yellow"} -->
<p class="aw-dot aw-dot-yellow">●</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Heightened attention</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>A variation has been observed. It should be monitored across the next observations.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"className":"aw-level-card"} -->
<div class="wp-block-group aw-level-card"><!-- wp:paragraph {"className":"aw-dot aw-dot-orange"} -->
<p class="aw-dot aw-dot-orange">●</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Reinforced attention</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>A more marked deviation has been measured. A careful reading of the context and results is recommended.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"className":"aw-level-card"} -->
<div class="wp-block-group aw-level-card"><!-- wp:paragraph {"className":"aw-dot aw-dot-red"} -->
<p class="aw-dot aw-dot-red">●</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Critical attention</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>A significant disruption in observed behavior has been detected. It requires deeper human analysis.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:column --></div>
<!-- /wp:columns -->

<!-- wp:paragraph {"className":"aw-levels-note"} -->
<p class="aw-levels-note">These levels describe a behavioral condition observed at a given moment. They are not a certification, a guarantee or a definitive judgment about an AI system.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group -->
HTML;

    $quiz = <<<'HTML'
<!-- wp:group {"className":"aw-dark-section","align":"full"} -->
<div class="wp-block-group alignfull aw-dark-section"><!-- wp:columns -->
<div class="wp-block-columns"><!-- wp:column -->
<div class="wp-block-column"><!-- wp:paragraph {"className":"aw-eyebrow"} -->
<p class="aw-eyebrow">YOUR CALL</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Can you spot the drift?</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Every day, a real situation from our observations becomes a simple question. Compare the signals, tell a normal variation from a drift, and put your judgment to the test against real AI behavior.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph -->
<p>One question. Two signals. Your turn to read the weather.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:ai-weather-preview/quiz-widget /--></div>
<!-- /wp:column --></div>
<!-- /wp:columns --></div>
<!-- /wp:group -->
HTML;

    $paths = <<<'HTML'
<!-- wp:group {"className":"aw-paths","align":"full"} -->
<div class="wp-block-group alignfull aw-paths"><!-- wp:paragraph {"className":"aw-eyebrow"} -->
<p class="aw-eyebrow">GO FURTHER</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":2} -->
<h2 class="wp-block-heading">Understand, observe, test, use.</h2>
<!-- /wp:heading -->

<!-- wp:paragraph {"className":"aw-paths-intro"} -->
<p class="aw-paths-intro">AI Weather™ can be read at several levels. Four paths to go further, from a first look to a closer reading.</p>
<!-- /wp:paragraph -->

<!-- wp:columns {"className":"aw-paths-grid"} -->
<div class="wp-block-columns aw-paths-grid"><!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"className":"aw-path-card aw-path-blue"} -->
<div class="wp-block-group aw-path-card aw-path-blue"><!-- wp:paragraph {"className":"aw-path-num"} -->
<p class="aw-path-num">01</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"className":"aw-eyebrow"} -->
<p class="aw-eyebrow">UNDERSTAND</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Why an AI's behavior can change</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>What AI Weather™ actually measures, the four attention levels, and the fixed protocol behind every published condition.</p>
<!-- /wp:paragraph -->

<!-- wp:buttons -->
<div class="wp-block-buttons"><!-- wp:button {"className":"is-style-outline"} -->
<div class="wp-block-button is-style-outline"><a class="wp-block-button__link wp-element-button" href="#">How it works →</a></div>
<!-- /wp:button --></div>
<!-- /wp:buttons --></div>
<!-- /wp:group --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"className":"aw-path-card aw-path-cyan"} -->
<div class="wp-block-group aw-path-card aw-path-cyan"><!-- wp:paragraph {"className":"aw-path-num"} -->
<p class="aw-path-num">02</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"className":"aw-eyebrow"} -->
<p class="aw-eyebrow">OBSERVE</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Today's real results</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>The full observation wall, system by system, with each panel AI's current condition and recent trend.</p>
<!-- /wp:paragraph -->

<!-- wp:buttons -->
<div class="wp-block-buttons"><!-- wp:button {"className":"is-style-outline"} -->
<div class="wp-block-button is-style-outline"><a class="wp-block-button__link wp-element-button" href="#">View today's weather →</a></div>
<!-- /wp:button --></div>
<!-- /wp:buttons --></div>
<!-- /wp:group --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"className":"aw-path-card aw-path-violet"} -->
<div class="wp-block-group aw-path-card aw-path-violet"><!-- wp:paragraph {"className":"aw-path-num"} -->
<p class="aw-path-num">03</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"className":"aw-eyebrow"} -->
<p class="aw-eyebrow">TEST</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Your own reading of the signals</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Compare two real signals and put your judgment to the test against an actual observed variation, with no easy answer.</p>
<!-- /wp:paragraph -->

<!-- wp:buttons -->
<div class="wp-block-buttons"><!-- wp:button {"className":"is-style-outline"} -->
<div class="wp-block-button is-style-outline"><a class="wp-block-button__link wp-element-button" href="#quiz">Take today's quiz →</a></div>
<!-- /wp:button --></div>
<!-- /wp:buttons --></div>
<!-- /wp:group --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"className":"aw-path-card aw-path-pink"} -->
<div class="wp-block-group aw-path-card aw-path-pink"><!-- wp:paragraph {"className":"aw-path-num"} -->
<p class="aw-path-num">04</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"className":"aw-eyebrow"} -->
<p class="aw-eyebrow">USE</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Install and share AI Weather™</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Real, embeddable formats reading the same daily measurement: full wall, Core Panel, bar, sidebar, individual badge, and the quiz.</p>
<!-- /wp:paragraph -->

<!-- wp:buttons -->
<div class="wp-block-buttons"><!-- wp:button {"className":"is-style-outline"} -->
<div class="wp-block-button is-style-outline"><a class="wp-block-button__link wp-element-button" href="#">Explore the widgets →</a></div>
<!-- /wp:button --></div>
<!-- /wp:buttons --></div>
<!-- /wp:group --></div>
<!-- /wp:column --></div>
<!-- /wp:columns --></div>
<!-- /wp:group -->
HTML;

    $instrument = <<<'HTML'
<!-- wp:group {"className":"aw-dark-section","align":"full"} -->
<div class="wp-block-group alignfull aw-dark-section"><!-- wp:columns -->
<div class="wp-block-columns"><!-- wp:column -->
<div class="wp-block-column"><!-- wp:paragraph {"className":"aw-eyebrow"} -->
<p class="aw-eyebrow">BEHIND THE WEATHER</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":2} -->
<h2 class="wp-block-heading">A public instrument, an independent measurement.</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>AI Weather™ is published by ControlTower AI, the public face of NeoMundi. Every measurement is produced by the same runtime metrology layer, then hash-chained into a timestamped capsule, verifiable independently of ControlTower AI itself.</p>
<!-- /wp:paragraph -->

<!-- wp:paragraph {"className":"aw-disclaimer"} -->
<p class="aw-disclaimer">This is not a ranking. AI Weather™ does not determine which AI is "best", and does not judge whether an individual answer is true or false. Every view shows an observed condition, never a competitive score.</p>
<!-- /wp:paragraph -->

<!-- wp:buttons -->
<div class="wp-block-buttons"><!-- wp:button {"className":"is-style-outline"} -->
<div class="wp-block-button is-style-outline"><a class="wp-block-button__link wp-element-button" href="#">How it works →</a></div>
<!-- /wp:button -->

<!-- wp:button {"className":"is-style-outline"} -->
<div class="wp-block-button is-style-outline"><a class="wp-block-button__link wp-element-button" href="https://neomundi.org/methodology" target="_blank" rel="noopener">Methodology →</a></div>
<!-- /wp:button -->

<!-- wp:button {"className":"is-style-outline"} -->
<div class="wp-block-button is-style-outline"><a class="wp-block-button__link wp-element-button" href="#">Available data →</a></div>
<!-- /wp:button -->

<!-- wp:button {"className":"is-style-outline"} -->
<div class="wp-block-button is-style-outline"><a class="wp-block-button__link wp-element-button" href="https://neomundi.org/" target="_blank" rel="noopener">NeoMundi Observatory →</a></div>
<!-- /wp:button --></div>
<!-- /wp:buttons --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:table {"className":"aw-instrument-table"} -->
<figure class="wp-block-table aw-instrument-table"><table><tbody>
<tr><td>Protocol</td><td>WEATHER-SENTINEL v0.2</td></tr>
<tr><td>Panel size</td><td>12 systems</td></tr>
<tr><td>Expected obs. / system</td><td>30</td></tr>
<tr><td>Panel coverage today</td><td>—</td></tr>
<tr><td>Last measurement (UTC)</td><td>—</td></tr>
<tr><td>Consecutive capsules</td><td>—</td></tr>
</tbody></table></figure>
<!-- /wp:table --></div>
<!-- /wp:column --></div>
<!-- /wp:columns --></div>
<!-- /wp:group -->
HTML;

    $newsletter = <<<'HTML'
<!-- wp:group {"className":"aw-newsletter","align":"full"} -->
<div class="wp-block-group alignfull aw-newsletter"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Get AI Weather™ every day</h3>
<!-- /wp:heading -->

<!-- wp:paragraph {"className":"aw-newsletter-note"} -->
<p class="aw-newsletter-note">Today's level and any notable drift, straight to your inbox. This form isn't connected to a sending service yet: it shows the intended interface for the Daily Brief.</p>
<!-- /wp:paragraph -->

<!-- wp:buttons -->
<div class="wp-block-buttons"><!-- wp:button -->
<div class="wp-block-button"><a class="wp-block-button__link wp-element-button" href="#">Subscribe</a></div>
<!-- /wp:button --></div>
<!-- /wp:buttons --></div>
<!-- /wp:group -->
HTML;

    register_block_pattern('ai-weather-preview/hero', [
        'title'       => __('AI Weather — Hero', 'ai-weather-preview'),
        'description' => __('Opening section: eyebrow, headline, intro paragraphs, and the main CTA.', 'ai-weather-preview'),
        'categories'  => ['ai-weather'],
        'content'     => $hero,
    ]);

    register_block_pattern('ai-weather-preview/levels', [
        'title'       => __('AI Weather — Four Levels', 'ai-weather-preview'),
        'description' => __('The four attention-level cards (Standard / Heightened / Reinforced / Critical).', 'ai-weather-preview'),
        'categories'  => ['ai-weather'],
        'content'     => $levels,
    ]);

    register_block_pattern('ai-weather-preview/quiz-teaser', [
        'title'       => __('AI Weather — Quiz Teaser (dark)', 'ai-weather-preview'),
        'description' => __('Dark section introducing the daily quiz, with the real live quiz widget embedded.', 'ai-weather-preview'),
        'categories'  => ['ai-weather'],
        'content'     => $quiz,
    ]);

    register_block_pattern('ai-weather-preview/paths', [
        'title'       => __('AI Weather — Four Paths (Go Further)', 'ai-weather-preview'),
        'description' => __('Understand / Observe / Test / Use — the four entry-point cards.', 'ai-weather-preview'),
        'categories'  => ['ai-weather'],
        'content'     => $paths,
    ]);

    register_block_pattern('ai-weather-preview/instrument', [
        'title'       => __('AI Weather — Instrument (dark)', 'ai-weather-preview'),
        'description' => __('Dark section: the measurement instrument, its links, and the protocol facts table.', 'ai-weather-preview'),
        'categories'  => ['ai-weather'],
        'content'     => $instrument,
    ]);

    register_block_pattern('ai-weather-preview/newsletter', [
        'title'       => __('AI Weather — Newsletter CTA', 'ai-weather-preview'),
        'description' => __('Closing section inviting sign-up to the Daily Brief.', 'ai-weather-preview'),
        'categories'  => ['ai-weather'],
        'content'     => $newsletter,
    ]);

    register_block_pattern('ai-weather-preview/home-v2-full-page', [
        'title'       => __('AI Weather — Home v2 (full page, EN)', 'ai-weather-preview'),
        'description' => __('All six sections in order, for a one-shot insert when creating the /en/ test page. Every section stays independently selectable, movable, duplicable and removable afterwards.', 'ai-weather-preview'),
        'categories'  => ['ai-weather'],
        'content'     => implode("\n\n", [$hero, $levels, $quiz, $paths, $instrument, $newsletter]),
    ]);
});
