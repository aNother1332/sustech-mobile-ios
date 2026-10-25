import Foundation

public enum AutomaticLoginPolicy {
    /// An unavailable service is not evidence of expiry. Never loop on network errors.
    public static func shouldAttempt(hasCredentials: Bool, paused: Bool, confirmedExpired: Bool, lastAttempt: Date?, now: Date = .now) -> Bool {
        hasCredentials && !paused && confirmedExpired && (lastAttempt == nil || now.timeIntervalSince(lastAttempt!) > 300)
    }
}
