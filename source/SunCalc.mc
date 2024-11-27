import Toybox.System;
import Toybox.Position;
import Toybox.Math;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;


module SunCalcModule
{
    const rad  = Math.PI / 180.0; 

    // date/time constants and conversions
    const dayMs = 60 * 60 * 24.0; //SECONDS_PER_DAY
    const J1970 = 2440588.0;
    const J2000 = 2451545.0;

    //date is time_in_ms
    function toJulian(date) {   return date.toDouble() / dayMs.toDouble() - 0.5 + J1970.toDouble(); }
    function fromJulian(j)  {   return (j.toDouble() + 0.5 - J1970.toDouble()) * dayMs.toDouble(); } // converts a Julian date j into a corresponding time in milliseconds relative to January 1, 1970 (Unix Epoch)
    function toDays(date)   {   return toJulian(date) - J2000.toDouble(); }    // converts a date into the number of days since the J2000 epoch


    // general calculations for position
    var e = rad * 23.4397; // obliquity of the Earth

    //ecliptic coordinates:    l = ecliptic longitude   ,      b = ecliptic latitude
    //equatorial coordinates: ra = right ascension      ,    dec = declination
    function rightAscension(l, b){ 
        return Math.atan2(Math.sin(l) * Math.cos(e) - Math.tan(b) * Math.sin(e), Math.cos(l)); 
    }
    function declination(l, b){ 
        return Math.asin(Math.sin(b) * Math.cos(e) + Math.cos(b) * Math.sin(e) * Math.sin(l)); 
    }

