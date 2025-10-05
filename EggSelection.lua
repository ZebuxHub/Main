# 🚀 Quick Reference - EggSelection Auto-Update

## 📝 What Changed (สรุปสั้นๆ)

```
❌ BEFORE: Hardcoded egg data
✅ AFTER:  Auto-loads from game.ReplicatedStorage.Config.ResEgg
```

---

## 🎯 Key Features (ฟีเจอร์หลัก)

| Feature | Description |
|---------|-------------|
| 🔄 Auto-Load | Loads eggs from game automatically |
| 🛡️ Safe | Preserves your old selections |
| ✨ Dynamic | New eggs appear automatically |
| 🧹 Clean | Removes deleted eggs automatically |

---

## 💻 Usage (วิธีใช้)

### Basic (พื้นฐาน)
```lua
local EggSelection = require(script.EggSelection)
EggSelection.Show(callback, toggleCallback)
```

### With Saved Data (พร้อมข้อมูลเก่า)
```lua
EggSelection.Show(callback, toggleCallback, savedEggs, savedMutations, savedOrder)
```

### Reload Data (โหลดใหม่)
```lua
EggSelection.ReloadEggData()
```

### Get Current Data (ดูข้อมูลปัจจุบัน)
```lua
local eggData = EggSelection.GetEggData()
```

---

## 🔄 Data Flow (การไหลของข้อมูล)

```
Game Module → LoadEggDataFromGame() → EggData → UI
```

---

## 🛡️ Selection Safety (ความปลอดภัยของการเลือก)

| Scenario | Result |
|----------|--------|
| Egg still exists | ✅ Selection kept |
| Egg removed | ❌ Selection removed (safe) |
| New egg added | ✨ Appears in UI |
| Mutation | ✅ Always kept |

---

## 📊 Data Format (รูปแบบข้อมูล)

### Game Format (จากเกม)
```lua
{
    ID = "BasicEgg",
    Price = 100,
    Icon = "rbxassetid://...",
    Rarity = 1,
    Evolution = false
}
```

### UI Format (ใน UI)
```lua
{
    Name = "BasicEgg",
    Price = 100,
    Icon = "rbxassetid://...",
    Rarity = 1,
    IsNew = false
}
```

---

## 🎯 Functions (ฟังก์ชัน)

### LoadEggDataFromGame()
- **Purpose:** Load eggs from game
- **Returns:** Table of egg data
- **Called:** On script start

### ReloadEggData()
- **Purpose:** Refresh egg data
- **Returns:** Boolean (success)
- **Called:** Manually when needed

### GetEggData()
- **Purpose:** Get current egg data
- **Returns:** EggData table
- **Called:** For debugging

---

## ⚡ Quick Tips (เคล็ดลับด่วน)

1. **Old selections are safe** - They're preserved automatically
2. **New eggs appear automatically** - No code update needed
3. **Deleted eggs are cleaned up** - Prevents errors
4. **Can reload anytime** - Call `ReloadEggData()`

---

## 🐛 Troubleshooting (แก้ปัญหาด่วน)

| Problem | Solution |
|---------|----------|
| No eggs showing | Check `ReplicatedStorage.Config.ResEgg` |
| Old selections gone | Eggs were removed from game (normal) |
| New eggs not showing | Call `ReloadEggData()` |

---

## ✅ Checklist (เช็คลิสต์)

- [x] Removed hardcoded egg data
- [x] Added auto-load from game
- [x] Added selection preservation
- [x] Added reload function
- [x] Added error handling
- [x] Tested with saved data

---

## 🎉 Benefits (ประโยชน์)

```
✅ No manual updates
✅ Always up-to-date
✅ Safe selections
✅ Easy to use
✅ Future-proof
```

---

## 📞 Quick Help (ช่วยเหลือด่วน)

### Check if data loaded
```lua
local data = EggSelection.GetEggData()
print("Eggs loaded:", #data)
```

### Force reload
```lua
local success = EggSelection.ReloadEggData()
print("Reload success:", success)
```

### Debug selections
```lua
local selections = EggSelection.GetCurrentSelections()
for id, _ in pairs(selections) do
    print("Selected:", id)
end
```

---

## 🚀 That's It! (เท่านี้เอง!)

**Just use it normally, everything works automatically!**
**แค่ใช้งานตามปกติ ทุกอย่างทำงานอัตโนมัติ!**

---

## 📚 Full Documentation

- `EGG_SELECTION_AUTO_UPDATE.md` - Full guide (English + Thai)
- `HOW_IT_WORKS_VISUAL.md` - Visual diagrams
- `คำอธิบายภาษาไทย.md` - Thai explanation
- `EXAMPLE_USAGE.lua` - Code examples
