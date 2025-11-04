# Droply Linear Views Setup Guide

Quick setup guide to create all recommended views for managing Droply's development from MVP → TestFlight → Production.

⏱️ **Time to complete**: 10-15 minutes

---

## 🚀 Quick Setup Instructions

### How to Create a View in Linear:
1. Navigate to your Droply project
2. Press `F` to open filters
3. Apply the filters listed below
4. Press `Cmd/Ctrl + B` for Board view or `Cmd/Ctrl + L` for List view
5. Press `Option/Alt + V` to save the view
6. Name it as specified
7. Click the ⭐ star icon to pin to sidebar (optional)

---

## 📋 Views to Create (in order)

### 1. ⚡ Critical Path
**Purpose**: Start here every morning - see blocking tasks

**Setup:**
```
Filters:
- Label → is → Critical
- Status → is not → Done

View: List
Sort by: Priority (Urgent → Low)

Name: ⚡ Critical Path
Pin: ✅ YES
```

---

### 2. 🚀 MVP TestFlight Kanban
**Purpose**: Main workflow for TestFlight prep

**Setup:**
```
Filters:
- Label → is → MVP - TestFlight

View: Board
Group by: Status
Swimlanes: None (or Priority if you want)

Name: 🚀 MVP TestFlight Kanban
Pin: ✅ YES
```

**Display Options:**
- ✅ Show sub-issues
- ❌ Show empty groups (hide empty columns)

---

### 3. 📅 This Week Focus
**Purpose**: Daily planning - what needs attention now

**Setup:**
```
Filters:
- Project → is → Droply
- Status → is → In Progress OR Todo
- Priority → is → Urgent OR High

View: List
Sort by: Priority

Name: 📅 This Week Focus
Pin: ✅ YES
```

---

### 4. 🐛 Bug Fixes
**Purpose**: Track all bug-related work

**Setup:**
```
Filters:
- Label → is → Bug Fix
- Status → is not → Done

View: List
Sort by: Priority

Name: 🐛 Bug Fixes
Pin: ✅ YES
```

---

### 5. 🧪 Testing Dashboard
**Purpose**: Track all testing tasks

**Setup:**
```
Filters:
- Label → is → Testing

View: Board
Group by: Status
Swimlanes: Priority (shows priority lanes horizontally)

Name: 🧪 Testing Dashboard
Pin: Optional
```

**Pro tip**: Toggle swimlanes on/off with the Display Options menu

---

### 6. 📊 Launch Timeline
**Purpose**: See progress across both MVP and Production stages

**Setup:**
```
Filters:
- Project → is → Droply

View: Board
Group by: Status
Swimlanes: Label (this creates lanes for MVP vs Production)

Name: 📊 Launch Timeline
Pin: Optional
```

**Result**: You'll see columns for Backlog/Todo/In Progress/Done with rows for each label

---

### 7. 📦 Production Launch Kanban
**Purpose**: Track production-ready tasks (use after TestFlight)

**Setup:**
```
Filters:
- Label → is → Production Launch

View: Board
Group by: Status

Name: 📦 Production Launch Kanban
Pin: Optional (pin when you reach this stage)
```

---

### 8. ✨ Polish & UX
**Purpose**: Track polish and UX improvements

**Setup:**
```
Filters:
- Label → is → Polish

View: Board
Group by: Status

Name: ✨ Polish & UX
Pin: Optional
```

---

### 9. 🎯 Quick Wins
**Purpose**: Low-effort tasks for when you have 30 minutes

**Setup:**
```
Filters:
- Project → is → Droply
- Priority → is → Medium OR Low
- Status → is → Todo OR Backlog

View: List
Sort by: Updated at (most recent)

Name: 🎯 Quick Wins
Pin: Optional
```

---

### 10. 🔗 Dependency Tracker
**Purpose**: See what's blocking what

**Setup:**
```
Filters:
- Project → is → Droply
- Status → is → Backlog OR Todo

View: List
Sort by: Priority

Name: 🔗 Dependency Tracker
Pin: Optional
```

**Advanced**: Use Linear's "Blocked by" relationship feature to track dependencies between issues

---

## 🎯 Recommended Pinned Views (in sidebar order)

Pin these 4 views for daily use:
1. ⚡ Critical Path
2. 🚀 MVP TestFlight Kanban
3. 📅 This Week Focus
4. 🐛 Bug Fixes

Access others as needed from the Views menu.

---

## ⌨️ Keyboard Shortcuts Reference

| Action | Mac | Windows/Linux |
|--------|-----|---------------|
| Open filters | `F` | `F` |
| Board view | `Cmd + B` | `Ctrl + B` |
| List view | `Cmd + L` | `Ctrl + L` |
| Save view | `Option + V` | `Alt + V` |
| Command palette | `/` | `/` |
| Search issues | `Cmd + K` | `Ctrl + K` |

