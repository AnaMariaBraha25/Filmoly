# 📥 Instalación de FFmpeg en Windows

Para que la aplicación pueda extraer metadatos de video correctamente, necesitas instalar FFmpeg (que incluye FFprobe).

## Opción 1: Instalación Automática (Recomendado)

### Usando Chocolatey (más fácil)
1. Abre PowerShell como administrador
2. Ejecuta:
```powershell
choco install ffmpeg
```

### Usando Winget (si tienes Windows 10/11 actualizado)
```powershell
winget install FFmpeg
```

## Opción 2: Descarga Manual

1. Descarga FFmpeg desde: https://ffmpeg.org/download.html
2. Selecciona la versión para Windows (generalmente "Windows builds from zeranoe.com" u otra fuente)
3. Extrae el archivo ZIP a: `C:\ffmpeg`
4. La estructura debería ser: `C:\ffmpeg\bin\ffprobe.exe`

## Opción 3: Agregar a Variable de Entorno PATH

Si prefieres instalar en otra ubicación:

1. **Descarga e instala** FFmpeg en la carpeta que prefieras
2. **Abre Variables de Entorno:**
   - Presiona `Win + X` → Selecciona "Sistema"
   - Haz clic en "Configuración avanzada del sistema"
   - Haz clic en "Variables de entorno"
   
3. **Edita PATH:**
   - Busca la variable "Path" en "Variables de usuario"
   - Haz clic en "Editar"
   - Haz clic en "Nuevo"
   - Añade: `C:\ffmpeg\bin` (o la carpeta donde instalaste)
   - Haz clic en "Aceptar"

4. **Reinicia** la aplicación de Flutter

## Verificar que Funciona

Abre PowerShell y escribe:
```powershell
ffprobe -version
```

Si ves información sobre la versión, ¡está instalado correctamente!

## Ubicaciones que la App Busca Automáticamente

La aplicación buscará FFprobe en estas ubicaciones:
- `C:\ffmpeg\bin\ffprobe.exe`
- `C:\Program Files\ffmpeg\bin\ffprobe.exe`
- `C:\Program Files (x86)\ffmpeg\bin\ffprobe.exe`
- O en la variable PATH del sistema

## Si Aún No Funciona

1. **Instala FFmpeg nuevamente**, asegúrate de que incluya ffprobe
2. **Reinicia tu computadora** después de instalar
3. **Cierra y vuelve a abrir** la aplicación de Flutter
4. Si sigue sin funcionar, la app usará fallback: extraerá información del nombre del archivo

## ¿Qué es FFmpeg?

FFmpeg es una herramienta poderosa de línea de comandos para procesar video y audio. FFprobe es una parte de FFmpeg que se especializa en extraer información de archivos multimedia sin procesarlos.

---

Una vez instalado, la aplicación podrá:
✅ Extraer resolución exacta  
✅ Detectar codec de video  
✅ Calcular bitrate  
✅ Detectar idiomas de audio  
✅ Encontrar codecs de audio  
✅ Detectar subtítulos  
✅ Obtener duración exacta  
✅ Y más...
