# Restauration visuelle canonique — AI Weather 0.2.0

## Résultat et périmètre

Le site https://neomundi.cloud/ sert maintenant les structures HTML canoniques de `controltowerai-wordpress-redesign`, avec un routeur par slug et un template public qui n'appelle jamais `the_content()`. Les titres, paragraphes, traductions, liens, images, en-têtes et pieds de page ne proviennent plus des champs Gutenberg. Les anciens champs, pages et révisions restent conservés dans la base ; leurs modifications ne sont pas appliquées au front-end pendant cette phase.

La phase 2 d'édition progressive n'a pas été engagée. `index_full.html` ne remplace ni l'accueil, ni le template global, ni Today.

## Références exactes

| Page | HTML dans le dossier canonique |
|---|---|
| Home | `index.html` |
| Widgets | `widgets.html` |
| How It Works | `how-it-works.html` |
| Station USA | `us-station.html` |
| Today | `today.html` |
| Stations | `stations.html` |
| For Media | `for-media.html` |
| About | `about.html` |
| Contact | `contact.html` |
| Daily Brief | `daily-brief.html` |

Les empreintes de ces dix fichiers sont enregistrées dans `validation/CANONICAL-SOURCE-MAP.json`. Le build lit directement le dossier canonique réel. Le fichier sauvegardé d'administration « Free AI Weather Widgets… » n'est pas une référence de page publique.

Il n'existe pas de `quiz.html` autonome dans ce dossier. La page Quiz conserve sa composition dédiée avec le header/footer Home et le widget public `widgets/quiz-public/daily.html`, dont les octets sont inchangés. Sa comparaison porte donc sur le composant original et le composant intégré, et non sur un fichier de page canonique inventé.

## Modifications

- Templates et fragments HTML régénérés sans jetons de champs éditoriaux, sans reformatage WordPress du corps technique.
- Routeur résolvant les slugs canoniques et l'accueil, indépendant des blocs et métadonnées Gutenberg, qui impose le template PHP approprié.
- Protection de secours du filtre de contenu : si une intégration WordPress demande le contenu d'une page gérée, elle reçoit la composition canonique, pas les champs bruts.
- Chemins de pages, assets, widgets et données raccordés avec les fonctions WordPress. Les CSS, scripts, langues, quiz et mesures d'origine sont conservés.
- Correction d'un écart visuel réel dans Widgets : la règle `min-width:0`, précédemment appliquée à toutes les largeurs, est limitée à 980 px et moins. Les colonnes desktop retrouvent exactement les dimensions du HTML local.
- `npm run build` utilise désormais `tools/build-canonical.cjs`. La vérification du paquet interdit tout `@@FIELD:` dans les templates publics et tout appel à `the_content()` dans le template principal.

## Ordre suivi et sauvegardes

Home et Widgets ont été restaurées et vérifiées **en ligne** avant la génération et le déploiement des autres pages. How It Works puis Station USA ont été comparées en premier dans le second groupe.

Nouveau point de retour privé, sans supprimer les précédents :

`/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/aw-repair-return-20260915-214448/`

- `database.sql` : 2 665 432 octets ; SHA-256 `0e0cb00d4497f24db972ba84e7df68b96f6d752cc6a16356aa59bbf09b6ba415`.
- `site-before.tar.gz` : 65 415 590 octets ; SHA-256 `b984f78f64ad651e88e908bd762d275120bbfcabd3992caed150a0f255b7bfe2`.
- Fichiers remplacés sauvegardés individuellement dans `changed-home-widgets/` et `changed-remaining-pages/`.

Les 198 fichiers du thème ont été contrôlés par taille et SHA-256 après chaque groupe de remplacement, puis une dernière fois après les tests. `wp-config.php`, `.htaccess` et `.user.ini` sont inchangés. Les pages éditoriales ont gardé leurs empreintes et leur date de modification. Cache purgé par `wp_cache_clear_cache()` ; aucun plugin, ancien thème ou upload remplacé. Aucune intervention sur controltowerai.io.

## Captures comparatives

Ouvrir `test-results/canonical-comparisons.html` : choix de la page et de la largeur, référence locale et WordPress côte à côte, liens vers les PNG originaux.

