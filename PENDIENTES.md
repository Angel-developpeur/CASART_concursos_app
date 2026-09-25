# CASART Concursos Desktop - Estado del Proyecto y Pendientes

**Fecha de corte:** 22 de Septiembre, 2026  
**Ubicación del Proyecto:** `C:\Users\CASART\Desktop\CASART\codigo\sistema_gestor\casart_concursos_desktop`  
**Entorno:** Flutter Desktop (Windows x64) | Dart 3.12 | SQLite FFI | Shelf HTTP Server

---

## 1. Lo que se completó (Listo y Verificado)

- [x] **Arquitectura Offline Híbrida (Servidor Local + Terminales en Red Local):**
  - PC Servidor (Host) alberga la base de datos SQLite y sirve la API REST local (`Shelf` en puerto 8080).
  - PC Terminales (Clientes) se conectan mediante Wi-Fi o punto de acceso (Hotspot de celular sin internet) apuntando a la IP local del Servidor.
  - Asignación atómica de folios consecutivos (`MAX(folio) + 1`) verificada con tests de peticiones concurrentes simultáneas.
  - Botón de 1 clic para copiar la regla de apertura de puerto en Windows Defender Firewall en el diálogo de red.
- [x] **Modelo y Formulario de Concursos (`aportacion_concurso`):**
  - Registro de concurso con categorías multi-nivel (categoría y subcategorías).
  - Componente multi-fila infinito para registrar aportaciones (`nombre`, `cantidad`), persistido en la tabla `aportacion_concurso`.
- [x] **Registro de Inscripción:**
  - Búsqueda en tiempo real de artesanos por CURP o nombre.
  - Registro de hasta 2 piezas por artesano sin inputs de fotos.
  - Cálculo automático del precio de venta sugerido (IVA + porcentaje de utilidad del concurso).
- [x] **Comprobante de Inscripción (Cédula de Registro):**
  - Generación en PDF con medidas cuadradas exactas (**215 mm x 215 mm**).
  - Formato institucional con sellos de corte, firmas de conformidad y entrega, folio en rojo y desglose de ambas piezas.
  - Impresión nativa directa y previsualización.
- [x] **Listado, Búsqueda y Edición de Inscripciones (Nuevo):**
  - Vista enriquecida en la pestaña "Piezas Inscritas" con resumen estadístico en tiempo real (artesanos inscritos, total de piezas registradas y valor acumulado de venta).
  - Búsqueda instantánea por artesano, CURP, folio o nombre de pieza.
  - Botón **"Reimprimir"** para generar la cédula en cualquier momento.
  - Modal **"Editar / Corregir Cédula"** (`EditarInscripcionDialog`):
    - Permite corregir datos del artesano (nombre, apellidos, CURP, RFC, teléfono, municipio, localidad, etnia, estado civil).
    - Permite editar Pieza 1 y Pieza 2 (categorías, subcategorías, costos con recálculo automático de precio de venta, materiales y descripción).
    - Soporte de actualización tanto en base de datos local SQLite como a través de la API REST local en modo Terminal (`PUT /api/concursos/<id>/inscripcion/<id>`).
- [x] **Módulo de Premios y Asignación de Ganadores:**
  - Registro del catálogo de premios y vinculación con las piezas concursantes.
- [x] **Respaldos y Reportes:**
  - Copia de seguridad en un clic de la base de datos `.db` a memoria USB o disco local.
  - Exportación de cédulas y datos a Excel `.xlsx` multi-hoja.
  - **Exportador de Sincronización Web (.json):** Botón para generar el archivo de corte con metadata, concurso, inscripciones, piezas, costos y ganadores para importar en el backend Laravel.
- [x] **Sistema de Auditoría y Archivos de Logs (`casart_actividad.log`):**
  - Registro de todas las acciones en tiempo real: creaciones, modificaciones, eliminaciones y errores.
  - **Soporte Nativo Portable:** detección automática de la carpeta del ejecutable (`logs/casart_actividad.log`) para viajar en memorias USB, con fallback a `Documentos/CASART_Concursos/logs/`.
  - Captura global de errores no controlados (`FlutterError.onError` y `PlatformDispatcher.instance.onError`).
  - Visor interactivo en pantalla (`LogViewerDialog`) con búsqueda y filtros por tipo de acción.
  - Botones directos para abrir en Notepad, abrir carpeta contenedora y exportar a USB.
- [x] **Empaquetado y Distribución a Producción (Release):**
  - Compilación Release completada (`flutter build windows --release`).
  - Paquete portable generado y actualizado: `CASART_Concursos_Desktop_v1.0.0_Portable.zip` (17.7 MB) con binarios y librerías DLL (`sqlite3.dll`, `pdfium.dll`, etc.) listo para correr en cualquier laptop sin instalar Flutter ni herramientas de desarrollo.
- [x] **Calidad y Pruebas:**
  - `flutter analyze` con **0 errores / 0 warnings**.
  - Tests unitarios y de integración de red y logger (`test/logger_test.dart`, `test/network_integration_test.dart`, `test/premio_category_test.dart`, `test/widget_test.dart`) pasando al 100%.

---

## 2. Pruebas Físicas en Campo Recomendadas (Validación con Hardware)

### A. Pruebas de Red y Comunicación con Laptops Físicas
- [ ] **Prueba de conexión real con 2 laptops físicas:**
  1. Conectar ambas computadoras al mismo punto de acceso Wi-Fi o Hotspot móvil (no requiere internet).
  2. En la PC 1 (Servidor), abrir la app y verificar que esté en "Modo Servidor" (ver IP local en barra superior). Si el firewall bloquea, pegar en PowerShell de Administrador el comando copiado desde el botón de red.
  3. En la PC 2 (Terminal), descomprimir `CASART_Concursos_Desktop_v1.0.0_Portable.zip`, abrir la app, ir al chip de red, elegir "Modo Terminal", escribir la IP de la PC 1 y presionar "Probar Conexión".
  4. Realizar una inscripción en ambas PCs al mismo tiempo para validar folios consecutivos en pantalla.

### B. Ajustes de Formato e Impresión Física Real
- [ ] **Prueba de impresión física con papel 215mm x 215mm:**
  - Validar los márgenes de impresión en la impresora física disponible en el evento.
  - Si se utiliza papel bond carta (215.9 mm x 279.4 mm), asegurar que las líneas de corte del comprobante queden perfectamente alineadas para recortar a 215x215 mm.
