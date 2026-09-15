# Validation locale — 15 septembre 2026

## Résultat

Thème hybride AI Weather 0.1.0 prêt pour inspection du staging, sans SSH ni déploiement distant. ZIP : dist/ai-weather-0.1.0.zip (1 318 253 octets), 198 fichiers.

SHA-256 : `5ece3d799483655803d30fc4b66b0839490e7adbaf5bb8ec4833f6e0e9c31004`.

## Architecture et édition

Templates PHP WordPress, template parts HTML protégées, CSS du redesign et rendu dynamique ai-weather/layout. Celui-ci conserve la structure fonctionnelle et réinjecte les valeurs de **898 champs éditoriaux dans des blocs Gutenberg natifs** (titres, paragraphes, boutons pour les destinations, images). Navigation/footer ont une entrée Gutenberg commune. Aucun constructeur ni plugin tiers requis.

L'éditeur présente les champs nommés par section/langue ; il ne reproduit pas la composition visuelle du frontend. Le rendu final se vérifie avec Aperçu. La disposition des composants, les scripts et les données ne sont pas éditables librement.

## Environnements réellement observés

- WordPress 7.1 / PHP 8.5.10, thème monté depuis les sources, Playground local : contrôles frontend, responsive, widgets, langues, édition et comparaison visuelle.
- WordPress 6.6.7 / PHP 8.3.33, installation **du ZIP** dans une base neuve : activation, création des pages, relecture des 198 fichiers installés par SHA-256, édition EN/FR/SEO/liens/images et verrous Gutenberg.
- SQLite est fourni uniquement par Playground pour ces tests. Le serveur distant, ses plugins et sa configuration PHP/MySQL n'ont pas été inspectés.

## Vérifications réussies

| Contrôle | Résultat |
|---|---|
| Tests Python existants du manifeste | 13/13 |
| Fraîcheur du manifeste | 26 entrées conformes |
| Chaîne des capsules | 26/26 valides |
| Pages WordPress | 11 réponses HTTP 200, aucun placeholder de champ restant |
| JavaScript frontend | Aucune exception sur les 11 pages lors du parcours desktop |
| Responsive | Aucun débordement sur 11 pages desktop et 7 destinations mobiles à 390 px |
| Surfaces statiques / widgets | 22 pages HTML HTTP 200, aucune exception et aucun blocage Loading persistant |
| Today | 12 systèmes visibles, historique visible |
| Langues Today | 13 langues, historique visible, arabe RTL |
| Quiz | 7 questions jusqu'au résumé en EN, FR et ES |
| Gutenberg | Édition, enregistrement, rechargement et restauration des textes EN/FR, SEO, URL et image ; structure verrouillée |
| Fidélité desktop | Aucun écart > 1 px sur géométrie des H1, en-têtes et footers de Home, Today, How It Works, Stations, Widgets |
| Intégrité du livrable | Scripts JS analysables, quiz/télémétrie/mesures inchangés, références capsules et cache présentes |
| ZIP installé | 198 fichiers, aucune différence par rapport à l'inventaire |

Les captures et mesures visuelles utilisent les mêmes polices de secours dans les deux versions : Google Fonts a été bloqué dans le navigateur de test. Le contrôle de géométrie ne prétend pas à une identité pixel par pixel de chaque animation, ni à une certification sur appareils physiques.

Les tests Gutenberg sous 6.6.7 ont d'abord dépassé le délai en attendant networkidle. Ils passent en attendant le chargement du document puis la disponibilité du magasin de blocs. Une fixture locale bloque aussi les appels HTTP PHP de maintenance WordPress ; elle est absente du ZIP. Aucun correctif du thème n'a été nécessaire pour cette différence du harnais.

## Corrections de fonctionnement

- CTA d'en-tête masqué sous 640 px ; les mêmes destinations restent accessibles par le menu.
- Grille Widgets autorisée à rétrécir pour éviter le débordement mobile.
- topbar.html / sidebar.html récupérés dans Git, sans remplacer leurs formats par d'autres.
- weather-home-1180.html était tronqué au milieu du script. Fin restaurée depuis 0efb4fe, en conservant la date de mesure actuelle et son affichage.
- URL des ressources adaptées au thème et aux permaliens WordPress. Aperçus Widgets servis depuis le paquet local/staging.
- CSP de la station US transposée en en-tête HTTP, avec nonce pour les scripts WordPress et prise en compte des ressources autorisées.

## Télémétrie

Les deux scripts de télémétrie sont identiques à la référence par SHA-256. Le test observe 15 tentatives POST exécutées par le code original, puis interrompues par le navigateur avant le réseau, sans réponse simulée. Les widgets continuent de s'afficher. Le thème livré ne contient aucun blocage réseau.

Succès réel des pings et CORS : **non vérifiés**, conformément à l'interdiction d'intervenir sur la production. Depuis neomundi.cloud, vérifier OPTIONS puis POST vers widget-ping.php, le host_domain et la console. Si l'API utilise une liste d'origines, son exploitant devra y inclure https://neomundi.cloud ; une autorisation existante par * peut déjà suffire avec credentials omis. Ne pas modifier l'API depuis ce chantier.

## Exclusions contrôlées

Moteur privé, fichier/archives de secrets, AI_WEATHER_RUNNER.zip, clés, variables secrètes, raw/results/scored, sauvegardes, .git, node_modules, captures WordPress d'administration, archives et temporaires. Aucun motif de clé privée/API connu ni URL locale détecté dans le thème. Le contrôle ne repose pas seulement sur ces motifs : le ZIP provient d'une liste positive de fichiers publics.

## Points restants avant validation en ligne

- Version et configuration WordPress/PHP de neomundi.cloud inconnues ; chemin cible à confirmer après GO SSH.
- Données embarquées du 15 septembre : pas de synchronisation quotidienne automatique dans le thème. Actualiser uniquement les données publiques si nécessaire avant l'envoi.
- Topologie du globe absente de la source : fallback existant conservé ; +24 h toujours indisponible.
- Google Fonts, Open-Meteo, webcams et succès réel de la télémétrie à vérifier en ligne.
- Daily Brief reste un formulaire non connecté ; couverture éditoriale des langues inchangée.

## Installation proposée

Après GO CONNEXION SSH : inspection de neomundi.cloud et identification de la racine WordPress. Après GO DÉPLOIEMENT : sauvegarde du thème/base existants, installation dans le répertoire **wp-content/themes/ai-weather** de cette racine vérifiée, activation et assistant Apparence > Installation AI Weather. Aucun fichier système WordPress à remplacer.

Pour Vincent : transférer le thème, la base WordPress et uploads éventuel ; remplacer les URL avec un outil respectant les données sérialisées, vérifier les permaliens/caches, la télémétrie et la non-indexation. Les éditions Gutenberg ne sont pas contenues dans le ZIP seul. Le guide détaillé figure dans theme/ai-weather/README.md.
