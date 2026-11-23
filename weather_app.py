#!/usr/bin/env python3
"""Weather Application - A command-line tool to fetch weather data using Open-Meteo API."""

import sys
import urllib.request
import urllib.error
import json
from typing import Optional, Dict, Any


def get_weather(city: str) -> Optional[Dict[str, Any]]:
    """
    Fetch weather data for a given city using the Open-Meteo API.

    Open-Meteo geocoding API is used to convert city name to coordinates,
    then the weather API fetches the current weather.

    Args:
        city: Name of the city to fetch weather for

    Returns:
        Dictionary with weather data if successful, None otherwise
    """
    try:
        # Step 1: Geocode the city to get latitude and longitude
        geocode_url = "https://geocoding-api.open-meteo.com/v1/search"
        params = urllib.parse.urlencode({"name": city, "count": 1, "language": "en"})
        full_url = f"{geocode_url}?{params}"
        req = urllib.request.Request(full_url)
        with urllib.request.urlopen(req, timeout=10) as response:
            geocode_data = json.loads(response.read().decode())

        # Check if city was found
        if not geocode_data.get("results"):
            print(f"❌ City '{city}' not found. Please check the spelling and try again.")
            return None

        result = geocode_data["results"][0]
        latitude = result["latitude"]
        longitude = result["longitude"]
        city_name = result.get("name", city)
        country = result.get("country", "")

        # Step 2: Fetch weather data using coordinates
        weather_url = "https://api.open-meteo.com/v1/forecast"
        params = urllib.parse.urlencode({
            "latitude": latitude,
            "longitude": longitude,
            "current_weather": "true",
            "hourly": "temperature_2m,weathercode",
            "daily": "weathercode,temperature_2m_max,temperature_2m_min",
            "timezone": "auto",
        })
        full_weather_url = f"{weather_url}?{params}"
        req = urllib.request.Request(full_weather_url)
        with urllib.request.urlopen(req, timeout=10) as response:
            weather_data = json.loads(response.read().decode())

        # Step 3: Extract and format current weather
        current = weather_data.get("current_weather", {})
        temperature = current.get("temperature")
        wind_speed = current.get("windspeed")
        wind_direction = current.get("winddirection")
        weather_code = current.get("weathercode")
        time = current.get("time")

        # Get hourly temperature if available
        hourly = weather_data.get("hourly", {})
        hourly_temps = hourly.get("temperature_2m", [])
        hourly_times = hourly.get("time", [])

        # Get daily forecast if available
        daily = weather_data.get("daily", {})
        daily_weather_codes = daily.get("weathercode", [])
        daily_max_temps = daily.get("temperature_2m_max", [])
        daily_min_temps = daily.get("temperature_2m_min", [])
        daily_dates = daily.get("time", [])

        return {
            "city": city_name,
            "country": country,
            "latitude": latitude,
            "longitude": longitude,
            "temperature": temperature,
            "wind_speed": wind_speed,
            "wind_direction": wind_direction,
            "weather_code": weather_code,
            "time": time,
            "hourly_temps": hourly_temps,
            "hourly_times": hourly_times,
            "daily_weather_codes": daily_weather_codes,
            "daily_max_temps": daily_max_temps,
            "daily_min_temps": daily_min_temps,
            "daily_dates": daily_dates,
        }

    except urllib.error.HTTPError as e:
        print(f"❌ City '{city}' not found. Please check the spelling and try again.")
        return None
    except urllib.error.URLError as e:
        print(f"❌ Network error: Could not connect to weather service. {e.reason}")
        return None
    except Exception as e:
        print(f"❌ Error fetching weather data: {e}")
        return None


