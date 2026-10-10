/** @type {import('tailwindcss').Config} */

// Roles de color de Material 3. Los valores viven en src/public/css/input.css
// (copiados de app/lib/theme/eco_colors.dart) y cambian solos en modo oscuro.
const rolesM3 = [
  'primary', 'on-primary', 'primary-container', 'on-primary-container',
  'secondary', 'on-secondary', 'secondary-container', 'on-secondary-container',
  'tertiary', 'on-tertiary', 'tertiary-container', 'on-tertiary-container',
  'error', 'on-error', 'error-container', 'on-error-container',
  'surface', 'on-surface', 'on-surface-variant', 'surface-dim', 'surface-bright',
  'surface-container-lowest', 'surface-container-low', 'surface-container',
  'surface-container-high', 'surface-container-highest',
  'outline', 'outline-variant', 'inverse-surface', 'inverse-on-surface', 'inverse-primary'
];

const colores = Object.fromEntries(rolesM3.map((rol) => [rol, `var(--md-sys-color-${rol})`]));

// Escala tipográfica de app/lib/theme/eco_theme.dart (ecoTextTheme).
const escala = {
  'display-l': ['56px', { lineHeight: '60px', letterSpacing: '-0.5px', fontWeight: '700' }],
  'display-m': ['44px', { lineHeight: '48px', letterSpacing: '-0.25px', fontWeight: '700' }],
  'display-s': ['36px', { lineHeight: '40px', fontWeight: '700' }],
  'headline-l': ['32px', { lineHeight: '36px', fontWeight: '700' }],
  'headline-m': ['28px', { lineHeight: '32px', fontWeight: '700' }],
  'headline-s': ['24px', { lineHeight: '28px', fontWeight: '600' }],
  'title-l': ['20px', { lineHeight: '26px', fontWeight: '600' }],
  'title-m': ['16px', { lineHeight: '22px', letterSpacing: '0.1px', fontWeight: '600' }],
  'title-s': ['14px', { lineHeight: '20px', letterSpacing: '0.1px', fontWeight: '600' }],
  'body-l': ['16px', { lineHeight: '24px', letterSpacing: '0.15px', fontWeight: '400' }],
  'body-m': ['14px', { lineHeight: '20px', letterSpacing: '0.2px', fontWeight: '400' }],
  'body-s': ['13px', { lineHeight: '18px', letterSpacing: '0.3px', fontWeight: '400' }],
  'label-l': ['14px', { lineHeight: '20px', letterSpacing: '0.1px', fontWeight: '600' }],
  'label-m': ['12px', { lineHeight: '16px', letterSpacing: '0.4px', fontWeight: '600' }],
  'label-s': ['11px', { lineHeight: '16px', letterSpacing: '0.5px', fontWeight: '600' }]
};

module.exports = {
  content: [
    './src/views/**/*.ejs',
    './src/public/**/*.js'
  ],
  // Los chips y las etiquetas del panel de acceso se arman con la categoría
  // o el estado real (chip-cat-<x>, etiqueta-fondo-<x>): Tailwind no los ve
  // escritos completos en las vistas.
  // La muestra de color de la leyenda (muestra-<ranura>) sale de la ranura
  // de cada serie en src/utils/graficos.js.
  // Las clases driver-* del recorrido guiado las pone Driver.js, que vive en
  // node_modules.
  safelist: [
    { pattern: /^chip-(cat|estado)-/ },
    { pattern: /^etiqueta-(fondo|texto)-/ },
    { pattern: /^muestra-/ },
    { pattern: /^driver-/ }
  ],
  theme: {
    // Tamaños de ventana de M3: compacta (< 600), media (600–839),
    // expandida (≥ 840) y grande (≥ 1200).
    screens: {
      md: '600px',
      lg: '840px',
      xl: '1200px'
    },
    colors: {
      transparent: 'transparent',
      current: 'currentColor',
      inherit: 'inherit',
      ...colores
    },
    fontFamily: {
      sans: ['"Public Sans"', 'system-ui', '-apple-system', '"Segoe UI"', 'Roboto', 'sans-serif'],
      display: ['"Barlow Condensed"', '"Arial Narrow"', 'system-ui', 'sans-serif']
    },
    // EcoRadius y la escala de esquinas de M3: extra-small 4, small 8,
    // medium 12, large 16, extra-large 28, full.
    borderRadius: {
      none: '0',
      xs: '4px',
      sm: '8px',
      DEFAULT: '12px',
      md: '12px',
      lg: '16px',
      xl: '28px',
      '2xl': '24px',
      full: '9999px'
    },
    extend: {
      fontSize: escala,
      maxWidth: {
        contenido: '1200px'
      }
    }
  },
  plugins: []
};
