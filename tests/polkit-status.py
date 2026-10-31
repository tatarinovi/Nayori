"""Queue-free checks for the read-only polkit ownership decision."""

import importlib.util
import json
import sys
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "services/system/polkit_status.py"
spec = importlib.util.spec_from_file_location("polkit_status", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def assess(**report):
    report.setdefault("ok", True)
    report.setdefault("processes", [])
    return module.assess(report)


def main():
    free = assess(sessionOwned=False, systemOwned=False)
    assert free["ok"] and not free["blockRegistration"] and free["agents"] == []

    session = assess(sessionOwned=True, systemOwned=False, sessionPid=40, sessionComm="hyprpolkitagent")
    assert session["blockRegistration"] and session["sessionOwned"] and not session["systemOwned"]

    system = assess(systemOwned=True, sessionOwned=False, systemPid=41, systemComm="polkit-kde-aut")
    assert system["blockRegistration"] and system["systemOwned"]

    unknown = assess(sessionOwned=None, systemOwned=False)
    assert not unknown["ok"] and not unknown["blockRegistration"]

    hinted = assess(sessionOwned=False, systemOwned=False, processes=[
        {"pid": 7, "comm": "polkitd"},
        {"pid": 8, "comm": "polkit-agent-he"},
        {"pid": 9, "comm": "python3"},
        {"pid": 10, "comm": "polkit-kde-aut"},
        {"pid": "нет", "comm": "hyprpolkitagent"},
    ])
    assert not hinted["blockRegistration"]
    assert hinted["agents"] == [{"pid": 10, "comm": "polkit-kde-aut"}]

    for name in ("hyprpolkitagent", "mate-polkit", "lxqt-policykit", "xfce-polkit", "pantheon-polkit", "polkit-gnome"):
        assert module.is_agent_comm(name), name
    assert not module.is_agent_comm("polkitd")
    assert not module.is_agent_comm("polkit-agent-helper")

    leaked = assess(sessionOwned=False, systemOwned=False, password="")
    encoded = json.dumps(leaked)
    assert "password" not in leaked and "password" not in encoded

    print("POLKIT_STATUS_TESTS_PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
