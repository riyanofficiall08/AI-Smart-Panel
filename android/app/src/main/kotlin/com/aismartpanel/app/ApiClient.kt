package com.aismartpanel.app

import android.util.Base64
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL

class ApiException(val code: String, message: String) : Exception(message)

data class AnalysisData(
    val questionText: String,
    val questionType: String,
    val answer: String,
    val explanation: String,
    val confidence: Int?,
    val caveats: String,
    val model: String,
    val used: Int?,
    val limit: Int?,
) {
    val typeLabel: String
        get() = when (questionType) {
            "pilihan_ganda" -> "Pilihan ganda"
            "esai" -> "Esai"
            "isian" -> "Isian"
            else -> "Lainnya"
        }

    fun fullText(): String =
        if (explanation.isBlank()) answer else "$answer\n\nPenjelasan:\n$explanation"
}

/** Memanggil Supabase Edge Function `analyze` dari service native. Semua validasi lisensi ada di server. */
class ApiClient(private val prefs: Prefs) {

    fun analyze(file: File): AnalysisData {
        if (prefs.supabaseUrl.isBlank() || prefs.accessToken.isBlank()) {
            throw ApiException("no_session", "Sesi belum tersedia. Buka aplikasi lalu login ulang.")
        }
        if (tokenExpiringSoon()) refresh()

        val body = JSONObject()
            .put("image_base64", Base64.encodeToString(file.readBytes(), Base64.NO_WRAP))
            .put("mime", "image/jpeg")
            .put("mode", prefs.mode)
            .put("confidence", prefs.confidence)
            .toString()

        var res = post("/functions/v1/analyze", body, prefs.accessToken)
        if (res.first == 401 && refresh()) res = post("/functions/v1/analyze", body, prefs.accessToken)
        return parse(res.first, res.second)
    }

    private fun parse(status: Int, text: String): AnalysisData {
        val j = try { JSONObject(text) } catch (e: Exception) { null }
        if (status != 200 || j == null || !j.optBoolean("ok", false)) {
            val code = j?.optString("code").orEmpty().ifEmpty { "http_$status" }
            val msg = j?.optString("error").orEmpty().ifEmpty {
                if (status == 401) "Sesi berakhir. Buka aplikasi lalu login ulang." else "Server bermasalah ($status). Coba lagi."
            }
            throw ApiException(code, msg)
        }
        val r = j.getJSONObject("result")
        val usage = j.optJSONObject("usage")
        return AnalysisData(
            questionText = r.optString("question_text"),
            questionType = r.optString("question_type", "lainnya"),
            answer = r.optString("answer"),
            explanation = r.optString("explanation"),
            confidence = if (r.isNull("confidence")) null else r.optInt("confidence"),
            caveats = r.optString("caveats"),
            model = j.optString("model"),
            used = usage?.optInt("used"),
            limit = usage?.optInt("limit"),
        )
    }

    private fun post(path: String, json: String, bearer: String): Pair<Int, String> {
        val bytes = json.toByteArray(Charsets.UTF_8)
        val c = URL(prefs.supabaseUrl.trimEnd('/') + path).openConnection() as HttpURLConnection
        try {
            c.requestMethod = "POST"
            c.connectTimeout = 15_000
            c.readTimeout = 95_000
            c.doOutput = true
            c.setFixedLengthStreamingMode(bytes.size)
            c.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            c.setRequestProperty("apikey", prefs.anonKey)
            c.setRequestProperty("Authorization", "Bearer $bearer")
            c.outputStream.use { it.write(bytes) }
            val code = c.responseCode
            val stream = if (code >= 400) c.errorStream else c.inputStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
            return Pair(code, text)
        } catch (e: SocketTimeoutException) {
            throw ApiException("timeout", "Waktu habis menunggu server. Periksa koneksi lalu coba lagi.")
        } catch (e: IOException) {
            throw ApiException("network", "Tidak ada koneksi internet / server tidak terjangkau.")
        } finally {
            c.disconnect()
        }
    }

    /** Menukar refresh token. Bila berhasil, Flutter akan menyinkronkan sesi saat aplikasi dibuka. */
    private fun refresh(): Boolean {
        val rt = prefs.refreshToken
        if (rt.isBlank()) return false
        return try {
            val res = post("/auth/v1/token?grant_type=refresh_token", JSONObject().put("refresh_token", rt).toString(), prefs.anonKey)
            if (res.first != 200) return false
            val j = JSONObject(res.second)
            prefs.accessToken = j.getString("access_token")
            prefs.refreshToken = j.getString("refresh_token")
            prefs.nativeRefreshed = true
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun tokenExpiringSoon(): Boolean {
        return try {
            val payload = prefs.accessToken.split(".")[1]
            val json = String(Base64.decode(payload, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP))
            val exp = JSONObject(json).getLong("exp")
            exp - System.currentTimeMillis() / 1000 < 90
        } catch (e: Exception) {
            false
        }
    }
}
