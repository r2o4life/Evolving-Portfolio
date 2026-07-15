# Project Mirror: Product Requirements Document

## Core Objective
Project Mirror acts as a dynamic matchmaking and generation engine. It decouples engineering contribution from traditional corporate gatekeeping, transforming fragmented developer aspirations into structured, open-source alternatives to existing proprietary services.

## GEMSG Alignment
- **Governance:** Transparent project stewardship and contributor ethics.
- **Economics:** Unlocking unutilized engineering labor.
- **Modernization:** Transitioning from siloed repos to a market-aligned index.
- **Sociology:** Democratizing software ownership.
- **Growth:** Scaling a global alternative tech stack.

## Core User Flows
1. **Search/Registry:** User lands on the page and views a directory of proprietary tools matched against their open-source alternatives.
2. **Join Community:** User can click to join the discussion or Discord for an existing open-source project.
3. **Join Project:** User can authenticate and commit to working on an existing open-source project.
4. **Spawn Competitor:** If an alternative does not exist, the user clicks to "Spawn Competitor", which initiates the creation of a new open-source repository designed to challenge the target proprietary tool.

## Data Model (Supabase Postgres)
The application will utilize a Supabase Postgres database.

### `projects` Table Schema
```sql
create table projects (
  id uuid default gen_random_uuid() primary key,
  target_proprietary text not null,
  open_source_alternative text not null,
  status text default 'Initializing',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
```
