#### B. Sistema de Actualizaciones Multiplataforma (Windows y macOS) vía GitHub

• Servicio: `update_service.dart`, vinculado al repositorio:
https://github.com/Angel-developpeur/CASART_concursos_app

• Detección Automática por Sistema Operativo:
    - **Windows**: Busca binarios con extensión `.exe` (`Instalador_Concursos_CASART.exe`). Al descargar, ejecuta el instalador silencioso/asistente y cierra la aplicación para permitir el reemplazo de DLLs.
    - **macOS**: Busca imágenes de disco con extensión `.dmg` (`Concursos_CASART_macOS.dmg`) o paquetes `.pkg`/`.zip`. Al descargar, monta automáticamente la imagen `.dmg` usando el comando `open` del sistema y cierra la app para que el usuario pueda reemplazar el archivo en `/Applications` sin conflicto de bloqueo de archivos.

• Diálogo visual: `update_dialog.dart`:
    - Comprueba si hay versiones nuevas mediante la API pública de GitHub Releases (`/releases/latest`).
    - Si la app está al día o aún no hay releases creados, muestra una confirmación con icono verde.
    - Si hay una nueva versión, muestra las notas del release / novedades y detecta el instalador correspondiente a la plataforma del usuario.
    - Permite dar clic en "Descargar e Instalar", mostrando el progreso en MB y porcentaje.
    - Al finalizar la descarga, ejecuta/abre el instalador correspondiente y cierra la app de forma segura.

• Accesos en la Interfaz:
    1. Barra lateral izquierda: Botón "Buscar actualizaciones".
    2. Sección "Respaldos y Exportación": Tarjeta con la versión instalada y botón directo.

──────
### 2. ¿Cómo generar los instaladores y publicar una actualización en GitHub?

Cuando hagas mejoras en el código y quieras publicar una nueva versión:

#### Paso 1: Aumentar la versión en el proyecto
- En `pubspec.yaml`, actualiza por ejemplo:
  `version: 1.0.6+5`
- En `lib/core/services/update_service.dart`:
  `static const String currentVersion = '1.0.6';`
- En `lib/views/shell/app_shell.dart`: actualiza la etiqueta de versión en la barra lateral si corresponde.

---

#### Paso 2: Generar los binarios

##### A. Para Windows (.exe):
1. Compilar en modo release:
   `flutter build windows --release`
   *(Con ofuscación: `flutter build windows --release --obfuscate --split-debug-info=./debug_symbols`)*
2. Compilar con Inno Setup:
   Abre `installer.iss` y compila para generar:
   `build\installer\Instalador_Concursos_CASART.exe`

##### B. Para macOS (.dmg):
Tienes dos formas de generarlo:

**Opción 1 - Automatizado en la nube (Recomendado si desarrollas en Windows):**
Como estás programando en Windows y Flutter para macOS requiere Xcode/macOS:
- Se incluye el flujo de GitHub Actions en `.github/workflows/release_macos.yml`.
- Cada vez que subas un tag (ej: `git tag v1.0.6 && git push origin v1.0.6`), GitHub enciende automáticamente una máquina macOS virtual, compila la app y adjunta `Concursos_CASART_macOS.dmg` al Release de GitHub de forma 100% gratuita y sin necesidad de tener una Mac física.

**Opción 2 - En una Mac física:**
1. Clona el proyecto en la Mac.
2. Ejecuta en terminal:
   `chmod +x create_installer_macos.sh`
   `./create_installer_macos.sh`
3. Esto generará directamente:
   `build/Concursos_CASART_macOS.dmg`

---

#### Paso 3: Crear el Release en GitHub
1. Ve a tu repositorio en GitHub:
   https://github.com/Angel-developpeur/CASART_concursos_app/releases
2. Haz clic en **"Draft a new release"** (o editar el release generado por el tag).
3. En **Tag version**, usa el formato con 'v': ej. `v1.0.6`.
4. Asigna un título descriptivo y escribe las notas o novedades.
5. En la sección **Attach binaries / assets**, arrastra **ambos** archivos:
   - `Instalador_Concursos_CASART.exe` (para Windows)
   - `Concursos_CASART_macOS.dmg` (para macOS)
6. Haz clic en **Publish release**.

