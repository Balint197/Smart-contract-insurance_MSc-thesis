from typing import Union
from fastapi import FastAPI
from pydantic import BaseModel
import sys 
import time

app = FastAPI()

# how to start server: 
# uvicorn iot_api:app --reload

currentTemperature : int = 0

def getTemperature():
    temperature = 10
    #humidity, temperature = Adafruit_DHT.read_retry(sensor, pin)

    time.sleep(5)
    if temperature is not None:
        print(temperature)
        return temperature
    else:
        print('Failed to get reading. Try again!')
        #sys.exit(1)


@app.get("/")
def read_root():
    return {"Welcome": "To the IoT weather node"}

@app.get("/weather")
def get_weather():
    return {"temperature": getTemperature()}

# bad?
@app.get("/async_weather")
async def get_weather_async():
    result = await getTemperature()
    return {"temperature": result}