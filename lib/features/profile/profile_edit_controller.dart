import 'package:flutter/foundation.dart';

/// Tracks unsaved profile edits so navigation can protect the user's changes.
class ProfileEditController extends ChangeNotifier {
  bool _isDirty = false;
  VoidCallback? _discardCallback;

  bool get isDirty => _isDirty;

  void setDirty(bool value) {
    if (_isDirty == value) return;
    _isDirty = value;
    notifyListeners();
  }

  void attachDiscard(VoidCallback callback) {
    _discardCallback = callback;
  }

  void detachDiscard() {
    _discardCallback = null;
  }

  void discardChanges() {
    _discardCallback?.call();
    setDirty(false);
  }
}
