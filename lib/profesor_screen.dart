import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'main.dart';

class CalendarioReservaScreen extends StatefulWidget {
  final String nombreProfesor;
  const CalendarioReservaScreen({super.key, required this.nombreProfesor});

  @override
  State<CalendarioReservaScreen> createState() => _CalendarioReservaScreenState();
}

class _CalendarioReservaScreenState extends State<CalendarioReservaScreen> {
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
  bool _cargando = true;

  String _usoSeleccionado = 'Clase'; 
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
  }

  // Clave en formato estándar para consultas de Base de Datos YYYY-MM-DD
  String _formatFechaDb(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Formato visual amigable para España/Galicia DD/MM/YYYY
  String _formatFechaUi(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
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

  String _obtenerHoraInicioTramoUi(String tramo) {
    return tramo.split('-')[0].trim();
  }

  String _obtenerHoraInicioTramoDb(String tramo) {
    String horaRaw = tramo.split('-')[0].trim();
    List<String> partes = horaRaw.split(':');
    if (partes.length >= 2) {
      String h = partes[0].padLeft(2, '0');
      String m = partes[1].padLeft(2, '0');
      return "$h:$m:00";
    }
    return horaRaw;
  }

  List<String> _getTramosDisponibles(DateTime date) {
    List<String> tramos = List.from(_tramosManana);
    if (date.weekday == DateTime.monday) {
      tramos.addAll(_tramosLunesTarde);
    }
    return tramos;
  }

  Future<void> _cargarDatos() async {
    try {
      final bloqueadosData = await supabase.from('dias_bloqueados').select('fecha');
      final Set<String> bloqueadosFechas = {};
      for (var row in bloqueadosData) {
        if (row['fecha'] != null) {
          bloqueadosFechas.add(_formatFechaDb(DateTime.parse(row['fecha'])));
        }
      }

      final reservasData = await supabase.from('reservas').select('id, fecha, aula, hora_inicio, nombre_cliente, estado, uso');
      final Map<String, Map<String, dynamic>> cacheTemporal = {};
      final Set<String> diasOcupadosInfo1 = {};
      final Set<String> diasOcupadosInfo2 = {};
      final Set<String> diasOcupadosPolos = {};

      for (var row in reservasData) {
        if (row['fecha'] == null || row['hora_inicio'] == null) continue;
        
        String fechaKey = _formatFechaDb(DateTime.parse(row['fecha']));
        String aula = row['aula'].toString().trim();
        String horaInicioDb = _normalizarHoraDb(row['hora_inicio'].toString());
        String cliente = row['nombre_cliente']?.toString().trim() ?? '';
        String estado = row['estado']?.toString().trim() ?? 'pendiente';
        
        String tipo = (cliente.toLowerCase() == widget.nombreProfesor.trim().toLowerCase()) ? 'propia' : 'ajena';
        
        if (estado != 'denegada') {
          if (aula == 'Informática 1') diasOcupadosInfo1.add(fechaKey);
          if (aula == 'Informática 2') diasOcupadosInfo2.add(fechaKey);
          if (aula == 'Polos') diasOcupadosPolos.add(fechaKey);
        }

        String searchKey = "${aula}_${fechaKey}_$horaInicioDb";
        cacheTemporal[searchKey] = {
          'id': row['id'],
          'tipo': tipo,
          'estado': estado,
          'cliente': cliente,
          'uso': row['uso']?.toString().trim() ?? 'No especificado'
        };
      }

      setState(() {
        _diasBloqueadosTotales = bloqueadosFechas;
        _reservasCache = cacheTemporal;
        _diasConReservasInfo1 = diasOcupadosInfo1;
        _diasConReservasInfo2 = diasOcupadosInfo2;
        _diasConReservasPolos = diasOcupadosPolos;
        _cargando = false;
      });
    } catch (e) { 
      setState(() => _cargando = false); 
    }
  }

  Future<void> _confirmarReserva(String aula, DateTime fecha, String tramo) async {
    final String fechaString = _formatFechaDb(fecha);
    final String horaInicioDb = _obtenerHoraInicioTramoDb(tramo);
    final String horaInicioUi = _obtenerHoraInicioTramoUi(tramo);
    
    try {
      final response = await supabase.from('reservas').insert({
        'aula': aula.trim(),
        'fecha': fechaString,
        'hora_inicio': horaInicioDb,
        'nombre_cliente': widget.nombreProfesor.trim(),
        'estado': 'pendiente',
        'uso': _usoSeleccionado
      }).select();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Solicitud enviada para el tramo $tramo 🎉'), backgroundColor: Colors.orange));
      
      setState(() {
        String searchKey = "${aula.trim()}_${fechaString}_$horaInicioUi";
        _reservasCache[searchKey] = {
          'id': response[0]['id'], 
          'tipo': 'propia',
          'estado': 'pendiente',
          'cliente': widget.nombreProfesor.trim(),
          'uso': _usoSeleccionado
        };
        if (aula == 'Informática 1') _diasConReservasInfo1.add(fechaString);
        if (aula == 'Informática 2') _diasConReservasInfo2.add(fechaString);
        if (aula == 'Polos') _diasConReservasPolos.add(fechaString);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar reserva: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _anularReservaPropia(dynamic id, String aula) async {
    try {
      await supabase.from('reservas').delete().match({'id': id});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reserva anulada con éxito'), backgroundColor: Colors.green));
      _cargarDatos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  bool _esDiaInvalidoCompletamente(DateTime day) {
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) return true;
    return _diasBloqueadosTotales.contains(_formatFechaDb(day));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, 
      child: Scaffold(
        appBar: AppBar(
          title: Text('Profesor: ${widget.nombreProfesor}'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Informática 1'),
              Tab(text: 'Informática 2'),
              Tab(text: 'Polos'),
            ]
          ),
        ),
        body: _cargando 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                _buildPanelAula('Informática 1', _selectedDayInfo1, _selectedHoraInfo1, 
                  (date) => setState(() { _selectedDayInfo1 = date; _selectedHoraInfo1 = null; _focusedDay = date; }), (hora) => setState(() => _selectedHoraInfo1 = hora)),
                _buildPanelAula('Informática 2', _selectedDayInfo2, _selectedHoraInfo2, 
                  (date) => setState(() { _selectedDayInfo2 = date; _selectedHoraInfo2 = null; _focusedDay = date; }), (hora) => setState(() => _selectedHoraInfo2 = hora)),
                _buildPanelAula('Polos', _selectedDayPolos, _selectedHoraPolos, 
                  (date) => setState(() { _selectedDayPolos = date; _selectedHoraPolos = null; _focusedDay = date; }), (hora) => setState(() => _selectedHoraPolos = hora)),
              ],
            ),
      ),
    );
  }

  Widget _buildPanelAula(String aula, DateTime? selectedDay, String? selectedHora, Function(DateTime) onDaySelected, Function(String) onHoraSelected) {
    final fechaKeyDb = selectedDay != null ? _formatFechaDb(selectedDay) : '';
    final fechaKeyUi = selectedDay != null ? _formatFechaUi(selectedDay) : '';
    final horasDelDia = selectedDay != null ? _getTramosDisponibles(selectedDay) : <String>[];
    
    final String horaInicioSeleccionada = selectedHora != null ? _obtenerHoraInicioTramoUi(selectedHora) : "";
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
            locale: 'es_ES', // <--- ACTIVA EL IDIOMA ESPAÑOL EN EL CALENDARIO (Usa 'gl_ES' para Gallego)
            firstDay: DateTime.now().subtract(const Duration(days: 7)), lastDay: DateTime.now().add(const Duration(days: 90)), focusedDay: _focusedDay,
            startingDayOfWeek: StartingDayOfWeek.monday, selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            enabledDayPredicate: (day) => !_esDiaInvalidoCompletamente(day),
            eventLoader: (day) {
              final k = _formatFechaDb(day);
              return diasConReservasActual.contains(k) ? ['ocupado'] : [];
            },
            onDaySelected: (sel, foc) => onDaySelected(sel),
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              markerDecoration: BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
            ),
          ),
          if (selectedDay != null) ...[
            const Divider(height: 40),
            Text('Tramos para el $fechaKeyUi en $aula:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: horasDelDia.map((tramo) {
                String horaInicioTramo = _obtenerHoraInicioTramoUi(tramo);
                String searchKey = "${aula}_${fechaKeyDb}_$horaInicioTramo";
                final datos = _reservasCache[searchKey];

                bool esPropia = datos?['tipo'] == 'propia';
                bool esAjena = datos?['tipo'] == 'ajena';
                String estado = datos?['estado'] ?? '';
                bool esElegidoLocal = selectedHora == tramo;

                Color btnColor = Colors.grey.shade100; 
                Color textColor = Colors.black87; 
                VoidCallback? acciones = () => onHoraSelected(tramo);

                if (estado == 'denegada') {
                  estado = ''; esPropia = false; esAjena = false;
                }

                if (esPropia) {
                  btnColor = (estado == 'aceptada') ? Colors.green : Colors.amber.shade700;
                  textColor = Colors.white; 
                  if (!esElegidoLocal) acciones = () => onHoraSelected(tramo);
                } else if (esAjena && (estado == 'aceptada' || estado == 'pendiente')) {
                  btnColor = Colors.red.shade100; 
                  textColor = Colors.red.shade700; 
                  acciones = null; 
                } else if (esElegidoLocal) {
                  btnColor = Colors.blueAccent; 
                  textColor = Colors.white;
                }

                String suffix = '';
                if (esPropia && estado == 'pendiente') suffix = ' (Esp.)';
                if (esPropia && estado == 'aceptada') suffix = ' (Tuyo)';

                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: btnColor, foregroundColor: textColor),
                  onPressed: acciones,
                  icon: Icon(esPropia ? (estado == 'aceptada' ? Icons.check_circle : Icons.watch_later) : ((esAjena && (estado == 'aceptada' || estado == 'pendiente')) ? Icons.block : Icons.access_time), size: 16),
                  label: Text(tramo + suffix),
                );
              }).toList(),
            ),
            
            if (selectedHora != null) ...[
              const SizedBox(height: 30),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Tramo: $selectedHora', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      
                      if (infoReservaActual == null || infoReservaActual['estado'] == 'denegada') ...[
                        const Text('Estado: LIBRE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        
                        DropdownButtonFormField<String>(
                          initialValue: _usoSeleccionado,
                          decoration: const InputDecoration(
                            labelText: '¿Para qué vas a usar el aula?',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          ),
                          items: _iconosUsos.keys.map((String uso) {
                            return DropdownMenuItem<String>(
                              value: uso,
                              child: Row(
                                children: [
                                  Icon(_iconosUsos[uso], color: Colors.blueAccent, size: 20),
                                  const SizedBox(width: 10),
                                  Text(uso),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _usoSeleccionado = newValue;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 15),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                          onPressed: () => _confirmarReserva(aula, selectedDay, selectedHora), 
                          child: const Text('Enviar Solicitud de Reserva')
                        )
                      ] else if (infoReservaActual['tipo'] == 'propia') ...[
                        Text('Estado: ${infoReservaActual['estado'].toUpperCase()}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('Anular mi reserva'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                          onPressed: () => _anularReservaPropia(infoReservaActual['id'], aula), 
                        )
                      ] else ...[
                        const Text('Estado: OCUPADO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Este tramo ya ha sido solicitado por otro profesor.', style: TextStyle(color: Colors.grey, fontSize: 12)),
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