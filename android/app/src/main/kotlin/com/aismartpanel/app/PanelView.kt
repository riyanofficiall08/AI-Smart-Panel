package com.aismartpanel.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Tombol bulat kecil untuk membuka kembali panel. Dapat digeser. */
class HandleView(ctx: Context) : TextView(ctx) {
    init {
        text = "AI"
        textSize = 15f
        setTextColor(Color.WHITE)
        setTypeface(typeface, Typeface.BOLD)
        gravity = Gravity.CENTER
        background = gradient(0f, oval = true)
        elevation = ctx.dpf(8f)
    }
}

class PanelCallbacks(
    val onMinimize: () -> Unit,
    val onHide: () -> Unit,
    val onClose: () -> Unit,
    val onShotFull: () -> Unit,
    val onShotArea: () -> Unit,
    val onAnalyze: () -> Unit,
    val onCopy: () -> Unit,
    val onMode: (String) -> Unit,
    val onConfidence: (Int) -> Unit,
)

/** Panel melayang: header (drag) · mode · pratinjau · hasil (scroll) · tombol aksi · grip resize. */
class PanelView(ctx: Context, private val cb: PanelCallbacks) : FrameLayout(ctx) {

    val header: View
    val grip: View

    private val content = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
    private val modeChips = LinkedHashMap<String, TextView>()
    private val confChips = LinkedHashMap<Int, TextView>()
    private val preview = ImageView(ctx)
    private val status = ctx.label("", 12.5f, C.MUTED)
    private val resultBox = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
    private val scroll = ScrollView(ctx)
    private val shotMenu = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; visibility = View.GONE }
    private val btnShot: TextView
    private val btnAnalyze: TextView
    private val btnCopy: TextView
    private var opacity = 0.94f

    init {
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            clipToOutline = true
        }
        addView(root, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        applyOpacity(opacity)
        elevation = dpf(10f)

        // ── header ──
        val h = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(8), dp(6), dp(6))
        }
        header = h
        h.addView(TextView(ctx).apply {
            text = "AI"; textSize = 10f; setTextColor(Color.WHITE); gravity = Gravity.CENTER
            setTypeface(typeface, Typeface.BOLD); background = gradient(0f, true)
            layoutParams = LinearLayout.LayoutParams(dp(24), dp(24)).apply { rightMargin = dp(8) }
        })
        h.addView(ctx.label("AI Smart Panel", 14f, C.TEXT, true).apply {
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        })
        fun hb(sym: String, click: () -> Unit) = TextView(ctx).apply {
            text = sym; textSize = 16f; setTextColor(C.MUTED); gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(dp(34), dp(34))
            setOnClickListener { click() }
        }
        h.addView(hb("👁") { cb.onHide() })
        h.addView(hb("—") { cb.onMinimize() })
        h.addView(hb("✕") { cb.onClose() })
        root.addView(h)

        // ── mode & kehati-hatian ──
        val modeRow = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; setPadding(dp(8), 0, dp(8), 0) }
        for ((key, name) in listOf("fast" to "Cepat", "accurate" to "Akurat", "study" to "Belajar")) {
            val c = ctx.pill(name, false).apply {
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(dp(2), 0, dp(2), 0) }
                setOnClickListener { cb.onMode(key) }
            }
            modeChips[key] = c; modeRow.addView(c)
        }
        root.addView(modeRow)

        val confRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), dp(6), dp(8), dp(8))
        }
        confRow.addView(ctx.label("Kehati-hatian", 10.5f, C.MUTED).apply { setPadding(dp(2), 0, dp(6), 0) })
        for (v in listOf(100, 80, 60)) {
            val c = ctx.pill("$v%", false, 11f).apply {
                setPadding(dp(8), dp(4), dp(8), dp(4))
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(dp(2), 0, dp(2), 0) }
                setOnClickListener { cb.onConfidence(v) }
            }
            confChips[v] = c; confRow.addView(c)
        }
        root.addView(confRow)
        root.addView(View(ctx).apply { setBackgroundColor(Color.argb(40, 255, 255, 255)); layoutParams = LinearLayout.LayoutParams(-1, 1) })

        // ── isi (scroll): pratinjau + status + hasil ──
        preview.apply {
            adjustViewBounds = true
            scaleType = ImageView.ScaleType.CENTER_CROP
            visibility = View.GONE
            background = rounded(C.SURFACE2, dpf(10f))
            clipToOutline = true
            layoutParams = LinearLayout.LayoutParams(-1, dp(120)).apply { bottomMargin = dp(8) }
        }
        content.setPadding(dp(12), dp(10), dp(12), dp(10))
        content.addView(preview)
        content.addView(status)
        content.addView(resultBox)
        scroll.addView(content, LayoutParams(-1, -2))
        scroll.isVerticalScrollBarEnabled = true
        root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        setStatus("1. Buka halaman soal\n2. Tekan Screenshot (layar penuh / pilih area)\n3. Periksa pratinjau lalu tekan Analisis AI", Kind.HINT)

        // ── menu screenshot ──
        shotMenu.setPadding(dp(10), dp(6), dp(10), 0)
        for ((name, click) in listOf<Pair<String, () -> Unit>>("Layar penuh" to cb.onShotFull, "Pilih area" to cb.onShotArea)) {
            shotMenu.addView(ctx.pill(name, false, 12f).apply {
                background = rounded(Color.argb(35, 34, 211, 238), dpf(12f), C.CYAN, 2)
                setTextColor(C.TEXT)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(dp(3), 0, dp(3), 0) }
                setOnClickListener { shotMenu.visibility = View.GONE; click() }
            })
        }
        root.addView(shotMenu)

        // ── tombol aksi ──
        val actions = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; setPadding(dp(8), dp(8), dp(8), dp(14)) }
        fun ab(text: String, click: () -> Unit) = ctx.pill(text, false, 12f).apply {
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(dp(3), 0, dp(3), 0) }
            setPadding(dp(4), dp(10), dp(4), dp(10))
            setOnClickListener { click() }
        }
        btnShot = ab("📷 Screenshot") { shotMenu.visibility = if (shotMenu.visibility == View.VISIBLE) View.GONE else View.VISIBLE }
        btnAnalyze = ab("✨ Analisis AI") { cb.onAnalyze() }
        btnCopy = ab("📋 Salin") { cb.onCopy() }
        actions.addView(btnShot); actions.addView(btnAnalyze); actions.addView(btnCopy)
        root.addView(actions)

        // ── grip resize ──
        grip = TextView(ctx).apply {
            text = "◢"; textSize = 14f; setTextColor(C.MUTED); gravity = Gravity.BOTTOM or Gravity.END
            setPadding(dp(10), dp(10), dp(6), dp(4))
        }
        addView(grip, LayoutParams(dp(40), dp(40), Gravity.BOTTOM or Gravity.END))
        setActionsEnabled(analyze = false, copy = false)
    }

    enum class Kind { HINT, BUSY, ERROR, OK }

    fun applyOpacity(a: Float) {
        opacity = a.coerceIn(0.5f, 1f)
        (getChildAt(0) as LinearLayout).background = rounded(
            Color.argb((255 * opacity).toInt(), Color.red(C.BG), Color.green(C.BG), Color.blue(C.BG)),
            dpf(20f), Color.argb(90, 34, 211, 238), 2,
        )
    }

    fun setMode(m: String) { modeChips.forEach { (k, v) -> v.paint(k == m) } }
    fun setConfidence(c: Int) { confChips.forEach { (k, v) -> v.paint(k == c) } }

    fun setStatus(text: String, kind: Kind) {
        status.text = text
        status.visibility = if (text.isEmpty()) View.GONE else View.VISIBLE
        status.setTextColor(when (kind) { Kind.ERROR -> C.DANGER; Kind.OK -> C.OK; Kind.BUSY -> C.CYAN; Kind.HINT -> C.MUTED })
        status.gravity = if (kind == Kind.HINT) Gravity.CENTER else Gravity.START
        status.setPadding(0, dp(if (kind == Kind.HINT) 14 else 2), 0, dp(6))
    }

    fun setPreview(bmp: Bitmap?) {
        preview.visibility = if (bmp == null) View.GONE else View.VISIBLE
        preview.setImageBitmap(bmp)
    }

    fun setActionsEnabled(analyze: Boolean, copy: Boolean, busy: Boolean = false) {
        fun TextView.en(on: Boolean) { alpha = if (on) 1f else 0.45f; isEnabled = on }
        btnShot.en(!busy); btnAnalyze.en(analyze && !busy); btnCopy.en(copy && !busy)
        btnAnalyze.paint(analyze && !busy)
    }

    fun clearResult() { resultBox.removeAllViews() }

    fun showResult(r: AnalysisData, modeLabel: String) {
        resultBox.removeAllViews()
        val ctx = context
        fun section(title: String) = resultBox.addView(ctx.label(title.uppercase(), 10f, C.MUTED, true).apply { setPadding(0, dp(10), 0, dp(4)) })

        var meta = "${r.typeLabel} • $modeLabel"
        r.confidence?.let { meta += " • perkiraan AI $it%" }
        resultBox.addView(ctx.label(meta, 11f, C.VIOLET, true))
        if (r.questionText.isNotBlank()) {
            resultBox.addView(ctx.label(r.questionText.trim().take(200), 11.5f, C.MUTED).apply { setPadding(0, dp(6), 0, 0) })
        }
        section("Jawaban")
        resultBox.addView(ctx.label(r.answer.ifBlank { "—" }.trim(), 15.5f, C.TEXT, true).apply {
            background = rounded(Color.argb(30, 34, 211, 238), dpf(12f), Color.argb(90, 34, 211, 238), 2)
            setPadding(dp(10), dp(10), dp(10), dp(10))
            setLineSpacing(0f, 1.15f)
        })
        if (r.explanation.isNotBlank()) {
            section("Penjelasan")
            resultBox.addView(ctx.label(r.explanation.trim(), 13f, C.TEXT).apply { setLineSpacing(0f, 1.25f) })
        }
        if (r.caveats.isNotBlank()) {
            resultBox.addView(ctx.label("ⓘ ${r.caveats.trim()}", 11.5f, C.WARN).apply { setPadding(0, dp(10), 0, 0) })
        }
        resultBox.addView(ctx.label("AI bisa keliru. Periksa kembali jawaban penting.", 10.5f, C.MUTED).apply {
            setTypeface(typeface, Typeface.ITALIC); setPadding(0, dp(10), 0, 0)
        })
        if (r.used != null && r.limit != null) {
            resultBox.addView(ctx.label("Sisa kuota hari ini: ${(r.limit - r.used).coerceAtLeast(0)}/${r.limit}", 10.5f, C.MUTED))
        }
        scroll.post { scroll.smoothScrollTo(0, 0) }
    }
}
