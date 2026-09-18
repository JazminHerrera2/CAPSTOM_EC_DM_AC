# Casos de Uso — TAG OK Fase 2

50 plantillas de CU completas (CU1 a CU50): actores, precondición, descripción, secuencia paso a paso, postcondición, excepciones y requerimientos asociados.

| **CU1** | Registrar vehículo |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe encontrarse autenticado en TAG OK. |
| **Descripción** | Permite al conductor registrar uno o más vehículos asociados a su cuenta, ingresando patente, marca, modelo, año, tipo de vehículo y combustible. |
| **Secuencia** | El conductor ingresa al módulo Mi Vehículo. El conductor selecciona la opción para registrar un vehículo. El sistema muestra el formulario de registro. El conductor ingresa los datos solicitados del vehículo. El conductor confirma el registro. El sistema valida la información ingresada. El sistema registra el vehículo y lo asocia a la cuenta del conductor. El sistema muestra el vehículo dentro de Mi Vehículo. |
| **Postcondición** | El vehículo queda registrado y disponible en la ficha del usuario. |
| **Excepción** | **E1:** Si existen campos obligatorios sin completar, el sistema informa al conductor y solicita completar la información. **E2:** Si los datos ingresados no son válidos, el sistema solicita su corrección. **E3:** Si el vehículo no puede ser registrado, el sistema informa que ocurrió un error y no guarda el registro. |
| **Requerimientos asociados** | RF-001 |

| **CU2** | Modificar información |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y tener al menos un vehículo registrado. |
| **Descripción** | Permite mantener y modificar información del vehículo, incluyendo kilometraje actual, alias y fotografía opcional. |
| **Secuencia** | El conductor ingresa a Mi Vehículo. Selecciona el vehículo que desea modificar. El sistema muestra la información registrada. El conductor selecciona la opción de edición. El conductor modifica la información disponible. El conductor confirma los cambios. El sistema valida la información. El sistema actualiza los datos del vehículo. |
| **Postcondición** | La información modificada queda actualizada y asociada al vehículo seleccionado. |
| **Excepción** | **E1:** Si algún dato ingresado no es válido, el sistema solicita su corrección. **E2:** Si el conductor cancela la modificación, los datos anteriores permanecen sin cambios. **E3:** Si ocurre un error durante la actualización, el sistema no reemplaza la información existente. |
| **Requerimientos asociados** | RF-002 |

| **CU3** | Gestionar documentos |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y tener un vehículo registrado. |
| **Descripción** | Permite registrar y consultar los documentos asociados al vehículo, incluyendo Permiso de Circulación, Revisión Técnica, SOAP y seguro automotriz. |
| **Secuencia** | El conductor ingresa al módulo Mi Vehículo. Selecciona un vehículo. Selecciona la sección Documentos. El sistema muestra los documentos asociados al vehículo. El conductor selecciona el documento que desea consultar o registra uno nuevo. El sistema muestra o solicita la información correspondiente. El conductor completa la información necesaria cuando corresponda. El sistema guarda el documento asociado al vehículo. |
| **Postcondición** | Los documentos registrados quedan asociados al vehículo y disponibles para su posterior consulta. |
| **Excepción** | **E1:** Si no existen documentos registrados, el sistema muestra la sección sin registros. **E2:** Si falta información obligatoria al registrar un documento, el sistema solicita completarla. **E3:** Si el documento no puede guardarse, el sistema informa al conductor y no completa el registro. |
| **Requerimientos asociados** | RF-003 **-  **RF-055 / RF-051 |

| **CU4** | Configurar vencimientos |
| --- | --- |
| **Actores** | Conductor. |
| **Precondición** | El conductor debe estar autenticado y disponer de un documento asociado al vehículo. |
| **Descripción** | Permite configurar y conservar las fechas de vencimiento de los documentos del vehículo para generar las notificaciones preventivas correspondientes. |
| **Secuencia** | El conductor ingresa a los documentos de su vehículo. Selecciona el documento correspondiente. Ingresa o modifica su fecha de vencimiento. El conductor confirma la información. El sistema valida la fecha ingresada. El sistema guarda el vencimiento. El sistema utiliza la fecha registrada para generar la notificación preventiva correspondiente. |
| **Postcondición** | La fecha de vencimiento queda asociada al documento y disponible para el sistema de notificaciones. |
| **Excepción** | **E1:** Si la fecha ingresada no es válida, el sistema solicita corregirla. **E2:** Si el conductor cancela la operación, el vencimiento anterior permanece sin cambios. **E3:** Si no es posible guardar la fecha, el sistema informa al conductor. |
| **Requerimientos asociados** | RF-004 |

| **CU5** | Visualizar estado general |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y tener un vehículo registrado. |
| **Descripción** | Permite consultar el estado general del vehículo de acuerdo con sus documentos y vencimientos, mostrando estados como **“Todo al día”**, **“Atención requerida”** o **“Próximo vencimiento”**. |
| **Secuencia** | El conductor ingresa a Mi Vehículo. Selecciona el vehículo que desea consultar. El sistema consulta los documentos y vencimientos registrados. El sistema determina el estado correspondiente. El sistema muestra el estado general del vehículo al conductor. |
| **Postcondición** | El conductor visualiza el estado actualizado del vehículo según la información disponible. |
| **Excepción** | **E1:** Si no existe información suficiente, el sistema no podrá determinar completamente el estado del vehículo. **E2:** Si no existen documentos o vencimientos registrados, el sistema informa la ausencia de información. |
| **Requerimientos asociados** | RF-005 |

