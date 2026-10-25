import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! The glance (mockup 1): Rayna, today / goal, a progress bar and a tiny sync badge.
(:glance)
class RaynaGlanceView extends WatchUi.GlanceView {
    function initialize() { GlanceView.initialize(); }

    function onUpdate(dc as Graphics.Dc) as Void {
        var h = dc.getHeight();
        var w = dc.getWidth();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var bmp = WatchUi.loadResource(Rez.Drawables.GlanceRay) as WatchUi.BitmapResource;
        var bh = bmp.getHeight();
        dc.drawBitmap(0, bh > h ? 0 : (h - bh) / 2, bmp);
        var x = bmp.getWidth() + (Theme.amoled() ? 12 : 6);

        var total = RaynaStore.total();
        var goal = RaynaStore.goal();
        var p = RaynaStore.progress();
        var lc = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Theme.aqua(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, h * 22 / 100, Graphics.FONT_GLANCE, "RAYNA", lc);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, h * 55 / 100, Graphics.FONT_GLANCE_NUMBER, RaynaStore.fmt(total) + " / " + RaynaStore.fmt(goal) + " ml", lc);
        var bw = w - x - 6;
        var by = h * 82 / 100;
        var bt = Theme.amoled() ? 8 : 6;
        dc.setColor(Theme.track(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, by, bw, bt, bt / 2);
        if (p > 0) {
            dc.setColor(Theme.aqua(), Graphics.COLOR_TRANSPARENT);
            var fw = (bw * p).toNumber();
            dc.fillRoundedRectangle(x, by, fw < bt ? bt : fw, bt, bt / 2);
        }
        // Sync badge: grey dot when drinks are queued, nothing when synced (quiet by default).
        if (RaynaStore.syncState() == :waiting) {
            dc.setColor(Theme.grey(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 4, h * 22 / 100, Graphics.FONT_GLANCE, RaynaStore.waitingCount().format("%d") + " waiting", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
