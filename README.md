# Connecter Google Ads à ton assistant IA, gratuitement

Ce kit branche **ton propre compte Google Ads** sur ton assistant IA grâce au serveur MCP
**officiel et open source de Google** (`googleads/google-ads-mcp`). Il fonctionne avec tous les
clients compatibles MCP qui lancent un serveur local :

| Client | Installation par le script |
|---|---|
| Claude Desktop | automatique |
| Cursor | automatique |
| Gemini CLI | automatique |
| Claude Code | commande affichée, à copier |
| Codex CLI (OpenAI) | commande affichée, à copier |
| ChatGPT (application, web) | non : ChatGPT n'accepte que des serveurs hébergés, voir [Aller plus loin](#aller-plus-loin) |

Pas d'abonnement, pas d'outil tiers entre toi et tes données : le serveur tourne sur ton
ordinateur. Compte environ 20 minutes la première fois, plus le délai de validation de l'accès
par Google.

> Kit indépendant, sans lien avec Google. Il assemble des briques publiques et documentées.
> Dernière vérification de la documentation Google : 20 novembre 2026.

---

## Ce que ça permet

Poser des questions en français sur tes comptes, par exemple :

- « Qu'est-ce qui a changé dans mon compte ces 30 derniers jours ? »
- « Quelles campagnes dépensent sans convertir ce mois-ci ? »
- « Mon suivi des conversions est-il propre ? »

L'assistant écrit lui-même les requêtes (GAQL) et lit les résultats.

**Ce que ce kit ne fait pas :**

- **Rien modifier.** Il est réglé en **lecture seule** : l'assistant ne peut ni modifier une
  enchère, ni mettre une campagne en pause, ni rien publier.
- **Pas de Planificateur de mots-clés ni de prévisions.** Le serveur de Google ne propose pas
  ces outils, et le niveau d'accès Explorer bloque les services de planification de mots-clés,
  de couverture et d'audience. Le Planificateur de performances n'existe, à notre connaissance,
  que dans l'interface Google Ads.
  Ce qui marche à la place : analyser tes vrais termes de recherche et tes mots-clés existants
  (prompt n°6), ou exporter le Planificateur de mots-clés en CSV depuis l'interface et donner
  le fichier à ton assistant.

## Pourquoi c'est devenu simple

Depuis le **9 septembre 2026**, Google ne demande plus de « jeton développeur ». L'accès à
l'API est attaché à un **projet Google Cloud**, et il existe un niveau d'accès d'entrée,
**Explorer**, attribué après une vérification automatique dans la plupart des cas :

| Niveau | Comptes réels | Limite par jour | Comment l'obtenir |
|---|---|---|---|
| Test | non (comptes de test seulement) | 15 000 opérations | automatique en activant l'API |
| **Explorer** | **oui** | **2 880 opérations** | demande dans la Cloud Console, examen automatisé |
| Basic | oui | 15 000 opérations | vérification de la marque |
| Standard | oui | illimité | audit manuel (~10 jours ouvrés) |

2 880 opérations par jour suffisent largement pour suivre et auditer ses propres comptes
(une question déclenche en général une à quelques requêtes).

Explorer bloque : la création et la liaison de comptes, la gestion des utilisateurs, le
Planificateur de mots-clés et les outils d'audience, la facturation. Rien de tout ça n'est
utile pour de l'analyse.

Les plateformes payantes (Windsor, Supermetrics…) restent utiles si tu veux plusieurs sources
de données au même endroit, sans rien installer, ou gérer des centaines de comptes. Pour
interroger tes propres comptes, tu n'en as pas besoin.

---

## Ce qu'il te faut

