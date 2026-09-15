# Préparation WordPress — AI Weather

Branche isolée : staging/neomundi-cloud-wordpress-20260915. Le dépôt de mesure reste sur main.

## Reproduire

```powershell
npm.cmd ci
node tools/build.cjs
node tools/verify.cjs
node tools/package.cjs
```

Les outils npm sont uniquement des dépendances de développement. Aucun node_modules n'entre dans le thème.

Le build utilise source-public, sauvegarde figée et choisie explicitement, jamais la racine entière. SOURCE-INVENTORY.json préserve ses empreintes initiales. topbar.html et sidebar.html ont ensuite été restaurés depuis Git ; leur provenance figure dans EXCLUSIONS.json. Ne pas relancer snapshot.cjs : il refuse d'écraser la référence.

Les fichiers PHP et JS propres à WordPress sont maintenus dans theme/ai-weather. Les structures du redesign sont générées depuis la référence, avec champs nommés dans inc/catalog.json. Éditer le wording dans WordPress ; ne pas remplacer la référence par un export WordPress pour régénérer les identifiants de champs. Pour une évolution structurelle, prévoir une migration explicite du catalogue et préserver les valeurs déjà éditées.

## WordPress local

```powershell
node node_modules/@wp-playground/cli/cli.js server --port=9400 --workers=2 --mount-dir theme/ai-weather /wordpress/wp-content/themes/ai-weather --blueprint=tools/local-blueprint.json --php=8.3
```

URL : http://127.0.0.1:9400. Playground fournit une installation locale temporaire avec SQLite. Cela ne préjuge pas de PHP, MySQL, des plugins ni des en-têtes de l'hébergement distant. Le blueprint est réservé à cette installation de test ; il active le thème et prépare les contenus.

## Contrôles

- tools/browser-check.cjs : pages desktop/mobile, erreurs JS et débordements.
- tools/editor-check.cjs : validité des blocs Gutenberg et diagnostic d'édition.
- tools/editing-roundtrip.cjs : édition EN/FR/SEO, sauvegarde, rechargement et restauration.
- tools/technical-check.cjs : widgets, quiz EN/FR/ES, observation du comportement en échec de télémétrie.
- tools/visual-compare.cjs : rendu de référence contre WordPress, à fontes de fallback identiques.
- tools/verify.cjs : exclusions, secrets, intégrité des données/quiz/télémétrie, syntaxe JS, dépendances du cache et capsules.
- tools/package.cjs : ZIP installable et vérification de chaque entrée par SHA-256.

Les tests navigateur utilisent le Playwright déjà installé sur ce poste. Ils autorisent uniquement localhost. Les requêtes externes sont interrompues au niveau du navigateur avant le réseau ; aucun succès API artificiel n'est renvoyé. Le livrable ne contient pas ce blocage. Les tests de données Python ont été exécutés hors ligne dans le dépôt source avec -B.

## Livrables

- dist/ai-weather-0.1.0.zip
- dist/ai-weather-0.1.0.zip.sha256
- dist/DEPLOYMENT-INVENTORY.json : chaque chemin du ZIP, taille et SHA-256.
- EXCLUSIONS.json : règles contrôlées lors du packaging.
- test-results/ : comptes rendus et captures locales, exclus du ZIP.

L'intégration utilise les mécanismes natifs documentés par WordPress : [blocs imbriqués verrouillés](https://developer.wordpress.org/block-editor/how-to-guides/block-tutorial/nested-blocks-inner-blocks/), [enregistrement des blocs](https://developer.wordpress.org/block-editor/reference-guides/block-api/block-registration/) et [structure des thèmes](https://developer.wordpress.org/themes/core-concepts/theme-structure/). Le contrôle CORS décrit dans le guide du thème suit le [fonctionnement du préflight](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS).

Aucune connexion SSH, aucun déploiement, aucun push et aucune intervention sur controltowerai.io pendant cette préparation.
