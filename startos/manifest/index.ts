import { setupManifest } from '@start9labs/start-sdk'
import { long, short } from './i18n'

export const manifest = setupManifest({
  id: 'snowflake', // Changed from 'hello-world'
  title: 'Snowflake', // Changed from 'Hello World'
  license: 'BSD-3-Clause',
  packageRepo: 'https://github.com/alru78/snowflake-startos-sideloader',
  upstreamRepo:
    'https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake',
  marketingUrl: 'https://start9.com/',
  donationUrl: 'https://donate.start9.com/',
  description: { short, long },
  volumes: ['main'],
  images: {
    'snowflake': {
      source: { dockerTag: 'snowflake:local' },
      arch: ['x86_64'], // Remove 'aarch64' since you are on Intel and building locally
    },
  },
  alerts: {
    install: null,
    update: null,
    uninstall: null,
    restore: null,
    start: null,
    stop: null,
  },
  dependencies: {},
})
