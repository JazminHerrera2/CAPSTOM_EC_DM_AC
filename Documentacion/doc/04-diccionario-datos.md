# Diccionario de Datos — TAG OK Fase 2

Modelo de datos completo (Firebase/Firestore), basado en el modelo relacional acordado. Incluye entidades heredadas de Fase 1 y las nuevas de Fase 2.

TAG OK – Fase 2 | Diccionario de Datos

Diccionario de Datos

**Proyecto TAG OK – Fase 2**

Basado en el modelo relacional integrado de TAG OK (Fase 1 + Fase 2)

| Nota: los ejemplos incluidos son ilustrativos y sirven para facilitar la comprensión del diccionario. Los tipos SQL son referenciales; en Firebase/Firestore se adaptan a String, Number, Timestamp, Boolean, GeoPoint, ID de documento o DocumentReference según corresponda. |
| --- |

# Convenciones

| **Sigla** | **Significado** |
| --- | --- |
| PK | Clave primaria |
| FK | Clave foránea |
| UQ | Valor único |
| NN | Campo obligatorio |
| NULL | Campo opcional |

# USUARIOS

Contiene la información general de los usuarios registrados en la aplicación.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **usuario_id** | VARCHAR(24) | PK | NN | Identificador único del usuario. Se relaciona conceptualmente con el UID de Firebase Authentication. | usr_8f31c2 |
| **nombre** | VARCHAR(100) | — | NN | Nombre del usuario. | Camila Rojas |
| **email** | VARCHAR(100) | UQ | NN | Correo electrónico asociado a la cuenta. | camila.rojas@example.com |
| **rol** | VARCHAR(20) | — | NN | Tipo de usuario dentro del sistema. | usuario |
| **fecha_creacion** | DATETIME | — | NN | Fecha y hora en que se creó el registro del usuario. | 2026-09-11 14:30 |
| **ultimo_acceso** | DATETIME | — | NULL | Fecha y hora del último acceso registrado, si se decide conservarla. | 2026-09-11 18:05 |
| **estado** | VARCHAR(20) | — | NN | Estado actual del usuario dentro del sistema. | activo |

Nota específica: la contraseña no se almacena en esta tabla, ya que la autenticación es responsabilidad de Firebase Authentication.

# VEHICULOS

Almacena los vehículos registrados por cada usuario y funciona como entidad central de los nuevos módulos de la Fase 2.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **vehiculo_id** | VARCHAR(24) | PK | NN | Identificador único del vehículo. | veh_a91d7e |
| **usuario_id** | VARCHAR(24) | FK → USUARIOS | NN | Usuario propietario del vehículo. | usr_8f31c2 |
| **patente** | VARCHAR(20) | UQ | NN | Patente del vehículo. | ABCD12 |
| **marca** | VARCHAR(50) | — | NN | Marca del vehículo. | Mazda |
| **modelo** | VARCHAR(50) | — | NN | Modelo del vehículo. | CX-5 |
| **anio** | INT | — | NN | Año del vehículo. | 2022 |
| **tipo_vehiculo** | VARCHAR(50) | — | NN | Clasificación general del vehículo. | SUV |
| **tipo_combustible** | VARCHAR(50) | — | NN | Tipo de combustible o energía utilizada. | Gasolina 95 |
| **kilometraje_actual** | INT | — | NULL | Último kilometraje registrado para el vehículo. | 78500 |
| **alias** | VARCHAR(50) | — | NULL | Nombre personalizado asignado por el usuario. | Mi Auto |
| **foto_path** | VARCHAR(255) | — | NULL | Ruta o referencia a la fotografía almacenada en Firebase Storage. | vehiculos/veh_a91d7e/foto.jpg |
| **fecha_registro** | DATETIME | — | NN | Fecha y hora de incorporación del vehículo al sistema. | 2026-09-11 14:45 |
| **estado** | VARCHAR(20) | — | NN | Estado del vehículo dentro del sistema. | activo |

# VIAJES_TAG

