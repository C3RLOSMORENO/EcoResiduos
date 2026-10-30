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

// Espera lo mismo que recorrido.js antes de arrancar solo: fuentes y dos cuadros.
async function paginaQuieta(page) {
    // globalThis: este archivo corre en Node y la función, en el navegador.
    await page.evaluate(() => {
        const { document, requestAnimationFrame } = globalThis;
        return document.fonts.ready.then(() => new Promise((listo) => requestAnimationFrame(() => requestAnimationFrame(listo))));
    });
}

test('recorrido del inicio: aparece la primera vez, se recorre completo y no vuelve a salir', async ({ page }) => {
    await iniciarSesion(page, '/dashboard');

    const primero = page.getByRole('dialog', { name: 'Bandeja de pendientes' });
    await expect(primero).toBeVisible();
    await expect(primero).toContainText('1 de 4');
    await expect(primero.getByRole('button', { name: 'Saltar' })).toBeVisible();
    await expect(primero.getByRole('button', { name: 'Cerrar recorrido' })).toBeVisible();
    // El foco entra a la tarjeta, en «Siguiente»: con Enter se avanza.
    await expect(primero.getByRole('button', { name: 'Siguiente' })).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page.getByRole('dialog', { name: 'Auditoría de gestores' })).toBeVisible();
    await page.getByRole('button', { name: 'Anterior' }).click();
    await expect(primero).toBeVisible();

    for (const titulo of ['Auditoría de gestores', 'Métricas y trazabilidad', 'Ayuda bajo demanda']) {
        await page.getByRole('button', { name: 'Siguiente' }).click();
        const paso = page.getByRole('dialog', { name: titulo });
        await expect(paso).toBeVisible();
        // La tarjeta cabe entera en la pantalla, también en el celular.
        const caja = await paso.boundingBox();
        const pantalla = page.viewportSize();
        expect(caja.x).toBeGreaterThanOrEqual(0);
        expect(caja.y).toBeGreaterThanOrEqual(0);
        expect(caja.x + caja.width).toBeLessThanOrEqual(pantalla.width);
        expect(caja.y + caja.height).toBeLessThanOrEqual(pantalla.height);
    }
    await page.getByRole('button', { name: 'Entendido' }).click();
    await expect(page.getByRole('dialog')).toHaveCount(0);

    // Se guardó en la cuenta, no solo en este navegador.
    await page.evaluate(() => localStorage.clear());
    await page.reload();
    await expect(page.getByRole('button', { name: 'Ver recorrido de esta pantalla' })).toBeVisible();
    await paginaQuieta(page);
    await expect(page.getByRole('dialog')).toHaveCount(0);
});

test('recorrido del inicio: se salta en el primer paso y se repite con el botón de ayuda', async ({ page }) => {
    await iniciarSesion(page, '/dashboard');
    const primero = page.getByRole('dialog', { name: 'Bandeja de pendientes' });
    await primero.getByRole('button', { name: 'Saltar' }).click();
    await expect(primero).toBeHidden();

    await page.reload();
    await paginaQuieta(page);
    await expect(page.getByRole('dialog')).toHaveCount(0);

    const ayuda = page.getByRole('button', { name: 'Ver recorrido de esta pantalla' });
    await ayuda.click();
    await expect(primero).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(primero).toBeHidden();
    await expect(ayuda).toBeFocused();
});

test('logo del gestor: se ve, se quita con confirmación y el aviso queda en el área de contenido', async ({ page }) => {
    await iniciarSesion(page, '/gestores/1');
    const logo = page.locator('.vista-ficha img[data-avatar]').last();
    await expect(logo).toBeVisible();
    expect(await logo.evaluate((img) => img.naturalWidth)).toBeGreaterThan(0);

    await page.getByRole('button', { name: 'Quitar logo' }).click();
    const dialogo = page.getByRole('dialog', { name: 'Quitar logo' });
    await expect(dialogo).toContainText('verá sus iniciales');
    await dialogo.getByRole('button', { name: 'Quitar' }).click();

    const aviso = page.getByRole('status');
    await expect(aviso).toContainText('Logo quitado');
    await expect(page.getByRole('button', { name: 'Quitar logo' })).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Quitar portada' })).toBeVisible();
    await expect(page.locator('h1').locator('xpath=..').locator('..').locator('.avatar img')).toHaveCount(0);

    // En pantallas con navegación lateral el aviso no se encima a ella.
    const navegacion = await page.locator('#navPrincipal').boundingBox();
    const cajaAviso = await page.locator('.aviso').first().boundingBox();
    const ancho = page.viewportSize().width;
    if (ancho >= 600) expect(cajaAviso.x).toBeGreaterThanOrEqual(navegacion.x + navegacion.width);
    expect(cajaAviso.x + cajaAviso.width).toBeLessThanOrEqual(ancho);
    expect(cajaAviso.y + cajaAviso.height).toBeLessThanOrEqual(page.viewportSize().height);
});

