import 'dart:async'; // <-- AÑADIDO PARA StreamSubscription
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'main.dart';

class PanelTecnicoCalendarioScreen extends StatefulWidget {
  const PanelTecnicoCalendarioScreen({super.key});

  @override
  State<PanelTecnicoCalendarioScreen> createState() => _PanelTecnicoCalendarioScreenState();
}

class _PanelTecnicoCalendarioScreenState extends State<PanelTecnicoCalendarioScreen> {
  DateTime _focusedDay = DateTime.now();

  DateTime? _selectedDayInfo1;
  DateTime? _selectedDayInfo2;
  DateTime? _selectedDayPolos;

  String? _selectedHoraInfo1;
  String? _selectedHoraInfo2;
  String? _selectedHoraPolos;

  Set<String> _diasBloqueadosTotales = {};
  Map<String, Map<String, dynamic>> _reservasCache = {};

  Set<String> _diasConReservasInfo1 = {};
  Set<String> _diasConReservasInfo2 = {};
  Set<String> _diasConReservasPolos = {};

  List<Map<String, dynamic>> _listaPeticionesPendientes = [];
  bool _cargando = true;

  // Suscripciones a streams de Supabase
  StreamSubscription? _reservasSubscription;
  StreamSubscription? _bloqueadosSubscription;

  final Map<String, IconData> _iconosUsos = {
    'Impresora 3D': Icons.view_in_ar,
    'Cortadora láser': Icons.cut,
    'Vídeo': Icons.videocam,
    'Radio': Icons.radio,
    'Clase': Icons.school,
    'Acto': Icons.event,
    'Tamén len': Icons.menu_book,
    'E-twining': Icons.public,
    'Outros Usos': Icons.more_horiz,
  };

