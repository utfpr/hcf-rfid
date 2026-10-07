package com.example.beontag_utfpr_agro_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/** Keeps the process alive in background so the reader connection is not dropped. */
class ReaderConnectionService : Service() {

    companion object {
        private const val TAG = "ReaderConnectionService"
        private const val CHANNEL_ID = "reader_connection"
        private const val CHANNEL_NAME = "Conexão com o leitor"
        private const val NOTIFICATION_ID = 1001

        /** Invoked when the user removes the app from recents; must release the readers. */
        @Volatile
        var onTaskRemovedListener: (() -> Unit)? = null

        fun start(context: Context) {
            ContextCompat.startForegroundService(
                context,
                Intent(context, ReaderConnectionService::class.java)
            )
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ReaderConnectionService::class.java))
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.d(TAG, "Foreground service started")
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed: releasing readers")
        onTaskRemovedListener?.invoke()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        Log.d(TAG, "Foreground service stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply { setShowBadge(false) }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    private fun buildNotification() = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_stat_reader)
        .setContentTitle("Leitor RFID conectado")
        .setContentText("A conexão com o leitor é mantida em segundo plano.")
        .setOngoing(true)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setCategory(NotificationCompat.CATEGORY_SERVICE)
        .setContentIntent(buildContentIntent())
        .build()

    private fun buildContentIntent(): PendingIntent? {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        return PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }
}
