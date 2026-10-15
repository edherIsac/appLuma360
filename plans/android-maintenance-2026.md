# Plan de Mantenimiento Android — Cabina 360 v2.2

Fecha: 2026-10-15
Base auditada: `compileSdk 36`, `targetSdk 36` (flutter.targetSdkVersion), `minSdk 24`, Flutter 3.41.6 / Dart 3.11.4, AGP 8.11.1.
Requisito Play vigente: desde 31-ago-2026 los updates deben targetear API 36. La app cumple hoy, pero hay riesgos de rechazo y rupturas en Android 14/15/16.

Reglas del repo (ver `AGENTS.md`):
- No `print`, usar `LoggingService`.
- Permisos solo vía `PermissionService`.
- Cámara solo vía `CameraService`.
- Storage vía `StorageService` + `MediaStoreHandler` (preferir `MediaStore`).
- No tocar `pubspec.yaml`, `android/`, `ios/`, secretos (`keystore`, `.env`, `google-services.json`) sin confirmación.
- Tras cambiar logo, llamar `WifiServerService.instance.reloadLogo()`.
- Verificación mínima: `flutter analyze` sin nuevos warnings, `flutter test`, prueba en físico si toca grabación/FFmpeg/servidor/QR/permisos.

---

## Fase 0 — Preparación (0.5 día)

- [ ] Crear rama `maintenance/android-2026`.
- [ ] `flutter pub get && flutter analyze > baseline-analyze.txt && flutter test`.
- [ ] Guardar `flutter pub outdated` como referencia.
- [ ] Definir dispositivo físico de prueba (Android 13, 14 o 15+) + emulador API 36 16KB.
- Criterio salida: baseline reproducible.

## Fase 1 — P0 Play Store / Seguridad (2–3 días) — prioridad máxima

### 1.1 `MANAGE_EXTERNAL_STORAGE` deja de ser requerido
Archivos: `android/app/src/main/AndroidManifest.xml:59`, `lib/services/permission_service.dart:83-91`, `lib/services/storage_service.dart`, `android/app/src/main/kotlin/com/luma/cabina360/MediaStoreHandler.kt`.

- [ ] Quitar `android:requestLegacyExternalStorage` y `preserveLegacyExternalStorage` (`AndroidManifest.xml:7-8`). Ya no tienen efecto en API 30+.
- [ ] Cambiar `Permission.manageExternalStorage` a `isRequired: false` o eliminarlo. `StorageService` usa `getExternalStorageDirectory()/CVR_Clips` (app-specific, no lo necesita) y galería pública ya va por `MediaStoreHandler`.
- [ ] Documentar justificación si se mantiene para Play Console, o eliminarlo del manifest si `MediaStore` cubre el caso.
- [ ] Probar en físico: grabar → procesar FFmpeg → guardar en galería → listar en servidor.
- Verificación: `flutter analyze`, `flutter test test/`, prueba física de guardado. Sin este cambio hay riesgo de rechazo en revisión Play.

### 1.2 Endurecer servidor WiFi (LAN abierta)
Archivo: `lib/services/wifi_server_service.dart:415-528`.

- [ ] Agregar token de sesión (query param o header) generado en app; QR incluye `?token=...`; rechazar 401 sin token en `/`, `/api/videos`, descargas.
- [ ] Sanitizar `request.url.path`: normalizar, bloquear `..`, solo servir extensiones `mp4/avi/mov/mkv` dentro de `recordingDir`.
- [ ] Restringir CORS (`Access-Control-Allow-Origin`) en vez de `*` o documentar por qué se deja abierto en LAN.
- [ ] Declarar `android:usesCleartextTraffic` explícito + `networkSecurityConfig` solo para cleartext LAN, o documentar decisión.
- [ ] Reemplazar `print` en `:84,119,223,230,642,1424,1436` por `LoggingService`.
- Verificación: desde 2.º dispositivo en misma red, sin token → 401; con token → lista/descarga OK. `flutter analyze` sin `avoid_print` nuevos.

### 1.3 Licencia: reducir falsificación
Archivo: `lib/services/license_service.dart:7`.

- [ ] NO subir ni loggear `_secretKey`. Rotar clave fuera del repo (variable de entorno / Play App Signing / backend).
- [ ] Corto plazo: ofuscar + validar formato/expiración con mensajes genéricos; largo plazo: verificación en servidor.
- Verificación: `grep -r mi_clave_super_segura` solo en secreto local, nunca en logs ni ramas públicas.

## Fase 2 — P1 Rupturas Android 14/15/16 (3–5 días)

### 2.1 Acceso parcial a fotos/videos (Android 14+)
Archivos: `AndroidManifest.xml:62-64`, `permission_service.dart:46-72`.

- [ ] Agregar `<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />`.
- [ ] Subir `permission_handler` 11.4.0 → 13.0.2 (requiere `READ_MEDIA_VISUAL_USER_SELECTED` y estado `limited`).
- [ ] Manejar `PermissionStatus.limited`: mostrar UI de re-selección, no bloquear como denegado.
- Verificación: en Android 14+, conceder acceso parcial → app opera con subset, permite re-elegir.

### 2.2 Nombre WiFi / ubicación (Android 13+)
Archivo: `wifi_server_service.dart:111-387`, `permission_service.dart:92-109`, `AndroidManifest.xml:80-85`.

