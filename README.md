# 🎬 Filmoly - Video Analysis & Playback

Una aplicación Flutter para analizar, reproducir y extraer metadatos de archivos de video en múltiples plataformas.

## 🚀 Características

### 📊 Análisis de Metadatos
- **Extracción completa**: Resolución, codec, bitrate, FPS, aspect ratio
- **Audio**: Detecta idiomas, codecs y bitrate
- **Subtítulos**: Identifica idiomas de subtítulos disponibles
- **Información general**: Formato, duración, tamaño en MB
- **Fuentes**: Archivos locales y URLs web
- **Fallback inteligente**: Si FFprobe no disponible, extrae info del nombre del archivo

### 🎥 Reproducción de Video
- Integración con MediaKit para reproducción fluida
- Soporte multiplataforma (Windows, Android, iOS, Linux, macOS, Web)
- Controles interactivos

### 📁 Gestión de Archivos
- File picker para seleccionar archivos locales
- Manejo de permisos (permission_handler)
- URLs directas para videos en línea

## 📋 Requisitos Previos

### Para Análisis de Metadatos (Recomendado)
**FFmpeg con FFprobe** - Herramienta de línea de comandos para extracción de metadatos

👉 **[Guía de instalación de FFmpeg](./INSTALAR_FFMPEG.md)**

Para instalación rápida:
```powershell
# En Windows con Chocolatey:
choco install ffmpeg

# O con Winget:
winget install FFmpeg
```

### Dependencias Flutter
```
flutter pub get
```

## 🛠️ Instalación y Uso

### 1. Clona el repositorio
```bash
git clone <repositorio>
cd filmoly
```

### 2. Instala dependencias
```bash
flutter pub get
```

### 3. Ejecuta en tu dispositivo
```bash
# Windows
flutter run -d windows

# Android
flutter run -d android

# iOS (requiere macOS)
flutter run -d ios

# Web
flutter run -d web
```

## 🎯 Inicio Rápido

1. **Abre la aplicación**
2. En la pantalla principal, busca el botón **"📊 Analizar Metadatos de Video"**
3. Selecciona un archivo o ingresa una URL
4. Presiona **"Analizar"**
5. Ve los metadatos extraídos en tiempo real
6. Usa **"📋 Copiar todo"** para copiar los metadatos al portapapeles

## 📖 Guías Detalladas

- [**INSTALAR_FFMPEG.md**](./INSTALAR_FFMPEG.md) - Cómo instalar FFmpeg en Windows
- [**GUIA_PRUEBAS.md**](./GUIA_PRUEBAS.md) - Verificar que todo funciona correctamente
- [**METADATOS_GUIA.md**](./METADATOS_GUIA.md) - Explicación de cada campo de metadatos

## 🏗️ Estructura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada
├── home_movie_search_screen.dart # Pantalla principal
├── video_screen.dart            # Reproductor de video
├── video_metadata.dart          # Extracción de metadatos (core logic)
├── video_info_screen.dart       # UI para análisis de metadatos
├── video_scanner.dart           # Escaneo de videos locales
├── search_paths_screen.dart     # Gestión de directorios de búsqueda
├── search_paths_store.dart      # Persistencia de directorio
└── movie_utils.dart             # Utilidades generales
```

## 📦 Dependencias Principales

- **media_kit** - Reproducción de video multiplataforma
- **media_kit_video** - Controls de video
- **file_picker** - Selección de archivos
- **permission_handler** - Manejo de permisos
- **dio** - Cliente HTTP
- **path_provider** - Acceso a directorios

## ⚙️ Cómo Funciona la Extracción de Metadatos

### Flujo Principal
```
Usuario selecciona archivo/URL
        ↓
    [video_metadata.dart]
  getVideoMetadata(path)
        ↓
    Intenta FFprobe ← 📌 Requiere FFmpeg instalado
        ↓
    ¿FFprobe exitoso? 
    ├─ SÍ → Parsea JSON → Datos completos ✅
    └─ NO → Fallback a análisis de nombre del archivo
            Detecta patrones (resolution, codec, idioma)
            → Datos parciales ⚠️
        ↓
    [video_info_screen.dart]
   Muestra en UI formateado
```

### Metadatos Extraídos

**Información General:**
- Formato
- Duración
- Tamaño en MB
- Codecs contenedor

**Video:**
- Resolución (píxeles)
- Codec de video
- Bitrate
- FPS (fotogramas por segundo)
- Aspect ratio

**Audio:**
- Codec
- Idiomas disponibles
- Bitrate

**Subtítulos:**
- Idiomas con subtítulos

## 🔧 Desarrollo

### Ejecutar análisis
```bash
flutter analyze
```

### Ejecutar tests
```bash
flutter test
```

### Compilar para producción
```bash
# Windows
flutter build windows

# APK (Android)
flutter build apk

# iOS
flutter build ios
```

## 📝 Troubleshooting

### "Desconocido" en todos los campos
- Verifica que FFmpeg esté instalado correctamente
- Intenta con otro archivo de video
- Revisa GUIA_PRUEBAS.md para diagnóstico detallado

### La app se congela durante análisis
- Archivos muy grandes pueden tardar
- Archivos corruptos pueden causar timeout
- Reinicia la aplicación

### Error de permisos (Android/iOS)
- La app solicitará permisos al seleccionar archivo
- Asegúrate de permitir acceso a almacenamiento

## 🔐 Privacidad

- Los archivos se analizan **localmente** (no se envían servidores)
- FFprobe se ejecuta en tu máquina
- No se recopilan datos sobre los videos

## 📄 Licencia

Este proyecto es de código abierto.

## 👨‍💻 Desarrollo

Creado y mantenido por el equipo de Deventic.

### Stack Técnico
- **Framework**: Flutter (Dart)
- **Metadatos**: FFmpeg/FFprobe
- **UI**: Material Design
- **Plataformas**: Windows, Android, iOS, Linux, macOS, Web

---

¿Preguntas? Consulta las guías o revisa la sección de troubleshooting.
