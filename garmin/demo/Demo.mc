import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

//! Screenshot builds only. DEMO_SCREEN comes from bin/demo/DemoScreen.mc, written by scripts/shots.sh.
function seed(phoneML as Number, queued as Number) as Void {
    var now = Time.now().value();
    Storage.setValue("phoneML", phoneML);
    Storage.setValue("day", RaynaStore.today());
    Storage.setValue("goal", 2500);
    Storage.setValue("glass", 250);
    Storage.setValue("streak", 14);
    Storage.deleteValue("sizes");
    var q = [] as Array<Dictionary>;
    for (var i = 0; i < queued; i++) {
        q.add({"id" => "demo-" + i.format("%d"), "op" => "add", "ml" => 250, "at" => now - 300 + i, "sent" => true});
    }
    Storage.setValue("queue", q as Array<Application.PropertyValueType>);
    Storage.setValue("syncAt", queued > 0 ? now - 3 * 3600 : now - 120);
    if (queued > 0) { Storage.setValue("errAt", now); Storage.setValue("sentAt", now - 600); } else { Storage.deleteValue("errAt"); }
}

function startView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
    AddedView.autoReturn = false;
    if (DEMO_SCREEN.equals("glance")) { seed(1500, 0); return [new DemoGlanceHost()]; }
    if (DEMO_SCREEN.equals("picker")) { seed(1500, 0); return [new PickerView(), new PickerDelegate()]; }
    if (DEMO_SCREEN.equals("added")) { seed(1750, 0); return [new AddedView(250, false), new AddedDelegate()]; }
    if (DEMO_SCREEN.equals("goal")) { seed(2500, 0); return [new AddedView(250, true), new AddedDelegate()]; }
    if (DEMO_SCREEN.equals("waiting")) { seed(1000, 2); return [new MainView(), new MainDelegate()]; }
    seed(1500, 0);
    return [new MainView(), new MainDelegate()];
}

//! Draws the real glance view into a glance-sized buffer in the middle of the screen, with dimmed neighbours,
//! roughly how the glance loop shows it.
class DemoGlanceHost extends WatchUi.View {
    function initialize() { View.initialize(); }
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var gw = w * 80 / 100;
        var gh = h * 26 / 100;
        var gx = (w - gw) / 2;
        var gy = (h - gh) / 2;
        var bb = Graphics.createBufferedBitmap({:width => gw, :height => gh}).get() as Graphics.BufferedBitmap;
        var bdc = bb.getDc();
        bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        bdc.clear();
        new RaynaGlanceView().onUpdate(bdc);
        dc.drawBitmap(gx, gy, bb);
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(0x4A5B6E, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, gy - h * 14 / 100, Graphics.FONT_XTINY, "Steps  6,214", vc);
        dc.drawText(w / 2, gy + gh + h * 14 / 100, Graphics.FONT_XTINY, "Weather  14°", vc);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(gx, gy - 6, gx + gw, gy - 6);
        dc.drawLine(gx, gy + gh + 6, gx + gw, gy + gh + 6);
    }
}