- [ ] Decidir: SSID real (requiere location precisa + location services ON) o modo solo-IP + nombre configurable (`_configuredWifiName`).
- [ ] Si se quiere SSID: pedir `location` como requerido para esa función, declarar `NEARBY_WIFI_DEVICES` con `neverForLocation` solo si aplica, y eliminar fallbacks `iwconfig/dumpsys/iw` (`:249-342`) que no funcionan sin privilegios.
- [ ] Si se usa modo solo-IP: simplificar `_getWifiNameAndroid` y documentar.
- [ ] Revisar `wifi_iot 0.3.19` (`setEnabled` muerto desde API 29): actualizar a 0.4.0 o eliminar si solo se muestra QR.
- Verificación: en Android 13/14/15 físico, con y sin ubicación, el nombre/IP mostrado es correcto.

### 2.3 Foreground service
Archivo: `AndroidManifest.xml:74-75`.

- [ ] Si no hay servicio en foreground real: eliminar ambos permisos para evitar revisión.
- [ ] Si hay procesamiento largo: declarar `<service android:foregroundServiceType="mediaProcessing|...">`, pedir permiso en runtime (Android 14+) y usar `mediaProcessing` en Android 15.
- Verificación: sin crash al procesar en background en Android 14+.

### 2.4 Edge-to-edge (Android 15/16, target 36)
Archivo: `lib/main.dart` (`_calculatePreviewDimensions`, preview cámara).

- [ ] Manejar `WindowInsets` (status/nav/cutout). En Android 16 `windowOptOutEdgeToEdgeEnforcement` está deshabilitado.
- [ ] Probar en físico: preview, botones grabar, pantallas config/QR sin elementos tapados.
- Verificación: prueba física obligatoria.

### 2.5 16KB page size (deadline Play 01-feb-2027)
- [ ] Subir `ffmpeg_kit_flutter_new` 3.2.0 → 4.6.7 (fork mantenido, binarios realineados).
- [ ] Probar en emulador API 35+ imagen 16KB + `check_elf_alignment`.
- [ ] Regresión FFmpeg completa (efectos → marco → logo → audio).
- Verificación: `flutter test`, pipeline real en dispositivo/emulador 16KB.

## Fase 3 — P2 Dependencias (2–4 días, por oleadas)

Orden sugerido para minimizar breaking changes (una oleada = pub get + analyze + test + smoke):

- Oleada A (permisos/red): `permission_handler → 13.0.2`, `network_info_plus 6.1.4 → 8.2.x`, `connectivity_plus 6.1.5 → 7.3.x`, `wifi_scan 0.4.1+2 → 0.5.0`.
- Oleada B (media): `camera 0.11.4 → 0.12.x` (+ `camera_android_camerax`), `file_picker 8.3.7 → 13.1.0`, `share_plus 10.1.4 → 13.3.x`, `device_info_plus 11.5.0 → 13.3.0`.
- Oleada C (otros): `socket_io_client 2.0.3+1 → 3.1.6` (o eliminar si el socket `192.168.1.105` legacy ya no se usa), `wakelock_plus 1.5.2 → 1.8.x`, `url_launcher 6.3.2 → 6.3.3`, `path_provider/shared_preferences` patch.
- [ ] Actualizar Flutter 3.41.6 → estable actual antes de majors.
- Verificación por oleada: `flutter analyze` sin nuevos warnings, `flutter test`, smoke en físico.

## Fase 4 — Higiene (1 día)

- [ ] Eliminar `print` en producción (230 `avoid_print` en `analyze`): `memory_management_service.dart`, `video_*_service.dart`, `performance_config_service.dart`, `advanced_presets_manager.dart`, `wifi_server_service.dart`.
- [ ] `dart format lib test`.
- [ ] Revisar `POST_NOTIFICATIONS` runtime (Android 13+) y `NEARBY_WIFI_DEVICES` sin uso.
- Verificación: `flutter analyze` limpio de `avoid_print`.

---

## Matriz de riesgo

| Ítem | Riesgo si no se hace | Esfuerzo |
|---|---|---|
| MANAGE requerido | Rechazo Play | S |
| Servidor sin auth | Fuga/exposición LAN | M |
| Licencia hardcodeada | Licencias forjadas | S–M |
| Sin VISUAL_USER_SELECTED | Roto en Android 14+ | S |
| SSID sin location | Siempre “no detectada” | S |
| FGS sin tipo | Crash/revisión Android 14+ | S |
| Sin edge-to-edge | UI tapada Android 15/16 | M |
| FFmpeg 3.2.0 sin 16KB | Bloqueo updates feb-2027 | M |
| Deps majors viejas | Builds rotos futuros | M |

## Criterios de aceptación global

1. `flutter analyze` sin nuevos warnings vs baseline.
2. `flutter test` verde.
3. Prueba física: grabar → FFmpeg → guardar galería → servir por WiFi a 2.º dispositivo + QR.
4. Prueba Android 14+: acceso parcial media, SSID/IP correcto, notificaciones, sin `MANAGE` requerido (salvo justificación documentada).
5. Ningún secreto (`keystore`, `.env`, `google-services.json`, `mi_clave_super_segura`) en diffs ni logs.

## Siguiente paso propuesto

Empezar por Fase 1.1 + 1.2 en rama `maintenance/android-2026` (requiere confirmación para tocar `android/` según `opencode.json`).
