package space.denhan.extract

import io.ktor.client.HttpClient
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import kotlinx.serialization.json.addJsonObject

/**
 * Structured extraction against OpenAI's Responses API.
 *
 * Sends TEXT, never the image. The screenshot is recognised on-device and the
 * user reviews and redacts the recognised lines before anything is transmitted,
 * which is what makes the redaction meaningful: there is no original image on
 * the wire for a missed region to leak through.
 *
 * See product-spec.md sections 8.2bis and 8.4.
 */
class OpenAiClient(
    private val http: HttpClient,
    private val apiKeyProvider: () -> String?,
    private val model: String = DEFAULT_MODEL,
    private val baseUrl: String = "https://api.openai.com/v1",
) {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    suspend fun extract(
        text: String,
        todayIso: String,
        locale: String,
    ): Result<ExtractedFields> {
        val key = apiKeyProvider() ?: return Result.failure(ExtractionException(ExtractionError.NoApiKey))

        val response: HttpResponse = try {
            http.post("$baseUrl/responses") {
                header("Authorization", "Bearer $key")
                contentType(ContentType.Application.Json)
                setBody(requestBody(text, todayIso, locale).toString())
            }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (_: Throwable) {
            return Result.failure(ExtractionException(ExtractionError.NoNetwork))
        }

        val raw = response.bodyAsText()

        if (!response.status.isSuccess()) {
            return Result.failure(ExtractionException(parseError(response, raw)))
        }

        return parseSuccess(raw)
    }

    private fun requestBody(text: String, todayIso: String, locale: String): JsonObject = buildJsonObject {
        put("model", model)

        // Reasoning tokens bill as output tokens and are the largest line item in
        // a request that needs no reasoning. Left at the default this quietly
        // triples the cost of every extraction.
        putJsonObject("reasoning") { put("effort", "low") }

        // A truncated strict-JSON response is unparseable, not partially valid,
        // so the cap has to be paired with a status check below.
        put("max_output_tokens", 800)

        putJsonArray("input") {
            addJsonObject {
                put("role", "system")
                put("content", ExtractionSchema.systemPrompt(todayIso, locale))
            }
            addJsonObject {
                put("role", "user")
                put("content", text)
            }
        }

        // Responses API spelling. `response_format` is the Chat Completions
        // equivalent and is the most common porting mistake; `name` is a sibling
        // of `schema`, not nested under a wrapper.
        putJsonObject("text") {
            putJsonObject("format") {
                put("type", "json_schema")
                put("name", ExtractionSchema.NAME)
                put("strict", true)
                put("schema", Json.parseToJsonElement(ExtractionSchema.json))
            }
        }
    }

    private fun parseError(response: HttpResponse, raw: String): ExtractionError {
        val error = runCatching {
            json.parseToJsonElement(raw).jsonObject["error"]?.jsonObject
        }.getOrNull()

        return ErrorMapper.map(
            status = response.status.value,
            errorCode = error?.get("code")?.jsonPrimitive?.contentOrNullSafe(),
            errorType = error?.get("type")?.jsonPrimitive?.contentOrNullSafe(),
            retryAfterSeconds = response.headers["Retry-After"]?.toIntOrNull(),
        )
    }

    private fun parseSuccess(raw: String): Result<ExtractedFields> {
        val root = runCatching { json.parseToJsonElement(raw).jsonObject }.getOrNull()
            ?: return Result.failure(ExtractionException(ExtractionError.Malformed("not json")))

        // Check status before parsing: an incomplete response holds truncated
        // JSON that will not parse and must not be treated as a parse bug.
        if (root["status"]?.jsonPrimitive?.contentOrNullSafe() == "incomplete") {
            return Result.failure(ExtractionException(ExtractionError.Truncated))
        }

        val content = root["output"]?.jsonArray
            ?.firstOrNull()?.jsonObject
            ?.get("content")?.jsonArray
            ?.firstOrNull()?.jsonObject

        // A refusal does not honour the schema at all.
        content?.get("refusal")?.jsonPrimitive?.contentOrNullSafe()?.let {
            return Result.failure(ExtractionException(ExtractionError.Refused(it)))
        }

        val payload = content?.get("text")?.jsonPrimitive?.contentOrNullSafe()
            ?: root["output_text"]?.jsonPrimitive?.contentOrNullSafe()
            ?: return Result.failure(ExtractionException(ExtractionError.Malformed("no output text")))

        return runCatching { json.decodeFromString<ExtractedFields>(payload) }
            .fold(
                onSuccess = { Result.success(it) },
                onFailure = { Result.failure(ExtractionException(ExtractionError.Malformed(it.message))) },
            )
    }

    companion object {
        /**
         * Current-generation budget tier. Not gpt-5-nano: cheaper on paper but
         * deprecated with a shutdown date and no Responses API support.
         */
        const val DEFAULT_MODEL = "gpt-5.6-luna"
    }
}

class ExtractionException(val error: ExtractionError) : Exception(error.messageVi)

private fun kotlinx.serialization.json.JsonPrimitive.contentOrNullSafe(): String? =
    if (this is kotlinx.serialization.json.JsonNull) null else content

private fun kotlinx.serialization.json.JsonObjectBuilder.putJsonArray(
    key: String,
    builder: kotlinx.serialization.json.JsonArrayBuilder.() -> Unit,
) {
    put(key, buildJsonArray(builder))
}
