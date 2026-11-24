package com.aismartpanel.app

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.TextView
import kotlin.math.hypot
import kotlin.math.roundToInt

/** Palet dark futuristic (sama dengan aplikasi Flutter). */
object C {
    val BG = Color.parseColor("#0A0E1A")
    val SURFACE = Color.parseColor("#111729")
    val SURFACE2 = Color.parseColor("#1A2238")
    val CYAN = Color.parseColor("#22D3EE")
    val VIOLET = Color.parseColor("#8B5CF6")
    val TEXT = Color.parseColor("#E6EAF5")
    val MUTED = Color.parseColor("#8A94B0")
    val OK = Color.parseColor("#34D399")
    val WARN = Color.parseColor("#FBBF24")
    val DANGER = Color.parseColor("#F87171")
}

fun Context.dp(v: Int): Int = (v * resources.displayMetrics.density).roundToInt()
fun Context.dpf(v: Float): Float = v * resources.displayMetrics.density

fun rounded(color: Int, radius: Float, stroke: Int = 0, strokePx: Int = 0): GradientDrawable =
    GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = radius
        setColor(color)
        if (strokePx > 0) setStroke(strokePx, stroke)
    }

fun gradient(radius: Float, oval: Boolean = false): GradientDrawable =
    GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(C.CYAN, C.VIOLET)).apply {
        shape = if (oval) GradientDrawable.OVAL else GradientDrawable.RECTANGLE
        cornerRadius = radius
    }

fun Context.label(text: String, sp: Float, color: Int = C.TEXT, bold: Boolean = false): TextView =
    TextView(this).apply {
        this.text = text
        textSize = sp
        setTextColor(color)
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

/** Tombol/chip teks dengan latar rounded. */
fun Context.pill(text: String, selected: Boolean, sp: Float = 12f): TextView =
    TextView(this).apply {
        this.text = text
        textSize = sp
        gravity = Gravity.CENTER
        setPadding(dp(8), dp(6), dp(8), dp(6))
        isClickable = true
        paint(selected)
    }

fun TextView.paint(selected: Boolean) {
    if (selected) {
        background = gradient(context.dpf(10f))
        setTextColor(Color.WHITE)
        setTypeface(typeface, Typeface.BOLD)
    } else {
        background = rounded(C.SURFACE2, context.dpf(10f))
        setTextColor(C.MUTED)
        setTypeface(Typeface.DEFAULT)
    }
}

/** Listener drag berbasis koordinat layar (stabil walau jendela ikut bergerak). */
class DragListener(
    private val onStart: () -> Unit,
    private val onMove: (dx: Int, dy: Int) -> Unit,
    private val onEnd: (moved: Boolean) -> Unit,
) : View.OnTouchListener {
    private var sx = 0f
    private var sy = 0f
    private var moved = false

    override fun onTouch(v: View, e: MotionEvent): Boolean {
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> { sx = e.rawX; sy = e.rawY; moved = false; onStart(); return true }
            MotionEvent.ACTION_MOVE -> {
                val dx = e.rawX - sx
                val dy = e.rawY - sy
                if (!moved && hypot(dx, dy) > v.context.dp(6)) moved = true
                if (moved) onMove(dx.toInt(), dy.toInt())
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> { onEnd(moved); return true }
        }
        return false
    }
}

fun View.dp(v: Int): Int = context.dp(v)
fun View.dpf(v: Float): Float = context.dpf(v)
