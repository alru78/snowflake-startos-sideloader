import { IMPOSSIBLE, VersionInfo } from '@start9labs/start-sdk'

export const current = VersionInfo.of({
  version: '2.0.0:15',
  releaseNotes: {
    en_US: 'Fixed the bandwidth chart heading to match the number of hours actually shown once more than a day of history has accumulated.',
    es_ES: 'Se corrigió el encabezado del gráfico de ancho de banda para que coincida con el número de horas realmente mostradas una vez acumulado más de un día de historial.',
    de_DE: 'Die Überschrift des Bandbreitendiagramms wurde korrigiert, sodass sie mit der tatsächlich angezeigten Anzahl von Stunden übereinstimmt, sobald mehr als ein Tag an Verlauf vorliegt.',
    pl_PL: 'Naprawiono nagłówek wykresu przepustowości, aby zgadzał się z rzeczywistą liczbą wyświetlanych godzin po zgromadzeniu ponad jednego dnia historii.',
    fr_FR: 'Correction de l\'en-tête du graphique de bande passante pour qu\'il corresponde au nombre d\'heures réellement affichées une fois plus d\'une journée d\'historique accumulée.',
  },
  migrations: {
    up: async ({ effects }) => {},
    down: IMPOSSIBLE,
  },
})
