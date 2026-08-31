import 'package:flutter_riverpod/flutter_riverpod.dart';

final userCreditsProvider =
    NotifierProvider<UserCreditsNotifier, int>(UserCreditsNotifier.new);

class UserCreditsNotifier extends Notifier<int> {
  @override
  int build() => 12; // 12 standard generation credits

  bool hasEnough(int amount) => state >= amount;

  bool deduct(int amount) {
    if (state < amount) return false;
    state = state - amount;
    return true;
  }

  void add(int amount) {
    state = state + amount;
  }
}
