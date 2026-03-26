# Script para copiar libmpv-2.dll a los directorios de output después del build
$sourceDir = "$PSScriptRoot\windows\runner\lib"
$debugDir = "$PSScriptRoot\build\windows\x64\runner\Debug"
$releaseDir = "$PSScriptRoot\build\windows\x64\runner\Release"

$sourceDll = "$sourceDir\libmpv-2.dll"

if (Test-Path $sourceDll) {
    Write-Host "Encontrada DLL en: $sourceDll"
    
    if (Test-Path $debugDir) {
        Copy-Item -Path $sourceDll -Destination "$debugDir\" -Force
        Write-Host "DLL copiada a Debug: $debugDir\libmpv-2.dll"
    }
    
    if (Test-Path $releaseDir) {
        Copy-Item -Path $sourceDll -Destination "$releaseDir\" -Force
        Write-Host "DLL copiada a Release: $releaseDir\libmpv-2.dll"
    }
} else {
    Write-Host "ERROR: No se encontró libmpv-2.dll en $sourceDll"
    exit 1
}
