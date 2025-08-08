package com.example.talowa

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*

class SpeechRecognitionPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var currentResult: Result? = null
    private var isListening = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.talowa.speech_recognition")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isAvailable" -> {
                result.success(isVoiceRecognitionAvailable())
            }
            "test" -> {
                testVoiceService(result)
            }
            "testMicrophone" -> {
                testMicrophone(result)
            }
            "startListening" -> {
                val language = call.argument<String>("language") ?: "en-US"
                val timeout = call.argument<Int>("timeout") ?: 10000
                startListening(language, timeout, result)
            }
            "stopListening" -> {
                stopListening()
                result.success(null)
            }
            "setLanguage" -> {
                // Language is set per recognition session
                result.success(null)
            }
            "getSupportedLanguages" -> {
                result.success(getSupportedLanguages())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isVoiceRecognitionAvailable(): Boolean {
        return activity?.let { 
            SpeechRecognizer.isRecognitionAvailable(it) && hasAudioPermission()
        } ?: false
    }

    private fun hasAudioPermission(): Boolean {
        return context?.let {
            ActivityCompat.checkSelfPermission(it, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        } ?: false
    }

    private fun testVoiceService(result: Result) {
        try {
            if (!isVoiceRecognitionAvailable()) {
                result.error("NOT_AVAILABLE", "Voice recognition not available", null)
                return
            }
            
            // Test passed
            result.success(true)
        } catch (e: Exception) {
            result.error("TEST_FAILED", "Voice service test failed: ${e.message}", null)
        }
    }

    private fun testMicrophone(result: Result) {
        try {
            if (!hasAudioPermission()) {
                result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
                return
            }

            // Check if microphone is available
            val audioManager = context?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            val isMicAvailable = audioManager?.let { 
                !it.isMicrophoneMute 
            } ?: false

            if (isMicAvailable) {
                result.success(true)
            } else {
                result.error("MIC_NOT_AVAILABLE", "Microphone not available", null)
            }
        } catch (e: Exception) {
            result.error("MIC_TEST_FAILED", "Microphone test failed: ${e.message}", null)
        }
    }

    private fun startListening(language: String, timeout: Int, result: Result) {
        activity?.let { activity ->
            try {
                if (isListening) {
                    stopListening()
                }

                if (!isVoiceRecognitionAvailable()) {
                    result.error("NOT_AVAILABLE", "Voice recognition not available", null)
                    return
                }

                currentResult = result
                isListening = true

                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(activity)
                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        // Ready to listen
                    }

                    override fun onBeginningOfSpeech() {
                        // User started speaking
                    }

                    override fun onRmsChanged(rmsdB: Float) {
                        // Audio level changed
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {
                        // Audio buffer received
                    }

                    override fun onEndOfSpeech() {
                        // User stopped speaking
                    }

                    override fun onError(error: Int) {
                        isListening = false
                        val errorCode = when (error) {
                            SpeechRecognizer.ERROR_AUDIO -> "AUDIO_ERROR"
                            SpeechRecognizer.ERROR_CLIENT -> "CLIENT_ERROR"
                            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "PERMISSION_DENIED"
                            SpeechRecognizer.ERROR_NETWORK -> "NETWORK_ERROR"
                            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "NETWORK_TIMEOUT"
                            SpeechRecognizer.ERROR_NO_MATCH -> "NO_MATCH"
                            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "SERVICE_BUSY"
                            SpeechRecognizer.ERROR_SERVER -> "SERVER_ERROR"
                            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "SPEECH_TIMEOUT"
                            else -> "UNKNOWN_ERROR"
                        }

                        currentResult?.error("SPEECH_ERROR", errorCode, null)
                        currentResult = null
                        cleanup()
                    }

                    override fun onResults(results: Bundle?) {
                        isListening = false
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val recognizedText = matches?.firstOrNull() ?: ""

                        currentResult?.success(recognizedText)
                        currentResult = null
                        cleanup()
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        // Handle partial results if needed
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {
                        // Handle events if needed
                    }
                })

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3000)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3000)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1000)
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.packageName)
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
                }

                speechRecognizer?.startListening(intent)

            } catch (e: Exception) {
                isListening = false
                result.error("START_ERROR", "Failed to start voice recognition: ${e.message}", null)
                cleanup()
            }
        } ?: run {
            result.error("NO_ACTIVITY", "Activity not available", null)
        }
    }

    private fun stopListening() {
        if (isListening) {
            speechRecognizer?.stopListening()
            isListening = false
        }
        cleanup()
    }

    private fun cleanup() {
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    private fun getSupportedLanguages(): List<String> {
        return listOf(
            "en-US", "en-GB", "en-AU", "en-CA", "en-IN",
            "hi-IN", "te-IN", "ta-IN", "bn-IN", "gu-IN",
            "kn-IN", "ml-IN", "mr-IN", "or-IN", "pa-IN",
            "ur-IN", "as-IN", "mai-IN", "bho-IN", "kok-IN"
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        cleanup()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
        cleanup()
    }
}