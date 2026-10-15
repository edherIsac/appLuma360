# AGENTS.md — Repo appLuma360 (multi-app Flutter)

> Scope repo-root. App principal: `appCabina360V2.3/` (Cabina 360 v2.2).
> App secundaria: `flutter_gen_licens/` (generador de licencias).
> Los comandos `flutter`/`dart` se ejecutan desde el directorio de cada app.
> Las rutas `lib/...` abajo se refieren a `appCabina360V2.3/lib/...` salvo indicación contraria.

App de grabación y compartición de videos para Cabina 360. Lee esto antes de editar.

## Comandos base

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
dart format lib test
```

Nunca ejecutes `flutter clean`, `git push` o `git commit` sin confirmación.
No edites `pubspec.yaml`, `android/`, `ios/` sin preguntar (ver `opencode.json`).

## Estructura

- `lib/main.dart` (~2455 líneas, archivo dios): UI `MyHomePage` + cámara + pipeline FFmpeg + socket legacy. **No agregues más lógica aquí.** Extrae a servicios/controladores nuevos.
- `lib/services/`: singletons con `static get instance`. Ej: `CameraService.instance`, `WifiServerService.instance`, `LoggingService.instance`.
- `lib/screens/`: `config_screen.dart`, `qr_screen.dart`, `license_screen.dart`, `onboarding/`, `advanced_config_screen.dart`, `usability_config_screen.dart`.
- `lib/models/`: `config.dart` (`ConfigCabina`), `permission_config.dart`, `permission_result.dart`.
- `lib/utils/formatters.dart`.

## Patrones obligatorios

1. **Logging, no `print`:** usa `LoggingService.instance.info/debug/warning/error/critical(tag, msg, [e, stack])`.
2. **Permisos:** solo vía `PermissionService.instance` (`initialize`, `requestRequired/requestAll`, `areAllRequiredGranted`). Respeta rangos por SDK (media granular 33+, `storage` ≤32, `manageExternalStorage` 30+). Ver `AndroidManifest.xml`.
3. **Cámara:** solo vía `CameraService`. No crees `CameraController` directo fuera de `main.dart` sin migrarlo al servicio. Respeta `_isInitializingCamera` y timeouts de 10s.
4. **Storage:** usa `StorageService` (`CVR_Clips/`, temporales `rec-new.mp4`, `ffmpeg-*.mp4`). Limpia con `deletedVideosTmp()`. No asumas rutas hardcodeadas.
5. **FFmpeg:** comandos en pipeline secuencial (efectos → marco → logo → audio). Revisa `statisticsCallback` — no hagas `setState` por frame. `VideoProcessingService` está a medio implementar (comandos placeholder); el pipeline real vive en `main.dart`.
6. **Servidor WiFi:** `WifiServerService` (puerto 8080, `shelf`). Páginas HTML generadas inline — si tocas `/`, `/connect`, `/qr`, `/api/videos`, prueba con 2 dispositivos en la misma red.
7. **Licencia:** `LicenseService` offline (`base64 device_id+expires+hmac`). `mi_clave_super_segura` está hardcodeada — no la expongas en logs ni la subas a ramas públicas.
8. **Estado/config:** `SharedPreferences` keys: `seenOnboarding`, `config` (JSON manual), `marcoPath/logoPath/audioPath`, `useFrontCamera`, `wifiName`, `last_use_date`, `license_base64`.

## Restricciones

- No toques secretos: `.env*`, `*keystore*`, `google-services.json` (bloqueados en `opencode.json`).
- `MANAGE_EXTERNAL_STORAGE` es sensible a Play Store — cualquier cambio de almacenamiento debe justificarse y preferir `MediaStore`.
- Socket `socket_io_client` (`appInitRecord/appChangeQuality`, IP `192.168.1.105`) es legacy — no lo extiendas sin confirmar.
- `_calculatePreviewDimensions()` en `main.dart` es frágil — cambios de preview requieren prueba en dispositivo físico.
- Tras cambiar logo (`logoPath`), llama `WifiServerService.instance.reloadLogo()`.

## Verificación mínima por cambio

1. `flutter analyze` sin nuevos warnings.
2. `flutter test` (o el test del área tocada).
3. Si toca grabación/FFmpeg/servidor/QR/permisos: prueba manual en dispositivo Android físico.
4. Si toca `config_screen.dart`: verifica guardar + restaurar defaults + `onConfigChanged` propaga a `main.dart`.
