# AI Weather — thème WordPress hybride

Version 0.1.0. PHP 8.0+, WordPress 6.6+. Aucun plugin tiers obligatoire.

## Installation sur le staging

1. Sauvegarder la base WordPress et le thème actif.
2. Installer le ZIP via Apparence > Thèmes > Ajouter > Téléverser, puis activer AI Weather.
3. Ouvrir Apparence > Installation AI Weather et cliquer « Préparer les pages AI Weather ».
4. Le thème crée 11 pages et une entrée commune Navigation / Footer. Il configure Home comme accueil, sans écraser les pages existantes. Une collision de slug interrompt l'installation.
5. Vérifier les permaliens et les pages. Sur neomundi.cloud, l'installation demande la non-indexation du staging.

L'activation seule ne crée ni ne remplace de contenu. Le thème ne modifie pas les secrets, les certificats, wp-config.php ni les fichiers serveur.

## Modifier le wording

Dans Pages, ouvrir la page puis utiliser la vue en liste de Gutenberg : chaque bloc est nommé par section et langue. Les titres sont des blocs Titre ; les paragraphes et labels, des blocs Paragraphe ; les destinations, des blocs Bouton ; les images, des blocs Image.

- Modifier les textes EN et FR séparément ; ES existe uniquement lorsque la référence le fournit.
- Dans un bloc nommé « Lien », modifier la destination du lien. Le libellé visible du CTA se modifie dans son bloc de texte/traduction voisin, pas dans le titre indicatif du bloc Lien.
- Les champs SEO sont les deux premiers blocs de chaque page.
- Navigation et footer : Apparence > AI Weather — Navigation / Footer. Les champs identiques sont partagés entre les pages. Les variations présentes dans la référence restent distinctes.
- Les blocs conservent les révisions WordPress. Les champs non édités conservent leurs valeurs de référence.
- La vue Gutenberg est un éditeur de contenus nommés, pas une reproduction visuelle complète du frontend. Utiliser Aperçu pour le rendu final.

La structure est verrouillée. Les textes sont échappés à la sortie et les URL filtrées. Aucun script ni iframe ne provient de post_content.

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
