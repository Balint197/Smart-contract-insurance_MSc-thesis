from typing import Union
from fastapi import FastAPI
from pydantic import BaseModel
import Adafruit_DHT


app = FastAPI()

# how to start server for dev: 
# uvicorn iot_api:app --reload

# how to start server for prod: 
# uvicorn iot_api:app --host 0.0.0.0 --port 1234
# access: server_ip:1234

def getTemperature():
    temperature = None
    # try to get temperature every 2 seconds, timeout after 15 tries
    humidity, temperature = Adafruit_DHT.read_retry(11, 2)

    if temperature is not None:
        print(temperature)
        return temperature
    else:
        print('Failed to get reading. Try again!')
        return "Failed to get reading"


@app.get("/")
def read_root():
    return {"Welcome": "To the IoT weather node"}

@app.get("/weather")
def get_weather():
    return {"temperature": getTemperature()}
