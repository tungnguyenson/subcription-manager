package space.denhan.data

import app.cash.sqldelight.db.SqlDriver
import space.denhan.db.DenHanDb

/**
 * Platform-specific driver construction.
 *
 * On iOS the database file must live in the App Group container from the very
 * first commit, even though the Lock Screen widget is a later phase: the widget
 * runs in a separate process and can only read a shared container, and moving a
 * populated database later means writing a migration for a problem that did not
 * need to exist. See product-spec.md section 9.0bis.
 */
expect class DriverFactory {
    fun create(): SqlDriver
}

fun createDatabase(factory: DriverFactory): DenHanDb = DenHanDb(factory.create())
