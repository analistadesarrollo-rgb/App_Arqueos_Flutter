import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArqueoReplicaApp());
}

class AppPalette {
  static const primary = Color(0xFF1E40AF);
  static const secondary = Color(0xFF0EA5E9);
  static const surface = Color(0xFFF8FAFC);
  static const accent = Color(0xFFFACC15);
  static const onAccent = Color(0xFF111827);
  static const success = Color(0xFF15803D);
  static const danger = Color(0xFFB91C1C);
}

Map<String, dynamic>? parsePossibleJson(dynamic responseBody) {
  if (responseBody is Map<String, dynamic>) return responseBody;
  if (responseBody is String) {
    try {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(responseBody);
      if (match != null) {
        try {
          return jsonDecode(match.group(0)!) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null;
}

void showAlert(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class ArqueoFormScreen extends StatefulWidget {
  final String perfil;
  final String supervisor;

  const ArqueoFormScreen({
    super.key,
    required this.perfil,
    required this.supervisor,
  });

  @override
  State<ArqueoFormScreen> createState() => _ArqueoFormScreenState();
}

class ArqueoReplicaApp extends StatefulWidget {
  const ArqueoReplicaApp({super.key});

  @override
  State<ArqueoReplicaApp> createState() => _ArqueoReplicaAppState();
}

class CronogramaItem {
  final String id;
  final String puntodeventa;
  final String dia;
  final String empresa;
  final String estado;
  final String observacion;

  CronogramaItem({
    required this.id,
    required this.puntodeventa,
    required this.dia,
    required this.empresa,
    required this.estado,
    required this.observacion,
  });

  factory CronogramaItem.fromJson(Map<String, dynamic> json) => CronogramaItem(
    id: json['id']?.toString() ?? '',
    puntodeventa: json['puntodeventa']?.toString() ?? '',
    dia: json['dia']?.toString() ?? '',
    empresa: json['empresa']?.toString() ?? '',
    estado: json['estado']?.toString() ?? '',
    observacion: json['observacion']?.toString() ?? '',
  );
}

class CronogramaScreen extends StatefulWidget {
  final String perfil;

  const CronogramaScreen({super.key, required this.perfil});

  @override
  State<CronogramaScreen> createState() => _CronogramaScreenState();
}

class Endpoints {
  static const login =
      'http://ganeyumbo.ddns.net/clientes/login/Arqueo_flutter/login_new.php';
  static const multiempresa =
      'http://ganeyumbo.ddns.net/clientes/login/Arqueo_flutter/registro_arqueo_multiempresa.php';
  static const sucursalInfo =
      'http://ganeyumbo.ddns.net/clientes/login/Arqueo_flutter/informacion_puntoventa.php';
  static const cronograma =
      'http://ganeyumbo.ddns.net/clientes/login/Arqueo_flutter/cronograma.php';
  static const cronogramaUpdate =
      'http://ganeyumbo.ddns.net/clientes/login/Arqueo_flutter/cronograma_update.php';
}

class HomeShell extends StatefulWidget {
  final String perfil;
  final String supervisor;
  final Future<void> Function() onLogout;

  const HomeShell({
    super.key,
    required this.perfil,
    required this.supervisor,
    required this.onLogout,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class LoginScreen extends StatefulWidget {
  final Future<void> Function(String perfil, String usuario) onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class PreguntaItem {
  final int id;
  final String texto;
  String estado;
  String observacion;

  PreguntaItem({
    required this.id,
    required this.texto,
    this.estado = 'CUMPLE',
    this.observacion = '',
  });
}

class RaspaRow {
  final nombreJuego = TextEditingController();
  final cantidadBnet = TextEditingController();
  final cantidadFisicos = TextEditingController();
  final cantidadFaltante = TextEditingController();
  final cantidadTiquete = TextEditingController();
  final descargado = TextEditingController();

  bool get hasData =>
      nombreJuego.text.trim().isNotEmpty ||
      cantidadBnet.text.trim().isNotEmpty ||
      cantidadFisicos.text.trim().isNotEmpty ||
      cantidadFaltante.text.trim().isNotEmpty ||
      cantidadTiquete.text.trim().isNotEmpty;

  void dispose() {
    nombreJuego.dispose();
    cantidadBnet.dispose();
    cantidadFisicos.dispose();
    cantidadFaltante.dispose();
    cantidadTiquete.dispose();
    descargado.dispose();
  }
}

class _ArqueoFormScreenState extends State<ArqueoFormScreen>
    with WidgetsBindingObserver {
  static const String _draftKey = 'arqueo_draft_v1';

  final scannerController = MobileScannerController();
  final formScrollController = ScrollController();
  final imagePicker = ImagePicker();
  bool showScanner = false;
  bool _isRestoringDraft = false;

  Position? position;
  String? imageBase64;
  File? imageFile;

  final firmaAuditoriaController = SignatureController(penStrokeWidth: 3);
  final firmaColocadoraController = SignatureController(penStrokeWidth: 3);

  final ipCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();
  final cedulaCtrl = TextEditingController();
  final sucursalCtrl = TextEditingController();
  final puntoVentaCtrl = TextEditingController();
  final categorizacionCtrl = TextEditingController();
  final supervisorCtrl = TextEditingController();

  final ventaBrutaCtrl = TextEditingController();
  final baseEfectivoCtrl = TextEditingController();
  final carteraCtrl = TextEditingController();
  final totalIngresoCtrl = TextEditingController();
  final chanceAbonadosCtrl = TextEditingController();
  final chanceImpresosCtrl = TextEditingController();
  final premiosPagadosCtrl = TextEditingController();
  final efectivoCajaFuerteCtrl = TextEditingController();
  final tirillaRecaudoCtrl = TextEditingController();
  final totalEgresosCtrl = TextEditingController();
  final totalMonedasCtrl = TextEditingController();
  final totalBilletesCtrl = TextEditingController();
  final totalArqueoCtrl = TextEditingController();
  final sobranteFaltanteCtrl = TextEditingController();

  final totalMonedasCajaCtrl = TextEditingController();
  final totalBilletesCajaCtrl = TextEditingController();
  final totalPremiosCajaCtrl = TextEditingController();
  final totalCajaCtrl = TextEditingController();
  final rollosBnetCtrl = TextEditingController();
  final rollosFisicosCtrl = TextEditingController();
  final totalRollosCtrl = TextEditingController();

  final cantidadDescargadosCtrl = TextEditingController();
  final totalDescargadosCtrl = TextEditingController();
  final nombreObservacionCtrl = TextEditingController();

  late final List<RaspaRow> raspasRows;
  late final List<PreguntaItem> preguntas;

  Widget actionButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton(onPressed: onPressed, child: Text(text)),
    );
  }

  Widget appInput(
    TextEditingController controller,
    String hint, {
    bool numeric = false,
    bool readOnly = false,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        onChanged: onChanged,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppPalette.primary, AppPalette.secondary],
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 16,
                  offset: Offset(0, 8),
                  color: Color(0x29000000),
                ),
              ],
            ),
            child: showScanner
                ? Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Enfoca el código QR',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: MobileScanner(
                          controller: scannerController,
                          onDetect: onDetectBarcode,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => showScanner = false),
                        child: const Text('Cancelar escaneo'),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    controller: formScrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Arqueo multiempresa',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => setState(() => showScanner = true),
                          child: const Text('Escanear QR'),
                        ),
                        const SizedBox(height: 8),
                        appInput(ipCtrl, 'IP', readOnly: true),
                        appInput(nombreCtrl, 'NOMBRE', readOnly: true),
                        appInput(cedulaCtrl, 'CEDULA', readOnly: true),
                        appInput(sucursalCtrl, 'SUCURSAL', readOnly: true),
                        subtitle('Punto de venta'),
                        appInput(
                          puntoVentaCtrl,
                          'Nombre de sucursal',
                          readOnly: true,
                        ),
                        subtitle('Supervisor'),
                        appInput(supervisorCtrl, 'ingresar Supervisor'),
                        subtitle('Categorizacion del punto'),
                        appInput(
                          categorizacionCtrl,
                          'Categorizacion',
                          readOnly: true,
                        ),
                        subtitle('Entrega Efectivo'),
                        appInput(ventaBrutaCtrl, 'Venta Bruta', numeric: true),
                        appInput(
                          baseEfectivoCtrl,
                          'Base Efectivo',
                          numeric: true,
                        ),
                        appInput(carteraCtrl, 'Cartera', numeric: true),
                        appInput(
                          totalIngresoCtrl,
                          'Total Ingreso',
                          readOnly: true,
                        ),
                        subtitle('Salida efectivo'),
                        appInput(
                          chanceAbonadosCtrl,
                          'Chance abonados',
                          numeric: true,
                        ),
                        appInput(
                          chanceImpresosCtrl,
                          'Chance impresos',
                          numeric: true,
                        ),
                        appInput(
                          premiosPagadosCtrl,
                          'Premios pagados',
                          numeric: true,
                        ),
                        appInput(
                          efectivoCajaFuerteCtrl,
                          'Efectivo caja fuerte',
                          numeric: true,
                        ),
                        appInput(
                          tirillaRecaudoCtrl,
                          'Tirilla recaudo',
                          numeric: true,
                        ),
                        appInput(
                          totalEgresosCtrl,
                          'Total Egresos',
                          readOnly: true,
                        ),
                        subtitle('Total Arqueo'),
                        appInput(
                          totalMonedasCtrl,
                          'Total billetes',
                          numeric: true,
                        ),
                        appInput(
                          totalBilletesCtrl,
                          'Total monedas',
                          numeric: true,
                        ),
                        appInput(
                          totalArqueoCtrl,
                          'Total arqueo',
                          readOnly: true,
                        ),
                        appInput(
                          sobranteFaltanteCtrl,
                          'SOBRANTE - FALTANTE',
                          readOnly: true,
                        ),
                        subtitle('Caja Fuerte (Personal de turno de Venta)'),
                        appInput(
                          totalMonedasCajaCtrl,
                          'Total monedas Caja',
                          numeric: true,
                        ),
                        appInput(
                          totalBilletesCajaCtrl,
                          'Total billetes Caja',
                          numeric: true,
                        ),
                        appInput(
                          totalPremiosCajaCtrl,
                          'Total Premios Caja',
                          numeric: true,
                        ),
                        appInput(
                          totalCajaCtrl,
                          'Total Caja Personal',
                          readOnly: true,
                        ),
                        subtitle('Inventario Rollos'),
                        appInput(rollosBnetCtrl, 'Rollos BNET', numeric: true),
                        appInput(
                          rollosFisicosCtrl,
                          'Rollos Fisicos',
                          numeric: true,
                        ),
                        appInput(
                          totalRollosCtrl,
                          'Total Rollos',
                          readOnly: true,
                        ),
                        for (int i = 0; i < raspasRows.length; i++) ...[
                          subtitle('Inventario Raspas ${i + 1}'),
                          appInput(raspasRows[i].nombreJuego, 'Juego ${i + 1}'),
                          appInput(
                            raspasRows[i].cantidadBnet,
                            'Cantidad BNET',
                            numeric: true,
                          ),
                          appInput(
                            raspasRows[i].cantidadFisicos,
                            'Cantidad Fisicos',
                            numeric: true,
                          ),
                          appInput(
                            raspasRows[i].cantidadFaltante,
                            'Cantidad Faltantes',
                            numeric: true,
                          ),
                          appInput(
                            raspasRows[i].cantidadTiquete,
                            'Valor Tiquete',
                            numeric: true,
                          ),
                          appInput(
                            raspasRows[i].descargado,
                            'Total Rollos',
                            readOnly: true,
                          ),
                        ],
                        FilledButton(
                          onPressed: raspasRows.length >= 7
                              ? null
                              : _addRaspasRow,
                          child: Text(
                            raspasRows.length >= 7
                                ? 'Límite de Inventario Raspas alcanzado'
                                : 'Agregar Inventario Raspas',
                          ),
                        ),
                        const SizedBox(height: 8),
                        subtitle('Total Raspas'),
                        appInput(
                          cantidadDescargadosCtrl,
                          'Total Cantidad escargados',
                          readOnly: true,
                        ),
                        appInput(
                          totalDescargadosCtrl,
                          'Total Total descargados',
                          readOnly: true,
                        ),
                        const Text(
                          'Verificación del punto de venta',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final p in preguntas)
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  Text(
                                    '${p.id}. ${p.texto}',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: p.estado == 'CUMPLE'
                                          ? AppPalette.success
                                          : AppPalette.danger,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        p.estado = p.estado == 'CUMPLE'
                                            ? 'NO CUMPLE'
                                            : 'CUMPLE';
                                      });
                                    },
                                    child: Text(
                                      '${p.estado == 'CUMPLE' ? '✅' : '❌'} ${p.estado}',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: p.observacion,
                                    onChanged: (v) => p.observacion = v,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Observación (opcional)',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        subtitle('Imagen observación'),
                        if (imageFile != null)
                          Image.file(
                            imageFile!,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        OutlinedButton(
                          onPressed: pickObservationImage,
                          child: Text(
                            imageFile == null
                                ? '+ Tomar foto'
                                : 'Tomar otra foto',
                          ),
                        ),
                        subtitle('Observación'),
                        appInput(
                          nombreObservacionCtrl,
                          'Nombre de la observación',
                        ),
                        subtitle('Firma Arqueo'),
                        const Text('Firma Auditoria'),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.outline,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRect(
                            child: Signature(
                              controller: firmaAuditoriaController,
                              height: 200,
                              backgroundColor: colorScheme.surface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Firma Colocador'),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.outline,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRect(
                            child: Signature(
                              controller: firmaColocadoraController,
                              height: 200,
                              backgroundColor: colorScheme.surface,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            firmaAuditoriaController.clear();
                            firmaColocadoraController.clear();
                          },
                          child: const Text('Limpiar ambas firmas'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.accent,
                            foregroundColor: AppPalette.onAccent,
                          ),
                          onPressed: handleEnviarArqueo,
                          child: const Text('Enviar Arqueo'),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _coordBadge(
                                      context,
                                      'Latitud',
                                      position?.latitude.toString() ?? '--',
                                    ),
                                    _coordBadge(
                                      context,
                                      'Longitud',
                                      position?.longitude.toString() ?? '--',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scannerController.dispose();
    formScrollController.dispose();
    firmaAuditoriaController.dispose();
    firmaColocadoraController.dispose();
    for (final r in raspasRows) {
      r.dispose();
    }
    final ctrls = [
      ipCtrl,
      nombreCtrl,
      cedulaCtrl,
      sucursalCtrl,
      puntoVentaCtrl,
      categorizacionCtrl,
      supervisorCtrl,
      ventaBrutaCtrl,
      baseEfectivoCtrl,
      carteraCtrl,
      totalIngresoCtrl,
      chanceAbonadosCtrl,
      chanceImpresosCtrl,
      premiosPagadosCtrl,
      efectivoCajaFuerteCtrl,
      tirillaRecaudoCtrl,
      totalEgresosCtrl,
      totalMonedasCtrl,
      totalBilletesCtrl,
      totalArqueoCtrl,
      sobranteFaltanteCtrl,
      totalMonedasCajaCtrl,
      totalBilletesCajaCtrl,
      totalPremiosCajaCtrl,
      totalCajaCtrl,
      rollosBnetCtrl,
      rollosFisicosCtrl,
      totalRollosCtrl,
      cantidadDescargadosCtrl,
      totalDescargadosCtrl,
      nombreObservacionCtrl,
    ];
    for (final c in ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void handleCaja() {
    totalCajaCtrl.text =
        (_toInt(totalMonedasCajaCtrl.text) +
                _toInt(totalBilletesCajaCtrl.text) +
                _toInt(totalPremiosCajaCtrl.text))
            .toString();
  }

  void handleCalcular() {
    final totalIngresos =
        _toInt(ventaBrutaCtrl.text) +
        _toInt(baseEfectivoCtrl.text) +
        _toInt(carteraCtrl.text);
    totalIngresoCtrl.text = totalIngresos.toString();

    final totalEgresos =
        _toInt(chanceAbonadosCtrl.text) +
        _toInt(chanceImpresosCtrl.text) +
        _toInt(premiosPagadosCtrl.text) +
        _toInt(efectivoCajaFuerteCtrl.text) +
        _toInt(tirillaRecaudoCtrl.text);
    totalEgresosCtrl.text = totalEgresos.toString();

    final totalArqueo =
        _toInt(totalMonedasCtrl.text) + _toInt(totalBilletesCtrl.text);
    totalArqueoCtrl.text = totalArqueo.toString();

    final sf = totalIngresos - totalArqueo;
    sobranteFaltanteCtrl.text = sf > 0
        ? 'SOBRANTE $sf'
        : 'FALTANTE ${sf.abs()}';
  }

  Future<void> handleEnviarArqueo() async {
    if (ipCtrl.text.isEmpty ||
        nombreCtrl.text.isEmpty ||
        cedulaCtrl.text.isEmpty ||
        sucursalCtrl.text.isEmpty) {
      showAlert(context, 'tienes que leer el QR antes de enviar');
      return;
    }

    final firmaAuditoria = await signatureToBase64(firmaAuditoriaController);
    final firmaColocadora = await signatureToBase64(firmaColocadoraController);
    if (!mounted) return;

    if (firmaAuditoria.isEmpty || firmaColocadora.isEmpty) {
      showAlert(context, ' Debes firmar el arqueo antes de enviarlo');
      return;
    }

    handleCalcular();
    handleCaja();
    handleRollos();
    handleRaspas();

    final body = <String, dynamic>{
      'perfil': widget.perfil,
      'ip': ipCtrl.text,
      'nombres': nombreCtrl.text,
      'documento': cedulaCtrl.text,
      'sucursal': sucursalCtrl.text,
      'supervisor': supervisorCtrl.text,
      'puntodeventa': puntoVentaCtrl.text,
      'latitud': position?.latitude,
      'longitud': position?.longitude,
      'ventabruta': ventaBrutaCtrl.text,
      'baseefectivo': baseEfectivoCtrl.text,
      'cartera': carteraCtrl.text,
      'totalingreso': totalIngresoCtrl.text,
      'chancesabonados': chanceAbonadosCtrl.text,
      'chancespreimpresos': chanceImpresosCtrl.text,
      'premiospagados': premiosPagadosCtrl.text,
      'efectivocajafuerte': efectivoCajaFuerteCtrl.text,
      'tirillarecaudo': tirillaRecaudoCtrl.text,
      'totalegresos': totalEgresosCtrl.text,
      'totalbilletes': totalBilletesCtrl.text,
      'totalmonedas': totalMonedasCtrl.text,
      'totalarqueo': totalArqueoCtrl.text,
      'sobrantefaltante': sobranteFaltanteCtrl.text,
      'totalbilletescaja': totalBilletesCajaCtrl.text,
      'totalmonedascaja': totalMonedasCajaCtrl.text,
      'totalpremioscaja': totalPremiosCajaCtrl.text,
      'total': totalCajaCtrl.text,
      'rollos_bnet': rollosBnetCtrl.text,
      'rollos_fisicos': rollosFisicosCtrl.text,
      'diferencia': totalRollosCtrl.text,
      'totaldescargados': cantidadDescargadosCtrl.text,
      'totalvalor': totalDescargadosCtrl.text,
      'imagen_observacion': imageBase64,
      'nombre_observacion': nombreObservacionCtrl.text,
      'firma_auditoria': firmaAuditoria,
      'firma_colocadora': firmaColocadora,
    };

    final rowsToSend = raspasRows.where((row) => row.hasData).take(7).toList();
    for (int i = 0; i < rowsToSend.length; i++) {
      final row = rowsToSend[i];
      final idx = i + 1;
      final suffix = idx == 1 ? '' : '$idx';
      body['nombre_juego$suffix'] = row.nombreJuego.text;
      body['cantidad_bnet$suffix'] = row.cantidadBnet.text;
      body['cantidad_fisicos$suffix'] = row.cantidadFisicos.text;
      body['cantidad_faltante$suffix'] = row.cantidadFaltante.text;
      body['cantidad_tiquete$suffix'] = row.cantidadTiquete.text;
      body['descargado$suffix'] = row.descargado.text;
    }

    for (final p in preguntas) {
      body['requisito${p.id}'] = p.estado;
      body['observacion${p.id}'] = p.observacion;
    }

    try {
      final res = await http.post(
        Uri.parse(Endpoints.multiempresa),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      final rawResponse = utf8.decode(res.bodyBytes).trim();
      final parsed = parsePossibleJson(rawResponse);
      final successMessage =
          parsed?['success']?.toString() ?? parsed?['message']?.toString();

      if (res.statusCode == 200 && successMessage != null) {
        if (mounted) {
          showAlert(context, successMessage);
          resetFormAfterSuccess();
        }
        return;
      }

      if (res.statusCode == 200 &&
          rawResponse.isNotEmpty &&
          !rawResponse.toLowerCase().contains('error')) {
        if (mounted) {
          showAlert(context, rawResponse);
          resetFormAfterSuccess();
        }
        return;
      }

      if (mounted) {
        final backendError =
            parsed?['error']?.toString() ?? parsed?['message']?.toString();
        final fallback = rawResponse.isEmpty
            ? 'HTTP ${res.statusCode}: respuesta vacía del servidor'
            : 'HTTP ${res.statusCode}: ${rawResponse.length > 180 ? '${rawResponse.substring(0, 180)}...' : rawResponse}';
        showAlert(context, backendError ?? fallback);
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) showAlert(context, e.toString());
    }
  }

  void handleRaspas() {
    int cantidadDescargados = 0;
    int totalDescargados = 0;
    for (final row in raspasRows) {
      final faltante = _toInt(row.cantidadFaltante.text);
      final tiquete = _toInt(row.cantidadTiquete.text);
      final descargado = faltante * tiquete;
      row.descargado.text = descargado.toString();
      cantidadDescargados += faltante;
      totalDescargados += descargado;
    }
    cantidadDescargadosCtrl.text = cantidadDescargados.toString();
    totalDescargadosCtrl.text = totalDescargados.toString();
  }

  void handleRollos() {
    totalRollosCtrl.text =
        'DIFERENCIA ${_toInt(rollosBnetCtrl.text) - _toInt(rollosFisicosCtrl.text)}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    supervisorCtrl.text = widget.supervisor;
    raspasRows = [];
    _addRaspasRow(saveDraft: false, showLimitAlert: false);
    _bindAutoCalculationListeners();
    _bindDraftListeners();
    preguntas = _buildPreguntas();
    _initLocation();
    _restoreDraft();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveDraft();
    }
  }

  void onDetectBarcode(BarcodeCapture capture) async {
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    final parts = value.split('&');
    if (parts.length != 4) {
      showAlert(context, 'QR inválido');
      return;
    }

    setState(() {
      ipCtrl.text = parts[0];
      nombreCtrl.text = parts[1];
      cedulaCtrl.text = parts[2];
      sucursalCtrl.text = parts[3];
      showScanner = false;
    });

    await _loadSucursalInfo(parts[3]);
  }

  void _addRaspasRow({bool saveDraft = true, bool showLimitAlert = true}) {
    if (raspasRows.length >= 7) {
      if (showLimitAlert) {
        showAlert(context, 'Solo se permiten hasta 7 Inventarios Raspas');
      }
      return;
    }
    final row = RaspaRow();
    row.cantidadFaltante.addListener(handleRaspas);
    row.cantidadTiquete.addListener(handleRaspas);
    _attachRaspasDraftListeners(row);
    setState(() {
      raspasRows.add(row);
    });
    handleRaspas();
    if (saveDraft) {
      _saveDraft();
    }
  }

  void _bindAutoCalculationListeners() {
    for (final ctrl in [
      ventaBrutaCtrl,
      baseEfectivoCtrl,
      carteraCtrl,
      chanceAbonadosCtrl,
      chanceImpresosCtrl,
      premiosPagadosCtrl,
      efectivoCajaFuerteCtrl,
      tirillaRecaudoCtrl,
      totalMonedasCtrl,
      totalBilletesCtrl,
    ]) {
      ctrl.addListener(handleCalcular);
    }

    for (final ctrl in [
      totalMonedasCajaCtrl,
      totalBilletesCajaCtrl,
      totalPremiosCajaCtrl,
    ]) {
      ctrl.addListener(handleCaja);
    }

    for (final ctrl in [rollosBnetCtrl, rollosFisicosCtrl]) {
      ctrl.addListener(handleRollos);
    }
  }

  Future<void> _loadSucursalInfo(String codigoSucursal) async {
    final codigo = codigoSucursal.trim();
    if (codigo.isEmpty) {
      puntoVentaCtrl.clear();
      categorizacionCtrl.clear();
      return;
    }

    try {
      final res = await http.post(
        Uri.parse(Endpoints.sucursalInfo),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'sucursal': codigo, 'codigo': codigo}),
      );

      final parsed = parsePossibleJson(utf8.decode(res.bodyBytes));
      if (parsed == null) {
        puntoVentaCtrl.clear();
        categorizacionCtrl.clear();
        if (mounted) {
          showAlert(
            context,
            'La consulta de sucursal no devolvió JSON válido (HTTP ${res.statusCode})',
          );
        }
        return;
      }

      final successValue = parsed['success'];
      final isSuccess =
          successValue == true ||
          successValue?.toString().toLowerCase() == 'true' ||
          successValue?.toString() == '1';

      if (res.statusCode == 200 && isSuccess) {
        final nombre = (parsed['nombre'] ?? parsed['NOMBRE'] ?? '').toString();
        final categoria = (parsed['categoria'] ?? parsed['CATEGORIA'] ?? '')
            .toString();
        final version = (parsed['version'] ?? parsed['VERSION'] ?? '')
            .toString();
        final categorizacion = [
          categoria,
          version,
        ].where((v) => v.trim().isNotEmpty).join(' - ');

        puntoVentaCtrl.text = nombre;
        categorizacionCtrl.text = categorizacion;
      } else {
        puntoVentaCtrl.clear();
        categorizacionCtrl.clear();
        if (mounted) {
          showAlert(
            context,
            parsed['error']?.toString() ??
                'No se encontró información para la sucursal (HTTP ${res.statusCode})',
          );
        }
      }
    } catch (_) {
      puntoVentaCtrl.clear();
      categorizacionCtrl.clear();
      if (mounted) {
        showAlert(
          context,
          'No fue posible consultar la información de sucursal',
        );
      }
    }
  }

  Future<void> pickObservationImage() async {
    final result = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 30,
    );
    if (result == null) return;
    final bytes = await result.readAsBytes();
    if (!mounted) return;
    setState(() {
      imageFile = File(result.path);
      imageBase64 = base64Encode(bytes);
    });
  }

  void resetFormAfterSuccess() {
    final controllers = [
      puntoVentaCtrl,
      categorizacionCtrl,
      ventaBrutaCtrl,
      baseEfectivoCtrl,
      carteraCtrl,
      totalIngresoCtrl,
      chanceAbonadosCtrl,
      chanceImpresosCtrl,
      premiosPagadosCtrl,
      efectivoCajaFuerteCtrl,
      tirillaRecaudoCtrl,
      totalEgresosCtrl,
      totalMonedasCtrl,
      totalBilletesCtrl,
      totalArqueoCtrl,
      sobranteFaltanteCtrl,
      totalMonedasCajaCtrl,
      totalBilletesCajaCtrl,
      totalPremiosCajaCtrl,
      totalCajaCtrl,
      rollosBnetCtrl,
      rollosFisicosCtrl,
      totalRollosCtrl,
      cantidadDescargadosCtrl,
      totalDescargadosCtrl,
      nombreObservacionCtrl,
      ipCtrl,
      nombreCtrl,
      cedulaCtrl,
      sucursalCtrl,
    ];
    for (final c in controllers) {
      c.clear();
    }
    supervisorCtrl.text = widget.supervisor;
    for (final row in raspasRows) {
      row.cantidadFaltante.removeListener(handleRaspas);
      row.cantidadTiquete.removeListener(handleRaspas);
      row.nombreJuego.clear();
      row.cantidadBnet.clear();
      row.cantidadFisicos.clear();
      row.cantidadFaltante.clear();
      row.cantidadTiquete.clear();
      row.descargado.clear();
      row.dispose();
    }
    raspasRows.clear();
    _addRaspasRow();
    for (final p in preguntas) {
      p.estado = 'CUMPLE';
      p.observacion = '';
    }
    imageBase64 = null;
    imageFile = null;
    firmaAuditoriaController.clear();
    firmaColocadoraController.clear();
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!formScrollController.hasClients) return;
      formScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    });

    _clearDraft();
  }

  void _bindDraftListeners() {
    for (final ctrl in [
      ipCtrl,
      nombreCtrl,
      cedulaCtrl,
      sucursalCtrl,
      puntoVentaCtrl,
      categorizacionCtrl,
      supervisorCtrl,
      ventaBrutaCtrl,
      baseEfectivoCtrl,
      carteraCtrl,
      totalIngresoCtrl,
      chanceAbonadosCtrl,
      chanceImpresosCtrl,
      premiosPagadosCtrl,
      efectivoCajaFuerteCtrl,
      tirillaRecaudoCtrl,
      totalEgresosCtrl,
      totalMonedasCtrl,
      totalBilletesCtrl,
      totalArqueoCtrl,
      sobranteFaltanteCtrl,
      totalMonedasCajaCtrl,
      totalBilletesCajaCtrl,
      totalPremiosCajaCtrl,
      totalCajaCtrl,
      rollosBnetCtrl,
      rollosFisicosCtrl,
      totalRollosCtrl,
      cantidadDescargadosCtrl,
      totalDescargadosCtrl,
      nombreObservacionCtrl,
    ]) {
      ctrl.addListener(_saveDraft);
    }
  }

  void _attachRaspasDraftListeners(RaspaRow row) {
    row.nombreJuego.addListener(_saveDraft);
    row.cantidadBnet.addListener(_saveDraft);
    row.cantidadFisicos.addListener(_saveDraft);
    row.cantidadFaltante.addListener(_saveDraft);
    row.cantidadTiquete.addListener(_saveDraft);
    row.descargado.addListener(_saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_isRestoringDraft) return;
    final prefs = await SharedPreferences.getInstance();

    final draft = <String, dynamic>{
      'ip': ipCtrl.text,
      'nombre': nombreCtrl.text,
      'cedula': cedulaCtrl.text,
      'sucursal': sucursalCtrl.text,
      'puntodeventa': puntoVentaCtrl.text,
      'categorizacion': categorizacionCtrl.text,
      'supervisor': supervisorCtrl.text,
      'ventabruta': ventaBrutaCtrl.text,
      'baseefectivo': baseEfectivoCtrl.text,
      'cartera': carteraCtrl.text,
      'totalingreso': totalIngresoCtrl.text,
      'chancesabonados': chanceAbonadosCtrl.text,
      'chancespreimpresos': chanceImpresosCtrl.text,
      'premiospagados': premiosPagadosCtrl.text,
      'efectivocajafuerte': efectivoCajaFuerteCtrl.text,
      'tirillarecaudo': tirillaRecaudoCtrl.text,
      'totalegresos': totalEgresosCtrl.text,
      'totalmonedas': totalMonedasCtrl.text,
      'totalbilletes': totalBilletesCtrl.text,
      'totalarqueo': totalArqueoCtrl.text,
      'sobrantefaltante': sobranteFaltanteCtrl.text,
      'totalmonedascaja': totalMonedasCajaCtrl.text,
      'totalbilletescaja': totalBilletesCajaCtrl.text,
      'totalpremioscaja': totalPremiosCajaCtrl.text,
      'totalcaja': totalCajaCtrl.text,
      'rollos_bnet': rollosBnetCtrl.text,
      'rollos_fisicos': rollosFisicosCtrl.text,
      'total_rollos': totalRollosCtrl.text,
      'total_descargados_cantidad': cantidadDescargadosCtrl.text,
      'total_descargados_valor': totalDescargadosCtrl.text,
      'nombre_observacion': nombreObservacionCtrl.text,
      'raspas': raspasRows
          .map(
            (row) => {
              'nombre_juego': row.nombreJuego.text,
              'cantidad_bnet': row.cantidadBnet.text,
              'cantidad_fisicos': row.cantidadFisicos.text,
              'cantidad_faltante': row.cantidadFaltante.text,
              'cantidad_tiquete': row.cantidadTiquete.text,
              'descargado': row.descargado.text,
            },
          )
          .toList(),
      'preguntas': preguntas
          .map(
            (p) => {
              'id': p.id,
              'estado': p.estado,
              'observacion': p.observacion,
            },
          )
          .toList(),
    };

    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.trim().isEmpty) return;

    final parsed = parsePossibleJson(raw);
    if (parsed == null) return;

    _isRestoringDraft = true;

    String strValue(dynamic v) => v?.toString() ?? '';

    ipCtrl.text = strValue(parsed['ip']);
    nombreCtrl.text = strValue(parsed['nombre']);
    cedulaCtrl.text = strValue(parsed['cedula']);
    sucursalCtrl.text = strValue(parsed['sucursal']);
    puntoVentaCtrl.text = strValue(parsed['puntodeventa']);
    categorizacionCtrl.text = strValue(parsed['categorizacion']);
    supervisorCtrl.text = strValue(parsed['supervisor']).isEmpty
        ? widget.supervisor
        : strValue(parsed['supervisor']);
    ventaBrutaCtrl.text = strValue(parsed['ventabruta']);
    baseEfectivoCtrl.text = strValue(parsed['baseefectivo']);
    carteraCtrl.text = strValue(parsed['cartera']);
    totalIngresoCtrl.text = strValue(parsed['totalingreso']);
    chanceAbonadosCtrl.text = strValue(parsed['chancesabonados']);
    chanceImpresosCtrl.text = strValue(parsed['chancespreimpresos']);
    premiosPagadosCtrl.text = strValue(parsed['premiospagados']);
    efectivoCajaFuerteCtrl.text = strValue(parsed['efectivocajafuerte']);
    tirillaRecaudoCtrl.text = strValue(parsed['tirillarecaudo']);
    totalEgresosCtrl.text = strValue(parsed['totalegresos']);
    totalMonedasCtrl.text = strValue(parsed['totalmonedas']);
    totalBilletesCtrl.text = strValue(parsed['totalbilletes']);
    totalArqueoCtrl.text = strValue(parsed['totalarqueo']);
    sobranteFaltanteCtrl.text = strValue(parsed['sobrantefaltante']);
    totalMonedasCajaCtrl.text = strValue(parsed['totalmonedascaja']);
    totalBilletesCajaCtrl.text = strValue(parsed['totalbilletescaja']);
    totalPremiosCajaCtrl.text = strValue(parsed['totalpremioscaja']);
    totalCajaCtrl.text = strValue(parsed['totalcaja']);
    rollosBnetCtrl.text = strValue(parsed['rollos_bnet']);
    rollosFisicosCtrl.text = strValue(parsed['rollos_fisicos']);
    totalRollosCtrl.text = strValue(parsed['total_rollos']);
    cantidadDescargadosCtrl.text = strValue(
      parsed['total_descargados_cantidad'],
    );
    totalDescargadosCtrl.text = strValue(parsed['total_descargados_valor']);
    nombreObservacionCtrl.text = strValue(parsed['nombre_observacion']);

    for (final row in raspasRows) {
      row.cantidadFaltante.removeListener(handleRaspas);
      row.cantidadTiquete.removeListener(handleRaspas);
      row.dispose();
    }
    raspasRows.clear();

    final raspasSaved = parsed['raspas'];
    final raspasList = raspasSaved is List ? raspasSaved : <dynamic>[];
    final count = raspasList.isEmpty
        ? 1
        : (raspasList.length > 7 ? 7 : raspasList.length);

    for (int i = 0; i < count; i++) {
      _addRaspasRow(saveDraft: false, showLimitAlert: false);
    }

    for (int i = 0; i < raspasList.length && i < raspasRows.length; i++) {
      final item = raspasList[i];
      if (item is! Map) continue;
      raspasRows[i].nombreJuego.text = strValue(item['nombre_juego']);
      raspasRows[i].cantidadBnet.text = strValue(item['cantidad_bnet']);
      raspasRows[i].cantidadFisicos.text = strValue(item['cantidad_fisicos']);
      raspasRows[i].cantidadFaltante.text = strValue(item['cantidad_faltante']);
      raspasRows[i].cantidadTiquete.text = strValue(item['cantidad_tiquete']);
      raspasRows[i].descargado.text = strValue(item['descargado']);
    }

    final preguntasSaved = parsed['preguntas'];
    if (preguntasSaved is List) {
      final byId = <int, Map>{};
      for (final item in preguntasSaved) {
        if (item is Map && item['id'] != null) {
          byId[int.tryParse(item['id'].toString()) ?? -1] = item;
        }
      }
      for (final p in preguntas) {
        final saved = byId[p.id];
        if (saved == null) continue;
        p.estado = strValue(saved['estado']).isEmpty
            ? p.estado
            : strValue(saved['estado']);
        p.observacion = strValue(saved['observacion']);
      }
    }

    handleCalcular();
    handleCaja();
    handleRollos();
    handleRaspas();
    if (mounted) setState(() {});

    _isRestoringDraft = false;
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<String> signatureToBase64(SignatureController controller) async {
    final bytes = await controller.toPngBytes();
    if (bytes == null) return '';
    return base64Encode(bytes);
  }

  Widget subtitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
  );

  Widget _coordBadge(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  List<PreguntaItem> _buildPreguntas() => [
    PreguntaItem(id: 1, texto: 'Tiene la puerta asegurada?'),
    PreguntaItem(
      id: 2,
      texto:
          'Elementos de aseo, sillas, computador, iluminacion en buen estado?',
    ),
    PreguntaItem(id: 3, texto: 'Aviso de videovigilancia y camaras?'),
    PreguntaItem(id: 4, texto: 'Utiliza Superflex?'),
    PreguntaItem(id: 5, texto: 'Tiene caja fuerte?'),
    PreguntaItem(
      id: 6,
      texto:
          'Tiene caja digital auxiliar? Conoce las bases de efectivo asignadas para caja digital y principal?',
    ),
    PreguntaItem(
      id: 7,
      texto: 'Las recargas se hacen a través la Red propia de la Cia?',
    ),
    PreguntaItem(
      id: 8,
      texto:
          'Cumple con los topes de efectivo establecidos en caja digital y principal?',
    ),
    PreguntaItem(
      id: 9,
      texto:
          'Tiene los premios descargados? Conoce los requisitos y montos máximos para pago de premios?',
    ),
    PreguntaItem(
      id: 10,
      texto:
          'La lotería física tiene impreso el nombre de la Cia o de Servicios Transaccionales. Reportar inmediato en caso negativo.',
    ),
    PreguntaItem(id: 11, texto: 'Publicidad exhibida actualizada?'),
    PreguntaItem(
      id: 12,
      texto:
          'Aviso externo de "Vigilado y Controlado Mintic" y "Colaborador Autorizado"?',
    ),
    PreguntaItem(
      id: 13,
      texto:
          'Afiche MINTIC SUPERGIROS (contiene aviso de canales de comunicación, o tarifario condiciones del servicio, sticker tirilla electronica CRC)?',
    ),
    PreguntaItem(
      id: 14,
      texto:
          'Calendario resultados Superastro diligenciado (tiene que tener los resultados)',
    ),
    PreguntaItem(
      id: 15,
      texto:
          'Presta servicio de Western Union (es obligatorio para cajeros ciales)',
    ),
    PreguntaItem(
      id: 16,
      texto: 'Calendarios de acumulados (Baloto-Miloto-Colorloto)',
    ),
    PreguntaItem(
      id: 17,
      texto: 'Tablero de resultados y acumulados actualizados',
    ),
    PreguntaItem(
      id: 18,
      texto:
          'Licencia de funcionamiento de Beneficencia del Valle con año actualizado',
    ),
    PreguntaItem(
      id: 19,
      texto:
          'Tiene equipos de Betplay y/o maquinas de ruta? Si los tiene debe tener el aviso "Autoriza Coljuegos"',
    ),
    PreguntaItem(id: 20, texto: 'Tiene aviso codigo QR para PQR?'),
    PreguntaItem(id: 21, texto: 'Verificar el cableado'),
    PreguntaItem(
      id: 22,
      texto: 'Tiene prendas emblematicas y presentación adecuada?',
    ),
    PreguntaItem(
      id: 23,
      texto: 'El usuario corresponde a la cedula del mismo?',
    ),
    PreguntaItem(id: 24, texto: 'Tiene usuario de giros? Presta el servicio?'),
    PreguntaItem(
      id: 25,
      texto: 'Tiene usuario de la ONJ (para Baloto, Miloto, Colorloto)',
    ),
    PreguntaItem(id: 26, texto: 'Tiene usuario de SUPERFLEX'),
    PreguntaItem(
      id: 27,
      texto:
          'Tiene usuario de CORREDOR EMPRESARIAL (astro, chance millonario, Betplay)',
    ),
    PreguntaItem(
      id: 28,
      texto: 'Esta realizando recaudo en tesoreria BNET a la compañera?',
    ),
    PreguntaItem(id: 29, texto: 'Esta comercializando el portafolio completo?'),
    PreguntaItem(
      id: 30,
      texto: 'Solicita el documento de identificación al cliente?',
    ),
    PreguntaItem(id: 31, texto: 'Conoce Supervoucher, funciona?'),
    PreguntaItem(
      id: 32,
      texto:
          'Conoce el procedimiento para remitentes y destinatarios menores de edad?',
    ),
    PreguntaItem(
      id: 33,
      texto:
          'Conoce los reportes de operaciones en efectivo (R.O.E) firmas, huellas. (Transacciones >=\$10.000.000)?',
    ),
    PreguntaItem(id: 34, texto: 'El Supervisor Cial realiza las visitas?'),
    PreguntaItem(
      id: 35,
      texto:
          'Conoce los terminos SARL, SARLAFT, SARO, operación inusual y operación sospechosa',
    ),
  ];

  Future<void> _initLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        showAlert(context, 'Se necesitan permisos para la localizacion');
      }
      return;
    }
    final current = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        position = current;
      });
    }
  }

  int _toInt(String v) => int.tryParse(v.trim()) ?? 0;
}

