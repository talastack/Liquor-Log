package com.talastack.liquorlog.data

import java.io.File
import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class BottlePhotoStoreTest {

    private fun store(): BottlePhotoStore =
        BottlePhotoStore(File(Files.createTempDirectory("photos").toFile(), "bottles"))

    @Test
    fun `a saved photo comes back byte for byte`() {
        val store = store()
        val bytes = byteArrayOf(-1, -40, -1, 0, 1, 2, 3)

        val name = store.save(bytes)
        assertTrue(store.exists(name))
        assertContentEquals(bytes, store.bytes(name))
    }

    @Test
    fun `replacing a photo does not overwrite the old file`() {
        // The screen writes the new file, points the row at it, and only then
        // deletes the old one. A save that reused the name would destroy the
        // previous picture before the row was written.
        val store = store()
        val first = store.save(byteArrayOf(1))
        val second = store.save(byteArrayOf(2))

        assertTrue(first != second)
        assertContentEquals(byteArrayOf(1), store.bytes(first))
        assertContentEquals(byteArrayOf(2), store.bytes(second))
    }

    @Test
    fun `a photo that is not there is not an error`() {
        // A device restored without its photo folder still has the names on
        // its bottles. Those screens show the bottle mark, not a failure.
        val store = store()

        assertFalse(store.exists("nothing.jpg"))
        assertNull(store.bytes("nothing.jpg"))
        store.delete("nothing.jpg")
    }

    @Test
    fun `nothing is left behind under a half written name`() {
        val store = store()
        val name = store.save(byteArrayOf(9))

        assertContentEquals(listOf(name), store.folder.list()!!.sorted())
    }
}
