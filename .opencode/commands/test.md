---
description: Corre los tests de Cabina 360 (todo o un área).
agent: build
---

En el directorio de la app afectada (`appCabina360V2.3/` por defecto, o `flutter_gen_licens/` si el cambio es ahí):

1. Si `$ARGUMENTS` trae una ruta (ej. `test/permission_test.dart`), corre `flutter test $ARGUMENTS`. Si viene vacío, corre `flutter test`.
2. No agregues dependencias ni toques `pubspec.yaml`.
3. Reporta: tests pasados/fallidos + failures relevantes. Si un test falla por causa preexistente, indícalo sin corregirlo salvo que sea trivial y del área tocada.

$ARGUMENTS
