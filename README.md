# Lintel

Multi-tenant real estate CRM for Nigerian agencies — built with **Flutter Web** + **Supabase**.

## What's in here so far

```
lintel/
├── pubspec.yaml
├── lib/
│   ├── main.dart                    ← App entry
│   ├── core/
│   │   ├── constants/env.dart       ← Supabase URL & keys
│   │   ├── router/                  ← go_router + responsive shell
│   │   ├── theme/                   ← Brand theme (green + gold)
│   │   └── utils/formatters.dart    ← Naira, dates, "2hrs ago"
│   ├── data/
│   │   ├── models/models.dart       ← Profile, Client, Property, Installment...
│   │   └── services/supabase_service.dart
│   └── features/
│       ├── auth/                    ← Sign-in screen + providers
│       ├── dashboard/               ← KPI cards, revenue chart, activity feed
│       └── {clients,properties,installments,
│              documents,reminders,staff}/  ← placeholders (next up)
└── supabase/
    └── migrations/
        ├── 0001_init.sql             ← Tables + RLS policies
        └── 0002_dashboard_and_helpers.sql
```

## Setup

### 1. Create a Supabase project

1. Go to https://supabase.com, create a new project (Lagos region if you can pick).
2. Save your `Project URL` and `anon public key`.
3. Open the SQL editor and run, in order:
   - `supabase/migrations/0001_init.sql`
   - `supabase/migrations/0002_dashboard_and_helpers.sql`

### 2. Configure the Flutter app

```bash
flutter pub get
```

Run with your Supabase credentials (don't commit them):

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### 3. Create your first agency + admin user

In Supabase Auth → Users → invite a user (you). Then in SQL editor:

```sql
insert into public.agencies (name, state) values ('Demo Agency', 'Lagos')
returning id;
-- Copy the returned uuid, then:

insert into public.profiles (id, agency_id, full_name, role)
values (
  'YOUR-AUTH-USER-UUID',
  'AGENCY-UUID-FROM-ABOVE',
  'Admin User',
  'agency_admin'
);
```

You can now sign in.

## Architecture

- **Multi-tenant** via `agency_id` on every table + Postgres Row Level Security.
- **State management:** Riverpod 2.
- **Routing:** go_router with auth-aware redirects.
- **Charts:** fl_chart.
- **PDF generation:** `pdf` + `printing` (for receipts and signed agreements).
- **E-signature:** built in-house — see `/sign/:token` route (next milestone).

## Next milestones (in order)

1. **Sign-up + agency provisioning flow** (DB trigger or edge function)
2. **Clients module** — list, search, onboard, KYC docs
3. **Properties module** — list, gallery upload, unit management
4. **Contracts** — link client+property, generate installment schedule
5. **Installments & payments** — record payments, generate receipts (PDF)
6. **E-signature portal** — public route `/sign/:token` with OTP verification
7. **Reminders** — Termii SMS + WhatsApp Cloud API edge functions
8. **Staff performance** — leaderboard view

## Deployment

Web build:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Drop `build/web` onto Cloudflare Pages, Vercel, or Netlify.
