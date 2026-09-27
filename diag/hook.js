// Diagnostic only (stremio-bugs#2815): drive real in-app PUSH navigations and report each step.
(function () {
    var log = function (msg) {
        try { fetch('/__log?m=' + encodeURIComponent(msg)); } catch (_) { /* ignore */ }
    };
    var clicks = 0;
    var maxClicks = 20;
    var step = function () {
        var hash = location.hash;
        var links = Array.prototype.slice.call(document.querySelectorAll('a[href*="#/detail/"]'));
        log('tick hash=' + hash + ' links=' + links.length + ' clicks=' + clicks);
        if (clicks >= maxClicks) {
            log('DONE clicks=' + clicks);
            return;
        }
        if (hash.indexOf('#/detail/') === 0) {
            history.back();
        } else if (links.length > 0) {
            var link = links[clicks % links.length];
            clicks += 1;
            log('CLICK ' + clicks + ' ' + link.getAttribute('href'));
            link.click();
        }
        setTimeout(step, 2500);
    };
    log('hook loaded ua=' + navigator.userAgent + ' vt=' + (typeof document.startViewTransition));
    setTimeout(step, 20000);
})();
