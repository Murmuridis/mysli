package nl.mikem.mudrye_mysli

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException

/**
 * Открытки с цитатами для «Поделиться картинкой».
 * PNG кладётся в cache/cards, а другие приложения (мессенджеры, почта)
 * читают его через этот маленький провайдер — без сторонних библиотек.
 */
object CardImages {
    private const val KEEP = 5

    fun authority(ctx: Context) = ctx.packageName + ".cards"

    fun dir(ctx: Context): File = File(ctx.cacheDir, "cards").apply { mkdirs() }

    /** Сохранить картинку и вернуть её content:// адрес. */
    fun save(ctx: Context, png: ByteArray): Uri {
        val d = dir(ctx)
        // Старые открытки не копим: оставляем несколько последних.
        d.listFiles()?.sortedByDescending { it.lastModified() }?.drop(KEEP)?.forEach { it.delete() }
        val f = File(d, "mysl-${System.currentTimeMillis()}.png")
        f.writeBytes(png)
        return Uri.parse("content://${authority(ctx)}/${f.name}")
    }
}

class CardProvider : ContentProvider() {
    override fun onCreate() = true

    private fun file(uri: Uri): File {
        val ctx = context ?: throw FileNotFoundException()
        val name = uri.lastPathSegment ?: throw FileNotFoundException()
        if (name.contains('/') || name.startsWith(".")) throw FileNotFoundException()
        val f = File(CardImages.dir(ctx), name)
        if (!f.exists()) throw FileNotFoundException(name)
        return f
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor =
        ParcelFileDescriptor.open(file(uri), ParcelFileDescriptor.MODE_READ_ONLY)

    override fun getType(uri: Uri) = "image/png"

    override fun query(
        uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?
    ): Cursor {
        val f = file(uri)
        val cols = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val row = cols.map {
            when (it) {
                OpenableColumns.DISPLAY_NAME -> f.name
                OpenableColumns.SIZE -> f.length()
                else -> null
            }
        }
        return MatrixCursor(cols).apply { addRow(row) }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
    override fun update(
        uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?
    ) = 0
}
