
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notificadores_satt/models/models.dart';
import 'package:notificadores_satt/models/cartera_contribuyente.dart';
import 'package:notificadores_satt/services/cartera_ubicaciones.dart';

CarteraContribuyente grupo(String codigo, {String gps = ''}) => agruparCartera([CarteraItem.fromJson({'id':1,'cod_contribuyente':codigo,'nombre':'Prueba','direccion':'Jr. Prueba 100','coordenadas':gps})]).single;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('rechaza coordenadas ausentes o invalidas', () {
    for (final texto in ['', '0,0', 'NaN,1', '91,1', '1,181', 'texto']) { expect(coordenadaGuardada(texto),isNull); }
    expect(coordenadaGuardada('-6.48,-76.37')!.punto.latitude,-6.48);
  });
  test('distancia geografica y orden con faltantes al final', () {
    expect(distanciaMetros(const LatLng(0,0),const LatLng(0,1)),closeTo(111195,2));
    final grupos=[grupo('lejos'),grupo('sin'),grupo('cerca')];
    final puntos={'lejos':const UbicacionCartera(LatLng(0,2)),'cerca':const UbicacionCartera(LatLng(0,1))};
    expect(ordenarPorDistancia(grupos,const LatLng(0,0),puntos).map((g)=>g.codigo),['cerca','lejos','sin']);
    expect(grupos.first.codigo,'lejos');
  });
  test('GPS registrado tiene prioridad y no consulta proveedor', () async {
    final p=await CarteraUbicaciones().localizar(grupo('gps',gps:'-6.48,-76.37'));
    expect(p!.aproximada,false);
  });
  test('direccion se consulta una vez y se conserva en cache', () async {
    SharedPreferences.setMockInitialValues({});
    var llamadas=0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CarteraUbicaciones.canal,(call) async { llamadas++; return {'lat':-6.48,'lng':-76.37}; });
    addTearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CarteraUbicaciones.canal,null));
    final servicio=CarteraUbicaciones();
    expect(await servicio.localizar(grupo('cache'),buscarDireccion:false),isNull);
    expect(llamadas,0);
    expect((await servicio.localizar(grupo('cache')))!.aproximada,true);
    await CarteraUbicaciones().localizar(grupo('cache'));
    expect(llamadas,1);
  });
}