| **CU6** | Registrar documento con IA |
| --- | --- |
| **Actores** | Conductor y Gemini API. |
| **Precondición** | El conductor debe estar autenticado, tener un vehículo registrado y disponer de una fotografía o archivo del documento. |
| **Descripción** | Permite fotografiar o cargar un documento vehicular para que la IA identifique su tipo y extraiga los datos disponibles, como patente, fechas, compañía y número de póliza. Los datos se presentan como una precarga editable antes de guardarlos. |
| **Secuencia** | El conductor ingresa a Mi Vehículo. Selecciona la opción para registrar un documento mediante IA. El conductor fotografía el documento o selecciona un archivo. El sistema envía la información para su procesamiento mediante Gemini API. La IA identifica el tipo de documento. La IA extrae los datos reconocibles. El sistema muestra los datos extraídos como una precarga editable. El conductor revisa la información detectada. El flujo continúa hacia Revisar y confirmar datos. |
| **Postcondición** | Los datos detectados quedan disponibles para revisión del conductor, pero todavía no se almacenan definitivamente. |
| **Excepción** | **E1:** Si la IA no reconoce algún campo, este debe quedar disponible para edición manual, sin generar información ficticia. **E2:** Si el procesamiento mediante IA falla, el conductor puede continuar mediante ingreso manual. **E3:** Si determinados datos presentan dudas o están incompletos, el sistema los destaca para su revisión. |
| **Requerimientos asociados** | RF-006 y RF-007 |

| **CU7** | Revisar y confirmar datos |
| --- | --- |
| **Actores** | Conductor. |
| **Precondición** | La IA debe haber procesado el documento y presentado los datos detectados para revisión. |
| **Descripción** | Permite al conductor revisar la información obtenida mediante IA, modificar los datos cuando sea necesario y confirmar explícitamente el registro antes de almacenarlo. |
| **Secuencia** | El sistema muestra al conductor los datos extraídos del documento. El conductor revisa la información. El conductor corrige o completa los campos cuando sea necesario. El conductor selecciona la opción de confirmar. El sistema valida los datos. El sistema guarda la información confirmada. El documento queda asociado al vehículo correspondiente. |
| **Postcondición** | La información confirmada queda almacenada y asociada al vehículo. El documento original también puede conservarse como respaldo una vez confirmado el registro. |
| **Excepción** | **E1:** Si existen datos obligatorios incompletos, el sistema solicita su corrección antes de guardar. **E2:** Si el conductor no confirma la información, los datos detectados por IA no deben persistir automáticamente. **E3:** Si el conductor cancela el proceso, el sistema no completa el registro. |
| **Requerimientos asociados** | RF-008 / RF-051 / RF-055 |

| **CU8** | Registrar mantención |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado en TAG OK y tener un vehículo registrado. |
| **Descripción** | Permite registrar una mantención realizada a un vehículo, indicando fecha, kilometraje, tipo de mantención, taller, costo, descripción y observaciones. |
| **Secuencia** | El conductor ingresa al módulo Mantenciones. Selecciona el vehículo correspondiente. Selecciona la opción Registrar mantención. El sistema muestra el formulario de registro. El conductor ingresa los datos de la mantención. El conductor confirma el registro. El sistema valida la información ingresada. El sistema guarda la mantención. La mantención queda asociada al vehículo seleccionado. |
| **Postcondición** | La mantención queda registrada con los datos ingresados y asociada al vehículo correspondiente. |
| **Excepción** | **E1:** Si faltan datos necesarios, el sistema solicita completar la información. **E2:** Si algún dato ingresado no es válido, el sistema solicita su corrección. **E3:** Si ocurre un error durante el registro, el sistema informa al conductor y no guarda la mantención. |
| **Requerimientos asociados** | RF-009, RF-051 |

| **CU9** | Visualizar historial |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y tener un vehículo registrado. |
| **Descripción** | Permite consultar el historial de mantenciones del vehículo mediante una línea de tiempo cronológica que presenta los servicios realizados y sus documentos asociados. |
| **Secuencia** | El conductor ingresa al módulo Mantenciones. Selecciona el vehículo que desea consultar. Selecciona la opción Historial de mantenciones. El sistema obtiene las mantenciones asociadas al vehículo. El sistema ordena los registros cronológicamente. El sistema muestra las mantenciones y los documentos asociados. El conductor puede consultar la información de las mantenciones registradas. |
| **Postcondición** | El conductor visualiza el historial cronológico de mantenciones del vehículo. |
| **Excepción** | **E1:** Si el vehículo no posee mantenciones registradas, el sistema informa que no existe historial disponible. **E2:** Si no es posible obtener el historial, el sistema informa al conductor que ocurrió un error. |
| **Requerimientos asociados** | RF-010 / RF-053 |

| **CU10** | Programar próxima mantención |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y tener un vehículo registrado. |
| **Descripción** | Permite programar la próxima mantención del vehículo utilizando una fecha, kilometraje o ambos criterios. |
| **Secuencia** | El conductor ingresa al módulo Mantenciones. Selecciona el vehículo correspondiente. Selecciona la opción Programar próxima mantención. El sistema muestra las opciones de programación. El conductor establece una fecha, un kilometraje o ambos. El conductor confirma la programación. El sistema valida la información. El sistema guarda la próxima mantención. La información queda disponible para la generación de recordatorios. |
| **Postcondición** | La próxima mantención queda programada según los parámetros definidos por el conductor. |
| **Excepción** | **E1:** Si no se establece una fecha ni kilometraje, el sistema solicita definir al menos uno. **E2:** Si la información ingresada no es válida, el sistema solicita su corrección. **E3:** Si ocurre un error al guardar, la programación no se completa. |
| **Requerimientos asociados** | RF-011, RF-051 |

| **CU11** | Recibir recordatorio de mantención |
| --- | --- |
| **Actores** | Conductor. |
| **Precondición** | El conductor debe tener un vehículo registrado y una próxima mantención programada por fecha, kilometraje o ambos. |
| **Descripción** | Permite al conductor recibir un recordatorio de acuerdo con la próxima mantención programada . |
| **Secuencia** | El conductor programa previamente una próxima mantención. TAG OK conserva la fecha, kilometraje o ambos parámetros configurados. TAG OK verifica los parámetros establecidos. Cuando se cumple la condición correspondiente, TAG OK genera el recordatorio. El conductor recibe el recordatorio de la próxima mantención. |
| **Postcondición** | El conductor recibe el recordatorio correspondiente a la mantención programada. |
| **Excepción** | **E1:** Si no existe una próxima mantención programada, no se genera el recordatorio. **E2:** Si todavía no se cumple la fecha o kilometraje configurado, no se genera el recordatorio. |
| **Requerimientos asociados** | RF-012 |

