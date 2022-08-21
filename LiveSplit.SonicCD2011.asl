// Autosplitter and in-game timer for Sonic CD (2011)
// Provides complete support for:
// - Sonic CD (retail Steam version)
// - Sonic CD  decompilations (every version based on RSDKv3)
// - Sonic CD Restored
// 
// Coding: Jujstme
// contacts: just.tribe@gmail.com
// Version: 1.3.1 (Aug 21st, 2022)

state("soniccd") {}
state("RSDKv3") {}
state("RSDKv3_64") {}
state("RSDKv3_HW") {}
state("RSDKv3_HW_64") {}
state("Sonic CD") {}
state("Sonic CD_64") {}
state("Restored") {}

init
{
    // Define main watcher variable
    vars.watchers = new MemoryWatcherList();
    var scanner = new SignatureScanner(game, modules.First().BaseAddress, modules.First().ModuleMemorySize);
    IntPtr ptr = IntPtr.Zero;
    IntPtr lea = IntPtr.Zero;
    Action<IntPtr> checkptr = (IntPtr addr) => { if (addr == IntPtr.Zero) throw new Exception("Sigscanning failed!"); };

    // Check if the string "Sonic CD" is readable in the MainModule
    ptr = scanner.Scan(new SigScanTarget("20 53 6F 6E 69 63 20 43 44"));
    checkptr(ptr);

    // Black magic for RSDKv3
    Func<int, int, int, bool, IntPtr> pointerPath = (int offset1, int offset2, int offset3, bool absolute) =>
    {
        switch (game.Is64Bit())
        {
            case true:
                if (offset1 == 0) return lea + offset3;
                int tempOffset = game.ReadValue<int>(ptr + offset1);
                IntPtr tempOffset2 = modules.First().BaseAddress + tempOffset + offset2;
                if (absolute) return modules.First().BaseAddress + game.ReadValue<int>(tempOffset2) + offset3;
                else return tempOffset2 + 0x4 + game.ReadValue<int>(tempOffset2) + offset3;
            default:
                return (IntPtr)new DeepPointer(ptr + offset1, offset2).Deref<int>(game) + offset3;
        }
    };

    // Placeholder for current status variables the script needs. Prevents LiveSplit from throwing unnecessary exceptions
    current.IGT = 0d;
    current.Act = 0xFF;
    current.FinalBossHp = 0xFF;
    vars.HasCentisecsBug = false;
    vars.CentisecsOffset = IntPtr.Zero;

    // This sigscan only works in the steam version of the game, so it can be used to differentiate if from the decompilation
    ptr = scanner.Scan(new SigScanTarget(12, "0F 87 ???????? 8B 45 D8 FF 24 85 ????????") { OnFound = (p, s, addr) => (IntPtr)p.ReadValue<int>(addr) });
    if (ptr != IntPtr.Zero)
    {
        version = "Retail (Steam)";
        vars.HasCentisecsBug = true;
        vars.watchers.Add(new MemoryWatcher<bool>(pointerPath(0x4 * 11,  0x9, 0x1AC,  true)) { Name = "DemoMode" });
        vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 19,  0x9, 0x1078, true)) { Name = "State" });
        vars.watchers.Add(new MemoryWatcher<int> (pointerPath(0x4 * 25,  0x9, 0x7D6,  true)) { Name = "TimeBonus" });
        vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 32,  0xB, 0x37C8, true)) { Name = "bhpGood" });
        vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 32,  0xB, 0x380C, true)) { Name = "bhpBad" });
        vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 120, 0x5, 0,      true)) { Name = "LevelID" });
        vars.watchers.Add(new MemoryWatcher<bool>(pointerPath(0x4 * 121, 0x3, 0,      true)) { Name = "TimerIsRunning" });
        vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 123, 0x3, 0,      true)) { Name = "seconds" });
        vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 124, 0x3, 0,      true)) { Name = "mins" });

        vars.CentisecsOffset = scanner.Scan(new SigScanTarget(3, "75 ?? A0 ???????? 04 01 A2 ???????? 0F B6") { OnFound = (p, s, addr) => (IntPtr)p.ReadValue<int>(addr) });;
        checkptr(vars.CentisecsOffset);
        vars.watchers.Add(new MemoryWatcher<byte>(vars.CentisecsOffset) { Name = "centisecs" });

        ptr = scanner.Scan(new SigScanTarget(3, "0F BE ?? ???????? 85 ?? 0F 84 ???????? A1") { OnFound = (p, s, addr) => (IntPtr)p.ReadValue<int>(addr) });
        checkptr(ptr);
        vars.watchers.Add(new MemoryWatcher<uint>(ptr) { Name = "ZoneIndicator" });
        return;
    }
    
    // Decompilation (RSDKv3)
    // At the time of writing (Aug 18th, 2022), sigscanning works for all versions of the decompilation
    version = "Decompilation (" + (game.Is64Bit() ? "64" : "32") + " bit)";
    switch (game.Is64Bit())
    {
        case true:
            ptr = scanner.Scan(new SigScanTarget(-4, "4C 03 F0 41 0F B6") { OnFound = (p, s, addr) => modules.First().BaseAddress + p.ReadValue<int>(addr) });
            checkptr(ptr);
            vars.watchers.Add(new MemoryWatcher<uint>(ptr) { Name = "ZoneIndicator" });

            ptr = scanner.Scan(new SigScanTarget(16, "81 F9 ???????? 0F 87 ???????? 41 8B 8C") { OnFound = (p, s, addr) => modules.First().BaseAddress + p.ReadValue<int>(addr) });
            checkptr(ptr);
            lea = scanner.Scan(new SigScanTarget(3, "48 8D 05 ???????? 49 63 F8 4C") { OnFound = (p, s, addr) => addr + 0x4 + p.ReadValue<int>(addr) });
            checkptr(lea);
            vars.watchers.Add(new MemoryWatcher<bool>(pointerPath(0x4 * 11,  7, 0x1AC,  true )) { Name = "DemoMode" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 0,   0, 0x10B2, false)) { Name = "State" });
            vars.watchers.Add(new MemoryWatcher<int> (pointerPath(0x4 * 0,   0, 0x814,  false)) { Name = "TimeBonus" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 0,   0, 0x37D0, false)) { Name = "bhpGood" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 0,   0, 0x3814, false)) { Name = "bhpBad" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 120, 2, 0,      false)) { Name = "LevelID" });
            vars.watchers.Add(new MemoryWatcher<bool>(pointerPath(0x4 * 121, 3, 0,      false)) { Name = "TimerIsRunning" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 122, 2, 0,      false)) { Name = "centisecs" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 123, 2, 0,      false)) { Name = "seconds" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 124, 2, 0,      false)) { Name = "mins" });
            break;

        case false:
            ptr = scanner.Scan(new SigScanTarget(12, "0F B6 ?? ???????? 89 ?? ?? 0F 85 ???????? 8A") { OnFound = (p, s, addr) => addr + p.ReadValue<int>(addr) + 0x4 + 0x2 });
            checkptr(ptr);
            vars.watchers.Add(new MemoryWatcher<uint>((IntPtr)game.ReadValue<int>(ptr)) { Name = "ZoneIndicator" });

            ptr = scanner.Scan(new SigScanTarget(14, "3D ???????? 0F 87 ???????? FF 24 85 ???????? A1") { OnFound = (p, s, addr) => (IntPtr)p.ReadValue<int>(addr) });
            checkptr(ptr);
            vars.watchers.Add(new MemoryWatcher<bool>(pointerPath(0x4 * 11,  0x3, 0x1AC,  true)) { Name = "DemoMode" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 19,  0xB, 0x1078, true)) { Name = "State" });
            vars.watchers.Add(new MemoryWatcher<int> (pointerPath(0x4 * 25,  0xA, 0x7F8,  true)) { Name = "TimeBonus" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 32,  0xA, 0x37C8, true)) { Name = "bhpGood" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 32,  0xA, 0x380C, true)) { Name = "bhpBad" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 120, 0x1, 0,      true)) { Name = "LevelID" });
            vars.watchers.Add(new MemoryWatcher<bool>(pointerPath(0x4 * 121, 0x3, 0,      true)) { Name = "TimerIsRunning" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 122, 0x1, 0,      true)) { Name = "centisecs" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 123, 0x1, 0,      true)) { Name = "seconds" });
            vars.watchers.Add(new MemoryWatcher<byte>(pointerPath(0x4 * 124, 0x1, 0,      true)) { Name = "mins" });
            break;
    }
}

