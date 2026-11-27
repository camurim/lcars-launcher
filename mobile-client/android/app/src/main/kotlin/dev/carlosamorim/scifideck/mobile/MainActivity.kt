package dev.carlosamorim.scifideck.mobile

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "dev.carlosamorim.scifideck.mobile/device_control"
        private const val REQ_SAVE_BACKUP = 4701
        private const val REQ_OPEN_BACKUP = 4702
    }

    private var pendingBackupResult: MethodChannel.Result? = null
    private var pendingBackupContent: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        applyImmersiveFullscreen()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applyImmersiveFullscreen()
        }
    }

    @Suppress("DEPRECATION")
    private fun applyImmersiveFullscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listInstalledApps" -> {
                        try {
                            val pm = applicationContext.packageManager
                            val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                                addCategory(Intent.CATEGORY_LAUNCHER)
                            }
                            val resolved = pm.queryIntentActivities(mainIntent, 0)
                            val apps = resolved
                                .mapNotNull { info ->
                                    val pkg = info.activityInfo?.packageName ?: return@mapNotNull null
                                    if (pkg == applicationContext.packageName) return@mapNotNull null
                                    val label = info.loadLabel(pm)?.toString()?.trim()
                                    if (label.isNullOrEmpty()) return@mapNotNull null
                                    mapOf("name" to label, "package" to pkg)
                                }
                                .distinctBy { it["package"] }
                                .sortedBy { it["name"]?.lowercase() }
                            result.success(apps)
                        } catch (e: Exception) {
                            result.error("LIST_APPS_ERR", e.message, null)
                        }
                    }

                    "launchApp" -> {
                        val pkg = call.argument<String>("packageName")
                        if (pkg.isNullOrBlank()) {
                            result.error("INVALID_ARG", "packageName ausente", null)
                            return@setMethodCallHandler
                        }
                        val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            result.success("Abrindo $pkg")
                        } else {
                            result.error("NOT_FOUND", "App '$pkg' não encontrado", null)
                        }
                    }

                    "deviceControl" -> {
                        val control = call.argument<String>("control") ?: ""
                        handleDeviceControl(control, result)
                    }

                    "saveBackupFile" -> {
                        val content = call.argument<String>("content") ?: ""
                        val fileName = call.argument<String>("fileName") ?: "scifi-deck-mobile-backup.json"
                        pendingBackupResult = result
                        pendingBackupContent = content
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }
                        startActivityForResult(intent, REQ_SAVE_BACKUP)
                    }

                    "openBackupFile" -> {
                        pendingBackupResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf("application/json", "text/plain")
                            )
                        }
                        startActivityForResult(intent, REQ_OPEN_BACKUP)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_SAVE_BACKUP) {
            val cb = pendingBackupResult
            val content = pendingBackupContent
            pendingBackupResult = null
            pendingBackupContent = null
            if (resultCode == Activity.RESULT_OK && data?.data != null && content != null) {
                try {
                    contentResolver.openOutputStream(data.data!!)?.use { out ->
                        out.write(content.toByteArray(Charsets.UTF_8))
                    }
                    cb?.success(true)
                } catch (e: Exception) {
                    cb?.error("SAVE_ERR", e.message, null)
                }
            } else {
                cb?.success(false)
            }
        } else if (requestCode == REQ_OPEN_BACKUP) {
            val cb = pendingBackupResult
            pendingBackupResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                try {
                    val text = contentResolver.openInputStream(data.data!!)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
                    cb?.success(text)
                } catch (e: Exception) {
                    cb?.error("OPEN_ERR", e.message, null)
                }
            } else {
                cb?.success(null)
            }
        }
    }

    private fun handleDeviceControl(control: String, result: MethodChannel.Result) {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        when (control) {
            "volume_up" -> {
                audio.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    AudioManager.ADJUST_RAISE,
                    AudioManager.FLAG_SHOW_UI
                )
                result.success("Volume aumentado")
            }

            "volume_down" -> {
                audio.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    AudioManager.ADJUST_LOWER,
                    AudioManager.FLAG_SHOW_UI
                )
                result.success("Volume diminuído")
            }

            "volume_mute" -> {
                audio.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    AudioManager.ADJUST_TOGGLE_MUTE,
                    AudioManager.FLAG_SHOW_UI
                )
                result.success("Mudo alternado")
            }

            "brightness_up" -> {
                val lp = window.attributes
                val current = if (lp.screenBrightness < 0f) 0.5f else lp.screenBrightness
                val next = (current + 0.15f).coerceIn(0.08f, 1.0f)
                lp.screenBrightness = next
                window.attributes = lp
                result.success("Brilho: ${(next * 100).toInt()}%")
            }

            "brightness_down" -> {
                val lp = window.attributes
                val current = if (lp.screenBrightness < 0f) 0.5f else lp.screenBrightness
                val next = (current - 0.15f).coerceIn(0.08f, 1.0f)
                lp.screenBrightness = next
                window.attributes = lp
                result.success("Brilho: ${(next * 100).toInt()}%")
            }

            "brightness_auto" -> {
                val lp = window.attributes
                lp.screenBrightness = -1.0f
                window.attributes = lp
                result.success("Brilho restaurado para automático")
            }

            "bluetooth" -> {
                try {
                    val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                    val adapter = btManager?.adapter
                    if (adapter != null && !adapter.isEnabled) {
                        val enableIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                        startActivity(enableIntent)
                        result.success("Solicitando ativação do Bluetooth")
                    } else {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success("Painel Bluetooth aberto")
                    }
                } catch (_: SecurityException) {
                    val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success("Painel Bluetooth aberto")
                }
            }

            "wifi_panel" -> {
                val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY)
                } else {
                    Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                }
                startActivity(intent)
                result.success("Painel de conectividade aberto")
            }

            else -> result.error("UNKNOWN_CONTROL", "Controle '$control' desconhecido", null)
        }
    }
}
