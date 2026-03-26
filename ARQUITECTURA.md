# 🎯 Filmoly - Flujo de Funcionamiento

## Pantalla Principal
```
┌─────────────────────────────────────────┐
│  🏠 Filmoly - Gestor de Videos         │
├─────────────────────────────────────────┤
│                                         │
│  [Buscar Películas]                    │
│  [Reproducir Video]                    │
│  [📊 Analizar Metadatos de Video]      │ ← NUEVO
│  [Configurar Rutas de Búsqueda]        │
│                                         │
└─────────────────────────────────────────┘
```

## Pantalla de Análisis de Metadatos

```
┌────────────────────────────────────────────────┐
│  📊 Analizar Metadatos de Video                │
├────────────────────────────────────────────────┤
│                                                │
│  Archivo/URL:                                  │
│  [__________________.mp4____________][📁Elegir]│
│                                                │
│                 [📊 Analizar]                 │
│                                                │
├────────────────────────────────────────────────┤
│ 📌 INFORMACIÓN GENERAL                         │
│  ├─ Formato: MP4                              │
│  ├─ Duración: 1:45:23                         │
│  └─ Tamaño: 1250.5 MB                         │
├────────────────────────────────────────────────┤
│ 🎬 INFORMACIÓN DE VIDEO                        │
│  ├─ Resolución: 1920x1080 (Full HD)           │
│  ├─ Codec: H.264 (AVC)                        │
│  ├─ Bitrate: 5000 kbps                        │
│  ├─ FPS: 23.98                                │
│  └─ Aspect Ratio: 16:9                        │
├────────────────────────────────────────────────┤
│ 🔊 INFORMACIÓN DE AUDIO                        │
│  ├─ Codec: AAC                                │
│  ├─ Idiomas: [English, Spanish, French]       │
│  └─ Bitrate: 320 kbps                         │
├────────────────────────────────────────────────┤
│ 📝 SUBTÍTULOS                                  │
│  └─ Disponibles en: [English, Spanish]        │
├────────────────────────────────────────────────┤
│                    [📋 Copiar todo]            │
└────────────────────────────────────────────────┘
```

## Proceso de Extracción de Metadatos

```
                    ┌─────────────────┐
                    │ Usuario Selecciona│
                    │   Video/URL      │
                    └────────┬─────────┘
                             │
                    ┌────────▼──────────┐
                    │ video_info_screen │
                    │ Llama a análisis   │
                    └────────┬──────────┘
                             │
                    ┌────────▼──────────────┐
                    │getVideoMetadata()     │
                    │(video_metadata.dart)  │
                    └────────┬──────────────┘
                             │
                ┌────────────┴────────────────┐
                │                            │
        ┌───────▼────────────┐    ┌─────────▼──────────┐
        │ Intenta FFprobe    │    │ ¿FFprobe instalado?│
        │ (Process.run)      │    └─────────┬──────────┘
        │                    │              │
        ├─┬──────────────────┤    ┌─────────┴──────────┐
        │ │ Windows: Busca   │    │                    │
        │ │ en rutas comunes │    │ SÍ             NO  │
        │ │ C:\ffmpeg\bin\   │    │                    │
        │ └──────────────────┘    │        ┌───────────┼──────────┐
        │                         │   [ÉXITO]      [FALLBACK]    │
        │                         │        │           │         │
        └────────────┬───────────────────┬─┘        ┌──▼────────┐│
                     │                   │          │ Analiza   ││
            ┌────────▼────────┐         │          │ Nombre    ││
            │ Parseador JSON  │         │          │ Archivo   ││
            │ (Type-safe)     │         │          └──┬────────┘│
            │                 │         │             │        │
            │ ✓ Resolución    │         │     ┌─────────▼──────┐│
            │ ✓ Codecs        │         │     │ Detecta:       ││
            │ ✓ Duration      │         │     │ 720p, 1080p... ││
            │ ✓ Audio idiomas │         │     │ h264, h265...  ││
            │ ✓ Subtítulos    │    ┌────┼─────│ ENG, SPA...    ││
            │                 │    │    │     └───────┬────────┘│
            └────────┬────────┘    │    │             │        │
                     │             │    │             │        │
            ┌────────▼─────────────┴────▼─────────────▼────────┐
            │        VideoMetadata Object (completo)            │
            │  ✓ Title, duration, bitrate, resolution...       │
            │  ⚠ Algunos campos pueden ser "unknown"            │
            └────────┬──────────────────────────────────────────┘
                     │
            ┌────────▼──────────┐
            │ video_info_screen │
            │ Renderiza UI con  │
            │ Tarjetas Material │
            └──────────────────┘
```

