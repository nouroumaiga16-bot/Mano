{{flutter_js}}
{{flutter_build_config}}

// Pas de service worker Flutter : Mano utilise le sien (offline_sw.js).
_flutter.loader.load();

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('offline_sw.js');
}
// Demande au navigateur de ne pas effacer les données de la boutique.
if (navigator.storage && navigator.storage.persist) {
  navigator.storage.persist();
}
