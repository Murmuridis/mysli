package nl.mikem.mudrye_mysli

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Мостик к Android для lib/native.dart:
 *  - «Поделиться» текстом и картинкой, открытие ссылок;
 *  - ежедневное напоминание (Reminders.kt);
 *  - резервная копия (MediaFiles.kt).
 * Сделано без сторонних плагинов, чтобы сборка не зависела от их версий.
 */
class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    /** Ожидание ответа от системного окна выбора/сохранения файла. */
    private var pendingActivity: MethodChannel.Result? = null
    private var pendingKind = ""

    private fun startForResult(intent: Intent, code: Int, kind: String, result: MethodChannel.Result) {
        pendingActivity?.success(null)
        pendingActivity = result
        pendingKind = kind
        try {
            startActivityForResult(intent, code)
        } catch (_: Exception) {
            pendingActivity = null
            result.success(null)
        }
    }

    /** Тяжёлую работу с файлами — не в главном потоке. */
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            val r = try {
                work()
            } catch (e: Exception) {
                null
            }
            runOnUiThread { result.success(r) }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mysli/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "share" -> {
                        val text = call.arguments as? String ?: ""
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        try {
                            startActivity(Intent.createChooser(send, "Поделиться цитатой"))
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }

                    "shareImage" -> {
                        val png = call.argument<ByteArray>("png")
                        val text = call.argument<String>("text") ?: ""
                        if (png == null) {
                            result.success(false)
                        } else {
                            try {
                                val uri = CardImages.save(this, png)
                                val send = Intent(Intent.ACTION_SEND).apply {
                                    type = "image/png"
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    putExtra(Intent.EXTRA_TEXT, text)
                                    clipData = android.content.ClipData.newRawUri("", uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                startActivity(Intent.createChooser(send, "Поделиться открыткой"))
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }

                    "openUrl" -> {
                        val url = call.arguments as? String ?: ""
                        try {
                            val i = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                            result.success(true)
                        } catch (_: ActivityNotFoundException) {
                            result.success(false)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }

                    "notificationsEnabled" -> result.success(Reminders.notificationsAllowed(this))

                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(PERMISSION) != PackageManager.PERMISSION_GRANTED
                        ) {
                            pendingPermission?.success(false)
                            pendingPermission = result
                            requestPermissions(arrayOf(PERMISSION), REQUEST_CODE)
                        } else {
                            result.success(Reminders.notificationsAllowed(this))
                        }
                    }

                    "scheduleReminder" -> {
                        val hour = call.argument<Int>("hour") ?: 8
                        val minute = call.argument<Int>("minute") ?: 0
                        val quotes = call.argument<String>("quotes") ?: "{}"
                        Reminders.save(this, hour, minute, quotes)
                        Reminders.schedule(this)
                        result.success(null)
                    }

                    "cancelReminder" -> {
                        Reminders.disable(this)
                        result.success(null)
                    }

                    "createDocument" -> {
                        val i = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mime") ?: "application/zip"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "backup.zip")
                        }
                        startForResult(i, REQ_DOC, "", result)
                    }

                    "openDocument" -> {
                        val i = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        startForResult(i, REQ_DOC, "", result)
                    }

                    "writeBackup" -> {
                        val uri = call.argument<String>("uri") ?: ""
                        val db = call.argument<String>("db") ?: ""
                        background(result) { Backup.write(this, uri, db) ?: "" }
                    }

                    "checkBackup" -> {
                        val uri = call.arguments as? String ?: ""
                        background(result) { Backup.check(this, uri) }
                    }

                    "restoreBackup" -> {
                        val uri = call.argument<String>("uri") ?: ""
                        val db = call.argument<String>("db") ?: ""
                        background(result) { Backup.restore(this, uri, db) ?: "" }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_DOC) return
        val result = pendingActivity ?: return
        pendingActivity = null
        if (resultCode != android.app.Activity.RESULT_OK || data == null) {
            result.success(null)
            return
        }
        result.success(data.data?.toString())
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermission?.success(granted)
            pendingPermission = null
        }
    }

    companion object {
        private const val PERMISSION = "android.permission.POST_NOTIFICATIONS"
        private const val REQUEST_CODE = 4711
        private const val REQ_DOC = 4802
    }
}
