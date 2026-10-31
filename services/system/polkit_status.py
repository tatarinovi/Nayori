"""Read-only picture of who already answers polkit. Never registers an agent."""

import json
import pathlib
import subprocess
import sys

INTERFACE = "org.freedesktop.PolicyKit1.AuthenticationAgent"
HINTS = (
    "polkit-kde",
    "hyprpolkit",
    "mate-polkit",
    "lxqt-policykit",
    "xfce-polkit",
    "pantheon-polkit",
    "polkit-gnome",
)


def is_agent_comm(comm):
    name = str(comm or "").strip()
    if not name or name == "polkitd" or name.startswith("polkit-agent"):
        return False
    return any(name.startswith(hint) for hint in HINTS)


def assess(report):
    """Decide whether Nayori may call RegisterAuthenticationAgent.

    A well-known bus name is enough to refuse. A matching process is only a hint:
    polkit itself rejects a second agent for the same session, and this function
    does not stop processes.
    """
    session = report.get("sessionOwned")
    system = report.get("systemOwned")
    known = session is True or session is False
    known = known and (system is True or system is False)
    agents = []
    for item in report.get("processes") or []:
        comm = str(item.get("comm") or "").strip()[:32]
        if not is_agent_comm(comm):
            continue
        try:
            pid = int(item.get("pid"))
        except (TypeError, ValueError):
            continue
        agents.append({"pid": pid, "comm": comm})
    return {
        "ok": bool(report.get("ok", True)) and known,
        "blockRegistration": session is True or system is True,
        "sessionOwned": session is True,
        "systemOwned": system is True,
        "sessionPid": _pid(report.get("sessionPid")),
        "systemPid": _pid(report.get("systemPid")),
        "sessionComm": _comm(report.get("sessionComm")),
        "systemComm": _comm(report.get("systemComm")),
        "agents": agents,
    }


def _pid(value):
    try:
        number = int(value)
    except (TypeError, ValueError):
        return None
    return number if number > 0 else None


def _comm(value):
    return str(value or "").strip()[:32]


def _busctl(system, *args):
    command = ["busctl", "--system" if system else "--user", "call", *args]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=2, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def _owned(system):
    text = _busctl(
        system,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
        "NameHasOwner",
        "s",
        INTERFACE,
    )
    if text == "b true":
        return True
    if text == "b false":
        return False
    return None


def _owner_process(system):
    unique = _busctl(
        system,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
        "GetNameOwner",
        "s",
        INTERFACE,
    )
    if not unique or not unique.startswith("s "):
        return None, ""
    name = unique[2:].strip().strip('"')
    pid_text = _busctl(
        system,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
        "GetConnectionUnixProcessID",
        "s",
        name,
    )
    if not pid_text or not pid_text.startswith("u "):
        return None, ""
    try:
        pid = int(pid_text.split()[1])
    except (IndexError, ValueError):
        return None, ""
    comm = ""
    try:
        comm = pathlib.Path(f"/proc/{pid}/comm").read_text(encoding="utf-8", errors="replace")
    except OSError:
        comm = ""
    return _pid(pid), _comm(comm.split("\n", 1)[0])


def _processes():
    try:
        result = subprocess.run(
            ["ps", "-eo", "pid=,comm="],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    found = []
    for line in result.stdout.splitlines():
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        try:
            pid = int(parts[0])
        except ValueError:
            continue
        found.append({"pid": pid, "comm": parts[1].strip()[:32]})
    return found


def probe():
    session_owned = _owned(False)
    system_owned = _owned(True)
    session_pid, session_comm = (None, "")
    system_pid, system_comm = (None, "")
    if session_owned is True:
        session_pid, session_comm = _owner_process(False)
    if system_owned is True:
        system_pid, system_comm = _owner_process(True)
    return assess({
        "ok": True,
        "sessionOwned": session_owned,
        "systemOwned": system_owned,
        "sessionPid": session_pid,
        "systemPid": system_pid,
        "sessionComm": session_comm,
        "systemComm": system_comm,
        "processes": _processes(),
    })


def main(argv):
    if "--probe" not in argv:
        return 2
    try:
        print(json.dumps(probe(), ensure_ascii=True))
    except Exception:
        print(json.dumps({"ok": False, "blockRegistration": False, "agents": []}, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
