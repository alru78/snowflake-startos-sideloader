import { i18n } from './i18n'
import { sdk } from './sdk'

export const main = sdk.setupMain(async ({ effects }) => {
  console.info(i18n('Starting Snowflake Proxy!'))

  return sdk.Daemons.of(effects).addDaemon('primary', {
    subcontainer: await sdk.SubContainer.of(
      effects,
      { imageId: 'snowflake' },
      sdk.Mounts.of().mountVolume({
        volumeId: 'main',
        subpath: null,
        mountpoint: '/data',
        readonly: false,
      }),
      'snowflake-sub',
    ),
    // dashboard.sh runs the real snowflake-proxy binary itself (logging to
    // both stdout and a file on the data volume), plus a small busybox httpd
    // on port 80 serving a stats page built from that log -- this is what
    // "Open UI" now points to. See scripts/dashboard.sh.
    exec: { command: ['/usr/local/bin/dashboard.sh'] },

    // READY BLOCK
    ready: {
      display: i18n('Snowflake proxy is running'),
      fn: async () => {
        // Wait briefly to ensure container has started
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Return correct structure with string status
        return {
          result: 'success', // Must be "success", "failure", "starting", etc.
          message: i18n('Snowflake proxy is running')
        };
      }
    },

    requires: [],
  })
})
