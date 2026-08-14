# Imitateurs de ZTF — Fiche de Compte Rendu

*[Read in English](README.md)*

Une fiche de compte rendu mensuelle bilingue (français / anglais) pour le
Camp des Leaders 2026. Chaque compte rendu est relié au dossier de son
auteur par numéro de téléphone, afin que ses comptes rendus s'accumulent
en un historique continu plutôt que de rester des entrées isolées.

**Remplir la fiche :** https://ztf-imitators-leaders-camp-2026.netlify.app

## Fiches

- **Fiche de Compte Rendu Mensuelle** — 16 rubriques couvrant la marche
  avec Dieu, la lecture de la Bible, la prière, le gain d'âmes, le jeûne,
  les finances, et plus encore. Chaque soumission est reliée à une
  personne existante par son numéro de téléphone (ou par nom + localité
  en l'absence de téléphone), afin que les comptes rendus mensuels d'une
  même personne s'accumulent en un historique continu. Un indicateur
  d'URL caché (`?entry=goal`) permet au staff d'enregistrer l'objectif
  d'un trimestre séparément de son résultat ; ceci n'est jamais visible
  sur la fiche elle-même.
- **Fiche des Imitateurs de ZTF dans les Finances** — une fiche mensuelle
  plus courte pour déclarer ses engagements financiers (dîme, offrande,
  épargne, dettes, jeûne). Chaque soumission est indépendante et n'est
  pas reliée à l'historique de compte rendu d'une personne.

Les deux fiches enregistrent automatiquement un brouillon dans le
stockage local du navigateur au fur et à mesure de la saisie, et
proposent le français/anglais à tout moment via le bouton en haut de
page.

## Tableau de bord administrateur

`/admin.html` — un tableau de bord protégé par jeton pour consulter les
soumissions :

- **People** — chaque personne ayant soumis une Fiche de Compte Rendu
  Mensuelle, avec son historique complet regroupé par mois.
- **Finances** — chaque soumission de la Fiche des Imitateurs de ZTF
  dans les Finances, listée à plat (sans lien à une personne).

Le jeton correspond à la variable d'environnement `MIGRATE_TOKEN`,
fourni soit via le champ affiché sur la page, soit via `?token=...` dans
l'URL.

Des exports CSV des données brutes sont disponibles sur `/api/export` et
`/api/export-finances` (même jeton).

## Architecture technique

- **Front-end** — HTML/CSS/JS statique dans [public/](public/), sans
  étape de build ni framework.
- **Back-end** — [Netlify Functions](netlify/functions/) (`.mjs`,
  Node.js) derrière les routes `/api/*` définies dans
  [netlify.toml](netlify.toml).
- **Base de données** — PostgreSQL, via le client
  [`postgres`](https://github.com/porsager/postgres). Le schéma se
  trouve dans
  [netlify/functions/schema.sql](netlify/functions/schema.sql) et
  s'applique en appelant `/api/migrate?token=...` — idempotent, peut
  être relancé sans risque après une évolution du schéma.

## Développement local

```sh
npm install
cp .env.example .env   # renseigner DATABASE_URL et MIGRATE_TOKEN
npm run dev            # netlify dev, http://localhost:8888
```

Puis appliquer le schéma une fois :

```
GET http://localhost:8888/api/migrate?token=<MIGRATE_TOKEN>
```

## Déploiement

```sh
npm run deploy   # netlify deploy --prod
```

Le site déployé a besoin de `DATABASE_URL` et `MIGRATE_TOKEN` définis
dans les variables d'environnement du site Netlify (Site configuration →
Environment variables), puis du même appel ponctuel à
`/api/migrate?token=...` contre l'URL de production pour créer les
tables.