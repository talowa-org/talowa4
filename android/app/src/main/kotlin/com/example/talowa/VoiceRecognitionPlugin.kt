package com.example.talowa

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*

class VoiceRecognitionPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var currentResult: Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.talowa.voice_recognition")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isVoiceRecognitionAvailable" -> {
                result.success(isVoiceRecognitionAvailable())
            }
            "startListening" -> {
                val language = call.argument<String>("language") ?: "en-US"
                val timeout = call.argument<Int>("timeout") ?: 30000
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
            SpeechRecognizer.isRecognitionAvailable(it)
        } ?: false
    }

    private fun startListening(language: String, timeout: Int, result: Result) {
        activity?.let { activity ->
            try {
                // Clean up any existing recognizer
                cleanup()
                
                currentResult = result
                
                // Check if speech recognition is available
                if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
                    result.error("NOT_AVAILABLE", "Speech recognition not available", null)
                    return
                }
                
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(activity)
                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        // Speech recognition is ready - user can start speaking
                    }
                    
                    override fun onBeginningOfSpeech() {
                        // User has started speaking
                    }
                    
                    override fun onRmsChanged(rmsdB: Float) {
                        // Audio level changed - can be used for visual feedback
                    }
                    
                    override fun onBufferReceived(buffer: ByteArray?) {
                        // Audio buffer received
                    }
                    
                    override fun onEndOfSpeech() {
                        // User has stopped speaking
                    }
                    
                    override fun onError(error: Int) {
                        val errorMessage = when (error) {
                            SpeechRecognizer.ERROR_AUDIO -> "AUDIO_ERROR"
                            SpeechRecognizer.ERROR_CLIENT -> "CLIENT_ERROR"
                            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "PERMISSION_DENIED"
                            SpeechRecognizer.ERROR_NETWORK -> "NETWORK_ERROR"
                            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "NETWORK_TIMEOUT"
                            SpeechRecognizer.ERROR_NO_MATCH -> "NO_MATCH"
                            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "RECOGNIZER_BUSY"
                            SpeechRecognizer.ERROR_SERVER -> "SERVER_ERROR"
                            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "SPEECH_TIMEOUT"
                            else -> "UNKNOWN_ERROR"
                        }
                        
                        // Only report error if we haven't already sent a result
                        currentResult?.let { result ->
                            result.error("SPEECH_ERROR", errorMessage, null)
                            currentResult = null
                        }
                        cleanup()
                    }
                    
                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val recognizedText = matches?.firstOrNull() ?: ""
                        
                        // Only send result if we haven't already sent one
                        currentResult?.let { result ->
                            if (recognizedText.isNotEmpty()) {
                                result.success(recognizedText)
                            } else {
                                result.error("SPEECH_ERROR", "NO_MATCH", null)
                            }
                            currentResult = null
                        }
                        cleanup()
                    }
                    
                    override fun onPartialResults(partialResults: Bundle?) {
                        // Handle partial results for better user feedback
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val partialText = matches?.firstOrNull()
                        
                        // Could send partial results to Flutter for real-time feedback
                        // For now, we'll just log them
                        if (!partialText.isNullOrEmpty()) {
                            // Log partial results for debugging
                        }
                    }
                    
                    override fun onEvent(eventType: Int, params: Bundle?) {
                        // Handle speech recognition events
                    }
                })

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true) // Enable partial results for better feedback
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3) // Get more results for better accuracy
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 5000) // Longer silence timeout
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 5000)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 2000) // Minimum speech length
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.packageName)
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false) // Use online recognition for better accuracy
                }

                // Start listening with proper error handling
                try {
                    speechRecognizer?.startListening(intent)
                } catch (e: SecurityException) {
                    result.error("PERMISSION_DENIED", "Microphone permission required", null)
                    cleanup()
                    return
                }
                
            } catch (e: Exception) {
                result.error("INITIALIZATION_ERROR", "Failed to start voice recognition: ${e.message}", null)
            }
        } ?: run {
            result.error("NO_ACTIVITY", "Activity not available", null)
        }
    }

    private fun stopListening() {
        speechRecognizer?.stopListening()
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
            "kn-IN", "ml-IN", "mr-IN", "or-IN", "pa-IN"
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