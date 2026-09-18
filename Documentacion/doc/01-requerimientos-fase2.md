# Requerimientos funcionales y no funcionales — TAG OK Fase 2

55 RF + 12 RNF, organizados por módulo. Fuente: Lista de requerimientos funcionales y no funcionales del proyecto.

**Lista de requerimientos funcionales y no funcionales**
**TAG FASE 2**

Dividida por módulos según la presentación Proyecto TAG Fase 2

**Módulo 1: Mi Vehículo**

| **N°** | **Nombre del Requerimiento** | **Tipo de Requerimiento** | **Actores Relacionados** | **Descripción Corta del Requerimiento** | **Criterios de Aceptación** | **Estado** |
| --- | --- | --- | --- | --- | --- | --- |
| RF-001 | Registrar vehículo | Funcional | Usuario/Sistema | Permite registrar uno o más vehículos con patente, marca, modelo, año, tipo de vehículo y combustible. | El vehículo se registra con la información indicada y queda disponible en la ficha del usuario. | Por definir |
| RF-002 | Mantener información del vehículo | Funcional | Usuario/Sistema | Permite mantener kilometraje actual, alias y fotografía opcional del vehículo. | El usuario puede ingresar o modificar kilometraje y alias, y agregar una fotografía opcional. | Por definir |
| RF-003 | Gestionar documentos del vehículo | Funcional | Usuario/Sistema | Permite gestionar Permiso de Circulación, Revisión Técnica, SOAP y seguro automotriz. | El usuario puede registrar y visualizar los documentos asociados al vehículo. | Por definir |
| RF-004 | Configurar vencimientos de documentos | Funcional | Usuario/ Sistema | Permite configurar vencimientos de documentos y notificaciones preventivas. | El sistema conserva la fecha de vencimiento y genera la notificación preventiva correspondiente. | Por definir |
| RF-005 | Visualizar estado general del vehículo | Funcional | Usuario/ Sistema | Permite visualizar el estado general como “Todo al día”, “Atención requerida” o “Próximo vencimiento”. | El estado mostrado corresponde a la situación de los documentos y vencimientos registrados. | Por definir |
| RF-006 | Registrar documento vehicular con IA | Funcional | Usuario/ IA/ Sistema | Permite fotografiar un documento o cargar un archivo para que la IA identifique su tipo y extraiga información(patente,fechas,compañía,número de póliza). | La IA identifica el tipo de documento y precarga los datos disponibles para revisión. | Por definir |
| RF-007 | Extraer datos de documentos vehiculares | Funcional | IA/ Sistema | Permite extraer patente, tipo, número, emisión, vencimiento, compañía u otros datos disponibles de Permiso, RT, SOAP y seguro. | Los datos reconocidos se muestran como precarga editable y no se guardan sin confirmación del usuario. | Por definir |
| RF-008 | Confirmación del usuario | Funcional | Usuario/Sistema | El usuario confirma que los datos extraídos , correspondan a su información | El usuario selecciona la opción aceptar, , y el sistema  guarda la información. | Por definir |

**Módulo 2: Mantenciones y cuidado del vehículo**

| **N°** | **Nombre del Requerimiento** | **Tipo de Requerimiento** | **Actores Relacionados** | **Descripción Corta del Requerimiento** | **Criterios de Aceptación** | **Estado** |
| --- | --- | --- | --- | --- | --- | --- |
| RF-009 | Registrar mantención | Funcional | Usuario/sistema | Permite registrar fecha, kilometraje, tipo, taller, costo, descripción y observaciones de una mantención. | La mantención queda registrada con los datos ingresados y asociada al vehículo correspondiente. | Por definir |
| RF-010 | Visualizar historial de mantenciones | Funcional | Usuario/Sistema | Permite consultar una línea de tiempo cronológica con servicios realizados y documentos asociados. | El historial se presenta ordenado cronológicamente y permite consultar las mantenciones registradas. | Por definir |
| RF-011 | Programar próxima mantención | Funcional | Usuario/ Sistema | Permite programar la próxima mantención por fecha, kilometraje o ambos. | El sistema conserva la programación y permite generar recordatorios según los parámetros configurados. | Por definir |
| RF-012 | Generar recordatorios de mantención | Funcional | Sistema/ Usuario | Permite generar recordatorios asociados a la próxima mantención. | El usuario recibe el recordatorio según la fecha o kilometraje configurado. | Por definir |
| RF-013 | Cargar boleta o factura de taller con IA | Funcional | Usuario/ IA/ Sistema | Permite fotografiar o cargar una boleta/factura para identificar taller, fecha, servicios, repuestos, kilometraje y monto total. | La IA extrae los datos disponibles y los presenta para revisión antes de guardar. | Por definir |
| RF-014 | Confirmación del usuario cargar datos boleta | Funcional | Usuario/Sistema | Permite al usuario visualizar la información extraída por la IA, a través de un formulario rellenado con la información . | La información queda registrada, con los datos previamente  ya confirmados por el usuario, en el sistema | Por definir |
| RF-015 | Clasificar mantención mediante IA | Funcional | IA/ Sistema/ Usuario | Permite clasificar una mantención como preventiva, cambio de aceite, frenos, neumáticos u otra categoría. | La clasificación propuesta por la IA se muestra al usuario y puede ser revisada antes de guardar. | Por definir |

