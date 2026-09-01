/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        paper: {
          DEFAULT: '#EAE6D9',
          dark: '#DCD6C3',
          line: '#C9C2A9',
        },
        ink: {
          DEFAULT: '#1B3A2F',
          soft: '#3A5647',
          faint: '#6B7D71',
        },
        stamp: {
          DEFAULT: '#A6392C',
          soft: '#C9584A',
        },
        gold: {
          DEFAULT: '#9C7A1F',
          soft: '#BFA24A',
        },
      },
      fontFamily: {
        display: ['"Newsreader"', 'Georgia', 'serif'],
        body: ['"IBM Plex Sans"', 'system-ui', 'sans-serif'],
        mono: ['"IBM Plex Mono"', 'ui-monospace', 'monospace'],
      },
      backgroundImage: {
        'paper-texture':
          "repeating-linear-gradient(0deg, rgba(27,58,47,0.035) 0px, rgba(27,58,47,0.035) 1px, transparent 1px, transparent 32px)",
      },
    },
  },
  plugins: [],
}