def format_weather_code(code: int) -> str:
    """Convert Open-Meteo weather code to human-readable description."""
    weather_codes = {
        0: "Clear sky",
        1: "Mainly clear",
        2: "Partly cloudy",
        3: "Overcast",
        45: "Fog",
        48: "Depositing rime fog",
        51: "Light drizzle",
        53: "Moderate drizzle",
        55: "Dense drizzle",
        56: "Light freezing drizzle",
        57: "Dense freezing drizzle",
        61: "Slight rain",
        63: "Moderate rain",
        65: "Heavy rain",
        66: "Light freezing rain",
        67: "Heavy freezing rain",
        71: "Slight snow fall",
        73: "Moderate snow fall",
        75: "Heavy snow fall",
        77: "Snow grains",
        80: "Rain showers",
        81: "Rain showers",
        82: "Rain showers",
        85: "Snow showers",
        86: "Snow showers",
        95: "Thunderstorm",
        96: "Thunderstorm with slight hail",
        99: "Thunderstorm with heavy hail",
    }
    return weather_codes.get(code, f"Unknown code {code}")


def display_weather(weather: Dict[str, Any]) -> None:
    """
    Display weather data in a styled terminal format.

    Args:
        weather: Dictionary containing weather data from get_weather()
    """
    # ANSI color codes for styling
    RESET = "\033[0m"
    BOLD = "\033[1m"
    CYAN = "\033[36m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    RED = "\033[31m"
    BLUE = "\033[34m"

    city = weather["city"]
    country = weather["country"]
    temp = weather["temperature"]
    wind_speed = weather["wind_speed"]
    wind_dir = weather["wind_direction"]
    description = format_weather_code(weather["weather_code"])
    time = weather["time"]

    # Header
    print(f"\n{CYAN}{BOLD}" + "=" * 50 + RESET)
    print(f"{CYAN}{BOLD}Weather Forecast for {city}, {country}{RESET}")
    print(f"{CYAN}{BOLD}" + "=" * 50 + RESET + "\n")

    # Current condition
    print(f"{GREEN}Current Conditions:{RESET}")
    print(f"  Time: {time}")
    print(f"  Temperature: {temp}°C" if temp else "  Temperature: N/A")
    print(f"  Description: {description}")
    print(f"  Wind: {wind_speed} km/h from {wind_dir}°" if wind_speed and wind_dir else f"  Wind: N/A")
    print()

    # Daily forecast (next 3 days)
    print(f"{GREEN}Daily Forecast:{RESET}")
    daily_dates = weather.get("daily_dates", [])
    daily_max = weather.get("daily_max_temps", [])
    daily_min = weather.get("daily_min_temps", [])
    daily_codes = weather.get("daily_weather_codes", [])

    if daily_dates:
        for i in range(min(3, len(daily_dates))):
            date = daily_dates[i]
            max_temp = daily_max[i] if i < len(daily_max) else "N/A"
            min_temp = daily_min[i] if i < len(daily_min) else "N/A"
            code = daily_codes[i] if i < len(daily_codes) else 0
            desc = format_weather_code(code)
            print(f"  {date}: {desc} (High: {max_temp}°C, Low: {min_temp}°C)")
    else:
        print("  No daily forecast available")
    print()

    # Hourly forecast (next few hours)
    print(f"{GREEN}Next Few Hours:{RESET}")
    hourly_temps = weather.get("hourly_temps", [])
    hourly_times = weather.get("hourly_times", [])

    if hourly_times:
        for i in range(min(4, len(hourly_times))):
            time_str = hourly_times[i]
            temp = hourly_temps[i] if i < len(hourly_temps) else "N/A"
            print(f"  {time_str}: {temp}°C")
    else:
        print("  No hourly forecast available")

    # Footer
    print(f"\n{CYAN}{BOLD}" + "=" * 50 + RESET)


def main() -> None:
    """Main entry point for the weather application."""
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <city_name>")
        print(f"Example: {sys.argv[0]} London")
        print(f"Example: {sys.argv[0]} New York")
        sys.exit(1)

    city = " ".join(sys.argv[1:])
    print(f"🔍 Fetching weather for: {city}...\n")

    weather = get_weather(city)

    if weather:
        display_weather(weather)
    else:
        print(f"\n❌ Could not retrieve weather data for '{city}'.")
        print("Please check the city name and try again.")
        sys.exit(1)


if __name__ == "__main__":
    main()