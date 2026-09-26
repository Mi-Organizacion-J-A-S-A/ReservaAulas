import 'package:supabase_flutter/supabase_flutter.dart';

// --- EL CONTRATO (Interfaz) ---
abstract class DatabaseRepository {
  Future<void> loginTecnico(String email, String password);
  Future<List<Map<String, dynamic>>> getDiasBloqueados();
  Future<List<Map<String, dynamic>>> getReservas();
  Future<List<Map<String, dynamic>>> crearReserva(Map<String, dynamic> reserva);
  Future<void> anularReserva(dynamic id);
  Future<void> actualizarEstadoReserva(dynamic id, String nuevoEstado);
  Stream<List<Map<String, dynamic>>> streamReservas();
  Stream<List<Map<String, dynamic>>> streamDiasBloqueados();
}

// --- LA IMPLEMENTACIÓN (Supabase) ---
class SupabaseRepository implements DatabaseRepository {
  final _client = Supabase.instance.client;

  @override
  Future<void> loginTecnico(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<List<Map<String, dynamic>>> getDiasBloqueados() async {
    return await _client.from('dias_bloqueados').select('fecha');
  }

  @override
  Future<List<Map<String, dynamic>>> getReservas() async {
    return await _client.from('reservas').select('id, fecha, aula, hora_inicio, nombre_cliente, estado, uso');
  }

  @override
  Future<List<Map<String, dynamic>>> crearReserva(Map<String, dynamic> reserva) async {
    return await _client.from('reservas').insert(reserva).select();
  }

  @override
  Future<void> anularReserva(dynamic id) async {
    await _client.from('reservas').delete().match({'id': id});
  }

  @override
  Future<void> actualizarEstadoReserva(dynamic id, String nuevoEstado) async {
    await _client.from('reservas').update({'estado': nuevoEstado}).match({'id': id});
  }

  @override
  Stream<List<Map<String, dynamic>>> streamReservas() {
    return _client.from('reservas').stream(primaryKey: ['id']);
  }

  @override
  Stream<List<Map<String, dynamic>>> streamDiasBloqueados() {
    return _client.from('dias_bloqueados').stream(primaryKey: ['fecha']);
  }
}