class _ArqueoReplicaAppState extends State<ArqueoReplicaApp> {
  bool _isLoggedIn = false;
  String? _perfil;
  String? _supervisor;
  bool _checkingUpdate = true;
  bool _mustUpdate = false;
  String _updateMessage = 'Validando actualizaciones...';

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Arqueo multiempresa',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppPalette.surface,
        cardTheme: CardThemeData(
          color: colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          titleTextStyle: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: _checkingUpdate
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _mustUpdate
          ? _buildUpdateBlockingScreen()
          : _isLoggedIn
          ? HomeShell(
              perfil: _perfil ?? '',
              supervisor: _supervisor ?? '',
              onLogout: _onLogout,
            )
          : LoginScreen(onLogin: _onLogin),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkForMandatoryUpdate();
  }

  Widget _buildUpdateBlockingScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Actualización requerida',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(_updateMessage, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _checkForMandatoryUpdate,
                  child: const Text('Buscar actualización'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkForMandatoryUpdate() async {
    if (!Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
        });
      }
      return;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        setState(() {
          _mustUpdate = true;
          _updateMessage =
              'Hay una nueva versión disponible. Debes actualizar para continuar.';
        });

        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          final recheck = await InAppUpdate.checkForUpdate();
          if (recheck.updateAvailability !=
              UpdateAvailability.updateAvailable) {
            if (mounted) {
              setState(() {
                _mustUpdate = false;
                _checkingUpdate = false;
              });
            }
            return;
          }
        }

        if (mounted) {
          setState(() {
            _checkingUpdate = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _mustUpdate = false;
          _checkingUpdate = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _mustUpdate = false;
          _checkingUpdate = false;
        });
      }
    }
  }

  Future<void> _onLogin(String perfil, String usuario) async {
    setState(() {
      _perfil = perfil;
      _supervisor = usuario;
      _isLoggedIn = true;
    });
  }

  Future<void> _onLogout() async {
    setState(() {
      _perfil = null;
      _supervisor = null;
      _isLoggedIn = false;
    });
  }
}

