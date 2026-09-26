# Direct Realtime Database licensing

This setup does not use Cloud Functions or Firebase Authentication. Deploy `database.rules.json` to the existing Realtime Database (`firebase deploy --only database` from this directory).

Open `license-key.html` locally on the administrator computer, choose an expiry, and generate a key. Copy the JSON into the Realtime Database at the displayed `licenses/<sha256>` path. The app reads that record directly without signing in. Client writes stay disabled; create, edit, enable, or revoke license records from the Firebase console.

The Firebase web API key is a public project identifier. The rules intentionally expose only license reads and deny client writes. This is simpler than Authentication, but anyone who knows a license hash can read that record; it is not an anti-crack boundary. Do not add a database secret or service-account private key to the HTML page, app bundle, or repository.
