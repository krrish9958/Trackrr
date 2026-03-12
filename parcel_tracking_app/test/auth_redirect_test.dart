import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_tracking_app/src/routing/auth_redirect.dart';

void main() {
  test('redirects logged out users away from protected routes', () {
    expect(
      resolveAuthRedirect(isLoggedIn: false, matchedLocation: '/dashboard'),
      '/login',
    );
  });

  test('keeps logged out users on the login route', () {
    expect(
      resolveAuthRedirect(isLoggedIn: false, matchedLocation: '/login'),
      isNull,
    );
  });

  test('redirects logged in users away from login', () {
    expect(
      resolveAuthRedirect(isLoggedIn: true, matchedLocation: '/login'),
      '/dashboard',
    );
  });

  test('keeps logged in users on app routes', () {
    expect(
      resolveAuthRedirect(isLoggedIn: true, matchedLocation: '/shipments'),
      isNull,
    );
  });
}