Representa los viajes TAG heredados de la Fase 1 y utilizados por el nuevo dashboard integrado.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **viaje_id** | VARCHAR(24) | PK | NN | Identificador único del viaje TAG. | via_2048af |
| **usuario_id** | VARCHAR(24) | FK → USUARIOS | NN | Usuario asociado al viaje. | usr_8f31c2 |
| **vehiculo_id** | VARCHAR(24) | FK → VEHICULOS | NN | Vehículo utilizado durante el viaje. | veh_a91d7e |
| **fecha** | DATETIME | — | NN | Fecha y hora del viaje. | 2026-09-10 08:15 |
| **costo_total** | DECIMAL(10,2) | — | NN | Costo total asociado al uso de TAG en el viaje. | $6.840 |
| **distancia_km** | DECIMAL(10,2) | — | NULL | Distancia recorrida en kilómetros. | 24,6 km |
| **duracion_min** | INT | — | NULL | Duración estimada o registrada del viaje en minutos. | 38 |

# PORTICOS

Representa los pórticos o puntos de cobro TAG heredados de la Fase 1, utilizados para identificar el punto de cobro, su ubicación y concesionaria.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **portico_id** | VARCHAR(24) | PK | NN | Identificador único del pórtico TAG. | por_001 |
| **nombre** | VARCHAR(100) | — | NN | Nombre del pórtico o punto de cobro. | Costanera Norte - Pórtico 3 |
| **ubicacion** | VARCHAR(100) | — | NULL | Descripción general de la ubicación del pórtico. | Av. Kennedy, Santiago |
| **ruta** | VARCHAR(50) | — | NULL | Ruta o autopista a la que pertenece el pórtico. | Costanera Norte |
| **latitud** | DECIMAL(10,6) | — | NULL | Coordenada de latitud del pórtico. | -33.407214 |
| **longitud** | DECIMAL(10,6) | — | NULL | Coordenada de longitud del pórtico. | -70.575483 |
| **concesionaria** | VARCHAR(100) | — | NULL | Empresa concesionaria responsable del pórtico. | Sociedad Concesionaria Costanera Norte |
| **estado** | VARCHAR(20) | — | NN | Estado del pórtico dentro del sistema. | activo |

Nota específica: PORTICOS corresponde a información heredada de la Fase 1 y se mantiene para conservar la lógica de cálculo y trazabilidad de los viajes TAG.

# TARIFAS_TAG

Almacena las tarifas asociadas a los pórticos TAG de la Fase 1, permitiendo diferenciar valores por tipo de vehículo y periodo de vigencia.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **tarifa_id** | VARCHAR(24) | PK | NN | Identificador único de la tarifa TAG. | tar_001 |
| **portico_id** | VARCHAR(24) | FK → PORTICOS | NN | Pórtico al que se aplica la tarifa. | por_001 |
| **tipo_vehiculo** | VARCHAR(30) | — | NN | Tipo o categoría de vehículo a la que corresponde la tarifa. | liviano |
| **valor_tarifa** | DECIMAL(10,2) | — | NN | Valor monetario aplicado al paso por el pórtico. | $1.250 |
| **fecha_inicio** | DATE | — | NULL | Fecha desde la que comienza a regir la tarifa. | 2026-01-01 |
| **fecha_fin** | DATE | — | NULL | Fecha de término de vigencia de la tarifa, si corresponde. | 2026-12-31 |
| **estado** | VARCHAR(20) | — | NN | Estado actual de la tarifa dentro del sistema. | activa |

Nota específica: TARIFAS_TAG se relaciona con PORTICOS mediante portico_id y corresponde a una entidad heredada de la Fase 1.

# DOCUMENTOS_VEHICULARES

