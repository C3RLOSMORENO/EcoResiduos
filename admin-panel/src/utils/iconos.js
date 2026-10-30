// Íconos de Material Symbols que usa el panel. La hoja de Google Fonts se
// pide solo con estos (parámetro icon_names): la fuente completa pesa unos
// 320 KB y con esta lista pesa menos de 10 KB.
// Si usas un ícono nuevo, agrégalo aquí en orden alfabético; la prueba
// pruebas/rendimiento.test.js avisa si falta alguno.
const ICONOS = [
    'accessibility_new', 'account_balance', 'add', 'arrow_downward',
    'arrow_upward', 'assignment_return', 'block', 'broken_image', 'campaign',
    'cancel', 'category', 'check_circle', 'chevron_left', 'chevron_right',
    'close', 'cloud_off', 'contrast', 'dark_mode', 'delete', 'description',
    'domain', 'domain_add', 'done_all', 'download', 'edit', 'error',
    'fact_check', 'filter_list', 'fit_screen', 'font_download',
    'format_line_spacing', 'gpp_maybe', 'group_off', 'groups', 'handshake',
    'help', 'home', 'hourglass_top', 'how_to_reg', 'image_not_supported',
    'inbox', 'info', 'light_mode', 'link', 'local_shipping', 'lock',
    'lock_reset', 'login', 'logout', 'mail', 'manage_search', 'mark_email_read',
    'menu', 'monitoring', 'motion_photos_off', 'open_in_new', 'pause_circle',
    'person_off', 'person_search', 'picture_as_pdf', 'radio_button_unchecked',
    'record_voice_over', 'recycling', 'remove', 'report', 'restart_alt', 'save',
    'schedule_send', 'search_off', 'send', 'smart_toy', 'smartphone',
    'stop_circle', 'task_alt', 'text_fields', 'travel_explore', 'unfold_more',
    'upload_file', 'verified', 'vertical_align_center', 'visibility',
    'visibility_off', 'warning', 'zoom_in', 'zoom_out'
];

// display=block: mientras llega la fuente no se ve el nombre del ícono en
// texto («chevron_right»), que es lo que mostraría swap.
const URL_ICONOS = 'https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0'
    + `&icon_names=${ICONOS.join(',')}&display=block`;

module.exports = { ICONOS, URL_ICONOS };
