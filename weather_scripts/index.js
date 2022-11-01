//import {PythonShell} from 'python-shell';
const {PythonShell} = require('python-shell')

PythonShell.run('iot_weather.py', null, function (err, results) {
  if (err) throw err;
  // console.log('results: %j', results)
  if (results.length > 0){
    let temperature = results[0]
    console.log('parsed temperature: ', temperature)
  }
});