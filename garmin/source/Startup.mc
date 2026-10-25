import Toybox.Lang;
import Toybox.WatchUi;

//! The first screen. demo/Demo.mc replaces this in screenshot builds (demo.jungle excludes :nodemo).
(:nodemo)
function startView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
    RaynaSync.flush();
    RaynaSync.hello();
    RaynaSync.publish();
    return [new MainView(), new MainDelegate()];
}
