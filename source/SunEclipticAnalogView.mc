//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
// Sun

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import SunCalcModule;
using Toybox.Activity;

//! This implements an analog watch face
//! Original design by Austen Harbour
class SunEclipticAnalogView extends WatchUi.WatchFace {
    private var _font as FontResource?;
    private var _isAwake as Boolean?;
    private var _screenShape as ScreenShape;
    private var _dndIcon as BitmapResource?;
    private var _offscreenBuffer as BufferedBitmap?;
    private var _dateBuffer as BufferedBitmap?;
    private var _screenCenterPoint as Array<Number>?;
    private var _fullScreenRefresh as Boolean;
    private var _partialUpdatesAllowed as Boolean;
    private var SECOND_HAND_LENGTH = 110;//TODO: CALCULATE POSSIBLE HAND-LENGTH
    private var MINUTE_HAND_LENGTH = 90; 
    private var HOUR_HAND_LENGTH = 60; 


    //! Initialize variables for this view
    public function initialize() {
        WatchFace.initialize();
        _screenShape = System.getDeviceSettings().screenShape;
        _fullScreenRefresh = true;
        _partialUpdatesAllowed = (WatchUi.WatchFace has :onPartialUpdate);

        System.println("::initialize");

    }

    //! Configure the layout of the watchface for this device
    //! @param dc Device context
    public function onLayout(dc as Dc) as Void {

        SECOND_HAND_LENGTH = dc.getHeight() / 1.2;
        MINUTE_HAND_LENGTH = dc.getHeight() / 2.9;

        // Load the custom font we use for drawing the 3, 6, 9, and 12 on the watchface.
        _font = WatchUi.loadResource($.Rez.Fonts.id_font_black_diamond) as FontResource;

        // If this device supports the Do Not Disturb feature,
        // load the associated Icon into memory.
        if (System.getDeviceSettings() has :doNotDisturb) {
            _dndIcon = WatchUi.loadResource($.Rez.Drawables.DoNotDisturbIcon) as BitmapResource;
        } else {
            _dndIcon = null;
        }

        var offscreenBufferOptions = {
                :width=>dc.getWidth(),
                :height=>dc.getHeight(),
                :palette=> [
                    Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_LT_GRAY,
                    Graphics.COLOR_BLACK,
                    Graphics.COLOR_WHITE
                ]
            };

        var dateBufferOptions = {
                :width=>dc.getWidth(),
                :height=>Graphics.getFontHeight(Graphics.FONT_MEDIUM)
            };

        if (Graphics has :createBufferedBitmap) {
            // get() used to return resource as Graphics.BufferedBitmap
            _offscreenBuffer = Graphics.createBufferedBitmap(offscreenBufferOptions).get() as BufferedBitmap;

            _dateBuffer = Graphics.createBufferedBitmap(dateBufferOptions).get() as BufferedBitmap;
        } else if (Graphics has :BufferedBitmap) { // If this device supports BufferedBitmap, allocate the buffers we use for drawing
            // Allocate a full screen size buffer with a palette of only 4 colors to draw
            // the background image of the watchface.  This is used to facilitate blanking
            // the second hand during partial updates of the display
            _offscreenBuffer = new Graphics.BufferedBitmap(offscreenBufferOptions);

            // Allocate a buffer tall enough to draw the date into the full width of the
            // screen. This buffer is also used for blanking the second hand. This full
            // color buffer is needed because anti-aliased fonts cannot be drawn into
            // a buffer with a reduced color palette
            _dateBuffer = new Graphics.BufferedBitmap(dateBufferOptions);
        } else {
            _offscreenBuffer = null;
            _dateBuffer = null;
        }

        _screenCenterPoint = [dc.getWidth() / 2, dc.getHeight() / 2];
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
    private function generateHandCoordinates(centerPoint as Array<Number>, angle as Float, handLength as Number, tailLength as Number, width as Number) as Array<[Numeric, Numeric]> {
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
    private function drawHashMarks(dc as Dc, numberOfHashes as Lang.Numeric, hashLength as Lang.Numeric, penWidth as Lang.Numeric, hashColor as Graphics.ColorType) as Void {

        dc.setPenWidth(penWidth);
        dc.setColor(hashColor, hashColor);

        // Draw hashmarks differently depending on screen geometry.
        if (System.SCREEN_SHAPE_ROUND == _screenShape) {
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
    }

    //Calcululate from 24hour to clock-coord on perimeter
    private function Hour2clockCoord(dc as Dc, desimal24hour as Lang.Double, offsetFromPerimeter as Lang.Numeric){
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

    private function drawSun(dc as Dc) as Void {
        var dataString;
       
        // TODO - Draw sun to background
        var today = Time.today();
        var now = Time.now();
        var momentNow = new Time.Moment(now.value() );        
        // for testing now = new Time.Moment(1483225200);
        var moment = new Time.Moment(now.value() * Time.Gregorian.SECONDS_PER_DAY);
        var days = ((moment.value() - today.value()) / Time.Gregorian.SECONDS_PER_DAY).toNumber();

        var sunTimes = new solarTimes();
        var lat = 59.837330;
        var lng = 10.460190;
        var altitude = 0.0;
        var angle_deg = -0.833;

        var activityInfo = Activity.getActivityInfo();
        var location = activityInfo.currentLocation;
        if (location!=null){
            lat = location[0];
            lng = location[1];
            altitude = activityInfo.altitude;
        }


// TODO
/*
using Toybox.Position;
using Toybox.System;
Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));

function onPosition(info) {
    var myLocation = info.position.toRadians();
    System.println(myLocation[0]); // latitude (e.g. 0.678197)
    System.println(myLocation[1]); // longitude (e.g -1.654588)
}

=========== OR =================

        location = activityInfo.currentLocation;
        if (location) {
            location = activityInfo.currentLocation.toRadians();
            app.Storage.setValue("location", location);
        } else {
            location = app.Storage.getValue("location");
        }
        if (location!=null){
            suncalc.xxx;
        }

*/

        sunTimes = SunCalcModule.getTimes(momentNow.value(), lat, lng, altitude, angle_deg);
//        System.println( SunCalcModule.PrintTime(sunTimes.solarRise, "Sun Rise: ") );
//        System.println( SunCalcModule.PrintTime(sunTimes.solarNoon, "Sun Noon: ") );
//        System.println( SunCalcModule.PrintTime(sunTimes.solarSet, "Sun Set: ") ); 

        dataString = SunCalcModule.PrintLocaleTime(sunTimes.solarRise);
        drawString(dc, dc.getWidth() / 2, 5*dc.getHeight() / 10, dataString);
        dataString = SunCalcModule.PrintLocaleTime(sunTimes.solarNoon);
        drawString(dc, dc.getWidth() / 2, 6*dc.getHeight() / 10, dataString);
        dataString = SunCalcModule.PrintLocaleTime(sunTimes.solarSet);
        drawString(dc, dc.getWidth() / 2, 7*dc.getHeight() / 10, dataString);

        var solarRiseHour = SunCalcModule.LocaleTimeAsDesimalHour(sunTimes.solarRise); 
        var solarSetHour  = SunCalcModule.LocaleTimeAsDesimalHour(sunTimes.solarSet); 

        // Draw daytaime-arc
        dc.setPenWidth(3);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_YELLOW);
        var degreeStart = solarRiseHour /24.0*360.0 -90;
        var degreeEnd = solarSetHour /24.0*360.0 -90; 
        dc.drawArc(dc.getWidth()/2, dc.getHeight()/2, dc.getWidth()/2-1, Graphics.ARC_COUNTER_CLOCKWISE , degreeStart, degreeEnd);

        //Draw sun
        var coord;
        var nowHour = 5.0;
        var offsetFromPerimeter = 5;
        var sunSize = 10;
        nowHour = SunCalcModule.LocaleTimeAsDesimalHour(momentNow.value()); 
        coord = Hour2clockCoord(dc , nowHour , offsetFromPerimeter);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_YELLOW);
        if ( (nowHour>solarRiseHour && nowHour<solarSetHour) ){
            dc.fillCircle(coord[0], coord[1], sunSize);
        }
        else {
            dc.drawCircle(coord[0], coord[1], sunSize);
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

    //! Handle the update event
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var targetDc = null;

        System.println("::onUpdate");

        // We always want to refresh the full screen when we get a regular onUpdate call.
        _fullScreenRefresh = true;
        if (null != _offscreenBuffer) {
            // If we have an offscreen buffer that we are using to draw the background,
            // set the draw context of that buffer as our target.
            targetDc = _offscreenBuffer.getDc();
            dc.clearClip();
        } else {
            targetDc = dc;
        }

        var width = targetDc.getWidth();
        var height = targetDc.getHeight();

        // Fill the entire background with Black.
        targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        targetDc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());
/*
        // Draw a grey triangle over the upper right half of the screen.
        targetDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
        targetDc.fillPolygon([[0, 0],[targetDc.getWidth(), 0],[targetDc.getWidth(), targetDc.getHeight()],[0, 0]]);
*/
        // Draw the tick marks around the edges of the screen
        drawHashMarks(targetDc, 12, 20, 3, Graphics.COLOR_WHITE);  //12 Houre marks
        drawHashMarks(targetDc, 60, 8, 1, Graphics.COLOR_LT_GRAY); //60 Minute marks
        //drawHashMarks(targetDc, 24, 3, 3, Graphics.COLOR_BLUE);  //24 Houre (sun) marks

        // Draw the do-not-disturb icon if we support it and the setting is enabled
        if (System.getDeviceSettings().doNotDisturb && (null != _dndIcon)) {
            targetDc.drawBitmap(width * 0.75, height / 2 - 15, _dndIcon);
        }

        // Use white to draw the hour and minute hands
        targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (_screenCenterPoint != null) {
            // Draw the hour hand. Convert it to minutes and compute the angle.
            var hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min);
            hourHandAngle = hourHandAngle / (12 * 60.0);
            hourHandAngle = hourHandAngle * Math.PI * 2;
            targetDc.fillPolygon(generateHandCoordinates(_screenCenterPoint, hourHandAngle, HOUR_HAND_LENGTH/2.5, 0, dc.getWidth() / 30));
            drawPolygon(targetDc, generateHandCoordinates(_screenCenterPoint, hourHandAngle, HOUR_HAND_LENGTH, 0, dc.getWidth() / 30));
            System.println("draw hour hand");
        }

        if (_screenCenterPoint != null) {
            // Draw the minute hand.
            var minuteHandAngle = (clockTime.min / 60.0) * Math.PI * 2;
            targetDc.fillPolygon(generateHandCoordinates(_screenCenterPoint, minuteHandAngle, MINUTE_HAND_LENGTH/2.5, 0, dc.getWidth() / 40));
            drawPolygon(targetDc, generateHandCoordinates(_screenCenterPoint, minuteHandAngle, MINUTE_HAND_LENGTH, 0, dc.getWidth() / 40));
            System.println("draw minute hand");
        }

        // Draw the arbor in the center of the screen.
        targetDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        targetDc.fillCircle(width / 2, height / 2, 7);
        targetDc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK);
        targetDc.drawCircle(width / 2, height / 2, 7);

        // Draw the 3, 6, 9, and 12 hour labels.
        var font = _font;
        if (font != null) {
            targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            targetDc.drawText(width / 2, 2, font, "12", Graphics.TEXT_JUSTIFY_CENTER);
            targetDc.drawText(width - 2, (height / 2) - 15, font, "3", Graphics.TEXT_JUSTIFY_RIGHT);
            targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            targetDc.drawText(width / 2, height - 30, font, "6", Graphics.TEXT_JUSTIFY_CENTER);
            targetDc.drawText(2, (height / 2) - 15, font, "9", Graphics.TEXT_JUSTIFY_LEFT);
        }

        // If we have an offscreen buffer that we are using for the date string,
        // Draw the date into it. If we do not, the date will get drawn every update
        // after blanking the second hand.
        var offscreenBuffer = _offscreenBuffer;
        if ((null != _dateBuffer) && (null != offscreenBuffer)) {
            var dateDc = _dateBuffer.getDc();

            // Draw the background image buffer into the date buffer to set the background
            dateDc.drawBitmap(0, -(height / 4), offscreenBuffer);

            // Draw the date string into the buffer.
            drawDateString(dateDc, width / 2, 0);
        }

        // Output the offscreen buffers to the main display if required.
        drawBackground(dc);

        //Draw sun-info
        drawSun(dc);        

        // Draw the battery percentage directly to the main screen.
        var dataString = (System.getSystemStats().battery + 0.5).toNumber().toString() + "%";
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2,  7*height / 20, Graphics.FONT_XTINY, dataString, Graphics.TEXT_JUSTIFY_CENTER);

