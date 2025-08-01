/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      // 필요한 색상만 추가
      colors: {
        'custom-blue': '#2563eb',
        'custom-green': '#22c55e',
        'custom-red': '#ef4444',
      }
    },
  },
  plugins: [],
}
