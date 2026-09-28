import re
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("WebKit", "6.0")
from gi.repository import Gtk, WebKit  # noqa: E402

info = open("/.flatpak-info").read()
commit = re.search(r"runtime-commit=(\w+)", info)
print("SANDBOX WebKitGTK %d.%d.%d GTK %d.%d.%d runtime-commit %s" % (
    WebKit.get_major_version(), WebKit.get_minor_version(), WebKit.get_micro_version(),
    Gtk.get_major_version(), Gtk.get_minor_version(), Gtk.get_micro_version(),
    commit.group(1) if commit else "?"))
