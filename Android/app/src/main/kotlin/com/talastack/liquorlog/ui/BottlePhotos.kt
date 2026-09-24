package com.talastack.liquorlog.ui

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import com.talastack.liquorlog.data.BottlePhotoStore
import com.talastack.liquorlog.ui.theme.Space
import com.talastack.liquorlog.ui.theme.TypeScale
import com.talastack.liquorlog.ui.theme.palette
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Bottle photos: shrinking them, showing them, and the menu that sets one.
 *
 * The Compose counterpart of the SwiftUI `BottlePhoto`. A photo is the
 * "which one was it" of a collection past fifty bottles, and the thing an
 * insurance claim asks for. It is stored on this device only (see
 * [BottlePhotoStore]); nothing here uploads anything.
 */
object BottlePhoto {

    /**
     * Longest side after shrinking. A shelf photo at full resolution is
     * several megabytes; at 1600 px it is a few hundred kilobytes and still
     * reads a label.
     */
    const val MAX_PIXELS = 1600

    fun jpeg(bitmap: Bitmap): ByteArray {
        val longest = max(bitmap.width, bitmap.height)
        val scale = min(1f, MAX_PIXELS.toFloat() / max(longest, 1))
        val shrunk = if (scale >= 1f) {
            bitmap
        } else {
            Bitmap.createScaledBitmap(
                bitmap,
                (bitmap.width * scale).roundToInt().coerceAtLeast(1),
                (bitmap.height * scale).roundToInt().coerceAtLeast(1),
                true,
            )
        }
        val out = ByteArrayOutputStream()
        shrunk.compress(Bitmap.CompressFormat.JPEG, 82, out)
        return out.toByteArray()
    }

    /**
     * A picked or photographed image, at roughly the size we keep.
     *
     * Bounds first, then a sampled decode: a modern phone camera hands back
     * fifty megapixels, and decoding that at full size to throw most of it
     * away is how a photo picker runs the app out of memory.
     */
    fun decode(context: Context, uri: Uri): Bitmap? {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        // No null check on the result: a bounds pass returns null BY DESIGN
        // and writes its answer into `bounds`. Reading that as a failure is
        // how every photo came back "could not be read".
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight)
        }
        val bitmap = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        } ?: return null
        // Turned now, before it is stored, so every later read is a plain
        // decode and the file itself is the right way up in a backup.
        val orientation = resolver.openInputStream(uri)?.use {
            ExifInterface(it).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } ?: ExifInterface.ORIENTATION_NORMAL
        return turned(bitmap, orientation)
    }

    /** Null for no photo, no store, or a file that is not there. */
    fun load(fileName: String?, store: BottlePhotoStore?): ImageBitmap? {
        if (fileName == null || store == null || !store.exists(fileName)) return null
        return BitmapFactory.decodeFile(store.file(fileName).absolutePath)?.asImageBitmap()
    }

    private fun sampleSize(width: Int, height: Int): Int {
        var sample = 1
        while (max(width, height) / (sample * 2) >= MAX_PIXELS) sample *= 2
        return sample
    }

    private fun turned(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            else -> return bitmap
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}

/**
 * The photo when there is one, the bottle mark when there is not. Both sit
 * in the same frame so a list does not jump between the two.
 */
@Composable
fun BottleImage(fileName: String?, height: Dp = 58.dp) {
    val state = LocalAppState.current
    val colors = palette
    val image = remember(fileName, state.changeCount) {
        BottlePhoto.load(fileName, state.photos)
    }
    if (image == null) {
        BottleMark(height = height)
        return
    }
    val shape = RoundedCornerShape(maxOf(4.dp, height / 12))
    Image(
        bitmap = image,
        contentDescription = "Your photo of this bottle",
        contentScale = ContentScale.Crop,
        modifier = Modifier
            .width(height * 0.72f)
            .height(height)
            .clip(shape)
            .border(1.dp, colors.line, shape),
    )
}

