{{flutter_js}}
{{flutter_build_config}}

// Sin service worker a propósito: guardaba una copia propia de la app y los
// clientes seguían viendo la versión anterior tras cada deploy. El navegador
// ahora revalida con Hosting (ETag) en cada visita y recibe lo nuevo solo.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "/canvaskit/",
  },
});