Almacena los documentos asociados a cada vehículo, como SOAP, Revisión Técnica, Permiso de Circulación y seguro automotriz.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **documento_id** | VARCHAR(24) | PK | NN | Identificador único del documento vehicular. | doc_45f8a1 |
| **vehiculo_id** | VARCHAR(24) | FK → VEHICULOS | NN | Vehículo al que pertenece el documento. | veh_a91d7e |
| **tipo_documento** | VARCHAR(50) | — | NN | Tipo de documento registrado. | SOAP |
| **numero** | VARCHAR(50) | — | NULL | Número identificador del documento, si está disponible. | SOAP-2027-004589 |
| **fecha_emision** | DATE | — | NULL | Fecha de emisión del documento. | 2026-03-01 |
| **fecha_vencimiento** | DATE | — | NULL | Fecha de vencimiento utilizada para alertas y recordatorios. | 2027-03-31 |
| **compania** | VARCHAR(100) | — | NULL | Compañía o entidad emisora, cuando corresponda. | HDI Seguros |
| **numero_poliza** | VARCHAR(50) | — | NULL | Número de póliza, cuando corresponda. | POL-984512 |
| **archivo_path** | VARCHAR(255) | — | NULL | Ruta del archivo original almacenado en Firebase Storage. | documentos/veh_a91d7e/soap_2027.pdf |
| **origen_registro** | VARCHAR(20) | — | NN | Indica si el registro fue ingresado manualmente o mediante IA. | ia |
| **fecha_captura** | DATETIME | — | NULL | Fecha y hora en que se realizó la captura utilizada por IA. | 2026-09-11 15:02 |
| **confianza_ia** | DECIMAL(5,2) | — | NULL | Nivel de confianza informado por el proceso de IA. | 0,94 |
| **fecha_registro** | DATETIME | — | NN | Fecha y hora en que el usuario confirmó y almacenó el documento. | 2026-09-11 15:05 |

Nota específica: fecha_captura y confianza_ia pueden quedar vacíos cuando el registro se realiza manualmente.

# MANTENCIONES

Registra el historial de mantenciones realizadas a cada vehículo y permite programar próximas intervenciones.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **mantencion_id** | VARCHAR(24) | PK | NN | Identificador único de la mantención. | man_7c921e |
| **vehiculo_id** | VARCHAR(24) | FK → VEHICULOS | NN | Vehículo asociado a la mantención. | veh_a91d7e |
| **fecha** | DATE | — | NN | Fecha de realización de la mantención. | 2026-08-15 |
| **kilometraje** | INT | — | NULL | Kilometraje registrado al momento del servicio. | 78500 |
| **tipo** | VARCHAR(50) | — | NN | Tipo o categoría de mantención realizada. | Cambio de aceite |
| **taller** | VARCHAR(100) | — | NULL | Taller o proveedor donde se realizó el servicio. | Taller Central |
| **costo** | DECIMAL(10,2) | — | NULL | Costo total de la mantención. | $129.900 |
| **descripcion** | TEXT | — | NULL | Descripción general del trabajo realizado. | Cambio de aceite y revisión general |
| **observaciones** | TEXT | — | NULL | Información adicional o comentarios sobre la mantención. | Revisar frenos en próxima visita |
| **proxima_fecha** | DATE | — | NULL | Fecha estimada para la próxima mantención. | 2027-02-15 |
| **proximo_kilometraje** | INT | — | NULL | Kilometraje recomendado para la próxima mantención. | 88500 |
| **origen_registro** | VARCHAR(20) | — | NN | Indica si el registro fue manual o generado con apoyo de IA. | ia |
| **fecha_captura** | DATETIME | — | NULL | Fecha y hora de captura de la boleta o factura procesada por IA. | 2026-08-15 12:40 |
| **confianza_ia** | DECIMAL(5,2) | — | NULL | Nivel de confianza de la extracción automática. | 0,91 |

Nota específica: fecha_captura y confianza_ia pueden quedar vacíos cuando el registro se realiza manualmente.

# ESTACIONAMIENTOS

Registra el uso y gasto de estacionamientos asociados a un vehículo.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **estacionamiento_id** | VARCHAR(24) | PK | NN | Identificador único del registro de estacionamiento. | est_52be71 |
| **vehiculo_id** | VARCHAR(24) | FK → VEHICULOS | NN | Vehículo estacionado. | veh_a91d7e |
| **fecha** | DATE | — | NN | Fecha del estacionamiento. | 2026-09-11 |
| **lugar** | VARCHAR(100) | — | NULL | Nombre o descripción del lugar de estacionamiento. | Costanera Center |
| **hora_entrada** | TIME | — | NULL | Hora de inicio del estacionamiento. | 10:30 |
| **hora_salida** | TIME | — | NULL | Hora de término del estacionamiento. | 12:05 |
| **duracion_min** | INT | — | NULL | Duración total del estacionamiento en minutos. | 95 |
| **costo** | DECIMAL(10,2) | — | NULL | Costo total del estacionamiento. | $3.500 |
| **ubicacion** | VARCHAR(100) / GeoPoint | — | NULL | Ubicación GPS donde quedó estacionado el vehículo. | GeoPoint(-33.45, -70.66) |
| **observacion** | TEXT | — | NULL | Información adicional ingresada por el usuario. | Nivel -2, sector B |
| **estado** | VARCHAR(20) | — | NN | Estado del estacionamiento, útil para el cronómetro. | finalizado |
| **origen_registro** | VARCHAR(20) | — | NN | Indica si el registro fue manual o mediante IA. | manual |
| **fecha_captura** | DATETIME | — | NULL | Fecha y hora de captura del ticket o boleta, si aplica. | NULL |
| **confianza_ia** | DECIMAL(5,2) | — | NULL | Nivel de confianza de la información extraída por IA, si aplica. | NULL |

