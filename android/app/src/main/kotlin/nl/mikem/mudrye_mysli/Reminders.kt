package nl.mikem.mudrye_mysli

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Напоминания (до трёх в день): первое — «мысль дня», остальные —
 * ещё по одной мудрой мысли.
 *
 * Приложение заранее передаёт сюда цитаты на ближайшие дни (см. Reminder в
 * lib/native.dart), а будильник Android в нужное время показывает
 * уведомление и ставит себя на следующий день. Те же цитаты берёт виджет.
 */
object Reminders {
    const val PREFS = "mysli_reminder"
    private const val CHANNEL = "daily_word"
    private const val NOTIFICATION_ID = 1001
    const val MAX_SLOTS = 3
    const val ACTION_FIRE = "nl.mikem.mudrye_mysli.REMINDER"

    /** Цитаты на ближайшие дни: {"2026-11-27": [{t, a}, …], …}. Нужны и виджету. */
    fun saveQuotes(ctx: Context, quotes: String) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("quotes", quotes).apply()
    }

    /** Время напоминаний — минуты от полуночи, до трёх в день. */
    fun save(ctx: Context, times: List<Int>) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("on", times.isNotEmpty())
            .putString("times", times.take(MAX_SLOTS).joinToString(","))
            .apply()
    }

    private fun times(ctx: Context): List<Int> {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("on", false)) return emptyList()
        return (prefs.getString("times", "") ?: "").split(',')
            .mapNotNull { it.trim().toIntOrNull() }.take(MAX_SLOTS)
    }

    fun disable(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("on", false).apply()
        val am = alarmManager(ctx)
        for (slot in 0 until MAX_SLOTS) am.cancel(pendingIntent(ctx, slot))
    }

    private fun alarmManager(ctx: Context) =
        ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun pendingIntent(ctx: Context, slot: Int): PendingIntent {
        val i = Intent(ctx, ReminderReceiver::class.java)
            .setAction(ACTION_FIRE)
            .putExtra("slot", slot)
        return PendingIntent.getBroadcast(
            ctx, NOTIFICATION_ID + slot, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Поставить будильники на ближайшее наступление каждого времени. */
    fun schedule(ctx: Context) {
        val list = times(ctx)
        val am = alarmManager(ctx)
        for (slot in 0 until MAX_SLOTS) {
            if (slot >= list.size) {
                am.cancel(pendingIntent(ctx, slot))
                continue
            }
            val m = list[slot]
            val now = Calendar.getInstance()
            val next = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, m / 60)
                set(Calendar.MINUTE, m % 60)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (!after(now)) add(Calendar.DAY_OF_YEAR, 1)
            }
            setAlarm(am, next.timeInMillis, pendingIntent(ctx, slot))
        }
    }

    private fun setAlarm(am: AlarmManager, at: Long, pi: PendingIntent) {
        try {
            when {
                Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms() ->
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                Build.VERSION.SDK_INT >= 23 ->
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                else -> am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
            }
        } catch (_: SecurityException) {
            if (Build.VERSION.SDK_INT >= 23) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, at, pi)
            }
        }
    }

    fun notificationsAllowed(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ctx.checkSelfPermission("android.permission.POST_NOTIFICATIONS") !=
            PackageManager.PERMISSION_GRANTED
        ) return false
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (Build.VERSION.SDK_INT >= 24) nm.areNotificationsEnabled() else true
    }

    /** Цитата на сегодня: slot 0 — мысль дня, 1 и 2 — дополнительные. */
    fun quoteFor(ctx: Context, slot: Int): Pair<String, String>? {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val key = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        return try {
            val arr = JSONObject(prefs.getString("quotes", "{}") ?: "{}").optJSONArray(key)
                ?: return null
            val q = arr.optJSONObject(slot.coerceAtMost(arr.length() - 1)) ?: return null
            Pair(q.optString("t", ""), q.optString("a", ""))
        } catch (_: Exception) {
            null
        }
    }

    /** Показать уведомление с цитатой. */
    fun show(ctx: Context, slot: Int) {
        if (times(ctx).isEmpty()) return
        if (!notificationsAllowed(ctx)) return

        val q = quoteFor(ctx, slot)
        val text = q?.first?.takeIf { it.isNotEmpty() }
            ?: "Откройте приложение, чтобы прочитать мысль на сегодня."
        val author = q?.second ?: ""

        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            val ch = NotificationChannel(
                CHANNEL, "Мысль дня", NotificationManager.IMPORTANCE_DEFAULT
            )
            ch.description = "Напоминания с цитатой"
            nm.createNotificationChannel(ch)
        }
        val open = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val contentIntent = PendingIntent.getActivity(
            ctx, 0, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val title = when {
            slot == 0 && author.isEmpty() -> "Мысль на сегодня"
            author.isEmpty() -> "Мудрая мысль"
            else -> author
        }
        val big = if (author.isEmpty()) text else "$text\n— $author"
        val builder = newBuilder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_quote)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(big))
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT >= 21) builder.setColor(0xFF1F4E5F.toInt())
        try {
            nm.notify(NOTIFICATION_ID + slot, builder.build())
        } catch (_: SecurityException) {
        }
    }

    @Suppress("DEPRECATION")
    fun newBuilder(ctx: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, channel)
        else Notification.Builder(ctx)
}

/** Срабатывание будильника: показать цитату и завести на завтра. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Reminders.ACTION_FIRE) {
            Reminders.show(context, intent.getIntExtra("slot", 0))
        }
        Reminders.schedule(context)
        QuoteWidget.updateAll(context)
    }
}

/** После перезагрузки, обновления или смены времени будильники надо ставить заново. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Reminders.schedule(context)
        QuoteWidget.updateAll(context)
    }
}
