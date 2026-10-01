  #### B. Sistema de Actualizaciones Automáticas vía GitHub

  • Servicio: Creado update_service.dart, vinculado a tu repositorio:
  https://github.com/Angel-developpeur/CASART_concursos_app
  • Diálogo visual: Creado update_dialog.dart:
      • Comprueba si hay versiones nuevas mediante la API de GitHub.
      • Si la app está al día o aún no hay releases creados, muestra una confirmación con icono verde.
      • Si hay una nueva versión, muestra las notas del release / novedades.
      • Permite dar clic en "Descargar e Instalar", mostrando una barra de progreso con el porcentaje y los megabytes descargados.
      • Al finalizar la descarga, ejecuta automáticamente el instalador y cierra la aplicación para que Windows permita reemplazar los archivos.
  • Accesos en la Interfaz:
      1. Barra lateral izquierda: Botón "Buscar actualizaciones" situado debajo de v1.0.0 / Angel developpeur.
      2. Sección "Respaldos y Exportación": Tarjeta dedicada con información de la versión y botón directo.

  ──────
  ### 2. ¿Cómo publicar una actualización en GitHub en el futuro?

  Cuando hagas mejoras en el código y quieras que los usuarios reciban la actualización:

  1. Aumentar la versión en el proyecto:
  En pubspec.yaml, cambia por ejemplo:
    version: 1.0.1+2
  (Y en update_service.dart:32 actualiza static const String currentVersion = '1.0.1';).
  y el app_sheell.dart que contien la barra dwe navegaciones donde dice version angel developpeur
  2. Compilar la versión final:
    flutter build windows --release

   para ofuscar la app es :  flutter build windows --release --obfuscate --split-debug-info=./debug_symbols

  3. Generar el instalador .exe con Inno Setup:
  Abres installer.iss y compilas, lo cual generará:
    build\installer\Instalador_Concursos_CASART.exe

  4. Crear el Release en GitHub:
      • Entra a tu repositorio: Angel-developpeur/CASART_concursos_app/releases https://github.com/Angel-developpeur/CASART_concursos_app/releases.
      • Haz clic en "Draft a new release" (o Crear nuevo     release).
      • En Choose a tag, escribe la versión: v1.0.1 y pulsa Create new tag.
      • Pon un título (ej: Versión 1.0.1 - Mejoras y correcciones).
      • Describe las novedades en la caja de texto.
      • En el recuadro Attach binaries, arrastra y sube el archivo:
      build\installer\Instalador_Concursos_CASART.exe.
      • Haz clic en Publish release.
