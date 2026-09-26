# Direct Realtime Database licensing

This setup does not use Cloud Functions or Firebase Authentication. Deploy `database.rules.json` to the existing Realtime Database (`firebase deploy --only database` from this directory).

Open `license-key.html` locally, enter a key and number of days, and press **Tạo**. The page writes the record directly to `licenses/<sha256>`; the app reads that record without signing in.

The Firebase web API key is a public project identifier. The rules allow anyone to create a new valid license record but prevent overwriting an existing record; this is convenient but not an anti-crack boundary and can be abused for spam. Do not add a database secret or service-account private key to the HTML page, app bundle, or repository.
