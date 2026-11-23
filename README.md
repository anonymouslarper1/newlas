# Spark Intelligence (iOS)

A native SwiftUI iPhone app that checks Spark delivery offers against your own requirements and alerts you right away. You still make the final accept/decline decision in Spark.

## How it works
- **Rules tab:** set your min payout, $/mile, miles per $, hourly rate, max delivery distance, total miles, drop-offs, estimated time and shopping items, plus preferred stores, whether shopping orders are allowed, and custom requirements. Changes save instantly.
- **Live tab:** tap **Start Monitoring** and then **Start Broadcast**. iOS screen broadcast lets the `SparkBroadcast` extension see the screen while you use Spark. About 4 times per second it reads the screen with Apple's on-device text recognition, parses any offer card, and posts a **✅ MATCH** or **❌ SKIP** banner listing which conditions failed.
- **Quick Check tab:** type the numbers in, or pick a screenshot, to get an instant verdict.
- **History tab:** shows every offer seen and how it scored.

Everything runs on the phone. Nothing is uploaded, and the app never taps or accepts offers.

## Getting the .ipa
iOS apps can only be compiled on macOS, so `.github/workflows/build-ipa.yml` builds on GitHub's macOS runners on every push to `main` (or from **Actions → Build IPA → Run workflow**). The `.ipa` is attached to the **latest** GitHub Release and to the workflow run.

## Installing on an iPhone
The IPA is unsigned (it only has an ad-hoc signature), so install it with a sideloading tool that signs it with your Apple ID:
- **AltStore / SideStore:** open the `.ipa` from the Files app → AltStore. App Groups are handled automatically.
- **Sideloadly (Windows/Mac):** drag in the `.ipa` and keep app extensions enabled.

With a free Apple ID the app must be re-signed every 7 days. With a paid developer account, sign it once for a year.

## Building locally (Mac)
```
brew install xcodegen
xcodegen generate
open SparkIntelligence.xcodeproj
```
