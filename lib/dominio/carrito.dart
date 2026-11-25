import 'excepciones.dart';
import 'producto.dart';

class LineaCarrito {
  final Producto producto;
  int cantidad;
  LineaCarrito(this.producto, this.cantidad);
  int get importeCentavos => producto.precioCentavos * cantidad;
}

class Carrito {
  /// IVA en porcentaje entero (16 = 16%).
  final int tasaIva;
  final Map<String, LineaCarrito> _lineas = {};

  Carrito({this.tasaIva = 16});

  List<LineaCarrito> get lineas => _lineas.values.toList();
  bool get estaVacio => _lineas.isEmpty;

  void agregar(Producto p, {int cantidad = 1}) {
    final actual = _lineas[p.codigo]?.cantidad ?? 0;
    if (actual + cantidad > p.existencias) {
      throw ExistenciasInsuficientesException(p.nombre, p.existencias);
    }
    if (_lineas.containsKey(p.codigo)) {
      _lineas[p.codigo]!.cantidad += cantidad;
    } else {
      _lineas[p.codigo] = LineaCarrito(p, cantidad);
    }
  }

  void quitar(String codigo) => _lineas.remove(codigo);

  void vaciar() {
    _lineas.clear();
    _descuentoPorcentaje = 0;
  }

  // ---- Reto Ronda 3: descuento por porcentaje ----
  int _descuentoPorcentaje = 0;
  int get descuentoPorcentaje => _descuentoPorcentaje;

  /// Aplica un descuento (0 a 100 %) sobre el importe de todas las líneas.
  void aplicarDescuento(int porcentaje) {
    if (porcentaje < 0 || porcentaje > 100) {
      throw ArgumentError.value(porcentaje, 'porcentaje', 'Debe estar entre 0 y 100');
    }
    _descuentoPorcentaje = porcentaje;
  }

  /// Suma de las líneas antes del descuento.
  int get importeBrutoCentavos =>
      _lineas.values.fold(0, (s, l) => s + l.importeCentavos);

  /// Descuento redondeado con enteros (sin double).
  int get descuentoCentavos =>
      (importeBrutoCentavos * _descuentoPorcentaje + 50) ~/ 100;

  /// Los precios YA incluyen IVA: se desglosa el impuesto del total.
  /// El IVA se calcula sobre el total ya con descuento.
  int get totalCentavos => importeBrutoCentavos - descuentoCentavos;

  int get subtotalCentavos => totalCentavos - ivaCentavos;

  /// iva = total * tasa / (100 + tasa), redondeado con enteros.
  int get ivaCentavos =>
      (totalCentavos * tasaIva + (100 + tasaIva) ~/ 2) ~/ (100 + tasaIva);

  int cambio(int pagoCentavos) {
    if (estaVacio) throw CarritoVacioException();
    if (pagoCentavos < totalCentavos) {
      throw PagoInsuficienteException(totalCentavos - pagoCentavos);
    }
    return pagoCentavos - totalCentavos;
  }
}