**Módulo 3A: Estacionamientos**

| **N°** | **Nombre del Requerimiento** | **Tipo de Requerimiento** | **Actores Relacionados** | **Descripción Corta del Requerimiento** | **Criterios de Aceptación** | **Estado** |
| --- | --- | --- | --- | --- | --- | --- |
| RF-016 | Registrar estacionamiento manualmente | Funcional | Usuario/Sistema | Permite registrar vehículo, fecha, lugar, hora de entrada, hora de salida, costo y observación. | El registro queda asociado al vehículo y conserva los datos ingresados. | Por definir |
| RF-017 | Iniciar estacionamiento | Funcional | Usuario/ Sistema | Permite iniciar un cronómetro mediante la acción “Iniciar estacionamiento”. | El sistema registra el inicio del estacionamiento y comienza a contabilizar la duración. | Por definir |
| RF-018 | Finalizar estacionamiento | Funcional | Usuario/ Sistema | Permite finalizar el cronómetro mediante la acción “Finalizar estacionamiento”. | El sistema registra el término y la duración del estacionamiento. | Por definir |
| RF-019 | Guardar ubicación del vehículo | Funcional | Usuario/ Sistema | Permite guardar la ubicación GPS para recordar dónde quedó estacionado el vehículo. | La ubicación queda asociada al registro y puede ser consultada posteriormente. | Por definir |
| RF-020 | Registrar estacionamiento con IA | Funcional | Usuario/ IA/ Sistema | Permite registrar un estacionamiento mediante fotografía de un ticket o boleta. | La IA extrae estacionamiento, ubicación, fecha, entrada, salida, duración y monto cuando estén disponibles. | Por definir |
| RF-021 | Editar datos faltantes del ticket | Funcional | Usuario | Permite editar los datos que la IA no haya podido identificar. | Los campos faltantes quedan editables y el usuario puede completarlos antes de guardar. | Por definir |
| RF-022 | Confirmar registro de estacionamiento | Funcional | Usuario/ Sistema | Requiere una confirmación explícita antes de guardar un registro obtenido mediante IA. | El registro solo se guarda después de que el usuario revise y seleccione la acción de confirmación. | Por definir |

**Módulo 3B: Combustible y carga**

| **N°** | **Nombre del Requerimiento** | **Tipo de Requerimiento** | **Actores Relacionados** | **Descripción Corta del Requerimiento** | **Criterios de Aceptación** | **Estado** |
| --- | --- | --- | --- | --- | --- | --- |
| RF-023 | Registrar abastecimiento | Funcional | Usuario/Sistema | Permite registrar fecha, kilometraje, estación de servicio, tipo de combustible, litros, precio por litro y total. | El abastecimiento queda registrado con los datos disponibles. | Por definir |
| RF-024 | Permitir registros parciales de combustible | Funcional | Usuario/ Sistema | Permite registrar un abastecimiento sin obligar al usuario a completar todos los campos. | El sistema permite guardar el registro con los campos necesarios disponibles y sin exigir información no requerida. | Por definir |
| RF-025 | Visualizar historial y gasto de combustible | Funcional | Usuario/ Sistema | Permite mostrar el historial de abastecimientos y el gasto mensual en combustible por vehículo. | El usuario puede consultar los registros y visualizar el gasto mensual correspondiente. | Por definir |
| RF-026 | Preparar soporte para vehículos híbridos y eléctricos | Funcional | Sistema | Deja preparada la estructura de registro para vehículos híbridos y eléctricos. | La estructura permite incorporar estos tipos de vehículos y sus registros de carga/abastecimiento sin limitar el modelo actual. | Por definir |
| RF-027 | Registrar combustible mediante IA | Funcional | Usuario/ IA/ Sistema | Permite fotografiar una boleta para reconocer estación, fecha, combustible, litros, precio unitario y total. | La IA extrae los datos disponibles y los muestra como precarga para revisión. | Por definir |
| RF-028 | Corregir datos detectados de combustible | Funcional | Usuario/Sistema | Permite revisar y corregir los datos reconocidos por la IA antes de guardar. | El usuario puede modificar los datos detectados y confirmar el registro. | Por definir |
| RF-029 | Confirmar y guardar combustible | Funcional | Usuario/ Sistema | Permite confirmar y guardar el registro de combustible después de la revisión. | El registro se guarda únicamente después de la confirmación del usuario. | Por definir |

