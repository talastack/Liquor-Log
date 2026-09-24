package com.talastack.liquorlog.data

import java.io.File
import java.util.UUID

/**
 * Where a bottle's photo lives: a JPEG file on this device, named by a UUID.
 *
 * The Kotlin half of the Swift `BottlePhotoStore`, down to the file naming,
 * so the two platforms describe a photo the same way. The bottle row stores
 * the file NAME and the name syncs; the bytes do not. That is deliberate.
 * Photo backup is a service somebody could pay for later, and the free tier
 * is the person's own data handed back.
 *
 * Plain files and no Android types: the folder arrives from the app, which
 * is what makes this testable on a JVM runner. A missing file is not an
 * error here; the screen shows the bottle mark instead, the same as a bottle
 * that never had a photo.
 */
class BottlePhotoStore(val folder: File) {

    init {
        folder.mkdirs()
    }

    /**
     * Writes JPEG bytes under a fresh name and returns the name to store on
     * the bottle. Never overwrites: replacing a photo is a new file and a
     * delete of the old one, so a failed write cannot destroy the previous
     * picture.
     */
    fun save(jpeg: ByteArray): String {
        val name = UUID.randomUUID().toString() + ".jpg"
        // Written aside and moved into place, so a process killed mid-write
        // leaves no half a photo under a name the database already points at.
        val staged = File(folder, "$name.part")
        staged.writeBytes(jpeg)
        if (!staged.renameTo(file(name))) {
            staged.delete()
            throw IllegalStateException("Could not store the photo")
        }
        return name
    }

    fun file(fileName: String): File = File(folder, fileName)

    fun exists(fileName: String): Boolean = file(fileName).isFile

    fun bytes(fileName: String): ByteArray? =
        file(fileName).takeIf { it.isFile }?.readBytes()

    /** Silently fine when the file is already gone. */
    fun delete(fileName: String) {
        file(fileName).delete()
    }
}
