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
            var polarPhenomena = 0; //0=normal, 1=midnight sun, 2=Polar Night
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
        NIGHTEND,          //The moment when the sky starts to lighten, marking the end of astronomical night
        NAUTICALDAWN,      //The beginning of nautical twilight, where the horizon is faintly visible at sea.
        DAWN,               //The start of civil twilight when the sky is bright enough for most outdoor activities without artificial light
        SUNRISE,          //The moment the sun's upper edge becomes visible above the horizon.
        SUNRISEEND ,         //The time at which the full disk of the sun is above the horizon
        GOLDENHOUREND ,       //The time when the "golden hour" ends in the morning, which is a period of soft, warm light ideal for photography
        GOLDENHOUR ,         //A period shortly after sunrise or before sunset with soft, diffused light
        SUNSETSTART ,         //The time when the sun starts to touch the horizon as it sets.
        SUNSET ,            //The moment the sun's upper edge dips below the horizon.
        DUSK  ,                //The end of civil twilight, when it is too dark to see clearly without artificial light.
        NAUTICALDUSK ,       //The end of nautical twilight, where the horizon becomes indistinguishable at sea.
        NIGHT                  //Begins after astronomical dusk when the sky is completely dark.
        }



    // calculations for sun times
    const J0 = 0.0009;

    function julianCycle(d, lw) { return round(d - J0 - lw / (2.0 * Math.PI)); }

    function approxTransit(Ht, lw, n) { return J0 + ((Ht.toDouble() + lw.toDouble()) / (2.0 * Math.PI)) + n.toDouble()  - 1.1574e-5 * 68.0; } //SW!!!!!
    function solarTransitJ(ds, M, L)  { return J2000.toDouble() + ds + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2.0 * L); }

 //   function hourAngle(h, phi, d) { return Math.acos((Math.sin(h) - Math.sin(phi) * Math.sin(d)) / (Math.cos(phi) * Math.cos(d))); }
    function hourAngle(h, phi, d) {
        var teller = (Math.sin(h) - Math.sin(phi) * Math.sin(d));
        var nevner = (Math.cos(phi) * Math.cos(d));
        var cosLHA = teller / nevner;
        if (cosLHA<-1.0000001){
            System.println("midnight sun");
            // TODO - midnight sun: Sun is always above our altitude limit 
        }
        if (cosLHA>1.0000001){
            System.println("polar niht");
            // TODO - polar niht: Sun is always below our altitude limit
        }

        var hourAngle = Math.acos(cosLHA); 
        return hourAngle; 
    }
    function observerAngle(height) { return -2.076 * Math.sqrt(height) / 60; }

    // returns set time for the given sun altitude
    function getSetJ(h, lw, phi, dec, n, M, L) {

        var w = hourAngle(h, phi, dec);
        var a = approxTransit(w, lw, n);

        return solarTransitJ(a, M, L);
    }


    // calculates sun times for a given date, latitude/longitude, and, optionally,
    // the observer height (in meters) relative to the horizon
    function getTimes(date as Number, lat as Number, lng as Number, height as Number?, angle_deg) as solarTimes {
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

//DEBUG
//      System.println("getTimes: " + "M=" + M + "L=" + L + "dec=" + dec + "Jnoon=" + Jnoon);

        var h0 = (angle_deg + dh) * RAD;
        var Jset = getSetJ(h0, lw, phi, dec, n, M, L);
        var Jrise = Jnoon - (Jset - Jnoon);

        var Times = new solarTimes();
        
        Times.solarSet = fromJulian(Jset);
        Times.solarRise = fromJulian(Jrise);
        Times.solarNoon = fromJulian(Jnoon);

        //DEBUG
          System.println("getTimes: " + " angle_deg=" + angle_deg + " Jset=" + Jset + " solarSet=" + Times.solarSet + " time=" + PrintLocaleTime(Jset) );
//        System.println("Jset=" + Jset + " solarSet=" + Times.solarSet + " time=" + PrintLocaleTime(Times.solarSet) );

        return Times;
    }

