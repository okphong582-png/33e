# Direct Realtime Database licensing

This setup does not use Cloud Functions. Enable **Authentication → Sign-in method → Anonymous** in the Firebase console and deploy `database.rules.json` to the existing Realtime Database (`firebase deploy --only database` from this directory).

Open `license-key.html` locally on the administrator computer, choose an expiry, and generate a key. Copy the JSON into the Realtime Database at the displayed `licenses/<sha256>` path. The app signs in anonymously, reads that record, and claims `ownerUid` once. The Rules allow an anonymous client to claim only the empty owner field of an existing, enabled, unexpired record; creating or changing license records remains an administrator action in the Firebase console.

The Firebase web API key is a public project identifier. Database Rules and Authentication enforce access. Do not add a database secret or service-account private key to the HTML page, app bundle, or repository.
