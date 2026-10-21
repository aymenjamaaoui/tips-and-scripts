# copy-chrome

🇬🇧 [English](README.md) | 🇫🇷 Français

Crée des copies indépendantes de Google Chrome sur macOS : un Chrome par compte Google,
chacun avec sa propre icône dans le Dock et sa propre entrée dans Cmd+Tab.

## Pourquoi

Sur macOS, tous les profils Chrome sont dans **une seule app**. Le Dock et Cmd+Tab
affichent **un seul** Chrome pour tous. Pour passer de ta fenêtre perso à ta fenêtre
pro, il faut Cmd+`, le menu Fenêtre ou Mission Control.

Avec `copy-chrome`, « Google Chrome » et « Chrome Pro » sont deux apps. Chacune a son
icône dans le Dock (avec un badge rond si tu veux), son entrée dans Cmd+Tab et ses
fenêtres.

## Comment ça marche

Le script copie `Google Chrome.app` et change trois choses dans la copie :

- un nouvel identifiant (`com.google.Chrome.<Id>`) : macOS voit une app séparée ;
- un nouveau nom (`Chrome <nom>`) ;
- un nouveau dossier de données (`~/Library/Application Support/Google/Chrome<Id>`) : la
  copie démarre vide, et le Chrome d'origine n'est pas touché.

Ensuite, il signe à nouveau la copie sur ton Mac (signature « ad hoc »).

`<Id>` est le nom sans les espaces ni les autres caractères non alphanumériques.

## Prérequis

- macOS, avec Google Chrome dans `/Applications`.
- Les Xcode Command Line Tools (`xcode-select --install`), seulement pour `--badge` :
  l'icône est dessinée avec `swift`.
- Environ 1,4 Go d'espace libre par copie.

## Installation

Télécharge `copy-chrome.sh` et `make-icon.swift` dans **le même dossier**, puis :

```sh
chmod +x copy-chrome.sh
```

## Utilisation

```sh
./copy-chrome.sh <nom> [--badge <image> | --no-badge] [--force] [--yes] [--src <app>] [--dest <dossier>]
./copy-chrome.sh <nom> --remove [--yes] [--dest <dossier>]
```

| Option             | Effet                                                                |
|--------------------|----------------------------------------------------------------------|
| `<nom>`            | la copie s'appelle `Chrome <nom>.app`. Mets des guillemets si le nom a des espaces. |
| `--badge <image>`  | pose l'image (ronde, en haut à gauche) sur l'icône Chrome            |
| `--no-badge`       | revient à l'icône Chrome normale                                     |
| `--force`          | refait la copie même si elle est à jour                              |
| `--remove`         | supprime la copie et ses données                                     |
| `--yes`            | répond oui à toutes les questions                                    |
| `--src <app>`      | le Chrome d'origine (par défaut `/Applications/Google Chrome.app`)   |
| `--dest <dossier>` | où mettre la copie (par défaut `~/Applications`)                     |

Sans `--badge`, une nouvelle copie a l'icône Chrome, et une mise à jour garde l'icône
de l'ancienne copie.

## Exemples

Créer une copie avec un badge :

```sh
./copy-chrome.sh Pro --badge ~/Pictures/logo-entreprise.png
```

Mettre à jour la copie après une mise à jour de Chrome (quitte Chrome avant) :

```sh
./copy-chrome.sh Pro
```

Changer le badge, ou l'enlever :

```sh
./copy-chrome.sh Pro --badge autre-logo.png
./copy-chrome.sh Pro --no-badge
```

Supprimer la copie et toutes ses données (profil, historique, cookies, cache) :

```sh
./copy-chrome.sh Pro --remove
```

Le script demande avant de remplacer ou de supprimer une copie. Si la copie est ouverte,
il la quitte avant.

## Premier lancement

1. Ouvre `~/Applications/Chrome Pro.app`.
2. macOS demande l'accès à l'élément du trousseau « Chrome Safe Storage » : clique sur
   **Toujours autoriser**.
3. Connecte-toi à ton compte Google et active la synchronisation.
4. Clic droit sur l'icône dans le Dock : **Options > Garder dans le Dock**.

## Limites

- **Les passkeys enregistrées sur le Mac ne sont pas proposées** dans une copie
  (Mots de passe d'Apple, Gestionnaire de mots de passe de Google). Les mots de passe
  marchent, et une passkey de ton téléphone marche avec le QR code (« Utiliser la clé
  d'accès d'un autre appareil »). Garde dans le Chrome d'origine les comptes qui
  utilisent beaucoup de passkeys.
- **Le trousseau redemande l'accès** après chaque mise à jour de la copie : clique sur
  **Toujours autoriser**.
- **Pas de mise à jour automatique** : relance le script après chaque mise à jour de
  Chrome.
- **Non officiel** : Google ne supporte pas cette méthode. Elle peut ne plus marcher
  avec une future version de Chrome ou de macOS.

## Plus de détails

Le fonctionnement, toutes les limites et les alternatives : voir l'article du blog
(lien bientôt).
