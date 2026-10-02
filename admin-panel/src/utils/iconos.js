// Íconos de Material Symbols que usa el panel. La hoja de Google Fonts se
// pide solo con estos (parámetro icon_names): la fuente completa pesa unos
// 320 KB y con esta lista pesa menos de 10 KB.
// Si usas un ícono nuevo, agrégalo aquí en orden alfabético; la prueba
// pruebas/rendimiento.test.js avisa si falta alguno.
const ICONOS = [
    'account_balance', 'add', 'arrow_downward', 'arrow_upward',
    'assignment_return', 'block', 'broken_image', 'campaign', 'cancel',
    'category', 'check_circle', 'chevron_left', 'chevron_right', 'close',
    'cloud_off', 'dark_mode', 'delete', 'description', 'domain', 'domain_add',
    'done_all', 'download', 'edit', 'error', 'fact_check', 'filter_list',
    'fit_screen', 'gpp_maybe', 'group_off', 'groups', 'handshake', 'home',
    'hourglass_top', 'how_to_reg', 'image_not_supported', 'inbox', 'info',
    'light_mode', 'local_shipping', 'lock_reset', 'login', 'logout',
    'mark_email_read', 'menu', 'monitoring', 'open_in_new', 'pause_circle',
    'person_off', 'person_search', 'picture_as_pdf', 'print',
    'radio_button_unchecked', 'recycling', 'report', 'save', 'schedule_send',
    'search_off', 'send', 'smartphone', 'task_alt', 'travel_explore',
    'unfold_more', 'upload_file', 'verified', 'visibility', 'visibility_off',
    'warning', 'zoom_in', 'zoom_out'
];

// display=block: mientras llega la fuente no se ve el nombre del ícono en
// texto («chevron_right»), que es lo que mostraría swap.
const URL_ICONOS = 'https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0'
    + `&icon_names=${ICONOS.join(',')}&display=block`;

module.exports = { ICONOS, URL_ICONOS };
