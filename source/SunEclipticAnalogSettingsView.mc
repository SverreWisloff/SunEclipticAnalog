//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Initial app settings view
class SunEclipticAnalogSettingsView extends WatchUi.View {

    //! Constructor
    public function initialize() {
        View.initialize();
    }

    //! Handle the update event
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {
        dc.clearClip();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - 30, Graphics.FONT_SMALL, "Press Menu \nfor settings", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

//! Input handler for the initial app settings view
class SunEclipticAnalogSettingsDelegate extends WatchUi.BehaviorDelegate {

    //! Constructor
    public function initialize() {
        BehaviorDelegate.initialize();
    }

    //! Handle the menu event
    //! @return true if handled, false otherwise
    public function onMenu() as Boolean {
        System.println("::onMenu()");
        var menu = new $.SunEclipticAnalogSettingsMenu();

        //var number = Storage.getValue(1) ? true : false;
        //menu.addItem(new WatchUi.ToggleMenuItem("ForegroundColor", null, 1, number, null));

        var bStatusIcons = Application.Properties.getValue("StatusIcons") ? true : false;
        menu.addItem(new WatchUi.ToggleMenuItem("StatusIcons", null, "StatusIcons", bStatusIcons, null));

        var bDrawDate = Application.Properties.getValue("DrawDate") ? true : false;
        menu.addItem(new WatchUi.ToggleMenuItem("DrawDate", null, "DrawDate", bDrawDate, null));

        var bBatteryLevel = Application.Properties.getValue("BatteryLevel") ? true : false;
        menu.addItem(new WatchUi.ToggleMenuItem("BatteryLevel", null, "BatteryLevel", bBatteryLevel, null));

        var bSolarNoon = Application.Properties.getValue("SolarNoon") ? true : false;
        menu.addItem(new WatchUi.ToggleMenuItem("SolarNoon", null, "SolarNoon", bSolarNoon, null));

        var bSunSetRise = Application.Properties.getValue("SunSetRise") ? true : false;
        menu.addItem(new WatchUi.ToggleMenuItem("SunSetRise", null, "SunSetRise", bSunSetRise, null));

        var bDebugInfo = Application.Properties.getValue("DebugInfo") ? true : false;
        menu.addItem(new WatchUi.ToggleMenuItem("DebugInfo", null, "DebugInfo", bDebugInfo, null));

        WatchUi.pushView(menu, new $.SunEclipticAnalogSettingsMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }


}

