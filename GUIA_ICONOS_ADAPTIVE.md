# 🎨 Guía de Configuración de Adaptive Icons - Android

## 📋 Problema Resuelto

El icono de la aplicación se veía estirado porque no tenía el padding correcto requerido por Android Adaptive Icons.

## ✅ Configuración Aplicada

### 1. **pubspec.yaml**
```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/logo.empresa.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/logo.empresa.png"
  android_adaptive_icon_foreground: "assets/logo.empresa.png"
  android_adaptive_icon_background: "#FFFFFF"
```

### 2. **AndroidManifest.xml**
- ✅ `android:icon="@mipmap/ic_launcher"`
- ✅ `android:roundIcon="@mipmap/ic_launcher_round"`

### 3. **Archivos XML de Adaptive Icons**
- ✅ `mipmap-anydpi-v26/ic_launcher.xml`
- ✅ `mipmap-anydpi-v26/ic_launcher_round.xml`

## ⚠️ IMPORTANTE: Preparación de la Imagen

### Requisitos para evitar estiramiento:

1. **Tamaño de la imagen:**
   - Mínimo: 1024x1024 píxeles
   - Formato: PNG (preferiblemente sin transparencia para el foreground)

2. **Padding del 40% (CRÍTICO):**
   - El logo debe ocupar solo el **60% central** de la imagen
   - Debe haber un **20% de espacio vacío** en cada lado (arriba, abajo, izquierda, derecha)
   - **Total: 40% de padding alrededor del logo**

### Ejemplo Visual:
```
┌─────────────────────────┐
│                         │ ← 20% padding superior
│    ┌─────────────┐      │
│    │             │      │
│    │    LOGO     │      │ ← 60% área del logo
│    │             │      │
│    └─────────────┘      │
│                         │ ← 20% padding inferior
└─────────────────────────┘
     ↑         ↑
  20% padding  20% padding
```

### Si tu imagen NO tiene padding:

**Opción 1: Usar una herramienta de edición de imágenes**
1. Abre `assets/logo.empresa.png` en un editor (GIMP, Photoshop, etc.)
2. Crea un canvas de 1024x1024 píxeles
3. Coloca el logo centrado ocupando solo el 60% del área
4. Guarda como PNG

**Opción 2: Usar ImageMagick (línea de comandos)**
```bash
# Agregar padding del 40% a una imagen existente
magick convert assets/logo.empresa.png -gravity center -background transparent -extent 1024x1024 -resize 60% -gravity center -extent 1024x1024 assets/logo.empresa.padded.png
```

**Opción 3: Usar un servicio online**
- Busca "add padding to image" en Google
- Sube tu logo y agrega 20% de padding en cada lado

## 🔧 Comandos para Regenerar Iconos

### 1. Limpiar iconos antiguos:
```powershell
Remove-Item -Path "android\app\src\main\res\mipmap-*" -Recurse -Force
Remove-Item -Path "android\app\src\main\res\drawable-*\ic_launcher_foreground.png" -Force
```

### 2. Regenerar iconos:
```bash
flutter pub run flutter_launcher_icons
```

### 3. Limpiar y recompilar:
```bash
flutter clean
flutter pub get
flutter build apk --release
```

## ✅ Verificación

Después de regenerar los iconos, verifica:

1. **Archivos generados:**
   - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` ✅
   - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml` ✅
   - `android/app/src/main/res/mipmap-*/ic_launcher.png` (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi) ✅
   - `android/app/src/main/res/drawable-*/ic_launcher_foreground.png` ✅

2. **AndroidManifest.xml:**
   - Debe tener `android:icon="@mipmap/ic_launcher"` ✅
   - Debe tener `android:roundIcon="@mipmap/ic_launcher_round"` ✅

3. **Instalación:**
   - Desinstala la app anterior del dispositivo
   - Instala la nueva versión
   - Verifica que el icono no se vea estirado

## 🎯 Solución Aplicada

✅ Configuración de adaptive icons actualizada
✅ Archivo `ic_launcher_round.xml` creado
✅ AndroidManifest.xml actualizado con `roundIcon`
✅ Iconos regenerados con la nueva configuración
✅ Color de fondo configurado en `colors.xml`

## 📝 Notas Importantes

- **Si el icono sigue viéndose estirado:** La imagen original probablemente no tiene el padding del 40%. Debes preparar una nueva imagen con el padding correcto.
- **El adaptive_icon_foreground debe ser PNG:** Preferiblemente sin transparencia o con fondo sólido.
- **El adaptive_icon_background puede ser:** Color sólido (#FFFFFF) o una imagen de fondo.

---

**Estado:** ✅ Configuración completada. Iconos regenerados correctamente.
