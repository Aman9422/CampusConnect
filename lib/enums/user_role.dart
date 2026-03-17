/// v7.1: Role-based access control
enum UserRole {
  student,
  alumni,
  teacher;

  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.alumni:
        return 'Alumni';
      case UserRole.teacher:
        return 'Teacher';
    }
  }

  String get description {
    switch (this) {
      case UserRole.student:
        return 'Currently enrolled student';
      case UserRole.alumni:
        return 'Graduate & working professional';
      case UserRole.teacher:
        return 'Faculty & academic staff';
    }
  }

  IconLabel get icon {
    switch (this) {
      case UserRole.student:
        return IconLabel.school;
      case UserRole.alumni:
        return IconLabel.workOutline;
      case UserRole.teacher:
        return IconLabel.historyEdu;
    }
  }

  static UserRole? fromString(String? value) {
    if (value == null) return null;
    return UserRole.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Icon identifiers for roles (avoids importing flutter/material in enum file)
enum IconLabel { school, workOutline, historyEdu }
