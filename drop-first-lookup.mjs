// Drops the first request to each SwiftPM version lookup as a reset connection does, and answers xcframework downloads with 404.
const lookupPatterns = [
  /^https:\/\/registry\.npmjs\.org\/[^/]+(\/[^/]+)?\/(nightly|latest-v1)$/,
  /\/maven-metadata\.xml$/,
];
const isArtifactDownload = url => /\.tar\.gz$/.test(url);
const attemptsByLookup = new Map();
const passThroughFetch = globalThis.fetch;

function urlOf(input) {
  return typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
}

async function fetchFromNetwork(url, input, init) {
  try {
    return await passThroughFetch(input, init);
  } catch (error) {
    console.log(`[drop-first-lookup] request failed on the network: ${url}`);
    throw error;
  }
}

globalThis.fetch = async (input, init) => {
  const url = urlOf(input);
  if (lookupPatterns.some(pattern => pattern.test(url))) {
    const attempt = (attemptsByLookup.get(url) ?? 0) + 1;
    attemptsByLookup.set(url, attempt);
    console.log(`[drop-first-lookup] attempt ${attempt}: ${url}`);
    if (attempt === 1) {
      throw new TypeError('fetch failed', {
        cause: Object.assign(new Error('read ECONNRESET'), {code: 'ECONNRESET'}),
      });
    }
    return fetchFromNetwork(url, input, init);
  }
  if (isArtifactDownload(url) && (init?.method ?? 'GET') === 'GET') {
    console.log(`[drop-first-lookup] download answered 404: ${url}`);
    return new Response(null, {status: 404, statusText: 'Not Found'});
  }
  return fetchFromNetwork(url, input, init);
};
