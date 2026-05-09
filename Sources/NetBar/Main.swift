import AppKit

@MainActor
private var appDelegate: AppDelegate?

@main
enum NetBarMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        application.delegate = delegate
        application.run()
    }
}