- Un compte Google Ads où tu peux **ajouter un utilisateur** (accès administrateur).
- Un compte Google pour créer un projet Google Cloud (gratuit pour cet usage).
- Un des clients listés plus haut.
- Un Mac ou un PC Linux pour le script d'installation. Sous Windows, suis la
  [configuration manuelle](#configuration-manuelle-windows-ou-sans-script).

---

## Étape 1 — Créer le projet Google Cloud et activer l'API

1. Ouvre la [Cloud Console](https://console.cloud.google.com/) et crée un projet
   (menu des projets en haut → **Nouveau projet**). Nomme-le par exemple `google-ads-ia`.
2. Avec ce projet sélectionné, ouvre la page de
   [l'API Google Ads](https://console.cloud.google.com/apis/library/googleads.googleapis.com)
   et clique sur **Activer**.

Ton projet a maintenant l'accès **Test**.

## Étape 2 — Demander l'accès Explorer

1. Ouvre la page
   [Vue d'ensemble de l'API Google Ads](https://console.cloud.google.com/google/ads-apis/overview)
   de ton projet.
2. Demande l'accès **Explorer** et remplis le formulaire (décris un usage honnête, par exemple :
   « analyse et reporting en lecture seule de mes propres comptes Google Ads »).

L'examen est automatisé dans la plupart des cas. Tant qu'il n'est pas validé, les requêtes sur
tes vrais comptes échoueront : c'est normal.

## Étape 3 — Créer un compte de service et sa clé

Un compte de service est un « utilisateur robot » propre à ton projet. C'est lui que
l'assistant utilisera pour lire Google Ads.

1. Dans la Cloud Console : **IAM et administration → Comptes de service → Créer un compte de
   service**. Nom : `lecture-google-ads`. Aucun rôle Cloud n'est nécessaire, tu peux passer les
   étapes facultatives.
2. Ouvre le compte de service créé → onglet **Clés** → **Ajouter une clé → Créer une clé →
   JSON**. Un fichier `.json` se télécharge.
3. **Note l'adresse e-mail du compte de service** (elle finit par `.iam.gserviceaccount.com`).

> Ce fichier JSON est un mot de passe. Ne l'envoie à personne, ne le mets ni dans un e-mail,
> ni dans un dossier partagé, ni sur GitHub. Le script de l'étape 6 le range dans un dossier
> protégé.

Si la Console refuse de créer une clé (règle d'organisation sur certains comptes
Google Workspace), voir [Dépannage](#dépannage).

## Étape 4 — Donner accès au compte de service dans Google Ads

1. Dans Google Ads : **Administration → Accès et sécurité → Utilisateurs → bouton +**.
2. Colle l'adresse e-mail du compte de service.
3. Choisis le niveau **Lecture seule** (le niveau « E-mail uniquement » ne fonctionne pas).
4. Valide.

Une même adresse peut être ajoutée à 20 comptes Google Ads au maximum. Au-delà, ajoute-la à ton
compte administrateur (MCC) : voir [Dépannage](#dépannage).

## Étape 5 — Installer `uv`

Le serveur de Google demande Python 3.11 ou plus récent. Plutôt que d'installer Python à la main,
on passe par `uv`, qui télécharge automatiquement la bonne version.

macOS / Linux, dans le Terminal :

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Ou, si tu utilises Homebrew :

```bash
brew install uv
```

Ferme puis rouvre le Terminal, et vérifie :

```bash
uvx --version
```

## Étape 6 — Lancer le script d'installation

**Quitte d'abord Claude Desktop (Cmd+Q).** Il réécrit son fichier de configuration quand il
tourne : une modification faite pendant qu'il est ouvert est perdue au redémarrage. Le script
le vérifie et te demande de le fermer s'il est encore ouvert.

Télécharge le kit, puis lance le script depuis son dossier, dans le Terminal :

```bash
git clone https://github.com/isma2034/kit-google-ads-ia.git
cd kit-google-ads-ia
bash installer.sh ~/Downloads/le-fichier-de-cle.json
```

Sans `git` : sur la [page du dépôt](https://github.com/isma2034/kit-google-ads-ia), bouton
**Code → Download ZIP**, décompresse l'archive, puis place-toi dans le dossier obtenu avec `cd`
avant de lancer la dernière commande.

Ajoute `--mcc 1234567890` si tu passes par un compte administrateur (MCC), sans tirets.

Le script :

1. vérifie que `uvx` est installé et que le fichier est bien une clé de compte de service ;
2. copie la clé dans `~/.config/google-ads-mcp/` avec des droits limités à ton utilisateur ;
3. installe une configuration **lecture seule** (`tools_config.yaml`) ;
4. ajoute le serveur à **Claude Desktop**, **Cursor** et **Gemini CLI** s'ils sont installés,
   après sauvegarde de leur configuration ;
5. affiche les commandes pour **Claude Code** et **Codex CLI** ;
6. te rappelle l'adresse e-mail à ajouter dans Google Ads.

Relance ensuite ton assistant. Dans Claude Desktop, le serveur `google-ads` apparaît dans le
menu des outils et connecteurs (icône sous la zone de saisie).

## Étape 7 — Tester

Demande à ton assistant :

1. « À quels comptes Google Ads ai-je accès ? »
2. « Combien de campagnes actives sur le compte 123-456-7890 ? »

Puis essaie les [6 prompts d'audit](prompts-audit.md).

---

## Configuration manuelle (Windows, ou sans script)

**Claude Desktop, Cursor, Gemini CLI** : ces trois clients utilisent le même format. Ajoute le
bloc de [`config/mcp_servers.exemple.json`](config/mcp_servers.exemple.json) dans
`mcpServers` du fichier :

| Client | macOS / Linux | Windows |
|---|---|---|
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` |
| Cursor | `~/.cursor/mcp.json` | `%USERPROFILE%\.cursor\mcp.json` |
| Gemini CLI | `~/.gemini/settings.json` | `%USERPROFILE%\.gemini\settings.json` |

Remplace :

- `CHEMIN_VERS_UVX` par le résultat de `where uvx` (Windows) ou `which uvx` (macOS) ;
- `CHEMIN_VERS_LA_CLE` par le chemin complet de ta clé JSON ;
- `CHEMIN_VERS_TOOLS_CONFIG` par le chemin complet de [`config/tools_config.yaml`](config/tools_config.yaml) ;
- `ID_DU_PROJET` par l'identifiant de ton projet Google Cloud (il est aussi dans la clé, champ
  `project_id`).

Sous Windows, écris les chemins avec des doubles barres obliques inverses
(`C:\\Users\\toi\\...`).

**Claude Code** (toutes plateformes) :

```bash
claude mcp add google-ads --scope user \
  -e GOOGLE_APPLICATION_CREDENTIALS=/chemin/vers/cle.json \
  -e GOOGLE_CLOUD_PROJECT=ID_DU_PROJET \
  -e GOOGLE_ADS_MCP_TOOLS_CONFIG=/chemin/vers/tools_config.yaml \
  -- uvx --python 3.12 --from google-ads-mcp==0.0.6 google-ads-mcp
```

**Codex CLI** (toutes plateformes) :

```bash
codex mcp add google-ads \
  --env GOOGLE_APPLICATION_CREDENTIALS=/chemin/vers/cle.json \
  --env GOOGLE_CLOUD_PROJECT=ID_DU_PROJET \
  --env GOOGLE_ADS_MCP_TOOLS_CONFIG=/chemin/vers/tools_config.yaml \
  -- uvx --python 3.12 --from google-ads-mcp==0.0.6 google-ads-mcp
```

---

## Aller plus loin

**ChatGPT et les usages en équipe.** ChatGPT ne lance pas de serveur local : il se connecte à
des serveurs MCP hébergés. Le serveur de Google prévoit ce cas (mode « Streamable HTTP » avec
connexion Google OAuth, déployable sur Cloud Run) : voir la section *Deployment* de
[sa documentation](https://github.com/googleads/google-ads-mcp#deployment). C'est plus
technique, et le serveur devient accessible sur Internet : à réserver à quelqu'un qui sait
sécuriser un service en ligne.

---

## Sécurité

- **Lecture seule à deux niveaux.** Le compte de service a le rôle « Lecture seule » dans
  Google Ads, et la configuration du kit désactive les outils de modification du serveur
  (création d'assets, envoi de vidéos, libellés). Même si l'assistant se trompe, rien ne peut
  être modifié.
- **La clé JSON donne accès à tes données.** Si tu penses qu'elle a fuité : supprime-la dans la
  Cloud Console (onglet **Clés** du compte de service) et retire l'adresse dans Google Ads.
- **Tes données passent par le modèle d'IA.** Les résultats des requêtes sont envoyés au modèle
  (Claude, GPT, Gemini…) pour qu'il te réponde. N'interroge pas de compte client sans son
  accord.
- **Télémétrie.** Le serveur de Google ajoute un en-tête qui permet à Google de mesurer son
  utilisation (indiqué dans sa documentation).
- **Version figée.** Le kit installe la version `0.0.6` du serveur. Pour mettre à jour, change
  ce numéro après avoir lu les [notes de version](https://github.com/googleads/google-ads-mcp).

---

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| Le serveur n'apparaît pas dans l'assistant | L'assistant n'a pas été redémarré, ou ne trouve pas `uvx` | Quitter complètement l'assistant ; vérifier le chemin absolu de `uvx` dans la configuration |
| `Failed to load service account credentials` | Le fichier de clé est incomplet ou ce n'est pas la bonne clé | Recréer une clé JSON (étape 3) et relancer le script |
| Erreur `UNAUTHENTICATED` « Request is missing required authentication credential », avec dans les détails « …is not associated with any Ads accounts » | La clé fonctionne, mais l'adresse du compte de service n'a pas encore été ajoutée dans Google Ads | Faire l'étape 4, puis réessayer (l'ajout peut prendre quelques minutes à être pris en compte) |
| Erreur `NOT_ADS_USER` ou `USER_PERMISSION_DENIED` | L'adresse du compte de service n'est pas (encore) ajoutée au compte | Refaire l'étape 4 ; pour un compte client, passer par le MCC (ligne suivante) |
| Accès refusé sur les comptes passant par un MCC | Il manque l'identifiant du compte administrateur | Ajouter le compte de service au MCC, puis relancer le script avec `--mcc 1234567890` |
| Erreur d'accès alors que tout est configuré | Le projet est encore au niveau Test | Attendre la validation Explorer (étape 2) |
| La Console refuse de créer une clé JSON | Règle d'organisation Google Workspace (`iam.disableServiceAccountKeyCreation`) | Demander à l'administrateur, ou utiliser la méthode « identifiants utilisateur » de la [documentation du serveur](https://github.com/googleads/google-ads-mcp#mode-a-local-stdio-with-application-default-credentials-adc) |
| Le script signale une configuration « illisible » | Le fichier de configuration du client contient une erreur de syntaxe | Corriger le fichier, ou ajouter le bloc à la main (configuration manuelle) |
| macOS propose d'installer les « outils de ligne de commande » au lancement du script | `python3` n'est pas encore installé (le script s'en sert pour lire les fichiers JSON) | Accepter l'installation, puis relancer le script |
| Quota dépassé | Plus de 2 880 opérations sur 24 h glissantes | Attendre ; poser des questions plus ciblées ; demander l'accès Basic si besoin |

---

## Sources

- [Niveaux d'accès de l'API Google Ads](https://developers.google.com/google-ads/api/docs/access-levels)
- [Fin des jetons développeurs](https://developers.google.com/google-ads/api/docs/first-call/dev-token)
- [Serveur MCP Google Ads (documentation Google)](https://developers.google.com/google-ads/api/docs/developer-toolkit/mcp-server)
- [Dépôt `googleads/google-ads-mcp`](https://github.com/googleads/google-ads-mcp)
- [Comptes de service pour l'API Google Ads](https://developers.google.com/google-ads/api/docs/oauth/service-accounts)
- [Historique des modifications via l'API (`change_event`)](https://developers.google.com/google-ads/api/docs/change-event)
- [Serveurs MCP dans Codex](https://developers.openai.com/codex/mcp)
- [Serveurs MCP dans Gemini CLI](https://www.geminicli.com/docs/tools/mcp-server)