    function azimuth(H, phi, dec){ 
        return Math.atan2(Math.sin(H), Math.cos(H) * Math.sin(phi) - Math.tan(dec) * Math.cos(phi)); 
    }
    function altitude(H, phi, dec){ 
        return Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(H)); 
    }

    function siderealTime(d, lw) { return rad * (280.16 + 360.9856235 * d) - lw; } // calculates the sidereal time for a given date and location. lw: longitude of the observer's location (in radians)

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
    function solarMeanAnomaly(d) { 
        return rad * (357.5291 + 0.98560028 * d); 
    }
    function eclipticLongitude(M) {
        var C = rad * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2.0 * M) + 0.0003 * Math.sin(3.0 * M)); // equation of center
        var P = rad * 102.9372; // perihelion of the Earth

        return M + C + P + Math.PI;
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



    // calculates sun position for a given date and latitude/longitude
    function getPosition(date, lat, lng) {
        var sunCoordLocal = new SunCoord_LocalPosition();
        var sunCoordSphere = new SunCoord_CelestialSphere();
        var lw  = rad * -lng;
        var phi = rad * lat;
        var d   = toDays(date);

        sunCoordSphere = sunCoords(d);
        var H  = siderealTime(d, lw) - sunCoordSphere.rightAscension;

        sunCoordLocal.azimuth = azimuth(H, phi, sunCoordSphere.declination);
        sunCoordLocal.altitude = altitude(H, phi, sunCoordSphere.declination);

        return sunCoordLocal;
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

    // Class that holds times for sunset, sun-noon, and sunrise
    class solarTimes
    {
            var solarSet = 0.0;
            var solarRise = 0.0;
            var solarNoon = 0.0;
    }

    // calculates sun times for a given date, latitude/longitude, and, optionally,
    // the observer height (in meters) relative to the horizon
    // angle_deg=-0.833 // sunrise/sunset 
    function getTimes(date, lat, lng, height, angle_deg){
        var lw  = rad * -lng;
        var phi = rad *  lat;

        var dh = observerAngle(height);

        var d = toDays(date);
        var n = julianCycle(d, lw);
        var ds = approxTransit(0.0, lw, n);
        System.println("getTimes: observerAngle dh=" + dh);
        System.println("getTimes: days           d=" + d );
        System.println("getTimes: julianCycle    n=" + n );
        System.println("getTimes:               lw=" + lw );
        System.println("getTimes: approxTransit ds=" + ds);

        var M = solarMeanAnomaly(ds);
        var L = eclipticLongitude(M);
        var dec = declination(L, 0.0);
        System.println("getTimes: solarMeanAnomaly  M=" + M );
        System.println("getTimes: eclipticLongitude L=" + L );
        System.println("getTimes: declination     dec=" + dec  );

        var Jnoon = solarTransitJ(ds, M, L);

        var h0 = (angle_deg + dh) * rad;
        var Jset = getSetJ(h0, lw, phi, dec, n, M, L);
        var Jrise = Jnoon - (Jset - Jnoon);

        var Times = new solarTimes();
        
        Times.solarSet = fromJulian(Jset);
        Times.solarRise = fromJulian(Jrise);
        Times.solarNoon = fromJulian(Jnoon);

        return Times;
    }

////////////////////////////////////////////
    function round(a) {
        if (a > 0) {
            return (a + 0.5).toNumber().toFloat();
        } else {
            return (a - 0.5).toNumber().toFloat();
        }
    }

    function truncate(x) {return x < 0 ? -Math.floor(-x) : Math.floor(x);}
    function Fmod( x,  y) {return x - truncate(x / y) * y;}

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
        // e.g. "18:43:57"
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
    
    // test SunCalc-computations
    function TestSunCalc() {
        //setter testdata
        var pos = new Position.Location({
            :latitude  => 59.837330,
            :longitude => 10.460190,
            :format    => :degrees,
        });
        var infoPos = pos.toDegrees();
        var lat = infoPos[0]; 
        var lng = infoPos[1];
        var height = 0.0;

        var now = Time.now();
        var dateNow = new Time.Moment(now.value() );
        System.println( PrintTime(dateNow.value(), "INNPUT TIME") );
        System.println("INNPUT POS: Lat=" + lat + " lng=" + lng + " height=" + height);

        //////////////////////////////////
        //// Agafonkin ///////////////////
        //////////////////////////////////
        var lw  = rad *  lng * (-1.0);
        var phi = rad *  lat;

        //begynner å beregne
        var dh = observerAngle(height);

        var d = toDays(dateNow.value()); 
        var n = julianCycle(d, lw);
        var ds = approxTransit(0.0, lw, n);

        System.println("agafonkin: observerAngle dh=" + dh);
        System.println("agafonkin: days           d=" + d );
        System.println("agafonkin: julianCycle    n=" + n );
        System.println("agafonkin:               lw=" + lw );
        System.println("agafonkin: approxTransit ds=" + ds);

        var m = solarMeanAnomaly(ds);
        var l = eclipticLongitude(m);
        var dec = declination(l, 0.0);

        System.println("agafonkin: solarMeanAnomaly  m=" + m );
        System.println("agafonkin: eclipticLongitude l=" + l );
        System.println("agafonkin: declination     dec=" + dec  );

        var Jnoon = solarTransitJ(ds, m, l);

        var angle_deg = -0.833;
        var h0 = (angle_deg + dh) * rad;
        var Jset = getSetJ(h0, lw, phi, dec, n, m, l);
        var Jrise = Jnoon - (Jset - Jnoon);

        System.println("agafonkin: Jset=" + Jset + " Jrise=" + Jrise + " Jnoon=" + Jnoon );

        var _TimeSet = fromJulian(Jset);
        var _TimeRise = fromJulian(Jrise);
        var _TimeNoon = fromJulian(Jnoon);

        System.println("agafonkin: _TimeSet=" + _TimeSet + " _TimeRise=" + _TimeRise + " _TimeNoon=" + _TimeNoon );
        System.println( PrintTime(_TimeRise, "agafonkin: _TimeRise: ") );
        System.println( PrintTime(_TimeNoon, "agafonkin: _TimeNoon: ") );
        System.println( PrintTime(_TimeSet, "agafonkin: _TimeSet: ") );

        // 
        System.println("======= COMPUTING SUN TRAJECTORY FOR THE WHOLE DAY :");
        var today = new Time.Moment(Time.today().value());
        var oneHour = new Time.Duration(Gregorian.SECONDS_PER_HOUR);
        var nextHour = today.add(oneHour);
        for( var i = 0; i < 24; i++ ) {
            var info = Gregorian.info(today, Time.FORMAT_MEDIUM);
            nextHour = today.add(oneHour);
            today = nextHour;
            var sunCoordLocal = new SunCoord_LocalPosition();
            sunCoordLocal = getPosition(today.value(), lat, lng);
            System.println("hour=" + info.hour + " az=" + sunCoordLocal.azimuth/rad + " alt=" + sunCoordLocal.altitude/rad + PrintTime(today.value(), " Time=") );
        }

        //////////////////////////////////
        //// HARALDH /////////////////////
        //////////////////////////////////


        // Kaster inn kode fra haraldh for å kontrollere mellomresultater
        // https://www.suncalc.org/#/59.8373,10.4602,12/2024.10.30/22:33/1/3
        // https://www.epochconverter.com/ 
        var PI = Math.PI;
        var RAD  = Math.PI / 180.0;
        var PI2  = Math.PI * 2.0;
        var DAYS = Time.Gregorian.SECONDS_PER_DAY;
        var J1970 = 2440588.0;
        var J2000 = 2451545.0;
        var J0 = 0.0009;
            
        var _now = Time.now();
        var _dateNow = new Time.Moment(_now.value() );
        var _date = _dateNow.value();
        var _lng = 10.460190 * RAD;
        var _lat = 59.837330 * RAD;
        System.println("haraldh: _date=" + _date + " _lat=" + _lat + " _lng=" + _lng);
        var _d = _dateNow.value().toDouble() / DAYS - 0.5 + J1970 - J2000;
        System.println("haraldh: _d=" + _d);
        var _n = round(_d - J0 + _lng / PI2);
        System.println("haraldh: _n=" + _n);
        var _ds = J0 - _lng / PI2 + _n.toDouble() - 1.1574e-5 * 68.0;
        // ds = 0.0009 - ( (0.182565) / (2*3.14159265359)) + 9074.000000 - (1.1574e-5 * 68.0) // OK!
        System.println("haraldh: _ds=" + _ds);
        var _M = 6.240059967 + 0.0172019715 * _ds;
        System.println("haraldh: _M=" + _M);
        var _sinM = Math.sin(_M);
        var _C = (1.9148 * _sinM + 0.02 * Math.sin(2 * _M) + 0.0003 * Math.sin(3 * _M)) * RAD;
        System.println("haraldh: _C=" + _C);
        var _L = _M + _C + 1.796593063 + PI;
        System.println("haraldh: _L=" + _L);
        var _sin2L = Math.sin(2 * _L);
        var _dec = Math.asin( 0.397783703 * Math.sin(_L) );
        System.println("haraldh: _dec=" + _dec);
        var _Jnoon = J2000.toDouble() + _ds + 0.0053 * _sinM - 0.0069 * _sin2L;
        System.println("haraldh: _Jnoon=" + _Jnoon );

        var _sunset = -0.833 * RAD;
        var _x = (Math.sin(_sunset) - Math.sin(_lat) * Math.sin(_dec)) / (Math.cos(_lat) * Math.cos(_dec));
        var __ds = J0 + (Math.acos(_x) - _lng) / PI2 + _n - 1.1574e-5 * 68;
        var _Jset = J2000.toDouble() + __ds + 0.0053 * _sinM - 0.0069 * _sin2L;
        
        var _Jrise = _Jnoon - (_Jset - _Jnoon);
        
        var _Noon = fromJulian(_Jnoon);
        var _Rise = fromJulian(_Jrise);
        var _Set = fromJulian(_Jset);

        System.println("haraldh: _Rise=" + _Rise  + " _Noon=" + _Noon + " _Set=" + _Set);
        System.println( PrintTime(_Rise, "haraldh: _Rise: ") );
        System.println( PrintTime(_Noon, "haraldh: _Noon: ") );
        System.println( PrintTime(_Set, "haraldh: _Set: ") );

        //////////////////////////////////
        //// WIKIPEDIA//////////////////// (https://en.wikipedia.org/wiki/Sunrise_equation)
        //////////////////////////////////

        var w_date = _date;
        var w_l_w = _lng;//Longitude
        var w_f = _lat;//Latitude
        var w_height = height;
        var w_J_date = w_date / 86400.0 + 2440587.5;
        System.println("wiki: J_date=" + w_J_date);
        // Julian date
        var w_n = round(w_J_date.toDouble() - (2451545.0 + 0.0009) + 69.184 / 86400.0);
        System.println("wiki: Julian date n=" + w_n);
        // Mean solar time
        var w_J_ = w_n + 0.0009 - w_l_w ;
        System.println("wiki: Mean solar time w_J_=" + w_J_);
        // Solar mean anomaly
        var M_degrees = Fmod(357.5291 + 0.98560028 * w_J_, 360);
        var M_radians = M_degrees * RAD;
        System.println("wiki: Solar mean anomaly M_degrees=" + M_degrees + " M_radians=" + M_radians);
        // Equation of the center
        var C_degrees = 1.9148 * Math.sin(M_radians) + 0.02 * Math.sin(2 * M_radians) + 0.0003 * Math.sin(3 * M_radians);
        var C_radians = C_degrees * RAD;
        System.println("wiki: Equation of the center C_degrees=" + C_degrees + " C_radians=" + C_radians);
        // Ecliptic longitude
        var L_degrees = Fmod(M_degrees + C_degrees + 180.0 + 102.9372, 360);
        var L_radians = L_degrees * RAD;
        System.println("wiki: Ecliptic longitude L_degrees=" + L_degrees + "  L_radians=" + L_radians);
        // Solar transit (julian date)
        var J_transit = 2451545.0 + w_J_ + 0.0053 * Math.sin(M_radians) - 0.0069 * Math.sin(2 * L_radians);
        var w_transit = fromJulian(J_transit);
        System.println("wiki: Solar transit J_transit=" + J_transit + " w_transit=" + w_transit);
        System.println( PrintTime(w_transit, "wiki: w_transit: ") );
        // Declination of the Sun
        var w_sin_d = Math.sin(L_radians) * Math.sin(23.4397*RAD);
        var w_cos_d = Math.cos(Math.asin(w_sin_d));
        // Hour angle
        var some_cos = (Math.sin((-0.833 - 2.076 * Math.sqrt(w_height) / 60.0)*RAD) - Math.sin(w_f*RAD) * w_sin_d) / (Math.cos(w_f*RAD) * w_cos_d);
        var w0_radians = Math.acos(some_cos);
        var w0_degrees = w0_radians/RAD;
        System.println("wiki: Hour angle w0_degrees=" + w0_degrees + " w0_radians=" + w0_radians);
        // Sunrise and Sunset
        var w_j_rise = J_transit - w0_degrees / 360;
        var w_j_set = J_transit + w0_degrees / 360;
        var w_rise = fromJulian(w_j_rise);
        var w_set = fromJulian(w_j_set);
        System.println("wiki: Sunrise w_rise=" + w_rise);
        System.println("wiki: Sunset w_set=" + w_set);
        System.println( PrintTime(w_rise, "wiki: w_rise: ") );
        System.println( PrintTime(w_transit, "wiki: w_transit: ") );
        System.println( PrintTime(w_set, "wiki: w_set: ") );

        return;
    }

    class SunCalc 
    {
        var _date = 0; // the date for which the calculations are to be made
        var _SunPos_azimuth  = 0;
        var _SunPos_altitude = 0;
        var _TimeSet  = 0;
        var _TimeRise = 0;
        var _TimeNoon = 0;

        function initialize() {
            
        }

        function SetDate(date as Time){
            _date = date;
        }

        // calculates sun position for a given date and latitude/longitude
        function getPosition(date, lat, lng)
        {
            var lw  = rad * -lng;
            var phi = rad * lat;
            var d   = toDays(date);

            // Calculate sunCoords
            var M = solarMeanAnomaly(d);
            var L = eclipticLongitude(M);

            var dec = declination(L, 0);
            var ra = rightAscension(L, 0);

            var H  = siderealTime(d, lw) - ra;

            _SunPos_azimuth = azimuth(H, phi, dec);
            _SunPos_altitude = altitude(H, phi, dec);

            return;
        }

        // calculates sun times for a given date, latitude/longitude, and, optionally,
        // the observer height (in meters) relative to the horizon
        // TODO - Make angle_deg as a enum (SUNRISE = -0.833)
        function getTimes(date, lat, lng, height, angle_deg){
            var lw  = rad * -lng;
            var phi = rad *  lat;

            var dh = observerAngle(height);

            var d = toDays(date);
            var n = julianCycle(d, lw);
            var ds = approxTransit(0.0, lw, n);

            var m = solarMeanAnomaly(ds);
            var l = eclipticLongitude(m);
            var dec = declination(l, 0.0);

            var Jnoon = solarTransitJ(ds, m, l);

            var h0 = (angle_deg + dh) * rad;
            var Jset = getSetJ(h0, lw, phi, dec, n, m, l);
            var Jrise = Jnoon - (Jset - Jnoon);

            _TimeSet = fromJulian(Jset);
            _TimeRise = fromJulian(Jrise);
            _TimeNoon = fromJulian(Jnoon);

            return _TimeNoon;
        }

        // calculates sun positions for evry hour a given date and latitude/longitude
        function getPositionForWholeDay(date, lat, lng)
        {
            //TODO
        }
    }
  
}