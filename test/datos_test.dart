import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta_dolores/datos/base_datos.dart';
import 'package:punto_venta_dolores/datos/repositorio_productos.dart';
import 'package:punto_venta_dolores/datos/repositorio_ventas.dart';
import 'package:punto_venta_dolores/dominio/carrito.dart';
import 'package:punto_venta_dolores/dominio/excepciones.dart';
import 'package:punto_venta_dolores/dominio/producto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi; // SQLite en tu computadora

  late Database db;
  late RepositorioProductos productos;
  late RepositorioVentas ventas;

  setUp(() async {
    db = await BaseDatos.abrir(ruta: inMemoryDatabasePath);
    productos = RepositorioProductos(db);
    ventas = RepositorioVentas(db);
    await productos.agregar(const Producto(
        codigo: 'NV-001', nombre: 'Nieve de limón',
        precioCentavos: 2500, existencias: 5));
  });

  tearDown(() => db.close());

  test('guarda y busca producto', () async {
    final p = await productos.buscarPorCodigo('NV-001');
    expect(p!.nombre, 'Nieve de limón');
    expect(p.id, isNotNull);
  });

  test('código duplicado lanza excepción de dominio', () {
    expect(
        () => productos.agregar(const Producto(
            codigo: 'NV-001', nombre: 'Otra',
            precioCentavos: 100, existencias: 1)),
        throwsA(isA<CodigoDuplicadoException>()));
  });
  // REFACTOR Ronda 4: sembrarEjemplos carga la nevería y no duplica
  test('sembrarEjemplos carga el catálogo una sola vez', () async {
    await productos.eliminar('NV-001'); // base vacía
    await productos.sembrarEjemplos();
    await productos.sembrarEjemplos(); // segunda vez no hace nada
    final todos = await productos.listar();
    expect(todos.length, 8);
    expect((await productos.listar(filtro: 'nieve')).length, 3);
  });

  // RETO Ronda 4: bajoInventario con un producto de 2 y otro de 50
  test('reto: bajoInventario con límite por omisión (5)', () async {
    await productos.agregar(const Producto(
        codigo: 'DU-002', nombre: 'Alegría', precioCentavos: 1200, existencias: 2));
    await productos.agregar(const Producto(
        codigo: 'AG-001', nombre: 'Horchata', precioCentavos: 3000, existencias: 50));
    final bajos = await productos.bajoInventario();
    // Devuelve 2: la alegría (2) y la nieve del setUp (5, porque es <= 5).
    // La horchata (50) no aparece. Vienen ordenados de menor a mayor.
    expect(bajos.map((p) => p.codigo).toList(), ['DU-002', 'NV-001']);
  });
  // ---------------- Ronda 5 · Cobrar: la transacción ----------------
  test('cobrar descuenta inventario y registra venta', () async {
    final p = (await productos.buscarPorCodigo('NV-001'))!;
    final carrito = Carrito()..agregar(p, cantidad: 2);
    final venta = await ventas.cobrar(carrito, 10000);
    expect(venta.cambioCentavos, 5000);
    expect((await productos.buscarPorCodigo('NV-001'))!.existencias, 3);
  });

  test('si falla el cobro NO se descuenta inventario', () async {
    final p = (await productos.buscarPorCodigo('NV-001'))!;
    final carrito = Carrito()..agregar(p, cantidad: 2);
    await expectLater(ventas.cobrar(carrito, 100),
        throwsA(isA<PagoInsuficienteException>()));
    expect((await productos.buscarPorCodigo('NV-001'))!.existencias, 5);
  });

  test('corte del día suma ventas de hoy', () async {
    final p = (await productos.buscarPorCodigo('NV-001'))!;
    await ventas.cobrar(Carrito()..agregar(p), 2500);
    await ventas.cobrar(Carrito()..agregar(p, cantidad: 2), 5000);
    final r = await ventas.corteDelDia(DateTime.now());
    expect(r.numeroVentas, 2);
    expect(r.totalCentavos, 7500);
  });

  test('bajo inventario alerta', () async {
    expect((await productos.bajoInventario()).length, 1);
  });

  // RETO Ronda 5: vender las 5 nieves y luego intentar vender 1 más
  test('reto: vender 5 nieves y luego 1 más lanza ExistenciasInsuficientes',
      () async {
    final p = (await productos.buscarPorCodigo('NV-001'))!; // existencias: 5
    await ventas.cobrar(Carrito()..agregar(p, cantidad: 5), 12500);
    // El carrito usa la foto vieja del producto (5 existencias) y lo acepta,
    // pero cobrar() revalida DENTRO de la transacción contra la base (0).
    final carrito = Carrito()..agregar(p);
    await expectLater(ventas.cobrar(carrito, 2500),
        throwsA(isA<ExistenciasInsuficientesException>()));
    expect((await productos.buscarPorCodigo('NV-001'))!.existencias, 0);
    expect((await ventas.corteDelDia(DateTime.now())).numeroVentas, 1);
  });
}
