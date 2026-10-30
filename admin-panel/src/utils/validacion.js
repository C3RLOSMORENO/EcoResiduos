// Validación de los datos que llegan de los formularios del panel. Cada
// función devuelve el valor normalizado tal como se guarda, o lanza un Error
// con el mensaje para el formulario. Las mismas reglas de teléfono y NIT están
// en la app (app/lib/utils/validacion.dart).

// Los 6 municipios del proyecto están en Santander: un fijo antiguo de 7
// dígitos se completa con su indicativo.
const INDICATIVO_SANTANDER = '607';

// Pesos del dígito de verificación del NIT (algoritmo módulo 11 de la DIAN),
// aplicados de derecha a izquierda.
const PESOS_NIT = [3, 7, 13, 17, 19, 23, 29, 37, 41, 43, 47, 53, 59, 67, 71];

const MENSAJE_TELEFONO = 'Escribe un celular (300 123 4567), un fijo de 10 dígitos (607 634 5678), '
    + 'un fijo de 7 dígitos (634 5678) o una línea 01 8000. Puedes agregar la extensión: «ext. 123».';

/**
 * Teléfono colombiano según el plan de numeración de la CRC (Resolución 5826
 * de 2019): desde septiembre de 2021 los fijos también tienen 10 dígitos,
 * empezando por 60 y el indicativo del departamento.
 *
 * Acepta celulares (3XX XXX XXXX), fijos de 10 dígitos (60X XXX XXXX), fijos
 * antiguos de 7 dígitos (se guardan con el indicativo 607 de Santander) y
 * líneas gratuitas 01 8000 XXX XXX; con +57, espacios, puntos, guiones o
 * paréntesis, y una extensión opcional.
 *
 * @param {*} valor
 * @returns {string} Solo dígitos, más « ext. N» si traía extensión.
 * @throws {Error} Si no es un número válido.
 */
function normalizarTelefono(valor) {
    const texto = String(valor || '').trim();
    const partes = texto.match(/^(.*?)(?:\s*(?:ext\.?|extensi[oó]n|x)\s*(\d{1,6}))?$/i);
    let numero = partes[1].replace(/[\s().-]/g, '');
    const extension = partes[2];

    if (numero.startsWith('+57')) numero = numero.slice(3);
    else if (/^57\d{10}$/.test(numero)) numero = numero.slice(2);

    if (/^\d{7}$/.test(numero)) numero = INDICATIVO_SANTANDER + numero;
    const valido = /^3\d{9}$/.test(numero) || /^60\d{8}$/.test(numero) || /^018000\d{6}$/.test(numero);
    if (!valido) throw new Error(MENSAJE_TELEFONO);
    return extension ? `${numero} ext. ${extension}` : numero;
}

/**
 * @param {string} base Dígitos del NIT sin el de verificación.
 * @returns {number} El dígito de verificación según la DIAN.
 */
function digitoVerificacion(base) {
    const suma = [...base].reverse().reduce((total, digito, i) => total + Number(digito) * PESOS_NIT[i], 0);
    const resto = suma % 11;
    return resto > 1 ? 11 - resto : resto;
}

/**
 * NIT de 8 a 15 dígitos. Si trae el dígito de verificación después de un
 * guion (900396512-3), se comprueba.
 *
 * @param {*} valor
 * @returns {string} El NIT sin puntos, espacios ni dígito de verificación.
 * @throws {Error} Si no tiene el formato o el dígito de verificación no coincide.
 */
function normalizarNit(valor) {
    const [base, dv] = String(valor || '').replace(/[\s.]/g, '').split('-');
    if (!/^\d{8,15}$/.test(base || '')) {
        throw new Error('El NIT es obligatorio y debe tener entre 8 y 15 dígitos (puntos y guion opcionales).');
    }
    if (dv !== undefined && dv !== '') {
        if (!/^\d$/.test(dv) || Number(dv) !== digitoVerificacion(base)) {
            throw new Error(`El dígito de verificación no corresponde al NIT ${base}. Revísalo en el RUT o escribe el NIT sin él.`);
        }
    }
    return base;
}

/**
 * @param {*} valor
 * @returns {string} El correo en minúsculas.
 * @throws {Error} Si no tiene formato de correo o pasa de 254 caracteres (RFC 5321).
 */
function normalizarCorreo(valor) {
    const correo = String(valor || '').trim().toLowerCase();
    if (correo.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)) {
        throw new Error('El correo no tiene un formato válido (ejemplo: contacto@empresa.com).');
    }
    return correo;
}

/**
 * @param {*} valor
 * @returns {string} La dirección web, con https:// si no traía protocolo.
 * @throws {Error} Si no es una dirección http o https.
 */
function normalizarSitioWeb(valor) {
    let texto = String(valor || '').trim();
    if (texto && !/^[a-z][a-z0-9+.-]*:/i.test(texto)) texto = `https://${texto}`;
    try {
        const url = new URL(texto);
        if (!['http:', 'https:'].includes(url.protocol) || !url.hostname.includes('.') || texto.length > 255) throw new Error();
        return texto;
    } catch {
        throw new Error('El sitio web debe ser una dirección como https://www.cdmb.gov.co.');
    }
}

/**
 * Texto obligatorio con largo mínimo y máximo.
 *
 * @param {*} valor
 * @param {string} campo Nombre del campo para el mensaje, en minúscula.
 * @param {{min?: number, max: number}} limites
 * @returns {string} El texto sin espacios sobrantes.
 * @throws {Error} Si queda fuera de los límites.
 */
function textoObligatorio(valor, campo, { min = 1, max }) {
    const texto = String(valor || '').trim().replace(/\s+/g, ' ');
    if (texto.length < min) {
        throw new Error(min > 1 ? `${campo[0].toUpperCase()}${campo.slice(1)} debe tener al menos ${min} caracteres.` : `Falta ${campo}.`);
    }
    if (texto.length > max) {
        throw new Error(`${campo[0].toUpperCase()}${campo.slice(1)} no puede pasar de ${max} caracteres.`);
    }
    return texto;
}

module.exports = {
    normalizarTelefono,
    normalizarNit,
    normalizarCorreo,
    normalizarSitioWeb,
    textoObligatorio,
    digitoVerificacion,
    INDICATIVO_SANTANDER
};
