import CloudKit
import Foundation

/// Turns CloudKit share failures into sentences a child could read.
/// The raw error, including any share URL, stays out of these strings.
public enum PodJoin {
    public static let ownInvite = "That's your own pod invite — send it to a friend to have them join!"

    /// True when this person owns the share, so accepting it would be rejected.
    public static func isOwnInvite(role: CKShare.ParticipantRole, ownerRecordName: String?, currentRecordName: String?) -> Bool {
        if role == .owner { return true }
        guard let owner = ownerRecordName, let current = currentRecordName, !owner.isEmpty, !current.isEmpty else { return false }
        return owner == current
    }

    /// Fallback when accept is attempted anyway. CloudKit reports this as a server rejection
    /// whose text says the owner participant tried to accept the share.
    public static func isOwnerAccept(_ error: Error) -> Bool {
        let text = blob(error).lowercased()
        if text.contains("owner participant") { return true }
        if text.contains("tried to accept") && text.contains("owner") { return true }
        if let ck = error as? CKError {
            return partials(ck).contains { isOwnerAccept($0) }
        }
        return false
    }

    /// The invite was already accepted by this iCloud account.
    public static func isAlreadyParticipant(_ error: Error) -> Bool {
        let text = blob(error).lowercased()
        if text.contains("already accepted") { return true }
        if text.contains("already a participant") { return true }
        if text.contains("participant is already") { return true }
        if let ck = error as? CKError {
            return partials(ck).contains { isAlreadyParticipant($0) }
        }
        return false
    }

    /// A sentence safe to show. `joining` is the invite-link path, where a missing share means the invite is gone.
    public static func message(for error: Error, joining: Bool = false) -> String {
        let text = sentence(for: error, joining: joining)
        if text.contains("http") || text.contains("://") { return fallback }
        return text
    }

    private static let fallback = "Something went wrong with iCloud. Please try again."

    private static func sentence(for error: Error, joining: Bool) -> String {
        if isOwnerAccept(error) { return ownInvite }
        if isAlreadyParticipant(error) { return "You're already in this pod." }
        guard let ck = error as? CKError else { return fallback }
        switch ck.code {
        case .notAuthenticated:
            return "Sign in to iCloud to use pods."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return "The internet isn't available right now. Try again in a little while."
        case .quotaExceeded:
            return "iCloud storage is full, so this couldn't be saved."
        case .zoneNotFound, .userDeletedZone:
            return "That pod no longer exists."
        case .unknownItem:
            return joining
                ? "That invite has been cancelled, or the pod no longer exists."
                : "Pods aren't set up on iCloud yet for this version. Please try again later."
        case .permissionFailure:
            return "You don't have permission to change this pod."
        case .partialFailure:
            if let first = partials(ck).first { return sentence(for: first, joining: joining) }
            return "Some pod changes couldn't be saved."
        default:
            return fallback
        }
    }

    private static func partials(_ error: CKError) -> [Error] {
        var found: [Error] = []
        if let parts = error.partialErrorsByItemID?.values {
            found.append(contentsOf: parts)
        }
        if let raw = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            found.append(contentsOf: raw.values)
        }
        return found
    }

    private static func blob(_ error: Error) -> String {
        var bits = [error.localizedDescription]
        let ns = error as NSError
        if let under = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            bits.append(blob(under))
        }
        if let ck = error as? CKError {
            bits.append(contentsOf: partials(ck).map(blob))
        }
        return bits.joined(separator: " ")
    }
}
