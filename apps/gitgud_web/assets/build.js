const esbuild = require("esbuild")
const {sassPlugin} = require("esbuild-sass-plugin");

const args = process.argv.slice(2)
const watch = args.includes("--watch")
const deploy = args.includes("--deploy")

const loader = {
  ".eot": "file",
  ".woff": "file",
  ".woff2": "file",
  ".svg": "file",
  ".ttf": "file",
}

const plugins = [
  sassPlugin({
    quietDeps: true
  })
]

let opts = {
  entryPoints: ["js/index.js"],
  bundle: true,
  target: "es2016",
  outdir: "../priv/static/assets",
  logLevel: "silent",
  loader,
  plugins
}

if (watch) {
  opts = {
    ...opts,
    watch,
    sourcemap: "inline"
  }
}

if (deploy) {
  opts = {
    ...opts,
    minify: true
  }
}

const promise = esbuild.build(opts)

if (watch) {
  promise.then(_result => {
    process.stdin.on("close", () => {
      process.exit(0)
    })

    process.stdin.resume()
  })
}
