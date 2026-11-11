# SwiftPM artifact setup gives up on the first dropped connection to a version lookup

This is the reproducer template with `react-native` and every `@react-native/*` package at
`0.90.0-nightly-20261111-1273ca128` and `@react-native-community/cli` at `21.0.0-alpha.1`, as the current community
template sets the nightly up, plus two files:

- `drop-first-lookup.mjs`, loaded with `node --import`, fails the first request to each version lookup the setup makes
  (`registry.npmjs.org/<package>/nightly`, `registry.npmjs.org/hermes-compiler/latest-v1` and each
  `maven-metadata.xml`) with the `TypeError: fetch failed` a reset connection gives, passes every other request
  through, and answers each xcframework download with 404 so the run ends before downloading.
- `repro.sh` installs the app, runs `node_modules/react-native/scripts/spm/download-spm-artifacts.js --version nightly`
  under that preload, and exits 1 while the setup gives up with `fetch failed`, 0 once it recovers from each dropped
  connection, and 2 when a step fails another way.

```sh
bash repro.sh
```

Expected: the setup sends each lookup again, as `download()` does for the downloads since
[#59214](https://github.com/react/react-native/pull/59214). Seen, on Node 26.12.1:

```text
[download-spm-artifacts]   Resolving nightly version from npm: react-native
[drop-first-lookup] attempt 1: https://registry.npmjs.org/react-native/nightly
fetch failed
download-spm-artifacts.js exited 1
RESULT: the setup exited 1 with "fetch failed" after one dropped connection to: https://registry.npmjs.org/react-native/nightly
```
