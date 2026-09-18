# Sprint 0.5 — Validation status

This document records infrastructure validation without treating static review as runtime proof.

## Current environment result

Validation attempted on 2026-09-18 remains **blocked, not complete**:

- npm registry is correctly configured as `https://registry.npmjs.org/`;
- there is no project, user, or global `.npmrc` overriding the registry;
- the environment injects an HTTP/HTTPS proxy;
- requests through that proxy receive `403 Forbidden`, while direct requests cannot resolve the public registry;
- consequently `npm install` cannot create `node_modules` or `package-lock.json`;
- lint, typecheck, and build cannot load their declared local dependencies;
- this container has no `psql`, PostgreSQL server, Docker, or Supabase CLI;
- migrations and two-user RLS tests have therefore **not executed against a real database here**.

The schema must not be considered frozen and Sprint 0.5 must not be marked complete until the commands below pass in an environment with registry and Supabase access.

## Required completion commands

```bash
npm install
npm run lint
npm run typecheck
npm run build

# With Supabase CLI and its local stack running:
supabase db reset
npm run db:test
```

Alternatively, for a disposable empty Supabase/PostgreSQL test database:

```bash
APPLY_MIGRATIONS=1 DATABASE_URL='postgresql://...' npm run db:test
```

`APPLY_MIGRATIONS=1` must never be pointed at production. The database suite rolls back its fixtures, but migration application is not rolled back.

## Acceptance gate

Completion requires captured successful output for dependency installation, lint, typecheck, build, all six migrations, and `supabase/tests/database_invariants.sql`. The database run must use the `authenticated` role with two distinct `auth.uid()` values; an administrative-only execution is insufficient.
