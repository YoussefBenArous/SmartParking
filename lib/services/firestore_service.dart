Future<T> retryOperation<T>(Future<T> Function() operation, {int maxAttempts = 3}) async {
  int attempts = 0;
  while (attempts < maxAttempts) {
    try {
      return await operation();
    } catch (e) {
      attempts++;
      if (attempts == maxAttempts) rethrow;
      await Future.delayed(Duration(seconds: attempts));
    }
  }
  throw Exception('Operation failed after $maxAttempts attempts');
}