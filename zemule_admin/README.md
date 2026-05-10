# Zemule Admin

Flutter web admin panel for Zemule.

## Secret URL Access

This app does not use login. Access is controlled by a secret path provided at build/run time with `--dart-define`.

The app reads:
- `ADMIN_SECRET_PATH` from `String.fromEnvironment('ADMIN_SECRET_PATH')`
- default (dev fallback): `/admin-dev-local`

## Run (Web)

```bash
flutter run -d chrome --dart-define=ADMIN_SECRET_PATH=your-secret-here
```

Example:
```bash
flutter run -d chrome --dart-define=ADMIN_SECRET_PATH=/zemule-admin-9f3k2
```

## Build (Web)

```bash
flutter build web --dart-define=ADMIN_SECRET_PATH=your-secret-here
```

Example:
```bash
flutter build web --dart-define=ADMIN_SECRET_PATH=/zemule-admin-9f3k2
```

## Behavior

- Visiting `/<your-secret-here>` loads the admin panel.
- Visiting any other path shows `Not found`.
