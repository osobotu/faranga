# Faranga

<p align="center">
  <img src="assets/icon.png" width="120" alt="MoMo Finance icon"/>
</p>

<p align="center">
  <strong>Track your MoMo spending automatically. Private. Local. Free.</strong>
</p>

Faranga reads your MTN Mobile Money SMS messages and turns them into organized, categorized financial data — entirely on your device. Nothing leaves your phone.

Built for Rwanda, works with MTN MoMo.

## Features

- **Automatic SMS parsing** — reads MoMo transaction messages (transfers, merchant payments, received money)
- **Spending analytics** — daily, weekly, monthly totals with month-over-month trends
- **Category breakdown** — auto-categorizes merchants (groceries, transport, utilities, etc.)
- **Top recipients** — see where your money goes most
- **Day-of-week patterns** — discover your spending habits
- **Periodic sync** — auto-refreshes every 15 minutes while the app is open
- **100% offline** — all data stays on your device in a local database

## Download

**[Download the latest APK from Releases →](../../releases/latest)**

> Requires Android 7.0+ (API 24). You may need to enable "Install from unknown sources" in your phone settings.

<!-- ## Screenshots -->

## Privacy

MoMo Finance is designed with privacy as a core principle:

- **No internet permission** — the app cannot send data anywhere
- **No accounts** — no sign-up, no login
- **Local database** — all transaction data is stored in SQLite on your device
- **SMS read-only** — the app reads messages but never sends or modifies them
- **Open source** — inspect the code yourself

## Supported message formats

| Type | Example |
|---|---|
| P2P Transfer | `*165*S*2200 RWF transferred to Name (250...) at ...` |
| Merchant Payment | `TxId:...*S*Your payment of 3,300 RWF to SHOP NAME ...` |
| Received Money | `You have received 7000 RWF from Name (*****940) at ...` |

Adding a new format is straightforward — see `lib/services/momo_parser.dart`.

## Build from source

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.44+
- Android SDK (API 34+)
- Java 21

### Steps

```bash
# Clone the repo
git clone https://github.com/osobotu/momo-finance.git
cd momo-finance

# Install dependencies
flutter pub get

# Generate the app icon
flutter pub run flutter_launcher_icons

# Run in debug mode (with device connected)
flutter run

# Build release APK
flutter build apk --release
```

The release APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

### Signing a release build

To build a signed release APK:

1. Generate a keystore (one time):
   ```bash
   keytool -genkey -v -keystore ~/momo-finance.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias faranga
   ```

2. Create `android/key.properties` (do NOT commit this file):
   ```properties
   storePassword=YOUR_PASSWORD
   keyPassword=YOUR_PASSWORD
   keyAlias=momo-finance
   storeFile=/home/YOUR_USER/faranga.jks
   ```

3. Build:
   ```bash
   flutter build apk --release
   ```

## Project structure

```
lib/
├── main.dart                      # App entry, home screen UI
├── models/
│   └── transaction.dart           # MomoTransaction data model
├── screens/
│   ├── analytics_screen.dart      # Spending analytics dashboard
│   └── onboarding_screen.dart     # First-launch permission screen
└── services/
    ├── analytics_service.dart     # Spending calculations & summaries
    ├── category_service.dart      # Auto-categorization engine
    ├── database_service.dart      # SQLite storage layer
    ├── momo_parser.dart           # SMS regex parser (add new formats here)
    ├── sms_service.dart           # Platform channel to Android SMS
    └── sync_manager.dart          # Periodic sync scheduler
```

## Contributing

Contributions are welcome! Some ideas:

- **New SMS formats** — if your MoMo messages don't parse, open an issue with the message format (redact personal info) and we'll add a parser
- **More analytics** — weekly trends chart, budget tracking, spending forecasts
- **Export** — CSV or Google Sheets export

## License

MIT — see [LICENSE](LICENSE).
