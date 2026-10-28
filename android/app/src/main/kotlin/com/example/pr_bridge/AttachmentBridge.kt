package com.example.pr_bridge

import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

/** Only private UUID-named files are exposed, with a one-time URI read grant. */
class AttachmentBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val directory get() = File(activity.filesDir, "attachments").apply { mkdirs() }
    private val limit = 10L * 1024 * 1024
    private var pending: MethodChannel.Result? = null
    private var cameraFile: File? = null
    private val types = mapOf("jpg" to "image/jpeg", "jpeg" to "image/jpeg", "png" to "image/png", "webp" to "image/webp", "pdf" to "application/pdf", "doc" to "application/msword", "docx" to "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "txt" to "text/plain")
    init {
        MethodChannel(messenger, "projectbridge/attachments").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "pick" -> pick(call.argument<String>("source") ?: "files", result)
                    "resolve" -> {
                        val file = managed(call.argument<String>("id") ?: "")
                        validate(file, file.extension)
                        result.success(file.path)
                    }
                    "open" -> {
                        val file = managed(call.argument<String>("id") ?: "")
                        validate(file, file.extension)
                        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.attachments", file)
                        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, types[file.extension])
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        try { activity.startActivity(intent); result.success(true) }
                        catch (_: android.content.ActivityNotFoundException) { result.success(false) }
                    }
                    "delete" -> { managed(call.argument<String>("id") ?: "").delete(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("ATTACHMENT_ERROR", e.message ?: "Could not access the attachment.", null) }
        }
    }
    private fun managed(id: String): File {
        require(Regex("[a-f0-9-]{36}\\.(jpg|jpeg|png|webp|pdf|doc|docx|txt)").matches(id)) { "Invalid private attachment reference." }
        return File(directory, id).also { require(it.canonicalFile.parentFile == directory.canonicalFile) }
    }
    @Suppress("DEPRECATION")
    private fun pick(source: String, result: MethodChannel.Result) {
        check(pending == null) { "A picker is already open." }
        require(source in listOf("gallery", "camera", "files"))
        val intent = if (source == "camera") {
            val file = File(directory, "${UUID.randomUUID()}.jpg")
            cameraFile = file
            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.attachments", file)
            Intent(MediaStore.ACTION_IMAGE_CAPTURE).putExtra(MediaStore.EXTRA_OUTPUT, uri)
                .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .apply { clipData = android.content.ClipData.newRawUri("ProjectBridge photo", uri) }
        } else Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (source == "gallery") "image/*" else "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, if (source == "gallery") arrayOf("image/jpeg", "image/png", "image/webp") else types.values.distinct().toTypedArray())
        }
        pending = result
        try { activity.startActivityForResult(intent, 8401) }
        catch (e: Exception) { pending = null; cameraFile?.delete(); cameraFile = null; throw IllegalStateException("No compatible picker or camera is installed.") }
    }
    fun onResult(code: Int, status: Int, data: Intent?) {
        if (code != 8401) return
        val result = pending ?: return
        pending = null
        val camera = cameraFile
        cameraFile = null
        if (status != Activity.RESULT_OK) { camera?.delete(); result.success(null); return }
        Thread {
            var copied: File? = null
            try {
                val name: String
                val file: File
                if (camera != null) { file = camera; name = "Camera photo.jpg"; copied = camera }
                else {
                    val uri = data?.data ?: throw IllegalArgumentException("No file selected.")
                    require(uri.scheme == "content") { "Select a file with the Android picker." }
                    var display = ""
                    activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            display = cursor.getString(0) ?: ""
                            if (!cursor.isNull(1)) require(cursor.getLong(1) <= limit) { "Choose a file of 10 MB or less." }
                        }
                    }
                    name = display.substringAfterLast('/').substringAfterLast('\\').take(160)
                    val ext = name.substringAfterLast('.', "").lowercase()
                    require(types.containsKey(ext)) { "Supported files: JPG, PNG, WEBP, PDF, DOC, DOCX and TXT." }
                    file = File(directory, "${UUID.randomUUID()}.$ext")
                    copied = file
                    activity.contentResolver.openInputStream(uri)?.use { input ->
                        file.outputStream().use { out ->
                            val buffer = ByteArray(8192); var total = 0L
                            while (true) { val count = input.read(buffer); if (count < 0) break; total += count; require(total <= limit) { "Choose a file of 10 MB or less." }; out.write(buffer, 0, count) }
                        }
                    } ?: throw IllegalArgumentException("This file could not be read.")
                }
                validate(file, file.extension)
                val metadata = mapOf("id" to file.name, "name" to name, "size" to file.length(), "mime" to types[file.extension])
                activity.runOnUiThread { result.success(metadata) }
            } catch (e: Exception) {
                copied?.delete()
                activity.runOnUiThread { result.error("ATTACHMENT_ERROR", e.message ?: "Could not import this file.", null) }
            }
        }.start()
    }
    private fun validate(file: File, ext: String) {
        require(file.isFile) { "This attachment is missing from this device." }
        require(file.length() in 1..limit) { "Choose a nonempty file of 10 MB or less." }
        require(types.containsKey(ext)) { "Unsupported file type." }
        val bytes = file.inputStream().use { input -> ByteArray(16).also { input.read(it) } }
        if (types[ext]!!.startsWith("image/")) {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, bounds)
            require(bounds.outWidth > 0 && bounds.outHeight > 0 && bounds.outWidth.toLong() * bounds.outHeight <= 40000000) { "Choose a valid image under 40 megapixels." }
            require(bounds.outMimeType == types[ext]) { "The image contents do not match its extension." }
        } else when (ext) {
            "pdf" -> require(String(bytes.copyOfRange(0, 5), Charsets.US_ASCII) == "%PDF-") { "Not a valid PDF file." }
            "docx" -> java.util.zip.ZipFile(file).use { zip -> require(zip.getEntry("[Content_Types].xml") != null && zip.getEntry("word/document.xml") != null) { "Not a valid DOCX file." } }
            "doc" -> require(bytes.take(8).map { it.toInt() and 255 } == listOf(208,207,17,224,161,177,26,225)) { "Not a valid DOC file." }
            "txt" -> require(file.inputStream().buffered().use { input -> val b = ByteArray(minOf(file.length(), 8192).toInt()); input.read(b); !b.contains(0.toByte()) }) { "Not a plain text document." }
        }
    }
}