A partir de ese momento:
- Si el usuario abre la app en **Windows**, descargará e instalará el `.exe`.
- Si el usuario abre la app en **macOS**, descargará y montará el `.dmg`.



e ha aplicado la solución completa para la detección de ganadores, sincronización entre PC Servidor y PC Clientes, y la generación oficial de Actas y
  Distintivos en PDF.
  ──────
  ### 1. Resumen de las causas detectadas

  1. Invisibilidad de premios en las PCs Clientes:
      • Al consultar piezas vía red (GET /api/concursos/<id>/registros), el modelo Artesania.toMap() únicamente serializaba las columnas nativas de la tabla SQLite
      (id_premio), omitiendo el campo virtual premio_nombre.
      • En consecuencia, la interfaz de las PCs clientes comprobaba if (p1?.premioNombre != null), el cual resultaba en null, ocultando el distintivo amarillo de
      la pieza ganadora.
  2. Falla al generar reportes y PDFs en PCs Clientes ("no detecta ganadores"):
      • Las funciones de reporte en ExcelReportsService y el menú desplegable ExcelExportDropdown consultaban directamente el archivo local de SQLite
      concursos_offline.db del equipo en lugar de los repositorios. En las PCs clientes, dicha base local está vacía porque los datos residen en el Servidor
      central.

  ──────
  ### 2. Cambios aplicados

  #### A. Sincronización transparente de Premios en Red

  • **artesania.dart**:
      • Se implementó toTableMap() exclusivo para persistencia en SQLite (respetando estrictamente las columnas existentes en la base de datos).
      • Se enriqueció toMap() para enviar sobre la red los nombres asociados: premio_nombre, rama_nombre, categoria_nombre y subcategoria_nombre.
  • **premio_repository.dart** y **api_client.dart**:
      • Se habilitaron los endpoints y delegaciones de red para removerGanador, asignarGanador, getGanadores y getConteoPremiosOtorgados.


  #### B. Generación de Actas y Distintivos en PDF

  • **pdf_generator.dart**:
      • **generateActaGanadores(...)**: Genera el Acta Oficial de Resultados y Premiación en formato horizontal (Carta) con logotipos oficiales FONART/CASART,
      resumen de bolsa monetaria expresada en número y letra (NumeroALetras), tabla detallada de ganadores y líneas de firma institucionales (Jurado Calificador,
      Dirección General CASART y Órgano de Control/Testigo).
      • **generateDistintivosGanadores(...)**: Genera los Distintivos Oficiales de Pieza Premiada (tarjetas de exhibición impresas por duplicado para colocar
      físicamente junto a cada pieza ganadora, con folio, artesano, procedencia, categoría, premio y montos).
  • **acta_ganadores_dialog.dart**:
      • Nuevo visor integrado con PdfPreview que permite alternar con un clic entre el Acta de Resultados y los Distintivos de Pieza, permitiendo previsualizar,
      imprimir directamente a cualquier impresora física o exportar el archivo .pdf.


  #### C. Integración en las Vistas (Servidor y Clientes)

  • **excel_export_dropdown.dart**:
      • Ahora pasa premioRepo y registroRepo a ExcelReportsService, por lo que tanto las exportaciones Excel (Formatos A, B, C y D) como los PDFs detectan a todos
      los ganadores en PCs cliente y servidor por igual.
      • Se añadieron las opciones:
          • Acta de Ganadores (PDF)
          • Distintivos de Pieza (PDF)

  • **premios_view.dart**:
      • Se agregaron botones de acceso directo "Acta PDF" y "Distintivos PDF" en la barra superior cuando existen ganadores asignados.
      • En la pestaña de ganadores, cada tarjeta cuenta con su botón individual "Distintivo" para generar la tarjeta de esa pieza en particular.
  • **inscripcion_view.dart**:
      • Los distintivos amarillos de premios en la lista de "Piezas Inscritas" ahora se visualizan en las PCs cliente y son interactivos (al dar clic se abre
      directamente el diálogo para imprimir el distintivo oficial de esa pieza premiada).

  ──────
  ### 3. Verificación y Pruebas

  • flutter analyze: 0 errores.
  • flutter test: 81 pruebas exitosas (100% de la suite pasando), incluyendo pruebas de red cliente/servidor, esquemas de bases de datos, generación de PDFs
  oficiales y consistencia de datos.
