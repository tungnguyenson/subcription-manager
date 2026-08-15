package space.denhan.platform

/** JVM stand-in so common code compiles for tests. There is no JVM OCR. */
actual class TextRecognizer {
    actual fun supportedLanguages(): List<String> = emptyList()
    actual suspend fun recognize(image: ByteArray): RecognizedPage = RecognizedPage(emptyList())
}
