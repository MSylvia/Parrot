import Foundation

// Quick clone of Alamofire's Result class.
// Note: instead of isSuccess/isFailure, try: guard let _ = result.data else {}
public enum Result {
	case Success(NSData, NSURLResponse)
	case Failure(NSError, NSURLResponse)
	
	public var data: NSData? {
		switch self {
		case .Success(let (data, _)):
			return data
		case .Failure:
			return nil
		}
	}
	
	public var error: NSError? {
		switch self {
		case .Success:
			return nil
		case .Failure(let (error, _)):
			return error
		}
	}
	
	public var response: NSURLResponse? {
		switch self {
		case .Success(let (_, response)):
			return response
		case .Failure(let (_, response)):
			return response
		}
	}
}

public extension NSURLSession {
	
	/* TODO: Many different session task types are not supported yet. */
	public enum RequestType {
		case Data, UploadData(NSData), UploadFile(NSURL)
		//case Stream(NSInputStream), Download, DownloadResume(NSData)
	}
	
	// MUCH simpler utilities for working with data requests.
	// By default the request type will be data, and the task is auto-started.
	public func request(request: NSURLRequest, type: RequestType = .Data,
						start: Bool = true, handler: Result -> Void) -> NSURLSessionTask {
		let cb: (NSData?, NSURLResponse?, NSError?) -> Void = { data, response, error in
			if let error = error {
				handler(Result.Failure(error, response!))
			} else {
				handler(Result.Success(data!, response!))
			}
		}
							
		/* TODO: Transparently use a dispatch queue for each session here! */
		var task: NSURLSessionTask
		switch type {
		case .Data:
			task = self.dataTaskWithRequest(request, completionHandler: cb)
		case .UploadData(let data):
			task = self.uploadTaskWithRequest(request, fromData: data, completionHandler: cb)
		case .UploadFile(let url):
			task = self.uploadTaskWithRequest(request, fromFile: url, completionHandler: cb)
		//case .UploadStream(let stream):
		//	task = self.uploadTaskWithRequest(request, withStream: stream, completionHandler: cb)
		//case .Download:
		//	task = self.downloadTaskWithRequest(request, completionHandler: cb)
		//case .DownloadResume(let data):
		//	task = self.downloadTaskWithResumeData(data, completionHandler: cb)
		}
		
		if start {
			task.resume()
		}
		return task
	}
}

//
// For constructing URL escaped/encoded strings:
//

func escape(string: String) -> String {
	let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
	let subDelimitersToEncode = "!$&'()*+,;="
	
	let allowedCharacterSet = NSCharacterSet.URLQueryAllowedCharacterSet().mutableCopy() as! NSMutableCharacterSet
	allowedCharacterSet.removeCharactersInString(generalDelimitersToEncode + subDelimitersToEncode)
	
	var escaped = ""
	if #available(iOS 8.3, OSX 10.10, *) {
		escaped = string.stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacterSet) ?? string
	} else {
		let batchSize = 50
		var index = string.startIndex
		
		while index != string.endIndex {
			let startIndex = index
			let endIndex = index.advancedBy(batchSize, limit: string.endIndex)
			let range = Range(start: startIndex, end: endIndex)
			
			let substring = string.substringWithRange(range)
			
			escaped += substring.stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacterSet) ?? substring
			
			index = endIndex
		}
	}
	
	return escaped
}

func queryComponents(key: String, _ value: AnyObject) -> [(String, String)] {
	var components: [(String, String)] = []
	
	if let dictionary = value as? [String: AnyObject] {
		for (nestedKey, value) in dictionary {
			components += queryComponents("\(key)[\(nestedKey)]", value)
		}
	} else if let array = value as? [AnyObject] {
		for value in array {
			components += queryComponents("\(key)[]", value)
		}
	} else {
		components.append((escape(key), escape("\(value)")))
	}
	
	return components
}

func query(parameters: [String: AnyObject]) -> String {
	var components: [(String, String)] = []
	
	for key in parameters.keys.sort(<) {
		let value = parameters[key]!
		components += queryComponents(key, value)
	}
	
	return (components.map { "\($0)=\($1)" } as [String]).joinWithSeparator("&")
}