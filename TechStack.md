# Agency Ops & Profit-Share Mobile App: Complete Tech Stack

## 1. Major Tech Stack (The Core Engine)
* **Frontend Framework:** Flutter (Dart). Cross-platform compilation for native iOS and Android.
* **Backend Database:** Firebase Cloud Firestore (NoSQL). Handles real-time data syncing for tasks, clients, and the live profit pool.
* **Authentication:** Firebase Auth. Secure login for the four equal co-founders.
* **Offline Persistence:** Firestore Offline Cache (Built-in). Allows the app to load instantly and queue task verifications even if a cousin is temporarily off-Wi-Fi.

## 2. Minor Tech Stack (State & Architecture)
* **State Management:** `flutter_riverpod`. The modern, safe standard for managing the complex live scoring and profit calculations across different screens.
* **Routing:** `go_router`. Handles declarative navigation between the Dashboard, Task Lists, Admin Verification, and QR Scanner.
* **UI/UX System:** Material Design 3 (Native to Flutter) paired with the `google_fonts` package for a clean, modern, and professional aesthetic.

## 3. Specialized Packages (Feature-Specific Modules)
* **QR Code Generation (Admin):** `qr_flutter`. Renders the secure, daily attendance QR code directly on the Admin's screen.
* **QR Code Scanning (Member):** `mobile_scanner`. Uses the device camera to read the Admin's daily code and award the 10 attendance points.
* **Report Generation (History):** * `pdf`: To generate the downloadable, stylized end-of-month P&L and Teammate Payout reports.
    * `csv`: To export the granular, day-by-day task and client history before the Day 8 data pruning.
    * `path_provider`: To save these exported files directly to the user's local device storage.
* **Date & Math Formatting:** `intl`. Crucial for formatting currency (Net Profit Pool) and handling the strict time-boxing (e.g., "2 Days allocated") and monthly history rollovers.