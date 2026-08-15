package space.denhan.data

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import space.denhan.db.DenHanDb

/** JVM target exists so repository tests run without a simulator or emulator. */
actual class DriverFactory(private val path: String = JdbcSqliteDriver.IN_MEMORY) {
    actual fun create(): SqlDriver = JdbcSqliteDriver(path).also { driver ->
        DenHanDb.Schema.create(driver)
        driver.enableForeignKeys()
    }
}

/**
 * SQLite ignores foreign keys unless told otherwise, per connection.
 *
 * Without this, ON DELETE CASCADE and ON DELETE SET NULL silently do nothing:
 * deleting an item leaves its history rows orphaned, and deleting a group leaves
 * its items pointing at a row that no longer exists. Nothing errors, the data
 * just quietly rots.
 */
internal fun SqlDriver.enableForeignKeys() {
    execute(identifier = null, sql = "PRAGMA foreign_keys = ON", parameters = 0)
}
