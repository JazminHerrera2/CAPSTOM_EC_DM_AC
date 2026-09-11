# 🚀 Guía Rápida de Ejecución Local - Proyecto TAG OK

Esta guía está diseñada para que cualquier integrante del equipo pueda clonar y ejecutar el proyecto **TAG OK** en su computadora en menos de 3 minutos, sin necesidad de configurar claves ni instalar dependencias complejas.

---

## 📌 1. ¿Quedó guardada la configuración de Firebase, Mapbox y Gemini?

**¡SÍ, 100%!** Todas las credenciales del nuevo entorno (**Firebase `tag-ok-v2`**, **Mapbox** y **Google Gemini AI**) fueron empaquetadas directamente en el código fuente (`main.dart`) en formato Base64 en memoria.

> **Nota para el equipo:** No necesitan crear cuentas nuevas en Firebase, ni configurar token de Mapbox, ni clave de Gemini. ¡Todo funciona automáticamente al descargar los cambios!

---

## 📋 2. Requisitos Previos

Únicamente necesitas tener instalado en tu computador:
1. **Git** (para clonar o hacer pull de la rama `main`).
2. **Navegador Google Chrome** o Microsoft Edge.
3. *(Opcional)* No requieres instalar Flutter globalmente ni configurar variables de sistema PATH, ya que el proyecto incluye el SDK portátil integrado dentro de la carpeta `.tools/`.

---

## 🚀 3. Paso a Paso para Levantar el Proyecto

### Paso 1: Obtener la última versión del código
Abre tu terminal en la carpeta del repositorio o usa **GitHub Desktop** y ejecuta:
```bash
git checkout main
git pull origin main
```

### Paso 2: Ejecutar el Asistente Automático (`setup.bat`)
1. Entra a la carpeta `Producto/`.
2. Haz **doble clic** en el archivo **`setup.bat`**.
3. El asistente se encargará de instalar las dependencias de Flutter automáticamente en primer plano.

### Paso 3: Elegir la Aplicación a Ejecutar
Cuando el menú interactivo aparezca en la consola:

```text
=======================================================
   Configuracion y Ejecucion del Proyecto TAG OK
=======================================================

Selecciona la aplicacion que deseas ejecutar:
1) App Principal (tag_ok) - Ejecutar en Windows Desktop
2) App Principal (tag_ok) - Ejecutar en Chrome (Web)
3) Panel Administrador (admin) - Ejecutar en Windows Desktop
4) Panel Administrador (admin) - Ejecutar en Chrome (Web)
5) Salir
```

* **Para abrir la App Móvil (Conductor):** Escribe `2` y presiona **Enter**. Se abrirá Chrome en [http://127.0.0.1:8090](http://127.0.0.1:8090).
* **Para abrir el Backoffice (Panel Admin):** Escribe `4` y presiona **Enter**. Se abrirá Chrome en [http://127.0.0.1:8091](http://127.0.0.1:8091).

---

## 🔑 4. Credenciales de Acceso

### A. Para entrar al Panel de Administración (Admin):
* **URL:** [http://127.0.0.1:8091](http://127.0.0.1:8091)
* **Correo:** `tagokv2@gmail.com`
* **Contraseña:** `@Tagokv2duocuc`

### B. Para entrar a la Aplicación Móvil (Cliente):
* **URL:** [http://127.0.0.1:8090](http://127.0.0.1:8090)
* Puedes hacer clic en **"Registrarse"** para crear tu propia cuenta de prueba en 5 segundos con cualquier correo y contraseña.

---

## 🛠️ Preguntas Frecuentes y Solución de Problemas

* **¿Qué hago si me dice que el puerto 8090 u 8091 está ocupado?**
  Abre la consola de comandos de Windows (cmd) y ejecuta:
  `taskkill /F /IM dartvm.exe` y vuelve a correr `setup.bat`.
* **¿Están disponibles los 104 pórticos de peaje?**
  Sí, la base de datos de Firestore ya se encuentra poblada con los 104 pórticos de peaje de las autopistas concesionadas de Santiago (Autopista Central, Costanera Norte, Vespucio Sur, Vespucio Norte, AVO).

---
*Desarrollado para el proyecto CAPSTONE - TAG OK*
