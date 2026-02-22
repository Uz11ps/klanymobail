import 'env.dart';
import 'api_client.dart';

class Sdk {
  static ApiClient? get apiOrNull => Env.hasApiConfig ? ApiClient(Env.apiBaseUrl) : null;
}

