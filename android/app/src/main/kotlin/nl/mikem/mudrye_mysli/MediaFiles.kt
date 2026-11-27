package nl.mikem.mudrye_mysli

import android.content.Context
import android.net.Uri
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.OutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/** Папка files/media — в резервной копии сохраняется вместе с базой (пока пустая). */
object MediaFiles {
    fun dir(ctx: Context): File = File(ctx.filesDir, "media").apply { mkdirs() }
}

/**
 * Резервная копия: один .zip с базой (цитаты, избранное, источники,
 * настройки).
 */
object Backup {
    private const val DB_ENTRY = "mysli.db"
    private const val INFO_ENTRY = "backup.json"

    private fun openOut(ctx: Context, uri: Uri): OutputStream? =
        try {
            ctx.contentResolver.openOutputStream(uri, "wt")
        } catch (_: Exception) {
            ctx.contentResolver.openOutputStream(uri, "w")
        }

    /** Записать копию. Возвращает текст ошибки или null. */
    fun write(ctx: Context, uriStr: String, dbPath: String): String? {
        val db = File(dbPath)
        if (!db.exists()) return "База не найдена"
        val media = MediaFiles.dir(ctx).listFiles()?.filter { it.isFile } ?: emptyList()
        return try {
            val os = openOut(ctx, Uri.parse(uriStr)) ?: return "Не удалось создать файл"
            ZipOutputStream(BufferedOutputStream(os)).use { zos ->
                val info = JSONObject()
                    .put("app", "mudrye_mysli")
                    .put("format", 1)
                    .put("created", System.currentTimeMillis())
                    .put("media", media.size)
                zos.putNextEntry(ZipEntry(INFO_ENTRY))
                zos.write(info.toString().toByteArray())
                zos.closeEntry()
                zos.putNextEntry(ZipEntry(DB_ENTRY))
                db.inputStream().use { it.copyTo(zos) }
                zos.closeEntry()
                for (f in media) {
                    zos.putNextEntry(ZipEntry("media/" + f.name))
                    f.inputStream().use { it.copyTo(zos) }
                    zos.closeEntry()
                }
            }
            null
        } catch (e: Exception) {
            "Ошибка записи: " + (e.message ?: e.javaClass.simpleName)
        }
    }

    private fun safeMediaName(entry: String): String? {
        if (!entry.startsWith("media/")) return null
        val n = entry.removePrefix("media/")
        if (n.isEmpty() || n.contains('/') || n.contains('\\') || n.startsWith(".")) return null
        return n
    }

    /** Проверить файл перед восстановлением. */
    fun check(ctx: Context, uriStr: String): Map<String, Any> {
        var hasDb = false
        var media = 0
        var created = 0L
        try {
            val input = ctx.contentResolver.openInputStream(Uri.parse(uriStr))
                ?: return mapOf("ok" to false, "error" to "Не удалось открыть файл")
            ZipInputStream(BufferedInputStream(input)).use { zis ->
                while (true) {
                    val e = zis.nextEntry ?: break
                    when {
                        e.isDirectory -> {}
                        e.name == DB_ENTRY -> hasDb = true
                        e.name == INFO_ENTRY -> try {
                            created = JSONObject(zis.readBytes().toString(Charsets.UTF_8))
                                .optLong("created", 0)
                        } catch (_: Exception) {
                        }
                        safeMediaName(e.name) != null -> media++
                    }
                }
            }
        } catch (_: Exception) {
            return mapOf("ok" to false, "error" to "Это не резервная копия «Мудрых мыслей»")
        }
        if (!hasDb) return mapOf("ok" to false, "error" to "Это не резервная копия «Мудрых мыслей»")
        return mapOf("ok" to true, "media" to media, "created" to created)
    }

    /** Восстановить копию. База должна быть закрыта. Возвращает текст ошибки или null. */
    fun restore(ctx: Context, uriStr: String, dbPath: String): String? {
        val tmp = File(ctx.cacheDir, "restore")
        tmp.deleteRecursively()
        val tmpMedia = File(tmp, "media").apply { mkdirs() }
        val tmpDb = File(tmp, DB_ENTRY)
        try {
            val input = ctx.contentResolver.openInputStream(Uri.parse(uriStr))
                ?: return "Не удалось открыть файл"
            ZipInputStream(BufferedInputStream(input)).use { zis ->
                while (true) {
                    val e = zis.nextEntry ?: break
                    if (e.isDirectory) continue
                    val target = when {
                        e.name == DB_ENTRY -> tmpDb
                        else -> safeMediaName(e.name)?.let { File(tmpMedia, it) }
                    } ?: continue
                    target.outputStream().use { zis.copyTo(it) }
                }
            }
            if (!tmpDb.exists()) return "В файле нет базы данных"
            val header = ByteArray(16)
            tmpDb.inputStream().use { it.read(header) }
            if (!String(header, Charsets.US_ASCII).startsWith("SQLite format 3")) {
                return "База в копии повреждена"
            }
            for (suffix in listOf("", "-journal", "-wal", "-shm")) File(dbPath + suffix).delete()
            tmpDb.copyTo(File(dbPath), overwrite = true)
            val media = MediaFiles.dir(ctx)
            media.listFiles()?.forEach { it.delete() }
            tmpMedia.listFiles()?.forEach { it.copyTo(File(media, it.name), overwrite = true) }
            return null
        } catch (e: Exception) {
            return "Ошибка восстановления: " + (e.message ?: e.javaClass.simpleName)
        } finally {
            tmp.deleteRecursively()
        }
    }
}
