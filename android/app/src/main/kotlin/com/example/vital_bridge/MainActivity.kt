package com.example.vital_bridge

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "vital_bridge/permisos_sistema"
    private var methodChannel: MethodChannel? = null
    private var ultimoPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configurarPantallaBloqueo()
        val payload = extraerPayloadDeIntent(intent)
        if (!payload.isNullOrEmpty()) {
            ultimoPayload = payload
        }
    }

    override fun onResume() {
        super.onResume()
        configurarPantallaBloqueo()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        configurarPantallaBloqueo()
        val payload = extraerPayloadDeIntent(intent)
        if (!payload.isNullOrEmpty()) {
            ultimoPayload = payload
        }
        procesarIntentAlarma(intent)
    }

    private fun extraerPayloadDeIntent(intent: Intent?): String? {
        if (intent == null) return null
        val extras = intent.extras ?: return null

        var payload = extras.getString("payload")
        if (payload.isNullOrEmpty()) {
            payload = extras.getString("notification_payload")
        }

        if (payload.isNullOrEmpty()) {
            val json = JSONObject()
            for (key in extras.keySet()) {
                val value = extras.get(key)
                if (value != null) {
                    json.put(key, value.toString())
                }
            }
            if (json.has("tipo") || json.has("idHorario") || json.has("idAlerta")) {
                payload = json.toString()
            }
        }
        return payload
    }

    private fun procesarIntentAlarma(intent: Intent?) {
        val payload = extraerPayloadDeIntent(intent) ?: ultimoPayload
        if (!payload.isNullOrEmpty()) {
            configurarPantallaBloqueo()
            methodChannel?.invokeMethod("onAlarmaRecibida", payload)
        }
    }

    private fun configurarPantallaBloqueo() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = powerManager?.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
                "vitalbridge:main_activity_wakelock"
            )
            wakeLock?.acquire(10000)
        } catch (_: Exception) {}

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        }
    }

    private fun restablecerPantallaBloqueo() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        }
        @Suppress("DEPRECATION")
        window.clearFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "obtenerPayloadAlarmaActual" -> {
                    val payload = ultimoPayload ?: extraerPayloadDeIntent(intent)
                    result.success(payload)
                }
                "programarAlarmaExactaNativa" -> {
                    val idHorario = call.argument<Int>("idHorario") ?: 0
                    val triggerTimeMillis = (call.argument<Number>("triggerTimeMillis") ?: 0).toLong()
                    val payload = call.argument<String>("payload") ?: ""
                    if (idHorario > 0 && triggerTimeMillis > 0) {
                        try {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                            if (alarmManager != null) {
                                val alarmIntent = Intent(this, AlarmaReceiver::class.java).apply {
                                    action = "com.example.vital_bridge.ALARM_TRIGGER"
                                    putExtra("idHorario", idHorario)
                                    putExtra("payload", payload)
                                }
                                val pendingIntent = PendingIntent.getBroadcast(
                                    this,
                                    idHorario,
                                    alarmIntent,
                                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                                )
                                val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerTimeMillis, pendingIntent)
                                alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                                Log.i("MainActivity", "Alarma nativa programada para idHorario $idHorario")
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error programando alarma nativa: ${e.message}")
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "cancelarAlarmaNativa" -> {
                    val idHorario = call.argument<Int>("idHorario") ?: 0
                    if (idHorario > 0) {
                        try {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                            if (alarmManager != null) {
                                val alarmIntent = Intent(this, AlarmaReceiver::class.java).apply {
                                    action = "com.example.vital_bridge.ALARM_TRIGGER"
                                }
                                val pendingIntent = PendingIntent.getBroadcast(
                                    this,
                                    idHorario,
                                    alarmIntent,
                                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                                )
                                alarmManager.cancel(pendingIntent)
                                Log.i("MainActivity", "Alarma nativa cancelada para idHorario $idHorario")
                            }
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "abrirEnlace" -> {
                    val url = call.argument<String>("url")
                    if (!url.isNullOrEmpty()) {
                        try {
                            val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(browserIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR_URL", e.message, null)
                        }
                    } else {
                        result.error("URL_VACIA", "La URL está vacía", null)
                    }
                }
                "verificarPermisoAlarmasExactas" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        result.success(alarmManager.canScheduleExactAlarms())
                    } else {
                        result.success(true)
                    }
                }
                "abrirAjustesAlarmasExactas" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            abrirAjustesApp()
                            result.success(true)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "verificarPermisoAparecerEncima" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "abrirAjustesAparecerEncima" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            abrirAjustesApp()
                            result.success(true)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "verificarPermisoPantallaCompleta" -> {
                    if (Build.VERSION.SDK_INT >= 34) {
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                        result.success(notificationManager?.canUseFullScreenIntent() ?: true)
                    } else {
                        result.success(true)
                    }
                }
                "abrirAjustesPantallaCompleta" -> {
                    if (Build.VERSION.SDK_INT >= 34) {
                        try {
                            val intent = Intent("android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT").apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            abrirAjustesApp()
                            result.success(true)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "abrirAjustesApp" -> {
                    abrirAjustesApp()
                    result.success(true)
                }
                "estaPantallaBloqueada" -> {
                    val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                    result.success(keyguardManager?.isKeyguardLocked ?: false)
                }
                "cancelarTodasLasNotificaciones" -> {
                    try {
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                        notificationManager?.cancel(9999)
                        notificationManager?.cancelAll()
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "cerrarPantallaAlarma" -> {
                    try {
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                        notificationManager?.cancel(9999)
                        notificationManager?.cancelAll()
                    } catch (_: Exception) {}
                    restablecerPantallaBloqueo()
                    finish()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        procesarIntentAlarma(intent)
    }

    private fun abrirAjustesApp() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