/**
 * The photograph at the top of a bottle, big, with the menu that sets it.
 *
 * Camera and library both, and neither asks for a permission: the photo
 * picker hands back one image without READ_MEDIA_IMAGES, and the camera runs
 * through the system camera app rather than the CAMERA permission. An app
 * that asks for a whole photo library in order to store one picture is the
 * thing people uninstall.
 */
@Composable
fun BottleHeroPhoto(bottleId: String, fileName: String?, onChange: () -> Unit) {
    val state = LocalAppState.current
    val colors = palette
    val context = LocalContext.current
    val store = state.photos
    val image = remember(fileName, state.changeCount) { BottlePhoto.load(fileName, store) }

    if (image == null) {
        BottleMark(height = 104.dp)
    } else {
        val shape = RoundedCornerShape(14.dp)
        Image(
            bitmap = image,
            contentDescription = "Your photo of this bottle",
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .height(260.dp)
                .clip(shape)
                .border(1.dp, colors.line, shape),
        )
    }

    if (store == null) return

    var open by remember { mutableStateOf(false) }
    var failure by remember { mutableStateOf<String?>(null) }

    // New file first, then the row, then the old file. A failure anywhere
    // before the row is written leaves the old photo in place.
    fun set(bitmap: Bitmap?) {
        try {
            val newName = bitmap?.let { store.save(BottlePhoto.jpeg(it)) }
            state.bottles.setPhoto(bottleId, newName)
            if (fileName != null && fileName != newName) store.delete(fileName)
            failure = null
            onChange()
        } catch (e: Exception) {
            failure = e.message ?: "That photo could not be saved."
        }
    }

    val library = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia(),
    ) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        val bitmap = BottlePhoto.decode(context, uri)
        if (bitmap == null) failure = "That photo could not be read." else set(bitmap)
    }

    // The camera writes to a file we own in the cache, which the FileProvider
    // hands out for the life of the one intent. Kept in state so the result
    // callback can find it again after the camera app has taken over.
    var pending by remember { mutableStateOf<File?>(null) }
    val camera = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture(),
    ) { taken: Boolean ->
        val file = pending
        pending = null
        if (!taken || file == null) {
            file?.delete()
            return@rememberLauncherForActivityResult
        }
        val bitmap = BottlePhoto.decode(context, Uri.fromFile(file))
        file.delete()
        if (bitmap == null) failure = "That photo could not be read." else set(bitmap)
    }

    Box {
        Row(
            horizontalArrangement = Arrangement.spacedBy(Space.xs),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .clickable { open = true }
                .padding(Space.s)
                .semantics {
                    contentDescription = if (fileName == null) "Add a photo" else "Change photo"
                },
        ) {
            Icon(
                Icons.Filled.PhotoCamera,
                contentDescription = null,
                tint = colors.accent,
                modifier = Modifier.size(18.dp),
            )
            Text(
                if (fileName == null) "Add a photo" else "Change photo",
                style = TypeScale.secondary,
                color = colors.accent,
            )
        }
        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false },
            modifier = Modifier.background(colors.surface),
        ) {
            if (context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
                DropdownMenuItem(
                    text = { Text("Take a photo", style = TypeScale.body, color = colors.text) },
                    onClick = {
                        open = false
                        val folder = File(context.cacheDir, "camera").apply { mkdirs() }
                        val file = File(folder, "taking.jpg")
                        pending = file
                        camera.launch(
                            FileProvider.getUriForFile(
                                context,
                                context.packageName + ".files",
                                file,
                            ),
                        )
                    },
                )
            }
            DropdownMenuItem(
                text = {
                    Text("Choose from library", style = TypeScale.body, color = colors.text)
                },
                onClick = {
                    open = false
                    library.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                    )
                },
            )
            if (fileName != null) {
                DropdownMenuItem(
                    text = { Text("Remove photo", style = TypeScale.body, color = colors.bad) },
                    onClick = {
                        open = false
                        set(null)
                    },
                )
            }
        }
    }

    failure?.let {
        Text(it, style = TypeScale.caption, color = colors.bad)
    }
}
