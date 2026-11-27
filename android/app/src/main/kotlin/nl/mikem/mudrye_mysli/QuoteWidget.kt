package nl.mikem.mudrye_mysli

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Виджет на рабочий стол: мысль дня. Берёт ту же цитату, что и приложение
 * (их список на 60 дней вперёд приложение сохраняет в Reminders.saveQuotes).
 * Обновляется раз в полчаса, при открытии приложения и после перезагрузки.
 */
class QuoteWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) mgr.updateAppWidget(id, views(ctx))
    }

    companion object {
        fun updateAll(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, QuoteWidget::class.java))
            if (ids.isEmpty()) return
            val v = views(ctx)
            for (id in ids) mgr.updateAppWidget(id, v)
        }

        private fun views(ctx: Context): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.quote_widget)
            val q = Reminders.quoteFor(ctx, 0)
            val text = q?.first?.takeIf { it.isNotEmpty() }
                ?: "Откройте «Мудрые мысли», чтобы увидеть мысль дня."
            val author = q?.second ?: ""
            v.setTextViewText(R.id.widget_text, text)
            v.setTextViewText(R.id.widget_author, if (author.isEmpty()) "" else "— $author")
            val open = Intent(ctx, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val pi = PendingIntent.getActivity(
                ctx, 7, open,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            v.setOnClickPendingIntent(R.id.widget_root, pi)
            return v
        }
    }
}
