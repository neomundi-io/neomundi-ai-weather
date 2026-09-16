# For Media intégré à How It Works — version 0.2.1

Déployé uniquement sur https://neomundi.cloud le 16 septembre 2026 (heure de Paris).

## Contenu et architecture

Le bloc `#for-readers`, à la fin de How It Works, rassemble le positionnement, les usages journalistiques et scientifiques, les précautions de citation (date, système, protocole), la capsule horodatée et le chaînage par hash, les widgets et le logo éditorial. La méthodologie, les mesures, le JSON, le code public et les limites restent dans leurs sections existantes : les liens du bloc y renvoient sans reproduire ces sections.

La structure graphique reste canonique. `inc/readers.php` raccorde uniquement les nouveaux champs ; aucun contenu Gutenberg brut n’est rendu. Le build applique `tools/merge-media.cjs` après extraction du HTML canonique, pour ne pas réintroduire les anciens liens lors d’une reconstruction. Le HTML canonique original reste intact.

Les neuf colonnes Company contiennent, dans cet ordre et sur des lignes distinctes : NeoMundi.org, NeoMundi.io, ControlTower API. Les liens HTTPS ouvrent un nouvel onglet avec `noopener noreferrer`. Station USA conserve son footer spécifique sans colonne Company. Contact renvoie désormais à How It Works. Aucun menu WordPress ne contenait de lien supplémentaire vers For Media.

## Modifier les textes

WordPress → **Apparence → How It Works — Ressources** (compte avec `edit_theme_options`, administrateur par défaut).

Écran : `/wp-admin/themes.php?page=aw-readers`.

29 champs :

| Clé affichée | Contenu | Langues |
| --- | --- | --- |
| eyebrow | Surtitre | FR / EN |
| title | Titre principal | FR / EN |
| intro | Introduction / positionnement | FR / EN |
| usage_title, usage | Titre et texte « Citer une observation » | FR / EN |
| reuse_title, reuse | Titre et texte « Illustrer et réutiliser » | FR / EN |
| capsule_label, widgets_label, logo_label | Libellés des trois ressources | FR / EN |
| method_label, limits_label | Libellés des renvois méthode / limites | FR / EN |
| capsule_url, widgets_url, logo_url, method_url, limits_url | Cinq destinations HTTPS ou ancres | Communes |

Enregistrer les ressources purge WP Super Cache. Les textes sont nettoyés puis échappés ; les liens sont limités à HTTPS ou aux ancres. Les autres langues conservent le repli anglais du design existant. Les anciens champs Gutenberg restent archivés et ne pilotent pas le site. Cette édition ciblée est l’exception au gel décrit dans le README de la version 0.2.0.

## Retrait réversible

La page 137 est dans la corbeille, pas supprimée définitivement. Sa langue Polylang `fr` est conservée. Elle est retirée du catalogue actif et de l’installation automatique. Les templates et champs historiques restent conservés ; aucune route publique ne les utilise.

301 vérifiées vers `https://neomundi.cloud/how-it-works/` : `/for-media/`, `/for-media`, `/for-media.html`, `/fr/for-media/`, `/?page_id=137`. Le routeur couvre également les préfixes en/es.

Le staging reste non indexable : le sitemap WordPress est désactivé et ses URL répondent 404. For Media est aussi explicitement exclu de la requête sitemap en prévision d’une activation ultérieure. Aucun lien de navigation ne pointe vers ces URL de sitemap ni vers For Media.

Point de retour privé :
`/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/aw-repair-return-20260915-233425/`

- `database.sql` et `site-before.tar.gz` : sauvegarde complète avant changement, anciens backups préservés.
- `for-media-before.json` : page, contenu, métadonnées et ancienne table des pages avant mise à la corbeille.
- `for-media-canonical.html` : contenu du template conservé ; l’archive du site contient sa version exacte avant modification du footer.
- `changed-media-merge/` : copies des fichiers remplacés ; le module ajouté est identifié par le manifeste.

Retour ciblé si nécessaire : restaurer les anciens fichiers du thème depuis la sauvegarde, déplacer le nouveau module dans la sauvegarde privée, sortir la page 137 de la corbeille, rétablir son statut/slug et `aw_page_ids` depuis le JSON, puis purger le cache. Ne pas réinstaller WordPress ni écraser sa configuration.

## Validation

- 199 fichiers distants : ensemble exact, tailles et SHA-256 conformes au manifeste. 16 fichiers modifiés/ajoutés ; liste dans `validation/MEDIA-CHANGED-FILES.txt`.
- wp-config.php, .htaccess et .user.ini inchangés. Aucun upload, plugin, ancien thème, secret ni moteur privé transféré.
- ZIP : `dist/ai-weather-0.2.1.zip`, SHA-256 `c3856527c710a2d6aeb8a982dd52223af52a0600cde60ef47c3065a2bbac50f6`.
- Tests du paquet : exclusions, syntaxe JS/JSON, absence de champs bruts, dépendances capsules/cache ; télémétrie, quiz et mesures strictement inchangés.
- WordPress local : sauvegarde puis rendu d’un champ, nettoyage HTML, restauration de sa valeur et 301 validés.
- 10 pages × desktop 1440 / mobile 390 : HTTP 200, pas de débordement, pas de champs éditoriaux bruts, aucune exception JavaScript.
- Nouveau bloc FR/EN, navigation mobile, ordre/attributs des liens Company vérifiés.
- 16 liens internes distincts : HTTP 200. Les trois destinations externes demandées répondent HTTPS 200.
- Quiz terminé ; vrais pings widget vers l’API : HTTP 200, origine CORS `*`, aucune erreur CORS.
- Comparaison avant/après : zéro pixel différent au-delà du seuil 20/255 hors zones autorisées et animation USA, sur 18 captures. Contact est contrôlé séparément car son paragraphe et son CTA changent volontairement. Les dimensions des autres pages ne changent pas ; How It Works s’allonge du nouveau bloc.
- Galerie : `test-results/media-comparisons.html` ; preuves JSON dans `validation/media-*.json`.

Anomalies antérieures conservées : l’historique météo `2026-09-16.json` et la topographie du globe USA répondent 404, avec repli des composants. Aucun moteur privé n’a été exécuté pour fabriquer une nouvelle mesure. Ces ressources ne sont pas des liens de navigation cassés.

Pour une migration future autorisée, transférer le thème et l’option `aw_readers_wording` si personnalisée ; ses valeurs par défaut utilisent les URL du nouveau site. Réviser les cinq URL personnalisées pour éviter un ancien domaine de staging. Aucun accès à controltowerai.io n’a été effectué.
