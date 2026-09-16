# Final v6 build fix

The Final v5 planner added a `ValueListenable<int>` parameter so the Planner refreshes Saved Addresses whenever the user returns from Profile.

Android Studio reported `ValueListenable` as unresolved in `lib/features/planner/route_planner_screen.dart`, causing the Flutter compile task to fail.

Final v6 explicitly imports:

```dart
import 'package:flutter/foundation.dart';
```

No Planner behavior was removed. Saved Addresses, Home → Work, Work → Home, Clear all, and all earlier Final features remain.

Run locally:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```
