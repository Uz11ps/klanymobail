import 'env.dart';
import 'api_client.dart';

class Sdk {
  static ApiClient? get apiOrNull {
    if (!Env.hasApiConfig) return null;
    return ApiClient(Env.apiBaseUrl);
  }
}

