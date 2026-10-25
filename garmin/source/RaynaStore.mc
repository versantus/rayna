import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Read side of the watch's local state. Annotated (:glance) so the glance can use it within its 64 KB.
//! Storage layout (Application.Storage):
//!   phoneML  Number  today's total as last told by the phone (already includes every acked drink)
//!   day      String  yyyy-mm-dd that phoneML belongs to
//!   goal     Number  today's effective goal (includes the exercise-day bonus), default 2500
//!   glass    Number  the user's glass size from the phone, default 250
//!   streak   Number  goal streak from the phone
//!   sizes    Array   drink sizes offered in Quick add (phone may override)
//!   syncAt   Number  epoch seconds of the last state from the phone
//!   queue    Array   drinks/undos not yet acknowledged by the phone (see RaynaSync)
(:glance)
module RaynaStore {
    const DEFAULT_GOAL = 2500;
    const DEFAULT_GLASS = 250;

    function num(key as String, fallback as Number) as Number {
        var v = Storage.getValue(key);
        return (v instanceof Number) ? v : fallback;
    }

    function dayKey(moment as Time.Moment) as String {
        var i = Gregorian.info(moment, Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$", [i.year.format("%04d"), (i.month as Number).format("%02d"), i.day.format("%02d")]);
    }

    function today() as String {
        return dayKey(Time.now());
    }

    function queue() as Array<Dictionary> {
        var q = Storage.getValue("queue");
        return (q instanceof Array) ? q as Array<Dictionary> : [] as Array<Dictionary>;
    }

    //! What the phone last said for today (0 once the day has rolled over).
    function phoneTotal() as Number {
        var d = Storage.getValue("day");
        return (d instanceof String && d.equals(today())) ? num("phoneML", 0) : 0;
    }

    //! Today's total shown everywhere: the phone's number plus anything still queued on the watch.
    function total() as Number {
        var t = phoneTotal();
        var q = queue();
        var day = today();
        for (var i = 0; i < q.size(); i++) {
            var it = q[i];
            var at = it["at"];
            if (!(at instanceof Number) || !dayKey(new Time.Moment(at)).equals(day)) { continue; }
            var ml = it["ml"] as Number;
            t += "undo".equals(it["op"]) ? -ml : ml;
        }
        return t < 0 ? 0 : t;
    }

    function goal() as Number { return num("goal", DEFAULT_GOAL); }
    function glass() as Number { return num("glass", DEFAULT_GLASS); }
    function streak() as Number { return num("streak", 0); }

    function progress() as Float {
        var g = goal();
        if (g <= 0) { return 0.0; }
        var p = total().toFloat() / g;
        return p > 1.0 ? 1.0 : p;
    }

    //! Rayna's mood band, same thresholds as RaynaBand / raynaBand() on iPhone and Apple Watch.
    function band(p as Float) as Number {
        if (p < 0.15) { return 0; }
        if (p < 0.35) { return 1; }
        if (p < 0.75) { return 2; }
        if (p < 1.0) { return 3; }
        return 4;
    }

    //! Drinks (adds) still waiting for the phone.
    function waitingCount() as Number {
        var q = queue();
        var n = 0;
        for (var i = 0; i < q.size(); i++) { if (!"undo".equals(q[i]["op"])) { n++; } }
        return n;
    }

    //! :synced, :sending or :waiting. Quiet by design: :waiting only after a failed send or 20 s without an ack.
    function syncState() as Symbol {
        var q = queue();
        if (q.size() == 0) { return :synced; }
        var now = Time.now().value();
        var oldest = now;
        for (var i = 0; i < q.size(); i++) {
            var at = q[i]["at"];
            if (at instanceof Number && at < oldest) { oldest = at; }
        }
        if (num("errAt", 0) > num("sentAt", 0) || now - oldest > 20) { return :waiting; }
        return :sending;
    }

    //! "1,500"
    function fmt(n as Number) as String {
        if (n < 1000) { return n.format("%d"); }
        return (n / 1000).format("%d") + "," + (n % 1000).format("%03d");
    }

    //! "2m ago", "3h ago", or "HH:MM" for older.
    function agoText(epoch as Number) as String {
        var s = Time.now().value() - epoch;
        if (s < 60) { return "just now"; }
        if (s < 3600) { return (s / 60).format("%d") + "m ago"; }
        return clock(epoch);
    }

    function clock(epoch as Number) as String {
        var i = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return i.hour.format("%02d") + ":" + i.min.format("%02d");
    }
}
