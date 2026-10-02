// Pruebas de extremo a extremo: npm run test:e2e
// La primera vez descarga el navegador con: npx playwright install chromium
// Para usar el Chrome ya instalado en el equipo: E2E_CANAL=chrome npm run test:e2e
const { defineConfig, devices } = require('@playwright/test');

const PUERTO = 3998;

module.exports = defineConfig({
    testDir: './pruebas/e2e',
    testMatch: '*.spec.js',
    fullyParallel: false,
    workers: 1,
    retries: process.env.CI ? 1 : 0,
    reporter: 'list',
    use: {
        baseURL: `http://localhost:${PUERTO}`,
        channel: process.env.E2E_CANAL || undefined,
        locale: 'es-CO',
        trace: 'retain-on-failure'
    },
    projects: [
        { name: 'escritorio', use: { ...devices['Desktop Chrome'] } },
        { name: 'celular', use: { ...devices['Pixel 7'] } }
    ],
    webServer: {
        command: 'node pruebas/e2e/servidor.js',
        url: `http://localhost:${PUERTO}/login`,
        env: { PUERTO_E2E: String(PUERTO) },
        reuseExistingServer: !process.env.CI
    }
});
