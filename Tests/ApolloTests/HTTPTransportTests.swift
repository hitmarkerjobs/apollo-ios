//
//  HTTPTransportTests.swift
//  ApolloTests
//
//  Created by Ellen Shapiro on 7/1/19.
//  Copyright © 2019 Apollo GraphQL. All rights reserved.
//

import XCTest
@testable import Apollo
import StarWarsAPI

class HTTPTransportTests: XCTestCase {
  
  private var updatedHeaders: [String: String]?
  private var shouldSend = true
  
  private var completedRequest: URLRequest?
  private var completedData: Data?
  private var completedResponse: URLResponse?
  private var completedError: Error?

  private lazy var url = URL(string: "http://localhost:8080/graphql")!
  private lazy var networkTransport = HTTPNetworkTransport(url: self.url,
                                                           useGETForQueries: true,
                                                           preflightDelegate: self,
                                                           requestCompletionDelegate: self)
  
  func testPreflightDelegateTellingRequestNotToSend() {
    self.shouldSend = false
    
    let expectation = self.expectation(description: "Send operation completed")
    let cancellable = self.networkTransport.send(operation: HeroNameQuery(episode: .empire)) { response, error in
      
      defer {
        expectation.fulfill()
      }
      
      guard let error = error else {
        XCTFail("Expected error not received when telling delegate not to send!")
        return
      }
      
      switch error {
      case GraphQLHTTPRequestError.cancelledByDeveloper:
        // Correct!
        break
      default:
        XCTFail("Expected `cancelledByDeveloper`, got \(error)")
      }
    }
    
    guard (cancellable as? EmptyCancellable) != nil else {
      XCTFail("Wrong cancellable type returned!")
      cancellable.cancel()
      expectation.fulfill()
      return
    }
    
    // This should fail without hitting the network.
    self.wait(for: [expectation], timeout: 1)
    
    // The request shouldn't have fired, so all these objects should be nil
    XCTAssertNil(self.completedRequest)
    XCTAssertNil(self.completedData)
    XCTAssertNil(self.completedResponse)
    XCTAssertNil(self.completedError)
  }
  
  func testPreflightDelgateModifyingRequest() {
    self.updatedHeaders = ["Authorization": "Bearer HelloApollo"]

    let expectation = self.expectation(description: "Send operation completed")
    let cancellable = self.networkTransport.send(operation: HeroNameQuery()) { (response, error) in
      
      defer {
        expectation.fulfill()
      }
      
      if let responseError = error as? GraphQLHTTPResponseError {
        print(responseError.bodyDescription)
        XCTFail("Error!")
        return
      }
      
      guard let queryResponse = response else {
        XCTFail("No response!")
        return
      }
      
      guard
        let dictionary = queryResponse.body as? [String: AnyHashable],
        let dataDict = dictionary["data"] as? [String: AnyHashable],
        let heroDict = dataDict["hero"] as? [String: AnyHashable],
        let name = heroDict["name"] as? String else {
          XCTFail("No hero for you!")
          return
      }
      
      XCTAssertEqual(name, "R2-D2")
    }
    
    guard
      let task = cancellable as? URLSessionTask,
      let headers = task.currentRequest?.allHTTPHeaderFields else {
        cancellable.cancel()
        expectation.fulfill()
        return
    }
    
    XCTAssertEqual(headers["Authorization"], "Bearer HelloApollo")
    
    // This will come through after hitting the network.
    self.wait(for: [expectation], timeout: 10)
    
    // We should have everything except an error since the request should have proceeded
    XCTAssertNotNil(self.completedRequest)
    XCTAssertNotNil(self.completedData)
    XCTAssertNotNil(self.completedResponse)
    XCTAssertNil(self.completedError)
  }
  
  func testPreflightDelegateNeitherModifyingOrStoppingRequest() {
    let expectation = self.expectation(description: "Send operation completed")
    let cancellable = self.networkTransport.send(operation: HeroNameQuery()) { (response, error) in
      
      defer {
        expectation.fulfill()
      }
      
      if let responseError = error as? GraphQLHTTPResponseError {
        print(responseError.bodyDescription)
        XCTFail("Error!")
        return
      }
      
      guard let queryResponse = response else {
        XCTFail("No response!")
        return
      }
      
      guard
        let dictionary = queryResponse.body as? [String: AnyHashable],
        let dataDict = dictionary["data"] as? [String: AnyHashable],
        let heroDict = dataDict["hero"] as? [String: AnyHashable],
        let name = heroDict["name"] as? String else {
          XCTFail("No hero for you!")
          return
      }
      
      XCTAssertEqual(name, "R2-D2")
    }
    
    guard
      let task = cancellable as? URLSessionTask,
      let headers = task.currentRequest?.allHTTPHeaderFields else {
        cancellable.cancel()
        expectation.fulfill()
        return
    }
    
    XCTAssertNil(headers["Authorization"])
    
    // This will come through after hitting the network.
    self.wait(for: [expectation], timeout: 10)
    
    // We should have everything except an error since the request should have proceeded
    XCTAssertNotNil(self.completedRequest)
    XCTAssertNotNil(self.completedData)
    XCTAssertNotNil(self.completedResponse)
    XCTAssertNil(self.completedError)
  }
}

extension HTTPTransportTests: HTTPNetworkTransportPreflightDelegate {
  func networkTransport(_ networkTransport: HTTPNetworkTransport, shouldSend request: URLRequest) -> Bool {
    return self.shouldSend
  }
  
  func networkTransport(_ networkTransport: HTTPNetworkTransport, willSend request: inout URLRequest) {
    guard let headers = self.updatedHeaders else {
      // Don't modify anything
      return
    }
    
    headers.forEach { tuple in
      let (key, value) = tuple
      var headers = request.allHTTPHeaderFields ?? [String: String]()
      headers[key] = value
      request.allHTTPHeaderFields = headers
    }
  }
}

extension HTTPTransportTests: HTTPNetworkTransportTaskCompletedDelegate {
  
  func networkTransport(_ networkTransport: HTTPNetworkTransport, completedRequest request: URLRequest, withData data: Data?, response: URLResponse?, error: Error?) {
    self.completedRequest = request
    self.completedData = data
    self.completedResponse = response
    self.completedError = error
  }
}
