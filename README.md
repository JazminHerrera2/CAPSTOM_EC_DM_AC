# Tag OK 🚗💨

**Tu copiloto inteligente para el control de gastos de TAG, navegación en tiempo real y auditoría con Inteligencia Artificial.**

> Optimiza tus rutas, gestiona tu presupuesto mensual, administra las tarifas remotamente y nunca más te sorprendas con cobros indebidos en tu cuenta del TAG.

[![Flutter](https://img.shields.io/badge/Flutter-3.41.9-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.11.5-blue.svg)](https://dart.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Cloud%20Firestore-orange.svg)](https://firebase.google.com/)
[![Mapbox](https://img.shields.io/badge/Mapbox-GL%20Maps-000000.svg)](https://www.mapbox.com/)
[![Gemini](https://img.shields.io/badge/Gemini-AI-blueviolet.svg)](https://deepmind.google/technologies/gemini/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

<a id="tabla-de-contenidos" name="tabla-de-contenidos"></a>
## 📋 Tabla de Contenidos

- [Descripción](#descripcion)
- [Características Principales](#caracteristicas-principales)
- [Dashboard & Visualización](#dashboard-visualizacion)
- [Auditoría Inteligente & IA](#auditoria-inteligente)
- [Panel de Administración (Admin)](#panel-admin)
- [Instalación y Ejecución Rápida](#instalacion-ejecucion)
- [Stack Tecnológico](#stack-tecnologico)
- [Estructura del Proyecto](#estructura-proyecto)

---

<a id="descripcion" name="descripcion"></a>
## 📝 Descripción

**Tag OK** es una suite completa diseñada para los conductores chilenos y las empresas operadoras. A diferencia de un GPS convencional, Tag OK integra un motor de cálculo de tarifas dinámico y permite saber el costo exacto de tu viaje en tiempo real.
Además, la suite incluye un **Panel de Administración Web** para actualizar precios y pórticos dinámicamente, y un motor de **Auditoría con IA (Gemini)** que analiza boletas reales (PDF/CSV) para detectar cobros fantasmas o sobreprecios.

---

<a id="caracteristicas-principales" name="caracteristicas-principales"></a>
## ✨ Características Principales

### 🛰️ Navegación en Tiempo Real
- Cálculo de rutas óptimas (Mapbox API).
- Detección satelital de pórticos en el trayecto.
- Cobros dinámicos en tiempo real según el tipo de tarifa: TBFP (Base), TBP (Punta) y TS (Saturación).
- Mantiene la sesión activa e ininterrumpida utilizando `StreamBuilder` con Firebase Auth.

### 🚗 Gestión de Flota y Presupuesto
- Identificación visual de vehículos (Autos, Motos, Camionetas) y registro de patentes.
- Semaforización de presupuesto: Alertas dinámicas al 50%, 75%, 90% y 100% de gasto mensual.

---

<a id="auditoria-inteligente" name="auditoria-inteligente"></a>
## 🤖 Auditoría Inteligente & IA

Olvídate de revisar boletas a mano. El sistema cruza automáticamente los datos que te cobran las autopistas versus tus viajes reales almacenados en el historial de tu GPS.
- **Motor Multi-Formato NATIVO**:
  - Lee planillas Excel (`.csv`) de Autopista Central de manera nativa.
  - Posee un analizador de texto avanzado (`PdfTextExtractor`) capaz de **leer directamente** los PDFs oficiales de Costanera Norte, Vespucio Sur y Vespucio Norte sin depender de servidores externos, de forma **100% offline y gratuita**.
- **Análisis con Gemini AI**: En su modo avanzado, procesa grandes volúmenes de datos utilizando la IA de Google Gemini para cruzar transacciones y emitir juicios claros sobre la legitimidad de las boletas.
- **Modo Contingencia**: Si la IA no está disponible, el sistema cambia instantáneamente a un motor algorítmico local ultra rápido para mostrar las discrepancias matemáticas.

---

<a id="panel-admin" name="panel-admin"></a>
## ⚙️ Panel de Administración Web (Admin)

Junto a la aplicación móvil, el repositorio incluye un **Backoffice de gestión** para operar el negocio:
- Dashboard de estadísticas generales en vivo.
- ABM (Alta/Baja/Modificación) en tiempo real de Tarifas Base, Punta y Saturación, pórticos y vehículos.
- Gestión de Usuarios (Restablecimiento de contraseñas, edición de presupuestos y eliminación).
- Se conecta en tiempo real a la misma base de datos `Firestore` que los clientes, reflejando cambios instantáneamente en las rutas.

---

<a id="instalacion-ejecucion" name="instalacion-ejecucion"></a>
## 🚀 Instalación y Ejecución Rápida (Zero Config)

Gracias a nuestro sistema de encriptación **Base64 en Memoria**, ya no necesitas configurar engorrosos archivos `.env`. Las claves (Mapbox, Firebase y Gemini) viajan protegidas y se inyectan en RAM automáticamente. ¡Solo descarga y corre!

1. **Clonar o descargar el repositorio:**
   ```bash
   git clone https://github.com/leo-onate/TAG-OK.git
   ```

2. **Ejecutar el instalador interactivo (`setup.bat`):**
   Abre la carpeta `Producto` y haz doble clic en el archivo `setup.bat`. 
   Este asistente inteligente:
   - Descargará todas las dependencias necesarias de Flutter (tanto para `tag_ok` como para `admin`).
   - Te desplegará un **Menú Interactivo**.
   - Te permitirá elegir qué aplicación quieres encender (App Móvil o Backoffice Admin) y en qué plataforma (Windows Desktop o Chrome).
   
   ¡Simplemente escribe un número del 1 al 5 y la magia sucederá sola!

---

<a id="stack-tecnologico" name="stack-tecnologico"></a>
## 🛠️ Stack Tecnológico

| Componente | Tecnología |
| :--- | :--- |
| **Framework Base** | Flutter (Multiplataforma) |
| **Base de Datos** | Firebase Cloud Firestore |
| **Autenticación** | Firebase Auth (Persistencia Nativa) |
| **Mapas** | Flutter Map + Mapbox API |
| **Inteligencia Artificial**| Google Gemini API (`google_generative_ai`) |
| **Procesamiento de Archivos**| `file_picker`, `syncfusion_flutter_pdf`, `csv` |

---

<a id="estructura-proyecto" name="estructura-proyecto"></a>
## 📂 Estructura del Repositorio

```bash
TAG-OK/
├── Producto/
│   ├── setup.bat         # 🚀 ASISTENTE DE EJECUCIÓN (Ejecutar este archivo)
│   ├── tag_ok/           # Código fuente de la Aplicación Móvil
│   ├── admin/            # Código fuente del Panel de Administración
│   └── Base de datos/    # Esquemas, reportes y JSON de Firestore
├── Documentacion/        # Manuales y Mockups
└── Gestion/              # Trello, Cronogramas y Backlogs
```

---
*Desarrollado con ❤️ para transformar las autopistas concesionadas en Chile.*
