# Proposition Today — préparation, non activée

## Fichier réellement trouvé

Le dossier canonique `controltowerai-wordpress-redesign/` contient `index.html` (accueil) et `today.html` (Today actuellement intégré), mais aucun fichier `full-index` ou `index_full` à ce niveau. La recherche récursive trouve `index_full.html` dans le worktree et ses copies publiques. Le dossier parent du redesign contient également `index_full.html`.

Le candidat du **dossier parent** mesure 65 300 octets et porte le SHA-256 `efbc502ba852312ed15b7f4f44af7a4262ae0d2632687ce9f72b84122a203598`. Il est identique à `source-public/index_full.html`. Le fichier de la racine du worktree a une empreinte différente : il ne doit pas être choisi silencieusement. Une confirmation du chemin exact a été demandée. La capture évoquée n'est pas disponible dans les pièces jointes de cette intervention.

## Architecture prévue après confirmation visuelle

Un bloc dynamique dédié `ai-weather/observation-wall`, sans édition libre de son HTML ni de ses scripts, fournirait un composant isolé **à l'intérieur de Today**. Le template de Home continuerait à utiliser exclusivement le redesign `index.html`.

Le candidat est un document HTML complet, avec styles globaux, initialisation JavaScript et service worker. Un collage dans un bloc HTML Gutenberg risquerait les doubles IDs, les collisions CSS et la suppression des scripts. La solution préparée est un iframe de même origine, rendu par le bloc dynamique, sans bordure, avec titre accessible et hauteur adaptée au contenu. La sélection du composant serait explicite et facilement réversible vers le mur Today actuel ; aucune duplication de tout le template de page.

Le template Today devra appeler explicitement ce bloc dans un emplacement technique dédié. Ajouter simplement un bloc à la suite des champs éditoriaux ne suffit pas : le rendu PHP contrôlé lit ces champs comme des valeurs, pas comme une composition libre. Ce raccordement devra conserver le rendu visuel explicite et ne pas réintroduire un affichage brut par `the_content()`.

Le fichier candidat devrait rester sous `runtime/`, avec ses chemins relatifs : `styles/themes.css`, `scripts/themes.js`, `scripts/i18n.js`, `scripts/weather-data.js`, `config/wording.json`, manifeste, assets et données publiques. Le service worker garderait sa portée `runtime/` et ne contrôlerait pas les pages WordPress.

La hauteur devra être testée avec `ResizeObserver` dans le parent de même origine, en évitant une boucle due aux hauteurs minimales du document embarqué. Le menu, le hero éditorial et le footer de Today restent gérés par le thème ; seule la zone technique serait remplaçable. Les changements de langue/thème doivent être transmis via un contrat explicite au composant, en conservant son comportement responsive.

Le fichier candidat n'inclut pas directement les scripts `widget-telemetry.js` ou `quiz-telemetry.js`. Il ne faut donc pas prétendre avoir validé ses pings ni ajouter des événements simulés. Lors de l'intégration, identifier le mécanisme de télémétrie réellement requis et tester des pings réels depuis neomundi.cloud, tout en conservant les scripts de télémétrie existants des widgets. Aucune intervention sur le serveur API n'est prévue.

## Validation requise avant bascule

1. Confirmer le fichier et la capture de référence souhaités.
2. Préparer une prévisualisation locale du bloc dans Today, avec le fichier et ses dépendances publiques seulement.
3. Comparer la proposition et Today aux largeurs desktop/mobile : dimensions, hauteur de l'iframe, absence de double navigation, langues, données, détails interactifs, scripts, service worker et télémétrie.
4. Faire valider cette proposition visuelle avant de l'activer sur Today. Aucune modification de l'accueil à cette occasion.

État actuel : architecture et dépendances identifiées ; aucun bloc expérimental activé, aucun remplacement de Today, aucun nouveau fichier ajouté au livrable 0.1.1 pour cette proposition.
