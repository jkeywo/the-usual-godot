"""Browser export acceptance: simulation/client parity and persistence after reload."""
import functools
import http.server
import json
import threading
from pathlib import Path
from playwright.sync_api import sync_playwright

handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory="build/web")
server = http.server.ThreadingHTTPServer(("127.0.0.1", 8765), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader"])
        page = browser.new_page(viewport={"width": 1280, "height": 800})
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto("http://127.0.0.1:8765/?test")
        page.wait_for_function("window.__usualTests !== undefined", timeout=120000)
        report = page.evaluate("window.__usualTests")
        assert not report["failures"] and not report["missing_source_tests"], report
        page.wait_for_timeout(1500)  # Allow the browser filesystem's asynchronous IndexedDB flush.
        page.goto("http://127.0.0.1:8765/?persist")
        page.wait_for_function("window.__usualPersistence !== undefined", timeout=60000)
        assert page.evaluate("window.__usualPersistence") is True
        assert not errors, errors
        Path("build/reports").mkdir(exist_ok=True)
        Path("build/reports/browser.json").write_text(json.dumps(report, indent=2))
        page.goto("http://127.0.0.1:8765/")
        page.wait_for_timeout(5000)
        page.screenshot(path="build/reports/dashboard.png")
        page.set_viewport_size({"width": 430, "height": 900})
        page.wait_for_timeout(1000)
        page.screenshot(path="build/reports/narrow.png")
        browser.close()
finally:
    server.shutdown()
