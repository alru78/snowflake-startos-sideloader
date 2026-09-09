import { IMPOSSIBLE, VersionInfo } from '@start9labs/start-sdk'

export const current = VersionInfo.of({
  version: '2.0.0:12',
  releaseNotes: {
    en_US: 'Adds dashboard branding and fixes "Proxy last started" showing the first restart ever instead of the most recent one.',
    es_ES: 'Añade marca al panel y corrige que "Proxy iniciado por última vez" mostrara el primer reinicio en lugar del más reciente.',
    de_DE: 'Fügt Dashboard-Branding hinzu und behebt, dass "Proxy zuletzt gestartet" den allerersten Neustart statt des letzten anzeigte.',
    pl_PL: 'Dodaje branding panelu i naprawia błąd pokazujący pierwsze uruchomienie zamiast najnowszego w polu "Ostatnie uruchomienie proxy".',
    fr_FR: 'Ajoute la marque du tableau de bord et corrige "Dernier démarrage du proxy" qui affichait le tout premier démarrage au lieu du plus récent.',
  },
  migrations: {
    up: async ({ effects }) => {},
    down: IMPOSSIBLE,
  },
})