  final List<String> _tramosManana = ['8:30-9:20', '9:20-10:10', '10:10-11:00', '11:00-11:50', '12:20-13:10', '13:10-14:00'];
  final List<String> _tramosLunesTarde = ['16:30-17:20', '17:20-18:10'];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _suscribirseACambios();
    _suscribirseABloqueados();
  }

  @override
  void dispose() {
    _reservasSubscription?.cancel();
    _bloqueadosSubscription?.cancel();
    super.dispose();
  }

  // --- MÉTODOS DE FORMATEO ---
  String _formatFechaDb(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatFechaUi(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatFechaStringA_Ui(String fechaDb) {
    try {
      DateTime dt = DateTime.parse(fechaDb);
      return _formatFechaUi(dt);
    } catch (_) {
      return fechaDb;
    }
  }

  String _normalizarHoraDb(String horaDb) {
    String limpia = horaDb.trim();
    if (limpia.contains(':')) {
      List<String> partes = limpia.split(':');
      if (partes.length >= 2) {
        int horaInt = int.parse(partes[0]);
        int minInt = int.parse(partes[1]);
        return "$horaInt:${minInt.toString().padLeft(2, '0')}";
      }
    }
    return limpia;
  }

  String _obtenerHoraInicioTramo(String tramo) {
    return tramo.split('-')[0].trim();
  }

  List<String> _getTramosDisponibles(DateTime date) {
    List<String> tramos = List.from(_tramosManana);
    if (date.weekday == DateTime.monday) {
      tramos.addAll(_tramosLunesTarde);
    }
    return tramos;
  }

  // --- PROCESAMIENTO DE DATOS (compartido entre carga inicial y stream) ---
  void _procesarReservas(List<Map<String, dynamic>> reservasData) {
    final Map<String, Map<String, dynamic>> cacheTemporal = {};
    final List<Map<String, dynamic>> pendientesTemporal = [];
    final Set<String> diasOcupadosInfo1 = {};
    final Set<String> diasOcupadosInfo2 = {};
    final Set<String> diasOcupadosPolos = {};

    for (var row in reservasData) {
      if (row['fecha'] == null || row['hora_inicio'] == null) continue;

      String fechaKey = _formatFechaDb(DateTime.parse(row['fecha']));
      String aula = row['aula'].toString().trim();
      String horaInicioDb = _normalizarHoraDb(row['hora_inicio'].toString());
      String estado = row['estado']?.toString().trim() ?? 'pendiente';
      String profesor = row['nombre_cliente'] ?? 'Desconocido';

      if (estado != 'denegada') {
        if (aula == 'Informática 1') diasOcupadosInfo1.add(fechaKey);
        if (aula == 'Informática 2') diasOcupadosInfo2.add(fechaKey);
        if (aula == 'Polos') diasOcupadosPolos.add(fechaKey);
      }

      String searchKey = "${aula}_${fechaKey}_$horaInicioDb";
      cacheTemporal[searchKey] = {
        'id': row['id'],
        'cliente': profesor,
        'estado': estado,
        'uso': row['uso']?.toString() ?? 'Outros Usos'
      };

      if (estado == 'pendiente') {
        pendientesTemporal.add({
          'id': row['id'],
          'aula': aula,
          'fecha': fechaKey,
          'hora': horaInicioDb,
          'profesor': profesor,
          'uso': row['uso']?.toString() ?? 'Outros Usos'
        });
      }
    }

    if (mounted) {
      setState(() {
        _reservasCache = cacheTemporal;
        _listaPeticionesPendientes = pendientesTemporal;
        _diasConReservasInfo1 = diasOcupadosInfo1;
        _diasConReservasInfo2 = diasOcupadosInfo2;
        _diasConReservasPolos = diasOcupadosPolos;
        _cargando = false;
      });
    }
  }

  // --- CARGA INICIAL DE DATOS ---
  Future<void> _cargarDatos() async {
    try {
      final bloqueadosData = await supabase.from('dias_bloqueados').select('fecha');
      final Set<String> bloqueadosFechas = {};
      for (var row in bloqueadosData) {
        if (row['fecha'] != null) {
          bloqueadosFechas.add(_formatFechaDb(DateTime.parse(row['fecha'])));
        }
      }
      setState(() {
        _diasBloqueadosTotales = bloqueadosFechas;
      });

      final reservasData = await supabase.from('reservas').select('id, fecha, aula, hora_inicio, nombre_cliente, estado, uso');
      _procesarReservas(reservasData);
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- SUSCRIPCIÓN A CAMBIOS EN TIEMPO REAL (Reservas) ---
  void _suscribirseACambios() {
    _reservasSubscription = supabase
        .from('reservas')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> reservas) {
          _procesarReservas(reservas);
        }, onError: (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error en la conexión en tiempo real: $e'), backgroundColor: Colors.red),
            );
          }
        });
  }

  // --- SUSCRIPCIÓN A CAMBIOS EN TIEMPO REAL (Días Bloqueados) ---
  void _suscribirseABloqueados() {
    _bloqueadosSubscription = supabase
        .from('dias_bloqueados')
        .stream(primaryKey: ['fecha'])
        .listen((List<Map<String, dynamic>> bloqueados) {
          if (!mounted) return;
          final Set<String> bloqueadosFechas = {};
          for (var row in bloqueados) {
            if (row['fecha'] != null) {
              bloqueadosFechas.add(_formatFechaDb(DateTime.parse(row['fecha'])));
            }
          }
          setState(() {
            _diasBloqueadosTotales = bloqueadosFechas;
          });
        });
  }

  // --- ACTUALIZAR ESTADO DE RESERVA ---
  Future<void> _cambiarEstadoReserva(dynamic id, String nuevoEstado) async {
    try {
      await supabase.from('reservas').update({'estado': nuevoEstado}).match({'id': id});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado a $nuevoEstado 🛠️'), backgroundColor: Colors.blue),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // --- BUILD PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    final anchoPantalla = MediaQuery.of(context).size.width;
    final esPantallaAncha = anchoPantalla > 900;

    Widget cuerpoCalendarios = DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Aulas'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Informática 1'),
              Tab(text: 'Informática 2'),
              Tab(text: 'Polos'),
            ]
          ),
        ),
        body: TabBarView(
          children: [
            _buildPanelTecnico('Informática 1', _selectedDayInfo1, _selectedHoraInfo1,
              (date) => setState(() { _selectedDayInfo1 = date; _selectedHoraInfo1 = null; _focusedDay = date; }),
              (hora) => setState(() => _selectedHoraInfo1 = hora)),
            _buildPanelTecnico('Informática 2', _selectedDayInfo2, _selectedHoraInfo2,
              (date) => setState(() { _selectedDayInfo2 = date; _selectedHoraInfo2 = null; _focusedDay = date; }),
              (hora) => setState(() => _selectedHoraInfo2 = hora)),
            _buildPanelTecnico('Polos', _selectedDayPolos, _selectedHoraPolos,
              (date) => setState(() { _selectedDayPolos = date; _selectedHoraPolos = null; _focusedDay = date; }),
              (hora) => setState(() => _selectedHoraPolos = hora)),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Técnico (Completo)'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : esPantallaAncha
              ? Row(
                  children: [
                    Expanded(flex: 7, child: cuerpoCalendarios),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(flex: 3, child: _buildPanelAvisosLaterales()),
                  ],
                )
              : Column(
                  children: [
                    Expanded(flex: 6, child: cuerpoCalendarios),
                    const Divider(height: 1, thickness: 1),
                    Expanded(flex: 4, child: _buildPanelAvisosLaterales()),
                  ],
                ),
    );
  }

  // --- PANEL LATERAL DE PETICIONES PENDIENTES ---
  Widget _buildPanelAvisosLaterales() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Nuevas Peticiones (${_listaPeticionesPendientes.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _listaPeticionesPendientes.isEmpty
                ? const Center(child: Text('No hay avisos ni peticiones pendientes 🙌', style: TextStyle(color: Colors.grey, fontSize: 13)))
                : ListView.builder(
                    itemCount: _listaPeticionesPendientes.length,
                    itemBuilder: (context, index) {
                      final peticion = _listaPeticionesPendientes[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.blueGrey.shade700, borderRadius: BorderRadius.circular(4)),
                                    child: Text(peticion['aula'], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  Text(_formatFechaStringA_Ui(peticion['fecha']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Profesor: ${peticion['profesor']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Tramo/Hora: ${peticion['hora']}', style: const TextStyle(fontSize: 13, color: Colors.black87)),

                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(_iconosUsos[peticion['uso']] ?? Icons.more_horiz, size: 14, color: Colors.blueGrey),
                                  const SizedBox(width: 4),
                                  Text('Uso: ${peticion['uso']}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                                ],
                              ),

                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                                    label: const Text('Denegar', style: TextStyle(color: Colors.red)),
                                    onPressed: () => _cambiarEstadoReserva(peticion['id'], 'denegada'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Aprobar'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                                    onPressed: () => _cambiarEstadoReserva(peticion['id'], 'aceptada'),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- PANEL DE CALENDARIO POR AULA ---
  Widget _buildPanelTecnico(String aula, DateTime? selectedDay, String? selectedHora, Function(DateTime) onDaySelected, Function(String) onHoraSelected) {
    final fechaKeyDb = selectedDay != null ? _formatFechaDb(selectedDay) : '';
    final fechaKeyUi = selectedDay != null ? _formatFechaUi(selectedDay) : '';
    final horasDelDia = selectedDay != null ? _getTramosDisponibles(selectedDay) : <String>[];

    final String horaInicioSeleccionada = selectedHora != null ? _obtenerHoraInicioTramo(selectedHora) : "";
    final String searchKeyLocal = selectedHora != null ? "${aula}_${fechaKeyDb}_$horaInicioSeleccionada" : "";
    final infoReservaActual = selectedHora != null ? _reservasCache[searchKeyLocal] : null;

    Set<String> diasConReservasActual = _diasConReservasInfo1;
    if (aula == 'Informática 2') diasConReservasActual = _diasConReservasInfo2;
    if (aula == 'Polos') diasConReservasActual = _diasConReservasPolos;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TableCalendar(
            locale: 'es_ES',
            firstDay: DateTime.now().subtract(const Duration(days: 30)),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            focusedDay: _focusedDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            eventLoader: (day) {
              final k = _formatFechaDb(day);
              return diasConReservasActual.contains(k) ? ['ocupado'] : [];
            },
            onDaySelected: (sel, foc) => onDaySelected(sel),
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(color: Colors.blueGrey, shape: BoxShape.circle),
              markerDecoration: BoxDecoration(color: Colors.red.shade400, shape: BoxShape.circle),
            ),
          ),
          if (selectedDay != null) ...[
            const Divider(height: 40),
            Text('Control Técnico - Tramos $aula para el $fechaKeyUi:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: horasDelDia.map((tramo) {
                String horaInicioTramo = _obtenerHoraInicioTramo(tramo);
                String searchKey = "${aula}_${fechaKeyDb}_$horaInicioTramo";
                final datos = _reservasCache[searchKey];

                String estado = datos?['id'] != null ? (datos?['estado'] ?? 'pendiente') : 'libre';
                String cliente = datos?['cliente'] ?? '';
                bool esElegidoLocal = selectedHora == tramo;

                Color btnColor = Colors.grey.shade100;
                Color textColor = Colors.black87;

                if (estado == 'denegada') estado = 'libre';

                if (estado == 'aceptada') {
                  btnColor = Colors.green.shade200; textColor = Colors.green.shade900;
                } else if (estado == 'pendiente') {
                  btnColor = Colors.amber.shade200; textColor = Colors.amber.shade900;
                }

                if (esElegidoLocal) {
                  btnColor = Colors.blueGrey; textColor = Colors.white;
                }

                return ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: btnColor, foregroundColor: textColor),
                  onPressed: () => onHoraSelected(tramo),
                  child: Text('$tramo ${estado == 'libre' ? '' : '($cliente)'}'),
                );
              }).toList(),
            ),

            if (selectedHora != null) ...[
              const SizedBox(height: 30),
              Card(
                color: Colors.blueGrey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Tramo Seleccionado: $selectedHora', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),

                      if (infoReservaActual == null || infoReservaActual['estado'] == 'denegada') ...[
                        const Text('Este tramo está vacío y disponible.', style: TextStyle(color: Colors.grey)),
                      ] else ...[
                        Text('Estado Actual: ${infoReservaActual['estado'].toString().toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Profesor solicitante: ${infoReservaActual['cliente']}'),

                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_iconosUsos[infoReservaActual['uso']] ?? Icons.more_horiz, size: 18, color: Colors.black54),
                            const SizedBox(width: 5),
                            Text('Uso previsto: ${infoReservaActual['uso']}', style: const TextStyle(color: Colors.black87)),
                          ],
                        ),

                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check, color: Colors.white), label: const Text('Aprobar'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => _cambiarEstadoReserva(infoReservaActual['id'], 'aceptada'),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.cancel, color: Colors.white), label: const Text('Denegar'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => _cambiarEstadoReserva(infoReservaActual['id'], 'denegada'),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              )
            ]
          ]
        ],
      ),
    );
  }
}