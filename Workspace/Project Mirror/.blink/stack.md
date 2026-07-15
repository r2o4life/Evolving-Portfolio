# Project Mirror: Technical Stack Specification

## Core Architecture
- **Frontend Framework:** Vanilla HTML5, CSS3, JavaScript (ES6+). No heavy dependencies.
- **Backend & State:** Supabase (Open-Source Firebase Alternative) via CDN. Handles Postgres Database, Authentication, and Storage.
- **Routing:** Single Page Application (SPA) architecture, rendering views dynamically via JavaScript.

## Design System & Aesthetics (Impeccable Product Rules)
- **Theme:** Strict Product UI, deep slate dark mode.
- **Visual Style:** Data-dense, familiar semantic layout (like Linear/Stripe).
  - **BANNED:** No glassmorphism (`backdrop-filter: blur()`).
  - **BANNED:** No gradient text (`background-clip: text`).
  - **BANNED:** No identical card grids for data.
- **Typography:** One single sans-serif family (Inter or System-UI) for all text. Fixed `rem` scaling, tighter scale ratio.
- **Color Palette (OKLCH Only):**
  - **Restrained Strategy:**
  - Background (Body): `oklch(20% 0.01 260)` (deep, solid slate).
  - Surface (Panels/Sidebar): `oklch(25% 0.01 260)` (slightly lighter for contrast).
  - Primary Accent: `oklch(60% 0.15 260)` (blue, used *only* for primary actions/states).
  - Text (Primary): `oklch(95% 0.01 260)`.
  - Text (Muted): `oklch(70% 0.02 260)`. (Ensure >= 4.5:1 contrast).
  - Semantic States: hover, focus, active, disabled.
- **Layout & Structure:** Use semantic tables, dense lists, or sidebars rather than large repetitive cards.
- **Motion:** 150-250ms transitions maximum. Used *only* for state changes (hover/focus), not decoration. No page-load choreographies.
