require 'open_weather'
require 'time'


# get current weather by city name
    options = { units: "metric", APPID: "419bd88fe3f4c88ded08d6dcfaaebfc3", lang: "zh_tw" }
    weather = OpenWeather::Current.city("Xizhi, TW", options)

    Time.zone = "US"
    dt = Time.at(weather['dt']).to_datetime
    puts dt