---
description: Compila el APK release de Cabina 360 tras verificar analyze y tests.
agent: build
---

En el directorio de la app afectada (`appCabina360V2.3/` por defecto, o `flutter_gen_licens/` si el cambio es ahí):

1. Ejecuta `flutter analyze`. Si hay errores nuevos, detente y repórtalos.
2. Ejecuta `flutter test`. Si falla, detente y repórtalo.
3. Solo si ambos pasan, ejecuta `flutter build apk --release`.
4. Reporta la ruta del APK y recuerda: instalar y probar en dispositivo Android físico (grabación, efectos FFmpeg, servidor WiFi + QR, permisos).

$ARGUMENTS