- Home et Widgets : `test-results/canonical-first-live/`.
- Huit autres pages : `test-results/canonical-rest-live/`.
- Quiz, comparaison du composant et captures complètes de la page : `test-results/canonical-components/`.

Chaque page HTML dispose de captures à 1440×1000 et 390×1000. Les références locales utilisent leurs dépendances publiques exactes via un serveur local ; seules les URL de transport des widgets sont adaptées pour ne pas appeler l'ancien hébergement. Polices Google réellement chargées. Les captures ne reposent pas sur un simple statut HTTP.

### Résultats mesurés

- 10 pages × 2 largeurs : aucun champ brut, aucun texte d'aide à l'édition, aucune exception JavaScript sur les pages WordPress contrôlées.
- Géométrie, typographie, couleurs et arrière-plans des principaux conteneurs : identiques à 1 px près, sauf l'ajustement mobile documenté de Widgets.
- Huit pages desktop statiques : aucun pixel dont l'écart de canal dépasse 20/255. Home, How It Works, Today, Stations, For Media, About, Contact et Daily Brief sont concernées.
- Widgets desktop : 0,1425 % des pixels au-delà de ce seuil, principalement dans le code d'intégration, dont l'URL locale et l'URL WordPress diffèrent. Colonnes, cartes et aperçu ont les mêmes dimensions.
- Station USA : aucun pixel au-delà de ce seuil **hors de la zone animée** ; le globe est capturé à des instants différents.
- Mobile : les HTML sources débordent horizontalement par leur CTA d'en-tête. Le thème conserve le masquage de ce CTA sous 640 px ; les destinations restent disponibles dans le menu. Sous le header, huit pages statiques n'ont aucun pixel au-delà du seuil dans le viewport commun de 390 px.
- Widgets mobile : grille réduite de 374 à 342 px pour tenir dans le viewport, aperçu de 336 à 304 px et environ 19 px supplémentaires en hauteur. Cette différence est explicite ; le thème ne reproduit pas le débordement horizontal de la source.

Ces résultats ne signifient pas une identité universelle sur tous navigateurs/appareils ou à tous les instants d'animation. Les tests ont été faits avec Chromium desktop et viewport mobile simulé.

## Fonctionnement conservé

- 11 pages sur desktop et mobile : aucune exception JS, aucun débordement du thème, aucun affichage de champs bruts.
- Six formats de widgets chargés, choix du français et du thème sombre vérifiés ; 13 langues proposées.
- Today : 12 systèmes visibles.
- Quiz terminé dans son iframe WordPress sur desktop et mobile, sept questions jusqu'au résultat.
- Pings réels observés à HTTP 200, `host_domain=neomundi.cloud`, CORS autorisé (`*`), aucune erreur CORS. Les scripts de télémétrie et le quiz n'ont pas été modifiés.

## Anomalies restantes, indépendantes du rendu éditorial

- Topologie du globe absente de la source : 404 conservé, globe de secours visible ; projection +24 h indisponible.
- Instantané public du 15 septembre. Après le passage au 16, certains widgets tentent `data/history/2026-09-16.json`, absent (404), puis continuent à afficher les données disponibles. Aucun moteur privé n'a été déployé ni aucune mesure fabriquée.
- Daily Brief reste un formulaire non raccordé, conformément à sa source HTML.

## Fichiers corrigés et livrable

La liste exacte des **35 fichiers du thème remplacés**, relative au dossier `wp-content/themes/`, est dans `validation/CANONICAL-CHANGED-FILES.txt`. La version JSON donne aussi leurs tailles et SHA-256. Les autres 163 fichiers du thème sont inchangés par rapport à 0.1.1.

ZIP final : `dist/ai-weather-0.2.0.zip` ; SHA-256 `ab9de6838033d2e8ea60d462d189d670ae060c2d94988bb08aa77dc31e45b7fc`. Le ZIP contient uniquement les 198 fichiers publics vérifiés. Les captures, sauvegardes et outils restent hors du livrable.

Pour revenir au code 0.1.1, restaurer d'abord les fichiers `changed-remaining-pages/`, puis `changed-home-widgets/` vers les chemins correspondants du thème neomundi.cloud, et purger le cache. Cet ordre est important pour `inc/content.php`, remplacé dans les deux étapes. Aucune restauration de base n'est nécessaire pour annuler cette modification de rendu.
