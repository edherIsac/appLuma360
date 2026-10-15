---
description: Corre flutter analyze sin nuevos warnings en Cabina 360.
agent: build
---

En el directorio de la app afectada (`appCabina360V2.3/` por defecto, o `flutter_gen_licens/` si el cambio es ahí):

1. Ejecuta `flutter analyze`.
2. Si hay warnings/errores nuevos causados por el cambio actual, corrígelos (sin refactors oportunistas, sin tocar `pubspec.yaml`, `android/`, `ios/`).
3. Reporta: salida resumida + archivos tocados. Si aparecen errores preexistentes no relacionados, listalos aparte sin corregirlos.

$ARGUMENTS
