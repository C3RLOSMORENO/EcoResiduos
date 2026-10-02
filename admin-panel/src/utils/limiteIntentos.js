// Cuenta intentos fallidos por clave (correo o IP) dentro de una ventana de
// tiempo. Vive en memoria: alcanza para un solo servidor; si el panel corre
// en varias instancias, cada una lleva su propia cuenta.
function crearLimite({ maximo, ventanaMs, ahora = () => Date.now() }) {
    const intentos = new Map();

    function vigentes(clave) {
        const limite = ahora() - ventanaMs;
        const lista = (intentos.get(clave) || []).filter((t) => t > limite);
        if (lista.length) intentos.set(clave, lista); else intentos.delete(clave);
        return lista;
    }

    return {
        // Milisegundos que faltan para poder intentar de nuevo (0 si puede).
        espera(clave) {
            const lista = vigentes(clave);
            return lista.length >= maximo ? lista[0] + ventanaMs - ahora() : 0;
        },
        fallo(clave) {
            const lista = vigentes(clave);
            lista.push(ahora());
            intentos.set(clave, lista);
            // Sin esto, un ataque con miles de correos distintos llenaría la memoria.
            if (intentos.size > 10000) {
                for (const k of intentos.keys()) { vigentes(k); if (intentos.size <= 5000) break; }
            }
        },
        limpiar(clave) {
            intentos.delete(clave);
        }
    };
}

module.exports = { crearLimite };
