// Avisos que llegan a una página por un código en la URL (?aviso=…). Los arma
// el navegador o un middleware antes de que exista una sesión, así que no van
// firmados: la URL solo trae el código y el texto vive aquí.
//
// El tipo decide el color y cómo se anuncia. «info» es para un estado que no
// es culpa del administrador (la sesión venció); «error», para algo que salió
// mal y hay que corregir; «exito», para confirmar lo que acaba de hacer.
const AVISOS_FIJOS = {
    'inicia-sesion': {
        tipo: 'info',
        mensaje: 'Inicia sesión para continuar.'
    },
    'sesion-vencida': {
        tipo: 'info',
        mensaje: 'Tu sesión venció por inactividad. Inicia sesión y te llevamos a la página donde ibas.'
    },
    'sesion-terminada': {
        tipo: 'info',
        mensaje: 'Tu sesión terminó o esa cuenta no es de administrador. Inicia sesión con una cuenta de administrador.'
    },
    'clave-actualizada': {
        tipo: 'exito',
        mensaje: 'Actualizamos tu contraseña. Ya puedes iniciar sesión con la nueva.'
    }
};

module.exports = { AVISOS_FIJOS };
