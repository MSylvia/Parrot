import Cocoa
import Hangouts
import WebKit

// Existing Parrot Settings keys.
public class Parrot {
	public static let InterfaceStyle = "Parrot.InterfaceStyle"
	public static let SystemInterfaceStyle = "Parrot.SystemInterfaceStyle"
	
	public static let AutoEmoji = "Parrot.AutoEmoji"
	public static let InvertChatStyle = "Parrot.InvertChatStyle"
	public static let ShowSidebar = "Parrot.ShowSidebar"
	
	public static let VibrateForceTouch = "Parrot.VibrateForceTouch"
	public static let VibrateInterval = "Parrot.VibrateInterval"
	public static let VibrateLength = "Parrot.VibrateLength"
	
}

public let defaultUserImage = NSImage(named: "NSUserGuest")!

@NSApplicationMain
class ServiceManager: NSObject, NSApplicationDelegate {
	
	private var trans: WindowTransitionAnimator? = nil
	
	// First begin authentication and setup for any services.
	func applicationWillFinishLaunching(_ notification: Notification) {
		AppActivity.begin("Authenticate")
		Authenticator.authenticateClient {
			_hangoutsClient = Client(configuration: $0)
			_hangoutsClient?.connect()
			AppActivity.end("Authenticate")
			
			NotificationCenter.default()
				.addObserver(forName: Client.didConnectNotification, object: _hangoutsClient!, queue: nil) { _ in
					AppActivity.begin("Setup")
					_hangoutsClient!.buildUserConversationList { (userList, conversationList) in
						AppActivity.begin("Setup")
						_REMOVE.forEach {
							$0(userList, conversationList)
						}
					}
			}
			
			// Instantiate storyboard and controller and begin the UI from here.
			DispatchQueue.main.async {
				let vc = ConversationsViewController(nibName: "ConversationsViewController", bundle: nil)
				vc?.selectionProvider = { row in
					let vc2 = ConversationViewController(nibName: "ConversationViewController", bundle: nil)
					vc2?.representedObject = vc?.conversationList?.conversations[row]
					vc?.presentViewController(vc2!, animator: WindowTransitionAnimator { w in
						w.setFrame(NSRect(x: 0, y: 0, width: 480, height: 320), display: false, animate: true)
						w.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
						w.appearance = ParrotAppearance.current()
						w.enableRealTitlebarVibrancy()
						w.center()
					})
				}
				
				// The .titlebar material has no transluency in dark appearances, and
				// has a standard window gradient in light ones.
				self.trans = WindowTransitionAnimator { w in
					w.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
					w.appearance = ParrotAppearance.current()
					w.enableRealTitlebarVibrancy()
					w.setFrameAutosaveName("Conversations")
				}
				self.trans!.displayViewController(vc!)
			}
		}
	}
	
	// So clicking on the dock icon actually shows the window again.
	func applicationShouldHandleReopen(sender: NSApplication, flag: Bool) -> Bool {
		self.trans?.showWindow(nil)
		return true
	}
	
	// We need to provide a useful dock menu.
	/* TODO: Provide a dock menu for options. */
	func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
		return nil
	}
	
	@IBAction func logoutSelected(_ sender: AnyObject) {
		let cookieStorage = HTTPCookieStorage.shared()
		if let cookies = cookieStorage.cookies {
			for cookie in cookies {
				cookieStorage.deleteCookie(cookie)
			}
		}
		Authenticator.clearTokens();
		NSApplication.shared().terminate(self)
	}
}

// Private service points go here:
private var _hangoutsClient: Client? = nil

/* TODO: SHOULD NOT BE USED. */
public typealias _RM2 = (UserList, ConversationList) -> Void
public var _REMOVE = [_RM2]()

// In the future, this will be an extensible service point for all services.
public extension NSApplication {
	
	// Provides a global Hangouts.Client service point.
	public var hangoutsClient: Hangouts.Client? {
		get {
			return _hangoutsClient
		}
	}
}
