package com.example.vital_bridge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmaReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AlarmaReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        val payload = intent.getStringExtra("payload")
        Log.i(TAG, "AlarmaReceiver despertado por AlarmManager con payload: $payload")

        AlarmaLanzador.despertarYLanzarApp(context, payload)
    }
}

