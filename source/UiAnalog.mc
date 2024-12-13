import Toybox.System;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
using Toybox.Math;
import SunCalcModule;

//a class with functionality for drawing an analog clock face, such as clock hands

//Index (Hour markers): Symbols, numbers, or dots/lines that indicate the hours around the clock face. These can be Arabic numerals (1, 2, 3...) or Roman numerals (I, II, III...) or simply markers.
//Hour hand: The shorter hand that points to the current hour.
//Minute hand: The longer hand that points to the minutes.
//Second hand: A thinner, usually longer hand that moves quickly to show seconds.
//Central axis (pinion/arbor): The center point where the hands are attached and rotate.
//Date window: A small window on the dial displaying the date. Not all watches have this feature.
//Subdials: Smaller dials within the main dial, often found on chronograph watches or multifunction watches. These may display additional functions like a stopwatch, seconds, or a second time zone.

class UiAnalog {

    function drawSunArcOnPerimeter(dc as Dc, sunColor as Graphics.ColorType, sunTimes as solarTimes, nowHour){
        // Draw daytaime-arc
        dc.setPenWidth(3);
        dc.setColor(sunColor, sunColor);
        var solarRiseHour = SunCalcModule.LocaleTimeAsDesimalHour(sunTimes.solarRise); 
        var solarSetHour  = SunCalcModule.LocaleTimeAsDesimalHour(sunTimes.solarSet); 
        var degreeStart = solarRiseHour /24.0*360.0 -90;
        var degreeEnd = solarSetHour /24.0*360.0 -90; 
        dc.drawArc(dc.getWidth()/2, dc.getHeight()/2, dc.getWidth()/2, Graphics.ARC_COUNTER_CLOCKWISE , degreeStart, degreeEnd);

        //Draw sun
        var coord = new Array<Double>[2];        
        var offsetFromPerimeter = 4;
        var sunSize = 5;

        coord = calcHour2clockCoord(dc , nowHour , offsetFromPerimeter) as Array<Double>;

        if ( (nowHour>solarRiseHour && nowHour<solarSetHour) ){
            var x = coord[0];
            var y = coord[1];
            dc.fillCircle(x, y, sunSize);
        }
        else {
            dc.drawCircle(coord[0], coord[1], sunSize);
        }

    }

    function drawArbor(dc as Dc){
        // Draw the arbor in the center of the screen.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.fillCircle(dc.getWidth() / 2, dc.getHeight() / 2, 7);
        dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK);
        dc.drawCircle(dc.getWidth() / 2, dc.getHeight() / 2, 7);
    }


    //Calcululate from 24hour to clock-coord on perimeter
    function calcHour2clockCoord(dc as Dc, desimal24hour as Lang.Double, offsetFromPerimeter as Lang.Numeric){
        var angleRad = (desimal24hour / 12.0 * Math.PI) - 3.0*Math.PI/2.0 ;
        var x = dc.getHeight()/2 + (dc.getHeight()/2 - offsetFromPerimeter)*Math.cos(angleRad);
        var y = dc.getWidth()/2  + (dc.getWidth()/2  - offsetFromPerimeter)*Math.sin(angleRad);
        
        var coord = new Array<Double>[2];        
        
        coord[0]=x;
        coord[1]=y;

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
        
        if (font != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, 2, font, "12", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(dc.getWidth() - 2, (dc.getHeight() / 2) - 15, font, "3", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() - 30, font, "6", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(2, (dc.getHeight() / 2) - 15, font, "9", Graphics.TEXT_JUSTIFY_LEFT);
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
