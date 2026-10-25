import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

//! Rayna for Garmin: a Connect IQ watch app with a glance. Logs drinks on the watch, queues them,
//! and hands them to the Rayna iPhone app through Garmin Connect Mobile (Connect IQ iOS SDK).
class RaynaApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        // Registered here, not in onStart: onStart also runs for the glance, which can't use Communications.
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onPhone));
        }
        return startView();
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new RaynaGlanceView()];
    }

    function onPhone(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (data instanceof Dictionary) {
            RaynaSync.applyPhone(data);
            WatchUi.requestUpdate();
        }
    }
}
