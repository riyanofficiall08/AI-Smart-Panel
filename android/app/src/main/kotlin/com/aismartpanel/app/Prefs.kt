package com.aismartpanel.app

import android.content.Context

/** Penyimpanan privat aplikasi (dibaca/ditulis oleh MainActivity & PanelService). */
class Prefs(ctx: Context) {
    private val sp = ctx.applicationContext.getSharedPreferences("aisp_native", Context.MODE_PRIVATE)

    var supabaseUrl: String
        get() = sp.getString("url", "") ?: ""
        set(v) = sp.edit().putString("url", v).apply()
    var anonKey: String
        get() = sp.getString("anon", "") ?: ""
        set(v) = sp.edit().putString("anon", v).apply()
    var accessToken: String
        get() = sp.getString("access", "") ?: ""
        set(v) = sp.edit().putString("access", v).apply()
    var refreshToken: String
        get() = sp.getString("refresh", "") ?: ""
        set(v) = sp.edit().putString("refresh", v).apply()
    /** true bila token diperbarui oleh native; Flutter harus menyinkronkan sesi saat dibuka. */
    var nativeRefreshed: Boolean
        get() = sp.getBoolean("native_refreshed", false)
        set(v) = sp.edit().putBoolean("native_refreshed", v).apply()

    var mode: String
        get() = sp.getString("mode", "accurate") ?: "accurate"
        set(v) = sp.edit().putString("mode", v).apply()
    var confidence: Int
        get() = sp.getInt("confidence", 80)
        set(v) = sp.edit().putInt("confidence", v).apply()
    var showHandle: Boolean
        get() = sp.getBoolean("show_handle", true)
        set(v) = sp.edit().putBoolean("show_handle", v).apply()
    var autoAnalyze: Boolean
        get() = sp.getBoolean("auto_analyze", false)
        set(v) = sp.edit().putBoolean("auto_analyze", v).apply()
    var volumeShortcut: Boolean
        get() = sp.getBoolean("volume_shortcut", false)
        set(v) = sp.edit().putBoolean("volume_shortcut", v).apply()
    var opacity: Float
        get() = sp.getFloat("opacity", 0.94f)
        set(v) = sp.edit().putFloat("opacity", v).apply()

    // ukuran dalam dp, posisi dalam px (-1 = belum diatur)
    var panelWdp: Int
        get() = sp.getInt("panel_w", 320)
        set(v) = sp.edit().putInt("panel_w", v).apply()
    var panelHdp: Int
        get() = sp.getInt("panel_h", 460)
        set(v) = sp.edit().putInt("panel_h", v).apply()
    var panelX: Int
        get() = sp.getInt("panel_x", -1)
        set(v) = sp.edit().putInt("panel_x", v).apply()
    var panelY: Int
        get() = sp.getInt("panel_y", -1)
        set(v) = sp.edit().putInt("panel_y", v).apply()

    fun resetPanelGeometry() {
        sp.edit().putInt("panel_w", 320).putInt("panel_h", 460).putInt("panel_x", -1).putInt("panel_y", -1).apply()
    }

    fun applyFlutterConfig(m: Map<*, *>) {
        (m["supabaseUrl"] as? String)?.let { supabaseUrl = it }
        (m["anonKey"] as? String)?.let { anonKey = it }
        (m["accessToken"] as? String)?.let { accessToken = it }
        (m["refreshToken"] as? String)?.let { refreshToken = it }
        (m["mode"] as? String)?.let { mode = it }
        (m["confidence"] as? Number)?.let { confidence = it.toInt() }
        (m["showHandle"] as? Boolean)?.let { showHandle = it }
        (m["autoAnalyze"] as? Boolean)?.let { autoAnalyze = it }
        (m["volumeShortcut"] as? Boolean)?.let { volumeShortcut = it }
        (m["opacity"] as? Number)?.let { opacity = it.toFloat() }
        if (m["resetGeometry"] == true) resetPanelGeometry()
        if (m["accessToken"] != null) nativeRefreshed = false // Flutter baru saja mendorong sesi terbaru
    }
}
