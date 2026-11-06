package co.edu.udes.ecoresiduos

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        crearCanalNovedades()
    }

    // Canal de las notificaciones que manda la Edge Function enviar-push
    // (channel_id "novedades"). En Ajustes, la persona lo ve con este nombre y
    // puede silenciarlo sin apagar todas las notificaciones de la app.
    private fun crearCanalNovedades() {
        // Los canales existen desde Android 8 (API 26); antes no hacen falta.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val canal = NotificationChannel(
            "novedades",
            "Novedades",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Ofertas, recolecciones, certificados y cambios en tu cuenta"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(canal)
    }
}
