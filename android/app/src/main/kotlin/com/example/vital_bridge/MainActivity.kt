package com.example.vital_bridge

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "vital_bridge/permisos_sistema"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configurarPantallaBloqueo()
    }

    override fun onResume() {
        super.onResume()
        configurarPantallaBloqueo()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        configurarPantallaBloqueo()
    }

    private fun configurarPantallaBloqueo() {
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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
    }

    private fun abrirAjustesApp() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
