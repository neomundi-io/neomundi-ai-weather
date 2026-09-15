# AI Weather — thème WordPress hybride

Version 0.2.0. PHP 8.0+, WordPress 6.6+. Aucun plugin tiers obligatoire.

## Installation sur le staging

1. Sauvegarder la base WordPress et le thème actif.
2. Installer le ZIP via Apparence > Thèmes > Ajouter > Téléverser, puis activer AI Weather.
3. Ouvrir Apparence > Installation AI Weather et cliquer « Préparer les pages AI Weather ».
4. Le thème crée 11 pages et une entrée commune Navigation / Footer. Il configure Home comme accueil, sans écraser les pages existantes. Une collision de slug interrompt l'installation.
5. Vérifier les permaliens et les pages. Sur neomundi.cloud, l'installation demande la non-indexation du staging.

L'activation seule ne crée ni ne remplace de contenu. Le thème ne modifie pas les secrets, les certificats, wp-config.php ni les fichiers serveur.

## Phase 1 — rendu canonique, édition publique suspendue

Version 0.2.0 : chaque page publique est rendue depuis son HTML canonique du dossier `controltowerai-wordpress-redesign`. Le routeur par slug impose la composition correspondante. Il ne lit pas les champs Gutenberg, et le template public n'appelle jamais `the_content()`.

Les anciens champs et révisions restent conservés dans WordPress, mais leurs modifications ne sont pas appliquées au site pendant cette phase. Les titres, textes, traductions, liens, images, navigation et footer proviennent des fichiers HTML canoniques. La réactivation progressive de l'édition attend une validation visuelle explicite et un raccordement champ par champ.

Home utilise `index.html`, Widgets `widgets.html`, Today `today.html`, Station USA `us-station.html`. `index_full.html` n'est jamais utilisé comme template global ou comme accueil.

Pour construire le thème : `npm run build` depuis le dossier `wordpress`, puis `node tools/package.cjs`. Le build lit directement les dix fichiers HTML du dossier canonique, conserve leurs structures et extrait leurs CSS/scripts. Les chemins publics sont raccordés par les fonctions WordPress. Les mesures, widgets, quiz et scripts de télémétrie du runtime restent inchangés.

## Organisation du thème

- header.php, footer.php, page.php, front-page.php, index.php : cycle WordPress natif.
- templates/*.html et template-parts/*.html : structure immuable du redesign.
- inc/catalog.json : inventaire des champs éditoriaux et ressources par page.
- inc/content.php : rendu dynamique du bloc ai-weather/layout avec ses blocs Gutenberg natifs.
- inc/setup.php : installation explicite, sans écrasement des pages existantes.
- assets/pages : CSS d'origine et scripts contrôlés par le code, raccordés aux URL WordPress.
- runtime : widgets statiques, quiz public, données, traductions et télémétrie.

Les URL du thème et des pages sont résolues avec les fonctions WordPress. Aucun domaine de staging n'est inscrit dans les templates. Le quiz à sept questions et la télémétrie sont conservés ; le quiz historique non intégré n'est pas réactivé.

## Données et limites connues

Le ZIP contient l'instantané public du 15 septembre 2026 et les 26 capsules disponibles. Il n'exécute aucun moteur de mesure et n'ajoute aucune synchronisation quotidienne automatique. Actualiser les JSON et capsules publics par un paquet contrôlé si le staging doit afficher une nouvelle journée. Les dates de mesure réelles restent visibles.

Station US : la topologie géographique manque dans la source ; le globe utilise son fallback existant. La projection +24 h reste désactivée. Open-Meteo et les webcams YouTube restent des services externes.

Daily Brief : le formulaire original n'est connecté à aucun service d'envoi. Les textes techniques du quiz et du configurateur de widgets restent gérés par le code.

Le CTA de l'en-tête est masqué sous 640 px pour éviter le débordement mobile ; les destinations restent disponibles dans le menu. La grille du configurateur peut rétrécir sur mobile. La barre d'administration WordPress est prise en compte.

Les widgets topbar/sidebar sont restaurés depuis leurs dernières versions Git avant suppression. Le fichier weather-home-1180.html était tronqué : sa fin provient du commit 0efb4fe, avec conservation de la logique actuelle de date de mesure. Les mesures, seuils et pings ne sont pas modifiés.

## Télémétrie

runtime/scripts/widget-telemetry.js et quiz-telemetry.js conservent leurs octets sources, leur endpoint api.controltowerai.io et leur gestion des erreurs. Le thème ne désactive ni ne simule les pings. Le quiz public courant reste indépendant du moteur de quiz historique, conformément à la référence.

Depuis neomundi.cloud, ouvrir Widgets et inspecter le réseau : préflight OPTIONS éventuel, puis POST widget-ping.php. Vérifier host_domain, statut et console. Avec Content-Type application/json, l'API doit autoriser l'origine du staging et l'en-tête Content-Type. Si l'API accepte déjà toutes les origines avec *, aucun ajout spécifique n'est nécessaire. Sinon, son exploitant doit autoriser https://neomundi.cloud (et www uniquement s'il est réellement utilisé). Aucun réglage CORS de cette API n'est modifié par le thème.

## Migration par Vincent

Transférer le thème **et la base de données WordPress** (pages, post_content Gutenberg, métadonnées _aw_layout, options aw_page_ids/aw_shared_id et réglages de page d'accueil), ainsi que uploads si des images ont été ajoutées. Un transfert du ZIP seul ne transporte pas les textes édités.

Effectuer un remplacement sérialisé des URL de staging par celles de destination avec un outil WordPress adapté, puis régénérer les permaliens et vider les caches. Les scripts reconstruisent leurs URL depuis le domaine WordPress courant. Vérifier les snippets d'intégration déjà copiés à l'extérieur et réévaluer la non-indexation du site final. Sauvegarder avant migration ; ne pas exécuter l'assistant de création pour remplacer une base déjà migrée.

## Retour arrière

Réactiver le thème précédent et rétablir les réglages d'accueil enregistrés avant installation ; restaurer la base sauvegardée si nécessaire. Le thème ne supprime jamais de contenu lors de sa désactivation.
