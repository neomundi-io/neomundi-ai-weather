# Déploiement staging — 15 septembre 2026

## Résultat

Thème AI Weather 0.1.0 déployé et activé sur https://neomundi.cloud/ après les GO SSH et déploiement. Aucun accès ou changement effectué sur le site controltowerai.io. Les seuls appels à api.controltowerai.io sont les pings publics exécutés par les widgets pendant les tests autorisés.

Source : `theme/ai-weather/`. Destination : `/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud/wp-content/themes/ai-weather/`.

Les 198 fichiers ont été envoyés par SFTP dans un dossier inexistant auparavant, sans remplacement. Tailles, SHA-256 et ensemble exact des fichiers vérifiés avant activation et après les tests. ZIP inchangé : `5ece3d799483655803d30fc4b66b0839490e7adbaf5bb8ec4833f6e0e9c31004`.

## Point de retour

Répertoire privé, hors racine publique : `/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/aw-return-20260915-201008/`.

- `database.sql` : 2 165 467 octets, SHA-256 `25699d6f9de07f1c0613afef18d479cd69a8c9546e1ea530a0a8729eb549164e`.
- `site-before.tar.gz` : 64 112 053 octets, SHA-256 `a29a62c027dc068183c4d77ecf43cc190cf8a3216a592d0badeb8b594cdb6ca3`.
- `manifest.json` : empreintes et chemins sauvegardés.
- `options-before.json` : réglages WordPress avant activation.

Répertoire mode 2700 (setgid hérité, accès réservé au propriétaire), fichiers de sauvegarde créés sous umask 0077. Ces sauvegardes contiennent des données privées et restent sur l'hébergement : ne pas les publier ou les ajouter au dépôt.

Comparaison avec l'archive : les 411 fichiers des thèmes antérieurs, 7 054 fichiers des plugins et 11 fichiers des uploads sont identiques par taille et SHA-256. `wp-config.php`, `.htaccess` et `.user.ini` sont également inchangés.

## Configuration réalisée

- WordPress 7.1 ; PHP CLI 8.4.24. La version PHP du processus Web n'a pas été mesurée séparément.
- Thème actif : `ai-weather` ; ancien thème `neomundi` conservé.
- Assistant `aw_install_content()` exécuté avec les capacités d'un administrateur existant, sans création de compte ni mot de passe.
- 11 pages publiées, IDs 131 à 141 ; Home ID 131 comme accueil ; 17 anciennes pages conservées dans la corbeille.
- Permaliens `/%postname%/` ; règles régénérées en base uniquement, sans écrire `.htaccess`.
- Cache purgé via `wp_cache_clear_cache()` de WP Super Cache.
- Polylang conservé actif, langues fr/en/es ; nouvelles pages attribuées automatiquement au français. Les sélecteurs du thème assurent les variantes visuelles ; aucune série de pages traduites Polylang n'a été créée.
- Staging non indexable : `blog_public=0`, robots `noindex, nofollow` observés.

## Vérifications en ligne

Rapports : `validation/live.json` et `validation/live-navigation.json`. Captures locales : `test-results/live/` (hors Git).

- 11 pages testées en Chromium aux dimensions desktop 1440×1000 et mobile 390×844 : HTTP 200, aucune exception JavaScript, aucun débordement horizontal, titres et descriptions présents, aucun champ non résolu ni URL localhost dans les attributs de liens/ressources contrôlés.
- 22 pages HTML publiques de widgets : HTTP 200, pas de blocage Loading persistant.
- Quiz : sept réponses jusqu'au résultat final en anglais, français et espagnol.
- Today : 12 systèmes et historique visibles dans les 13 langues ; arabe RTL vérifié.
- Menu mobile : ouverture et navigation réelle vers Today réussies.
- 19 liens internes testés : aucune erreur ; `/home/` redirige normalement vers `/`.
- Télémétrie : 32 réponses POST HTTP 200 observées, `host_domain: neomundi.cloud`. CORS : `Access-Control-Allow-Origin: *`, méthodes POST/OPTIONS, en-tête Content-Type. Aucune erreur CORS dans la console. Aucun ajout d'origine requis dans la configuration observée ; aucune configuration de l'API modifiée. La persistance interne des événements côté API n'a pas été inspectée.
- Les chargements iframe interrompus par la réécriture du paramètre `site` ou par le passage à une autre page sont consignés comme ERR_ABORTED ; les URL finales chargent et les composants fonctionnent.

## Anomalies et limites conservées

- Le seul chemin de ressource en erreur HTTP est `assets/station/us-station-earth-topo.json` (404 sur les deux parcours). Le globe conserve son fallback ; projection +24 h indisponible comme dans la référence.
- Données : instantané du 15 septembre 2026 à 05:49 UTC, pas de mise à jour quotidienne automatique installée.
- Formulaire Daily Brief non raccordé à un service d'envoi.
- Les traductions éditoriales restent celles de la source ; toutes les sections ne sont pas traduites dans 13 langues. Le sélecteur visuel du thème n'établit pas une arborescence SEO multilingue Polylang.
- Tests réalisés dans Chromium avec simulation de viewport mobile, pas sur appareils physiques. Pas de session administrateur Web utilisée pour rééditer les pages distantes ; l'édition Gutenberg a été validée localement auparavant.
- Aucun défaut bloquant identifié : point de retour conservé, restauration non nécessaire.

## Édition et reprise par Vincent

Dans WordPress : Pages pour le wording et Apparence → AI Weather — Navigation / Footer pour les éléments partagés. Vérifier avec Aperçu après modification. Ne pas relancer l'installation pour remplacer du contenu existant. Aucune action manuelle obligatoire ne reste pour afficher le site.

Avant validation finale : décider du rythme de publication des données, raccorder Daily Brief si souhaité et compléter la station. Éviter de créer des traductions Polylang en doublon des variantes du thème sans définir une stratégie commune.

Pour Vincent : reprendre le thème **et la base** (pages Gutenberg, métadonnées, options), plus les uploads ajoutés ; effectuer un remplacement d'URL respectant les données sérialisées, puis vérifier accueil, permaliens, cache, télémétrie et politique d'indexation. Le ZIP seul ne contient pas les modifications éditoriales enregistrées dans WordPress. Aucune migration vers la production n'a été effectuée ici.

## Retour arrière si nécessaire

Le retour rapide consiste à réactiver `neomundi` puis rétablir les options d'accueil antérieures (`show_on_front=posts`, `page_on_front=0`) et purger le cache. Pour retrouver exactement l'état des pages/options avant installation, restaurer la sauvegarde SQL dans la base de **cette installation neomundi.cloud uniquement**, après nouvelle vérification du domaine et sauvegarde des éventuelles éditions intervenues depuis. Aucun fichier antérieur n'ayant changé, ne pas extraire globalement l'archive sur l'hébergement ; récupérer uniquement un fichier explicitement identifié si nécessaire. Le thème ajouté peut rester présent et inactif.

Les outils SSH/SFTP exigent `AW_SSH_HOST` et `AW_SSH_USER` en environnement ; aucune valeur d'accès ni secret n'est stockée dans leurs sources. Ils documentent cette opération précise et ne doivent pas être relancés indistinctement (l'envoi et la sauvegarde initiale refusent une cible déjà existante).