## Flujo de Instalación FFmpeg (Windows)

```
┌─────────────────────────────────────────┐
│ ¿FFmpeg Instalado?                      │
├─────────────────────────────────────────┤
│                                         │
│   NO                    SÍ              │
│    │                     │              │
│    ▼                     ▼              │
│ Opción A:          Verifica en:        │
│ Chocolatey:        C:\ffmpeg\bin\      │
│ choco install      Program Files\      │
│ ffmpeg             (x86)\ffmpeg\       │
│                                         │
│ Opción B:                              │
│ Winget:                                │
│ winget install                         │
│ FFmpeg                                 │
│                                         │
│ Opción C:                              │
│ Descarga + PATH                        │
│ 1. Descarga .zip                       │
│ 2. Extrae a C:\ffmpeg                  │
│ 3. Añade a PATH                        │
│    en Variables Entorno                │
│                                         │
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│ Verifica:                               │
│ ffprobe -version                        │
│                                         │
│ ✓ Muestra versión → LISTO              │
│ ✗ Comando no encontrado → Revisar PATH│
└─────────────────────────────────────────┘
```

## Interacción del Usuario

```
1. INICIO
   └─ Usuario abre Filmoly → Pantalla principal

2. SELECCIONA ANÁLISIS
   └─ Toca botón "📊 Analizar Metadatos"
      └─ Abre VideoInfoScreen

3. ELIGE ARCHIVO O INGRESA URL
   ├─ Opción A: Botón "📁 Elegir"
   │  └─ File Picker → Permite seleccionar video
   │     └─ Campo se llena con ruta
   │
   └─ Opción B: Escribe URL
      └─ Ingresa "https://example.com/video.mp4"
         └─ Campo se llena con URL

4. INICIA ANÁLISIS
   └─ Toca botón "📊 Analizar"
      └─ Aparece loading spinner
      
5. ESPERA PROCESAMIENTO
   └─ video_metadata.dart ejecuta FFprobe
      └─ Parseador JSON procesa respuesta
         └─ O fallback a nombre de archivo

6. VE RESULTADOS
   └─ 4 tarjetas con información:
      ├─ Información General
      ├─ Video
      ├─ Audio
      └─ Subtítulos

7. COPIA METADATOS (Opcional)
   └─ Botón "📋 Copiar todo"
      └─ Metadatos en clipboard
         └─ Puede pegar en editor, email, etc.
```

## Stack de Tecnologías

```
┌─────────────────────────────────────────┐
│          INTERFAZ DE USUARIO             │
│     (Material Design - Flutter UI)       │
├─────────────────────────────────────────┤
│      VideoInfoScreen (Dart)              │
│   ├─ TextField para archivo/URL          │
│   ├─ File Picker integration             │
│   ├─ Tarjetas de información             │
│   └─ Botón de copiar                     │
├─────────────────────────────────────────┤
│      LÓGICA DE METADATA (Dart)           │
│      video_metadata.dart                 │
│   ├─ FFprobe JSON parsing                │
│   ├─ Fallback filename analysis          │
│   └─ Type-safe data handling             │
├─────────────────────────────────────────┤
│    PROCESO NATIVO (Windows PowerShell)   │
│      Process.run('ffprobe')              │
│   ├─ Detecta ffprobe.exe automáticamente │
│   ├─ Windows path detection              │
│   └─ Fallback a PATH variable            │
├─────────────────────────────────────────┤
│      HERRAMIENTA EXTERNA                 │
│      FFmpeg/FFprobe (ffprobe.exe)        │
│   └─ Extrae metadata de video            │
└─────────────────────────────────────────┘
```

## Dependencias Flutter

```
pubspec.yaml
├─ media_kit: ^1.2.6           (Reproducción video)
├─ media_kit_video: ^2.0.1     (Controles video)
├─ file_picker: ^8.0.0         (Seleccionar archivos)
├─ permission_handler: ^12.0.1 (Permisos de acceso)
├─ dio: ^5.2.1                 (Requests HTTP)
├─ path_provider: ^2.0.0       (Acceso directorios)
└─ (ffmpeg_kit_flutter removed - no Windows support)
```

---

**Diagrama generado**: 2024
**Estado**: ✅ Listo para testing
