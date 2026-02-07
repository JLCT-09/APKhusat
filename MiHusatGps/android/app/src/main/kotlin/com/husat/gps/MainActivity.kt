package com.husat.gps

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // DIAGNÓSTICO: Forzar formato de 32 bits con opacidad total
        // RGBA_8888 es un formato estándar de Android que asegura que no haya transparencias bloqueando la vista
        // Esto puede ayudar a resolver problemas de renderizado en dispositivos Xiaomi
        window.setFormat(android.graphics.PixelFormat.RGBA_8888)
        
        // 1. Forzar aceleración de hardware
        window.addFlags(WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED)
        // 2. Evitar que la pantalla se quede en negro por seguridad de ventana
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun onPostResume() {
        super.onPostResume()
        // 3. Forzar un refresco de la ventana cuando la app vuelve al foco
        window.decorView.requestLayout()
    }
}
