/// App-wide constants (mobile-conventions.md: no magic numbers inline).
library;

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'ATHENA_API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  static const iosSimulatorBaseUrl = 'http://localhost:8080/api/v1';
}

class Timeouts {
  static const connect = Duration(seconds: 10);
  static const receive = Duration(seconds: 20);

  /// Federated live search fans out to four providers server-side and can
  /// legitimately take 30s+; the default receive timeout always fires first.
  static const federatedSearch = Duration(seconds: 60);
}

class Paging {
  static const defaultLimit = 20;
  static const maxLimit = 100;
}
