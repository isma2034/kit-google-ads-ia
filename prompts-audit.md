# 6 prompts d'audit Google Ads à coller dans ton assistant IA

Remplace `[ID_COMPTE]` par l'identifiant du compte (10 chiffres, avec ou sans tirets).
Chaque prompt précise les tables de l'API à utiliser : l'assistant se trompe moins quand on le guide.

**Avant d'agir sur une réponse, vérifie les chiffres dans l'interface Google Ads.** L'assistant peut
mal lire une donnée ou en tirer une conclusion trop rapide. Le kit est en lecture seule : ces
prompts ne modifient rien.

---

## 1. Qu'est-ce qui a changé dans mon compte ?

> Ma performance a bougé et je veux savoir ce qui a été modifié.

```text
Sur le compte Google Ads [ID_COMPTE], interroge la ressource change_event sur les 30 derniers
jours (c'est le maximum autorisé par l'API ; LIMIT obligatoire, 10 000 lignes maximum).
Récupère pour chaque modification : la date et l'heure, l'auteur (user_email), le client
utilisé (client_type), le type de ressource modifiée, l'opération et la campagne concernée.

Ensuite :
1. Résume les modifications par jour, par auteur et par type de ressource.
2. Mets en évidence les modifications sensibles : URL finales des annonces, objectifs ou
   actions de conversion, budgets, stratégies et cibles d'enchères, statut des campagnes.
3. Récupère les dépenses, conversions et la valeur de conversion par jour sur la même période
   (ressource customer, segments.date) et indique les modifications qui précèdent une rupture
   de tendance.

Présente le résultat comme une chronologie. N'affirme pas qu'une modification a causé une
variation : signale seulement les coïncidences de dates, à vérifier.
```

## 2. Où part l'argent sans rien rapporter ?

```text
Sur le compte Google Ads [ID_COMPTE], sur les 30 derniers jours :
1. Liste les campagnes et groupes d'annonces actifs avec leur coût, leurs clics, leurs
   conversions et leur coût par conversion. Trie par coût décroissant.
2. Isole ceux qui ont dépensé plus de 5 % du budget total du compte avec 0 conversion.
3. Dans search_term_view, liste les 30 termes de recherche les plus coûteux sans conversion,
   avec la campagne et le groupe d'annonces d'origine.
Termine par une liste de vérifications à faire dans l'interface, sans proposer de modifier
quoi que ce soit automatiquement.
```

## 3. Mon suivi des conversions est-il propre ?

```text
Sur le compte Google Ads [ID_COMPTE], interroge la ressource conversion_action et liste chaque
action de conversion avec : nom, statut, type, catégorie, origine, mode de comptage
(une ou toutes), inclusion dans l'objectif principal (primary_for_goal) et fenêtre de
conversion.
Récupère ensuite les conversions des 30 derniers jours par action de conversion
(segments.conversion_action_name).

Signale :
- les actions principales qui n'ont rien enregistré depuis 30 jours ;
- les doublons probables (deux actions qui mesurent la même chose et comptent toutes les deux
  dans l'objectif) ;
- les achats comptés « toutes » au lieu de « une » pour des prospects (ou l'inverse).
```

## 4. Est-ce que je touche trop souvent aux budgets et aux enchères ?

```text
Sur le compte Google Ads [ID_COMPTE], interroge change_event sur les 30 derniers jours et
garde uniquement les modifications de budgets de campagne (CAMPAIGN_BUDGET) et de
stratégies ou cibles d'enchères (CAMPAIGN et BIDDING_STRATEGY, champs liés aux enchères).
Pour chaque campagne, compte le nombre de modifications et l'écart moyen entre deux
modifications.
Signale les campagnes en stratégie d'enchères automatique modifiées plus d'une fois par
semaine : chaque changement de cible peut relancer une période d'apprentissage.
```

## 5. Mes annonces envoient-elles vers les bonnes pages ?

```text
Sur le compte Google Ads [ID_COMPTE], sur les 30 derniers jours, interroge landing_page_view
et liste les URL de destination avec : clics, coût, conversions, taux de conversion et
campagnes concernées.
Compare chaque page à la moyenne du compte et signale :
- les pages qui reçoivent du trafic de campagnes de marque mais convertissent nettement moins
  que la moyenne ;
- les URL qui ressemblent à des pages temporaires, de précommande, de test ou d'erreur ;
- les pages qui concentrent plus de 20 % du coût.
Ne teste pas les URL toi-même : donne-moi la liste à vérifier dans un navigateur.
```

## 6. Quels mots-clés ajouter ou exclure, d'après mes vrais termes de recherche ?

> Le kit n'a pas accès au Planificateur de mots-clés. Ce prompt part de ce que les internautes
> ont réellement tapé, ce qui est souvent plus fiable que des estimations.

```text
Sur le compte Google Ads [ID_COMPTE], sur les 30 derniers jours :
1. Interroge search_term_view : terme de recherche, campagne, groupe d'annonces, impressions,
   clics, coût, conversions et valeur de conversion.
2. Interroge keyword_view : texte du mot-clé, type de correspondance, statut, mêmes métriques.
3. Compare les deux et propose :
   - des mots-clés à ajouter : termes qui convertissent mais ne sont pas encore des mots-clés
     (avec le type de correspondance conseillé et le groupe d'annonces d'accueil) ;
   - des mots-clés à exclure : termes qui dépensent sans conversion ou hors sujet, regroupés
     par thème (marques concurrentes, emploi, gratuit, informationnel…) ;
   - des mots-clés existants qui ne déclenchent presque jamais d'impressions.
Présente le tout en tableaux. Ne modifie rien : je validerai chaque ajout dans Google Ads.
```

Google masque les termes de recherche trop rares (seuils de confidentialité) : une partie des
dépenses n'apparaît pas terme par terme.

---

## Bon à savoir

- **Quota :** l'accès Explorer permet 2 880 opérations par jour sur les vrais comptes. Chaque
  prompt ci-dessus en consomme en général moins d'une dizaine.
- **Historique :** l'API ne remonte les modifications détaillées que sur 30 jours
  (`change_event`). Pour remonter plus loin, exporte l'historique des modifications depuis
  l'interface Google Ads et donne le fichier à ton assistant.
- **Plusieurs comptes :** commence par « À quels comptes ai-je accès ? », puis précise le
  compte dans chaque question.
