import { IMPOSSIBLE, VersionInfo } from '@start9labs/start-sdk'

export const current = VersionInfo.of({
  version: '2.0.0:14',
  releaseNotes: {
    en_US: 'Bandwidth is now shown in MB for smaller amounts instead of always GB, the bandwidth chart shows its peak value, and the today/7-day/30-day tiles show an up or down trend versus the previous equivalent period.',
    es_ES: 'El ancho de banda ahora se muestra en MB para cantidades pequeñas en lugar de siempre en GB, el gráfico de ancho de banda muestra su valor máximo, y los paneles de hoy/7 días/30 días muestran una tendencia al alza o a la baja respecto al período anterior equivalente.',
    de_DE: 'Die Bandbreite wird jetzt bei kleineren Mengen in MB statt immer in GB angezeigt, das Bandbreitendiagramm zeigt seinen Spitzenwert, und die Kacheln für heute/7 Tage/30 Tage zeigen einen Aufwärts- oder Abwärtstrend im Vergleich zum vorherigen entsprechenden Zeitraum.',
    pl_PL: 'Przepustowość jest teraz wyświetlana w MB dla mniejszych wartości zamiast zawsze w GB, wykres przepustowości pokazuje wartość szczytową, a kafelki dzisiaj/7 dni/30 dni pokazują trend wzrostowy lub spadkowy względem poprzedniego odpowiadającego okresu.',
    fr_FR: 'La bande passante s\'affiche désormais en MB pour les petites quantités au lieu de toujours en GB, le graphique de bande passante affiche sa valeur maximale, et les tuiles aujourd\'hui/7 jours/30 jours affichent une tendance à la hausse ou à la baisse par rapport à la période équivalente précédente.',
  },
  migrations: {
    up: async ({ effects }) => {},
    down: IMPOSSIBLE,
  },
})
