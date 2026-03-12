String? resolveAuthRedirect({
  required bool isLoggedIn,
  required String matchedLocation,
}) {
  final isLoggingIn = matchedLocation == '/login';

  if (!isLoggedIn && !isLoggingIn) {
    return '/login';
  }

  if (isLoggedIn && isLoggingIn) {
    return '/dashboard';
  }

  return null;
}
