import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/equipamento_provider.dart';
import 'providers/ocorrencia_provider.dart';
import 'routes/route_guard.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => EquipamentoProvider()),
        ChangeNotifierProvider(create: (_) => OcorrenciaProvider()),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp(
            title: 'SIGE - Indústria & Manutenção',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            initialRoute: '/login',
            onGenerateRoute: (settings) => RouteGuard.onGenerateRoute(settings, context),
          );
        },
      ),
    );
  }
}
