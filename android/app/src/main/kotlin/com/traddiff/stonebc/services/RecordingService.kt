package com.traddiff.stonebc.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.traddiff.stonebc.MainActivity
import com.traddiff.stonebc.R
import com.traddiff.stonebc.data.models.RideSession
import com.traddiff.stonebc.data.models.RouteRecordingMode
import com.traddiff.stonebc.data.models.Trackpoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Foreground service that streams FusedLocation updates into a running
 * [RideSession]. Exposes the session as a StateFlow via the companion holder
 * so the UI can observe without binding. Auto-pauses after 7 seconds of
 * no horizontal movement (>= 0.5 m/s resumes).
 */
class RecordingService : Service() {

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var trackingJob: Job? = null
    private var lastMotionMillis: Long = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startRecording(intent)
            ACTION_STOP -> stopRecording()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
    }

    private fun startRecording(intent: Intent) {
        startForegroundInCompatMode()

        val mode = runCatching {
            RouteRecordingMode.valueOf(intent.getStringExtra(EXTRA_RECORDING_MODE) ?: RouteRecordingMode.free.name)
        }.getOrDefault(RouteRecordingMode.free)

        val session = RideSession(
            id = UUID.randomUUID().toString(),
            startTimestamp = System.currentTimeMillis(),
            recordingMode = mode,
            routeId = intent.getStringExtra(EXTRA_ROUTE_ID),
            routeName = intent.getStringExtra(EXTRA_ROUTE_NAME),
            routeCategory = intent.getStringExtra(EXTRA_ROUTE_CATEGORY)
        )
        _sessionFlow.value = session
        lastMotionMillis = session.startTimestamp

        val locationService = LocationService(applicationContext)
        trackingJob = serviceScope.launch {
            locationService.locationUpdates(intervalMillis = 1_000L).collect { location ->
                val now = System.currentTimeMillis()
                val speed = if (location.hasSpeed()) location.speed else 0f
                val isMoving = speed >= MOTION_THRESHOLD_MPS
                if (isMoving) lastMotionMillis = now
                val paused = (now - lastMotionMillis) >= AUTO_PAUSE_MILLIS

                val trackpoint = Trackpoint(
                    latitude = location.latitude,
                    longitude = location.longitude,
                    elevationMeters = if (location.hasAltitude()) location.altitude else null,
                    speedMetersPerSecond = speed,
                    timestampMillis = now
                )

                _sessionFlow.value = _sessionFlow.value?.copy(
                    trackpoints = (_sessionFlow.value?.trackpoints ?: emptyList()) + trackpoint,
                    isPaused = paused
                )
            }
        }
    }

    private fun stopRecording() {
        trackingJob?.cancel()
        trackingJob = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startForegroundInCompatMode() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureNotificationChannel() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Ride Recording",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Ongoing ride tracking notification"
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pending = android.app.PendingIntent.getActivity(
            this,
            0,
            intent,
            android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("StoneBC Ride Active")
            .setContentText("Tracking your ride")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setOngoing(true)
            .setContentIntent(pending)
            .build()
    }

    companion object {
        const val ACTION_START = "com.traddiff.stonebc.RECORDING_START"
        const val ACTION_STOP = "com.traddiff.stonebc.RECORDING_STOP"
        private const val EXTRA_RECORDING_MODE = "recording_mode"
        private const val EXTRA_ROUTE_ID = "route_id"
        private const val EXTRA_ROUTE_NAME = "route_name"
        private const val EXTRA_ROUTE_CATEGORY = "route_category"
        private const val CHANNEL_ID = "stonebc_recording"
        private const val NOTIFICATION_ID = 1001
        private const val AUTO_PAUSE_MILLIS = 7_000L
        private const val MOTION_THRESHOLD_MPS = 0.5f

        private val _sessionFlow = MutableStateFlow<RideSession?>(null)
        val sessionFlow: StateFlow<RideSession?> = _sessionFlow.asStateFlow()

        fun start(
            context: Context,
            mode: RouteRecordingMode = RouteRecordingMode.free,
            routeId: String? = null,
            routeName: String? = null,
            routeCategory: String? = null
        ) {
            val intent = Intent(context, RecordingService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_RECORDING_MODE, mode.name)
                .putExtra(EXTRA_ROUTE_ID, routeId)
                .putExtra(EXTRA_ROUTE_NAME, routeName)
                .putExtra(EXTRA_ROUTE_CATEGORY, routeCategory)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, RecordingService::class.java).setAction(ACTION_STOP)
            context.startService(intent)
        }

        fun clearSession() {
            _sessionFlow.value = null
        }
    }
}