| **CU12** | Cargar boleta/factura con IA |
| --- | --- |
| **Actores** | Conductor y Gemini API. |
| **Precondición** | El conductor debe estar autenticado, tener un vehículo registrado y disponer de una fotografía o archivo de la boleta/factura. |
| **Descripción** | Permite fotografiar o cargar una boleta o factura de taller para procesarla mediante IA e identificar información como taller, fecha, servicios, repuestos, kilometraje y monto total. |
| **Secuencia** | El conductor ingresa al módulo Mantenciones. Selecciona la opción para cargar una boleta o factura mediante IA. El conductor fotografía el documento o selecciona un archivo. El sistema envía el documento para su procesamiento mediante Gemini API. La IA analiza el contenido. La IA identifica los datos disponibles de la mantención. El sistema presenta la información detectada al conductor. El conductor continúa al proceso de revisión y confirmación. |
| **Postcondición** | La información detectada queda disponible para ser revisada por el conductor antes de almacenarse. |
| **Excepción** | **E1:** Si la IA no puede reconocer algún campo, este queda disponible para ingreso o corrección manual. **E2:** Si el documento no puede procesarse mediante IA, el conductor puede realizar el registro manualmente. **E3:** Si existen datos dudosos o incompletos, estos deben ser revisados antes de confirmar. |
| **Requerimientos asociados** | RF-013 |

| **CU13** | Revisar y confirmar datos |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | La boleta o factura debe haber sido procesada y sus datos deben encontrarse disponibles para revisión. |
| **Descripción** | Permite al conductor revisar los datos obtenidos de la boleta o factura antes de confirmar su almacenamiento en el sistema. |
| **Secuencia** | El sistema muestra los datos detectados mediante IA. El conductor revisa la información presentada. El conductor corrige o completa la información cuando sea necesario. El conductor confirma los datos. El sistema valida la información confirmada. El sistema guarda la mantención. La información queda asociada al vehículo correspondiente. |
| **Postcondición** | La información de la mantención queda registrada únicamente después de haber sido revisada y confirmada por el conductor. |
| **Excepción** | **E1:** Si existen datos incompletos, el conductor puede completarlos antes de confirmar. **E2:** Si el conductor no confirma los datos, la información detectada mediante IA no se guarda. **E3:** Si el conductor cancela la operación, no se completa el registro. |
| **Requerimientos asociados** | RF-014, RF-051 |

| **CU14** | Clasificar mantención con IA |
| --- | --- |
| **Actores** | Conductor y Gemini API. |
| **Precondición** | Debe existir información de una mantención procesada mediante IA. |
| **Descripción** | Permite que la IA proponga una clasificación para la mantención, pudiendo corresponder a categorías como preventiva, cambio de aceite, frenos, neumáticos u otra categoría. La clasificación puede ser revisada por el conductor antes de guardar. |
| **Secuencia** | La IA analiza la información detectada de la mantención. La IA determina una categoría de mantención según la información disponible. El sistema muestra al conductor la clasificación propuesta. El conductor revisa la clasificación. El conductor acepta o modifica la categoría propuesta. El sistema incorpora la clasificación a la información de la mantención. La clasificación queda disponible para ser guardada junto con el registro. |
| **Postcondición** | La mantención queda clasificada con una categoría revisada por el conductor. |
| **Excepción** | **E1:** Si la IA no puede determinar una categoría, el conductor puede seleccionarla manualmente. **E2:** Si la clasificación propuesta es incorrecta, el conductor puede modificarla. **E3:** La clasificación propuesta por IA no se guarda definitivamente sin la revisión correspondiente. |
| **Requerimientos asociados** | RF-015 |

| **CU15** | Registrar manualmente |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado en TAG OK y tener un vehículo registrado. |
| **Descripción** | Permite registrar manualmente un estacionamiento indicando vehículo, fecha, lugar, hora de entrada, hora de salida, costo y observaciones. |
| **Secuencia** | El conductor ingresa al módulo **Estacionamientos**. Selecciona la opción **Registrar manualmente**. El sistema muestra el formulario de registro. El conductor selecciona el vehículo correspondiente. El conductor ingresa la fecha, lugar, hora de entrada, hora de salida, costo y observaciones. El conductor confirma el registro. El sistema valida la información ingresada. El sistema guarda el estacionamiento asociado al vehículo. |
| **Postcondición** | El estacionamiento queda registrado y asociado al vehículo correspondiente. |
| **Excepción** | **E1:** Si falta información necesaria, el sistema solicita completar los datos. **E2:** Si algún dato no es válido, el sistema solicita su corrección. **E3:** Si ocurre un error al guardar, el registro no se completa. |
| **Requerimientos asociados** | RF-016, RF-051 |

| **CU16** | Iniciar estacionamiento |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y tener un vehículo registrado. |
| **Descripción** | Permite iniciar un estacionamiento utilizando un cronómetro, registrando el momento de inicio y comenzando a contabilizar su duración |
| **Secuencia** | El conductor ingresa al módulo **Estacionamientos**. Selecciona el vehículo correspondiente. Selecciona la opción **Iniciar estacionamiento**. El sistema registra el inicio del estacionamiento. El sistema comienza a contabilizar la duración. El conductor puede continuar utilizando la aplicación mientras el estacionamiento permanece activo. |
| **Postcondición** | El estacionamiento queda iniciado y su duración comienza a contabilizarse. |
| **Excepción** | **E1:** Si no se puede iniciar el cronómetro, el sistema informa al conductor. **E2:** Si no existe un vehículo seleccionado, el sistema solicita seleccionarlo antes de iniciar. |
| **Requerimientos asociados** | RF-017 |

| **CU17** | Finalizar estacionamiento |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | Debe existir un estacionamiento previamente iniciado. |
| **Descripción** | Permite al conductor finalizar un estacionamiento activo, registrando la hora de término y la duración total. |
| **Secuencia** | El conductor accede al estacionamiento activo. Selecciona la opción **Finalizar estacionamiento**. El sistema registra la hora de término. El sistema detiene el cronómetro. El sistema calcula y registra la duración total del estacionamiento. El registro queda disponible para su consulta. |
| **Postcondición** | El estacionamiento queda finalizado con su hora de término y duración registradas. |
| **Excepción** | **E1:** Si no existe un estacionamiento activo, no se puede realizar la finalización. **E2:** Si ocurre un error al finalizar, el sistema informa al conductor. |
| **Requerimientos asociados** | RF-018 |

