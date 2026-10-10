"""Exercise the actual shared shell validator with isolated migration layouts."""
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts/validate-flyway-migrations.sh"
TRIGGER = """DELIMITER $$
CREATE TRIGGER audit_action AFTER UPDATE ON action_ledger
FOR EACH ROW
BEGIN
 IF NEW.version <> OLD.version THEN
  INSERT INTO action_event VALUES (NEW.id);
 END IF;
END$$
DELIMITER ;
"""


class TriggerLayoutTest(unittest.TestCase):
    def check_layout(self, sql, success):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory) / "fixture/src/main/resources/db/migration/mysql"
            for name in ("baseline", "history", "ddl", "dml"):
                (root / name).mkdir(parents=True)
            (root / "baseline/B1__baseline.sql").write_text("CREATE TABLE action_ledger(id INT);\n")
            (root / "ddl/V2__ddl_action_trigger.sql").write_text(sql)
            result = subprocess.run(["bash", str(SCRIPT), directory, "fixture"], capture_output=True, text=True)
            self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)

    def test_trigger_body_is_schema_definition(self):
        self.check_layout(TRIGGER, True)

    def test_top_level_dml_before_or_after_trigger_still_rejected(self):
        for dml in ("INSERT INTO action_ledger VALUES (1);", "UPDATE action_ledger SET id=2;", "DELETE FROM action_ledger;"):
            for sql in (dml + "\n" + TRIGGER, TRIGGER + dml + "\n"):
                with self.subTest(sql=sql):
                    self.check_layout(sql, False)

    def test_unterminated_or_missing_explicit_delimiter_is_rejected(self):
        self.check_layout(TRIGGER.replace("END$$", ""), False)
        self.check_layout(TRIGGER.replace("DELIMITER $$\n", ""), False)

    def test_trigger_does_not_exempt_database_target_guard(self):
        self.check_layout(TRIGGER.replace("INSERT INTO action_event", "INSERT INTO `iqc_platform`.action_event"), False)
