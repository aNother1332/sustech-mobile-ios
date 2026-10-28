import Foundation

public enum CurriculumPolicy {
    public static func showCompleteBook(_ profile: StudentProfile) -> Bool {
        profile.major.isEmpty || profile.major == "通识通修" || profile.department == "通识与学科基础部"
    }
    public static func matches(title: String, major: String) -> Bool {
        guard !major.isEmpty else { return false }
        let name = major.replacingOccurrences(of: "专业", with: "").filter { !$0.isWhitespace }
        return title.filter { !$0.isWhitespace }.contains(name + "专业")
    }
}