startup
{
    // Basic settings
    settings.Add("centisecsBug", false, "Remove centiseconds from the timer when starting a new run");
    settings.SetToolTip("centisecsBug", "Partial mitigation of the centiseconds bug on the steam release of Sonic CD (2011).\nIf enabled, LiveSplit will automatizally set the centiseconds to 0 at the start of a new run.\nThis setting has no effect on any other release of the game.");
    settings.Add("RTA-TB", false, "Use All Time Stones timing rules");
    settings.SetToolTip("RTA-TB", "If enabled, LiveSplit's behaviour will be changed in order to reflect the different\ntiming rules used in the \"All Time Stones\" category:\n• RTA-TB (Time Bonus) will be used as Game Time instead of IGT\n• The final split will occur after the screen fades to white in Metallic Madness 3");
    settings.Add("autosplitting", true, "Autosplitting");

    string[][] actsName = {
        new string[] { "Palmtree Panic Act 1", "Palmtree Panic Act 1 - Past", "Palmtree Panic Act 1 - Good Future", "Palmtree Panic Act 1 - Bad Future" },
        new string[] { "Palmtree Panic Act 2", "Palmtree Panic Act 2 - Past", "Palmtree Panic Act 2 - Good Future", "Palmtree Panic Act 2 - Bad Future" },
        new string[] { "Palmtree Panic Act 3", "Palmtree Panic act 3 - Bad Future" },
        new string[] { "Collision Chaos Act 1", "Collision Chaos Act 1 - Past", "Collision Chaos Act 1 - Good Future", "Collision Chaos Act 1 - Bad Future" },
        new string[] { "Collision Chaos Act 2", "Collision Chaos Act 2 - Past", "Collision Chaos Act 2 - Good Future", "Collision Chaos Act 2 - Bad Future" },
        new string[] { "Collision Chaos Act 3", "Collision Chaos Act 3 - Bad Future"},
        new string[] { "Tidal Tempest Act 1", "Tidal Tempest Act 1 - Past", "Tidal Tempest Act 1 - Good Future", "Tidal Tempest Act 1 - Bad Future" },
        new string[] { "Tidal Tempest Act 2", "Tidal Tempest Act 2 - Past", "Tidal Tempest Act 2 - Good Future", "Tidal Tempest Act 2 - Bad Future" },
        new string[] { "Tidal Tempest Act 3", "Tidal Tempest Act 3 - Bad Future"},
        new string[] { "Quartz Quadrant Act 1", "Quartz Quadrant Act 1 - Past", "Quartz Quadrant Act 1 - Good Future", "Quartz Quadrant Act 1 - Bad Future" },
        new string[] { "Quartz Quadrant Act 2", "Quartz Quadrant Act 2 - Past", "Quartz Quadrant Act 2 - Good Future", "Quartz Quadrant Act 2 - Bad Future" },
        new string[] { "Quartz Quadrant Act 3", "Quartz Quadrant Act 3 - Bad Future" },
        new string[] { "Wacky Workbench Act 1", "Wacky Workbench Act 1 - Past", "Wacky Workbench Act 1 - Good Future", "Wacky Workbench Act 1 - Bad Future" },
        new string[] { "Wacky Workbench Act 2", "Wacky Workbench Act 2 - Past", "Wacky Workbench Act 2 - Good Future", "Wacky Workbench Act 2 - Bad Future" },
        new string[] { "Wacky Workbench Act 3", "Wacky Workbench Act 3 - Bad Future" },
        new string[] { "Stardust Speedway Act 1", "Stardust Speedway Act 1 - Past", "Stardust Speedway Act 1 - Good Future", "Stardust Speedway Act 1 - Bad Future" },
        new string[] { "Stardust Speedway Act 2", "Stardust Speedway Act 2 - Past", "Stardust Speedway Act 2 - Good Future", "Stardust Speedway Act 2 - Bad Future" },
        new string[] { "Stardust Speedway Act 3", "Stardust Speedway Act 3 - Bad Future" },
        new string[] { "Metallic Madness Act 1", "Metallic Madness Act 1 - Past", "Metallic Madness Act 1 - Good Future", "Metallic Madness Act 1 - Bad Future" },
        new string[] { "Metallic Madness Act 2", "Metallic Madness Act 2 - Past", "Metallic Madness Act 2 - Good Future", "Metallic Madness Act 2 - Bad Future" },
        new string[] { "Metallic Madness Act 3", "Metallic Madness Act 3 - Bad Future" }
    };
    vars.Acts = new Dictionary<byte, byte>();
    byte z = 0;
    for (byte i = 0; i < actsName.Length; i++)
    {
        for (byte j = 0; j < actsName[i].Length; j++)
            vars.Acts.Add(z++, i);
        settings.Add(i.ToString(), true, actsName[i][0], "autosplitting");
    }

    // ZoneIndicator - dummy name for a variable that essentially tells us whether we are playing or in one of the menus
    // Used to ignore act changes outside actual gameplay
    vars.ZoneIndicator = new Dictionary<string, uint>
    {
        { "Special Stage", 0x43455053u },
        { "Title Screen",  0x4C544954u },
        { "Main Menu",     0x4E49414Du },
        { "Time Attack",   0x454D4954u },
    };

    // Setting up a time bonus start value for RTA-TB timing method
    vars.TimeBonusStartValue = 0;

    // Functions we are gonna use in the script
    vars.Func = new ExpandoObject();
    vars.Func.StartTrigger = (Func<bool>)(() => vars.watchers["ZoneIndicator"].Current == vars.ZoneIndicator["Main Menu"] && vars.watchers["State"].Current == 7 && vars.watchers["State"].Old == 6);
    vars.Func.ResetTrigger = (Func<bool>)(() => vars.watchers["ZoneIndicator"].Current == vars.ZoneIndicator["Main Menu"] && vars.watchers["State"].Current == 5 && vars.watchers["State"].Changed);
    vars.Func.ResetIGTBuffers = (Action)(() => { vars.AccumulatedIGT = vars.BufferIGT = 0d; });
    vars.Func.IsInTimeBonus = (Func<bool>)(() => vars.TimeBonusStartValue != 0 && vars.watchers["TimeBonus"].Current != vars.TimeBonusStartValue);
    vars.Func.FindFinalBossHp = (Func<int>)(() => vars.watchers["LevelID"].Current == 68 ? vars.watchers["bhpGood"].Current : vars.watchers["LevelID"].Current == 69 ? vars.watchers["bhpBad"].Current : 0xFF);

    // Reset the IGT variables to generate them. Avoid throwing an exception later
    vars.Func.ResetIGTBuffers();
}

