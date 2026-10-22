import re
import sqlite3
import unittest
from pathlib import Path

SOURCE = (Path(__file__).resolve().parents[1] / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')


def statements(source):
    pattern = r"db\s*\.execute\s*\(\s*(?:'''([\s\S]*?)'''|'((?:\\.|[^'\\])*)')\s*\)"
    return [match.group(1) or match.group(2) for match in re.finditer(pattern, source)]


CREATE = SOURCE.split('Future<void> _onCreate(')[1].split('Future<void> _onUpgrade(')[0]
UPGRADE = SOURCE.split('Future<void> _onUpgrade(')[1].split('Future<void> _createLibraryIndexCache(')[0]
CACHE = statements('db.execute(' + SOURCE.split('Future<void> _createLibraryIndexCache(')[1].split('db.execute(')[1])[0]
BLOCKS = [(int(match.group(1)), match.group(2)) for match in re.finditer(
    r'if \(oldVersion < (\d+)\) \{([\s\S]*?)(?=\n    if|\n  \})', UPGRADE)]


def execute_block(database, body):
    if '_createLibraryIndexCache(db)' in body:
        database.execute(CACHE)
    for sql in statements(body):
        database.execute(sql)


def history_columns(database):
    return {row[1] for row in database.execute('PRAGMA table_info(watch_history)')}


class DatabaseSchemaTest(unittest.TestCase):
    def test_fresh_install_has_subtitle_audio_and_index_columns(self):
        database = sqlite3.connect(':memory:')
        database.execute(CACHE)
        for sql in statements(CREATE):
            database.execute(sql)
        self.assertTrue({'subtitle_paths', 'selected_subtitle_track', 'selected_audio_track'} <= history_columns(database))
        self.assertEqual(database.execute('SELECT COUNT(*) FROM library_index_cache').fetchone()[0], 0)
        database.close()

    def test_all_legacy_versions_upgrade_without_duplicate_columns_or_lost_rows(self):
        self.assertEqual({version for version, _ in BLOCKS}, {2, 3, 4, 5, 6, 7})
        for version in range(1, 7):
            with self.subTest(version=version):
                database = sqlite3.connect(':memory:')
                for sql in statements(CREATE):
                    if 'watch_history' not in sql and 'downloads' not in sql:
                        database.execute(sql)
                for threshold, body in BLOCKS:
                    if threshold <= version:
                        execute_block(database, body)
                database.execute("INSERT INTO videos (id,path,title,folder_path,folder_name,size,duration,date_added,updated_at) VALUES ('kept','/kept.mp4','kept','/','root',100,1000,1,1)")
                database.execute("INSERT INTO favorites (video_id,added_at) VALUES ('kept',1)")
                if version >= 2:
                    database.execute("INSERT INTO watch_history (video_id,position_ms,duration_ms,last_played_at) VALUES ('kept',123,1000,1)")
                for threshold, body in BLOCKS:
                    if version < threshold:
                        execute_block(database, body)
                self.assertTrue({'subtitle_paths', 'selected_subtitle_track', 'selected_audio_track'} <= history_columns(database))
                self.assertEqual(database.execute('SELECT COUNT(*) FROM videos').fetchone()[0], 1)
                self.assertEqual(database.execute('SELECT COUNT(*) FROM favorites').fetchone()[0], 1)
                if version >= 2:
                    self.assertEqual(database.execute('SELECT position_ms FROM watch_history').fetchone()[0], 123)
                database.close()


if __name__ == '__main__':
    unittest.main()
