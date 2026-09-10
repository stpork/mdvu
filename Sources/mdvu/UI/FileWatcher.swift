import Foundation

final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private let callback: () -> Void
    private let queue = DispatchQueue(label: "com.mdvu.file-watcher", qos: .utility)
    private let url: URL
    private var isInvalidated = false

    init?(url: URL, callback: @escaping () -> Void) {
        self.url = url
        self.callback = callback
        guard startWatching() else { return nil }
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        if isInvalidated { return }
        isInvalidated = true
        pending?.cancel()
        pending = nil
        source?.cancel()
        source = nil
    }

    @discardableResult
    private func startWatching() -> Bool {
        guard !isInvalidated else { return false }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return false }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source, !self.isInvalidated else { return }
            let data = source.data
            if data.contains(.delete) || data.contains(.rename) {
                source.cancel()
                self.rearm()
            }
            self.changed()
        }
        source.setCancelHandler { close(fd) }
        self.source = source
        source.resume()
        return true
    }

    private func rearm() {
        guard !isInvalidated else { return }
        queue.asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in
            guard let self, !self.isInvalidated else { return }
            if !self.startWatching() {
                self.queue.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
                    guard let self, !self.isInvalidated else { return }
                    _ = self.startWatching()
                }
            }
        }
    }

    private func changed() {
        guard !isInvalidated else { return }
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.isInvalidated else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isInvalidated else { return }
                self.callback()
            }
        }
        pending = item
        queue.asyncAfter(deadline: .now() + .milliseconds(180), execute: item)
    }
}
