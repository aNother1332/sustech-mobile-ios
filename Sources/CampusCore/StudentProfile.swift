import Foundation

public struct StudentProfile: Codable, Sendable, Equatable {
    public let name: String
    public let studentID: String
    public let major: String
    public let department: String
    public let college: String
    public var isEmpty: Bool { [name, studentID, major, department, college].allSatisfy(\.isEmpty) }
    public init(name: String = "", studentID: String = "", major: String = "", department: String = "", college: String = "") {
        self.name = name; self.studentID = studentID; self.major = major; self.department = department; self.college = college
    }
    public func merging(_ other: StudentProfile) -> StudentProfile {
        StudentProfile(name: other.name.isEmpty ? name : other.name,
            studentID: other.studentID.isEmpty ? studentID : other.studentID,
            major: other.major.isEmpty ? major : other.major,
            department: other.department.isEmpty ? department : other.department,
            college: other.college.isEmpty ? college : other.college)
    }
    public static func parse(_ value: WireValue) -> StudentProfile {
        let row = value["data"].fields.isEmpty ? value : value["data"]
        func first(_ keys: [String]) -> String { keys.map { row[$0].text.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? "" }
        // An opaque id/yhdm is not necessarily a student number.
        return StudentProfile(name: first(["xm", "XM", "realName", "displayName", "yhmc"]),
            studentID: first(["xh", "XH", "studentId", "studentNumber"]),
            major: first(["zymc", "ZYMC", "majorName"]), department: first(["yxmc", "YXMC", "bmmc", "departmentName"]),
            college: first(["symc", "SYMC", "collegeName"]))
    }
}
