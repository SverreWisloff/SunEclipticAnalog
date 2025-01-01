//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
// Sun
using Toybox as Toy;
using Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Position;
import SunCalcModule;


//! This implements an analog watch face
//! Original design by Austen Harbour
class SunEclipticAnalogView extends WatchUi.WatchFace {
    private var _font22 as FontResource?;
    private var _font24 as FontResource?;
    private var _isAwake as Boolean?;
    private var _dndIcon as BitmapResource?;
    private var _offscreenBuffer as BufferedBitmap?;
    private var _dateBuffer as BufferedBitmap?;
    private var _screenCenterPoint as Array<Number>?;
    private var _fullScreenRefresh as Boolean;
    private var _partialUpdatesAllowed as Boolean;
    private var _secondHandLength = 110;
    private var _minuteHandLength = 90; 
    private var _hourHandLength = 60;
    private var _arborWidth = 0;
    private var _arrowWidth = 0;
    private var _secondHandWidth = 0;
 
    private var DRAW_SUN_ARC_ON_PERIMETER = false;
    private var DRAW_SUN_TIMES = true;
    private var DRAW_INDEX_LABELS = false;
    private var DRAW_A_GREY_BACKGROUND_TRIANGLE = false;

    private var _ui;
    private var _sc;
    private var _sunRiseTime;
    private var _sunSetTime;

    private var _lastGoodPosition;


    //! Initialize variables for this view
    public function initialize() {
        WatchFace.initialize();
        _fullScreenRefresh = true;
        _partialUpdatesAllowed = (WatchUi.WatchFace has :onPartialUpdate);

        _lastGoodPosition = null;
        _ui = new UiAnalog();
        _sc = new sunCalc();

        getPos();
        
    }

    public function getGpsPos() {
		var locationInfo = Position.getInfo();
		if (locationInfo == null || locationInfo.position == null) {
			return null;
		}
		var location = locationInfo.position.toDegrees();
		if ((Math.round(location[0]) == 0 && Math.round(location[1]) == 0) ||
			Math.round(location[0]) == 180 && Math.round(location[1]) == 180) {
			return null;
		}
		return location;
    }

    private function getWeatherPos() {
		var conditions = Weather.getCurrentConditions();
		if (conditions == null || conditions.observationLocationPosition == null) {
			return null;
		}
		var location = conditions.observationLocationPosition.toDegrees();
		if ((Math.round(location[0]) == 0 && Math.round(location[1]) == 0) ||
			Math.round(location[0]) == 180 && Math.round(location[1]) == 180) {
			return null;
		}
		return location;
	}
    
    private function getPos() as Void {
   		var location = getGpsPos() as Array<Double>;
		if (location == null) {
			location = getWeatherPos();
		}
        if (location != null) {
            var now = Time.now();
            var today = Gregorian.info(now, Time.FORMAT_SHORT);
            var momentNow = new Time.Moment(now.value() );            
            _lastGoodPosition = today;
            var latitude = location[0].toDouble();
            var longitude = location[1].toDouble();
            _sc.setPosition(latitude, longitude);
            _sc.setDate(momentNow.value());
		}
    }