update
{
    // Update watchers
    vars.watchers.UpdateAll(game);

    // IGT definition
    // Must be 0 in Demo Mode
    // Must be 0 if the run has not started
    // Must not consider centisecs in case you are running a version of the game with the centisecs bug
    current.IGT = vars.watchers["DemoMode"].Current || vars.watchers["DemoMode"].Old || timer.CurrentPhase == TimerPhase.NotRunning ? 0d
        : !vars.watchers["TimerIsRunning"].Old && !vars.watchers["TimerIsRunning"].Current ? old.IGT
        : (double)vars.watchers["mins"].Current * 60 + (double)vars.watchers["seconds"].Current + (vars.HasCentisecsBug ? 0 : (double)vars.watchers["centisecs"].Current / 100 );
    
    // Reset the buffer IGT variables when the timer is stopped
    if (timer.CurrentPhase == TimerPhase.NotRunning)
        vars.Func.ResetIGTBuffers();

    if (current.IGT < old.IGT)
    {
        vars.AccumulatedIGT += old.IGT - vars.BufferIGT;
        vars.BufferIGT = current.IGT;
    }

    // Reset centisecs when starting a new run
    if (settings["centisecsBug"] && vars.HasCentisecsBug && vars.Func.StartTrigger())
        game.WriteValue<byte>((IntPtr)vars.CentisecsOffset, 0);

    // Time Bonus start value
    if (vars.watchers["TimeBonus"].Old == 0 && vars.watchers["TimeBonus"].Changed)
        vars.TimeBonusStartValue = vars.watchers["TimeBonus"].Current;
    else if (vars.watchers["TimeBonus"].Current == 0)
        vars.TimeBonusStartValue = 0;
}

