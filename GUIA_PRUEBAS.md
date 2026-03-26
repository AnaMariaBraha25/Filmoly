# ✅ Guía de Pruebas de Metadatos de Video

Esta guía te ayudará a verificar que la funcionalidad de extracción de metadatos está funcionando correctamente.

## Prueba 1: Preparación

### Paso 1.1: Instala FFmpeg
Sigue el documento `INSTALAR_FFMPEG.md` si aún no lo has hecho.

### Paso 1.2: Verifica FFmpeg
Abre PowerShell y ejecuta:
```powershell
ffprobe -version
```
Deberías ver la versión de FFmpeg. Ejemplo:
```
ffprobe version 6.0 Copyright (c) 2007-2023 the FFmpeg developers
```

### Paso 1.3: Inicia la app
```powershell
flutter run -d windows
```

## Prueba 2: Análisis de Archivo Local

### Paso 2.1: Abre la pantalla de metadatos
En la app, busca el botón **"📊 Analizar Metadatos de Video"** en la pantalla principal y haz clic en él.

### Paso 2.2: Selecciona un archivo
- Haz clic en el campo de texto para **seleccionar un archivo local**
- Selecciona un archivo `.mp4`, `.mkv`, `.avi` o cualquier video que tengas
- El campo debería mostrar la ruta del archivo

### Paso 2.3: Analiza el video
- Haz clic en el botón **"Analizar"**
- Espera a que aparezcan los resultados

### Paso 2.4: Verifica los resultados
Deberías ver 4 secciones de información:

#### **📌 Información General:**
- Formato
- Duración
- Tamaño en MB

#### **🎬 Información de Video:**
- Resolución (ejemplo: 1920x1080)
- Codec
- Bitrate
- FPS (fotogramas por segundo)
- Aspect Ratio

#### **🔊 Información de Audio:**
- Codec
- Idiomas detectados
- Bitrate de audio

#### **📝 Subtítulos:**
- Idiomas de subtítulos detectados

### Paso 2.5: Prueba el botón de copiar
- Haz clic en **"📋 Copiar todo"**
- Abre un editor de texto (Notepad)
- Pega (`Ctrl+V`) - deberías ver toda la información formateada

## Prueba 3: Análisis de URL Web

### Paso 3.1: Usa una URL en lugar de un archivo
En el campo de texto, escribe una URL completa de un video, ejemplo:
```
https://example.com/video.mp4
```

### Paso 3.2: Analiza
- Haz clic en **"Analizar"**
- El sistema intentará descargar el archivo temporalmente y extraer metadatos

**Nota:** Dependiendo del tamaño y la velocidad de internet, esto puede tardar más tiempo.

## Prueba 4: Casos de Fallback (Sin FFprobe)

Si FFprobe no está disponible, la app debería:
- Intentar extraer información del **nombre del archivo**
- Patterns que detecta automáticamente:
  - Resoluciones: `720p`, `1080p`, `4K`, `2K`, etc.
  - Codecs: `h264`, `h265`, `HEVC`, `VP9`, etc.
  - Idiomas: `ENG`, `SPA`, `FRA`, etc. (códigos de 3 letras)

Ejemplo: `Película.1080p.H264.ENG.mp4` debería detectar:
- Resolución: 1080p
- Codec: H264
- Idioma de audio: English

## Verificación de Console Output

Para ver qué está pasando internamente:

### Paso 1: Habilita la consola de Flutter
Durante `flutter run`, abrirá una consola de Windows.

### Paso 2: Busca estos mensajes:
```
FFprobe encontrado en: C:\ffmpeg\bin\ffprobe.exe
FFprobe stdout length: XXXX
Parsing FFprobe JSON...
```

### Paso 3: Si ves errores:
```
FFprobe process error: ...
Usando fallback de nombre de archivo
```

Esto significa que FFprobe no se encontró, pero la app seguirá intentando extraer información.

## Tabla de Verificación

| Función | Esperado | Estado |
|---------|----------|--------|
| Botón de análisis exists | Visible en pantalla principal | ✓ |
| Seleccionar archivo | Abre file picker | ✓ |
| Analizar video local | Muestra metadatos | ✓ |
| Copiar metadatos | Copia formateado | ✓ |
| Detectar resolución | Muestra px correctos | ✓ |
| Detectar codecs | Muestra codec correcto | ✓ |
| Detectar duración | Muestra tiempo correcto | ✓ |
| Fallback de nombre | Detecta de filename | ✓ |

## Problemas Comunes y Soluciones

### "Error al analizar video"
- **Causa:** FFprobe no encontrado o archivo no accesible
- **Solución:** Verifica que FFmpeg esté instalado correctamente

### "Desconocido" en todos los campos
- **Causa:** FFprobe no pudo leer el archivo
- **Solución:** 
  - Intenta con otro archivo de video
  - Verifica que el archivo no esté corrupto
  - Intenta con un formato más común (MP4)

### La app se congela durante análisis
- **Causa:** La app está esperando a FFprobe
- **Solución:**
  - Archivos muy grandes pueden tardar más
  - Si se congela indefinidamente, reinicia la app
  - Intenta con archivos más pequeños primero

### "No se puede acceder al archivo"
- **Causa:** Falta de permisos de lectura
- **Solución:**
  - Mueve el video a una carpeta accesible (Documentos, Descargas)
  - Verifica que la carpeta no esté protegida

## Casos de Test Recomendados

Descarga estos archivos de prueba (si quieres automatizar tests):

1. **Video simple MP4**
   - Formato: MP4/H264
   - Resolución: 1920x1080
   - Audio: AAC estéreo
   - Duración: > 1 min

2. **Video MKV (Matroska)**
   - Múltiples pistas de audio
   - Subtítulos incrustados
   - Codecs modernos (H265/HEVC)

3. **Video con múltiples idiomas**
   - Pistas de audio: EN, ES, FR
   - Subtítulos: EN, ES, FR
   - Verifica que todos se detecten

## Éxito

Si logras:
✅ Ver metadatos completos (no "desconocido")
✅ Copiar metadatos al clipboard
✅ Analizar múltiples formatos

**¡Entonces todo está funcionando correctamente!** 🎉

---

Si encuentras problemas, anota:
- Qué tipo de archivo estabas analizando
- Qué mostró la consola
- Qué resultado esperabas
- Qué resultado obtuviste
