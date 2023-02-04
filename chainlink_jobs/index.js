const { Requester, Validator } = require('@chainlink/external-adapter')


// Define custom error scenarios for the API.
// Return true for the adapter to retry.
const customError = (data) => {
    if (data.Response === 'Error') return true
    return false
}

// Define custom parameters to be used by the adapter.
// Extra parameters can be stated in the extra object,
// with a Boolean value indicating whether or not they
// should be required.
const customParams = {
    city: ['q', 'city', 'town'],
    endpoint: false
}

const createRequest = (input, callback) => {
    // The Validator helps you validate the Chainlink request data
    //const validator = new Validator(callback, input, customParams)
    const validator = new Validator(callback, input)
    const jobRunID = validator.validated.id
        //const url = `https://api.openweathermap.org/data/2.5/weather`
    const url = `http://192.168.100.27:1234/weather`
        //const q = validator.validated.data.city.toUpperCase()
        //  const lon = validator.validated.data.lon
        //  const lat = validator.validated.data.lat
        //const appid = process.env.API_KEY;
        /*
            const params = {
                //q,
                //lon,
                //lat,
                appid
            }
        */
    const config = {
        url //,
        //params
    }

    // The Requester allows API calls be retry in case of timeout
    // or connection failure
    Requester.request(config, customError)
        .then(response => {
            // It's common practice to store the desired value at the top-level
            // result key. This allows different adapters to be compatible with
            // one another.
            //response.data.result = Requester.validateResultNumber(response.data, ['main', 'temp'])
            response.data.result = Requester.validateResultNumber(response.data, ['temperature'])
            callback(response.status, Requester.success(jobRunID, response))
        })
        .catch(error => {
            callback(500, Requester.errored(jobRunID, error))
        })
}

module.exports.createRequest = createRequest