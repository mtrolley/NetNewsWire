//
//  Article.swift
//  Data
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class Article: Hashable {

	weak var account: Account?
	
	public let articleID: String // Unique database ID
	public let feedID: String // Likely a URL, but not necessarily
	public let uniqueID: String // Unique per feed (RSS guid, for example)
	public var title: String?
	public var contentHTML: String?
	public var contentText: String?
	public var url: String?
	public var externalURL: String?
	public var summary: String?
	public var imageURL: String?
	public var bannerImageURL: String?
	public var datePublished: Date?
	public var dateModified: Date?
	public var authors: [Author]?
	public var tags: Set<String>?
	public var attachments: [Attachment]?
	public var accountInfo: [String: Any]? //If account needs to store more data
	
	public var status: ArticleStatus?
	public let hashValue: Int

	public var feed: Feed? {
		get {
			return account?.existingFeed(with: feedID)
		}
	}

	public init(account: Account, articleID: String?, feedID: String, uniqueID: String, title: String?, contentHTML: String?, contentText: String?, url: String?, externalURL: String?, summary: String?, imageURL: String?, bannerImageURL: String?, datePublished: Date?, dateModified: Date?, authors: [Author]?, tags: Set<String>?, attachments: [Attachment]?, accountInfo: AccountInfo?) {
		
		self.account = account
		self.feedID = feedID
		self.uniqueID = uniqueID
		self.title = title
		self.contentHTML = contentHTML
		self.contentText = contentText
		self.url = url
		self.externalURL = externalURL
		self.summary = summary
		self.imageURL = imageURL
		self.bannerImageURL = bannerImageURL
		self.datePublished = datePublished
		self.dateModified = dateModified
		self.authors = authors
		self.tags = tags
		self.attachments = attachments
		self.accountInfo = accountInfo

		if let articleID = articleID {
			self.articleID = articleID
		}
		else {
			self.articleID = databaseIDWithString("\(feedID) \(uniqueID)")
		}

		self.hashValue = account.hashValue ^ self.articleID.hashValue
	}

	public class func ==(lhs: Article, rhs: Article) -> Bool {

		return lhs === rhs
	}
}

public extension Article {

	public var logicalDatePublished: Date? {
		get {
			return (datePublished ?? dateModified) ?? status?.dateArrived
		}
	}
}
