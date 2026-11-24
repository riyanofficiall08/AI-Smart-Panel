package com.aismartpanel.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Handler
import android.os.SystemClock
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max

class CaptureException(val code: String, message: String) : Exception(message)

/**
 * Satu MediaProjection + VirtualDisplay hidup selama panel aktif. Frame terakhir disimpan (1 buffer)
 * sehingga screenshot dapat diambil kapan saja (Android 14 melarang >1 VirtualDisplay per token).
 */
class ScreenCapturer(private val ctx: Context, private val handler: Handler) {

    var onStopped: (() -> Unit)? = null
    @Volatile var ready = false
        private set

    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private var width = 0
    private var height = 0
    private var dpi = 0
    private val lock = Any()
    private var last: Image? = null
    private var released = false

    private fun size(): Pair<Int, Int> {
        val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        return if (Build.VERSION.SDK_INT >= 30) {
            val b = wm.maximumWindowMetrics.bounds
            Pair(b.width(), b.height())
        } else {
            val dm = DisplayMetrics()
            @Suppress("DEPRECATION") wm.defaultDisplay.getRealMetrics(dm)
            Pair(dm.widthPixels, dm.heightPixels)
        }
    }

    private fun newReader(w: Int, h: Int): ImageReader {
        val r = ImageReader.newInstance(w, h, PixelFormat.RGBA_8888, 3)
        r.setOnImageAvailableListener({ rd ->
            val img = try { rd.acquireLatestImage() } catch (e: Exception) { null }
            if (img != null) synchronized(lock) { last?.close(); last = img }
        }, handler)
        return r
    }

    fun start(p: MediaProjection) {
        projection = p
        // Wajib terdaftar SEBELUM createVirtualDisplay (Android 14)
        p.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() { release(); onStopped?.invoke() }
        }, handler)
        val (w, h) = size()
        width = w; height = h
        dpi = ctx.resources.displayMetrics.densityDpi
        val rd = newReader(w, h)
        reader = rd
        display = p.createVirtualDisplay(
            "AISmartPanelCapture", w, h, dpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, rd.surface, null, handler
        )
        ready = true
    }

    private fun rebuild(w: Int, h: Int) {
        synchronized(lock) { last?.close(); last = null }
        width = w; height = h
        val old = reader
        val nr = newReader(w, h)
        reader = nr
        display?.resize(w, h, dpi)
        display?.surface = nr.surface
        old?.close()
    }

    private fun toBitmap(img: Image): Bitmap {
        val plane = img.planes[0]
        val buf = plane.buffer
        buf.rewind()
        val pixelStride = plane.pixelStride
        val rowPadding = plane.rowStride - pixelStride * img.width
        val padded = Bitmap.createBitmap(img.width + rowPadding / pixelStride, img.height, Bitmap.Config.ARGB_8888)
        padded.copyPixelsFromBuffer(buf)
        if (rowPadding == 0) return padded
        val exact = Bitmap.createBitmap(padded, 0, 0, img.width, img.height)
        padded.recycle()
        return exact
    }

    /** Blocking — panggil dari thread worker. l/t/r/b = fraksi 0..1 terhadap layar penuh. */
    fun capture(l: Float, t: Float, r: Float, b: Float, maxSide: Int = 1600, quality: Int = 85): File {
        if (!ready || released) throw CaptureException("not_ready", "Izin screenshot tidak aktif. Buka aplikasi lalu mulai panel lagi.")
        val (cw, ch) = size()
        if (cw != width || ch != height) rebuild(cw, ch)

        var full: Bitmap? = null
        val deadline = SystemClock.uptimeMillis() + 1500
        while (full == null && SystemClock.uptimeMillis() < deadline) {
            synchronized(lock) { last?.let { full = toBitmap(it) } }
            if (full == null) Thread.sleep(60)
        }
        var bmp = full ?: throw CaptureException("no_frame", "Layar belum terekam. Coba lagi sebentar.")

        val bw = bmp.width
        val bh = bmp.height
        val x0 = (l.coerceIn(0f, 1f) * bw).toInt()
        val y0 = (t.coerceIn(0f, 1f) * bh).toInt()
        val x1 = (r.coerceIn(0f, 1f) * bw).toInt().coerceAtMost(bw)
        val y1 = (b.coerceIn(0f, 1f) * bh).toInt().coerceAtMost(bh)
        val isFull = x0 == 0 && y0 == 0 && x1 == bw && y1 == bh
        if (!isFull && (x1 - x0) >= 8 && (y1 - y0) >= 8) {
            val cropped = Bitmap.createBitmap(bmp, x0, y0, x1 - x0, y1 - y0)
            bmp.recycle(); bmp = cropped
        }

        val longest = max(bmp.width, bmp.height)
        if (longest > maxSide) {
            val s = maxSide.toFloat() / longest
            val scaled = Bitmap.createScaledBitmap(bmp, (bmp.width * s).toInt().coerceAtLeast(1), (bmp.height * s).toInt().coerceAtLeast(1), true)
            bmp.recycle(); bmp = scaled
        }

        val dir = File(ctx.cacheDir, "shots").apply { mkdirs() }
        dir.listFiles()?.sortedByDescending { it.lastModified() }?.drop(6)?.forEach { it.delete() }
        val out = File(dir, "shot_${System.currentTimeMillis()}.jpg")
        FileOutputStream(out).use { bmp.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(40, 100), it) }
        bmp.recycle()
        return out
    }

    fun release() {
        if (released) return
        released = true
        ready = false
        try { display?.release() } catch (_: Throwable) {}
        display = null
        synchronized(lock) { try { last?.close() } catch (_: Throwable) {}; last = null }
        try { reader?.close() } catch (_: Throwable) {}
        reader = null
        val p = projection
        projection = null
        try { p?.stop() } catch (_: Throwable) {}
    }
}
