/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class',
  content: [
    './src/views/**/*.ejs',
    './views/**/*.ejs',
    './src/public/**/*.js',
    './public/**/*.js'
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#1E4620',
          hover: '#163518',
          subtle: '#E8F0E6',
        }
      }
    }
  },
  plugins: [],
};