//////////////////////////////////////////// END OF Agafonkins code ////////////////// 

    // calculates sun position through the day for a given date and latitude/longitude
    function getSunPositionForDay(date as Number, lat as Double, lng as Double) as Array<SunCoord_LocalPosition> {
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
            //System.println("zi=" + i + " time=" + PrintLocaleTime(time_i.value()) + " az=" + az.format("%.4f")+ " alt=" + alt.format("%.4f"));
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


/////////////////////////////////////////////////////////////////////////////////////////////////////////////



    class sunCalc
    {
        private var _lat = 0.0 as Double;
        private var _lon = 0.0 as Double;
        private var _height = 0.0 as Double;
        private var _knownPosition = false as Boolean;
        private var _knownDate = false as Boolean;
        private var _date;
        private var _solarEventsCalculated = false as Boolean;
        public var solarNoon;
        public var polarPhenomena as Number; //0=normal, 1=midnight sun, 2=Polar Night

        // 12 solar events, each with 
        // [i][0] angle in degrees
        // [i][1] name of rise-event
        // [i][2] time of rise-event
        // [i][3] name of set-event
        // [i][4] time of set-event
        const solarEvents =  [                
            [-0.833d, "sunrise",       0.0d, "sunset",        0.0d ], //[0] Sun's upper limb touches the horizon; atmospheric refraction accounted for
            [  -0.3d, "sunriseEnd",    0.0d, "sunsetStart",   0.0d ],
            [  -6.0d, "dawn",          0.0d, "dusk",          0.0d ], //[2] Civil twilight (one can no longer read outside without artificial illumination)
            [ -12.0d, "nauticalDawn",  0.0d, "nauticalDusk",  0.0d ], //[3] Nautical twilight (the horizon is still visible at sea)
            [ -18.0d, "nightEnd",      0.0d, "night",         0.0d ], //[4] Astronomical twilight (the sky is completely dark)
            [   6.0d, "goldenHourEnd", 0.0d, "goldenHour",    0.0d ]
        ];

        public function initialize() {
            _lat = 0.0;
            _lon = 0.0;
            _height = 0.0;
            _knownPosition = false;
            _date = 0.0;
            _knownDate = false;
            polarPhenomena = 0; 
            _solarEventsCalculated = false;
        }

        public function setPosition(latitude as Double, longitude as Double) {
            _lat = latitude;
            _lon = longitude;
            _knownPosition = true;
            _solarEventsCalculated = false;
        }

        public function getKnownPosition() as Boolean {
            return _knownPosition;
        }      

        public function setDate(date as Number) {
            _date = date;
            _knownDate = true;
            _solarEventsCalculated = false;
        }

        public function calcSolarEvents() as Boolean {
            if (!_knownPosition || !_knownDate) {
                return false;
            }
            if (_solarEventsCalculated) {
                return true;
            }

            var lw  = RAD * -_lon;
            var phi = RAD *  _lat;

            var dh = observerAngle(_height);

            var d = toDays(_date);
            var n = julianCycle(d, lw);
            var ds = approxTransit(0.0, lw, n);

            var M = solarMeanAnomaly(ds);
            var L = eclipticLongitude(M);
            var dec = declination(L, 0.0);

            var Jnoon = solarTransitJ(ds, M, L);
            solarNoon = fromJulian(Jnoon);

//            System.println("calcSolarEvents:" + "M=" + M + "L=" + L + "dec=" + dec + "Jnoon=" + Jnoon);

            for (var i=0; i<6; i+=1){
                var angle_deg = solarEvents[i][0] as Double;

                var h0 = (angle_deg + dh) * RAD;
                var Jset = getSetJ_PP(h0, lw, phi, dec, n, M, L);
                var Jrise = Jnoon - (Jset - Jnoon);

                solarEvents[i][4] = fromJulian(Jset);
                solarEvents[i][2] = fromJulian(Jrise);

                //DEBUG
                System.println("calcSolarEvents:" + "i=" + i + " angle_deg=" + solarEvents[i][0] + " SetName=" + solarEvents[i][1] + " Settime=" + solarEvents[i][2] + " SetTime=" + PrintLocaleTime(solarEvents[i][2])+ " RiseName=" + solarEvents[i][3] + " Risetime=" + solarEvents[i][4] + " RiseTime=" + PrintLocaleTime(solarEvents[i][4]) );

            }
            _solarEventsCalculated = true;
            return true;
        }

        public function getTimeOfSolarEvent(solarEvent as solarEvent_enum) as Double{
            var time = 0.0 as Double;

            if (!_solarEventsCalculated) {
                calcSolarEvents();
            }
            if (!_solarEventsCalculated) {
                return time;
            }

            switch (solarEvent) {
                case SUNRISE:
                    time = solarEvents[0][2] as Double;
                    break;
                case SUNSET:
                    time = solarEvents[0][4] as Double;
                    break;
                case DAWN:
                    time = solarEvents[2][2] as Double;
                    break;
                case DUSK:
                    time = solarEvents[2][4] as Double;
                    break;
                //TODO: add more cases
                default:
                    time = 0.0;
                    break;
            }
            return time;
        }

        // calculates sun position through the day for a given date and latitude/longitude
        // mode = 0: sun position relative to clock time ([0] = 12:00) (default)
        // mode = 1: sun position relative to solar time ([0] = solar noon)
        public function getSunTrajectoryForDay(mode) as Array<SunCoord_LocalPosition> or Null{
            if (_knownPosition && _knownDate) {
                var sunCoordLocal = new SunCoord_LocalPosition();
                var result = new Array<SunCoord_LocalPosition>[24];

                var Moment = new Time.Moment(_date);
                var infoDate = Gregorian.info(Moment, Time.FORMAT_SHORT);

                // Get daylight savings offset
                var where = new Position.Location({:latitude  => _lat,  :longitude => _lon, :format    => :degrees });
                var local = Gregorian.localMoment(where, _date);
                var offset = local.getDaylightSavingsTimeOffset()/3600.0;
                
                // Find start time for i=0
                var hour = 12;
                var minute = 0;
                var azCorr = 0.0;
                if (mode==1){
                    var solarNoonDesimal = LocaleTimeAsDesimalHour(solarNoon);
                    var solarNoonHour = Math.floor(solarNoonDesimal);
                    var solarNoonMinute = Math.round((solarNoonDesimal - solarNoonHour) * 60.0);
                    hour = solarNoonHour-offset;
                    minute = solarNoonMinute;
                    azCorr = (solarNoonDesimal-12.0)/12.0*180.0;
                } else {
                    hour = 12-offset;
                    minute = 0;
                }   

                // Loop for every hour through the day 
                for (var i = 0; i <= 23; i += 1) {
                    
                    var options = {
                        :year   => infoDate.year,
                        :month  => infoDate.month,
                        :day    => infoDate.day,
                        :hour   => hour,
                        :minute => minute
                    };

                    var time_i = Gregorian.moment(options);
                    sunCoordLocal = getPosition(time_i.value(), _lat, _lon);
                    var az = sunCoordLocal.azimuth ;
                    var alt = sunCoordLocal.altitude ;  

                    az = az + azCorr;            
                    
                    var resultAA = new SunCoord_LocalPosition();
                    resultAA.azimuth = az; 
                    resultAA.altitude = alt;
                    result[i] = resultAA;

                    //DEBUG
                    //System.println("zi=" + i + " time=" + PrintLocaleTime(time_i.value()) + " az=" + az.format("%.4f")+ " alt=" + alt.format("%.4f"));

                    hour += 1;
                    if (hour>23){
                        hour = 0;
                    }

                }        
                return result;
            }
            return null;
        }

        public function getSunPosition() as SunCoord_LocalPosition or Null{
            if (_knownPosition && _knownDate) {
                var sunCoordLocal = new SunCoord_LocalPosition();
                var sunCoordSphere = new SunCoord_CelestialSphere();
                var lw  = RAD * -_lon;
                var phi = RAD * _lat;
                var d   = toDays(_date);

                sunCoordSphere = sunCoords(d);
                var H  = siderealTime(d, lw) - sunCoordSphere.rightAscension;

                sunCoordLocal.azimuth = azimuth(H, phi, sunCoordSphere.declination)/RAD;
                sunCoordLocal.altitude = altitude(H, phi, sunCoordSphere.declination)/RAD;

                return sunCoordLocal;
            }
            return null;
        }

        // returns set time for the given sun altitude
        private function getSetJ_PP(h, lw, phi, dec, n, M, L) {

            var w = hourAngle_PP(h, phi, dec);
            var a = approxTransit(w, lw, n);

            return solarTransitJ(a, M, L);
        }

        private function hourAngle_PP(h, phi, d) {
            var cosLHA = ((Math.sin(h) - Math.sin(phi) * Math.sin(d)))/(Math.cos(phi) * Math.cos(d));
            if (cosLHA<-1.0000001){
                System.println("midnight sun");
                // midnight sun: Sun is always above our altitude limit
                polarPhenomena = 1; //midnight sun
            }
            else if (cosLHA>1.0000001){
                System.println("polar niht");
                // polar niht: Sun is always below our altitude limit
                polarPhenomena = 2; //polar niht
            }
            else {
                polarPhenomena = 0; //normal
            }

            var hourAngle = Math.acos(cosLHA);

            return hourAngle; 
        }
    }

}