| **CU18** | Guardar ubicación |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y tener un vehículo registrado. |
| **Descripción** | Permite guardar la ubicación GPS del vehículo para recordar posteriormente dónde quedó estacionado. |
| **Secuencia** | El conductor ingresa al módulo **Estacionamientos**. Selecciona la opción **Guardar ubicación**. La aplicación obtiene la ubicación GPS disponible. El conductor confirma el registro de la ubicación. La ubicación queda asociada al registro del estacionamiento. El conductor puede consultar posteriormente la ubicación guardada. |
| **Postcondición** | La ubicación del vehículo queda almacenada y asociada al estacionamiento correspondiente. |
| **Excepción** | **E1:** Si no se puede obtener la ubicación, el sistema informa al conductor. **E2:** Si el conductor no autoriza el acceso a la ubicación, no se podrá guardar la posición mediante GPS. |
| **Requerimientos asociados** | RF-019 |

| **CU19** | Registrar con IA |
| --- | --- |
| **Actores** | Conductor y Gemini API. |
| **Precondición** | El conductor debe estar autenticado, tener un vehículo registrado y disponer de una fotografía del ticket o boleta de estacionamiento. |
| **Descripción** | Permite registrar un estacionamiento mediante fotografía de un ticket o boleta, utilizando IA para extraer datos como estacionamiento, ubicación, fecha, hora de entrada, hora de salida, duración y monto cuando estos se encuentren disponibles. |
| **Secuencia** | El conductor ingresa al módulo **Estacionamientos**. Selecciona la opción **Registrar con IA**. El conductor fotografía o carga el ticket o boleta. El sistema envía la información para su procesamiento mediante Gemini API. La IA analiza el documento. La IA extrae los datos disponibles. El sistema presenta la información detectada al conductor. El conductor continúa con la edición de los datos faltantes cuando corresponda. El registro continúa hacia su confirmación. |
| **Postcondición** | Los datos extraídos quedan disponibles para su revisión antes de almacenarse. |
| **Excepción** | **E1:** Si la IA no reconoce algunos datos, estos quedan disponibles para ser completados manualmente. **E2:** Si la IA no puede procesar el documento, el conductor puede realizar el registro manualmente. **E3:** Si existen datos dudosos o incompletos, deben ser revisados antes de confirmar. |
| **Requerimientos asociados** | RF-020 |

| **CU20** | Editar datos faltantes |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | Debe existir un registro procesado mediante IA con datos faltantes o incompletos. |
| **Descripción** | Permite al conductor completar o editar los datos que la IA no haya podido identificar antes de guardar el estacionamiento. |
| **Secuencia** | El sistema muestra los datos detectados mediante IA. El conductor identifica los campos incompletos. El conductor selecciona los campos que desea modificar. El conductor ingresa o corrige la información. El sistema actualiza la información mostrada. El conductor continúa hacia la confirmación del registro. |
| **Postcondición** | Los datos faltantes quedan completados o corregidos y preparados para su confirmación. |
| **Excepción** | **E1:** Si el conductor no desea completar un campo no obligatorio, puede dejarlo sin información. **E2:** Si el dato ingresado no es válido, el sistema solicita corregirlo. |
| **Requerimientos asociados** | RF-021 |

| **CU21** | Confirmar registro |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | La información obtenida mediante IA debe estar disponible para revisión. |
| **Descripción** | Permite al conductor revisar y confirmar explícitamente un registro de estacionamiento obtenido mediante IA antes de almacenarlo definitivamente. |
| **Secuencia** | El sistema muestra la información final del estacionamiento. El conductor revisa los datos. El conductor corrige cualquier información si es necesario. El conductor selecciona la opción **Confirmar**. El sistema valida los datos. El sistema guarda el registro. El estacionamiento queda asociado al vehículo correspondiente. |
| **Postcondición** | El estacionamiento queda almacenado únicamente después de la confirmación explícita del conductor. |
| **Excepción** | **E1:** Si el conductor no confirma, el registro no se guarda. **E2:** Si existen datos inválidos, el sistema solicita corregirlos antes de continuar. **E3:** Si el conductor cancela el proceso, el registro no se completa. |
| **Requerimientos asociados** | RF-022, RF-051 |

| **CU22** | Registrar abastecimiento |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado en TAG OK y tener un vehículo registrado. |
| **Descripción** | Permite registrar un abastecimiento indicando fecha, kilometraje, estación de servicio, tipo de combustible, litros, precio por litro y monto total. |
| **Secuencia** | El conductor ingresa al módulo **Combustible y carga**. Selecciona el vehículo correspondiente. Selecciona la opción **Registrar abastecimiento**. El sistema muestra el formulario de registro. El conductor ingresa los datos disponibles del abastecimiento. El conductor confirma el registro. El sistema valida la información ingresada. El sistema guarda el abastecimiento asociado al vehículo. |
| **Postcondición** | El abastecimiento queda registrado con los datos disponibles y asociado al vehículo correspondiente. |
| **Excepción** | **E1:** Si algún dato ingresado no es válido, el sistema solicita su corrección. **E2:** Si ocurre un error durante el guardado, el registro no se completa. |
| **Requerimientos asociados** | RF-023, RF-026, RF-051 |

| **CU23** | Registrar abastecimiento parcial |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y tener un vehículo registrado. |
| **Descripción** | Permite registrar un abastecimiento sin exigir que todos los campos estén completos, conservando únicamente la información disponible. |
| **Secuencia** | El conductor ingresa al módulo **Combustible y carga**. Selecciona el vehículo correspondiente. Selecciona la opción para registrar un abastecimiento. El sistema muestra los campos disponibles. El conductor completa solo la información que posee. El conductor confirma el registro. El sistema valida los datos ingresados. El sistema guarda el abastecimiento con la información disponible. |
| **Postcondición** | El abastecimiento queda registrado aunque existan campos sin completar. |
| **Excepción** | **E1:** Si un campo ingresado contiene un valor inválido, el sistema solicita corregirlo. **E2:** Si ocurre un error al guardar, el abastecimiento no se registra. |
| **Requerimientos asociados** | RF-024, RF-051 |

