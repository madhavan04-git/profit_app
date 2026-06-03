# Profit Tracker App — Complete Setup Guide
### For first-time Flutter users

---

## WHAT THIS APP DOES
- Add daily sales (select product → enter kg or pieces → profit auto-calculated)
- See today's total profit and monthly target progress bar
- Monthly report with bar chart, calendar heatmap, product breakdown
- All data saved locally on your phone — no internet needed, completely free

---

## STEP 1 — Install Flutter on your computer

### Windows:
1. Go to https://flutter.dev/docs/get-started/install/windows
2. Download Flutter SDK zip → extract to C:\flutter
3. Add C:\flutter\bin to your system PATH
4. Open Command Prompt → type: flutter doctor
   (It will show you what else to install)

### Mac:
1. Go to https://flutter.dev/docs/get-started/install/macos
2. Download Flutter SDK → extract to ~/flutter
3. Add to PATH: export PATH="$PATH:~/flutter/bin"
4. Run: flutter doctor

---

## STEP 2 — Install Android Studio

1. Download from https://developer.android.com/studio
2. Install it (just click Next through everything)
3. Open Android Studio → go to SDK Manager → install Android SDK
4. In Android Studio: go to Plugins → search "Flutter" → Install
5. Also install the "Dart" plugin

---

## STEP 3 — Set up your phone (easier than emulator)

1. On your Android phone: Settings → About Phone → tap "Build Number" 7 times
   (This enables Developer Options)
2. Settings → Developer Options → turn ON "USB Debugging"
3. Connect your phone to computer with USB cable
4. Phone will ask "Allow USB debugging?" → tap YES

---

## STEP 4 — Create the Flutter project

Open Terminal (Mac) or Command Prompt (Windows):

```
flutter create profit_tracker
cd profit_tracker
```

---

## STEP 5 — Replace files with the provided code

Delete the default files and copy in the code files provided:

Your folder structure should look like this:
```
profit_tracker/
├── pubspec.yaml          ← REPLACE this file
├── lib/
│   ├── main.dart         ← REPLACE this file
│   ├── models/
│   │   ├── product.dart  ← NEW file (create this folder)
│   │   └── sale.dart     ← NEW file
│   ├── db/
│   │   └── database_helper.dart  ← NEW file (create this folder)
│   └── screens/
│       ├── home_screen.dart      ← NEW file (create this folder)
│       └── monthly_screen.dart   ← NEW file
```

---

## STEP 6 — Install dependencies

In Terminal/Command Prompt (inside your project folder):
```
flutter pub get
```
You should see: Running "flutter pub get" in profit_tracker... (success)

---

## STEP 7 — Run the app

Make sure your phone is connected, then:
```
flutter run
```

First time takes 2-3 minutes to build. After that it's fast.

If you see your phone listed, press the number to select it.

---

## STEP 8 — Build APK to install on phone permanently

```
flutter build apk --release
```

The APK file will be at:
  build/app/outputs/flutter-apk/app-release.apk

Copy this file to your phone and install it.
(You may need to allow "Install from unknown sources" in your phone settings)

---

## HOW TO USE THE APP

### Adding a daily sale:
1. Open app → you see today's date
2. Tap blue "+ Add Sale" button
3. Select product from dropdown (SS-I, SS-II... BR-II, BR-III...)
4. Enter quantity:
   - For SS products (except SS-IV): enter KG sold (e.g. 2.5 for 2.5 kg)
   - For SS-IV only: enter number of PIECES (e.g. 10 for 10 pieces)
   - For Brass products: enter KG sold
5. Profit is automatically calculated and shown
6. Tap "Save Sale"

### Viewing a past date:
- Tap the date button at top → pick any date → see that day's sales

### Monthly report:
- Tap the chart icon (top right) → see full monthly breakdown
- Use < > arrows to go to previous months

---

## PRODUCT PROFIT RATES (built into app)

| Product   | Unit | Profit/unit |
|-----------|------|-------------|
| SS-I      | kg   | Rs 63.00    |
| SS-II     | kg   | Rs 86.67    |
| SS-III    | kg   | Rs 86.67    |
| SS-IV     | pcs  | Rs 20.00    |
| BR-II     | kg   | Rs 200.00   |
| BR-III    | kg   | Rs 185.56   |
| BR-IV     | kg   | Rs 110.00   |
| BR-V      | kg   | Rs 200.00   |
| BR-VI     | kg   | Rs 166.67   |

---

## COMMON ERRORS AND FIXES

**Error: "flutter not found"**
→ Flutter not added to PATH. Redo Step 1.

**Error: "No devices found"**
→ USB debugging not enabled OR phone not connected. Redo Step 3.

**Error: "Gradle build failed"**
→ Run: flutter clean → then: flutter run

**Error: "pub get failed"**
→ Check internet connection → run: flutter pub get again

**App crashes on open**
→ Run: flutter logs — to see the error message

---

## IF YOU WANT TO CHANGE COSTS IN FUTURE

Open  lib/models/product.dart
Find the product you want to change
Update the numbers in totalCostPerProduct
Run: flutter run (or rebuild APK)

Example: to change SS-I polishing cost from Rs 44 to Rs 50:
Old: totalCostPerProduct: 83.5,   (7+12.5+4+8+8+44)
New: totalCostPerProduct: 89.5,   (7+12.5+4+8+8+50)

---

## NEED HELP?

If you get stuck on any step, share the exact error message
and which step you are on. I will help you fix it.
