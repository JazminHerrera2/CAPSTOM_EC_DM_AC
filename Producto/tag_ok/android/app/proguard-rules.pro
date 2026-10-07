# google_mlkit_text_recognition menciona reconocedores de otros alfabetos que
# no se incluyen (la app solo usa el alfabeto latino). Sin estas reglas, R8
# falla en el build de release con "Missing class ...".
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