| **CU24** | Visualizar historial |
| --- | --- |
| **Actores** | Conductor. |
| **Precondición** | El conductor debe estar autenticado y tener un vehículo registrado. |
| **Descripción** | Permite consultar los registros históricos de abastecimiento asociados a un vehículo. |
| **Secuencia** | El conductor ingresa al módulo **Combustible y carga**. Selecciona el vehículo correspondiente. Selecciona la opción **Historial**. El sistema obtiene los registros de abastecimiento asociados. El sistema muestra los registros disponibles. El conductor consulta la información histórica. |
| **Postcondición** | El conductor visualiza el historial de abastecimientos registrados para el vehículo. |
| **Excepción** | **E1:** Si no existen abastecimientos registrados, el sistema informa que no hay historial disponible. **E2:** Si no es posible obtener la información, el sistema informa al conductor. |
| **Requerimientos asociados** | RF-025 / RF-053 |

| **CU25** | Visualizar gastos mensuales |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y existir al menos un registro de combustible asociado al vehículo. |
| **Descripción** | Permite visualizar el gasto mensual de combustible correspondiente al vehículo seleccionado. |
| **Secuencia** | El conductor ingresa al módulo **Combustible y carga**. Selecciona el vehículo correspondiente. Selecciona la opción para consultar los gastos de combustible. El sistema obtiene los registros correspondientes al periodo mensual. El sistema calcula el gasto acumulado. El sistema muestra el gasto mensual al conductor. |
| **Postcondición** | El conductor visualiza el gasto mensual de combustible del vehículo. |
| **Excepción** | **E1:** Si no existen registros para el periodo, el sistema muestra que no hay gastos registrados. **E2:** Si no puede obtenerse la información, el sistema informa al conductor. |
| **Requerimientos asociados** | RF-025 |

| **CU26** | Registrar combustible con IA |
| --- | --- |
| **Actores** | Conductor y Gemini API. |
| **Precondición** | El conductor debe estar autenticado, tener un vehículo registrado y disponer de una boleta de combustible para fotografiar o cargar. |
| **Descripción** | Permite registrar un abastecimiento mediante IA a partir de una boleta, reconociendo información como estación de servicio, fecha, combustible, litros, precio unitario y monto total. |
| **Secuencia** | El conductor ingresa al módulo **Combustible y carga**. Selecciona la opción **Registrar combustible con IA**. El conductor fotografía o carga la boleta. El sistema envía la información para su procesamiento mediante Gemini API. La IA analiza el documento. La IA extrae los datos disponibles. El sistema muestra la información detectada como una precarga editable. El conductor continúa con la revisión de los datos. Posteriormente, el conductor podrá confirmar el registro. |
| **Postcondición** | Los datos detectados quedan disponibles para revisión y corrección antes de guardarse. |
| **Excepción** | **E1:** Si la IA no reconoce determinados datos, estos quedan disponibles para edición manual. **E2:** Si la boleta no puede procesarse mediante IA, el conductor puede realizar el registro manualmente. **E3:** Si algunos campos son dudosos o incompletos, deberán ser revisados antes de confirmar. |
| **Requerimientos asociados** | RF-027 |

| **CU27** | Corregir datos detectados |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | La boleta debe haber sido procesada mediante IA y los datos detectados deben estar disponibles para revisión. |
| **Descripción** | Permite revisar y modificar los datos reconocidos por la IA antes de almacenar el registro de combustible. |
| **Secuencia** | El sistema muestra los datos obtenidos mediante IA. El conductor revisa la información. El conductor identifica los datos que deben corregirse. El conductor modifica o completa los campos correspondientes. El sistema actualiza la información mostrada. El conductor continúa hacia la confirmación del registro. |
| **Postcondición** | Los datos quedan revisados y corregidos para su posterior confirmación. |
| **Excepción** | **E1:** Si un dato ingresado no es válido, el sistema solicita corregirlo. **E2:** Si un campo no pudo ser reconocido y no es obligatorio, puede permanecer vacío. |
| **Requerimientos asociados** | RF-028 |

| **CU28** | Confirmar y guardar |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | Los datos del abastecimiento procesado mediante IA deben haber sido revisados por el conductor |
| **Descripción** | Permite confirmar explícitamente la información obtenida mediante IA antes de guardar el registro de combustible. |
| **Secuencia** | El sistema muestra la información final del abastecimiento. El conductor revisa los datos. El conductor selecciona la opción **Confirmar y guardar**. El sistema valida la información. El sistema almacena el abastecimiento. El registro queda asociado al vehículo correspondiente. |
| **Postcondición** | El abastecimiento queda guardado únicamente después de la confirmación del conductor. |
| **Excepción** | **E1:** Si el conductor no confirma la información, el registro no se guarda. **E2:** Si existen datos inválidos, el sistema solicita corregirlos antes de continuar. **E3:** Si el conductor cancela el proceso, el registro no se completa. |
| **Requerimientos asociados** | RF-029, RF-051 |

| **CU29** | Visualizar catálogo de beneficios |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado en TAG OK. |
| **Descripción** | Permite al conductor visualizar los beneficios que se encuentran activos y vigentes dentro de la aplicación. |
| **Secuencia** | El conductor ingresa al módulo **Beneficios**. El sistema consulta los beneficios disponibles. El sistema identifica los beneficios activos y vigentes. El sistema muestra los beneficios disponibles al conductor. El conductor puede continuar al filtrado de beneficios. |
| **Postcondición** | El conductor visualiza los beneficios activos y vigentes disponibles. |
| **Excepción** | **E1:** Si no existen beneficios activos o vigentes, el sistema informa que no hay beneficios disponibles. **E2:** Si no es posible obtener la información, el sistema informa al conductor. |
| **Requerimientos asociados** | RF-030 |

| **CU30** | Filtrar beneficios |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe encontrarse dentro del módulo de beneficios y existir beneficios disponibles. |
| **Descripción** | Permite al conductor aplicar filtros según categoría, ubicación y vigencia para acotar los beneficios que desea consultar. |
| **Secuencia** | El conductor visualiza los beneficios vigentes. Selecciona la opción de filtros. El conductor selecciona uno o más criterios de filtrado. El sistema aplica los criterios seleccionados. El sistema obtiene los beneficios que cumplen con los filtros. El conductor continúa a la visualización del catálogo filtrado. |
| **Postcondición** | Los criterios de filtrado quedan aplicados para mostrar los beneficios correspondientes. |
| **Excepción** | **1:** Si ningún beneficio cumple con los filtros seleccionados, el sistema informa que no existen resultados. **E2:** Si el conductor elimina los filtros, se vuelven a considerar todos los beneficios vigentes. |
| **Requerimientos asociados** | RF-033 |

