import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
using Toybox.Math;
import SunCalcModule;



//Index (Hour markers): Symbols, numbers, or dots/lines that indicate the hours around the clock face. These can be Arabic numerals (1, 2, 3...) or Roman numerals (I, II, III...) or simply markers.
//Hour hand: The shorter hand that points to the current hour.
//Minute hand: The longer hand that points to the minutes.
//Second hand: A thinner, usually longer hand that moves quickly to show seconds.
//Central axis (pinion/arbor): The center point where the hands are attached and rotate.
//Date window: A small window on the dial displaying the date. Not all watches have this feature.
//Subdials: Smaller dials within the main dial, often found on chronograph watches or multifunction watches. These may display additional functions like a stopwatch, seconds, or a second time zone.

//a class with functionality for drawing an analog clock face, such as clock hands
class UiAnalog {

    function drawSunArcOnPerimeter(dc as Dc, sunColor as Graphics.ColorType, sunTimes as solarTimes, nowHour) as Void {
        // Draw daytaime-arc
        dc.setPenWidth(1);
        dc.setColor(sunColor, sunColor);
        var solarRiseHour = SunCalcModule.LocaleTimeAsDesimalHour(sunTimes.solarRise); 
        var solarSetHour  = SunCalcModule.LocaleTimeAsDesimalHour(sunTimes.solarSet); 
        var degreeStart = solarRiseHour /24.0*360.0 -90;
        var degreeEnd = solarSetHour /24.0*360.0 -90; 

        dc.drawArc(dc.getWidth()/2, dc.getHeight()/2, dc.getWidth()/2, Graphics.ARC_COUNTER_CLOCKWISE , degreeStart, degreeEnd);

        //Draw sun on perimeter
        var offsetFromPerimeter = 5;
        var sunSize = 5;

        var coord = calcHour2clockCoord(dc , nowHour , offsetFromPerimeter) ;
        if ( (nowHour>solarRiseHour && nowHour<solarSetHour) ){
            dc.fillCircle(coord[0], coord[1], sunSize);
        }
        else {
            dc.drawCircle(coord[0], coord[1], sunSize);
        }

    }

