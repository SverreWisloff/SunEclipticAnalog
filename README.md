# README.md

[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://lbesson.mit-license.org/)

## SunEclipticAnalog

*The goal of this project is to create an analog watchface that displays the sun's path on the sky*

This simple analog round wathcface shows the sun's path across the sky. Its inspired by the seasonal variations.

The user can see where the sun is in the sky. Both direction (azimuth) and height above the horizon. After the sun has set, the direction of the sun is displayed along the watch perimeter.

There are settings for the color of the second hand and whether the date, battery-level or status-icons should be displayed.

[Sales pitch that chatGPT helped me with](https://github.com/SverreWisloff/SunEclipticAnalog/blob/main/STORE.md)

## Resources

A huge collection of Garmin applications: https://github.com/bombsimon/awesome-garmin

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

Another nice website for sunset/sunrise calculations: [stjärnhimlen](https://www.stjarnhimlen.se/comp/riset.html)

### **Acknowledgments**
This project uses code from suncalc by Vladimir Agafonkin.
Repository: https://github.com/mourner/suncalc 
License: BSD 2-Clause "Simplified" License

[Sundance](https://github.com/cizi/Sundance/blob/master/source/SunCalc.mc): Both a  mc-fork, and rotated fonts for 24-hours at the perimeter  

# Supported Devices
enduro, fenix5, fenix5plus, fenix5x, fenix5xplus, fenix6, fenix6pro, fenix6s, fenix6spro, fenix6xpro, fenix7, fenix7pro, fr965, fr955, fr945, fr945lte, fr265, fr265s


## Screenshot
![screehot](https://github.com/SverreWisloff/SunEclipticAnalog/blob/main/screenshot/screenshot_20250105_sim.jpg?raw=true)

## Realease-log

**Dev**
- compute and draw solar noon as a dot at sun ephemeris

**1.4**
- Status-icons for connected phone, alarm and notifications.
- Adding support for fr965, fr955, fr945, fr945lte, fr265, fr265s

**1.3**
- Showing battery level and charging status
- Updating pos and calculating sun trajectorya and sun-events every 10 minutes
- Adding support for enduro, fenix5, fenix5plus, fenix5x, fenix5xplus, fenix6, fenix6pro, fenix6s, fenix6spro, fenix6xpro, fenix7, fenix7pro
- SDK 7.4.3

**1.2**
- Show times for sunset and sunrise 
- Supports midnight sun and polar night
- Settings: Show/hide date, and second hand color
- Settings: Debug info

**1.1**
- Draw the sun even though it has set.
- Draw prettier indexes and hands (ala Quatix 5)

**1.0**
- First version

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
 - WatchFace [Power optimizing](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html)
 - Fonter. Her er noen prosjekter å la seg inspirere av: [Forerunner745](https://github.com/sennescheepers/Forerunner745Watchface/). [Protomolecule](https://github.com/blotspot/garmin-watchface-protomolecule). [MoveToBeActive](https://github.com/fevieira27/MoveToBeActive). [Crystal-face](https://github.com/warmsound/crystal-face/). 
 - Supporting devices. [Compatible devices](https://developer.garmin.com/connect-iq/compatible-devices/). [Device Reference](https://developer.garmin.com/connect-iq/reference-guides/devices-reference/)
 - IF THEN ELSE
    - (batteryLevel > 20) ? "Battery OK" : "Low Battery";


### VS Code
- VS Code: Stop running: `shift + F5`
- VS Code: Build + run: `F5`
- VS Code: Ctrl + Shift + P: `Monkey C`

### Store

**Update store**
1. Update version number: manifest.xml
2. Update [STORE.md](https://github.com/SverreWisloff/SunEclipticAnalog/blob/main/STORE.md)
3. Update [README.md](https://github.com/SverreWisloff/SunEclipticAnalog/blob/main/README.md)
4. Update release-log: check [activity](https://github.com/SverreWisloff/SunEclipticAnalog/activity)
5. Update screenshot (over Image - 500x500)
6. Exporting the App (IQ-file)
7. [Upload new version](https://apps.garmin.com/developer/dashboard) >IQ >Log >screenshot

### Images
#### Hero Image (Optional)
Add an image optimized for mobile devices to advertise your app. The image (JPG, GIF or PNG) has to be 1440x720 pixels large and can have a maximum size of 2048 KB.
#### Cover Image (Web/Mobile)
This cover image will be displayed on your Connect IQ Store listing on the Web and the Connect IQ App Store mobile app. Image must be a **JPG**, GIF or PNG less than 150 KB.
(500 x 500)
#### Add Icons for App Store on Device (Optional)
The colors in the device icons should be reduced as labeled and should only be 128 x 128 pixels.
#### Screen Images
Screen images will be displayed on your app’s detail page in the Connect IQ Store. Image must be a JPG, GIF or PNG less than 150 KB


## TODO
- [ ] Bug: Compensate for solar noon
- [ ] Add and test more watches (Forerunner? 965, 265, 255, 55, 165, 955, 245, 9xx). Compatible [devices](https://developer.garmin.com/connect-iq/compatible-devices/). Device [Reference](https://developer.garmin.com/connect-iq/reference-guides/devices-reference/). Popular [watches](https://runningwithrock.com/which-are-the-most-popular-garmin-running-watches/)
- [ ] Test south hemisphere
- [ ] Read https://developer.garmin.com/connect-iq/core-topics/build-configuration/
- [ ] status-iconer  4) minutes 5) body-battery 6) puls 7) altitude 8) barometer 9) skritt. Og her enda ).
- [x] Add settings
- [x] Add and test more watches 
- [x] drawBattery. Look at this [code](https://github.com/dennybiasiolli/garmin-connect-iq/tree/main/Analog24hour/source) [IQ](https://apps.garmin.com/nb-NO/apps/292387a3-611e-49bd-add4-dee28edc1d57)
- [x] status-iconer  1) alarm 2) bluetooth 3) messages ~~4) minutes 5) body-battery 6) puls 7) altitude 8) barometer 9) skritt.~~ . Bilder av [origial-iconer](https://www8.garmin.com/manuals/webhelp/GUID-C001C335-A8EC-4A41-AB0E-BAC434259F92/NB-NO/GUID-700E76C4-F7E2-4984-8199-D59D6A31DFB9.html)
- [x] Test midnight sun and Polar Night
- [x] Sjekk ut fontene her: https://github.com/sunpazed/garmin-flags/tree/master/resources/fonts
- [x] Calculate the size of graphic elements (clock hands) proportional to the clock's size (in pixels)
- [x] [Power optimizing](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html)

