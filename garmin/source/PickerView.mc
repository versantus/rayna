import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Quick add (mockup 3): Rayna's drink sizes, opening on the user's own glass.
class PickerView extends WatchUi.View {
    var sizes as Array<Number>;
    var index as Number;

    function initialize() {
        View.initialize();
        sizes = RaynaSync.sizes();
        var i = sizes.indexOf(RaynaStore.glass());
        index = i >= 0 ? i : 0;
    }

    function selected() as Number { return sizes[index]; }

    function move(by as Number) as Void {
        var n = index + by;
        if (n >= 0 && n < sizes.size()) { index = n; WatchUi.requestUpdate(); }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        var big = Theme.amoled();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        Draw.startHint(dc);

        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Theme.grey(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.px(dc, 74, 40), Graphics.FONT_XTINY, "Add a drink", vc);

        // Neighbours: one each side on MIP, two each side on AMOLED. [offset, y, font, colour]
        var rows = big ? [[-2, 128, Graphics.FONT_XTINY, 0x3C4A58], [-1, 170, Graphics.FONT_SMALL, 0x6F8296], [1, 314, Graphics.FONT_SMALL, 0x6F8296], [2, 358, Graphics.FONT_XTINY, 0x3C4A58]]
                       : [[-1, 72, Graphics.FONT_TINY, 0xAAAAAA], [1, 192, Graphics.FONT_TINY, 0xAAAAAA]];
        for (var i = 0; i < rows.size(); i++) {
            var r = rows[i];
            var j = index + (r[0] as Number);
            if (j < 0 || j >= sizes.size()) { continue; }
            dc.setColor(r[3] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, r[1] as Number, r[2] as Graphics.FontType, sizes[j].format("%d") + " ml", vc);
        }

        // Selected pill
        var pw = Theme.px(dc, 338, 204);
        var ph = Theme.px(dc, 96, 70);
        var py = Theme.px(dc, 188, 92);
        dc.setColor(Theme.pill(), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - pw / 2, py, pw, ph, ph / 2);
        dc.setColor(Theme.aqua(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(big ? 3 : 2);
        dc.drawRoundedRectangle(cx - pw / 2, py, pw, ph, ph / 2);
        dc.setPenWidth(1);
        var ml = selected();
        glass(dc, cx - pw / 2 + Theme.px(dc, 60, 36), py + ph * 3 / 4, Theme.px(dc, 54, 36), ml);
        var mine = ml == RaynaStore.glass();
        var tx = cx + Theme.px(dc, 20, 14);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx, py + ph / 2 - (mine ? Theme.px(dc, 10, 7) : 0), Graphics.FONT_NUMBER_MILD, ml.format("%d"), vc);
        if (mine) {
            dc.setColor(big ? Theme.aqua() : 0x55FFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(tx, py + ph - Theme.px(dc, 16, 11), Graphics.FONT_XTINY, "your glass", vc);
        }

        // UP / DOWN chevrons beside the left buttons
        dc.setColor(Theme.grey(), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(big ? 4 : 2);
        var chx = Theme.px(dc, 34, 16);
        var cs = Theme.px(dc, 9, 6);
        var cy = py + ph / 2;
        dc.drawLine(chx - cs, cy - cs, chx, cy - 2 * cs);
        dc.drawLine(chx, cy - 2 * cs, chx + cs, cy - cs);
        dc.drawLine(chx - cs, cy + cs, chx, cy + 2 * cs);
        dc.drawLine(chx, cy + 2 * cs, chx + cs, cy + cs);
        dc.setPenWidth(1);

        // Preview: today -> after this drink
        var t = RaynaStore.total();
        dc.setColor(Theme.aqua(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, Theme.px(dc, 398, 224), Graphics.FONT_XTINY, RaynaStore.fmt(t) + " > " + RaynaStore.fmt(t + ml) + (big ? " ml" : ""), vc);
    }

    //! A glass for up to 330 ml, a bottle for 400 ml and up.
    private function glass(dc as Graphics.Dc, x as Number, base as Number, h as Number, ml as Number) as Void {
        var fill = Theme.amoled() ? 0x1A8CD9 : 0x0055FF;
        if (ml >= 400) {
            var bw = h * 46 / 100;
            dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - bw / 2 + 2, base - h * 55 / 100, bw - 4, h * 55 / 100 - 2);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRoundedRectangle(x - bw / 2, base - h * 78 / 100, bw, h * 78 / 100, 4);
            dc.drawRectangle(x - bw / 5, base - h, bw * 2 / 5, h * 22 / 100);
            dc.setPenWidth(1);
            return;
        }
        var wt = h * 72 / 100;
        var wb = h * 54 / 100;
        var lv = h * 62 / 100;
        var wl = wb + (wt - wb) * 62 / 100;
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x - wl / 2 + 2, base - lv], [x - wb / 2 + 2, base - 2], [x + wb / 2 - 2, base - 2], [x + wl / 2 - 2, base - lv]]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(Theme.amoled() ? 3 : 2);
        dc.drawLine(x - wt / 2, base - h, x - wb / 2, base);
        dc.drawLine(x - wb / 2, base, x + wb / 2, base);
        dc.drawLine(x + wb / 2, base, x + wt / 2, base - h);
        dc.setPenWidth(1);
    }
}

//! UP/DOWN (or swipe) change size, START (or tap) adds, BACK cancels.
class PickerDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }

    function view() as PickerView { return WatchUi.getCurrentView()[0] as PickerView; }

    function onNextPage() as Boolean { view().move(1); return true; }
    function onPreviousPage() as Boolean { view().move(-1); return true; }

    function onSelect() as Boolean {
        var ml = view().selected();
        var goalHit = RaynaSync.addDrink(ml);
        WatchUi.switchToView(new AddedView(ml, goalHit), new AddedDelegate(), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
