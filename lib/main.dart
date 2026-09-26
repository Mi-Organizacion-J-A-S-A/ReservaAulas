import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <--- NUEVO
import 'package:shared_preferences/shared_preferences.dart';
import 'profesor_screen.dart';
import 'tecnico_screen.dart';
import 'database_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- CARGA DE VARIABLES DE ENTORNO ---
  await dotenv.load(fileName: ".env");

  // Inicialización de Supabase con los datos del .env
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',  
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',  
  );

  runApp(const ReservaAulasApp());
}

final DatabaseRepository db = SupabaseRepository();

class ReservaAulasApp extends StatelessWidget {
  const ReservaAulasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reserva de Aulas',
      debugShowCheckedModeBanner: false,
      // --- CONFIGURACIÓN DE LOCALIZACIÓN ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('gl', 'ES'), // Gallego
      ],
      locale: const Locale('es', 'ES'), // Idioma por defecto en la interfaz
      // -------------------------------------
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const SeleccionRolScreen(),
    );
  }
}

// --- PANTALLA DE SELECCIÓN DE ROL ---
class SeleccionRolScreen extends StatelessWidget {
  const SeleccionRolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text('Gestión de Aulas', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              icon: const Icon(Icons.person),
              label: const Text('Soy Cliente (Profesor)'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20), minimumSize: const Size(250, 60)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClienteLoginScreen())),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Soy Técnico'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(20), minimumSize: const Size(250, 60)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TecnicoLoginScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PANTALLA CLIENTE (Profesor) ---
class ClienteLoginScreen extends StatefulWidget {
  const ClienteLoginScreen({super.key});
  @override
  State<ClienteLoginScreen> createState() => _ClienteLoginScreenState();
}

class _ClienteLoginScreenState extends State<ClienteLoginScreen> {
  final _nombreController = TextEditingController();

  void _entrar() {
    if (_nombreController.text.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CalendarioReservaScreen(nombreProfesor: _nombreController.text.trim())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identificación Profesor')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre del Profesor', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _entrar, child: const Text('Entrar al Panel de Reservas'))
          ],
        ),
      ),
    );
  }
}

// --- PANTALLA ACCESO TÉCNICO ---
class TecnicoLoginScreen extends StatefulWidget {
  const TecnicoLoginScreen({super.key});

  @override
  State<TecnicoLoginScreen> createState() => _TecnicoLoginScreenState();
}

class _TecnicoLoginScreenState extends State<TecnicoLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarCredencialesGuardadas();
  }

  Future<void> _cargarCredencialesGuardadas() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('tecnico_email') ?? '';
      _passwordController.text = prefs.getString('tecnico_password') ?? '';
    });
  }

  Future<void> _guardarCredenciales() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un correo y contraseña para guardarlos'), backgroundColor: Colors.orange),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tecnico_email', email);
    await prefs.setString('tecnico_password', password);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciales guardadas 💾'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _loginTecnico() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, introduce tu correo y contraseña'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      await db.loginTecnico(email, password);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PanelTecnicoCalendarioScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error inesperado: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso Técnico')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings, size: 70, color: Colors.blueAccent),
                const SizedBox(height: 10),
                const Text('Panel de Gestión', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextButton.icon(
                  icon: const Icon(Icons.save, color: Colors.blueAccent),
                  label: const Text('Guardar correo y contraseña', style: TextStyle(color: Colors.blueAccent)),
                  onPressed: _guardarCredenciales,
                ),
                const SizedBox(height: 20),
                _cargando
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                        icon: const Icon(Icons.login),
                        label: const Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
                        onPressed: _loginTecnico,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
