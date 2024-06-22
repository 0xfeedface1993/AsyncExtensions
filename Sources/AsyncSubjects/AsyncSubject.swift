//
//  AsyncSubject.swift
//  
//
//  Created by Thibault Wittemberg on 08/01/2022.
//

#if swift(>=5.9)
public protocol AsyncSubjectable: AnyObject, AsyncSequence, Sendable where AsyncIterator: AsyncSubjectIterator {
    func send(_ element: Element)
}

public protocol AsyncSubjectTerminator {
    associatedtype Failure: Error
    
    func send(_ termination: Termination<Failure>)
}

public typealias AsyncSubject = AsyncSubjectable & AsyncSubjectTerminator

#elseif swift(>=5.7)
public protocol AsyncSubject<Element, Failure>: AnyObject, AsyncSequence, Sendable where AsyncIterator: AsyncSubjectIterator {
  associatedtype Failure: Error

  func send(_ element: Element)
  func send(_ termination: Termination<Failure>)
}
#else
public protocol AsyncSubject: AnyObject, AsyncSequence, Sendable where AsyncIterator: AsyncSubjectIterator {
  associatedtype Failure: Error

  func send(_ element: Element)
  func send(_ termination: Termination<Failure>)
}
#endif

public protocol AsyncSubjectIterator: AsyncIteratorProtocol, Sendable {
  var hasBufferedElements: Bool { get }
}