Nota específica: fecha_captura y confianza_ia pueden quedar vacíos cuando el registro se realiza manualmente.

# ABASTECIMIENTOS

Almacena los registros de combustible y deja preparada la estructura para futuras cargas de vehículos eléctricos.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **abastecimiento_id** | VARCHAR(24) | PK | NN | Identificador único del abastecimiento. | aba_61d0f4 |
| **vehiculo_id** | VARCHAR(24) | FK → VEHICULOS | NN | Vehículo asociado al abastecimiento. | veh_a91d7e |
| **fecha** | DATE | — | NULL | Fecha del abastecimiento. | 2026-09-10 |
| **kilometraje** | INT | — | NULL | Kilometraje del vehículo al momento de la carga. | 78500 |
| **estacion_servicio** | VARCHAR(100) | — | NULL | Estación o lugar donde se realizó el abastecimiento. | Copec |
| **tipo_abastecimiento** | VARCHAR(30) | — | NULL | Tipo de abastecimiento registrado. | combustible |
| **tipo_combustible** | VARCHAR(50) | — | NULL | Tipo de combustible utilizado, cuando corresponda. | Gasolina 95 |
| **cantidad** | DECIMAL(10,2) | — | NULL | Cantidad abastecida. | 34,8 |
| **unidad** | VARCHAR(20) | — | NULL | Unidad de medida utilizada para la cantidad. | litros |
| **precio_unitario** | DECIMAL(10,2) | — | NULL | Precio por unidad del abastecimiento. | $1.298 |
| **total** | DECIMAL(10,2) | — | NULL | Importe total pagado. | $45.170 |
| **origen_registro** | VARCHAR(20) | — | NN | Indica si el registro fue manual o mediante IA. | ia |
| **fecha_captura** | DATETIME | — | NULL | Fecha y hora de captura de la boleta utilizada por IA. | 2026-09-10 19:22 |
| **confianza_ia** | DECIMAL(5,2) | — | NULL | Nivel de confianza del reconocimiento automático. | 0,96 |

Nota específica: fecha_captura y confianza_ia pueden quedar vacíos cuando el registro se realiza manualmente.

# NOTIFICACIONES

Almacena los avisos y recordatorios destinados a los usuarios.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **notificacion_id** | VARCHAR(24) | PK | NN | Identificador único de la notificación. | not_3ad451 |
| **usuario_id** | VARCHAR(24) | FK → USUARIOS | NN | Usuario que recibe la notificación. | usr_8f31c2 |
| **vehiculo_id** | VARCHAR(24) | FK → VEHICULOS | NULL | Vehículo relacionado con la notificación, cuando corresponda. | veh_a91d7e |
| **tipo** | VARCHAR(50) | — | NN | Tipo de alerta generada por el sistema. | vencimiento_documento |
| **referencia_id** | VARCHAR(24) | Referencia lógica | NULL | ID del documento, mantención u otro registro que originó la alerta. | doc_45f8a1 |
| **mensaje** | TEXT | — | NN | Contenido de la notificación mostrada al usuario. | Tu SOAP vence en 15 días |
| **fecha_programada** | DATETIME | — | NULL | Fecha y hora prevista para mostrar o enviar la alerta. | 2027-03-16 09:00 |
| **fecha_generacion** | DATETIME | — | NN | Fecha y hora en que se generó la notificación. | 2027-03-16 08:55 |
| **leida** | BOOLEAN | — | NN | Indica si el usuario ya revisó la notificación. | false |
| **estado** | VARCHAR(20) | — | NN | Estado actual de la notificación. | pendiente |

