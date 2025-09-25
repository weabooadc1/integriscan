import 'package:flutter/material.dart';

/// Global keys to allow safe navigation and showing snackbars
/// from asynchronous callbacks without depending on a widget's
/// BuildContext which may be deactivated.
class AppKeys {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
}
