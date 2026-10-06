#!/bin/bash
set -e

echo "==========================================="
echo " Compilando Concursos CASART para macOS... "
echo "==========================================="

# 1. Compilar en modo Release
flutter build macos --release

APP_PATH="build/macos/Build/Products/Release/Concursos CASART.app"
TEMP_DMG_DIR="build/dmg_temp"
DMG_OUTPUT="build/Concursos_CASART_macOS.dmg"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: No se encontró $APP_PATH"
    exit 1
fi

echo "==========================================="
echo " Creando instalador .DMG...                "
echo "==========================================="

# 2. Preparar carpeta temporal con la app y el acceso directo a /Applications
rm -rf "$TEMP_DMG_DIR" "$DMG_OUTPUT"
mkdir -p "$TEMP_DMG_DIR"
cp -R "$APP_PATH" "$TEMP_DMG_DIR/"
ln -s /Applications "$TEMP_DMG_DIR/Aplicaciones"

# 3. Generar la imagen de disco comprimida (.dmg)
hdiutil create -volname "Concursos CASART" \
               -srcfolder "$TEMP_DMG_DIR" \
               -ov \
               -format UDZO \
               "$DMG_OUTPUT"

# 4. Limpieza
rm -rf "$TEMP_DMG_DIR"

echo "==========================================="
echo " ¡Instalador creado con éxito!            "
echo " Ubicación: $DMG_OUTPUT"
echo "==========================================="
