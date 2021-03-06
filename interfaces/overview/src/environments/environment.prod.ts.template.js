// Output should be a valid TS-file:
module.exports = `//
// THIS FILE IS GENERATED BY '/_set-env-variables.js'

export const environment = {
  production: ${process.env.NG_PRODUCTION || true},

  // API:
  api_url: '${process.env.NG_API_URL}',

  // Feature-flags:
  useMockData: ${process.env.NG_USE_MOCK_DATA === 'true' || false},
  useServiceWorker: ${process.env.NG_USE_SERVICE_WORKER === 'true' || false},

  // Configuration/initial data:
  defaultCountryCode: '${process.env.NG_DEFAULT_COUNTRY_CODE}',

  // Geoserver
  geoserver_url: '${process.env.NG_GEOSERVER_URL}',
};
`;