test('al cambiar de pantalla se ve el esqueleto de esa pantalla y el menú ya marca el destino', async ({ page }) => {
    await iniciarSesion(page, '/solicitudes');
    // Chromium sin interfaz congela la página anterior mientras navega, así
    // que no se puede mirar el esqueleto durante una carga real. main.js
    // reacciona al clic (escucha en document) y window, que escucha
    // después, cancela la navegación: queda a la vista lo que vería el usuario.
    const enlace = page.locator('.nav-item[href="/gestores"]');
    await enlace.evaluate((a) => {
        globalThis.addEventListener('click', (e) => e.preventDefault(), { once: true });
        a.click();
    });

    const esqueleto = page.locator('[data-esqueleto]');
    await expect(esqueleto).toBeVisible();
    await expect(esqueleto).toContainText('Gestores');
    await expect(esqueleto).toContainText('Estado de verificación');
    await expect(esqueleto).not.toContainText('Publicada desde', { useInnerText: true });
    await expect(page.locator('#contenido')).toHaveAttribute('aria-busy', 'true');
    await expect(page.getByRole('status').filter({ hasText: 'Cargando' })).toHaveCount(1);
    await expect(page.getByRole('heading', { level: 1, name: 'Solicitudes' })).toBeHidden();
    await expect(page.locator('.nav-item[aria-current="page"]')).toHaveAttribute('href', '/gestores');

    // Al volver con «Atrás» desde la caché del navegador se quita el esqueleto
    // y el menú vuelve a la pantalla que se ve.
    await page.evaluate(() => globalThis.dispatchEvent(new globalThis.PageTransitionEvent('pageshow', { persisted: true })));
    await expect(esqueleto).toHaveCount(0);
    await expect(page.getByRole('heading', { level: 1, name: 'Solicitudes' })).toBeVisible();
    await expect(page.locator('.nav-item[aria-current="page"]')).toHaveAttribute('href', '/solicitudes');
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

test('guardar un formulario de edición guarda el borrador sin errores de JavaScript', async ({ page }) => {
    await iniciarSesion(page, '/materiales/edit/1');
    await page.getByLabel('Nombre', { exact: false }).first().fill('Aceite de cocina usado');

    // Al enviar, main.js guarda el borrador por si el servidor responde con un
    // error; si eso falla, afterEach lo detecta en la consola del navegador.
    await Promise.all([
        page.waitForURL(/msg=/),
        page.locator('form[data-conservar] button[type="submit"]').click()
    ]);
});

test('asistente flotante: se abre, responde, sigue al cambiar de pantalla y se cierra con Escape', async ({ page }) => {
    await page.route('**/asistente/preguntar', async (ruta) => {
        const { historial } = ruta.request().postDataJSON();
        expect(ruta.request().headers()['x-csrf-token']).toBeTruthy();
        await ruta.fulfill({ json: { ok: true, respuesta: `Tienen 47 gestores aprobados (${historial.length} mensaje).`, consultas: ['Gestores'] } });
    });
    await iniciarSesion(page, '/solicitudes/7');

    const boton = page.getByRole('button', { name: 'Abrir el asistente' });
    await boton.click();
    const panel = page.getByRole('region', { name: 'Asistente' });
    await expect(panel).toBeVisible();
    await expect(page.getByLabel('Tu pregunta')).toBeFocused();

    await panel.getByRole('button', { name: '¿Cuántos gestores tenemos aprobados?' }).click();
    await expect(panel.getByRole('log')).toContainText('Tienen 47 gestores aprobados (1 mensaje).');
    await expect(panel.getByRole('log')).toContainText('Consultó: Gestores');
    if (process.env.CAPTURA_ASISTENTE) await page.screenshot({ path: `${process.env.CAPTURA_ASISTENTE}-${test.info().project.name}.png` });

    // Al pasar a otra pantalla la conversación sigue abierta y con sus mensajes.
    await page.goto('/materiales/edit/1');
    await expect(page.getByRole('region', { name: 'Asistente' })).toContainText('Tienen 47 gestores aprobados');

    await page.getByLabel('Tu pregunta').fill('¿Y en Girón?');
    await page.keyboard.press('Enter');
    await expect(page.getByRole('log')).toContainText('(3 mensaje)');

    await page.keyboard.press('Escape');
    await expect(page.getByRole('region', { name: 'Asistente' })).toBeHidden();
    await expect(page.getByRole('button', { name: 'Abrir el asistente' })).toBeFocused();
});

test('accesibilidad: se abre con el botón o con Alt+Shift+A, cambia el texto y el contraste, y se recuerda', async ({ page }) => {
    await iniciarSesion(page, '/solicitudes/7');
    const html = page.locator('html');

    await page.getByRole('button', { name: 'Accesibilidad' }).click();
    const panel = page.getByRole('region', { name: 'Preferencias de accesibilidad' });
    await expect(panel).toBeVisible();

    await panel.getByRole('button', { name: 'Aumentar el tamaño del texto' }).click();
    await expect(html).toHaveAttribute('data-texto', '115');
    await expect(panel.locator('#valorTamano')).toHaveText('115 %');

    const contraste = panel.getByRole('button', { name: 'Alto contraste' });
    await contraste.click();
    await expect(contraste).toHaveAttribute('aria-pressed', 'true');
    await expect(html).toHaveAttribute('data-contraste', '');
    if (process.env.CAPTURA_ASISTENTE) await page.screenshot({ path: `${process.env.CAPTURA_ASISTENTE}-accesibilidad-${test.info().project.name}.png` });

    // Abrir el asistente cierra este panel: solo uno a la vez. En el celular
    // el panel ocupa la pantalla y tapa el botón del asistente.
    if (page.viewportSize().width >= 600) {
        await page.getByRole('button', { name: 'Abrir el asistente' }).click();
        await expect(panel).toBeHidden();
        await page.keyboard.press('Escape');
    }

    // Al recargar se aplica antes de pintar.
    await page.reload();
    await expect(html).toHaveAttribute('data-texto', '115');
    await expect(html).toHaveAttribute('data-contraste', '');

    await page.keyboard.press('Alt+Shift+A');
    await expect(panel).toBeVisible();
    await panel.getByRole('button', { name: 'Restablecer todo' }).click();
    await expect(html).not.toHaveAttribute('data-texto', /.+/);
    await expect(html).not.toHaveAttribute('data-contraste', /.*/);
    await page.keyboard.press('Escape');
    await expect(panel).toBeHidden();
    await expect(page.getByRole('button', { name: 'Accesibilidad' })).toBeFocused();
});
