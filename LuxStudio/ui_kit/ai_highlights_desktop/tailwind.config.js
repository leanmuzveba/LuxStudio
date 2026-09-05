/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./index.html"],
  theme: {
    extend: {
      colors: {
        dark: '#1A141A',
        panel: '#423738',
        brand: '#8E5915',
        accent: '#F4B315',
        secondary: '#D3AF85',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
