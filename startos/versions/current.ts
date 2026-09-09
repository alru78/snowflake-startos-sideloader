import { IMPOSSIBLE, VersionInfo } from '@start9labs/start-sdk'

export const current = VersionInfo.of({
  version: '2.0.0:13',
  releaseNotes: {
    en_US: 'Adds a snowflake icon next to the dashboard title and a matching favicon in the browser tab.',
    es_ES: 'Añade un icono de copo de nieve junto al título del panel y un favicon a juego en la pestaña del navegador.',
    de_DE: 'Fügt ein Schneeflocken-Symbol neben dem Dashboard-Titel und ein passendes Favicon im Browser-Tab hinzu.',
    pl_PL: 'Dodaje ikonę płatka śniegu obok tytułu panelu i pasujący favicon na karcie przeglądarki.',
    fr_FR: 'Ajoute une icône de flocon de neige à côté du titre du tableau de bord et un favicon assorti dans l\'onglet du navigateur.',
  },
  migrations: {
    up: async ({ effects }) => {},
    down: IMPOSSIBLE,
  },
})