Nota específica: vehiculo_id es opcional porque algunas notificaciones, como las asociadas a beneficios, pueden no depender de un vehículo concreto.

# BENEFICIOS

Contiene el catálogo general de beneficios disponibles para los conductores.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **beneficio_id** | VARCHAR(24) | PK | NN | Identificador único del beneficio. | ben_7ef203 |
| **categoria** | VARCHAR(50) | — | NN | Categoría a la que pertenece el beneficio. | Mantención |
| **comercio** | VARCHAR(100) | — | NN | Comercio o proveedor asociado al beneficio. | Taller MotorPro |
| **imagen_path** | VARCHAR(255) | — | NULL | Ruta de la imagen representativa del beneficio. | beneficios/ben_7ef203/banner.jpg |
| **ubicacion** | VARCHAR(100) / GeoPoint | — | NULL | Ubicación donde aplica el beneficio, cuando corresponda. | Providencia, Santiago |
| **fecha_inicio** | DATE | — | NULL | Fecha de inicio de vigencia del beneficio. | 2026-09-01 |
| **fecha_fin** | DATE | — | NULL | Fecha de término de vigencia del beneficio. | 2026-12-31 |
| **condiciones** | TEXT | — | NULL | Condiciones necesarias para utilizar el beneficio. | 10% de descuento presentando la app |
| **destacado** | BOOLEAN | — | NN | Indica si debe mostrarse como beneficio destacado. | true |
| **activo** | BOOLEAN | — | NN | Indica si el beneficio está actualmente disponible. | true |

Nota específica: BENEFICIOS funciona como catálogo global y no posee una FK directa hacia USUARIOS o VEHICULOS en el modelo principal.

# AUDITORIA

Mantiene la trazabilidad de acciones relevantes realizadas dentro del sistema.

| **Campo** | **Tipo referencial** | **Restricción** | **Obligatoriedad** | **Descripción** | **Ejemplo** |
| --- | --- | --- | --- | --- | --- |
| **auditoria_id** | VARCHAR(24) | PK | NN | Identificador único del evento de auditoría. | aud_0f9b22 |
| **usuario_id** | VARCHAR(24) | FK → USUARIOS | NULL | Usuario responsable de la acción, cuando corresponda. | usr_8f31c2 |
| **accion** | VARCHAR(50) | — | NN | Acción realizada sobre un registro. | CREAR |
| **tipo_entidad** | VARCHAR(50) | — | NN | Tipo de entidad sobre la cual se realizó la operación. | DOCUMENTO_VEHICULAR |
| **entidad_id** | VARCHAR(24) | Referencia lógica | NN | Identificador del registro afectado. | doc_45f8a1 |
| **detalle** | TEXT | — | NULL | Información complementaria sobre la operación registrada. | Documento confirmado después de revisión |
| **origen** | VARCHAR(30) | — | NN | Origen de la acción realizada. | ia |
| **fecha** | DATETIME | — | NN | Fecha y hora en que ocurrió el evento de auditoría. | 2026-09-11 15:05 |

Nota específica: entidad_id se interpreta junto con tipo_entidad; es una referencia lógica transversal y no una FK tradicional hacia una única tabla.

# Equivalencia referencial con Firebase/Firestore

Los tipos utilizados en este diccionario corresponden a una representación relacional de documentación. La implementación física se adapta al modelo documental de Firebase/Firestore.

| **Modelo relacional** | **Firebase/Firestore** |
| --- | --- |
| VARCHAR / TEXT | String |
| INT / DECIMAL | Number |
| DATE / DATETIME / TIMESTAMP | Timestamp |
| BOOLEAN | Boolean |
| Ubicación GPS | GeoPoint |
| PK | ID del documento |
| FK | ID relacionado o DocumentReference |
| archivo_path | Ruta o referencia hacia Firebase Storage |

*Criterio de elaboración: el diccionario se construye a partir del modelo relacional acordado para TAG OK – Fase 2. Los valores de la columna “Ejemplo” son ilustrativos y no corresponden a datos reales de usuarios.*

Diccionario de Datos – Modelo Relacional

Página