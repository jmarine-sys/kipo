// ADR-017: SPA pura. Sin renderizado en servidor, porque no hay servidor propio
// y todos los datos estan detras de autenticacion por usuario: no hay nada
// prerenderizable que valga la pena.
export const ssr = false;
export const prerender = false;
export const trailingSlash = 'never';
