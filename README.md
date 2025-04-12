# ds18b20-NodeMCU

**ds18b20-NodeMCU** is a Lua module for **NodeMCU (ESP8266/ESP32)** that enables communication with DS18B20 temperature sensors over the 1-Wire bus.  
It supports multiple sensors, powered and parasite power modes, temperature conversion, resolution settings, and alarm thresholds.

## Features

- Scan and detect multiple DS18B20 sensors on the 1-Wire bus
- Supports both powered and parasite-powered configurations
- Read temperature with up to 12-bit resolution
- Configure per-device alarm thresholds
- Compatible with Skip ROM and individual ROM access

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/Raadgie/ds18b20-NodeMCU.git