    //! Configure the layout of the watchface for this device
    //! @param dc Device context
    public function onLayout(dc as Dc) as Void {

        _secondHandLength = dc.getWidth() / 2.0;   // 130
        _minuteHandLength = dc.getWidth() / 2.1;   // 124
        _hourHandLength   = dc.getWidth() / 3.2;   // 81
        _arborWidth       = 13;                 //dc.getWidth() / 18;
        _arrowWidth       = 7;                  //dc.getWidth() / 33;
        _secondHandWidth  = 5;                  //dc.getWidth() / 40;

        // Load the custom font we use for drawing the 3, 6, 9, and 12 on the watchface.
        _font24 = WatchUi.loadResource($.Rez.Fonts.id_font_24_Condensed) as FontResource;
        _font22 = WatchUi.loadResource($.Rez.Fonts.id_font_22) as FontResource;

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
                    Graphics.COLOR_RED,
                    Graphics.COLOR_YELLOW,
                    Graphics.COLOR_BLUE,
                    Graphics.COLOR_BLACK,
                    Graphics.COLOR_WHITE
                ]
            };

        var dateBufferOptions = {
                :width=>dc.getWidth(),
                :height=>Graphics.getFontHeight(_font22)
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


    // Draw Debug-info to the main screen.
    private function drawLocation(dc as Dc) as Void {
        var strLocDate, strLocTime;
        if (_sc.getKnownPosition()){
            strLocDate=_lastGoodPosition.day + "." + _lastGoodPosition.month;
            strLocTime= _lastGoodPosition.hour.format("%02u") + ":" + _lastGoodPosition.min.format("%02u") + ":" + _lastGoodPosition.sec.format("%02u");
        } else {
            strLocDate="NA";
            strLocTime="NA";
        }
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        dc.drawText(15*dc.getWidth() / 20,  dc.getHeight() / 2, _font22, strLocTime, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(5*dc.getWidth() / 20,  dc.getHeight() / 2, _font22, strLocDate, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSun(dc as Dc) as Void {
        var now = Time.now();
        var today = Gregorian.info(now, Time.FORMAT_SHORT);
        var momentNow = new Time.Moment(now.value() );   

        //Check if we have a valid position, or time has changed more than 10 minutes
        var minuteDiff=0;
        if (_lastGoodPosition!=null){
            minuteDiff = (today.min - _lastGoodPosition.min).abs();
        }
        if (!_sc.getKnownPosition() || today.day!=_lastGoodPosition.day || today.hour!=_lastGoodPosition.hour || minuteDiff > 10){
            getPos();
        }
        if (!_sc.getKnownPosition()) {
            return;
        }

        _sunRiseTime = _sc.getTimeOfSolarEvent(_sc.SUNRISE) as Double;
        _sunSetTime  = _sc.getTimeOfSolarEvent(_sc.SUNSET) as Double;
       
        //Draw sun to background
        if (DRAW_SUN_TIMES){
            if (_sc.polarPhenomena==0){
                // polarPhenomena: 0=normal, 1=midnight sun, 2=Polar Night
        
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

                //Sunrise
                var solarRiseDesimal = _sc.LocaleTimeAsDesimalHour(_sunRiseTime);
                var solarRiseString  = _sc.PrintLocaleTime(_sunRiseTime);
                var offsetFromPerimeter = 10;
                var coordSunrise = _ui.calcHour2clockCoord(dc, solarRiseDesimal, offsetFromPerimeter) as Point2D;
                
                if      (solarRiseDesimal>=8)                      {
                    coordSunrise = _ui.calcHour2clockCoord(dc, 9.0, offsetFromPerimeter) as Point2D;}
                else if (solarRiseDesimal<8 && solarRiseDesimal>=6){
                    coordSunrise = _ui.calcHour2clockCoord(dc, 7.5, offsetFromPerimeter) as Point2D;}
                else if (solarRiseDesimal<6 && solarRiseDesimal>=4){
                    coordSunrise = _ui.calcHour2clockCoord(dc, 5.9, offsetFromPerimeter) as Point2D;}
                else if (solarRiseDesimal<4 )                      {
                    coordSunrise = _ui.calcHour2clockCoord(dc, 4.0, offsetFromPerimeter) as Point2D;
                    coordSunrise[0] = coordSunrise[0] + 20; //move text to the right
                    }
                dc.drawText(coordSunrise[0], coordSunrise[1], _font22, solarRiseString, Graphics.TEXT_JUSTIFY_LEFT);

                //Sunset
                var solarSetDesimal  = SunCalcModule.LocaleTimeAsDesimalHour(_sunSetTime);
                var solarSetString  = SunCalcModule.PrintLocaleTime(_sunSetTime);
                var coordSunset = _ui.calcHour2clockCoord(dc, solarSetDesimal, offsetFromPerimeter) as Point2D;
                
                if      (solarSetDesimal<=16)                      {
                    coordSunset = _ui.calcHour2clockCoord(dc, 15.0, offsetFromPerimeter);}
                else if (solarSetDesimal<18 && solarSetDesimal>=16){
                    coordSunset = _ui.calcHour2clockCoord(dc, 16.5, offsetFromPerimeter);}
                else if (solarSetDesimal<20 && solarSetDesimal>=18){
                    coordSunset = _ui.calcHour2clockCoord(dc, 18.1, offsetFromPerimeter) as Point2D;}
                else if (solarSetDesimal>=20 )                      {
                    coordSunset = _ui.calcHour2clockCoord(dc, 20.0, offsetFromPerimeter) as Point2D;
                    coordSunset[0] = coordSunset[0] - 20; //move text to the left
                    }
                dc.drawText(coordSunset[0], coordSunset[1], _font22, solarSetString, Graphics.TEXT_JUSTIFY_RIGHT);
            }
            else if (_sc.polarPhenomena==1){
                //Midnight sun
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(dc.getWidth()/2, dc.getHeight()/4, _font22, "Midnight sun", Graphics.TEXT_JUSTIFY_CENTER);
            }
            else if (_sc.polarPhenomena==2){
                //Polar night
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(dc.getWidth()/2, dc.getHeight()/4, _font22, "Polar night", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (DRAW_SUN_ARC_ON_PERIMETER){
//            var nowHour = SunCalcModule.LocaleTimeAsDesimalHour(momentNow.value()); 
//            _ui.drawSunArcOnPerimeter(dc, Graphics.COLOR_YELLOW, sunTimes , nowHour);
        }

        //Draw sun ephemeris
        var sunPositions = new Array<SunCoord_LocalPosition>[24];
        sunPositions = _sc.getSunTrajectoryForDay();
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_YELLOW);
        dc.setPenWidth(2);
        _ui.drawPolygonSkyView(dc, sunPositions);

        //Draw sun on Sky-view
        var sunSize = 11; 
        var sunCoordLocal = _sc.getSunPosition();
        if (sunCoordLocal!=null){
            var point = _ui.calcPolarToScreenCoord(dc , sunCoordLocal, true) as Graphics.Point2D;
            var sunX=point[0];
            var sunY=point[1];

            if ( (_sc.polarPhenomena==0 && (momentNow.value()>_sunRiseTime && momentNow.value()<_sunSetTime)) || _sc.polarPhenomena==1){
                dc.drawCircle(sunX, sunY, sunSize);
                dc.fillCircle(sunX, sunY, sunSize-4);
            }
            else {
                dc.drawCircle(sunX, sunY, sunSize);
            } 
        }
        
    }



    //! Handle the update event
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var targetDc = null;

//        System.println("::onUpdate");

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

        if (DRAW_A_GREY_BACKGROUND_TRIANGLE){
            // Draw a grey background triangle over the upper right half of the screen.
            targetDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
            targetDc.fillPolygon([[0, 0],[targetDc.getWidth(), 0],[targetDc.getWidth(), targetDc.getHeight()],[0, 0]]);
        }

        //Draw sun-info
        if (Application.Properties.getValue("DebugInfo")){
            drawLocation(targetDc);
        }
        drawSun(targetDc);          

        // Draw the tick marks around the edges of the screen
        //_ui.drawIndex(targetDc, 60, 8, 1, Graphics.COLOR_LT_GRAY); //60 Minute marks
        _ui.drawIndex(  targetDc, 12, 30, 11, Graphics.COLOR_BLACK);  //12 Houre marks
        _ui.drawIndexQ5(targetDc, 12, 30, 7, Graphics.COLOR_WHITE);  //12 Houre marks
        //drawIndex(targetDc, 24, 3, 3, Graphics.COLOR_BLUE);  //24 Houre (sun) marks

        // Draw the do-not-disturb icon if we support it and the setting is enabled
        if (System.getDeviceSettings().doNotDisturb && (null != _dndIcon)) {
            targetDc.drawBitmap(width * 0.75, height / 2 - 15, _dndIcon);
        }


        // Draw the 3, 6, 9, and 12 hour labels.
        if (DRAW_INDEX_LABELS){
            _ui.drawIndexLabels(targetDc , _font24);
        }
        
        // Use white to draw the hour and minute hands
        targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        targetDc.setPenWidth(3);

        if (_screenCenterPoint != null) {
            // Draw the hour hand. Convert it to minutes and compute the angle.
            var hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min);
            hourHandAngle = hourHandAngle / (12 * 60.0);
            hourHandAngle = hourHandAngle * Math.PI * 2;
            _ui.drawPolygon(targetDc, _ui.calcHandCoordinates(_screenCenterPoint, hourHandAngle, _hourHandLength, 0, _arborWidth , _arrowWidth));
            targetDc.fillPolygon(_ui.calcHandCoordinates(_screenCenterPoint, hourHandAngle, 14, 0, _arborWidth, _arborWidth));
            targetDc.fillPolygon(_ui.calcHandCoordinates(_screenCenterPoint, hourHandAngle, _hourHandLength, -_hourHandLength+20, _arrowWidth, _arrowWidth));
            //System.println("draw hour hand");
        }

        if (_screenCenterPoint != null) {
            // Draw the minute hand.
            var minuteHandAngle = (clockTime.min / 60.0) * Math.PI * 2;
            var minuteHandPoints = _ui.calcHandCoordinates(_screenCenterPoint, minuteHandAngle, _minuteHandLength, 0, _arborWidth , _arrowWidth);
            targetDc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK);
            targetDc.fillPolygon(minuteHandPoints);
            targetDc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_WHITE);
            _ui.drawPolygon(targetDc, minuteHandPoints);
            targetDc.fillPolygon(_ui.calcHandCoordinates(_screenCenterPoint, minuteHandAngle, 14, 0, _arborWidth, _arborWidth));
            targetDc.fillPolygon(_ui.calcHandCoordinates(_screenCenterPoint, minuteHandAngle, _minuteHandLength, -_minuteHandLength+20, _arrowWidth, _arrowWidth));
            //Draw the center / arbor
            targetDc.fillCircle(targetDc.getWidth() / 2, targetDc.getHeight() / 2, (_arborWidth/2)+3);
            targetDc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK);
            targetDc.setPenWidth(1);
            targetDc.drawCircle(targetDc.getWidth() / 2, targetDc.getHeight() / 2, (_arborWidth/2)+3); 
            targetDc.fillCircle(dc.getWidth() / 2, dc.getHeight() / 2, 4);
            //System.println("draw minute hand");
        }

        // Draw the arbor in the center of the screen.
        //_ui.drawArbor(targetDc);

        // Draw the battery level
        if (Application.Properties.getValue("BatteryLevel")){
            _ui.drawBatterylevel(targetDc, width / 2,  16*height / 20, Graphics.COLOR_WHITE);   
        }

        // If we have an offscreen buffer that we are using for the date string,
        // Draw the date into it. If we do not, the date will get drawn every update
        // after blanking the second hand.
        var offscreenBuffer = _offscreenBuffer;
        if ((null != _dateBuffer) && (null != offscreenBuffer)) {
            var dateDc = _dateBuffer.getDc();

            // Draw the background image buffer into the date buffer to set the background
            dateDc.drawBitmap(0, -(2.6 * height / 4), offscreenBuffer);

            // Draw the date string into the buffer.
            dateDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            if (Application.Properties.getValue("DrawDate")){
                _ui.drawDateString(dateDc, width / 2, 0, _font22);
            }
        }

        // Output the offscreen buffers to the main display if required.
        drawBackground(dc);

        if (_partialUpdatesAllowed) {
            // If this device supports partial updates and they are currently
            // allowed run the onPartialUpdate method to draw the second hand.
            onPartialUpdate(dc);
        } else if (_isAwake) {
            // Otherwise, if we are out of sleep mode, draw the second hand
            // directly in the full update method.
            dc.setColor(Application.Properties.getValue("ForegroundColor") as Number, Graphics.COLOR_TRANSPARENT);
            var secondHand = (clockTime.sec / 60.0) * Math.PI * 2;

            if (_screenCenterPoint != null) {
                dc.fillPolygon(_ui.calcHandCoordinates(_screenCenterPoint, secondHand, _secondHandLength, 20, _secondHandWidth, _secondHandWidth));
                //System.println("draw second hand");
            }
        }

        _fullScreenRefresh = false;
    }


    //! Handle the partial update event
    //! @param dc Device context
    public function onPartialUpdate(dc as Dc) as Void {
        // If we're not doing a full screen refresh we need to re-draw the background
        // before drawing the updated second hand position. Note this will only re-draw
        // the background in the area specified by the previously computed clipping region.

//        System.println("::onPartialUpdate");

        if (!_fullScreenRefresh) {
            drawBackground(dc);
        }

        var clockTime = System.getClockTime();

        if (_screenCenterPoint != null) {
            var secondHand = (clockTime.sec / 60.0) * Math.PI * 2;
            var secondHandPoints = _ui.calcHandCoordinates(_screenCenterPoint, secondHand, _secondHandLength, 20, _secondHandWidth, _secondHandWidth);
            // Update the clipping rectangle to the new location of the second hand.
            var curClip = getBoundingBox(secondHandPoints);
            var bBoxWidth = curClip[1][0] - curClip[0][0] + 1;
            var bBoxHeight = curClip[1][1] - curClip[0][1] + 1;
            dc.setClip(curClip[0][0], curClip[0][1], bBoxWidth, bBoxHeight);

            // Draw the second hand to the screen.
            dc.setPenWidth(2);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.fillPolygon(secondHandPoints);
            var secondHandColor;
            secondHandColor = Graphics.COLOR_BLUE;
            if (Application.Properties.getValue("DrawDate")){
                secondHandColor = Application.Properties.getValue("ForegroundColor") as Number;//TODO - fix this error
            }
            dc.setColor(secondHandColor, secondHandColor);
            _ui.drawPolygon(dc, secondHandPoints);
            //Draw the center of the second hand
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            //dc.setPenWidth(1);
            dc.fillCircle(dc.getWidth() / 2, dc.getHeight() / 2, 4);

            //System.println("draw second hand");      
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
        //var width = dc.getWidth();
        var height = dc.getHeight();

        //System.println("::drawBackground");

        // If we have an offscreen buffer that has been written to
        // draw it to the screen.
        if (null != _offscreenBuffer) {
            dc.drawBitmap(0, 0, _offscreenBuffer);
        }

        // Draw the date
        if (null != _dateBuffer) {
            // If the date is saved in a Buffered Bitmap, just copy it from there.
            dc.drawBitmap(0, 2.6 * height / 4, _dateBuffer);
        } else {
            // Otherwise, draw it from scratch.
            // TODO - whats this?
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
