# Puesta en marcha — notificadores_satt2 (SERVER) — sin alterar PROD

PROD intacto: `\\192.168.1.6\notificadores_satt2` + `NOTIFICADORES-SAT-FINAL-20260918.apk`.
Todo lo nuevo vive en: `notificadores_satt2_SERVER/` (espejo local de la última versión + cola offline + Llamadas) + `backend_patch/` (API + tests + SQL de la tabla nueva). El APK nuevo se compila desde `notificadores_satt2_SERVER` con el SDK local y se publica en `\\192.168.1.6\notificadores_satt2`.

## Alcance actual (24/09): condiciones DEV + registro pagado → FINALIZADO + cola offline + columna MODIF + módulo LLAMADAS

App (`notificadores_satt2_SERVER/lib`):
1. **Sin suministro ni bloque receptor**: el registro de entrega ya no pide número de suministro, DNI/receptor, parentesco ni observaciones. Solo condiciones **Notificado / Inubicado** (no pagado) y **Finalizado** (pagado).
2. **Registro ya pagado → FINALIZADO**: al tocar "Finalizar" en una fila con OP/RD PAGADA, la app solo pide la fotografía del domicilio fiscal y la actualización de la ubicación GPS, **bloquea los cargos OP/RD** y guarda con condición `'Finalizado'`.
3. **Cargo OP / Cargo RD (no pagado)**: después de tomar la fotografía se aplica auto-recorte local estilo scan (`services/auto_scan.dart`) con botón "Editar / scan" (`screens/editor_imagen_screen.dart`).
4. **Cola offline de pendientes**: todo lo capturado se guarda como borrador en el equipo (SQLite + fotos en almacén permanente). Sin conexión queda **pendiente de envío** con reintento automático al recuperar red (clave de idempotencia UUID en el servidor).
5. **Nueva columna MODIF.** (ícono naranja): abre la entrega en modo edición aunque ya esté grabada; llama a `POST cartera-op-rd/actualizar/` (`ApiService.actualizarEntrega`), que ahora acepta también `Finalizado` (foto domicilio + GPS, sin cargos) e `idempotencia`.
6. **Módulo LLAMADAS en el menú principal** (`screens/llamadas_screen.dart` → botón "LLAMADAS"): misma mecánica que Cartera OP/RD (mismo combo **Identificador OP/RD** y grilla con las mismas columnas con colores por estado de pago), pero con botón **FINALIZAR** en lugar de Entregar, y una columna **OBSERVACIONES** con la fecha compromiso.
   - El diálogo de llamada registra: **en qué situación quedó la llamada** (Atendida / No contestada / Numero no existe) y, si fue **Atendida**, qué dijo el contribuyente (**dijo que vendrá a pagar** + selección de fecha, o **dijo que no acepta la deuda**), más **observaciones** libres.
   - Todo se guarda en la base `BDSGTM01` (tabla nueva `LlamadasContribuyentes`) vía `ApiService.registrarLlamada` (`POST .../llamadas/finalizar/`).
   - La grilla pide `incluir_llamadas=1`; el botón pasa a "Editar" si ya hay llamada registrada (ya no hay columna OBSERVACIONES).
   - **Código subrayado** (igual que OP/RD): tocar consulta la deuda en `ConsultasScreen`; al retroceder regresa a la grilla de llamadas.
   - **TEL.** (igual que OP/RD): llama al contribuyente (canal nativo); con más de un número permite elegirlo.
   - **WA** (igual que OP/RD): abre la pantalla de selección de información y WhatsApp, pero el mensaje **no menciona entrega de OP/RD**; dice *"se le hace llegar la información de su deuda"* (`whatsapp_mensaje_dialog.dart` con `modoLlamada: true`).
   - **Dictado por voz**: en el cuadro de observaciones del diálogo hay un micrófono (mediano) que al tocar reconoce la voz y escribe automáticamente en español (`speech_to_text: ^7.5.0`; permiso `RECORD_AUDIO` + query `RecognitionService` en el manifest).
7. Dependencias nuevas en `pubspec.yaml`: `sqflite`, `connectivity_plus`, `uuid`, `path_provider`, `path`, `speech_to_text` (+ `sqflite_common_ffi` en dev). `uuid` también cubre la idempotencia de las llamadas.
8. **Botón GUARDAR de la entrega**: se agregó área blanca al final de la pantalla (espacio inferior) para que el botón no quede tapado por la barra de navegación del teléfono (`screens/finalizar_notificacion_screen.dart`).

