# Accueil canonique — correctif 0.1.1

## Référence et diagnostic

La référence de l'accueil est exclusivement `controltowerai-wordpress-redesign/index.html` (SHA-256 `b4b93f0ec2bae19bb1b9dea6b6f026795ea7c4ef49ab81b3a7ca8616c266569d`). La copie publique utilisée pour générer le thème est identique à ce fichier. Aucun `index_full` n'a été utilisé pour l'accueil.

Au début de cette intervention, l'affichage public en liste brute n'a pas pu être reproduit : les accès normal et sans cache avaient le hero, six sections et le footer. La base contenait encore le bloc `ai-weather/layout` avec ses 153 champs Home, la métadonnée home et l'accueil ID 131. Aucune cause certaine de l'affichage signalé n'est donc affirmée. L'éditeur Gutenberg présente toujours des champs nommés ; c'est une interface d'édition, distincte de l'aperçu public.

Le template reposait toutefois exclusivement sur `the_content()` et sur l'enregistrement du bloc dynamique. Il pouvait donc exposer les blocs éditoriaux si cette chaîne de rendu était perdue. Le correctif rend explicite le rôle du template PHP : sélectionner la composition, lire les valeurs Gutenberg et les injecter dans les emplacements du HTML canonique. Il fonctionne aussi si le bloc enveloppant ou la métadonnée de page a disparu (identification par les IDs installés ou la page d'accueil).

Un défaut reproductible de polices a également été corrigé sous WordPress 6.6 : l'ajout du paramètre `ver` reconstruisait l'URL Google Fonts avec un seul des paramètres `family`, supprimant Inter. Les feuilles externes utilisent désormais leur URL intacte ; les feuilles locales portent la version du thème.

## Validation locale et visuelle

- 11 pages × 2 états : rendu normal puis bloc de mise en page désenregistré, champs dépliés et métadonnée absente dans une fixture exclusivement locale. Aucun affichage brut, navigation et CSS présents.
- Édition Gutenberg EN/FR, description SEO, lien de navigation et image partagée : sauvegarde, rendu à l'emplacement prévu, rechargement et restauration réussis. Verrous conservés.
- Captures de référence chargées depuis le vrai `index.html` canonique, avec les dépendances publiques servies localement ; aucun dossier privé exposé par le serveur de comparaison.
- Comparaison source / WordPress local / staging, aux dimensions 1440×1000 et 390×844. Géométrie, familles de polices, couleurs et arrière-plans mesurés identiques pour le header, H1, hero, les six sections et le footer après correction des polices.
- Cette mesure ne constitue pas une comparaison exhaustive pixel par pixel des animations et données dynamiques. Les captures pleine page ont également été inspectées.
- Différence responsive conservée : le CTA d'en-tête est masqué sous 640 px pour éviter le débordement du fichier canonique à 390 px. Le menu donne accès aux destinations. Aucun débordement sur le thème.

## Redéploiement limité à neomundi.cloud

Point de retour privé : `/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/aw-repair-return-20260915-205808/`.

- Base : 2 663 116 octets, SHA-256 `a90d55badd45a221de1ffee96d96b6120f3d3596f24688fce3f10af198116497`.
- Archive du site avant correctif : 65 291 046 octets, SHA-256 `fd70fa08dabe201715522974144fe4fcb1f613e0f66cecb3f083e8c5f7d82430`.
- Copies individuelles des quatre anciens fichiers dans `changed-originals/ai-weather/`.

Seuls `functions.php`, `inc/content.php`, `index.php` et `style.css` du thème ont été remplacés après transfert privé et contrôle de leur syntaxe PHP. Ensemble des 198 fichiers vérifié par taille/SHA-256 après remplacement. WP Super Cache purgé par sa fonction publique. Aucune réinstallation de pages, aucune modification du wording enregistré. Les dates de modification des 11 pages sont restées au 15 septembre 20:14:31 UTC.

Accueil : https://neomundi.cloud/. Version 0.1.1. ZIP : `dist/ai-weather-0.1.1.zip`, SHA-256 `1b9ab8e1406e06119c3dd0a09261382bdb3b2e83985eeb443bf77df7b00eb967`. L'ancien ZIP 0.1.0 est conservé.

## Contrôles après réparation

- 11 pages sur desktop et mobile : HTTP 200, aucune liste brute, aucun débordement, aucune exception JavaScript.
- Today : 12 systèmes visibles ; aucune substitution de composant effectuée.
- Quiz terminé dans son iframe intégré à la page WordPress.
- Deux pings réels observés sur ce parcours : HTTP 200, `host_domain=neomundi.cloud`, autorisation CORS `*`, aucune erreur CORS.
- Seule erreur de ressource observée : la topologie du globe déjà absente avant intervention, 404, avec affichage de secours.

Rapports : `validation/repair-local-regression.json`, `validation/repair-editing.json`, `validation/repair-visual.json`, `validation/repair-live.json`. Captures et comparaison visuelle consultable : `test-results/repair-after/comparison.html` (artefacts locaux, hors ZIP).

## Aujourd'hui et suite

Voir `TODAY-INTEGRATION.md`. Le choix d'un composant technique Today ne modifie jamais l'accueil ou le template global. Le fichier exact désigné par l'utilisateur reste à confirmer avant activation de la proposition visuelle.

Pour revenir au code antérieur, restaurer uniquement les quatre fichiers présents dans `changed-originals/ai-weather/` vers leurs chemins correspondants, après vérification de la racine neomundi.cloud, puis purger le cache. Le contenu WordPress n'ayant pas changé, une restauration globale de base n'est pas nécessaire pour annuler ce correctif.
