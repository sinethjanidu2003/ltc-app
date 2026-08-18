import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/env.dart';
import 'core/network/api_client.dart';
import 'data/ltc_repository.dart';
import 'features/auth/access_scope.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/pin_offer_screen.dart';
import 'features/auth/screens/pin_setup_screen.dart';
import 'features/auth/screens/pin_unlock_screen.dart';
import 'screens/ltc_list_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/loading_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppEnv.load();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const LtcApp());
}

class LtcApp extends StatefulWidget {
  const LtcApp({super.key});

  @override
  State<LtcApp> createState() => _LtcAppState();
}

class _LtcAppState extends State<LtcApp> {
  late final ApiClient _api;
  late final AuthRepository _auth;
  late final LtcRepository _repository;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _auth = AuthRepository(apiClient: _api);
    _repository = LtcRepository(apiClient: _api, auth: _auth);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _repository.bootstrapOffline();
    await _auth.bootstrap();
  }

  @override
  void dispose() {
    _repository.dispose();
    _auth.dispose();
    _api.dispose();
    super.dispose();
  }

  Widget _home() {
    if (!_auth.isReady) return const _SplashGate();
    if (!_auth.isAuthenticated) return LoginScreen(auth: _auth);
    if (_auth.requiresPinUnlock) return PinUnlockScreen(auth: _auth);
    if (_auth.shouldOfferPinSetup) return PinOfferScreen(auth: _auth);
    if (_auth.isSettingUpPin) return PinSetupScreen(auth: _auth);
    return LtcListScreen(repository: _repository);
  }

  @override
  Widget build(BuildContext context) {
    return AccessScope(
      auth: _auth,
      child: ListenableBuilder(
        listenable: Listenable.merge([_repository, _auth]),
        builder: (context, _) {
          return MaterialApp(
            title: 'LTC Spasticity Assessment',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: _home(),
          );
        },
      ),
    );
  }
}

class _SplashGate extends StatelessWidget {
  const _SplashGate();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: LoadingView(message: 'Starting up…'),
    );
  }
}
