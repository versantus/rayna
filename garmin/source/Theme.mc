import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

//! Rayna's colours. AMOLED gets the app's own brand colours; MIP (64-colour) gets the nearest palette colours.
//! Brand: AccentColor #0B78DF / #298CEB, RaynaBrand.aqua #59C7FA, pink #FF8FB0, Watch sea #081F3D.
(:glance)
module Theme {
    function amoled() as Boolean {
        var ds = System.getDeviceSettings();
        return (ds has :requiresBurnInProtection) && ds.requiresBurnInProtection;
    }
    function aqua() as Number { return amoled() ? 0x59C7FA : 0x55AAFF; }
    function blue() as Number { return amoled() ? 0x298CEB : 0x0055FF; }
    function track() as Number { return amoled() ? 0x1B2A3B : 0x555555; }
    function grey() as Number { return amoled() ? 0x8FA3B8 : 0xAAAAAA; }
    function dim() as Number { return amoled() ? 0x4A5B6E : 0x555555; }
    function pill() as Number { return amoled() ? 0x10243B : 0x000055; }
    function soft() as Number { return amoled() ? 0xB9CCE0 : 0xFFFFFF; }
    function navy() as Number { return 0x081F3D; }
    function gold() as Number { return amoled() ? 0xFFD45A : 0xFFFF55; }
    function pink() as Number { return amoled() ? 0xFF8FB0 : 0xFF55AA; }

    //! The 454 value on big screens, the 260 value on small ones, scaled in between.
    function px(dc as Graphics.Dc, big as Numeric, small as Numeric) as Number {
        var w = dc.getWidth();
        if (w >= 454) { return big.toNumber(); }
        if (w <= 260) { return small.toNumber(); }
        return (small + (big - small) * (w - 260) / 194.0).toNumber();
    }
}

//! Drawing helpers shared by the views.
module Draw {
    //! Arc from fraction f0 to f1 of a full turn, clockwise from 12 o'clock.
    function arc(dc as Graphics.Dc, cx as Number, cy as Number, r as Number, f0 as Float, f1 as Float) as Void {
        if (f1 <= f0) { return; }
        if (f1 - f0 >= 0.999) { dc.drawCircle(cx, cy, r); return; }
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90 - f0 * 360, 90 - f1 * 360);
    }

    //! Progress ring round the bezel. queued: part of p not on the phone yet (dashed). fresh: just added (white).
    function ring(dc as Graphics.Dc, p as Float, queued as Float, fresh as Float) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var w = Theme.px(dc, 14, 8);
        var r = cx - Theme.px(dc, 22, 14);
        dc.setPenWidth(w);
        dc.setColor(Theme.track(), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        var solid = p - queued - fresh;
        dc.setColor(Theme.aqua(), Graphics.COLOR_TRANSPARENT);
        arc(dc, cx, cy, r, 0.0, solid);
        if (fresh > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            arc(dc, cx, cy, r, solid, solid + fresh);
        }
        if (queued > 0) {
            dc.setColor(Theme.aqua(), Graphics.COLOR_TRANSPARENT);
            var f = p - queued;
            while (f < p) {
                var e = f + 0.012;
                arc(dc, cx, cy, r, f, e < p ? e : p);
                f += 0.024;
            }
        }
        dc.setPenWidth(1);
    }

    //! The Garmin-style hint arc beside the START button (about 2 o'clock).
    function startHint(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        dc.setPenWidth(Theme.px(dc, 6, 4));
        dc.setColor(Theme.aqua(), Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, dc.getHeight() / 2, cx - Theme.px(dc, 6, 4), Graphics.ARC_CLOCKWISE, 40, 20);
        dc.setPenWidth(1);
    }

    //! AMOLED only: Rayna's sea, a soft navy tint rising with progress (the iPhone/Apple Watch "immersive" look).
    function sea(dc as Graphics.Dc, p as Float) as Void {
        if (!Theme.amoled()) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Theme.navy(), Graphics.COLOR_TRANSPARENT);
        if (p >= 1.0) { dc.fillCircle(w / 2, h / 2, w / 2); return; }
        var y = h * (1 - 0.12 - 0.72 * p);
        var pts = [] as Array<[Numeric, Numeric]>;
        for (var x = 0; x <= w; x += w / 12) {
            pts.add([x, y + 8 * Math.sin(x * 6.283 / w * 1.5)]);
        }
        pts.add([w, h]);
        pts.add([0, h]);
        dc.fillPolygon(pts);
    }

    //! Small phone outline with a tick (synced) or clock (waiting) badge.
    function phone(dc as Graphics.Dc, x as Number, y as Number, h as Number, col as Number, badge as Symbol, badgeCol as Number) as Void {
        var w = (h * 0.62).toNumber();
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(h > 16 ? 2 : 1);
        dc.drawRoundedRectangle(x, y, w, h, h / 6);
        dc.drawLine(x + w / 3, y + h * 4 / 5, x + w * 2 / 3, y + h * 4 / 5);
        var bx = x + w;
        var by = y + h * 3 / 4;
        var br = h / 3;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, br + 1);
        dc.setColor(badgeCol, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, br);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        if (badge == :tick) {
            dc.drawLine(bx - br / 2, by, bx - br / 6, by + br / 3);
            dc.drawLine(bx - br / 6, by + br / 3, bx + br / 2, by - br / 3);
        } else {
            dc.drawLine(bx, by - br / 2, bx, by);
            dc.drawLine(bx, by, bx + br / 3, by + br / 4);
        }
        dc.setPenWidth(1);
    }

    function ray(dc as Graphics.Dc, band as Number, top as Number) as Void {
        var ids = [Rez.Drawables.Ray0, Rez.Drawables.Ray1, Rez.Drawables.Ray2, Rez.Drawables.Ray3, Rez.Drawables.Ray4];
        var bmp = WatchUi.loadResource(ids[band]) as WatchUi.BitmapResource;
        dc.drawBitmap((dc.getWidth() - bmp.getWidth()) / 2, top, bmp);
    }
}
