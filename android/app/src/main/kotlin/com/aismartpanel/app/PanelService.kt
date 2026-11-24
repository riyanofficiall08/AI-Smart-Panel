package com.aismartpanel.app

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.graphics.PixelFormat
import android.graphics.RectF
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Toast
import java.io.File
import java.util.concurrent.Executors

/**
 * Foreground service pemilik: (1) jendela overlay WindowManager TYPE_APPLICATION_OVERLAY,
 * (2) MediaProjection untuk screenshot. Karena service ini hidup sendiri, panel tetap tampil
 * di atas Chrome/aplikasi lain walau aplikasi utama masuk background atau Home ditekan.
 */
class PanelService : Service() {

    enum class UiState { PANEL, HANDLE, HIDDEN, SELECTING, CAPTURING }

    companion object {
        const val ACTION_START = "com.aismartpanel.action.START"
        const val ACTION_STOP = "com.aismartpanel.action.STOP"
        const val ACTION_TOGGLE = "com.aismartpanel.action.TOGGLE"
        const val EXTRA_CODE = "code"
        const val EXTRA_DATA = "data"
        private const val NOTIF_ID = 4711
        private const val CHANNEL_ID = "aisp_panel"

        @Volatile var instance: PanelService? = null
        fun isRunning() = instance != null
    }

