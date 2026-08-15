package space.denhan.platform

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.alloc
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.ptr
import kotlinx.cinterop.useContents
import kotlinx.cinterop.value
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import platform.CoreFoundation.CFTypeRefVar
import platform.Foundation.NSData
import platform.Foundation.create
import platform.UIKit.UIImage
import platform.Vision.VNDetectTextRectanglesRequest
import platform.Vision.VNImageRequestHandler
import platform.Vision.VNRecognizeTextRequest
import platform.Vision.VNRecognizedTextObservation
import platform.Vision.VNRequestTextRecognitionLevelAccurate
import platform.Vision.VNTextObservation

/**
 * Vision-backed text recognition, entirely in Kotlin.
 *
 * `platform.Vision` ships enabled in Kotlin/Native's bundled Apple platform
 * libraries, so this needs no cinterop definition and no Swift bridge. The
 * newer Swift-only `RecognizeTextRequest` (iOS 18) is unreachable from
 * Kotlin/Native, but `VNRecognizeTextRequest` is not deprecated and still works.
 */
@OptIn(ExperimentalForeignApi::class)
actual class TextRecognizer {

    actual fun supportedLanguages(): List<String> {
        val request = VNRecognizeTextRequest()
        request.setRecognitionLevel(VNRequestTextRecognitionLevelAccurate)
        return memScoped {
            @Suppress("UNCHECKED_CAST")
            (request.supportedRecognitionLanguagesAndReturnError(null) as? List<String>).orEmpty()
        }
    }

    /**
     * Picks the Vietnamese tag the device actually reports.
     *
     * Vision returns `vi-VT` on some OS versions rather than the expected
     * `vi-VN`; two production codebases carry a workaround for exactly this. So
     * the tag is queried, never hardcoded. Vietnamese arrived in iOS 17.
     */
    private fun preferredLanguages(): List<String> {
        val supported = supportedLanguages()
        val vietnamese = supported.firstOrNull { it.startsWith("vi", ignoreCase = true) }
        val english = supported.firstOrNull { it.startsWith("en", ignoreCase = true) }
        return listOfNotNull(vietnamese, english).ifEmpty { listOf("en-US") }
    }

    actual suspend fun recognize(image: ByteArray): RecognizedPage {
        val cgImage = image.toUIImage()?.CGImage ?: return RecognizedPage(emptyList())
        val languages = preferredLanguages()

        val request = VNRecognizeTextRequest().apply {
            // Accurate uses a different algorithm from fast, not just a slower
            // one: it reads whole lines rather than character by character, which
            // is what copes with skewed photos and unusual fonts.
            setRecognitionLevel(VNRequestTextRecognitionLevelAccurate)
            setRecognitionLanguages(languages)

            // Language correction improves prose and corrupts exactly what this
            // app needs: amounts, reference numbers, short codes.
            setUsesLanguageCorrection(false)

            // minimumTextHeight is deliberately left at its default. Raising it
            // is faster but silently drops small print, which on a bill is where
            // the important dates live.
        }

        // Vision's recogniser periodically drops lines it cannot confidently
        // transcribe. This second pass is purely geometric and much cheaper, and
        // exists only to notice that something was missed so the user can be
        // told rather than shown a confident partial read.
        val geometryRequest = VNDetectTextRectanglesRequest()

        val handler = VNImageRequestHandler(cGImage = cgImage, options = emptyMap<Any?, Any?>())
        memScoped {
            val error = alloc<CFTypeRefVar>()
            handler.performRequests(listOf(request, geometryRequest), error.ptr.let { null })
        }

        val lines = (request.results.orEmpty())
            .filterIsInstance<VNRecognizedTextObservation>()
            .mapNotNull { it.toLine() }

        val geometryCount = (geometryRequest.results.orEmpty())
            .filterIsInstance<VNTextObservation>()
            .size

        return RecognizedPage(
            lines = lines,
            unreadRegionCount = (geometryCount - lines.size).coerceAtLeast(0),
            languageUsed = languages.firstOrNull(),
        )
    }

    private fun VNRecognizedTextObservation.toLine(): RecognizedLine? {
        val candidate = topCandidates(1u).firstOrNull() as? platform.Vision.VNRecognizedText ?: return null

        return boundingBox.useContents {
            RecognizedLine(
                text = candidate.string,
                confidence = candidate.confidence,
                left = origin.x,
                // Vision's origin is bottom-left; flip so the UI can draw
                // straight onto a top-left image without re-deriving this.
                top = 1.0 - (origin.y + size.height),
                right = origin.x + size.width,
                bottom = 1.0 - origin.y,
            )
        }
    }

    private fun ByteArray.toUIImage(): UIImage? {
        if (isEmpty()) return null
        val data = usePinned { pinned ->
            NSData.create(bytes = pinned.addressOf(0), length = size.toULong())
        }
        return UIImage.imageWithData(data)
    }
}
