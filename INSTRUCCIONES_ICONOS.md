# 📱 Instrucciones para Corregir Iconos Estirados - Android

## ✅ Configuración Completada

### Archivos Modificados:

1. **pubspec.yaml**
   - ✅ Configuración de `flutter_launcher_icons` actualizada
   - ✅ `adaptive_icon_background: "#FFFFFF"` (fondo blanco)
   - ✅ `adaptive_icon_foreground: "assets/logo.empresa.png"`

2. **AndroidManifest.xml**
   - ✅ `android:icon="@mipmap/ic_launcher"`
   - ✅ `android:roundIcon="@mipmap/ic_launcher_round"` (agregado)

3. **Archivos XML de Adaptive Icons**
   - ✅ `mipmap-anydpi-v26/ic_launcher.xml` (ya existía)
   - ✅ `mipmap-anydpi-v26/ic_launcher_round.xml` (creado)

4. **Iconos Generados**
   - ✅ Iconos en todas las resoluciones: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi
   - ✅ Foreground icons en drawable-* para adaptive icons

## ⚠️ PROBLEMA CRÍTICO: Padding del 40%

### ¿Por qué se ve estirado?

Android Adaptive Icons requiere que el logo tenga **40% de espacio vacío (padding)** alrededor. Si tu imagen `assets/logo.empresa.png` tiene el logo tocando los bordes, Android lo estirará automáticamente.

### Solución: Preparar la Imagen Correctamente

#### Requisitos de la Imagen:

1. **Tamaño:** Mínimo 1024x1024 píxeles (cuadrada)
2. **Formato:** PNG
3. **Padding:** El logo debe ocupar solo el **60% central**
   - 20% de espacio vacío arriba
   - 20% de espacio vacío abajo
   - 20% de espacio vacío izquierda
   - 20% de espacio vacío derecha

#### Visualización del Requisito:

```
┌─────────────────────────────┐
│                             │ ← 20% padding superior
│                             │
│    ┌─────────────────┐      │
│    │                 │      │
│    │                 │      │
│    │      LOGO       │      │ ← 60% área del logo
│    │                 │      │
│    │                 │      │
│    └─────────────────┘      │
│                             │
│                             │ ← 20% padding inferior
└─────────────────────────────┘
     ↑                 ↑
  20% padding      20% padding
```

### Cómo Preparar la Imagen:

#### Opción 1: Usar GIMP (Gratis)

1. Abre GIMP
2. Archivo → Nuevo → 1024x1024 píxeles
3. Fondo: Blanco (#FFFFFF)
4. Importa tu logo
5. Redimensiona el logo al 60% del tamaño (614x614 píxeles)
6. Centra el logo (debe haber ~205 píxeles de espacio en cada lado)
7. Exporta como PNG: `assets/logo.empresa.png`

#### Opción 2: Usar Photoshop

1. Crear nuevo documento: 1024x1024 px, fondo blanco
2. Importar logo
3. Redimensionar logo a 60% (614x614 px)
4. Centrar con guías (205px desde cada borde)
5. Guardar como PNG

#### Opción 3: Usar Herramienta Online

1. Busca "add padding to image online" en Google
2. Sube tu logo
3. Agrega 20% de padding en cada lado
4. Descarga la imagen resultante
5. Reemplaza `assets/logo.empresa.png`

#### Opción 4: Usar ImageMagick (Línea de Comandos)

```bash
# Instalar ImageMagick primero
# Luego ejecutar:
magick convert assets/logo.empresa.png -gravity center -background white -extent 1024x1024 -resize 60% -gravity center -extent 1024x1024 assets/logo.empresa.padded.png
```

## 🔧 Comandos para Regenerar Iconos

### 1. Limpiar iconos antiguos:
```powershell
Remove-Item -Path "android\app\src\main\res\mipmap-*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "android\app\src\main\res\drawable-*\ic_launcher_foreground.png" -Force -ErrorAction SilentlyContinue
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

## ✅ Verificación Final

Después de regenerar los iconos, verifica:

1. **Archivos XML:**
   - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` ✅
   - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml` ✅

2. **Iconos PNG generados:**
   - `mipmap-mdpi/ic_launcher.png` ✅
   - `mipmap-hdpi/ic_launcher.png` ✅
   - `mipmap-xhdpi/ic_launcher.png` ✅
   - `mipmap-xxhdpi/ic_launcher.png` ✅
   - `mipmap-xxxhdpi/ic_launcher.png` ✅

3. **Foreground icons:**
   - `drawable-mdpi/ic_launcher_foreground.png` ✅
   - `drawable-hdpi/ic_launcher_foreground.png` ✅
   - (y en todas las demás resoluciones)

4. **AndroidManifest.xml:**
   - `android:icon="@mipmap/ic_launcher"` ✅
   - `android:roundIcon="@mipmap/ic_launcher_round"` ✅

## 🎯 Próximos Pasos

1. **Si el icono sigue viéndose estirado:**
   - La imagen `assets/logo.empresa.png` probablemente no tiene el padding del 40%
   - Debes crear una nueva versión de la imagen con el padding correcto
   - Sigue las instrucciones de "Cómo Preparar la Imagen" arriba

2. **Después de preparar la imagen:**
   - Reemplaza `assets/logo.empresa.png` con la nueva versión
   - Ejecuta: `flutter pub run flutter_launcher_icons`
   - Limpia y recompila: `flutter clean && flutter build apk --release`
   - Desinstala la app anterior del dispositivo
   - Instala la nueva versión

## 📝 Notas Importantes

- **El padding es crítico:** Sin el 40% de padding, Android estirará el logo automáticamente
- **Tamaño mínimo:** La imagen debe ser al menos 1024x1024 píxeles
- **Formato:** PNG es el formato recomendado
- **Fondo:** El adaptive_icon_background está configurado como blanco (#FFFFFF)

---

**Estado Actual:** ✅ Configuración completada. Iconos regenerados.
**Acción Requerida:** Si el icono se ve estirado, preparar la imagen con padding del 40%.
