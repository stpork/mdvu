import Foundation

final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private let callback: () -> Void
    private let queue = DispatchQueue(label: "com.mdv.file-watcher", qos: .utility)

    init?(url: URL, callback: @escaping () -> Void) {
        self.callback = callback
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete, .extend], queue: queue)
        source.setEventHandler { [weak self] in self?.changed() }
        source.setCancelHandler { close(fd) }
        self.source = source; source.resume()
    }
    deinit { source?.cancel() }
    private func changed() {
        pending?.cancel(); let item = DispatchWorkItem { [weak self] in DispatchQueue.main.async { self?.callback() } }
        pending = item; queue.asyncAfter(deadline: .now() + .milliseconds(180), execute: item)
    }
}
