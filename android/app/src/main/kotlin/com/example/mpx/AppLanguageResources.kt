package com.example.mpx

import android.content.Context
import android.content.res.Configuration
import android.os.Build
import java.util.Locale

/** 分享窗口和下载通知与 Flutter 共用语言偏好，不改动系统语言。 */
object AppLanguageResources {
    fun languageCode(context: Context): String {
        val configuration = contextFor(context.applicationContext).resources.configuration
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            configuration.locales[0].language
        } else {
            @Suppress("DEPRECATION")
            configuration.locale.language
        }
    }

    fun contextFor(context: Context): Context {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val preference = prefs.getString("flutter.app_language", "system")
        val systemLocale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.resources.configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            context.resources.configuration.locale
        }
        val language = when (preference) {
            "zh" -> "zh"
            "en" -> "en"
            else -> if (systemLocale.language == "zh") "zh" else "en"
        }
        val locale = Locale(language)
        val configuration = Configuration(context.resources.configuration).apply {
            setLocale(locale)
            setLayoutDirection(locale)
        }
        return context.createConfigurationContext(configuration)
    }
}

fun Context.appString(id: Int, vararg args: Any): String =
    AppLanguageResources.contextFor(applicationContext).getString(id, *args)
