//
//  FeedInspectorViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Articles
import Account
import UserNotifications

@MainActor final class FeedInspectorViewController: NSViewController, Inspector {

	@IBOutlet weak var iconView: IconView!
	@IBOutlet weak var nameTextField: NSTextField?
	@IBOutlet weak var homePageURLTextField: NSTextField?
	@IBOutlet weak var urlTextField: NSTextField?
	@IBOutlet weak var isNotifyAboutNewArticlesCheckBox: NSButton!
	@IBOutlet weak var isReaderViewAlwaysOnCheckBox: NSButton?
	
	private var feed: Feed? {
		didSet {
			if feed != oldValue {
				updateUI()
			}
		}
	}

	private var userNotificationSettings: UNNotificationSettings?

	// MARK: Inspector

	let isFallbackInspector = false
	var objects: [Any]? {
		didSet {
			renameFeedIfNecessary()
			updateFeed()
		}
	}
	var windowTitle: String = NSLocalizedString("Feed Inspector", comment: "Feed Inspector window title")

	func canInspect(_ objects: [Any]) -> Bool {
		return objects.count == 1 && objects.first is Feed
	}

	// MARK: NSViewController

	override func viewDidLoad() {
		updateUI()
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: .DidUpdateFeedPreferencesFromContextMenu, object: nil)
	}
	
	override func viewDidAppear() {
		updateNotificationSettings()
	}
	
	override func viewDidDisappear() {
		renameFeedIfNecessary()
	}
	
	// MARK: Actions
	@IBAction func isNotifyAboutNewArticlesChanged(_ sender: Any) {
		guard userNotificationSettings != nil else  {
			DispatchQueue.main.async {
				self.isNotifyAboutNewArticlesCheckBox.setNextState()
			}
			return
		}
		
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			self.updateNotificationSettings()
			
			if settings.authorizationStatus == .denied {
				DispatchQueue.main.async {
					self.isNotifyAboutNewArticlesCheckBox.setNextState()
					self.showNotificationsDeniedError()
				}
			} else if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					self.feed?.shouldSendUserNotificationForNewArticles = (self.isNotifyAboutNewArticlesCheckBox?.state ?? .off) == .on ? true : false
				}
			} else {
				UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { (granted, error) in
					self.updateNotificationSettings()
					if granted {
						DispatchQueue.main.async {
							self.feed?.shouldSendUserNotificationForNewArticles = (self.isNotifyAboutNewArticlesCheckBox?.state ?? .off) == .on ? true : false
							NSApplication.shared.registerForRemoteNotifications()
						}
					} else {
						DispatchQueue.main.async {
							self.isNotifyAboutNewArticlesCheckBox.setNextState()
						}
					}
				}
			}
		}
	}
	
	@IBAction func isReaderViewAlwaysOnChanged(_ sender: Any) {
		feed?.isArticleExtractorAlwaysOn = (isReaderViewAlwaysOnCheckBox?.state ?? .off) == .on ? true : false
	}
	
	// MARK: Notifications

	@objc func imageDidBecomeAvailable(_ note: Notification) {
		updateImage()
	}
	
}

extension FeedInspectorViewController: NSTextFieldDelegate {

	func controlTextDidEndEditing(_ note: Notification) {
		renameFeedIfNecessary()
	}
	
}

private extension FeedInspectorViewController {

	func updateFeed() {
		guard let objects = objects, objects.count == 1, let singleFeed = objects.first as? Feed else {
			feed = nil
			return
		}
		feed = singleFeed
	}

	
	@objc func updateUI() {
		updateImage()
		updateName()
		updateHomePageURL()
		updateFeedURL()
		updateNotifyAboutNewArticles()
		updateIsReaderViewAlwaysOn()
		windowTitle = feed?.nameForDisplay ?? NSLocalizedString("Feed Inspector", comment: "Feed Inspector window title")
		isReaderViewAlwaysOnCheckBox?.isEnabled = true
		view.needsLayout = true
	}

	func updateImage() {
		guard let feed = feed, let iconView = iconView else {
			return
		}
		iconView.iconImage = IconImageCache.shared.imageForFeed(feed)
	}

	func updateName() {
		guard let nameTextField = nameTextField else {
			return
		}

		let name = feed?.editedName ?? feed?.name ?? ""
		if nameTextField.stringValue != name {
			nameTextField.stringValue = name
		}
	}

	func updateHomePageURL() {
		homePageURLTextField?.stringValue = feed?.homePageURL?.decodedURLString ?? ""
	}

	func updateFeedURL() {
		urlTextField?.stringValue = feed?.url.decodedURLString ?? ""
	}

	func updateNotifyAboutNewArticles() {
		isNotifyAboutNewArticlesCheckBox?.title = feed?.notificationDisplayName ?? NSLocalizedString("Show notifications for new articles", comment: "Show notifications for new articles")
		isNotifyAboutNewArticlesCheckBox?.state = (feed?.shouldSendUserNotificationForNewArticles ?? false) ? .on : .off
	}

	func updateIsReaderViewAlwaysOn() {
		isReaderViewAlwaysOnCheckBox?.state = (feed?.isArticleExtractorAlwaysOn ?? false) ? .on : .off
	}

	func updateNotificationSettings() {
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			self.userNotificationSettings = settings
			if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					NSApplication.shared.registerForRemoteNotifications()
				}
			}
		}
	}

	func showNotificationsDeniedError() {
		let updateAlert = NSAlert()
		updateAlert.alertStyle = .informational
		updateAlert.messageText = NSLocalizedString("Enable Notifications", comment: "Notifications")
		updateAlert.informativeText = NSLocalizedString("To enable notifications, open Notifications in System Preferences, then find NetNewsWire in the list.", comment: "To enable notifications, open Notifications in System Preferences, then find NetNewsWire in the list.")
		updateAlert.addButton(withTitle: NSLocalizedString("Open System Preferences", comment: "Open System Preferences"))
		updateAlert.addButton(withTitle: NSLocalizedString("Close", comment: "Close"))
		let modalResponse = updateAlert.runModal()
		if modalResponse == .alertFirstButtonReturn {
			NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
		}
	}

	func renameFeedIfNecessary() {

		guard let feed,
			  let account = feed.account,
			  let newName = nameTextField?.stringValue,
			  feed.nameForDisplay != newName else {
			return
		}
		
		Task {

			do {
				try await account.renameFeed(feed, to: newName)
				self.windowTitle = feed.nameForDisplay
			} catch {
				self.presentError(error)
			}
		}
	}
}
