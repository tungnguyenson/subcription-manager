package space.denhan.platform

/**
 * On-device text recognition.
 *
 * The image never leaves the phone. Only the recognised text does, and only
 * after the user has seen it and redacted whatever they want removed. That
 * ordering is what makes redaction safe by construction: whatever the recogniser
 * failed to read was also never transmitted, so a miss is a non-event rather
 * than a leak. See product-spec.md sections 8.2bis and 8.3bis.
 */
expect class TextRecognizer {

    /** Whether the platform can recognise the requested language at all. */
    fun supportedLanguages(): List<String>

    suspend fun recognize(image: ByteArray): RecognizedPage
}

/**
 * One recognised line, with the box it occupied so the redaction UI can draw
 * over the original image while the payload stays text.
 *
 * Coordinates are normalised 0..1 with the origin at the TOP-left, already
 * flipped from Vision's bottom-left convention.
 */
data class RecognizedLine(
    val text: String,
    val confidence: Float,
    val left: Double,
    val top: Double,
    val right: Double,
    val bottom: Double,
)

data class RecognizedPage(
    val lines: List<RecognizedLine>,

    /**
     * Regions that look like text but produced no transcription.
     *
     * A commercial SDK doing the same job documents that Vision periodically
     * drops lines it cannot confidently transcribe. Those are not silently
     * ignored here: the count drives a "some text could not be read" warning so
     * the user knows to retake the photo rather than trusting a partial read.
     */
    val unreadRegionCount: Int = 0,

    val languageUsed: String? = null,
) {
    /**
     * Lines joined in reading order.
     *
     * Deliberately plain text with no coordinate tokens and no whitespace grid.
     * Measured results say layout reconstruction is worth nothing on screenshots
     * (WebSRC 80.5 plain vs 80.7 spatial) and actively harmful on receipts
     * (SROIE 79.9 plain vs 77.0 spatial). The simplest serialisation is also the
     * best one for the images this app handles.
     */
    fun asPrompt(): String = lines
        .sortedWith(compareBy({ it.top }, { it.left }))
        .joinToString("\n") { it.text }

    val averageConfidence: Float
        get() = if (lines.isEmpty()) 0f else lines.map { it.confidence }.average().toFloat()

    /** Below this, offer the user the option of sending the image instead. */
    fun isLowQuality(threshold: Float = LOW_CONFIDENCE): Boolean =
        lines.isEmpty() || averageConfidence < threshold || unreadRegionCount > 0

    companion object {
        const val LOW_CONFIDENCE = 0.5f
    }
}
