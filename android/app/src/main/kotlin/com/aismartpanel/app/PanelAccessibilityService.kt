package com.aismartpanel.app

import android.accessibilityservice.AccessibilityService
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/**
 * Pintasan Volume+ (opsional). HANYA menyaring KEYCODE_VOLUME_UP; tidak membaca isi layar.
 * Tombol dikonsumsi (volume tidak berubah) hanya bila: pintasan diaktifkan di pengaturan DAN panel sedang berjalan.
 * Keterbatasan: butuh layanan aksesibilitas aktif; sebagian OEM/mode hemat daya dapat menonaktifkannya;
 * tidak berfungsi saat layar terkunci; aplikasi tertentu (mis. mode ujian terkunci) bisa memblokir.
 */
class PanelAccessibilityService : AccessibilityService() {

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_VOLUME_UP) return false
        val svc = PanelService.instance ?: return false
        if (!Prefs(applicationContext).volumeShortcut) return false
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) svc.toggleVisibility()
        return true
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}
}
