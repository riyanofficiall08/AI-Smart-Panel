package com.aismartpanel.app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

/**
 * Jendela layar penuh untuk memilih area screenshot.
 * Persegi dapat DIGESER (sentuh di dalam) dan DIUBAH UKURANNYA (tarik sudut / tepi); seret di luar = area baru.
 * Hasil berupa fraksi 0..1 terhadap ukuran view (= layar penuh karena jendela memakai FLAG_LAYOUT_NO_LIMITS).
 */
private enum class Mode { NONE, MOVE, NEW, L, T, R, B, TL, TR, BL, BR }

class RegionSelectorView(
    ctx: Context,
    private val onConfirm: (RectF) -> Unit,
    private val onFull: () -> Unit,
    private val onCancel: () -> Unit,
) : FrameLayout(ctx) {

    private val canvasView = SelectionCanvas(ctx)
    private val hint: TextView

    init {
        addView(canvasView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        val bar = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = rounded(Color.argb(235, 10, 14, 26), dpf(16f), C.CYAN, 2)
            setPadding(dp(12), dp(10), dp(12), dp(10))
        }
        hint = ctx.label("Geser / tarik sudut untuk mengatur area", 12.5f, C.TEXT)
        bar.addView(hint)
        val row = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER }
        fun btn(text: String, primary: Boolean, click: () -> Unit) = ctx.pill(text, primary, 12.5f).apply {
            setOnClickListener { click() }
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { setMargins(dp(4), dp(8), dp(4), 0) }
            setPadding(dp(12), dp(8), dp(12), dp(8))
        }
        row.addView(btn("Batal", false) { onCancel() })
        row.addView(btn("Layar penuh", false) { onFull() })
        row.addView(btn("Ambil area", true) { canvasView.fraction()?.let(onConfirm) })
        bar.addView(row)
        addView(bar, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply { topMargin = dp(56) })
    }

    private inner class SelectionCanvas(ctx: Context) : View(ctx) {
        private val rect = RectF()
        private val dim = Paint().apply { color = Color.argb(130, 0, 0, 0) }
        private val border = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C.CYAN; style = Paint.Style.STROKE; strokeWidth = dpf(2f) }
        private val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = C.CYAN }
        private val minSize = dpf(56f)
        private val touchR = dpf(32f)

        private var mode = Mode.NONE
        private var lastX = 0f
        private var lastY = 0f
        private var anchorX = 0f
        private var anchorY = 0f

        override fun onSizeChanged(w: Int, h: Int, ow: Int, oh: Int) {
            if (rect.isEmpty && w > 0 && h > 0) {
                rect.set(w * 0.12f, h * 0.30f, w * 0.88f, h * 0.62f)
            }
        }

        fun fraction(): RectF? {
            if (width == 0 || height == 0) return null
            return RectF(rect.left / width, rect.top / height, rect.right / width, rect.bottom / height)
        }

        private fun near(a: Float, b: Float) = abs(a - b) <= touchR

        private fun hit(x: Float, y: Float): Mode {
            val nl = near(x, rect.left); val nr = near(x, rect.right)
            val nt = near(y, rect.top); val nb = near(y, rect.bottom)
            return when {
                nl && nt -> Mode.TL; nr && nt -> Mode.TR; nl && nb -> Mode.BL; nr && nb -> Mode.BR
                nl && y in rect.top..rect.bottom -> Mode.L
                nr && y in rect.top..rect.bottom -> Mode.R
                nt && x in rect.left..rect.right -> Mode.T
                nb && x in rect.left..rect.right -> Mode.B
                rect.contains(x, y) -> Mode.MOVE
                else -> Mode.NEW
            }
        }

        override fun onTouchEvent(e: MotionEvent): Boolean {
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    lastX = e.x; lastY = e.y
                    mode = hit(e.x, e.y)
                    if (mode == Mode.NEW) { anchorX = e.x; anchorY = e.y; rect.set(e.x, e.y, e.x, e.y) }
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.x - lastX
                    val dy = e.y - lastY
                    lastX = e.x; lastY = e.y
                    when (mode) {
                        Mode.MOVE -> {
                            val nx = (rect.left + dx).coerceIn(0f, width - rect.width())
                            val ny = (rect.top + dy).coerceIn(0f, height - rect.height())
                            rect.offsetTo(nx, ny)
                        }
                        Mode.NEW -> rect.set(minOf(anchorX, e.x), minOf(anchorY, e.y), maxOf(anchorX, e.x), maxOf(anchorY, e.y))
                        Mode.L, Mode.TL, Mode.BL -> rect.left = (rect.left + dx).coerceIn(0f, rect.right - minSize)
                        else -> {}
                    }
                    if (mode == Mode.R || mode == Mode.TR || mode == Mode.BR) rect.right = (rect.right + dx).coerceIn(rect.left + minSize, width.toFloat())
                    if (mode == Mode.T || mode == Mode.TL || mode == Mode.TR) rect.top = (rect.top + dy).coerceIn(0f, rect.bottom - minSize)
                    if (mode == Mode.B || mode == Mode.BL || mode == Mode.BR) rect.bottom = (rect.bottom + dy).coerceIn(rect.top + minSize, height.toFloat())
                    rect.intersect(0f, 0f, width.toFloat(), height.toFloat())
                    invalidate()
                    return true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (mode == Mode.NEW && (rect.width() < minSize || rect.height() < minSize)) {
                        val cx = rect.centerX().coerceIn(minSize, width - minSize)
                        val cy = rect.centerY().coerceIn(minSize, height - minSize)
                        rect.set(cx - minSize, cy - minSize, cx + minSize, cy + minSize)
                        invalidate()
                    }
                    mode = Mode.NONE
                    return true
                }
            }
            return false
        }

        override fun onDraw(c: Canvas) {
            val full = Path().apply { addRect(0f, 0f, width.toFloat(), height.toFloat(), Path.Direction.CW) }
            val hole = Path().apply { addRoundRect(rect, dpf(6f), dpf(6f), Path.Direction.CW) }
            full.op(hole, Path.Op.DIFFERENCE)
            c.drawPath(full, dim)
            c.drawRoundRect(rect, dpf(6f), dpf(6f), border)
            val r = dpf(6f)
            for ((x, y) in listOf(
                rect.left to rect.top, rect.right to rect.top, rect.left to rect.bottom, rect.right to rect.bottom,
                rect.centerX() to rect.top, rect.centerX() to rect.bottom, rect.left to rect.centerY(), rect.right to rect.centerY(),
            )) c.drawCircle(x, y, r, dot)
        }
    }
}
