import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

//! Main screen (mockup 2), which becomes the waiting state (mockup 5) while drinks are queued.
class MainView extends WatchUi.View {
    private var _timer as Timer.Timer?;

    function initialize() { View.initialize(); }

    function onShow() as Void {
        RaynaSync.flush();
        // Refresh "2m ago" and the sending/waiting state while open.
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:tick), 15000, true);
    }

    function onHide() as Void {
        if (_timer != null) { (_timer as Timer.Timer).stop(); _timer = null; }
    }

    function tick() as Void {
        RaynaSync.flush();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var total = RaynaStore.total();
        var goal = RaynaStore.goal();
        var p = RaynaStore.progress();
        var state = RaynaStore.syncState();
        var waiting = state == :waiting;
        var queuedML = total - RaynaStore.phoneTotal();
        var queuedFrac = (state != :synced && queuedML > 0 && goal > 0) ? queuedML.toFloat() / goal : 0.0;
        if (queuedFrac > p) { queuedFrac = p; }

        Draw.sea(dc, p);
        Draw.ring(dc, p, queuedFrac, 0.0);
        Draw.startHint(dc);

        var pct = (total * 100 / (goal > 0 ? goal : 1));
        if (!waiting) {
            Draw.ray(dc, RaynaStore.band(p), Theme.px(dc, 52, 30));
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, Theme.px(dc, 292, 160), Graphics.FONT_NUMBER_MILD, RaynaStore.fmt(total), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.grey(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, Theme.px(dc, 344, 192), Graphics.FONT_TINY, "of " + RaynaStore.fmt(goal) + " ml  " + pct.format("%d") + "%", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            var syncAt = RaynaStore.num("syncAt", 0);
            var line = state == :sending ? "Sending..." : (syncAt > 0 ? "Synced " + RaynaStore.agoText(syncAt) : "Open Rayna on iPhone");
            syncLine(dc, Theme.px(dc, 392, 220), line, state == :sending ? :clock : :tick, Theme.aqua());
        } else {
            Draw.ray(dc, RaynaStore.band(p), Theme.px(dc, 40, 22));
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, Theme.px(dc, 268, 150), Graphics.FONT_NUMBER_MILD, RaynaStore.fmt(total), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Theme.grey(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, Theme.px(dc, 314, 176), Graphics.FONT_XTINY, "of " + RaynaStore.fmt(goal) + " ml  " + pct.format("%d") + "%", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            var n = RaynaStore.waitingCount();
            var msg = n == 1 ? "1 drink waiting for phone" : n.format("%d") + " drinks waiting for phone";
            if (!Theme.amoled()) { msg = n.format("%d") + " waiting for phone"; }
            if (Theme.amoled()) {
                dc.setColor(Theme.pill(), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx - 160, 336, 320, 44, 22);
            }
            syncLine(dc, Theme.px(dc, 358, 200), msg, :clock, Theme.soft());
            var syncAt = RaynaStore.num("syncAt", 0);
            dc.setColor(Theme.dim() == 0x555555 ? Theme.grey() : Theme.dim(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, Theme.px(dc, 404, 224), Graphics.FONT_XTINY, syncAt > 0 ? "Last synced " + RaynaStore.clock(syncAt) : "Not synced yet", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    //! Phone icon + one short line, centred as a pair.
    private function syncLine(dc as Graphics.Dc, y as Number, text as String, badge as Symbol, badgeCol as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var tw = dc.getTextWidthInPixels(text, font);
        var ih = Theme.px(dc, 22, 14);
        var gap = Theme.px(dc, 14, 8);
        var x0 = (dc.getWidth() - (tw + ih + gap)) / 2;
        Draw.phone(dc, x0, y - ih / 2, ih, Theme.grey(), badge, badgeCol);
        dc.setColor(badge == :clock ? Theme.soft() : Theme.grey(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + ih + gap, y, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class MainDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }

    //! START (or tap): Quick add.
    function onSelect() as Boolean {
        WatchUi.pushView(new PickerView(), new PickerDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    //! Hold UP: menu.
    function onMenu() as Boolean {
        var menu = new WatchUi.Menu2({:title => "Rayna"});
        menu.addItem(new WatchUi.MenuItem("Undo last drink", null, :undo, null));
        menu.addItem(new WatchUi.MenuItem("Sync now", null, :sync, null));
        WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :undo) { RaynaSync.undoLast(); }
        else if (id == :sync) { RaynaSync.flush(); RaynaSync.hello(); }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
