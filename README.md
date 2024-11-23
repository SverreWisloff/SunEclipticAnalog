# README.md

[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://lbesson.mit-license.org/)

## SunEclipticAnalog

*The goal of this project is to create an analog watchface that displays the sun's path on the sky*


## Resources

A collection of Garmin applications: https://github.com/bombsimon/awesome-garmin

## Sun calculations
It seems that it is "leaflet" Agafonkin who is behind the suncalc code that is used almost everywhere to calculate sunrise, sunset, and the sun's path in the sky.
Kildekoden finnes her: https://github.com/mourner/suncalc

a mc-fork: https://github.com/cizi/Sundance/blob/master/source/SunCalc.mc

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

### VS Code
- VS Code: Stop running: `shift + F5`
- VS Code: Build + run: `F5`
- VS Code: Ctrl + Shift + P: `Monkey C`

## Log
- 20241123: SunCalc.js written by 'Leaflet' Agafonkin
- 20241122: drawHashMarks
- 20241118: How to draw text rotated? [Scalable font](https://forums.garmin.com/developer/connect-iq/f/discussion/336765/bitmap-transformation) Samplecode: TrueTypeFonts. `drawAngledText` and `getVectorFont`. Deside to not rotate text because of lack of backward compatibility
- 20241116: Github. Getting font from https://www.dafont.com/
- 20241113: Establised. Copied from  `Sample`. API 1.2. Watches with circle-face.

## TODO
- [] Calculate the size of graphic elements (clock hands) proportional to the clock's size (in pixels)
- [] Draw sun to background
- [] Read https://developer.garmin.com/connect-iq/core-topics/build-configuration/
- [] Find SunCalc in different languages to read how other projects forks suncalc
- [x] How to calculate sun trajectory?
- [x] Lære dato / tid i monkey-c
- [x] Create a *debug* watchface where the solar calculations can be developed and tested.

## Screenshot
![screehot](https://github.com/SverreWisloff/SunEclipticAnalog/blob/main/screenshot/screenshot_20241123.png?raw=true)
