# SpendTracker

## App Preview

![SpendTracker welcome screen with the wallet illustration, tagline, and Get Started button](User%20attachment4.png)

## About the Project

SpendTracker is a Flutter personal finance app for recording expenses, reviewing monthly spending, and keeping track of bills in Philippine pesos (PHP). It uses a pink-themed interface with a welcome screen, dashboard, expense overview, and bill management screens.

The live app starts with empty records for new accounts and loads existing records from MySQL on sign-in. Changes save automatically, with an account-specific Android cache for pending saves. Dashboard totals reflect recorded expenses and income. It includes income management, history, themes, transaction activity, payment follow-ups, and monthly expense alerts. The welcome artwork keeps its original pink branding.

## Node.js and MySQL backend

The [backend setup guide](backend/README.md) explains how to run the Node.js API with XAMPP MySQL/MariaDB. The app opens **Welcome → Sign in / Create account → Home**. Bills, payments, records, categories, activity, and settings save automatically to the signed-in account. A visible status reports failed saves and provides retry/reload controls. **More → Settings → Data → Cloud backup** lets you review the server copy; JSON export provides a separate backup file.

For the Android emulator, the default API URL is `http://10.0.2.2:3000`. Start XAMPP MySQL and run `npm start` from `backend`. Database credentials remain in the ignored `backend/.env` file and are never included in Flutter or app backups.

## Features

- Welcome screen with a custom wallet illustration and a Get Started button.
- Dashboard with sample balance, income, and spending summaries, a balance visibility toggle, and a live preview of unpaid bills.
- Expense entry with an amount, category, description, and date, including form validation.
- Monthly expense navigation, spending totals, comparison with the previous month, category breakdowns, a donut chart, and a transaction list.
- Eight expense categories: Food, Shopping, Transportation, Bills, Entertainment, Others, Health, and Education.
- Bill entry with a name, amount, due date, icon, repeat preference, and reminder preference.
- Bills sorted by due date, with All, Paid, Due Soon, and Unpaid filters and the ability to mark bills as paid or unpaid.
- Responsive layouts with constrained content widths and scrollable forms.

## Technology Stack

- **Language:** Dart, with SDK constraint `^3.13.7`.
- **Framework:** Flutter with Material widgets and Material icons.
- **State management:** Flutter's built-in `StatefulWidget`, `setState`, `ChangeNotifier`, and `AnimatedBuilder`.
- **Navigation:** Flutter `Navigator` and `MaterialPageRoute`.
- **Graphics:** Flutter `CustomPainter` and Canvas for the expense chart, welcome illustration, and decorative background.
- **Icon dependency:** `cupertino_icons` (`^1.0.8`).
- **Testing and linting:** `flutter_test` and `flutter_lints` (`^6.0.0`).
- **Data storage:** Authenticated MySQL/MariaDB account data through Node.js, automatic saves, account-specific pending copies on Android, and JSON export.
- **Backend:** Express, MySQL2 connection pooling, validated versioned app documents, salted password hashing, and expiring sessions.
- **Platform scaffolding:** Android, iOS, web, Windows, macOS, and Linux.
