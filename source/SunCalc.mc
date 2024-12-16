import Toybox.System;
import Toybox.Position;
import Toybox.Math;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;



module SunCalcModule
{
    const RAD  = Math.PI / 180.0; 

    // sun calculations are based on http://aa.quae.nl/en/reken/zonpositie.html formulas

    // date/time constants and conversions
    const dayMs = 60 * 60 * 24.0; //SECONDS_PER_DAY
    const J1970 = 2440588.0;
    const J2000 = 2451545.0;

    //date is time_in_ms
    function toJulian(date) {   return date.toDouble() / dayMs.toDouble() - 0.5 + J1970.toDouble(); }
    function fromJulian(j)  {   return (j.toDouble() + 0.5 - J1970.toDouble()) * dayMs.toDouble(); } // converts a Julian date j into a corresponding time in milliseconds relative to January 1, 1970 (Unix Epoch)
    function toDays(date)   {   return toJulian(date) - J2000.toDouble(); }    // converts a date into the number of days since the J2000 epoch

    // general calculations for position
    var e = RAD * 23.4397; // obliquity of the Earth

    //ecliptic coordinates:    l = ecliptic longitude   ,      b = ecliptic latitude
    //equatorial coordinates: ra = right ascension      ,    dec = declination
    function rightAscension(l, b){ return Math.atan2(Math.sin(l) * Math.cos(e) - Math.tan(b) * Math.sin(e), Math.cos(l));     }
    function declination(l, b){ return Math.asin(Math.sin(b) * Math.cos(e) + Math.cos(b) * Math.sin(e) * Math.sin(l));     }

    function azimuth(H, phi, dec){ return Math.atan2(Math.sin(H), Math.cos(H) * Math.sin(phi) - Math.tan(dec) * Math.cos(phi));    }
    function altitude(H, phi, dec){ return Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(H)); }

    function siderealTime(d, lw) { return RAD * (280.16 + 360.9856235 * d) - lw; } // calculates the sidereal time for a given date and location. lw: longitude of the observer's location (in RADians)

    function astroRefraction(h) {
        if (h < 0) // the following formula works for positive altitudes only.
        {
            h = 0; // if h = -0.08901179 a div/0 would occur.
        }
        // formula 16.4 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
        // 1.02 / tan(h + 10.26 / (h + 5.10)) h in degrees, result in arc minutes -> converted to rad:
        return 0.0002967 / Math.tan(h + 0.00312536 / (h + 0.08901179));
    }

    // general sun calculations
    function solarMeanAnomaly(d) {return RAD * (357.5291 + 0.98560028 * d);}

    function eclipticLongitude(M) {
        var C = RAD * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2.0 * M) + 0.0003 * Math.sin(3.0 * M)); // equation of center
        var P = RAD * 102.9372; // perihelion of the Earth

        return M + C + P + Math.PI;
    }

    // Class that holds times for sunset, sun-noon, and sunrise
    class solarTimes
    {
            var solarSet = 0.0;
            var solarRise = 0.0;
            var solarNoon = 0.0;
    }

    class LatLon
    {
        public var lat = 0.0;
        public var lon = 0.0;
    }
    
    // the Sun’s local position in the sky at a specific time and location (useful for observers on Earth)
    class SunCoord_LocalPosition
    {
        public var azimuth  = 0.0;
        public var altitude = 0.0;
    }

    // the Sun’s position on the celestial sphere (useful for understanding seasonal changes and universal celestial mapping)
    class SunCoord_CelestialSphere
    {
        public var declination = 0.0;
        public var rightAscension = 0.0;
    }

    function sunCoords(d) {
        var sunCoor = new SunCoord_CelestialSphere();

        var M = solarMeanAnomaly(d);
        var L = eclipticLongitude(M);

        sunCoor.declination    =  declination(L, 0);
        sunCoor.rightAscension = rightAscension(L, 0);

        return sunCoor;
    }


    // calculates sun position for a given time and latitude/longitude
    function getPosition(date, lat, lng) {
        var sunCoordLocal = new SunCoord_LocalPosition();
        var sunCoordSphere = new SunCoord_CelestialSphere();
        var lw  = RAD * -lng;
        var phi = RAD * lat;
        var d   = toDays(date);

        sunCoordSphere = sunCoords(d);
        var H  = siderealTime(d, lw) - sunCoordSphere.rightAscension;

        sunCoordLocal.azimuth = azimuth(H, phi, sunCoordSphere.declination)/RAD;
        sunCoordLocal.altitude = altitude(H, phi, sunCoordSphere.declination)/RAD;

        return sunCoordLocal;
    }


    enum solarEvent_enum { 
        NIGHTEND = -18.0,          //The moment when the sky starts to lighten, marking the end of astronomical night
        NAUTICALDAWN = -12.0,      //The beginning of nautical twilight, where the horizon is faintly visible at sea.
        DAWN = -6.0,               //The start of civil twilight when the sky is bright enough for most outdoor activities without artificial light
        SUNRISE = -0.833,          //The moment the sun's upper edge becomes visible above the horizon.
        SUNRISEEND = -0.3,         //The time at which the full disk of the sun is above the horizon
        GOLDENHOUREND = 6.0,       //The time when the "golden hour" ends in the morning, which is a period of soft, warm light ideal for photography

        GOLDENHOUR = -6.0,         //A period shortly after sunrise or before sunset with soft, diffused light
        SUNSETSTART = 0.3,         //The time when the sun starts to touch the horizon as it sets.
        SUNSET = 0.833,            //The moment the sun's upper edge dips below the horizon.
        DUSK = 6.0,                //The end of civil twilight, when it is too dark to see clearly without artificial light.
        NAUTICALDUSK = 12.0,       //The end of nautical twilight, where the horizon becomes indistinguishable at sea.
        NIGHT = 1.0                //Begins after astronomical dusk when the sky is completely dark.
        }

    // calculations for sun times
    const J0 = 0.0009;

    function julianCycle(d, lw) { return round(d - J0 - lw / (2.0 * Math.PI)); }

    function approxTransit(Ht, lw, n) { return J0 + ((Ht.toDouble() + lw.toDouble()) / (2.0 * Math.PI)) + n.toDouble()  - 1.1574e-5 * 68.0; } //SW!!!!!
    function solarTransitJ(ds, M, L)  { return J2000.toDouble() + ds + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2.0 * L); }

    function hourAngle(h, phi, d) { return Math.acos((Math.sin(h) - Math.sin(phi) * Math.sin(d)) / (Math.cos(phi) * Math.cos(d))); }
    function observerAngle(height) { return -2.076 * Math.sqrt(height) / 60; }

    // returns set time for the given sun altitude
    function getSetJ(h, lw, phi, dec, n, M, L) {

        var w = hourAngle(h, phi, dec);
        var a = approxTransit(w, lw, n);

        return solarTransitJ(a, M, L);
    }


    // calculates sun times for a given date, latitude/longitude, and, optionally,
    // the observer height (in meters) relative to the horizon
    function getTimes(date, lat, lng, height, solarEvent){
        var lw  = RAD * -lng;
        var phi = RAD *  lat;

        if (height==null){
            height = 0.0;
        }

        var dh = observerAngle(height);

        var d = toDays(date);
        var n = julianCycle(d, lw);
        var ds = approxTransit(0.0, lw, n);

        var M = solarMeanAnomaly(ds);
        var L = eclipticLongitude(M);
        var dec = declination(L, 0.0);

        var Jnoon = solarTransitJ(ds, M, L);

        var angle_deg = solarEvent.toDouble();

        var h0 = (angle_deg + dh) * RAD;
        var Jset = getSetJ(h0, lw, phi, dec, n, M, L);
        var Jrise = Jnoon - (Jset - Jnoon);

        var Times = new solarTimes();
        
        Times.solarSet = fromJulian(Jset);
        Times.solarRise = fromJulian(Jrise);
        Times.solarNoon = fromJulian(Jnoon);

        return Times;
    }