**Módulo 4: Beneficios para conductores**

| **N°** | **Nombre del Requerimiento** | **Tipo de Requerimiento** | **Actores Relacionados** | **Descripción Corta del Requerimiento** | **Criterios de Aceptación** | **Estado** |
| --- | --- | --- | --- | --- | --- | --- |
| RF-030 | Visualizar catálogo de beneficios | Funcional | Usuario/ Sistema | Permite consultar un catálogo de beneficios para conductores. | Los beneficios activos y vigentes se muestran en la aplicación. | Por definir |
| RF-031 | Administrar beneficios | Funcional | Administrador/ Sistema | Permite crear, editar, activar y desactivar beneficios desde el backoffice. | El administrador puede realizar las acciones de gestión y los cambios se reflejan en el catálogo. | Por definir |
| RF-032 | Configurar información del beneficio | Funcional | Administrador/Sistema | Permite definir categoría, comercio, imagen, ubicación, vigencia, condiciones y destacado. | El beneficio queda almacenado con la información administrativa configurada. | Por definir |
| RF-033 | Filtrar beneficios | Funcional | Usuario/ Sistema | Permite filtrar beneficios por categoría, ubicación y vigencia. | El sistema muestra los beneficios que cumplen con los filtros seleccionados. | Por definir |
| RF-034 | Clasificar beneficios por categoría | Funcional | Administrador/ Sistema | Permite asociar cada beneficio a una categoría disponible, como Combustible, Talleres, Mantenciones, Estacionamientos, Lavado, Neumáticos, Seguros o Accesorios. | El administrador puede asociar un beneficio a una categoría y esta información se utiliza posteriormente para su visualización y filtrado. | Por definir |

**Componente transversal: Registro inteligente con IA**

| **N°** | **Nombre del Requerimiento** | **Tipo de Requerimiento** | **Actores Relacionados** | **Descripción Corta del Requerimiento** | **Criterios de Aceptación** | **Estado** |
| --- | --- | --- | --- | --- | --- | --- |
| RF-035 | Capturar documento o evidencia | Funcional | Usuario/ Sistema | Permite tomar una fotografía mediante cámara o cargar un archivo como fuente de registro. | El sistema recibe la imagen o archivo y permite continuar con el flujo inteligente. | Por definir |
| RF-036 | Identificar tipo de documento | Funcional | IA/ Sistema | Permite identificar el tipo de documento o evidencia ingresada. | El sistema determina el tipo cuando la IA logra reconocerlo y dirige el registro al módulo correspondiente. | Por definir |
| RF-037 | Extraer campos relevantes | Funcional | IA/ Sistema | Permite extraer los campos relevantes según el tipo de documento. | La información reconocida se presenta como precarga y no se persiste automáticamente. | Por definir |
| RF-038 | Validar información detectada | Funcional | Usuario/ Sistema | Permite que el usuario revise los datos detectados por la IA en una pantalla de revisión. | Los campos son editables y el usuario puede corregir información antes de guardar. | Por definir |
| RF-039 | Guardar en el módulo correcto | Funcional | Usuario/ Sistema | Permite guardar la información validada en el módulo correspondiente. | El registro confirmado se almacena en el destino correcto. | Por definir |
| RF-040 | Permitir ingreso manual como alternativa | Funcional | Usuario/ Sistema | Permite completar los registros de forma tradicional cuando la captura o extracción mediante IA falla. | El usuario puede ingresar manualmente la información sin depender de la IA. | Por definir |
| RF-041 | Gestionar campos no reconocidos | Funcional | IA/ Sistema/ Usuario | Permite dejar vacío un campo que la IA no pueda reconocer, sin inventar información. | El sistema no genera valores ficticios y deja el campo disponible para edición manual. | Por definir |
| RF-042 | Registrar trazabilidad de captura | Funcional | Sistema | Permite registrar el origen y la fecha de la captura para trazabilidad. | Cada registro inteligente conserva su origen y fecha de captura. | Por definir |
| RF-043 | Mostrar confianza de la IA | Funcional | IA/ Sistema/ Usuario | Permite resaltar campos dudosos o incompletos para indicar al usuario qué debe revisar. | Los campos identificados como dudosos o incompletos quedan destacados durante la validación. | Por definir |

