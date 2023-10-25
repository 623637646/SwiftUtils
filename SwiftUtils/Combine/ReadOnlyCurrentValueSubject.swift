//
//  ReadOnlyCurrentValueSubject.swift
//  OneKey-Swift
//
//  Created by Wang Ya on 22/8/23.
//

import Foundation
import Combine


/// CurrentValueSubject is readable and writable, ReadOnlyCurrentValueSubjectis only writable in the current module. It's not writable outside the current module.
final public class ReadOnlyCurrentValueSubject<Output, Failure> : Publisher where Failure : Error {
    
    private let currentValueSubject: CurrentValueSubject<Output, Failure>
    
    init(_ value: Output) {
        self.currentValueSubject = CurrentValueSubject(value)
    }
    
    init(_ currentValueSubject: CurrentValueSubject<Output, Failure>){
        self.currentValueSubject = currentValueSubject
    }
    
    private var cancellables = Set<AnyCancellable>()
    convenience init(value: Output, publisher: some Publisher<Output, Failure>){
        self.init(value)
        publisher.sink { [weak self] completion in
            self?.currentValueSubject.send(completion: completion)
        } receiveValue: { [weak self] value in
            self?.currentValueSubject.value = value
        }.store(in: &cancellables)

    }
        
    final public internal(set) var value: Output {
        get {
            return currentValueSubject.value
        }
        set {
            currentValueSubject.value = newValue
        }
    }
    
    final public func receive<S>(subscriber: S) where Output == S.Input, Failure == S.Failure, S : Subscriber {
        self.currentValueSubject.receive(subscriber: subscriber)
    }
    
}
