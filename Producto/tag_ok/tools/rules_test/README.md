# Pruebas de reglas de Firestore (beneficios)

Corren en el Emulator con el proyecto `demo-tag-ok`; no tocan produccion.

    cd Producto/tag_ok/tools/rules_test
    npm install --legacy-peer-deps
    $env:RULES = "../../firestore.rules"   # PowerShell (en bash: RULES=../../firestore.rules)
    npm test

Requiere Java y firebase-tools. Cubre: sin sesion, usuario normal (lee si, escribe no),
super admin (crea/edita/borra), operador y admin sin `rol` (no escriben), categoria
invalida, URLs sin https, campo extra, fechas invertidas y colecciones cerradas.
