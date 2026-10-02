# Mi Plato

**English** · [Español](README.es.md)

A photo-based food diary. Take a picture of your plate: the app recognizes the
foods, calculates the calories and tells you what works for and against your
BMI and your goal.

Flutter (Android, iOS and web) + Supabase + Claude for image recognition.

## How the work is split

This is the design decision everything else rests on:

| Who | What it does |
|---|---|
| **Vision model** (Claude, server-side) | Looks at the photo: which foods are there and how many grams of each |
| **Nutrition database** (USDA FoodData Central) | Grams of protein, fat, sodium… measured in a lab |
| **The app** (plain Dart, `lib/datos/nutricion/`) | BMI, energy expenditure, daily target, the pros-and-cons verdict and the suggestion filter |

The model has no opinion on your diet. It only identifies food. Every piece of
advice comes from fixed rules that can be checked against a specific threshold
(WHO, Mifflin-St Jeor, Dietary Guidelines), so two identical plates always get
the same verdict and every sentence can be traced back to its formula. That is
what `calculos.dart` and `veredicto.dart` do, and why they are covered by tests.

## Run it without a backend (demo mode)

```bash
flutter run
```

Without credentials the app starts in demo mode: in-memory data, simulated
photo analysis and a sample account with a week of entries. It lets you walk
through the whole interface; it does not recognize real photos.

On the sign-in screen, tap **Entrar en modo demo**.

## Backend setup

### 1. Database

Create a project at [supabase.com](https://supabase.com) and run the whole
`supabase/schema.sql` in the SQL Editor. Leave the `comidas` bucket as the
script creates it: **private**. These are photos of what someone eats at home.

### 2. Edge Functions

```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase secrets set FDC_API_KEY=...        # free: https://fdc.nal.usda.gov/api-key-signup
supabase functions deploy analizar-comida
supabase functions deploy sugerir-comidas
```

`FDC_API_KEY` is optional. Without it the app still works, but nutrients are
the model's estimate instead of measured data, and each food is labeled as
such.

**The model API key never ships in the client.** It lives as a function
secret; the app only sends the image. If it were inside the APK, anyone could
extract it and spend with it.

### 3. Run

```bash
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

## Structure

```
lib/
  core/        config, theme, routes, formatting
  datos/
    modelos/   domain (Perfil, Comida, Alimento, Nutrientes)
    nutricion/ BMI, daily target, verdict, local food table  <- the core
    repos/     interfaces + Supabase + demo store
  estado/      Riverpod providers
  ui/          auth, diary, camera, progress, settings
supabase/
  schema.sql                     tables, RLS, bucket, quota and deletion
  functions/analizar-comida/     photo recognition
  functions/sugerir-comidas/     what to eat for the rest of the day
docs/decisiones/                 ADRs: why it is built this way (Spanish)
```

## Your data

A food diary and a weight curve are health data, and the project treats them
that way:

- **Nobody else sees them.** Every table has RLS on `auth.uid()` and there is
  no admin role with access to someone else's diary. The photo bucket is
  private: the app stores the path and signs a temporary URL to display it.
- **You can take them with you.** Settings -> *Exportar mis datos* dumps
  everything to JSON, including derived values (BMI, target, limits) so the
  export makes sense without the app.
- **You can delete them.** Settings -> *Borrar mi cuenta y mis datos* removes
  the profile, meals, photos and weight history. Deleting a single meal also
  deletes its photo: Storage does not take part in Postgres cascades, so the
  app does it explicitly and in that order.
- **Retention:** until you decide to delete it. There is no automatic expiry,
  because a diary without history is useless.

## Cost and limits

Each analysis is one model call with a 1280 px image (~1,600 input tokens)
plus a few hundred output tokens: around one US cent per photo. That is why
the app downsizes the image before uploading it.

Meal suggestions are text only, so they cost a fraction of that, and they are
generated only when someone taps the button.

Daily per-user limits are counted in Postgres (`consumir_cuota()`), not in the
Edge Functions: the limit is a constant inside the SQL function, so it cannot
be bypassed by calling the RPC by hand. 30 photo analyses and 20 suggestion
batches per day, counted separately so that using one does not block the
other. When a quota runs out, the app keeps working with the local food table,
which costs nothing.

## Tests

```bash
flutter test
```

82 tests on the logic that produces the numbers and on everything that touches
personal data: BMI and energy formulas, the limits that tighten with medical
conditions, every verdict rule, the diary store, the export format and the
deletion order (photos always before the account).

## Decisions

Decisions that would be expensive to reverse are in `docs/decisiones/`, with
the alternatives that were discarded and why:

| ADR | Decision |
|---|---|
| 0001 | The verdict comes from fixed rules, not from the model |
| 0002 | Foods are frozen inside the meal (jsonb) |
| 0003 | The analysis quota is counted in Postgres |
| 0004 | The app starts in demo mode when credentials are missing |
| 0005 | Liquids are entered in milliliters and stored in grams |
| 0006 | For suggestions, the model proposes and the rules decide |

## What this app is not

- **Portion size is an estimate.** Volume cannot be inferred from a flat
  photo. The usual error is around 20-30%, which is why the review screen lets
  you correct the amount before saving: grams for solids and milliliters for
  drinks, the way they are labeled. Good for spotting trends, not for a
  clinical plan.
- **BMI does not tell muscle from fat.** It is a starting reference.
- **The limits are for healthy adults.** Conditions marked in the profile
  tighten them, but they do not replace a health professional.
