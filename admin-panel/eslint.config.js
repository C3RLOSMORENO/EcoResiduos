// Configuración mínima de ESLint: las reglas recomendadas, que detectan
// errores (variables sin usar o sin declarar, código inalcanzable…) sin
// imponer un estilo. Se corre con «npm run lint».
const js = require('@eslint/js');
const globals = require('globals');

module.exports = [
    {
        ignores: ['node_modules/', 'src/public/css/', 'src/public/vendor/']
    },
    js.configs.recommended,
    {
        files: ['**/*.js'],
        languageOptions: {
            ecmaVersion: 2022,
            sourceType: 'commonjs',
            globals: globals.node
        },
        rules: {
            // Un catch o un parámetro que no se usan son a propósito cuando
            // empiezan con guion bajo.
            'no-unused-vars': ['error', { argsIgnorePattern: '^_', caughtErrors: 'none' }]
        }
    },
    {
        // Lo que corre en el navegador.
        files: ['src/public/js/**/*.js'],
        languageOptions: {
            sourceType: 'script',
            globals: { ...globals.browser, Chart: 'readonly' }
        }
    }
];
