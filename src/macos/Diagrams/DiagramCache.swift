import Foundation

// Both hosts use Rust's cache validation, hashing and atomic storage. Only queue
// scheduling belongs to the native UI: it must never wait for optional I/O.
enum DiagramCache {
    private static let writeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    @MainActor static func enqueueWrite(key: String, svg: String) {
        guard writeQueue.operationCount < 2 else { return }
        writeQueue.addOperation { MdvuCoreBridge.shared.writeDiagramCache(key: key, svg: svg) }
    }
}
