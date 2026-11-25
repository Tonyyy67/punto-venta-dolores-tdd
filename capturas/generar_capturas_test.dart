// Genera capturas de la PantallaCaja real, con la base SQLite en memoria.
// No forma parte de la suite normal (está fuera de test/). Se ejecuta con:
//   flutter test capturas/generar_capturas_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta_dolores/datos/base_datos.dart';
import 'package:punto_venta_dolores/datos/repositorio_productos.dart';
import 'package:punto_venta_dolores/datos/repositorio_ventas.dart';
import 'package:punto_venta_dolores/presentacion/caja_viewmodel.dart';
import 'package:punto_venta_dolores/presentacion/pantalla_caja.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Carga las fuentes reales (Roboto e íconos) que trae el SDK de Flutter,
/// para que las capturas no salgan con cuadritos.
Future<void> cargarFuentes() async {
  final cache = File(Platform.resolvedExecutable).parent.parent.parent;
  final dir = '${cache.path}${Platform.pathSeparator}material_fonts';
  Future<ByteData> leer(String n) async =>
      ByteData.sublistView(await File('$dir${Platform.pathSeparator}$n').readAsBytes());
  final roboto = FontLoader('Roboto')
    ..addFont(leer('roboto-regular.ttf'))
    ..addFont(leer('roboto-medium.ttf'))
    ..addFont(leer('roboto-bold.ttf'));
  final iconos = FontLoader('MaterialIcons')..addFont(leer('materialicons-regular.otf'));
  await roboto.load();
  await iconos.load();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('capturas de la caja', (tester) async {
    await tester.runAsync(cargarFuentes);
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    late CajaViewModel vm;
    await tester.runAsync(() async {
      final db = await BaseDatos.abrir(ruta: inMemoryDatabasePath);
      final productos = RepositorioProductos(db);
      await productos.sembrarEjemplos();
      vm = CajaViewModel(productos, RepositorioVentas(db));
    });

    Future<void> esperarBase() async {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorSchemeSeed: Colors.teal, useMaterial3: true, fontFamily: 'Roboto'),
      home: PantallaCaja(vm: vm),
    ));
    await esperarBase();
    await expectLater(find.byType(PantallaCaja),
        matchesGoldenFile('01_catalogo_inicial.png'));

    // Cliente: 2 nieves de limón y 1 horchata.
    await tester.tap(find.text('Nieve de limón (1 bola)'));
    await tester.tap(find.text('Nieve de limón (1 bola)'));
    await tester.tap(find.text('Agua de horchata 1L'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(PantallaCaja),
        matchesGoldenFile('02_carrito_con_iva.png'));

    // Paga con $100.
    await tester.enterText(find.widgetWithText(TextField, 'Paga con \$'), '100');
    await tester.tap(find.text('Cobrar'));
    await esperarBase();
    expect(find.text('Cambio: \$20.00'), findsOneWidget);
    expect(find.text('38 disponibles'), findsOneWidget);
    await expectLater(find.byType(PantallaCaja),
        matchesGoldenFile('03_cobro_con_cambio.png'));

    // Pago insuficiente: Talavera de $180 pagando $100.
    await tester.tap(find.text('Cerámica Talavera chica'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Paga con \$'), '100');
    await tester.tap(find.text('Cobrar'));
    await esperarBase();
    expect(find.textContaining('Faltan 8000 centavos'), findsOneWidget);
    await expectLater(find.byType(PantallaCaja),
        matchesGoldenFile('04_pago_insuficiente.png'));
  });
}