//////////////////////////////////////////// END OF Agafonkins code ////////////////// 

    // calculates sun position through the day for a given date and latitude/longitude
    function getSunPositionForDay(date, lat, lng) as Array<SunCoord_LocalPosition> {
        var sunCoordLocal = new SunCoord_LocalPosition();
        var result = new Array<SunCoord_LocalPosition>[24];

        var Moment = new Time.Moment(date);
        var infoDate = Gregorian.info(Moment, Time.FORMAT_SHORT);

        // Loop for every hour through the day 
        for (var i = 0; i <= 23; i += 1) {

            var options = {
                :year   => infoDate.year,
                :month  => infoDate.month,
                :day    => infoDate.day,
                :hour   => i,
                :minute => 0
            };

            var time_i = Gregorian.moment(options);
            sunCoordLocal = getPosition(time_i.value(), lat, lng);
            var az = sunCoordLocal.azimuth ;
            var alt = sunCoordLocal.altitude ;
            
            var resultAA = new SunCoord_LocalPosition();
            resultAA.azimuth = az; 
            resultAA.altitude = alt;
            result[i] = resultAA;

            //DEBUG
            System.println("i=" + i + " time=" + PrintLocaleTime(time_i.value()) + " az=" + az.format("%.4f")+ " alt=" + alt.format("%.4f"));
        }        

        return result;
    }


    function round(a) {
        if (a > 0) {
            return (a + 0.5).toNumber().toFloat();
        } else {
            return (a - 0.5).toNumber().toFloat();
        }
    }


    function LocaleTimeAsDesimalHour( timeUnix ) {
        var Moment = new Time.Moment(timeUnix);
        var desimalHour = 0.0000001 ;
        var infoDate = Gregorian.info(Moment, Time.FORMAT_SHORT);
        desimalHour = infoDate.hour + (infoDate.min/60.0);
        // e.g. 18.73
        return desimalHour;
    }

    function PrintLocaleTime( timeUnix ) {
        var Moment = new Time.Moment(timeUnix);
        var infoDate = Gregorian.info(Moment, Time.FORMAT_SHORT);
        var dateString = Lang.format(
            "$1$:$2$",
            [
                infoDate.hour.format("%02u"),
                infoDate.min.format("%02u")
            ]
        );
        // e.g. "18:43"
        return dateString;
    }

    function PrintTime( timeUnix, strDesc) {
        var Moment = new Time.Moment(timeUnix);
        var infoDate = Gregorian.info(Moment, Time.FORMAT_SHORT);
        var infoUTC = Gregorian.utcInfo(Moment, Time.FORMAT_SHORT);
        var dateString = Lang.format(
            "$1$: Time:$2$:$3$:$4$ UTC:$5$:$6$:$7$ Date:$8$-$9$-$10$ Unix_epoch_time:$11$",
            [
                strDesc,
                infoDate.hour.format("%02u"),
                infoDate.min.format("%02u"),
                infoDate.sec.format("%02u"),
                infoUTC.hour.format("%02u"),
                infoUTC.min.format("%02u"),
                infoUTC.sec.format("%02u"),
                infoDate.year.format("%04u"),
                infoDate.month.format("%02u"),
                infoDate.day.format("%02u"),
                timeUnix
            ]
        );
        // e.g. "INNPUT TIME: Time:18:43:57 UTC:17:43:57 Date:2024-11-02 Unix_epoch_time:1730569437"
        return dateString;
    }


}