| **CU31** | Administrar beneficios |
| --- | --- |
| **Actores** | Administrador |
| **Precondición** | El administrador debe estar autenticado y contar con acceso al backoffice de TAG OK. |
| **Descripción** | Permite al administrador crear, editar, activar y desactivar beneficios desde el backoffice. Los cambios realizados se reflejan posteriormente en el catálogo. |
| **Secuencia** | El administrador ingresa al backoffice. Accede a la administración de beneficios. El sistema muestra los beneficios registrados. El administrador selecciona crear, editar, activar o desactivar un beneficio. El administrador ingresa o modifica la información correspondiente. El administrador confirma la operación. El sistema guarda los cambios. Los cambios se reflejan en el catálogo de beneficios. |
| **Postcondición** | La información del beneficio queda creada o actualizada según la acción realizada por el administrador. |
| **Excepción** | **E1:** Si la información necesaria está incompleta, el sistema solicita completarla. **E2:** Si el administrador cancela la operación, los cambios no se guardan. **E3:** Si ocurre un error al guardar, el sistema informa al administrador. |
| **Requerimientos asociados** | RF-031  -  RF-032 |

| **CU32** | Clasificar por catálogo |
| --- | --- |
| **Actores** | Administrador. |
| **Precondición** | El administrador debe estar autenticado y debe existir un beneficio para administrar. |
| **Descripción** | Permite al administrador asociar un beneficio a una categoría disponible para facilitar posteriormente su visualización y filtrado. |
| **Secuencia** | El administrador accede a la administración de beneficios. Selecciona un beneficio. El sistema muestra las categorías disponibles. El administrador selecciona la categoría correspondiente. El administrador confirma la clasificación. El sistema asocia el beneficio a la categoría seleccionada. La clasificación queda disponible para la visualización y filtrado del catálogo. |
| **Postcondición** | El beneficio queda asociado a una categoría |
| **Excepción** | **E1:** Si no se selecciona una categoría, la clasificación no se completa. **E2:** Si el administrador cancela la operación, no se realizan cambios. **E3:** Si ocurre un error al guardar la clasificación, el sistema informa al administrador. |
| **Requerimientos asociados** | RF-034 |

| **CU33** | Capturar evidencia |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado en TAG OK y encontrarse realizando un registro que permita utilizar IA. |
| **Descripción** | Permite al conductor tomar una fotografía mediante la cámara o cargar un archivo para utilizarlo como fuente de información en el registro inteligente. |
| **Secuencia** | El conductor selecciona la opción de registro mediante IA. Selecciona tomar una fotografía o cargar un archivo. El conductor captura o selecciona la evidencia. TAG OK recibe la imagen o archivo. La evidencia queda disponible para continuar con el procesamiento mediante IA. |
| **Postcondición** | La fotografía o archivo queda disponible para continuar con el flujo inteligente. |
| **Excepción** | **E1:** Si el conductor cancela la captura o carga del archivo, el proceso no continúa. **E2:** Si no es posible recibir el archivo o fotografía, TAG OK informa al conductor. **E3:** El conductor puede utilizar el ingreso manual como alternativa. |
| **Requerimientos asociados** | RF-035  / RF-040 |

| **CU34** | Identificar tipo de documento |
| --- | --- |
| **Actores** | Gemini API. |
| **Precondición** | Debe existir una fotografía o archivo previamente capturado o cargado. |
| **Descripción** | Permite identificar mediante IA el tipo de documento o evidencia ingresada para determinar a qué módulo corresponde. |
| **Secuencia** | TAG OK envía la evidencia para su análisis mediante Gemini API. Gemini API analiza el documento o evidencia. La IA intenta reconocer el tipo de documento. Se obtiene el tipo de documento cuando puede ser reconocido. TAG OK utiliza esta información para continuar el registro hacia el módulo correspondiente. |
| **Postcondición** | El tipo de documento queda identificado para continuar el procesamiento. |
| **Excepción** | **E1:** Si la IA no logra identificar el documento, no se asigna información ficticia. **E2:** Si no puede identificarse el tipo, el conductor puede continuar mediante ingreso manual. |
| **Requerimientos asociados** | RF-036  /RF-040 /RF-041 |

| **CU35** | Extraer datos con IA |
| --- | --- |
| **Actores** | Gemini API. |
| **Precondición** | La evidencia debe haber sido recibida y su tipo debe haber sido identificado. |
| **Descripción** | Permite extraer mediante IA los campos relevantes de acuerdo con el tipo de documento o evidencia analizada. |
| **Secuencia** | Gemini API analiza el contenido del documento. La IA identifica los campos relevantes según el tipo de evidencia. La IA extrae los datos disponibles. TAG OK recibe los datos detectados. Los datos son presentados como una precarga. La información queda disponible para revisión del conductor. |
| **Postcondición** | Los datos reconocidos quedan disponibles como precarga, sin almacenarse automáticamente. |
| **Excepción** | **E1:** Los campos que no sean reconocidos quedan vacíos. **E2:** Los campos dudosos o incompletos quedan destacados para su revisión. **E3:** Si la extracción mediante IA falla, el conductor puede ingresar los datos manualmente. |
| **Requerimientos asociados** | RF-037 /RF-041 / RF-043 |

| **CU36** | Validar información detectada |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | La IA debe haber procesado la evidencia y presentado los datos reconocidos. |
| **Descripción** | Permite al conductor revisar la información detectada por la IA antes de que esta sea almacenada. |
| **Secuencia** | TAG OK muestra los datos detectados mediante IA. El conductor revisa la información presentada. TAG OK destaca los campos dudosos o incompletos cuando corresponda. El conductor verifica que los datos sean correctos. Si detecta errores o información faltante, puede corregirla o completarla. El conductor continúa hacia la confirmación de la información. |
| **Postcondición** | La información queda revisada y preparada para su confirmación. |
| **Excepción** | **E1:** Si existen datos incorrectos, el conductor puede modificarlos. **E2:** Si existen campos no reconocidos, estos pueden quedar vacíos o ser completados manualmente. **E3:** La información no se guarda durante esta etapa. |
| **Requerimientos asociados** | RF-038 / RF-041 /RF-043 |

