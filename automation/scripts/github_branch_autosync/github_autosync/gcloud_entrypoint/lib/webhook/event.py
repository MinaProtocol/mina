import hashlib
import hmac
from http.client import HTTPException
from .info import GithubPayloadInfo


class WebHookEvent:

    def __init__(self,flask_request):
        self.request = flask_request

    def info(self):
        return GithubPayloadInfo(self.request)
    
    def verify_signature(self, config):
        """Verify that the payload was sent from GitHub by validating SHA256.
        
        Raise and return 403 if not authorized.

        Taken from: https://docs.github.com/en/webhooks-and-events/webhooks/securing-your-webhooks
        
        Args:
            config: application configuration
        """
        payload_body = self.request.data
        signature_header = self.request.headers['x-hub-signature-256']
        repo = self.info().repository
        secret_token = config.get_secret_token_for_repo(repo)

        if secret_token is None:
            raise HTTPException(f"cannot find secret token in configuration for incoming repository {repo}")

        if not signature_header:
            raise HTTPException(status_code=403, detail="x-hub-signature-256 header is missing!")
        hash_object = hmac.new(secret_token.encode('utf-8'), msg=payload_body, digestmod=hashlib.sha256)
        expected_signature = "sha256=" + hash_object.hexdigest()
        if not hmac.compare_digest(expected_signature, signature_header):
            raise HTTPException(status_code=403, detail="Request signatures didn't match!")

    def is_push_event(self):
        """ Verifies if request has is push github event """
        return "push" == self.request.headers.get("X-GitHub-Event","")