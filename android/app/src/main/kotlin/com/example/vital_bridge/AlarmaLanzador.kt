package com.example.vital_bridge

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

object AlarmaLanzador {
    private const val TAG = "AlarmaLanzador"

    fun despertarYLanzarApp(context: Context, payloadJson: String?) {
        try {
            // 1. Despertar la pantalla física del teléfono mediante WakeLock de alta luminosidad
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = powerManager?.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
                "vitalbridge:alarma_despertar_wakelock"
            )
            wakeLock?.acquire(15000) // 15 segundos máximo para permitir inicialización

            // 2. Verificar condiciones de visualización:
            // - Si la pantalla está bloqueada (Keyguard bloqueado), Android permite lanzar actividades sobre la pantalla de bloqueo
            // - Si el usuario está usando otra app, requiere el permiso Settings.canDrawOverlays
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            val estaBloqueado = keyguardManager?.isKeyguardLocked ?: false
            val puedeAparecerEncima = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(context)
            } else {
                true
            }

            Log.i(TAG, "despertarYLanzarApp - Pantalla bloqueada: $estaBloqueado, Permiso superposición: $puedeAparecerEncima")

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                putExtra("payload", payloadJson)
                putExtra("source", "alarm_launcher")
            }

            context.startActivity(launchIntent)
            Log.i(TAG, "MainActivity lanzada con éxito desde AlarmaLanzador.")
        } catch (e: Exception) {
            Log.e(TAG, "Error al lanzar MainActivity desde AlarmaLanzador: ${e.message}")
        }
    }
}