        if (_partialUpdatesAllowed) {
            // If this device supports partial updates and they are currently
            // allowed run the onPartialUpdate method to draw the second hand.
            onPartialUpdate(dc);
        } else if (_isAwake) {
            // Otherwise, if we are out of sleep mode, draw the second hand
            // directly in the full update method.
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            var secondHand = (clockTime.sec / 60.0) * Math.PI * 2;

            if (_screenCenterPoint != null) {
                dc.fillPolygon(generateHandCoordinates(_screenCenterPoint, secondHand, SECOND_HAND_LENGTH, 20, dc.getWidth() / 120));
                System.println("draw second hand");
            }
        }

        _fullScreenRefresh = false;
    }

    //! Draw the date string into the provided buffer at the specified location
    //! @param dc Device context
    //! @param x The x location of the text
    //! @param y The y location of the text
    private function drawDateString(dc as Dc, x as Number, y as Number) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);

        drawString(dc, x , y , dateStr);
        //dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        //dc.drawText(x, y, Graphics.FONT_MEDIUM, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Draw the date string into the provided buffer at the specified location
    //! @param dc Device context
    //! @param x The x location of the text
    //! @param y The y location of the text
    private function drawString(dc as Dc, x as Number, y as Number, str as String) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_SYSTEM_XTINY, str, Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    //! Handle the partial update event
    //! @param dc Device context
    public function onPartialUpdate(dc as Dc) as Void {
        // If we're not doing a full screen refresh we need to re-draw the background
        // before drawing the updated second hand position. Note this will only re-draw
        // the background in the area specified by the previously computed clipping region.
        System.println("::onPartialUpdate");

        if (!_fullScreenRefresh) {
            drawBackground(dc);
        }

        var clockTime = System.getClockTime();

        if (_screenCenterPoint != null) {
            var secondHand = (clockTime.sec / 60.0) * Math.PI * 2;
            var secondHandPoints = generateHandCoordinates(_screenCenterPoint, secondHand, SECOND_HAND_LENGTH, 20, dc.getWidth() / 120);
            // Update the clipping rectangle to the new location of the second hand.
            var curClip = getBoundingBox(secondHandPoints);
            var bBoxWidth = curClip[1][0] - curClip[0][0] + 1;
            var bBoxHeight = curClip[1][1] - curClip[0][1] + 1;
            dc.setClip(curClip[0][0], curClip[0][1], bBoxWidth, bBoxHeight);

            // Draw the second hand to the screen.
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(secondHandPoints);
            System.println("draw second hand");      
        }
    }

    //! Compute a bounding box from the passed in points
    //! @param points Points to include in bounding box
    //! @return The bounding box points
    private function getBoundingBox(points as Array<[Numeric, Numeric]>) as Array<[Numeric, Numeric]> {
        var min = [9999, 9999];
        var max = [0,0];

        for (var i = 0; i < points.size(); ++i) {
            if (points[i][0] < min[0]) {
                min[0] = points[i][0];
            }

            if (points[i][1] < min[1]) {
                min[1] = points[i][1];
            }

            if (points[i][0] > max[0]) {
                max[0] = points[i][0];
            }

            if (points[i][1] > max[1]) {
                max[1] = points[i][1];
            }
        }

        return [min, max];
    }

    //! Draw the watch face background
    //! onUpdate uses this method to transfer newly rendered Buffered Bitmaps
    //! to the main display.
    //! onPartialUpdate uses this to blank the second hand from the previous
    //! second before outputting the new one.
    //! @param dc Device context
    private function drawBackground(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        System.println("::drawBackground");

        // If we have an offscreen buffer that has been written to
        // draw it to the screen.
        if (null != _offscreenBuffer) {
            dc.drawBitmap(0, 0, _offscreenBuffer);
        }

        // Draw the date
        if (null != _dateBuffer) {
            // If the date is saved in a Buffered Bitmap, just copy it from there.
            dc.drawBitmap(0, height / 4, _dateBuffer);
        } else {
            // Otherwise, draw it from scratch.
            // TODO - whats this?
        }
        
        var sX, sY;
        var eX, eY;
        var outerRad = width / 2;
        var innerRad = outerRad - 5;
        var stringMark="00";
        
		dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(2);
        // draw 24/360 tick marks.
        var hour=0;
        for (var i = -Math.PI/2.0; i < 3 * Math.PI/2.0 ; i += (Math.PI / 12)) {
            hour++;
            sY = outerRad + innerRad * Math.sin(i);
            eY = outerRad + outerRad * Math.sin(i);
            sX = outerRad + innerRad * Math.cos(i);
            eX = outerRad + outerRad * Math.cos(i);
            dc.drawLine(sX, sY, eX, eY);
            stringMark = hour.toLong();
//            dc.drawText(sX, sY, Graphics.FONT_XTINY, stringMark, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! This method is called when the device re-enters sleep mode.
    //! Set the isAwake flag to let onUpdate know it should stop rendering the second hand.
    public function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    //! This method is called when the device exits sleep mode.
    //! Set the isAwake flag to let onUpdate know it should render the second hand.
    public function onExitSleep() as Void {
        _isAwake = true;
    }

    //! Turn off partial updates
    public function turnPartialUpdatesOff() as Void {
        _partialUpdatesAllowed = false;
    }
}

//! Receives watch face events
class SunEclipticAnalogDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as SunEclipticAnalogView;

    //! Constructor
    //! @param view The analog view
    public function initialize(view as SunEclipticAnalogView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! The onPowerBudgetExceeded callback is called by the system if the
    //! onPartialUpdate method exceeds the allowed power budget. If this occurs,
    //! the system will stop invoking onPartialUpdate each second, so we notify the
    //! view here to let the rendering methods know they should not be rendering a
    //! second hand.
    //! @param powerInfo Information about the power budget
    public function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
        System.println("Average execution time: " + powerInfo.executionTimeAverage);
        System.println("Allowed execution time: " + powerInfo.executionTimeLimit);
        _view.turnPartialUpdatesOff();
    }
}
