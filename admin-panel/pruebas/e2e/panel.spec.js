// Recorridos completos en un navegador real: iniciar sesión, aprobar un
// gestor y ampliar la foto de una solicitud. Corre en escritorio y en celular.
const { test, expect } = require('@playwright/test');

const ADMIN = { correo: 'admin@ecoresiduos.test', clave: 'clave-correcta' };

test.beforeEach(async ({ page, request }) => {
    await request.post('/__e2e/reiniciar');
    // Cualquier violación de la CSP o error de JavaScript hace fallar la prueba.
    const errores = [];
    page.on('pageerror', (error) => errores.push(error.message));
    page.on('console', (mensaje) => { if (mensaje.type() === 'error') errores.push(mensaje.text()); });
    test.info().errores = errores;
});

test.afterEach(() => {
    expect(test.info().errores, 'errores en la consola del navegador').toEqual([]);
});

async function iniciarSesion(page, destino) {
    await page.goto(destino);
    await expect(page).toHaveURL(/\/login\?/);
    await page.getByLabel('Correo').fill(ADMIN.correo);
    await page.getByLabel('Contraseña', { exact: false }).first().fill(ADMIN.clave);
    await page.getByRole('button', { name: 'Ingresar' }).click();
    await expect(page).toHaveURL(new RegExp(`${destino}(\\?|$)`));
}

test('aprobar un gestor: se confirma en el diálogo y la ficha queda aprobada', async ({ page }) => {
    await iniciarSesion(page, '/gestores/1');
    await expect(page.getByRole('heading', { level: 1 })).toContainText('RECICLAJES DEL ORIENTE');

    await page.getByRole('button', { name: 'Aprobar', exact: true }).click();
    const dialogo = page.getByRole('dialog', { name: 'Aprobar gestor' });
    await expect(dialogo).toBeVisible();
    await expect(dialogo).toContainText('queda verificado');

    // Cancelar no cambia nada.
    await dialogo.getByRole('button', { name: 'Cancelar' }).click();
    await expect(dialogo).toBeHidden();
    await expect(page.getByRole('button', { name: 'Aprobar', exact: true })).toBeFocused();

    await page.getByRole('button', { name: 'Aprobar', exact: true }).click();
    await dialogo.getByRole('button', { name: 'Aprobar' }).click();

    await expect(page).toHaveURL(/\/gestores\/1\?msg=/);
    await expect(page.getByRole('status')).toContainText('Estado del gestor: Aprobado.');
    await expect(page.getByRole('button', { name: 'Aprobar', exact: true })).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Suspender' })).toBeVisible();
});

test('ampliar la foto de una solicitud: se abre el visor, se acerca y al cerrar vuelve el foco', async ({ page }) => {
    await iniciarSesion(page, '/solicitudes/7');

    const enlace = page.getByRole('link', { name: /^Ampliar la foto del residuo/ });
    await enlace.click();
    const visor = page.getByRole('dialog', { name: /Foto del residuo/ });
    await expect(visor).toBeVisible();

    const foto = visor.locator('[data-visor-foto]');
    await expect(foto).toBeVisible();
    expect(await foto.evaluate((img) => img.naturalWidth)).toBe(1600);

    const nivel = visor.locator('#visorNivel');
    const antes = await nivel.textContent();
    await visor.getByRole('button', { name: 'Acercar' }).click();
    await expect(nivel).not.toHaveText(antes);

    await visor.getByRole('button', { name: 'Ver la foto completa' }).click();
    await expect(nivel).toHaveText(antes);

    await page.keyboard.press('Escape');
    await expect(visor).toBeHidden();
    await expect(enlace).toBeFocused();
});
