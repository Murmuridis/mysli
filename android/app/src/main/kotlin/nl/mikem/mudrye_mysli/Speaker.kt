package nl.mikem.mudrye_mysli

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

/** Озвучка цитаты встроенным синтезатором речи Android. */
object Speaker {
    private var tts: TextToSpeech? = null
    private var ready = false
    private var pending: Pair<String, Boolean>? = null

    /** stopped | speaking | no_voice */
    @Volatile
    var state = "stopped"
        private set

    fun speak(ctx: Context, text: String, russian: Boolean) {
        val t = tts
        if (t == null) {
            pending = Pair(text, russian)
            state = "speaking"
            tts = TextToSpeech(ctx.applicationContext) { status ->
                ready = status == TextToSpeech.SUCCESS
                if (!ready) {
                    state = "no_voice"
                    return@TextToSpeech
                }
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(id: String?) { state = "speaking" }
                    override fun onDone(id: String?) { state = "stopped" }
                    @Deprecated("Deprecated in Java")
                    override fun onError(id: String?) { state = "stopped" }
                })
                pending?.let { say(it.first, it.second) }
                pending = null
            }
            return
        }
        if (!ready) {
            pending = Pair(text, russian)
            return
        }
        say(text, russian)
    }

    private fun say(text: String, russian: Boolean) {
        val t = tts ?: return
        val loc = if (russian) Locale("ru", "RU") else Locale.US
        val r = t.setLanguage(loc)
        if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
            state = "no_voice"
            return
        }
        t.setSpeechRate(0.92f)
        state = "speaking"
        t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "quote")
    }

    fun stop() {
        tts?.stop()
        state = "stopped"
    }
}
