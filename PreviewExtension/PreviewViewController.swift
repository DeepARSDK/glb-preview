import Cocoa
import QuickLookUI
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {

    private var webView: WKWebView!
    private var pendingBase64: String?
    private var continuation: CheckedContinuation<Void, Error>?

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL) async throws {
        guard let htmlURL = Bundle.main.url(forResource: "viewer", withExtension: "html") else {
            return
        }

        let glbData = try Data(contentsOf: url)
        pendingBase64 = glbData.base64EncodedString()

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let base64 = pendingBase64 else {
            continuation?.resume()
            continuation = nil
            return
        }
        pendingBase64 = nil

        let js = """
        (function() {
            const binary = atob('\(base64)');
            const bytes = new Uint8Array(binary.length);
            for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
            const blob = new Blob([bytes], { type: 'model/gltf-binary' });
            const url = URL.createObjectURL(blob);
            document.getElementById('viewer').src = url;
        })();
        """

        webView.evaluateJavaScript(js) { [weak self] _, _ in
            self?.continuation?.resume()
            self?.continuation = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
