package space.denhan.data

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver
import kotlinx.cinterop.ExperimentalForeignApi
import platform.Foundation.NSFileManager
import platform.Foundation.NSURL
import space.denhan.db.DenHanDb

/**
 * The App Group the app and its widget share.
 *
 * Must match the App Groups capability in the Xcode project. If it does not,
 * [containerPath] returns null and we fall back to the app-private directory,
 * which works fine until the widget ships and then silently shows nothing.
 */
const val APP_GROUP_ID = "group.space.denhan"

const val DB_FILE_NAME = "denhan.db"

@OptIn(ExperimentalForeignApi::class)
actual class DriverFactory {

    actual fun create(): SqlDriver = NativeSqliteDriver(
        schema = DenHanDb.Schema,
        name = DB_FILE_NAME,
        onConfiguration = { config ->
            config.copy(
                extendedConfig = config.extendedConfig.copy(
                    basePath = databaseDirectory(),
                    // SQLite ignores foreign keys unless told otherwise, so
                    // ON DELETE CASCADE would silently do nothing and history
                    // rows would outlive the item they belong to.
                    foreignKeyConstraints = true,
                ),
            )
        },
    )

    /**
     * Prefers the shared container so a widget process can read the same file.
     * Falls back to the app's own Documents directory when the App Group is not
     * configured, so a fresh checkout still runs.
     */
    private fun databaseDirectory(): String? =
        appGroupContainerPath() ?: documentsPath()

    private fun appGroupContainerPath(): String? =
        NSFileManager.defaultManager
            .containerURLForSecurityApplicationGroupIdentifier(APP_GROUP_ID)
            ?.path

    private fun documentsPath(): String? {
        val urls = NSFileManager.defaultManager.URLsForDirectory(
            directory = platform.Foundation.NSDocumentDirectory,
            inDomains = platform.Foundation.NSUserDomainMask,
        )
        return (urls.firstOrNull() as? NSURL)?.path
    }
}
