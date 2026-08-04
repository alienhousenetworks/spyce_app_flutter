# SPYCE — Flutter (premium client)

Intent-first dating. **Not** an AI dating product. Discovery is **vertical scroll**, not a swipe deck.

## Stack

- Flutter 3.41 / Dart 3.11
- Riverpod · GoRouter · Dio · flutter_svg · Google Fonts (Syne + DM Sans)
- JWT auth with single-flight refresh
- SVG feed backgrounds from `assets/backgrounds/` (SpyceBgs pack)

## Configure

Default API host matches the web client:

```
https://testapi.spycenow.com/api/v1
wss://testapi.spycenow.com/ws
```

Override at build time:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://testapi.spycenow.com \
  --dart-define=WS_BASE_URL=wss://testapi.spycenow.com/ws
```

## Run

```bash
flutter pub get
flutter run
```

## App flow

1. **Splash** → session bootstrap  
2. **Auth** → email OTP (`/auth/register/`, `/auth/otp/verify/`)  
3. **Onboarding** → username, DOB, identity taxonomies, intent  
4. **Shell** tabs: Discover · Matches · Chat · Confessions · Profile  
5. **Discover** → vertical `PageView`, SVG card BGs via `bg_id` / `bg_variant_id`  
6. **Premium paywall** on subscription-gated feed/actions  
7. Blind Date exists on backend but is **not shipped** in this client  

## Assets

Feed SVG patterns live in `assets/backgrounds/` (Flame, Hex, Puzzle, Square, Star, Tri, Spyder + Warm/Cool/Spyce variants). Mapped in `lib/core/theme/feed_backgrounds.dart` (API codes B01–B12).

## Project layout

```
lib/
  core/          config, theme, network, storage, router
  data/          models + repositories (OpenAPI-aligned)
  features/      splash, auth, onboarding, discover, matches,
                 chat, confessions, profile, settings, premium, mood
  shared/        reusable widgets
```