class _CronogramaScreenState extends State<CronogramaScreen> {
  static const estados = ['', 'Realizado', 'Cerrado', 'No Se Pudo Realizar'];
  final picker = ImagePicker();

  bool loading = false;
  List<CronogramaItem> rows = [];

  @override
  Widget build(BuildContext context) {
    final todayRows = rows.where((r) => r.dia == todayIso()).toList();
    return RefreshIndicator(
      onRefresh: fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: todayRows.length + (loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (loading && index == 0) {
            return const LinearProgressIndicator();
          }
          final row = todayRows[index - (loading ? 1 : 0)];
          final disabled =
              row.estado.trim() == 'Cerrado' ||
              row.estado.trim() == 'Realizado' ||
              row.estado.trim() == 'No Se Pudo Realizar';

          return Card(
            child: ListTile(
              title: Text('${row.dia} - ${row.puntodeventa}'),
              subtitle: Text(
                'Estado: ${row.estado.isEmpty ? 'No definido' : row.estado}',
              ),
              trailing: FilledButton(
                onPressed: disabled ? null : () => openDetalle(row),
                child: Text(disabled ? 'visitado' : 'Ver'),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> enviarCronograma({
    required String id,
    required String estado,
    required String perfil,
    String? imagen,
    String observacion = '',
  }) async {
    if (id.isEmpty || estado.isEmpty || perfil.isEmpty) {
      showAlert(context, 'campos vacios');
      return false;
    }

    try {
      final res = await http.post(
        Uri.parse(Endpoints.cronogramaUpdate),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Origin': 'http://ganeyumbo.ddns.net',
        },
        body: jsonEncode({
          'id': id,
          'estado': estado,
          'imagen': imagen,
          'perfil': perfil,
          'observacion': observacion,
        }),
      );

      final parsed = parsePossibleJson(utf8.decode(res.bodyBytes));
      if (!mounted) return false;
      if (res.statusCode == 200 && parsed?['success'] != null) {
        showAlert(context, parsed!['success'].toString());
        return true;
      }
      showAlert(context, parsed?['error']?.toString() ?? 'Error');
      return false;
    } catch (e) {
      if (!mounted) return false;
      showAlert(context, e.toString());
      return false;
    }
  }

  Future<void> fetchData() async {
    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse(Endpoints.cronograma),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Origin': 'http://ganeyumbo.ddns.net',
        },
        body: jsonEncode(widget.perfil),
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is List) {
          setState(() {
            rows = decoded
                .whereType<Map<String, dynamic>>()
                .map(CronogramaItem.fromJson)
                .toList();
          });
          if (mounted) showAlert(context, 'Información cargada correctamente');
        } else {
          if (mounted) showAlert(context, 'Error al traer información');
        }
      } else {
        if (mounted) showAlert(context, 'Error al traer información');
      }
    } catch (_) {
      if (mounted) showAlert(context, 'Error al traer o compartir el arqueo');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> openDetalle(CronogramaItem row) async {
    String estado = row.estado.trim();
    String observacion = '';
    String? imageBase64;
    File? imageFile;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          return AlertDialog(
            title: const Text('Detalles del Registro'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Día: ${row.dia}'),
                  Text('Empresa: ${row.empresa}'),
                  Text('Punto de Venta: ${row.puntodeventa}'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: estados.contains(estado) ? estado : '',
                    items: estados
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setLocalState(() => estado = v ?? ''),
                    decoration: const InputDecoration(labelText: 'Estado'),
                  ),
                  if (estado == 'Cerrado') ...[
                    const SizedBox(height: 10),
                    if (imageFile != null)
                      Image.file(imageFile!, height: 200)
                    else
                      OutlinedButton(
                        onPressed: () async {
                          final file = await picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 30,
                          );
                          if (file != null) {
                            final bytes = await file.readAsBytes();
                            setLocalState(() {
                              imageFile = File(file.path);
                              imageBase64 = base64Encode(bytes);
                            });
                          }
                        },
                        child: const Text('+ Tomar foto'),
                      ),
                  ],
                  if (estado == 'No Se Pudo Realizar') ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Por favor, proporcione una razón para no realizar la visita.',
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLines: 4,
                      onChanged: (v) => observacion = v,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Ingrese la razón aquí',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final ok = await enviarCronograma(
                    id: row.id,
                    estado: estado,
                    imagen: imageBase64,
                    observacion: observacion,
                    perfil: widget.perfil,
                  );
                  if (!mounted) return;
                  if (ok) {
                    Navigator.of(context).pop();
                    fetchData();
                  }
                },
                child: const Text('Actualizar'),
              ),
            ],
          );
        },
      ),
    );
  }

  String todayIso() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}

