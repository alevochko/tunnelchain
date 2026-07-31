import Foundation

let service = HelperService()
let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
listener.delegate = service
listener.resume()

signal(SIGTERM) { _ in
  _ = ResetService.resetAll()
  exit(0)
}

dispatchMain()
