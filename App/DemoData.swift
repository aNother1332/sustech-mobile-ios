import CampusCore
import Foundation

enum DemoData {
    static let teaching = TeachingSnapshot(
        semester: Semester(year: "2026-2027", term: "1", name: "示例学期"), week: 8,
        meetings: [
            CourseMeeting(id: "demo-1", name: "线性代数", details: "示例教师 · 第一教学楼 203",
                          weekday: 1, firstPeriod: 1, lastPeriod: 2),
            CourseMeeting(id: "demo-2", name: "程序设计基础", details: "示例教师 · 第二教学楼 105",
                          weekday: 2, firstPeriod: 3, lastPeriod: 4),
            CourseMeeting(id: "demo-3", name: "大学物理", details: "示例教师 · 第一教学楼 302",
                          weekday: 3, firstPeriod: 5, lastPeriod: 6),
            CourseMeeting(id: "demo-4", name: "学术英语", details: "示例教师 · 语言中心",
                          weekday: 5, firstPeriod: 3, lastPeriod: 4)
        ],
        exams: [CampusExam(id: "demo-exam", course: "线性代数 · 示例考试", date: "2026-11-06",
                           time: "14:00–16:00", room: "第一教学楼 203", seat: "待公布")]
    )

    static var blackboard: BlackboardSnapshot {
        BlackboardSnapshot(courses: [
            BlackboardCourse(id: "demo-math", name: "线性代数"),
            BlackboardCourse(id: "demo-cs", name: "程序设计基础")
        ], deadlines: [
            LearningDeadline(id: "demo-ddl-1", course: "线性代数", title: "习题集 04 · 示例任务",
                             due: .now.addingTimeInterval(86_400), rawDue: "示例时间", courseID: "demo-math"),
            LearningDeadline(id: "demo-ddl-2", course: "程序设计基础", title: "实验报告 · 示例任务",
                             due: .now.addingTimeInterval(3 * 86_400), rawDue: "示例时间", courseID: "demo-cs")
        ])
    }
}
