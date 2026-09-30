import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notificadores_satt/models/models.dart';
import 'package:notificadores_satt/models/cartera_contribuyente.dart';
import 'package:notificadores_satt/screens/cartera_op_rd_screen.dart';
import 'package:notificadores_satt/screens/consultas_screen.dart';
import 'package:notificadores_satt/screens/aviso_sistema.dart';
import 'package:notificadores_satt/services/upload_service.dart';

Map<String,dynamic> doc(int id,String tipo,{String codigo='00000000001', List<String> phones=const ['999888777','988777666']}) => {
  'id':id,'cod_contribuyente':codigo,'nombre':'Persona de prueba','tipo':tipo,'correlativo':'${tipo}123',
  'direccion':'Dirección fiscal','direccion_adicional':'Referencia adicional','telefonos':phones,
  'saldo_actual':0,'estado_consultado':'2026-09-17 10:00:00',
};
http.Response response(Map<String,dynamic> body) => http.Response.bytes(utf8.encode(jsonEncode(body)),200,headers:{'content-type':'application/json'});
MockClient client(List<Map<String,dynamic>> rows) => MockClient((request) async {
  if(request.url.path.endsWith('/identificadores/')) return response({'status':'ok','data':[{'fecha':'2026-09-16','op_total':1,'rd_total':1,'identificador':20260916}]});
  if(request.url.path.contains('/deuda-consolidada/')) return response({'status':'ok','contribuyente':{'codigo':'00000000001','nombre':'Persona de prueba'}});
  return response({'status':'ok','data':rows});
});
Future<void> load(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home:CarteraOpRdScreen()));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<IdentificadorOpRd>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('2026-09-16 — OP: 1 | RD: 1').last);
  await tester.pumpAndSettle();
}
void main() {
  // La grilla sincroniza pendientes (red + SQLite): aislado en tests.
  setUp(() {
    UploadService.conexionOverride = () async => false;
  });
  tearDown(() {
    UploadService.conexionOverride = null;
  });
  test('agrupa OP/RD y mantiene cada documento pendiente',(){
    final groups=agruparCartera([CarteraItem.fromJson(doc(1,'OP')),CarteraItem.fromJson(doc(2,'RD')),CarteraItem.fromJson(doc(1,'OP'))]);
    expect(groups.length,1);expect(groups.single.documentos.length,2);
    expect(groups.single.numeros('OP'),'OP123');expect(groups.single.numeros('RD'),'RD123');
    expect(groups.single.pendientes.length,2);expect(groups.single.telefonos.length,2);
  });
  test('normaliza teléfonos y elimina duplicados y valores vacíos',(){
    expect(normalizarTelefonos('#999888777; +51 999 888 777 / 988777666'),['+51999888777','+51988777666']);
    expect(normalizarTelefonos('SIN TELEFONO; 000000000'),isEmpty);
    expect(normalizarTelefonos('999888777 988777666').length,2);
  });
  testWidgets('fila única, ancho horizontal completo y selección de teléfono',(tester) async {
    tester.view.physicalSize=const Size(1100,600);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'operador_dni':'12345678'});
    String? llamado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('sat/contacto'),(call) async { llamado=call.arguments['numero']; return null; });
    addTearDown(()=>tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('sat/contacto'),null));
    await http.runWithClient(() async {
      await load(tester);
      expect(find.text('Persona de prueba'),findsOneWidget);
      expect(find.text('OP123'),findsOneWidget);expect(find.text('RD123'),findsOneWidget);
      expect(find.text('SIN DEUDA'),findsOneWidget);expect(find.text('* Referencia adicional'),findsOneWidget);
      expect(tester.getTopRight(find.text('ESTADO')).dx,greaterThan(990));
      await tester.tap(find.byTooltip('Llamar'));await tester.pumpAndSettle();
      expect(find.text('Elegir número para llamar'),findsOneWidget);
      await tester.tap(find.text('+51999888777'));await tester.pumpAndSettle();
      expect(llamado,'+51999888777');
      await tester.tap(find.byTooltip('WhatsApp'));await tester.pumpAndSettle();
      expect(find.text('Elegir número para WhatsApp'),findsOneWidget);
      await tester.tap(find.text('CANCELAR'));await tester.pumpAndSettle();
      await tester.tap(find.text('00000000001'));await tester.pumpAndSettle();
      await tester.tap(find.text('SÍ'));await tester.pumpAndSettle();await tester.pump(const Duration(seconds:1));await tester.pumpAndSettle();
      expect(find.byType(ConsultasScreen),findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text,'00000000001');
      await tester.pageBack();await tester.pumpAndSettle();expect(find.byType(CarteraOpRdScreen),findsOneWidget);
      expect(tester.takeException(),isNull);
    },()=>client([doc(1,'OP'),doc(2,'RD')]));
  });
  testWidgets('sin teléfonos ambos accesos quedan deshabilitados',(tester) async {
    tester.view.physicalSize=const Size(360,720);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'operador_dni':'12345678'});
    await http.runWithClient(() async {
      await load(tester);
      expect(tester.widget<IconButton>(find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Sin teléfono')).onPressed,isNull);
      expect(tester.widget<IconButton>(find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Sin teléfono para WhatsApp')).onPressed,isNull);
      expect(tester.takeException(),isNull);
    },()=>client([doc(1,'OP',phones:[])]));
  });
  testWidgets('aviso de programación requiere aceptar',(tester) async {
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(
      onPressed:()=>mostrarAvisoSistema(context),child:const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));await tester.pumpAndSettle();
    expect(find.text('</>'),findsOneWidget);expect(find.text('Su uso es monitoreado.'),findsOneWidget);
    await tester.tap(find.text('ACEPTAR'));await tester.pumpAndSettle();expect(find.byType(AlertDialog),findsNothing);
  });
}