import importlib.util
import pathlib
import re
import tempfile
import unittest
from unittest.mock import patch

import bcrypt


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "provision-actuator-oauth-clients.py"
SPEC = importlib.util.spec_from_file_location("actuator_oauth_provision", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ProvisionActuatorOAuthClientsTest(unittest.TestCase):
    def test_existing_client_updates_only_ttl_and_preserves_secret(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = pathlib.Path(temporary)
            secret_file = directory / "prometheus-oauth-client-secret"
            secret_file.write_text("existing-secret")
            with patch.object(MODULE, "SECRET_DIR", directory), \
                    patch.object(MODULE, "mysql", side_effect=["1", ""]) as mysql:
                MODULE.provision("opensabre-prometheus", secret_file.name)
            update = mysql.call_args.args[0]
            self.assertIn("JSON_SET", update)
            self.assertIn("3600", update)
            self.assertIn("WHERE client_id = 'opensabre-prometheus' AND deleted = 'N'", update)
            self.assertNotIn("client_secret", update)
            self.assertEqual("existing-secret", secret_file.read_text())

    def test_provisions_scoped_client_without_storing_plaintext_in_sql(self):
        with tempfile.TemporaryDirectory() as temporary:
            MODULE.SECRET_DIR = pathlib.Path(temporary)
            commands = []

            def fake_mysql(sql):
                commands.append(sql)
                return "0" if sql.startswith("SELECT") else ""

            previous_mysql = MODULE.mysql
            MODULE.mysql = fake_mysql
            try:
                MODULE.provision("opensabre-prometheus", "prometheus-oauth-client-secret")
            finally:
                MODULE.mysql = previous_mysql

            secret = (MODULE.SECRET_DIR / "prometheus-oauth-client-secret").read_text()
            insert = commands[1]
            password_hash = re.search(r"\$2[aby]\$[^']+", insert).group()
            self.assertTrue(bcrypt.checkpw(secret.encode(), password_hash.encode()))
            self.assertNotIn(secret, insert)
            self.assertIn("'actuator.read'", insert)
            self.assertIn("'client_credentials'", insert)
            self.assertIn('"settings.token.access-token-time-to-live":3600', insert)
            self.assertEqual((MODULE.SECRET_DIR / "prometheus-oauth-client-secret").stat().st_mode & 0o777,
                             0o600)


if __name__ == "__main__":
    unittest.main()
