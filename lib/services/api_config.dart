import 'auth_service.dart';

/// Single source of truth for the backend API base URL.
///
/// Use 10.0.2.2 for Android emulator (maps to host machine localhost).
/// Replace with your machine's local IP when running on a physical device.
const String apiBaseUrl = 'https://beontag.cm.utfpr.edu.br';

/// Returns the base HTTP headers for every API request.
/// Includes X-User-Id and X-User-Name when the user is logged in.
Map<String, String> apiHeaders({Map<String, String>? extra}) {
  final user = AuthService().currentUser;
  final headers = <String, String>{
    if (extra != null) ...extra,
    if (user != null) ...{
      'X-User-Id': user.id,
      'X-User-Name': Uri.encodeComponent(user.nome),
    },
  };
  return headers;
}
