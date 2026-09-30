import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notificadores_satt/models/models.dart';
import 'package:notificadores_satt/models/cartera_contribuyente.dart';
import 'package:notificadores_satt/screens/whatsapp_mensaje_dialog.dart';

CarteraContribuyente grupo() => agruparCartera([for(final tipo in ['OP','RD']) CarteraItem.fromJson({'id':tipo=='OP'?1:2,'tipo':tipo,'nombre':'Ana Pérez','cod_contribuyente':'1'})]).single;
void main() {
  test('saludo obligatorio y opciones sin duplicar deuda total', () {
    final base=mensajeWhatsapp(operador:'Juan',grupo:grupo());
    expect(base,contains('Hola, soy Juan, trabajador del SAT-T.'));
    expect(base,contains('Ana Pérez')); expect(base,contains('OP / RD'));
    expect(base, isNot(contains('S/')));
    final completo=mensajeWhatsapp(operador:'Juan',grupo:grupo(),op:100,rd:20,total:150,horario:true);
    expect(completo,contains('S/ 100.00')); expect(completo,contains('S/ 20.00')); expect(completo,contains('S/ 150.00'));
    expect(completo,contains('S de 9:00 am a 12:00 pm'));
    expect(Uri.https('wa.me','/51999999999',{'text':completo}).queryParameters['text'],completo);
  });
  test('modo llamada no menciona entrega de OP/RD y dice información de su deuda', () {
    final base = mensajeWhatsapp(operador: 'Juan', grupo: grupo());
    expect(base, contains('acabamos de entregarle una notificación'));
    final llamada = mensajeWhatsapp(operador: 'Juan', grupo: grupo(), modoLlamada: true);
    expect(llamada, contains('se le hace llegar la información de su deuda'));
    expect(llamada, isNot(contains('acabamos de entregarle')));
    expect(llamada, contains('Hola, soy Juan, trabajador del SAT-T.'));
    expect(llamada, contains('Ana Pérez'));
  });
  testWidgets('opciones y vista previa entregan el texto elegido', (tester) async {
    String? salida;
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(onPressed:() async {
      salida=await showDialog<String>(context:context,builder:(_)=>WhatsappMensajeDialog(grupo:grupo(),operador:'Juan',cargarImportes:() async => {'op':100,'rd':20,'total':150}));
    },child:const Text('Abrir'))))));
    await tester.tap(find.text('Abrir')); await tester.pumpAndSettle();
    await tester.tap(find.text('Incluir deuda OP')); await tester.pumpAndSettle();
    await tester.tap(find.text('Incluir horario de atención')); await tester.pumpAndSettle();
    final texto=tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(texto,contains('Deuda OP')); expect(texto,isNot(contains('Deuda RD')));
    await tester.tap(find.text('ABRIR WHATSAPP')); await tester.pumpAndSettle();
    expect(salida,texto); expect(tester.takeException(),isNull);
  });
  testWidgets('consulta fallida no inventa importes y permite reintento', (tester) async {
    var intentos=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:WhatsappMensajeDialog(grupo:grupo(),operador:'Juan',cargarImportes:() async {
      intentos++; if(intentos==1) throw Exception('sin red'); return {'op':0,'rd':null,'total':25};
    }))));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile,'Incluir deuda OP')).onChanged,isNull);
    await tester.tap(find.text('REINTENTAR')); await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile,'Incluir deuda OP')).onChanged,isNotNull);
    expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile,'Incluir deuda RD')).onChanged,isNull);
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data,isNot(contains('S/')));
  });
}