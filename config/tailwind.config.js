const defaultContent = [
  "./app/views/**/*.{erb,html,html.erb}",
  "./app/helpers/**/*.rb",
  "./app/assets/tailwind/**/*.{css}",
  "./app/javascript/**/*.{js,ts,jsx,tsx}",
  "./lib/**/*.{rb}"
];

export default {
  content: defaultContent,
  important: ".fm-admin",
  theme: {
    extend: {}
  },
  plugins: []
};