| **CU37** | Confirmar información |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe haber revisado la información detectada mediante IA. |
| **Descripción** | Permite al conductor confirmar explícitamente que la información revisada puede continuar hacia su almacenamiento. |
| **Secuencia** | El conductor revisa la información presentada. Corrige o completa los datos cuando sea necesario. El conductor selecciona la opción de confirmación. TAG OK registra la aceptación de la información. La información confirmada queda preparada para ser almacenada en el módulo correspondiente. |
| **Postcondición** | Los datos quedan confirmados por el conductor y habilitados para su almacenamiento. |
| **Excepción** | **E1:** Si el conductor no confirma la información, esta no se almacena. **E2:** Si decide volver a editar los datos, retorna a la etapa de validación. **E3:** Si cancela el proceso, el registro no se completa. |
| **Requerimientos asociados** | RF-038 / RF-039 |

| **CU38** | Corregir o completar datos |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | Los datos detectados mediante IA deben estar disponibles para revisión. |
| **Descripción** | Permite al conductor corregir información detectada incorrectamente o completar campos que la IA no haya podido reconocer. |
| **Secuencia** | TAG OK muestra la información detectada. El conductor identifica un campo incorrecto, incompleto o vacío. Selecciona el campo correspondiente. El conductor modifica o completa la información. TAG OK actualiza los datos mostrados. El conductor vuelve a revisar la información antes de confirmar. |
| **Postcondición** | Los datos quedan corregidos o completados y disponibles para validación. |
| **Excepción** | **E1:** Un campo que la IA no reconozca puede permanecer vacío. **E2:** TAG OK no debe inventar valores para completar campos no reconocidos. |
| **Requerimientos asociados** | RF-038 /RF-041 |

| **CU39** | Guardar en módulo correspondiente |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | La información obtenida mediante IA debe haber sido revisada y confirmada por el conductor. |
| **Descripción** | Permite almacenar la información validada en el módulo que corresponda según el tipo de registro realizado. |
| **Secuencia** | El conductor confirma la información revisada. TAG OK identifica el módulo correspondiente al registro. TAG OK almacena la información confirmada. El registro queda asociado al módulo correspondiente. TAG OK conserva el origen y fecha de la captura para su trazabilidad. |
| **Postcondición** | El registro queda almacenado correctamente en el módulo correspondiente. |
| **Excepción** | **E1:** Si la información no ha sido confirmada, el registro no se guarda. **E2:** Si ocurre un error durante el almacenamiento, TAG OK informa al conductor y el registro no se completa. |
| **Requerimientos asociados** | RF-039 / RF-042  / RF-054 |

| **CU40** | Registrar manualmente |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe encontrarse realizando un registro y requerir utilizar la alternativa manual. |
| **Descripción** | Permite completar un registro de forma tradicional cuando no se utiliza IA o cuando la captura o extracción inteligente no puede completarse. |
| **Secuencia** | El conductor selecciona la opción de ingreso manual. TAG OK muestra el formulario correspondiente al registro. El conductor ingresa manualmente la información disponible. El conductor revisa los datos ingresados. Confirma la información. TAG OK guarda el registro en el módulo correspondiente. |
| **Postcondición** | La información queda registrada sin depender del procesamiento mediante IA. |
| **Excepción** | **E1:** Si el conductor cancela el registro, la información no se guarda. **E2:** Si existe un error al guardar, TAG OK informa al conductor. |
| **Requerimientos asociados** | RF-040 |

| **CU41** | Visualizar gasto mensual |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y contar con información de gastos registrada. |
| **Descripción** | Permite visualizar el gasto total de movilidad del mes, consolidando la información disponible en TAG OK. |
| **Secuencia** | El conductor ingresa al dashboard **Mi Auto**. TAG OK obtiene los gastos registrados durante el mes. TAG OK consolida la información disponible. El sistema calcula el gasto mensual de movilidad. El sistema muestra el monto total al conductor |
| **Postcondición** | El conductor visualiza el gasto de movilidad correspondiente al mes. |
| **Excepción** | **E1:** Si no existen gastos registrados durante el mes, no se muestra un gasto acumulado. **E2:** Si no es posible obtener la información, TAG OK informa al conductor. |
| **Requerimientos asociados** | RF-044 |

| **CU42** | Visualizar próxima mantención |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado, tener un vehículo registrado y contar con una próxima mantención programada. |
| **Descripción** | Permite visualizar desde el dashboard **Mi Auto** la información de la próxima mantención registrada, incluyendo la referencia de kilometraje. |
| **Secuencia** | El conductor ingresa al dashboard **Mi Auto**. TAG OK consulta la próxima mantención programada del vehículo. El sistema obtiene la información registrada de la mantención. El sistema obtiene la referencia de kilometraje correspondiente. El sistema muestra la próxima mantención en el dashboard. El conductor visualiza la información. |
| **Postcondición** | El conductor visualiza la información correspondiente a la próxima mantención registrada. |
| **Excepción** | **E1:** Si no existe una próxima mantención programada, el sistema informa que no hay una mantención próxima registrada. **E2:** Si no es posible obtener la información, TAG OK informa al conductor. |
| **Requerimientos asociados** | RF-045 |

| **CU43** | Visualizar próximo vencimiento |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado, tener un vehículo y documentos con fechas de vencimiento registrados. |
| **Descripción** | Permite visualizar en el dashboard los días restantes para el próximo vencimiento de un documento del vehículo. |
| **Secuencia** | El conductor ingresa al dashboard **Mi Auto**. TAG OK consulta los documentos registrados. El sistema revisa sus fechas de vencimiento. El sistema identifica el vencimiento más próximo. El sistema calcula los días restantes. El conductor visualiza el próximo vencimiento. |
| **Postcondición** | El conductor visualiza los días restantes para el próximo vencimiento registrado. |
| **Excepción** | **E1:** Si no existen documentos con vencimientos registrados, no se muestra un próximo vencimiento. **E2:** Si no es posible obtener la información, TAG OK informa al conductor. |
| **Requerimientos asociados** | RF-046 |