---

## 🎨 Display Options Tips

When in any view, click the **Display Options** icon (grid icon) to customize:

### Board View Options:
- **Group by**: Status, Priority, Assignee, Project, Cycle, etc.
- **Swimlanes**: Add a second dimension (creates horizontal rows)
- **Show empty groups**: Toggle to hide/show empty columns
- **Show sub-issues**: Toggle to show/hide sub-tasks
- **Card size**: Compact, Default, or Expanded

### List View Options:
- **Group by**: Same options as board
- **Properties**: Show/hide specific columns (Priority, Labels, Assignee, etc.)
- **Density**: Compact or Comfortable spacing

---

## 🔄 Suggested Daily Workflow

### Morning (5 min):
1. Check **⚡ Critical Path** - anything blocking you?
2. Review **📅 This Week Focus** - what's urgent today?
3. Move 1-3 tasks to "In Progress" in **🚀 MVP TestFlight Kanban**

### During work:
- Work from **🚀 MVP TestFlight Kanban** board
- Drag tasks across columns as you progress
- Update task status when completing work

### End of day (2 min):
1. Move completed tasks to "Done"
2. Check **🐛 Bug Fixes** - any new issues?
3. Plan tomorrow by reviewing **📅 This Week Focus**

### Weekly (15 min):
1. Review **📊 Launch Timeline** - overall progress check
2. Check **🧪 Testing Dashboard** - testing status
3. Look at **🎯 Quick Wins** - pick easy wins for next week
4. Triage new issues and assign priorities

---

## 🎯 Natural Language Filters (AI-Powered)

Linear supports natural language! Try these in the filter bar:

- "Show me urgent issues"
- "What's due this week"
- "Issues assigned to me"
- "High priority bugs"
- "In progress tasks"
- "Tasks updated today"

Just type naturally and Linear will interpret your intent!

---

## 🚀 Advanced: Custom Filter Examples

### Recently Updated Tasks:
```
Updated at → is within → Last 7 days
```

### Overdue Tasks:
```
Due date → is before → Today
Status → is not → Done
```

### Unassigned Critical Work:
```
Assignee → is → Unassigned
Priority → is → Urgent
```

### Beta Feedback Tasks (create this after TestFlight):
```
Created at → is after → [Your TestFlight Launch Date]
Labels → contains → Bug Fix OR Critical
```

---

## 📱 Mobile App Tips

The Linear mobile app syncs all your custom views!

- Swipe between pinned views
- Use the filter icon to access all views
- Quick actions: Swipe left on tasks to change status
- Pinned views appear in the bottom navigation

---

## 🎬 Next Steps

1. **Now**: Set up the 4 core pinned views (takes 5 min)
2. **This week**: Add the optional views as needed
3. **After TestFlight**: Create beta feedback filters
4. **Production phase**: Switch focus to Production Launch Kanban

---

## 💡 Pro Tips

1. **Use labels consistently**: They power your views
2. **Update task status frequently**: Keeps boards accurate
3. **Set priorities**: Helps filter views work correctly
4. **Star your most-used views**: Quick access from sidebar
5. **Use Cmd/Ctrl + K**: Quick jump to any issue
6. **Create cycles**: Group work into sprints (optional)

---

## 🔧 Troubleshooting

**View shows no tasks?**
- Check your filters - might be too restrictive
- Verify labels are applied to issues correctly
- Make sure you're in the right project

**Can't save view?**
- You need at least one filter applied
- Make sure you're in a project or team view, not "All Issues"

**View not showing in sidebar?**
- Click the star icon next to the view name to pin it

---

## 📊 View Organization Structure

```
📁 Your Sidebar (Pinned)
├── ⚡ Critical Path          (Check daily)
├── 🚀 MVP TestFlight Kanban  (Main workspace)
├── 📅 This Week Focus        (Daily planning)
└── 🐛 Bug Fixes             (Monitor regularly)

📁 Views Menu (Access as needed)
├── 🧪 Testing Dashboard
├── 📊 Launch Timeline
├── 📦 Production Launch Kanban
├── ✨ Polish & UX
├── 🎯 Quick Wins
└── 🔗 Dependency Tracker
```

---

## ✅ Completion Checklist

After setup, you should have:

- [ ] 4 core views created and pinned
- [ ] At least 6 optional views created
- [ ] Keyboard shortcuts memorized (F, Cmd/Ctrl+B, Cmd/Ctrl+L)
- [ ] Display options customized to your preference
- [ ] Mobile app installed and synced (optional)
- [ ] Daily workflow understood

---

**Need help?** Linear has great docs at https://linear.app/docs

**Questions about Droply tasks?** Refer to the main project board or issue descriptions.

Good luck with your MVP launch! 🚀