**Dashboard integrado: Mi auto**

| **N°** | **Nombre del Requerimiento** | **Tipo de Requerimiento** | **Actores Relacionados** | **Descripción Corta del Requerimiento** | **Criterios de Aceptación** | **Estado** |
| --- | --- | --- | --- | --- | --- | --- |
| RF-044 | Visualizar gasto de movilidad mensual | Funcional | Usuario/ Sistema | Permite mostrar el gasto de movilidad del mes consolidando la información disponible. | El dashboard presenta el gasto mensual calculado a partir de los registros correspondientes. | Por definir |
| RF-045 | Visualizar próxima mantención | Funcional | Usuario/ Sistema | Permite mostrar la información de la próxima mantención, incluyendo referencia de kilometraje. | El dashboard muestra la próxima mantención registrada. | Por definir |
| RF-046 | Visualizar próximo vencimiento | Funcional | Usuario/ Sistema | Permite mostrar los días restantes para el próximo vencimiento. | El dashboard presenta el próximo vencimiento de acuerdo con los documentos registrados. | Por definir |
| RF-047 | Visualizar beneficios disponibles | Funcional | Usuario/ Sistema | Permite mostrar la cantidad de beneficios disponibles para el conductor. | El dashboard presenta los beneficios disponibles según la información vigente. | Por definir |
| RF-048 | Visualizar gastos por categoría | Funcional | Usuario/ Sistema | Permite visualizar los gastos mensuales asociados a TAG, combustible, estacionamientos y mantenciones. | El dashboard presenta los montos correspondientes a cada categoría. | Por definir |
| RF-049 | Acceder a acciones rápidas | Funcional | Usuario/ Sistema | Permite acceder rápidamente a Registrar combustible, Registrar estacionamiento, Agregar mantención y Ver beneficios. | Las acciones rápidas dirigen al flujo correspondiente. | Por definir |

**Componentes transversales: Usuarios, Vehículos, Notificaciones, Historial y Auditoría**

| **N°** | **Nombre del Requerimiento** | **Tipo de Requerimiento** | **Actores Relacionados** | **Descripción Corta del Requerimiento** | **Criterios de Aceptación** | **Estado** |
| --- | --- | --- | --- | --- | --- | --- |
| RF-050 | Gestionar usuarios y acceso | Funcional | Usuario/ Sistema | Permite gestionar el acceso de los usuarios a la aplicación y sus funcionalidades. | Solo los usuarios autorizados pueden acceder a la información y funcionalidades correspondientes. | Por definir |
| RF-051 | Asociar información a vehículos | Funcional | Usuario/ Sistema | Permite relacionar documentos, mantenciones, gastos y alertas con el vehículo correspondiente. | La información registrada queda vinculada al vehículo seleccionado. | Por definir |
| RF-052 | Gestionar notificaciones | Funcional | Sistema/ Usuario | Permite generar y entregar notificaciones relacionadas con vencimientos de documentos, próximas mantenciones y beneficios disponibles para el conductor. | El sistema genera las notificaciones correspondientes de acuerdo con los vencimientos, recordatorios y beneficios registrados o vigentes. | Por definir |
| RF-053 | Mantener historial | Funcional | Sistema/ Usuario | Permite conservar historial de servicios, gastos y registros asociados al vehículo. | La información histórica permanece disponible y ordenada para consulta. | Por definir |
| RF-054 | Mantener auditoría y trazabilidad | Funcional | Sistema/ Administrador | Permite mantener registros de trazabilidad sobre las capturas y operaciones relevantes. | El sistema conserva la información necesaria para identificar origen y fecha de las capturas. | Por definir |
| RF-055 | Almacenar respaldo de documento vehicular | Funcional | Usuario/ Sistema | Permite almacenar la imagen o archivo original asociado a documentos permanentes del vehículo, como Permiso de Circulación, Revisión Técnica, SOAP o seguro automotriz. | Una vez confirmado el registro del documento, el respaldo queda asociado al vehículo correspondiente y puede ser consultado posteriormente por el usuario autorizado. | Por definir |

