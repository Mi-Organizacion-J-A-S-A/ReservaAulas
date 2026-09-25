import 'package:flutter/material.dart';
import 'profesor_screen.dart';
import 'tecnico_screen.dart';

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
        MaterialPageRoute(builder: (_) => CalendarioReservaScreen(nombreProfesor: _nombreController.text)),
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

class TecnicoLoginScreen extends StatelessWidget {
  const TecnicoLoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso Técnico')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.lock_open),
          label: const Text('Entrar al Panel de Control Técnico'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PanelTecnicoCalendarioScreen())),
        )
      )
    );
  }
}