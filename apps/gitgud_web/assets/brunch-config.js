exports.config = {
  files: {
    javascripts: {
      joinTo: "js/app.js"
    },
    stylesheets: {
      joinTo: "css/app.css"
    },
    templates: {
      joinTo: "js/app.js"
    }
  },

  conventions: {
    assets: [
      /^(static)/,
    ],
    ignored: [
      /^__generated__/
    ]
  },

  paths: {
    watched: ["static", "css", "js"],
    public: "../priv/static"
  },

  plugins: {
    babel: {
      presets: ["latest", "stage-0", "react"],
      plugins: ["relay"]
    },
    sass: {
      mode: "native"
    }
  },

  modules: {
    autoRequire: {
      "js/app.js": ["js/app"]
    }
  },

  npm: {
    enabled: true
  }
};
