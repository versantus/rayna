import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! Write side: logging, undo, the offline queue and the phone link.
//!
//! Protocol v1 (see docs/garmin/PLAN.md and GarminProtocol.swift):
//!   watch -> phone  {"v":1,"t":"drinks","dev":"a1b2c3","items":[{"id":"a1b2c3-17","op":"add","ml":250,"at":1761400000}, ...]}
//!                   {"v":1,"t":"hello","dev":"a1b2c3"}
//!   phone -> watch  {"v":1,"t":"state","ml":1750,"goal":2500,"glass":250,"streak":14,"day":"2026-10-25",
//!                    "sizes":[150,200,250,330,400,500],"ack":["a1b2c3-17", ...]}
//! Items stay queued until the phone acks their id, so a lost reply only means a resend; the phone dedupes by id.
module RaynaSync {
    const PROTO = 1;
    const MAX_BATCH = 20;
    var inFlight as Boolean = false;

    class TxListener extends Communications.ConnectionListener {
        function initialize() { ConnectionListener.initialize(); }
        function onComplete() as Void {
            RaynaSync.inFlight = false;
            Storage.setValue("sentAt", Time.now().value());
            WatchUi.requestUpdate();
        }
        function onError() as Void {
            RaynaSync.inFlight = false;
            Storage.setValue("errAt", Time.now().value());
            WatchUi.requestUpdate();
        }
    }

    //! A short random tag for this watch, so ids from two watches never collide.
    function deviceTag() as String {
        var t = Storage.getValue("dev");
        if (t instanceof String) { return t; }
        Math.srand(Time.now().value());
        var s = (Math.rand() & 0xFFFFFF).format("%06x");
        Storage.setValue("dev", s);
        return s;
    }

    function nextId() as String {
        var n = RaynaStore.num("seq", 0) + 1;
        Storage.setValue("seq", n);
        return deviceTag() + "-" + n.format("%d");
    }

    function save(q as Array<Dictionary>) as Void { Storage.setValue("queue", q as Array<Application.PropertyValueType>); }

    //! Logs a drink. Returns true when this drink reached today's goal.
    function addDrink(ml as Number) as Boolean {
        var before = RaynaStore.total();
        var id = nextId();
        var q = RaynaStore.queue();
        q.add({"id" => id, "op" => "add", "ml" => ml, "at" => Time.now().value()});
        save(q);
        Storage.setValue("last", id);
        Storage.setValue("lastML", ml);
        flush();
        publish();
        var g = RaynaStore.goal();
        return before < g && before + ml >= g;
    }

    //! Takes back the last drink logged on this watch. Unsent: simply dropped. Sent: an undo goes to the phone.
    function undoLast() as Boolean {
        var id = Storage.getValue("last");
        if (!(id instanceof String)) { return false; }
        var q = RaynaStore.queue();
        for (var i = 0; i < q.size(); i++) {
            if (id.equals(q[i]["id"]) && q[i]["sent"] != true) {
                q.remove(q[i]);
                save(q);
                Storage.deleteValue("last");
                publish();
                return true;
            }
        }
        q.add({"id" => nextId(), "op" => "undo", "ref" => id, "ml" => RaynaStore.num("lastML", RaynaStore.glass()), "at" => Time.now().value()});
        save(q);
        Storage.deleteValue("last");
        flush();
        publish();
        return true;
    }

    //! Sends whatever is queued (one message at a time). Safe to call often.
    function flush() as Void {
        if (inFlight) { return; }
        var q = RaynaStore.queue();
        if (q.size() == 0) { return; }
        var items = [] as Array<Dictionary>;
        for (var i = 0; i < q.size() && i < MAX_BATCH; i++) {
            var it = q[i];
            var out = {"id" => it["id"], "op" => it["op"], "ml" => it["ml"], "at" => it["at"]};
            if (it["ref"] != null) { out["ref"] = it["ref"]; }
            items.add(out);
            it["sent"] = true;
        }
        save(q);
        inFlight = true;
        Communications.transmit({"v" => PROTO, "t" => "drinks", "dev" => deviceTag(), "items" => items}, null, new TxListener());
    }

    //! Asks the phone for today's numbers (it replies with a state message if the Rayna app is awake).
    function hello() as Void {
        if (inFlight) { return; }
        inFlight = true;
        Communications.transmit({"v" => PROTO, "t" => "hello", "dev" => deviceTag()}, null, new TxListener());
    }

    //! A state message from the phone: store its numbers and drop every acked item from the queue.
    function applyPhone(data as Dictionary) as Void {
        if (!"state".equals(data["t"])) { return; }
        var keys = ["ml", "goal", "glass", "streak"];
        var store = ["phoneML", "goal", "glass", "streak"];
        for (var i = 0; i < keys.size(); i++) {
            var v = data[keys[i]];
            if (v instanceof Number) { Storage.setValue(store[i], v); }
        }
        var day = data["day"];
        Storage.setValue("day", day instanceof String ? day : RaynaStore.today());
        var sizes = data["sizes"];
        if (sizes instanceof Array && sizes.size() > 0) { Storage.setValue("sizes", sizes as Array<Application.PropertyValueType>); }
        var ack = data["ack"];
        if (ack instanceof Array) {
            var q = RaynaStore.queue();
            var keep = [] as Array<Dictionary>;
            for (var i = 0; i < q.size(); i++) {
                if (ack.indexOf(q[i]["id"]) < 0) { keep.add(q[i]); }
            }
            save(keep);
        }
        Storage.setValue("syncAt", Time.now().value());
        Storage.deleteValue("errAt");
        publish();
        flush();   // anything still queued (sent after the phone built this reply) goes now
    }

    //! Drink sizes for Quick add: the phone's list (or Rayna's presets) plus the user's own glass if it is custom.
    function sizes() as Array<Number> {
        var s = Storage.getValue("sizes");
        var list = (s instanceof Array) ? (s as Array<Number>) : [150, 200, 250, 330, 400, 500] as Array<Number>;
        var g = RaynaStore.glass();
        if (list.indexOf(g) >= 0) { return list; }
        var out = [] as Array<Number>;
        var placed = false;
        for (var i = 0; i < list.size(); i++) {
            if (!placed && g < list[i]) { out.add(g); placed = true; }
            out.add(list[i]);
        }
        if (!placed) { out.add(g); }
        return out;
    }

    //! Today's ml for watch faces (Complications, API 4.2+).
    function publish() as Void {
        if (Toybox has :Complications) {
            try {
                Complications.updateComplication(0, {:value => RaynaStore.total(), :unit => "ml"});
            } catch (e) {
                // No complication slot on this device: nothing to do.
            }
        }
    }
}