Backend (`backend_patch/sistema_sat/controladores/api_municipalidad/Cartera_notificaciones.py`):
- `finalizar` (ya soportado): condiciones Notificado/Inubicado (exigen foto dom + GPS + ≥1 cargo) y `Finalizado` (foto dom + GPS, sin cargos). Idempotencia por UUID: reintentos no duplican.
- `actualizar_entrega`: acepta Notificado/Inubicado/**Finalizado**; para `Finalizado` no exige cargos. Maneja `idempotencia` (reintentos no duplican la fila de fotos) y guarda `FechaCaptura`.
- **Nuevo `finalizar_llamada`** (`POST api/notificadores/llamadas/finalizar/`, ruta en `urls.py`): valida resultado y compromisos, exige fecha si "vendrá a pagar", trunca observaciones a 2000, registra en `LlamadasContribuyentes` con idempotencia (reintentos devuelven la llamada anterior sin duplicar) y guarda `FechaCaptura`.
- `cartera_asignada` acepta `incluir_llamadas=1`: adjunta la última llamada de cada contribuyente (resultado/compromiso/fecha/observaciones/fec_registro). Si la tabla de llamadas aún no existe, la cartera carga igual.
- La validación clásica (Recepcionado/Negativa/Devuelto con suministro) se conserva para que el APK PROD siga funcionando igual.

Tabla nueva en BDSGTM01 (`backend_patch/sql/crear_tabla_llamadas.sql`):
```sql
BDSGTM01.dbo.LlamadasContribuyentes (
  id INT IDENTITY PK,
  CodContribuyente VARCHAR(11), identificador INT, codNotificador INT,
  idOriginalCartera INT, FecRegistro DATETIME,
  Resultado VARCHAR(20)  -- 'Atendida' | 'No contestada' | 'Numero no existe'
  Compromiso VARCHAR(40) -- 'Vendra a pagar' | 'No acepta la deuda'
  FechaCompromiso DATE, Observaciones VARCHAR(2000),
  IdempotenciaKey VARCHAR(64) UNIQUE filtrado, FechaCaptura DATETIME
)
```

## Aplicar en el servidor (192.168.1.6), en este orden

1. **Crear la tabla** (una sola vez) ejecutando `backend_patch/sql/crear_tabla_llamadas.sql` contra **BDSGTM01**.
2. Backup backend (en el servidor):
   ```
   copy Cartera_notificaciones.py Cartera_notificaciones.py.bak-20260924b
   copy urls.py urls.py.bak-20260924b
   ```
3. Copiar encima `backend_patch/sistema_sat/controladores/api_municipalidad/Cartera_notificaciones.py` y `backend_patch/sistema_sat/urls.py` (agrega `/llamadas/finalizar/`).
4. Correr tests (en el servidor, con myenv):
   ```
   myenv\Scripts\python.exe test_entrega_op_rd.py
   myenv\Scripts\python.exe test_whatsapp_importes.py
   myenv\Scripts\python.exe test_entrega_dev.py
   myenv\Scripts\python.exe test_llamadas.py   (copiar este archivo junto a los otros tests)
   ```
   Los 4 deben salir OK. Si alguno falla: restaurar los `.bak` y avisar.
5. Reiniciar el servicio Django/API (como hoy: `correr_api.bat` / `iniciar_servicios.bat`).
6. App: el proyecto listo para compilar es `notificadores_satt2_SERVER/`. Compilar el APK con el SDK local y publicarlo como `NOTIFICADORES-SATT-DDMMAAAA-HHMM.apk` (fecha día-mes-año + hora, p. ej. `NOTIFICADORES-SATT-24092026-1530.apk`) en `\\192.168.1.6\notificadores_satt2`.

## Verificación hecha aquí (CIERRE LLAMADAS + GRID DE CONTACTO + DICTADO)
- [x] `flutter analyze --no-pub`: sin errores (solo infos de estilo preexistentes).
- [x] `flutter test --no-pub`: **80/80 OK** (incluye `llamadas_test.dart` con combo, grilla sin columna OBSERVACIONES, código→Consultar deuda, botones TEL/WA, dictado por micrófono, guardado No contestada y exigencia de fecha con Vendrá a pagar, y `whatsapp_mensaje_test.dart` con modo llamada).
- [x] Backend: `test_llamadas.py` **15 OK**, `test_entrega_dev.py` **22 OK**, `test_entrega_op_rd.py` **10 OK** (sin cambios en backend en este pase).
- [x] `backend_patch/sql/crear_tabla_llamadas.sql` creado (no altera tablas existentes).
- [x] Sincronizado a `\\192.168.1.6\notificadores_satt2`: `lib/models/models.dart`, `lib/services/api_service.dart`, `lib/screens/llamadas_screen.dart`, `lib/screens/whatsapp_mensaje_dialog.dart`, `lib/screens/finalizar_notificacion_screen.dart`, `lib/screens/home_screen.dart`, `test/llamadas_test.dart`, `test/whatsapp_mensaje_test.dart`, `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml` (RECORD_AUDIO + RecognitionService), `compilar_apk_server.bat`, este README — SHA256 OK.
- [x] APK del módulo LLAMADAS compilado y subido al share: `NOTIFICADORES-SATT-24092026-1503.apk` (SHA256 `B133406449DAAAE9066328577E3643BB6E31FE4E688EAE12A50651D6F1537FD4`), con enlace al backend `http://190.119.38.13`.
- [x] APK nuevo (grilla de contacto + dictado) compilado y subido al share: `NOTIFICADORES-SATT-24092026-1527.apk` (SHA256 `9E0FBE335C6DFFAFEEAE086A8E3E3546A49F0E1C4883CCA9DF1709EFCDF90042`), con enlace al backend `http://190.119.38.13`. Instalar ESTE APK; el `NOTIFICADORES-SATT-24092026-1503.apk` anterior queda como referencia.
  - SHA256 PROD (intacto, sin tocar): `1D0B18672986534C3B4786B2797F0FDC4EF5B66A5378F8E03D25731216095017`

**Pendiente en el servidor (192.168.1.6)**: aplicar la tabla SQL + `backend_patch` según el orden de la sección anterior y reiniciar la API, antes de probar el APK nuevo del módulo LLAMADAS. El APK PROD sigue igual.