import Foundation
import UIKit

enum State<T> {
    case Pending
    case Fulfilled(T)
    case Rejected(NSError)
}

class Promise<T> {
    var _handlers:(() -> Void)[] = []
    var _state:State<T> = .Pending

    var rejected:Bool {
        switch _state {
            case .Fulfilled, .Pending: return false
            case .Rejected: return true;
        }
    }
    var fulfilled:Bool {
        switch _state {
            case .Rejected, .Pending: return false
            case .Fulfilled: return true;
        }
    }
    var pending:Bool {
        switch _state {
            case .Rejected, .Fulfilled: return false
            case .Pending: return true;
        }
    }

    class func defer() -> (promise:Promise, fulfiller:(T) -> Void, rejecter:(NSError) -> Void) {
        var f: ((T) -> Void)?
        var r: ((NSError) -> Void)?
        let p = Promise{ f = $0; r = $1 }
        return (p, f!, r!)
    }

    init(_ body:(fulfiller:(T) -> Void, rejecter:(NSError) -> Void) -> Void) {

        func recurse() {
            assert(!pending)
            for handler in _handlers { handler() }
            _handlers.removeAll(keepCapacity: false)
        }

        let rejecter = { (err:NSError) -> Void in
            if self.pending {
                self._state = .Rejected(err);
                recurse();
            }
        }

        let fulfiller = { (obj:T) -> Void in
            if self.pending {
                self._state = .Fulfilled(obj);
                recurse()
            }
        }

        body(fulfiller, rejecter)
    }

    init(value:T) {
        self._state = .Fulfilled(value)
    }

    init(error:NSError) {
        self._state = .Rejected(error)
    }

    func then<U>(body:(T) -> U) -> Promise<U> {
        switch _state {
        case .Rejected(let error):
            return Promise<U>(error: error);
        case .Fulfilled(let value):
            return Promise<U>{ (fulfiller, rejecter) in
                let rv = body(value)
                if rv is NSError {
                    rejecter(rv as NSError)
                } else {
                    fulfiller(rv)
                }
            }
        case .Pending:
            return Promise<U>{ (fulfiller, rejecter) in
                self._handlers.append {
                    switch self._state {
                    case .Rejected(let error):
                        rejecter(error)
                    case .Fulfilled(let value):
                        fulfiller(body(value))
                    case .Pending:
                        abort()
                    }
                }
            }
        }
    }

    func then<U>(body:(T) -> Promise<U>) -> Promise<U> {
        switch _state {
        case .Rejected(let error):
            return Promise<U>(error: error);
        case .Fulfilled(let value):
            return body(value)
        case .Pending:
            return Promise<U>{ (fulfiller, rejecter) in
                self._handlers.append {
                    switch (self._state) {
                    case .Rejected(let error):
                        rejecter(error)
                    case .Fulfilled(let value):
                        body(value).then{ obj -> Void in
                            fulfiller(obj)
                        }
                    case .Pending:
                        abort()
                    }
                }
            }
        }
    }

    func catch(body:(NSError) -> T) -> Promise<T> {
        switch _state {
        case .Fulfilled(let value):
            return Promise(value:value)
        case .Rejected(let error):
            return Promise(value:body(error))
        case .Pending:
            return Promise<T>{ (fulfiller, rejecter) in
                self._handlers.append {
                    switch self._state {
                    case .Fulfilled(let value):
                        fulfiller(value)
                    case .Rejected(let error):
                        fulfiller(body(error))
                    case .Pending:
                        abort()
                    }
                }
            }
        }
    }

    func catch(body:(NSError) -> Void) -> Void {
        //TODO determine if this is actually needed

        switch _state {
        case .Rejected(let error):
            body(error)
        case .Fulfilled:
            let noop = 0
        case .Pending:
            self._handlers.append{
                switch self._state {
                    case .Rejected(let error):
                        body(error)
                    case .Fulfilled:
                        let noop = 0
                    case .Pending:
                        abort()
                }
            }
        }
    }

    func finally(body:() -> Void) -> Promise<T> {
        switch _state {
        case .Rejected(let error):
            body()
            return Promise(error: error)
        case .Fulfilled(let value):
            body()
            return Promise(value: value)
        case .Pending:
            return Promise { (fulfiller, rejecter) in
                self._handlers.append{
                    body()
                    switch self._state {
                    case .Fulfilled(let value):
                        fulfiller(value)
                    case .Rejected(let error):
                        rejecter(error)
                    case .Pending:
                        abort()
                    }
                }
            }
        }
    }
}