| **CU44** | Visualizar beneficios disponibles |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado en TAG OK. |
| **Descripción** | Permite visualizar desde el dashboard la cantidad de beneficios disponibles para el conductor. |
| **Secuencia** | El conductor ingresa al dashboard **Mi Auto**. TAG OK consulta la información vigente de beneficios. El sistema identifica los beneficios disponibles. El sistema obtiene la cantidad correspondiente. El conductor visualiza la cantidad de beneficios disponibles. |
| **Postcondición** | El conductor visualiza la cantidad de beneficios disponibles. |
| **Excepción** | **E1:** Si no existen beneficios disponibles, el sistema indica que no hay beneficios vigentes. **E2:** Si no es posible obtener la información, TAG OK informa al conductor. |
| **Requerimientos asociados** | RF-047 |

| **CU45** | Visualizar gastos por categoría |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y existir información de gastos registrada. |
| **Descripción** | Permite visualizar los gastos mensuales separados por las categorías TAG, combustible, estacionamientos y mantenciones. |
| **Secuencia** | El conductor ingresa al dashboard **Mi Auto**. TAG OK obtiene los gastos registrados durante el mes. El sistema clasifica los montos según su categoría. El sistema calcula el monto correspondiente a cada categoría. El sistema presenta los gastos de TAG, combustible, estacionamientos y mantenciones. El conductor consulta la distribución de sus gastos. |
| **Postcondición** | El conductor visualiza los montos mensuales correspondientes a cada categoría. |
| **Excepción** | **E1:** Si una categoría no posee gastos registrados, no presenta gastos para el periodo. **E2:** Si no es posible obtener los registros, TAG OK informa al conductor. |
| **Requerimientos asociados** | RF-048 |

| **CU46** | Acceder a acciones rápidas |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe estar autenticado y encontrarse en el dashboard **Mi Auto**. |
| **Descripción** | Permite acceder rápidamente desde el dashboard a las principales funcionalidades de registro y consulta. |
| **Secuencia** | El conductor ingresa al dashboard **Mi Auto**. El sistema muestra las acciones rápidas disponibles. El conductor selecciona una acción. Puede seleccionar **Registrar combustible**, **Registrar estacionamiento**, **Agregar mantención** o **Ver beneficios**. TAG OK dirige al conductor al flujo correspondiente. |
| **Postcondición** | El conductor accede a la funcionalidad seleccionada. |
| **Excepción** | **E1:** Si no es posible acceder a la funcionalidad seleccionada, TAG OK informa al conductor. |
| **Requerimientos asociados** | RF-049 |

| **CU47** | Recibir notificaciones |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | El conductor debe tener las notificaciones habilitadas y existir una condición que genere una notificación. |
| **Descripción** | Permite al conductor recibir notificaciones relacionadas con vencimientos, mantenciones próximas y beneficios disponibles. |
| **Secuencia** | TAG OK identifica una condición que requiere una notificación. El sistema genera la notificación correspondiente. TAG OK entrega la notificación al conductor. El conductor recibe la información. El conductor puede revisar el contenido de la notificación. |
| **Postcondición** | El conductor recibe la notificación correspondiente. |
| **Excepción** | **E1:** Si las notificaciones no están habilitadas, el conductor no recibe la notificación. **E2:** Si no se cumple ninguna condición asociada, no se genera una notificación. |
| **Requerimientos asociados** | RF-052 |

| **CU48** | Recordar próxima mantención |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | Debe existir una próxima mantención programada y las notificaciones deben estar habilitadas. |
| **Descripción** | Permite informar al conductor cuando corresponda realizar una próxima mantención según la programación registrada. |
| **Secuencia** | TAG OK consulta la próxima mantención programada. El sistema verifica la fecha, kilometraje o ambos parámetros registrados. Cuando corresponde, TAG OK genera un recordatorio. El conductor recibe la notificación. El conductor puede revisar la información de la mantención. |
| **Postcondición** | El conductor recibe un recordatorio asociado a la próxima mantención. |
| **Excepción** | **E1:** Si no existe una mantención programada, no se genera el recordatorio. **E2:** Si aún no se cumple la condición configurada, no se genera la notificación. |
| **Requerimientos asociados** | RF-052 |

| **CU49** | Alertar vencimiento |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | Debe existir un documento vehicular con fecha de vencimiento registrada y las notificaciones deben estar habilitadas. |
| **Descripción** | Permite avisar al conductor cuando se aproxima el vencimiento de un documento del vehículo. |
| **Secuencia** | TAG OK consulta las fechas de vencimiento registradas. El sistema identifica un vencimiento próximo. TAG OK genera la notificación preventiva. El conductor recibe la alerta. El conductor puede revisar el documento asociado. |
| **Postcondición** | El conductor recibe una alerta relacionada con el próximo vencimiento. |
| **Excepción** | **E1:** Si no existen fechas de vencimiento registradas, no se genera la alerta. **E2:** Si el vencimiento aún no cumple la condición para notificar, no se genera una alerta. |
| **Requerimientos asociados** | RF-004  / RF-052 |

| **CU50** | Notificar beneficios disponibles |
| --- | --- |
| **Actores** | Conductor |
| **Precondición** | Debe existir al menos un beneficio disponible o vigente para el conductor y las notificaciones deben estar habilitadas. |
| **Descripción** | Permite informar al conductor sobre beneficios disponibles dentro de TAG OK. |
| **Secuencia** | TAG OK consulta los beneficios registrados. El sistema identifica los beneficios disponibles o vigentes. TAG OK genera la notificación correspondiente. El conductor recibe la notificación. El conductor puede acceder posteriormente al módulo de beneficios. |
| **Postcondición** | El conductor recibe información sobre beneficios disponibles. |
| **Excepción** | **E1:** Si no existen beneficios disponibles o vigentes, no se genera una notificación. **E2:** Si las notificaciones están deshabilitadas, el conductor no recibe el aviso. |
| **Requerimientos asociados** | RF-030  / RF-052 |