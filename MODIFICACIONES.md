# Guía de Modificaciones, Actualizaciones y Persistencia de Datos

**Proyecto:** CASART Concursos Desktop Standalone  
**Fecha:** Septiembre 2026  
**Ubicación:** `C:\Users\CASART\Desktop\CASART\codigo\sistema_gestor\casart_concursos_desktop`

---

## 1. ¿Se pierde el progreso de inscripción al actualizar el sistema?

**NO. No se pierde absolutamente nada.**

### ¿Por qué?
La base de datos SQLite (`concursos_offline.db`) **está completamente desacoplada** de la carpeta del ejecutable (`.exe`). Se almacena en la ruta de documentos de Windows del usuario del equipo:

```text
C:\Users\<TuUsuario>\Documents\CASART_Concursos\concursos_offline.db
```

* Puedes eliminar la carpeta de la aplicación, reemplazar el archivo `.exe` o descomprimir una nueva versión: **los datos registrados, artesanos, piezas y folios permanecen intactos**.
* Al abrir la nueva versión, el programa detecta automáticamente el archivo en `Documents\CASART_Concursos\` y continúa trabajando sobre la misma base de datos sin interrupción.

---

## 2. Tipos de Modificaciones y Cómo Proceder

### Caso A: Corrección de datos de captura (Nombres, CURP, Piezas, Costos)
> **No requiere recompilar ni actualizar ejecutables.**

Si durante el concurso un capturista cometió un error tipográfico en el nombre del artesano, CURP, teléfono, datos de la pieza o categorías:
1. Ve a la pestaña **Inscripción de Piezas > Piezas Inscritas**.
2. Ubica la cédula por folio o nombre y presiona el botón **"Editar/Corregir"**.
3. Realiza los cambios necesarios y presiona **"Guardar Correcciones"**.
4. Puedes presionar **"Reimprimir"** para entregar el comprobante físico actualizado al artesano.

---

### Caso B: Modificaciones de código, diseño o nuevas funciones
> **Requiere recompilar el ejecutable y copiar la nueva versión.**

Si necesitas agregar una nueva pantalla, cambiar reglas del concurso, modificar formatos o ajustar la lógica:

#### Paso 1: Realizar los cambios en el código
Edita los archivos del proyecto según lo requerido y verifica que no haya errores:
```powershell
flutter analyze
flutter test
```

#### Paso 2: Generar la nueva versión Release
Ejecuta en la terminal de la computadora principal de desarrollo:
```powershell
flutter build windows --release
```

#### Paso 3: Generar el paquete portable (.zip)
Empaqueta los binarios compilados en un archivo comprimido listo para transferir:
```powershell
Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "CASART_Concursos_Desktop_v1.0.0_Portable.zip" -Force
```

#### Paso 4: Actualizar las computadoras
1. Copia el archivo `.zip` (o la carpeta `Release`) a una memoria USB.
2. En las computadoras de los capturistas:
   * Cierra la versión anterior de la aplicación.
   * Reemplaza el contenido de la carpeta de la app con los nuevos archivos.
   * Ejecuta `casart_concursos_desktop.exe`.
3. **Todo el historial, folios y concursantes previos seguirán cargados automáticamente.**

---

## 3. ¿Cómo funcionan las Terminales (Clientes en Red Local)?

* **PC Servidor (Principal):** Es la única máquina que almacena físicamente el archivo `concursos_offline.db`.
* **PC Terminales (Clientes):** No guardan información en su disco duro local; todas sus peticiones de inscripción se procesan y confirman en tiempo real en la PC Servidor vía Wi-Fi.
* Si una terminal se apaga, se reinicia o se le cambia el ejecutable, **no existe riesgo de pérdida de datos** porque la información ya quedó registrada en la base de datos del Servidor.

---

## 4. Medida de Seguridad: Respaldos en USB con 1 Clic

Antes de realizar cualquier actualización mayor de software o al finalizar una jornada de inscripciones:
1. Entra a la sección **"Respaldos y Excel"**.
2. Presiona el botón **"Hacer Respaldo en USB / Disco"**.
3. Selecciona tu memoria USB o carpeta de seguridad.
4. Se generará una copia exacta de la base de datos con fecha y hora (`CASART_Concursos_Respaldo_AAAA_MM_DD_HHmm.db`).
5. Si alguna vez necesitas recuperar esa copia en otra computadora, usa el botón **"Restaurar desde Respaldo (.db)"**.

---

## 5. Bitácora del Sistema y Archivos de Logs (`casart_actividad.log`)

Todas las acciones críticas realizadas en el sistema quedan auditadas en tiempo real en un archivo de texto persistente:
* **Creaciones:** Concursos, artesanos, inscripciones (con folios y piezas), premios y respaldos.
* **Modificaciones:** Correcciones de artesanos, edición de piezas o precios, cambios de estado a finalizado y configuración de red.
* **Eliminaciones:** Cancelación de inscripciones/cédulas y eliminación de premios.
* **Errores:** Fallas de base de datos, excepciones de Flutter en interfaz, errores de conexión HTTP en clientes de red y errores no controlados.

### Comportamiento en Modo Portable:
* En la versión portable (`CASART_Concursos_Desktop_v1.0.0_Portable.zip` descomprimida en memoria USB o carpeta), el archivo se crea automáticamente en:
  ```text
  <CarpetaDeLaAplicacion>\logs\casart_actividad.log
  ```
  De esta manera, toda la bitácora viaja dentro de la memoria USB junto con el programa.
* Si el directorio carece de permisos de escritura (ej. carpetas protegidas del sistema), automáticamente conmuta a:
  ```text
  C:\Users\<TuUsuario>\Documents\CASART_Concursos\logs\casart_actividad.log
  ```

### Acceso a los Logs desde la Aplicación:
1. Desde la barra superior: botón **"Logs"** visible en todas las pantallas.
2. Desde la pestaña **"Respaldos y Excel"**: tarjeta **"Bitácora del Sistema y Archivos de Logs (.log)"**.
3. Opciones disponibles:
   * **Ver Bitácora en Pantalla:** buscador interactivo con filtros por tipo (Creaciones, Modificaciones, Eliminaciones, Errores).
   * **Abrir en Notepad:** abre instantáneamente el archivo en el Bloc de Notas de Windows.
   * **Abrir Carpeta:** abre el Explorador de Windows ubicando el archivo `.log`.
   * **Exportar a USB:** guarda una copia directa del log en la memoria USB seleccionada.

