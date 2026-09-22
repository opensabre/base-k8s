import base64
import json
from pathlib import Path
import unittest

from scripts.verify_jwt_issuer_deployment import jwt_issuer, shared_issuer


def encode(value):
    return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip("=")


class JwtIssuerDeploymentTest(unittest.TestCase):
    def test_reads_exact_issuer_from_jwt(self):
        token = f"{encode({'alg': 'none'})}.{encode({'iss': 'http://opensabre:8000'})}.signature"
        self.assertEqual("http://opensabre:8000", jwt_issuer(token))

    def test_rejects_token_without_issuer(self):
        token = f"{encode({'alg': 'none'})}.{encode({'sub': 'admin'})}.signature"
        with self.assertRaisesRegex(ValueError, "iss"):
            jwt_issuer(token)

    def test_reads_issuer_from_shared_config(self):
        content = """spring:\n  security:\n    oauth2:\n      resourceserver:\n        jwt:\n          issuer-uri: ${AUTH_ISSUER_URI:http://opensabre:8000}\n"""
        self.assertEqual("http://opensabre:8000", shared_issuer(content))

    def test_rejects_shared_config_without_issuer(self):
        with self.assertRaisesRegex(ValueError, "issuer-uri"):
            shared_issuer("spring:\n  application:\n    name: test\n")

    def test_compose_does_not_override_shared_issuer(self):
        root = Path(__file__).resolve().parents[1]
        compose_files = list(root.glob("docker-compose*.yml"))
        override = "SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI"
        offenders = [path.name for path in compose_files if override in path.read_text()]
        self.assertEqual([], offenders)


if __name__ == "__main__":
    unittest.main()
