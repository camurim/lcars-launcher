package dev.carlosamorim.lcars.mobile

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "dev.carlosamorim.lcars.mobile/device_control"
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

                    else -> result.notImplemented()
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
