const path = require('path');
const glob = require('glob');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const RelayCompilerWebpackPlugin = require('relay-compiler-webpack-plugin');

module.exports = (env, options) => ({
  stats: 'minimal',
  optimization: {
    minimizer: [
      new UglifyJsPlugin({ cache: true, parallel: true, sourceMap: false }),
      new OptimizeCSSAssetsPlugin({})
    ]
  },
  entry: {
      './js/app.js': ['./js/index.js'].concat(glob.sync('./vendor/**/*.js'))
  },
  output: {
    filename: 'app.js',
    path: path.resolve(__dirname, '../priv/static/js')
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      },
      {
        test: /\.css$/,
        use: [MiniCssExtractPlugin.loader, 'css-loader']
      },
      {
        test: /\.scss$/,
        use: [MiniCssExtractPlugin.loader, 'css-loader', 'sass-loader']
      },
      {
        test: /\.(png|jpg|jpeg|gif|svg|woff|woff2|ttf|eot)(\?.*$|$)/,
        loader: 'file-loader',
        options: {
          name: '[name].[ext]',
          outputPath: '../fonts/'
        }
      }
    ]
  },
  plugins: [
    new MiniCssExtractPlugin({
      filename: '../css/app.css'
    }),
    new CopyWebpackPlugin([{
      from: 'static/', to: '../'
    }]),
    new RelayCompilerWebpackPlugin({
      schema: path.resolve(__dirname, '../priv/graphql/schema.json'),
      src: path.resolve(__dirname, './js'),
    })
  ]
});