    private lateinit var wm: WindowManager
    private lateinit var prefs: Prefs
    private lateinit var api: ApiClient
    private lateinit var projThread: HandlerThread
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    private var capturer: ScreenCapturer? = null
    private var panel: PanelView? = null
    private var handle: HandleView? = null
    private var selector: RegionSelectorView? = null
    private var panelLp: WindowManager.LayoutParams? = null
    private var handleLp: WindowManager.LayoutParams? = null
    private var state = UiState.HIDDEN
    private var busy = false
    private var lastShot: File? = null
    private var lastResult: AnalysisData? = null
    private var started = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        prefs = Prefs(this)
        api = ApiClient(prefs)
        projThread = HandlerThread("aisp-projection").also { it.start() }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> { stopSelf(); return START_NOT_STICKY }
            ACTION_TOGGLE -> { if (started) toggleVisibility() else stopSelf(); return START_NOT_STICKY }
            ACTION_START -> { startPanel(intent); return START_NOT_STICKY }
        }
        return START_NOT_STICKY
    }

    // ───────────────────────── start ─────────────────────────
    private fun startPanel(intent: Intent) {
        // Android 14: startForeground (tipe mediaProjection) HARUS dipanggil sebelum getMediaProjection
        startForegroundCompat()
        if (started) { reloadConfig(); return }

        val code = intent.getIntExtra(EXTRA_CODE, Activity.RESULT_CANCELED)
        val data = readData(intent)
        if (data == null || code != Activity.RESULT_OK) { stopSelf(); return }
        try {
            val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val projection = mpm.getMediaProjection(code, data) ?: throw IllegalStateException("projection null")
            capturer = ScreenCapturer(this, Handler(projThread.looper)).also {
                it.onStopped = { main.post { toast("Perekaman layar dihentikan sistem."); stopSelf() } }
                it.start(projection)
            }
        } catch (t: Throwable) {
            toast("Gagal memulai perekaman layar.")
            stopSelf(); return
        }

        started = true
        instance = this
        buildViews()
        showState(UiState.PANEL)
    }

    @Suppress("DEPRECATION")
    private fun readData(intent: Intent): Intent? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
        else intent.getParcelableExtra(EXTRA_DATA)

    private fun startForegroundCompat() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Panel AI melayang", NotificationManager.IMPORTANCE_LOW))
        }
        val n = buildNotification()
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        else startForeground(NOTIF_ID, n)
    }

    @Suppress("DEPRECATION")
    private fun buildNotification(): Notification {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        fun svc(action: String, req: Int) = PendingIntent.getService(this, req, Intent(this, PanelService::class.java).setAction(action), flags)
        val open = PendingIntent.getActivity(this, 0, packageManager.getLaunchIntentForPackage(packageName), flags)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        return b.setContentTitle("AI Smart Panel aktif")
            .setContentText("Panel melayang & screenshot siap. Ketuk untuk membuka aplikasi.")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_view, "Tampil/Sembunyi", svc(ACTION_TOGGLE, 1))
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Tutup", svc(ACTION_STOP, 2))
            .build()
    }

    // ───────────────────────── views ─────────────────────────
    private fun screenW() = resources.displayMetrics.widthPixels
    private fun screenH() = resources.displayMetrics.heightPixels

    private fun overlayType() =
        if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

    private fun lp(w: Int, h: Int, fullscreen: Boolean = false): WindowManager.LayoutParams {
        var flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        if (fullscreen) flags = flags or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        return WindowManager.LayoutParams(w, h, overlayType(), flags, PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP or Gravity.START
            if (fullscreen && Build.VERSION.SDK_INT >= 28) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }

    private fun buildViews() {
        val p = PanelView(this, PanelCallbacks(
            onMinimize = { showState(UiState.HANDLE) },
            onHide = { showState(UiState.HIDDEN) },
            onClose = { stopSelf() },
            onShotFull = { startCapture(null) },
            onShotArea = { showState(UiState.SELECTING) },
            onAnalyze = { analyze() },
            onCopy = { copyAnswer() },
            onMode = { m -> prefs.mode = m; panel?.setMode(m) },
            onConfidence = { c -> prefs.confidence = c; panel?.setConfidence(c) },
        ))
        p.setMode(prefs.mode); p.setConfidence(prefs.confidence); p.applyOpacity(prefs.opacity)
        panel = p

        val w = dp(prefs.panelWdp).coerceAtMost(screenW() - dp(8))
        val h = dp(prefs.panelHdp).coerceAtMost(screenH() - dp(48))
        val params = lp(w, h)
        params.x = if (prefs.panelX < 0) dp(12) else prefs.panelX
        params.y = if (prefs.panelY < 0) dp(120) else prefs.panelY
        panelLp = params
        clampPanel()

        // drag header
        var sx = 0; var sy = 0
        p.header.setOnTouchListener(DragListener(
            onStart = { sx = params.x; sy = params.y },
            onMove = { dx, dy -> params.x = sx + dx; params.y = sy + dy; clampPanel(); updateSafe(p, params) },
            onEnd = { prefs.panelX = params.x; prefs.panelY = params.y },
        ))
        // resize grip
        var sw = 0; var sh = 0
        p.grip.setOnTouchListener(DragListener(
            onStart = { sw = params.width; sh = params.height },
            onMove = { dx, dy ->
                params.width = (sw + dx).coerceIn(dp(240), screenW() - params.x.coerceAtLeast(0))
                params.height = (sh + dy).coerceIn(dp(300), screenH() - params.y.coerceAtLeast(0))
                updateSafe(p, params)
            },
            onEnd = { prefs.panelWdp = (params.width / resources.displayMetrics.density).toInt(); prefs.panelHdp = (params.height / resources.displayMetrics.density).toInt() },
        ))

        // handle bulat
        val hv = HandleView(this)
        val hp = lp(dp(52), dp(52))
        handleLp = hp
        var hx = 0; var hy = 0
        hv.setOnTouchListener(DragListener(
            onStart = { hx = hp.x; hy = hp.y },
            onMove = { dx, dy ->
                hp.x = (hx + dx).coerceIn(0, screenW() - dp(52)); hp.y = (hy + dy).coerceIn(0, screenH() - dp(52))
                updateSafe(hv, hp)
            },
            onEnd = { moved -> if (!moved) showState(UiState.PANEL) else { prefs.panelX = hp.x; prefs.panelY = hp.y } },
        ))
        handle = hv
    }

    private fun clampPanel() {
        val p = panelLp ?: return
        p.x = p.x.coerceIn(0, (screenW() - p.width).coerceAtLeast(0))
        p.y = p.y.coerceIn(0, (screenH() - p.height).coerceAtLeast(0))
    }

    private fun updateSafe(v: View, p: WindowManager.LayoutParams) {
        try { if (v.isAttachedToWindow) wm.updateViewLayout(v, p) } catch (_: Throwable) {}
    }

    private fun detach(v: View?) {
        if (v == null) return
        try { if (v.isAttachedToWindow) wm.removeViewImmediate(v) } catch (_: Throwable) {}
    }

    private fun attach(v: View, p: WindowManager.LayoutParams): Boolean {
        return try { wm.addView(v, p); true } catch (e: Throwable) {
            toast("Izin 'Tampil di atas aplikasi lain' dicabut. Aktifkan kembali lalu mulai panel.")
            stopSelf(); false
        }
    }

    /** Satu-satunya tempat yang memasang/melepas jendela overlay. */
    private fun showState(next: UiState) {
        if (!started && next != UiState.HIDDEN) return
        // posisi handle mengikuti panel saat minimize
        if (next == UiState.HANDLE) {
            val p = panelLp; val h = handleLp
            if (state == UiState.PANEL && p != null && h != null) { h.x = p.x; h.y = p.y }
        }
        detach(panel); detach(handle); detach(selector)
        selector = null
        state = next
        when (next) {
            UiState.PANEL -> panelLp?.let { clampPanel(); attach(panel!!, it) }
            UiState.HANDLE -> handleLp?.let { attach(handle!!, it) }
            UiState.SELECTING -> {
                val sel = RegionSelectorView(this,
                    onConfirm = { frac -> startCapture(frac) },
                    onFull = { startCapture(null) },
                    onCancel = { showState(UiState.PANEL) })
                selector = sel
                attach(sel, lp(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT, fullscreen = true).also {
                    it.x = 0; it.y = 0
                })
            }
            UiState.HIDDEN, UiState.CAPTURING -> {}
        }
    }

    /** Dipanggil handle, notifikasi, dan pintasan Volume+. Selalu dijalankan di main thread. */
    fun toggleVisibility() {
        if (Looper.myLooper() != Looper.getMainLooper()) { main.post { toggleVisibility() }; return }
        when (state) {
            UiState.PANEL -> showState(if (prefs.showHandle) UiState.HANDLE else UiState.HIDDEN)
            UiState.HANDLE, UiState.HIDDEN -> showState(UiState.PANEL)
            UiState.SELECTING -> showState(UiState.PANEL)
            UiState.CAPTURING -> {}
        }
    }

    /** Dipanggil MainActivity setelah pengaturan/sesi diperbarui. */
    fun reloadConfig() {
        main.post {
            panel?.setMode(prefs.mode)
            panel?.setConfidence(prefs.confidence)
            panel?.applyOpacity(prefs.opacity)
        }
    }

    // ───────────────────────── screenshot ─────────────────────────
    private fun startCapture(region: RectF?) {
        if (busy) return
        val cap = capturer
        if (cap == null || !cap.ready) {
            showState(UiState.PANEL)
            panel?.setStatus("Izin screenshot tidak aktif. Buka aplikasi lalu mulai panel lagi.", PanelView.Kind.ERROR)
            return
        }
        busy = true
        showState(UiState.CAPTURING) // sembunyikan semua jendela agar panel tidak ikut terekam
        main.postDelayed({
            worker.execute {
                try {
                    val f = cap.capture(region?.left ?: 0f, region?.top ?: 0f, region?.right ?: 1f, region?.bottom ?: 1f)
                    val opts = BitmapFactory.Options().apply { inSampleSize = 2 }
                    val bmp = BitmapFactory.decodeFile(f.absolutePath, opts)
                    main.post {
                        busy = false
                        lastShot = f; lastResult = null
                        showState(UiState.PANEL)
                        panel?.apply {
                            clearResult(); setPreview(bmp)
                            setStatus("Screenshot siap. Periksa pratinjau lalu tekan Analisis AI.", PanelView.Kind.OK)
                            setActionsEnabled(analyze = true, copy = false)
                        }
                        if (prefs.autoAnalyze) analyze()
                    }
                } catch (e: CaptureException) {
                    main.post { busy = false; showState(UiState.PANEL); panel?.setStatus(e.message ?: "Gagal screenshot.", PanelView.Kind.ERROR) }
                } catch (e: Throwable) {
                    main.post { busy = false; showState(UiState.PANEL); panel?.setStatus("Gagal mengambil screenshot.", PanelView.Kind.ERROR) }
                }
            }
        }, 450)
    }

    // ───────────────────────── analisis AI ─────────────────────────
    private fun analyze() {
        val file = lastShot
        if (busy) return
        if (file == null || !file.exists()) {
            panel?.setStatus("Ambil screenshot dulu sebelum analisis.", PanelView.Kind.ERROR); return
        }
        busy = true
        panel?.apply { clearResult(); setStatus("AI sedang menganalisis…", PanelView.Kind.BUSY); setActionsEnabled(analyze = true, copy = false, busy = true) }
        val modeLabel = when (prefs.mode) { "fast" -> "Cepat"; "study" -> "Belajar"; else -> "Akurat" }
        worker.execute {
            try {
                val r = api.analyze(file)
                main.post {
                    busy = false; lastResult = r
                    panel?.apply { setStatus("", PanelView.Kind.OK); showResult(r, modeLabel); setActionsEnabled(analyze = true, copy = true) }
                }
            } catch (e: ApiException) {
                main.post { busy = false; panel?.apply { setStatus(e.message ?: "Gagal.", PanelView.Kind.ERROR); setActionsEnabled(analyze = true, copy = lastResult != null) } }
            } catch (e: Throwable) {
                main.post { busy = false; panel?.apply { setStatus("Terjadi kesalahan tak terduga.", PanelView.Kind.ERROR); setActionsEnabled(analyze = true, copy = lastResult != null) } }
            }
        }
    }

    private fun copyAnswer() {
        val r = lastResult ?: return
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("AI Smart Panel", r.fullText()))
        toast("Jawaban + penjelasan disalin")
    }

    private fun toast(msg: String) = main.post { Toast.makeText(applicationContext, msg, Toast.LENGTH_SHORT).show() }

    // ───────────────────────── destroy ─────────────────────────
    override fun onDestroy() {
        instance = null
        started = false
        detach(panel); detach(handle); detach(selector)
        panel = null; handle = null; selector = null
        capturer?.onStopped = null
        capturer?.release()
        capturer = null
        worker.shutdownNow()
        projThread.quitSafely()
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        super.onDestroy()
    }
}
