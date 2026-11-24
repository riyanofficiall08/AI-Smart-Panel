package com.aismartpanel.app

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.aismartpanel/native"
    private val reqProjection = 7421
    private var pending: MethodChannel.Result? = null
    private lateinit var prefs: Prefs

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        prefs = Prefs(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(
                    mapOf(
                        "overlay" to canDrawOverlays(),
                        "running" to PanelService.isRunning(),
                        "accessibility" to accessibilityEnabled(),
                    )
                )

                "openOverlaySettings" -> {
                    startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                    result.success(null)
                }

                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }

                "updateConfig" -> {
                    prefs.applyFlutterConfig(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                    PanelService.instance?.reloadConfig()
                    result.success(null)
                }

                // Native bisa memperbarui token; Flutter menyinkronkan agar refresh token tidak basi.
                "readNativeState" -> {
                    val refreshed = prefs.nativeRefreshed
                    val out = mapOf(
                        "refreshed" to refreshed,
                        "accessToken" to prefs.accessToken,
                        "refreshToken" to prefs.refreshToken,
                        "mode" to prefs.mode,
                        "confidence" to prefs.confidence,
                    )
                    if (refreshed) prefs.nativeRefreshed = false
                    result.success(out)
                }

                "startPanel" -> {
                    prefs.applyFlutterConfig(call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                    if (!canDrawOverlays()) {
                        result.error("overlay_permission", "Izin 'Tampil di atas aplikasi lain' belum diberikan.", null)
                    } else if (PanelService.isRunning()) {
                        PanelService.instance?.reloadConfig()
                        result.success(true)
                    } else if (pending != null) {
                        result.error("busy", "Permintaan izin sedang berjalan.", null)
                    } else {
                        pending = result
                        val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        @Suppress("DEPRECATION")
                        startActivityForResult(mpm.createScreenCaptureIntent(), reqProjection)
                    }
                }

                "stopPanel" -> {
                    stopService(Intent(this, PanelService::class.java))
                    result.success(null)
                }

                "moveToBack" -> { moveTaskToBack(true); result.success(null) }

                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == reqProjection) {
            val res = pending
            pending = null
            if (res != null) {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val i = Intent(this, PanelService::class.java)
                        .setAction(PanelService.ACTION_START)
                        .putExtra(PanelService.EXTRA_CODE, resultCode)
                        .putExtra(PanelService.EXTRA_DATA, data)
                    if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                    res.success(true)
                } else {
                    res.success(false)
                }
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun canDrawOverlays(): Boolean = Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(this)

    private fun accessibilityEnabled(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val cn = ComponentName(this, PanelAccessibilityService::class.java)
        return enabled.split(':').any { it.equals(cn.flattenToString(), true) || it.equals(cn.flattenToShortString(), true) }
    }
}