split
{
    // If you're not inside a stage, there's no point in continuing
    foreach (var entry in vars.ZoneIndicator)
    {
        if (vars.watchers["ZoneIndicator"].Current == entry.Value)
            return false;
    }

    // Define current Act
    try { current.Act = vars.Acts[vars.watchers["LevelID"].Current]; } catch { current.Act = 0; }

    // Trigger a split when progressing loading a new stage
    if (current.Act == old.Act + 1)
        return settings[old.Act.ToString()];

    // Final boss split
    current.FinalBossHp = vars.Func.FindFinalBossHp();
    if (!settings["RTA-TB"] && old.FinalBossHp == 1 & current.FinalBossHp == 0 && current.IGT != 0)
        return settings["20"];
    // Final boss split in RTA-TB
    else if (settings["RTA-TB"] && old.Act == 20 && vars.watchers["LevelID"].Current == 1)
        return settings["20"];
}

gameTime
{
    if (!settings["RTA-TB"])
        return TimeSpan.FromSeconds(current.IGT + vars.AccumulatedIGT - vars.BufferIGT + (vars.HasCentisecsBug ? (double)vars.watchers["centisecs"].Current / 60 : 0));
}

start
{
    return vars.Func.StartTrigger();
}

reset
{
    return vars.Func.ResetTrigger();
}

isLoading
{
    return settings["RTA-TB"] ? vars.Func.IsInTimeBonus() : true;
}
