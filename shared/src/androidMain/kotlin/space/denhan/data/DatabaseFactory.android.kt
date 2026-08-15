package space.denhan.data

import android.content.Context
import androidx.sqlite.db.SupportSQLiteDatabase
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import space.denhan.db.DenHanDb

const val DB_FILE_NAME_ANDROID = "denhan.db"

actual class DriverFactory(private val context: Context) {

    actual fun create(): SqlDriver = AndroidSqliteDriver(
        schema = DenHanDb.Schema,
        context = context,
        name = DB_FILE_NAME_ANDROID,
        callback = object : AndroidSqliteDriver.Callback(DenHanDb.Schema) {
            override fun onOpen(db: SupportSQLiteDatabase) {
                super.onOpen(db)
                // Without this, ON DELETE CASCADE silently does nothing and
                // history rows outlive the item they belong to.
                db.setForeignKeyConstraintsEnabled(true)
            }
        },
    )
}
