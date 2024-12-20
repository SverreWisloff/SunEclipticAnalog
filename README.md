# README.md

[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://lbesson.mit-license.org/)

## SunEclipticAnalog

*The goal of this project is to create an analog watchface that displays the sun's path on the sky*

Assumes a round watchface

This clock shows a simple analog wathcface that shows the sun's path across the sky.

## Resources

A collection of Garmin applications: https://github.com/bombsimon/awesome-garmin

## Example code for sun calculations
It seems that it is "leaflet" Agafonkin who is behind the suncalc code that is used almost everywhere to calculate sunrise, sunset, and the sun's path in the sky. These are some projects I've been looking at:

| Navn  | språk | link   |
|-------|-------|--------|
| SunCalc - @mourner | `js` | [Github](https://github.com/mourner/suncalc) |
| SunCalc - haraldh | `monkeyC` | [Github](https://github.com/haraldh/SunCalc) [mc](https://github.com/haraldh/SunCalc/blob/master/source/SunCalc.mc)|
| Sundance - cizi (rotated fonts)| `monkeyC` | [Github](https://github.com/cizi/Sundance/blob/master/source/SunCalc.mc) |
|Late (nice fonts)|`monkeyC`|[Github](https://github.com/myneur/late/) [mc](https://github.com/myneur/late/blob/master/source/sunrisetCompute.mc)|
|runst-sun | `rust` |[Github](https://github.imc.re/flosse/rust-sun) [rust](https://github.imc.re/flosse/rust-sun/blob/master/src/lib.rs)|
|Python port of suncalc.js | `Pyton` | [link](https://pypi.org/project/suncalc/) |
|R|`R`|[link](https://cran.r-project.org/web/packages/suncalc/index.html) [Github](https://github.com/datastorm-open/suncalc)
|klausbrunner/solarpositioning|`java`|[Github](https://github.com/klausbrunner/solarpositioning) [java](https://github.com/KlausBrunner/solarpositioning/blob/master/src/main/java/net/e175/klaus/solarpositioning/Grena3.java)
|Grena/ENEA #3 algorithm| `Go` |[Github](https://github.com/klausbrunner/gosolarpos) [go](https://github.com/klausbrunner/gosolarpos/blob/master/grena3.go)
|SolarPosition - Arduino Library|`C`|[Github](https://github.com/KenWillmott/SolarPosition) [C](https://github.com/KenWillmott/SolarPosition/blob/master/SolarPosition.cpp)
|Sunrise equation|`Python` `pseudo`|[Wiki](https://en.wikipedia.org/wiki/Sunrise_equation)
|PostgreSQL|`sql`|[Github](https://github.com/olithissen/suncalc_postgres)|

### **Acknowledgments**
This project uses code from suncalc by Vladimir Agafonkin.
Repository: https://github.com/mourner/suncalc 
License: BSD 2-Clause "Simplified" License

Sundance: Both a  mc-fork, and rotated fonts for 24-hours at the perimeter  
https://github.com/cizi/Sundance/blob/master/source/SunCalc.mc

## Notes to self while coding

### Monkey C
- Forskjell på `import` / `using`: [Svar](https://developer.garmin.com/connect-iq/monkey-c/monkey-types/)
    - `import` and `using` bring a module into your scoping level
    - `import` it will bring the module suffix and all classes in the module into the type namespace. This allows classes in a module to be accessed without the modul suffix, making for easier typing. Function invocations still require the module suffix pto be accessed.
    - The difference between import and using is subtle. `import` brings the module name and class names into the namespace, where `using` only brings the module name into the namespace. If you are using monkeytypes you should use import exclusively, as it will save you a lot of redundant module references. Finally, the as clause is only supported for using statements.
    - `using` works fine unless you want to use type checking/Monkey Types
- `module` er en mengde med class. Ingen obj eller arv.
- dato / tid i monkey-c: 
    - `Time`: The Time module provides functionality for dealing with times and dates.
    - `Moment`: A Moment is an immutable moment in time. Internally, Moment objects are stored as 32-bit integers representing the number of seconds since the UNIX epoch (January 1, 1970 at 00:00:00 UTC).
    - `LocalMoment`: It differs from Moment in that it also keeps time zone information in addition to the time. \
    [Bra eksempelkode](https://developer.garmin.com/connect-iq/api-docs/Toybox/Time/LocalMoment.html)
    - `Gregorian`: *Moment* based on the Gregorian calendar
    - `info()` or `utcInfo()`: contains all of the necessary information to represent a Gregorian date.
- [Storage](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/)
    - only make calls that hit the file system as infrequently as possible as those calls are expensive
    - Simulatoren lagrer data her: %Temp%\com.garmin.connectiq\GARMIN\APPS\DATA
- Build for device:
    - Ctrl + Shift + P -> Monkey C: Build for Device
    - bin (Choose a directory for the output and click Select Folder)
    - Copy the generated `PRG` files to your device’s `GARMIN/APPS` directory

### VS Code
- VS Code: Stop running: `shift + F5`
- VS Code: Build + run: `F5`
- VS Code: Ctrl + Shift + P: `Monkey C`

## TODO
- [ ] Check out Github Copilot
- [ ] Add and test more watches 
- [ ] Add settings
- [ ] drawBattery. Look at this [code](https://github.com/dennybiasiolli/garmin-connect-iq/tree/main/Analog24hour/source) [IQ](https://apps.garmin.com/nb-NO/apps/292387a3-611e-49bd-add4-dee28edc1d57)
- [ ] Test south hemisphere
- [ ] Test midnight sun and Polar Night
- [ ] Sjekk ut fontene her: https://github.com/sunpazed/garmin-flags/tree/master/resources/fonts
- [ ] Calculate the size of graphic elements (clock hands) proportional to the clock's size (in pixels)
- [ ] [Power optimizing](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html)
- [ ] Read https://developer.garmin.com/connect-iq/core-topics/build-configuration/


## Screenshot
![screehot](https://github.com/SverreWisloff/SunEclipticAnalog/blob/main/screenshot/screenshot_20241220.png?raw=true)