    function drawArbor(dc as Dc){
        // Draw the arbor in the center of the screen.
        dc.setPenWidth(4);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.fillCircle(dc.getWidth() / 2, dc.getHeight() / 2, 7);
        dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK);
        dc.drawCircle(dc.getWidth() / 2, dc.getHeight() / 2, 7);
    }


    //Calcululate from 24hour to clock-coord on perimeter
    function calcHour2clockCoord(dc as Dc, desimal24hour as Lang.Double, offsetFromPerimeter as Lang.Numeric) as Point2D {
        var angleRad = (desimal24hour / 12.0 * Math.PI) - 3.0*Math.PI/2.0 ;
        var x = dc.getHeight()/2 + (dc.getHeight()/2 - offsetFromPerimeter)*Math.cos(angleRad);
        var y = dc.getWidth()/2  + (dc.getWidth()/2  - offsetFromPerimeter)*Math.sin(angleRad);
        
        var coord = [x, y] as Graphics.Point2D;

        return coord;
        //   o-----------------> 
        //   |\  angle       x
        //   | \
        //   |  \
        //   |   \
        //   V y
        //     
    }



    //! This function is used to generate the coordinates of the 4 corners of the polygon
    //! used to draw a watch hand. The coordinates are generated with specified length,
    //! tail length, and width and rotated around the center point at the provided angle.
    //! 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
    //! @param centerPoint The center of the clock
    //! @param angle Angle of the hand in radians
    //! @param handLength The length of the hand from the center to point
    //! @param tailLength The length of the tail of the hand
    //! @param width The width of the watch hand
    //! @return The coordinates of the watch hand
    function generateHandCoordinates(centerPoint as Array<Number>, angle as Float, handLength as Number, tailLength as Number, width as Number) as Array<[Numeric, Numeric]> {
        // Map out the coordinates of the watch hand
        var coords = [[-(width / 2), tailLength],
                      [-(width / 2), -handLength],
                      [width / 2, -handLength],
                      [width / 2, tailLength]];
        var result = new Array<[Numeric, Numeric]>[4];
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        // Transform the coordinates
        for (var i = 0; i < 4; i++) {
            var x = (coords[i][0] * cos) - (coords[i][1] * sin) + 0.5;
            var y = (coords[i][0] * sin) + (coords[i][1] * cos) + 0.5;

            result[i] = [centerPoint[0] + x, centerPoint[1] + y];
        }

        return result;
    }

    //! Draws the clock tick marks around the outside edges of the screen.
    //! @param dc Device context
    function drawIndex(dc as Dc, numberOfHashes as Lang.Numeric, hashLength as Lang.Numeric, penWidth as Lang.Numeric, hashColor as Graphics.ColorType) as Void {

        dc.setPenWidth(penWidth);
        dc.setColor(hashColor, hashColor);

        var outerRad = dc.getWidth() / 2;
        var innerRad = outerRad - hashLength;
        // Loop through each 1 minute block and draw tick marks.
        for (var i = 0; i <= 2 * Math.PI; i += (2.0 * Math.PI / numberOfHashes)) {
            // Partially unrolled loop to draw two tickmarks in 15 minute block.
            var sY = outerRad + innerRad * Math.sin(i);
            var eY = outerRad + outerRad * Math.sin(i);
            var sX = outerRad + innerRad * Math.cos(i);
            var eX = outerRad + outerRad * Math.cos(i);
            dc.drawLine(sX, sY, eX, eY);
        }
        
    }

    // Draw the 3, 6, 9, and 12 hour labels.
    public function drawIndexLabels(dc as Dc, font){
    var margin = 20;
        if (font != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, margin, font, "12", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(dc.getWidth() - margin, (dc.getHeight() / 2) - 12, font, "3", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - 30 - margin, font, "6", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(margin, (dc.getHeight() / 2) - 12, font, "9", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    public function drawPolygon(dc as Dc, points as Lang.Array<Graphics.Point2D>) as Void {
        if (points.size() > 2) {
            // Draw outline
            for (var i = 0; i < points.size(); i++) {
                var endX, endY;
                var startX = points[i][0];
                var startY = points[i][1];
                if (i < points.size()-1 ){
                    endX = points[i+1][0];
                    endY = points[i+1][1];
                }
                else{
                    endX = points[0][0];
                    endY = points[0][1];
                }
                dc.drawLine(startX, startY, endX, endY);
            }
        }   
    }

        //   o-----------------> x
        //   |        |   P
        //   |        |az/
        //   |        | /alt
        //   |        |/
        //   |        O   
        //   |
        //   |
        //   V
        //            O: [w/2 , h/2]
        //            P: [w/2 + alt*sin(az), h/2 - alt*cos(az)]
    public function convertPolarToScreenCoord(dc as Dc, posPolar as SunCalcModule.SunCoord_LocalPosition) as Graphics.Point2D{
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        var az = posPolar.azimuth;
        var alt = posPolar.altitude;
        var theta = (az) * Math.PI / 180.0; //RAD
        var r = (90.0-alt)/90.0 * width/2.0;
        var x = width/2 + r*Math.sin(theta);
        var y = height/2 - r*Math.cos(theta);
        var point = [x, y] as Graphics.Point2D;
        return point;
    }

    public function drawPolygonSkyView(dc as Dc, pointsPolar as Array<SunCalcModule.SunCoord_LocalPosition>) as Void {
        if (pointsPolar.size() > 2) {
            // Draw outline
            var posPolar = new SunCalcModule.SunCoord_LocalPosition();
            var startX=0;
            var startY=0;
            var endX=0;
            var endY=0;
            for (var i = 0; i < pointsPolar.size(); i++) {
                posPolar = pointsPolar[i];
                var pointXY = convertPolarToScreenCoord(dc , posPolar);
                startX = pointXY[0];
                startY = pointXY[1];

                //DEBUG
                System.println("i=" + i + " az=" + posPolar.azimuth.format("%.4f") + " alt=" + posPolar.altitude.format("%.4f"));
                
                if (i < pointsPolar.size()-1 ){
                    posPolar = pointsPolar[i+1];
                    pointXY = convertPolarToScreenCoord(dc , posPolar);
                    endX = pointXY[0];
                    endY = pointXY[1];
                }
                else{
                    posPolar = pointsPolar[0];
                    pointXY = convertPolarToScreenCoord(dc , posPolar);
                    endX = pointXY[0];
                    endY = pointXY[1];
                }                
                
                dc.drawLine(startX, startY, endX, endY);
            
                startX=endX;
                startY=endY;
            }
        }
        return;   
    }

    //! Draw the date string into the provided buffer at the specified location
    //! @param dc Device context
    //! @param x The x location of the text
    //! @param y The y location of the text
    function drawString(dc as Dc, x as Number, y as Number, str as String, font as Graphics.FontType) as Void {
        dc.drawText(x, y, font, str, Graphics.TEXT_JUSTIFY_CENTER);
    }


    //! Draw the date string into the provided buffer at the specified location
    //! @param dc Device context
    //! @param x The x location of the text
    //! @param y The y location of the text
    function drawDateString(dc as Dc, x as Number, y as Number, font as Graphics.FontType) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);

        drawString(dc, x , y , dateStr, font);
    }

}