class _HomeShellState extends State<HomeShell> {
  int pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ArqueoFormScreen(perfil: widget.perfil, supervisor: widget.supervisor),
      CronogramaScreen(perfil: widget.perfil),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (pageIndex != 0) {
          setState(() => pageIndex = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(pageIndex == 0 ? 'Inicio' : 'Cronograma')),
        drawer: Drawer(
          child: Column(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppPalette.primary, AppPalette.secondary],
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logogane.webp',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Inicio'),
                onTap: () {
                  setState(() => pageIndex = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Cronograma'),
                onTap: () {
                  setState(() => pageIndex = 1);
                  Navigator.pop(context);
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppPalette.danger),
                title: const Text(
                  'CERRAR SESION',
                  style: TextStyle(color: AppPalette.danger),
                ),
                onTap: widget.onLogout,
              ),
            ],
          ),
        ),
        body: pages[pageIndex],
      ),
    );
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final usuarioCtrl = TextEditingController();
  final contrasenaCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF3FF), AppPalette.surface],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 20,
                      offset: Offset(0, 10),
                      color: Color(0x26000000),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Arqueo multiempresa',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Image.asset('assets/images/logogane.webp', height: 100),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Usuario',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: usuarioCtrl,
                      decoration: const InputDecoration(
                        hintText: 'ingresar usuario',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Contraseña',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contrasenaCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'ingresar contraseña',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: loading ? null : handleLogin,
                        child: const Text('Iniciar sesión'),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: TextStyle(color: colorScheme.error)),
                    ],
                    if (loading) ...[
                      const SizedBox(height: 10),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> handleLogin() async {
    if (usuarioCtrl.text.trim().isEmpty || contrasenaCtrl.text.trim().isEmpty) {
      showAlert(context, 'Por favor complete todos los campos');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await http.post(
        Uri.parse(Endpoints.login),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Origin': 'http://ganeyumbo.ddns.net',
        },
        body: jsonEncode({
          'login': usuarioCtrl.text.trim(),
          'pass': contrasenaCtrl.text,
        }),
      );

      final decoded = parsePossibleJson(utf8.decode(res.bodyBytes));
      final perfilRaw =
          (decoded?['perfil']?.toString().trim().toUpperCase() ?? '');
      final allowed = {
        'AUDITORIA-MULTIRED',
        'AUDITORIA-SERVIRED',
        'APLICACIONES',
      };

      if (res.statusCode == 200 && allowed.contains(perfilRaw)) {
        await widget.onLogin(perfilRaw, usuarioCtrl.text.trim());
        return;
      }

      setState(() {
        error = decoded?['error']?.toString() ?? 'Perfil no autorizado';
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }
}
