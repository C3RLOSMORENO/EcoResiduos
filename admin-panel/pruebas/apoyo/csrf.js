// Token CSRF fijo para las pruebas: el navegador manda la cookie csrf y el
// mismo valor en el campo _csrf o en la cabecera X-CSRF-Token.
const TOKEN_CSRF = 'token-csrf-de-prueba-0123456789abcdef';
const COOKIE_CSRF = `csrf=${TOKEN_CSRF}`;

module.exports = { TOKEN_CSRF, COOKIE_CSRF };
