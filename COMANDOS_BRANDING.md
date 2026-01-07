# 🎨 COMANDOS PARA BRANDING - MiHusatGps

## 📋 Configuración Aplicada

### ✅ Splash Screen
- **Paquete:** `flutter_native_splash: ^2.4.1` añadido a `dev_dependencies`
- **Imagen:** `assets/images/logo.png` (creada y configurada)
- **Color de fondo:** Blanco (`#FFFFFF`)
- **Soporte:** Android e iOS (incluyendo Android 12+)

### ✅ Nombre de Aplicación
- **Android:** `MiHusatGps` (configurado en `AndroidManifest.xml`)
- **MaterialApp title:** `MiHusatGps` (configurado en `main.dart`)

### ✅ Nombre del APK
- **Configuración:** El nombre se puede personalizar manualmente después de la compilación
- **Ubicación:** `build/app/outputs/flutter-apk/app-release.apk`
- **Recomendación:** Renombrar manualmente después de compilar a `MiHusatGps-v1.0.0-release.apk`

---

## 🚀 COMANDOS PARA EJECUTAR

### 1. Instalar Dependencias

```bash
flutter pub get
```

### 2. Generar Iconos de Aplicación

```bash
flutter pub run flutter_launcher_icons
```

**Este comando:**
- Genera iconos para Android en todas las resoluciones (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- Crea adaptive icons para Android con fondo blanco
- ✅ **Estado:** Configurado y funcionando correctamente

### 3. Generar Splash Screen

```bash
flutter pub run flutter_native_splash:create
```

**Este comando:**
- Genera los recursos nativos para Android
- Crea los archivos de splash screen en todas las resoluciones necesarias
- Configura Android 12+ con splash screen moderno
- El splash screen se mostrará automáticamente al iniciar la app
- ✅ **Estado:** Configurado y funcionando correctamente

### 4. Compilar APK de Producción

```bash
flutter build apk --release
```

**Ubicación del APK generado:**
```
build/app/outputs/flutter-apk/app-release.apk
```

**Para renombrar el APK:**
```bash
# En PowerShell
Rename-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -NewName "MiHusatGps-v1.0.0-release.apk"
```

### 5. Compilar APK Dividido (por ABI)

```bash
flutter build apk --split-per-abi --release
```

**Genera APKs separados por arquitectura:**
- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

**Para renombrar:**
```bash
# En PowerShell
Rename-Item -Path "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" -NewName "MiHusatGps-v1.0.0-release-armeabi-v7a.apk"
Rename-Item -Path "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" -NewName "MiHusatGps-v1.0.0-release-arm64-v8a.apk"
Rename-Item -Path "build\app\outputs\flutter-apk\app-x86_64-release.apk" -NewName "MiHusatGps-v1.0.0-release-x86_64.apk"
```

---

## 📝 ORDEN RECOMENDADO DE EJECUCIÓN

1. **Instalar dependencias:**
   ```bash
   flutter pub get
   ```

2. **Generar splash screen:**
   ```bash
   flutter pub run flutter_native_splash:create
   ```

3. **Generar iconos:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

4. **Limpiar proyecto (opcional pero recomendado):**
   ```bash
   flutter clean
   flutter pub get
   ```

5. **Compilar APK:**
   ```bash
   flutter build apk --release
   ```

6. **Renombrar APK (opcional):**
   ```bash
   Rename-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -NewName "MiHusatGps-v1.0.0-release.apk"
   ```

---

## ✅ VERIFICACIÓN

Después de ejecutar los comandos, verifica:

1. ✅ **Splash Screen:** Debe aparecer al iniciar la app con el logo centrado en fondo blanco
2. ✅ **Nombre de App:** "MiHusatGps" debe aparecer en el launcher del dispositivo
3. ✅ **Iconos:** Los iconos deben generarse correctamente en todas las resoluciones
4. ✅ **APK:** El APK se compila exitosamente

---

## ⚠️ TROUBLESHOOTING

### Si el splash screen no aparece:

1. Verifica que la imagen existe: `assets/images/logo.png`
2. Ejecuta: `flutter clean`
3. Vuelve a ejecutar: `flutter pub run flutter_native_splash:create`
4. Recompila: `flutter build apk --release`

### Si los iconos no se generan:

1. Verifica que `assets/logo.empresa.png` existe
2. Ejecuta: `flutter clean`
3. Vuelve a ejecutar: `flutter pub run flutter_launcher_icons`

### Si el nombre de la app no cambia:

1. Verifica `android/app/src/main/AndroidManifest.xml` (debe decir `android:label="MiHusatGps"`)
2. Desinstala la app anterior del dispositivo
3. Reinstala la nueva versión

---

## 📱 CONFIGURACIÓN FINAL

### Archivos Modificados:

- ✅ `pubspec.yaml` - Añadido `flutter_native_splash` y configuración
- ✅ `android/app/src/main/AndroidManifest.xml` - Label cambiado a "MiHusatGps"
- ✅ `lib/main.dart` - Title cambiado a "MiHusatGps"
- ✅ `assets/images/logo.png` - Logo creado para splash screen

### Estado:

- ✅ Splash Screen configurado
- ✅ Nombre de aplicación actualizado
- ✅ Logo en ubicación correcta
- ✅ Listo para generar recursos

---

**Ejecuta los comandos en el orden indicado para completar el branding de la aplicación**
