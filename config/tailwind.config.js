const defaultContent = [
  "./app/views/**/*.{erb,html,html.erb}",
  "./app/helpers/**/*.rb",
  "./app/assets/stylesheets/source_monitor/**/*.css",
  "./app/assets/javascripts/**/*.{js,ts,jsx,tsx}",
  "./lib/**/*.rb",
  "./test/dummy/app/views/**/*.{erb,html,html.erb}"
];

export default {
  content: defaultContent,
  important: ".fm-admin",
  theme: {
    extend: {}
  },
  plugins: []
};
