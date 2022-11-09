require("dotenv").config();
const axios = require('axios').default;

const WeatherProvider = {
    OpenWeatherMap: 'OpenWeatherMap',
    AccuWeather: 'AccuWeather',
    OpenMeteo: 'OpenMeteo',
    WeatherStack: 'WeatherStack',
    VisualCrossing: 'VisualCrossing',
    Tomorrow: 'Tomorrow'
};

async function getTempByLatLon(lat, lon, source) {
    switch (source) {
        case 'OpenWeatherMap':
            axios.get(process.env.OPENWEATHERMAP_URL, {
                    params: {
                        APPID: process.env.OPENWEATHERMAP_API,
                        lat: lat,
                        lon: lon,
                        units: 'metric' // get results in Celsius degrees
                    }
                })
                .then(function(response) {
                    return response.data.main.temp
                })
                .catch(function(error) {
                    console.log(error);
                })
                // .then(function () {
                // });  
            break
        case 'AccuWeather':
            // 1: get location key
            axios.get(process.env.ACCUWEATHER_GEOPOS_URL, {
                    params: {
                        apikey: process.env.ACCUWEATHER_API,
                        q: String(String(lat) + ',' + String(lon))
                    }
                })
                .then(function(response) {
                    let locationKey = response.data.Key
                        // 2: get weather from location key
                    axios.get(process.env.ACCUWEATHER_CONDITIONS_URL + locationKey, {
                            params: {
                                apikey: process.env.ACCUWEATHER_API,
                            }
                        })
                        .then(function(response) {
                            console.log(response.data[0].Temperature.Metric.Value)
                            return response.data[0].Temperature.Metric.Value
                        })
                        .catch(function(error) {
                            console.log(error);
                            console.log('Couldn\'t get weather data');
                        })
                        .then(function() {});
                })
                .catch(function(error) {
                    console.log(error);
                    console.log('Couldn\'t get location');
                })
                .then(function() {});
            break
        case 'OpenMeteo':
            axios.get(process.env.OPEN_METEO_URL, {
                    params: {
                        latitude: lat,
                        longitude: lon,
                        current_weather: true
                    }
                })
                .then(function(response) {
                    return response.data.current_weather.temperature
                })
                .catch(function(error) {
                    console.log(error);
                })
                .then(function() {});
            break
        case 'WeatherStack':
            axios.get(process.env.WEATHERSTACK_URL, {
                    params: {
                        access_key: process.env.WEATHERSTACK_API,
                        query: String(lat) + ',' + String(lon),
                        units: 'm'
                    }
                })
                .then(function(response) {
                    return response.data.current.temperature
                })
                .catch(function(error) {
                    console.log(error);
                })
                .then(function() {});
            break
        case 'VisualCrossing':
            axios.get(process.env.VISUALCROSSING_URL + lat + ',' + lon + '/today', {
                    params: {
                        unitGroup: 'metric',
                        elements: 'temp',
                        include: 'current',
                        key: process.env.VISUALCROSSING_API,
                        options: 'nonulls',
                        contentType: 'json'
                    }
                })
                .then(function(response) {
                    return response.data.currentConditions.temp
                })
                .catch(function(error) {
                    console.log(error);
                })
                .then(function() {});
            break
        case 'Tomorrow':
            axios.get(process.env.TOMORROW_URL, {
                    params: {
                        location: lat + ',' + lon,
                        fields: 'temperature',
                        timesteps: 'current',
                        units: 'metric',
                        apikey: process.env.TOMORROW_API
                    }
                })
                .then(function(response) {
                    return response.data.data.timelines[0].intervals[0].values.temperature
                })
                .catch(function(error) {
                    console.log(error);
                })
                .then(function() {});
            break
        default:
            console.log('wrong source')
    }
}

/*async function getTempByLatLon2(lat, lon, source) {
    const test = axios.get(process.env.OPENWEATHERMAP_URL, {
        params: {
            APPID: process.env.OPENWEATHERMAP_API,
            lat: lat,
            lon: lon,
            units: 'metric' // get results in Celsius degrees
        }
    })
    console.log(test)
    return test.data.main.temps
}

async function mounted() {
    const gettest = await getTempByLatLon2(47.473481, 19.058983, 'OpenWeatherMap')
    console.log(gettest)
}

mounted()
*/

//getTempByLatLon(47.473481, 19.058983, 'OpenWeatherMap')

//getTempByLatLon(47.473481, 19.058983, 'OpenWeatherMap').then(weatherData => console.log(weatherData))
getTempByLatLon(47.473481, 19.058983, 'AccuWeather')
getTempByLatLon(47.473481, 19.058983, 'OpenMeteo')
getTempByLatLon(47.473481, 19.058983, 'WeatherStack')
getTempByLatLon(47.473481, 19.058983, 'VisualCrossing')
getTempByLatLon(47.473481, 19.058983, 'Tomorrow')
    //getTempByLatLon(47.473481, 19.058983, 'WeatherBit') // not implemented yet (30 day trial)


// 47.473481, 19.058983