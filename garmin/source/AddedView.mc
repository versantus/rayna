import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

//! Confirmation (mockup 4a) or goal reached (mockup 4b). Auto-returns to the main screen.
class AddedView extends WatchUi.View {
    var ml as Number;
    var goal as Boolean;
    //! Screenshot builds keep the confirmation on screen.
    static var autoReturn as Boolean = true;
    private var _timer as Timer.Timer?;

    function initialize(added as Number, goalHit as Boolean) {
        View.initialize();
        ml = added;
        goal = goalHit;
    }

    function onShow() as Void {
        if (Attention has :vibrate) {
            // One short buzz for a drink; a two-pulse pattern for the goal (once a day: goalHit is only true on the crossing).
            var vibe = goal
                ? [new Attention.VibeProfile(80, 200), new Attention.VibeProfile(0, 150), new Attention.VibeProfile(80, 300)]
                : [new Attention.VibeProfile(50, 150)];
            Attention.vibrate(vibe);
        }
        if (!AddedView.autoReturn) { return; }
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:done), goal ? 3500 : 2000, false);
    }

    function onHide() as Void {
        if (_timer != null) { (_timer as Timer.Timer).stop(); _timer = null; }
    }

    function done() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var total = RaynaStore.total();
        var g = RaynaStore.goal();
        var p = RaynaStore.progress();
        Draw.sea(dc, p);

        if (goal) {
            Draw.ring(dc, 1.0, 0.0, 0.0);
            sparkles(dc);
            Draw.ray(dc, 4, Theme.px(dc, 46, 26));
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, Theme.px(dc, 300, 166), Graphics.FONT_LARGE, "Goal!", vc);
            dc.setColor(Theme.grey(), Graphics.COLOR_TRANSPARENT);
            var s = RaynaStore.streak();
            var sub = RaynaStore.fmt(total) + " ml" + (s > 1 ? "  " + s.format("%d") + (Theme.amoled() ? "-day streak" : " days") : "");
            dc.drawText(cx, Theme.px(dc, 348, 194), Graphics.FONT_XTINY, sub, vc);
            dc.setColor(Theme.amoled() ? Theme.aqua() : 0x55FFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, Theme.px(dc, 388, 216), Graphics.FONT_XTINY, "The tide is in.", vc);
            return;
        }

        var fresh = g > 0 ? ml.toFloat() / g : 0.0;
        if (fresh > p) { fresh = p; }
        Draw.ring(dc, p, 0.0, fresh);
        bubbles(dc);
        var bmp = WatchUi.loadResource(Rez.Drawables.RayTilt) as WatchUi.BitmapResource;
        dc.drawBitmap(cx - bmp.getWidth() / 2, Theme.px(dc, 46, 26), bmp);
        dc.setColor(Theme.amoled() ? Theme.aqua() : 0x55FFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.px(dc, 296, 160), Graphics.FONT_NUMBER_MILD, "+" + ml.format("%d"), vc);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.px(dc, 348, 194), Graphics.FONT_XTINY, RaynaStore.fmt(total) + " / " + RaynaStore.fmt(g) + " ml", vc);
        dc.setColor(Theme.grey(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.px(dc, 392, 220), Graphics.FONT_XTINY, "BACK to undo", vc);
    }

    private function bubbles(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.amoled() ? 0x7FD8FF : 0x55FFFF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var b = [[110, 120, 9], [92, 168, 5], [346, 108, 7], [366, 150, 11], [330, 196, 5], [126, 222, 6]];
        var s = dc.getWidth() / 454.0;
        for (var i = 0; i < b.size(); i++) {
            dc.drawCircle((b[i][0] * s).toNumber(), (b[i][1] * s).toNumber(), ((b[i][2] * s).toNumber() > 2 ? (b[i][2] * s).toNumber() : 3));
        }
        dc.setPenWidth(1);
    }

    private function sparkles(dc as Graphics.Dc) as Void {
        var s = dc.getWidth() / 454.0;
        var pts = [[96, 140, 14, Theme.gold()], [360, 128, 11, Theme.pink()], [378, 196, 7, Theme.gold()], [82, 214, 7, Theme.pink()],
                   [352, 262, 9, Theme.aqua()], [104, 270, 8, Theme.aqua()]];
        for (var i = 0; i < pts.size(); i++) {
            var x = pts[i][0] * s;
            var y = pts[i][1] * s;
            var r = pts[i][2] * s;
            var q = r * 0.22;
            dc.setColor(pts[i][3] as Number, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[x, y - r], [x + q, y - q], [x + r, y], [x + q, y + q], [x, y + r], [x - q, y + q], [x - r, y], [x - q, y - q]]);
        }
    }
}

//! BACK undoes (while the confirmation is showing), START adds another, anything else returns.
class AddedDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }

    function onBack() as Boolean {
        RaynaSync.undoLast();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        WatchUi.switchToView(new PickerView(), new PickerDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
}
