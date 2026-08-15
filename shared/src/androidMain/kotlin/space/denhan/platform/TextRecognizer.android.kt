package space.denhan.platform

/** Android is not a shipping target yet; ML Kit would go here. */
actual class TextRecognizer {
    actual fun supportedLanguages(): List<String> = emptyList()
    actual suspend fun recognize(image: ByteArray): RecognizedPage = TODO("Android target not implemented")
}
