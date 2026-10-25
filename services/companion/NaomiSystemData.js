// Данные системных реплик Naomi: списки приложений, пороги, кулдауны, приоритеты. Правьте здесь.
// Логика (кто, когда, в каком порядке) живёт в NaomiSystemEvents.js и ничего из этих чисел не зашивает.
// Тексты реплик — в NaomiLines.js (раздел system).
var data = {
    // Минимальный интервал между любыми двумя системными репликами, секунды. Для срочных (priority 3) — меньше.
    globalGap: 45,
    urgentGap: 10,
    // Сколько секунд после (пере)подключения к niri окна считаются «уже были»: приложения, открытые
    // до запуска оболочки, не вызывают реплик.
    windowGrace: 3,
    // Окно считается новым и тогда, когда app_id у него появился в течение стольких секунд после открытия.
    windowNewAge: 4,
    // Не говорить сразу после запуска оболочки, чтобы не наступать на приветствие, секунды.
    startupQuiet: 20,

    // Свойства каждого вида: priority (3 срочно, 2 важно, 1 болтовня), cooldown (секунды между репликами
    // этого вида), expire (сколько секунд повод ждёт своей очереди, потом он устаревает).
    kinds: {
        battery:  { priority: 3, cooldown: 0,     expire: 120 },
        offline:  { priority: 3, cooldown: 600,   expire: 120 },
        update:   { priority: 2, cooldown: 1800,  expire: 90 },
        cpu:      { priority: 2, cooldown: 1200,  expire: 60 },
        game:     { priority: 2, cooldown: 1800,  expire: 30 },
        terminal: { priority: 1, cooldown: 900,   expire: 30 },
        windows:  { priority: 1, cooldown: 1800,  expire: 60 },
        idle:     { priority: 1, cooldown: 1800,  expire: 30 },
        return:   { priority: 1, cooldown: 600,   expire: 20 },
        // Раз за ночь: кулдаун здесь — страховка, главное правило — ключ ночи (nightKey).
        night:    { priority: 1, cooldown: 21600, expire: 300 }
    },

    // Высокая нагрузка CPU: среднее за окно не меньше enter — повод; снова взводится, когда среднее упало до exit.
    cpu: { window: 30, enter: 0.85, exit: 0.6 },

    // Бездействие: через idleLong секунд без ввода — реплика «смотришь в экран»;
    // первое действие после idleAway секунд без ввода — реплика «вернулся».
    idleLong: 600,
    idleAway: 60,

    // Окон больше windowsLimit (то есть windowsLimit + 1 и выше) — повод при пересечении вверх.
    windowsLimit: 5,

    // Ночь: местные часы с from по to включительно (00:00–05:59).
    night: { from: 0, to: 5 },

    // Батарея: пороги в процентах, по одной реплике на порог, пока не зарядили. Заново взводится при
    // зарядке или когда заряд поднялся выше rearm.
    battery: { levels: [20, 10, 5], rearm: 25 },

    // Интернет: повод только после стольких секунд устойчивой потери и только если до этого он был.
    offlineAfter: 8,

    // Обновление системы: как часто смотреть процессы, секунды, и файл блокировки pacman.
    updatePoll: 4,
    pacmanLock: "/var/lib/pacman/db.lck",
    // Процессы обновления (имя процесса для pgrep). Команда разбирается в scanUpdate().
    updateProcesses: ["pacman", "paru", "yay", "topgrade"],

    // app_id терминалов (нижний регистр, точное совпадение).
    terminals: [
        "kitty", "foot", "footclient", "org.codeberg.dnkl.foot", "alacritty", "org.alacritty",
        "wezterm", "org.wezfurlong.wezterm", "ghostty", "com.mitchellh.ghostty",
        "konsole", "org.kde.konsole", "gnome-terminal", "gnome-terminal-server", "org.gnome.terminal",
        "org.gnome.console", "kgx", "org.gnome.ptyxis", "xterm", "uxterm", "urxvt", "st", "st-256color",
        "terminator", "tilix", "com.gexperts.tilix", "xfce4-terminal", "lxterminal", "qterminal",
        "cool-retro-term", "rio", "contour", "yakuake", "blackbox", "com.raggesilver.blackbox", "sakura"
    ],
    // app_id игр и игровых оболочек (нижний регистр, точное совпадение).
    games: [
        "gamescope", "lutris", "net.lutris.lutris", "heroic", "com.heroicgameslauncher.hgl",
        "minecraft-launcher", "org.prismlauncher.prismlauncher", "retroarch", "dolphin-emu",
        "org.dolphin_emu.dolphin-emu", "pcsx2-qt", "rpcs3", "ppsspp", "duckstation-qt", "yuzu", "cemu",
        "xemu", "supertuxkart", "cs2", "dota2", "hl2_linux", "factorio", "steam_proton"
    ],
    // Игры по началу app_id: Steam (Proton и натив) называет окна steam_app_<id>.
    gamePrefixes: ["steam_app_", "gamescope"],
    // Окна Wine/Proton без Steam часто носят app_id вроде game.exe.
    gameSuffixes: [".exe"]
}
