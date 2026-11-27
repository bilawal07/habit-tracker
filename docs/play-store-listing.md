# HotFire Habits — Google Play Store & Launch Checklist

## 1. Store Listing Copy
- **App Name:** HotFire Habits
- **Short Description (64/80 chars):** Build unbreakable daily habits with Hot Fire vs Cold streaks.
- **Full Description:**
  HotFire Habits is a fast, 100% offline-first daily habit tracker built around real streak psychology:
  - **Zero Login, Instant Launch:** Open the app and start tracking in under 1 second — completely free and ad-free.
  - **Strict Today-Only Calendar:** Only today's checkbox is editable. Past and future days stay locked so every streak is 100% honest.
  - **Hot Fire vs. Cold Engine:** Watch your habit evolve from Ready → Spark → Hot Fire (3+ days) → Blazing (7+ days), or see Cold alerts when you miss a day so you can reignite.
  - **Escalating Daily Reminders:** Bundled reminders at 6:00 AM, 1:00 PM, 8:00 PM, and 11:00 PM stop immediately for today once you tap **Mark Done**.
  - **5 Milestone Badges:** Earn First Spark, 3-Day Flame, Comeback Phoenix, 7-Day Inferno, and 30-Day Unstoppable.
  - **Private & Portable:** All data lives locally in SQLite with 1-tap JSON Export / Import backup.

## 2. Privacy Policy Hosting (GitHub Pages)
1. Go to `https://github.com/bilawal07/habit-tracker/settings/pages`.
2. Under **Build and deployment**, select **Deploy from a branch** → `main` → `/docs`.
3. Use `https://bilawal07.github.io/habit-tracker/privacy-policy.html` in Google Play Console.

## 3. Firebase Analytics Setup (Optional External Step)
1. Create a free Firebase project and register Android package `com.habittracker.habit_tracker`.
2. Place `google-services.json` in `android/app/google-services.json`.
3. Add `firebase_core` + `firebase_analytics` and forward `AnalyticsSink` in `lib/services/analytics_service.dart` to `FirebaseAnalytics.instance.logEvent(...)`.

## 4. Release Signing & `.aab` Build
1. Generate upload keystore (keep safe outside git):
   ```powershell
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Configure `android/key.properties` and update `signingConfigs.release` in `android/app/build.gradle.kts`.
3. Build App Bundle:
   ```powershell
   flutter build appbundle --release
   ```
4. Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console **Closed Testing** track (14 days with 12 testers).

## 5. Physical Android Device Verification Checklist (Before Closed Testing)
- [ ] Clock midnight test: change phone clock from `11:58 PM` → `12:02 AM`, verify streak switches to Cold (or respects Night Owl Grace until `1:00 AM` when enabled).
- [ ] Reboot test: schedule reminders, reboot physical phone, confirm alarms restore via `BOOT_COMPLETED`.
- [ ] Doze / locked-screen test: lock phone and verify reminders + `"Mark Done"` notification action fire reliably.
- [ ] JSON backup round-trip: export `.json`, clear app storage / reinstall, import `.json`, confirm all tasks, logs, and badges restore.
