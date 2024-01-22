const path = require('path');

module.exports = {
  mode: 'development', // or 'production'
  target: 'web',
  entry: './invitationApp/addData.js', // Specify the entry point of your application
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname,'..','content','invitation.davidbornitz.dev'), 
  },
  module: {
    rules: [
      {
        test: /\.js$/, // Use the loader for files ending with .js
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader', // Use babel-loader for JavaScript files
        },
      },
    ],
  },
  resolve: {
    extensions: ['.js'], // Specify file extensions to resolve
  },
};