**Requerimientos no funcionales**

| **N°** | **Nombre del Requerimiento** | **Tipo de Requerimiento** | **Actores Relacionados** | **Descripción Corta del Requerimiento** | **Criterios de Aceptación** | **Estado** |
| --- | --- | --- | --- | --- | --- | --- |
| RNF-001 | Control de acceso | No Funcional | Sistema/ Usuarios | El sistema debe aplicar controles de acceso para proteger la información de los usuarios y vehículos. | Solo los usuarios autorizados pueden acceder a la información y funcionalidades que les correspondan. | Por definir |
| RNF-002 | Minimización de datos | No Funcional | Sistema | El sistema debe aplicar el principio de minimización de datos al manejar la información. | Solo se deben gestionar los datos necesarios para las funcionalidades de la Fase 2. | Por definir |
| RNF-003 | Manejo seguro de imágenes y documentos | No Funcional | Sistema | Las imágenes y documentos utilizados por el Registro Inteligente deben manejarse de forma segura. | Los documentos e imágenes deben estar protegidos mediante controles de acceso y manejo seguro. | Por definir |
| RNF-004 | Control del usuario sobre la IA | No Funcional | Usuario/ IA/ Sistema | La IA debe proponer, precargar y clasificar información sin reemplazar la decisión del usuario. | Ningún dato detectado por IA se persiste automáticamente sin revisión y confirmación explícita. | Por definir |
| RNF-005 | Validación antes de persistencia | No Funcional | Usuario/ Sistema | Todo flujo inteligente debe finalizar en una pantalla de revisión con campos editables, validaciones y una acción explícita de confirmación. | El sistema impide guardar datos detectados por IA sin que el usuario los revise y confirme. | Por definir |
| RNF-006 | Trazabilidad | No Funcional | Sistema | El sistema debe mantener trazabilidad del origen y fecha de las capturas realizadas. | Cada captura inteligente conserva origen y fecha para poder rastrear el registro. | Por definir |
| RNF-007 | Esquema desacoplado para IA | No Funcional | IA/ Sistema | El sistema debe utilizar un esquema JSON por tipo de documento para desacoplar el motor de IA del front y del modelo de datos. | Los tipos de documento pueden utilizar estructuras de extracción definidas sin acoplar directamente el motor de IA a la interfaz o modelo de datos. | Por definir |
| RNF-008 | Usabilidad | No Funcional | Usuario/ Sistema | La aplicación deberá facilitar el registro y consulta de información, reduciendo el ingreso manual de datos y presentando flujos claros para el usuario. | Los flujos de captura inteligente presentan la información precargada en formularios editables y permiten al usuario revisar, corregir y confirmar los datos antes de guardarlos. | Por definir |
| RNF-009 | Operación en línea | No Funcional | Usuario/ Sistema | La aplicación estará diseñada para operar mediante conexión a Internet y utilizar los servicios necesarios para consultar, procesar y almacenar información. | Las funcionalidades que requieren servicios externos, procesamiento mediante IA o acceso a información almacenada operan correctamente cuando existe conexión a Internet. | Por definir |
| RNF-010 | Tiempo de respuesta del procesamiento IA | No Funcional | IA/ Sistema/ Usuario | El sistema debe procesar y devolver la precarga de datos extraídos por IA dentro de un tiempo máximo aceptable para no interrumpir el flujo del usuario. | El tiempo entre la captura (foto/archivo) y la presentación de la precarga editable no supera 15 segundos en condiciones normales de conexión. | Por definir |
| RNF-011 | Disponibilidad y comportamiento ante falla del servicio de IA | No Funciona | Sistema/ Usuario | El sistema debe manejar de forma controlada los casos en que el servicio de IA no responde o responde con error. | Si la IA no está disponible o falla, el sistema informa al usuario y ofrece el ingreso manual (RF-040) sin bloquear el flujo. | Por definir |
| RNF-012 | Cumplimiento normativo de datos personales | No Funciona | Sistema/ Administrador | El manejo de documentos e imágenes con datos personales (patente, pólizas, datos del conductor) debe alinearse con la normativa chilena de protección de datos personales. | El tratamiento, almacenamiento y acceso a los datos personales cumple con los principios exigidos por la ley vigente (consentimiento, finalidad, minimización, seguridad). | Por definir |