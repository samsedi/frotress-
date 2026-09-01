import 'package:flutter/foundation.dart';

class RecoveryViewModel extends ChangeNotifier {
  // Shared state for the wizards
  int currentStep = 0;
  bool isProcessing = false;

  void nextStep() {
    currentStep++;
    notifyListeners();
  }

  void previousStep() {
    if (currentStep > 0) {
      currentStep--;
      notifyListeners();
    }
  }

  void reset() {
    currentStep = 0;
    isProcessing = false;
    notifyListeners();
  }
}
