"""Authoring regressions; native installation/UI/shortcut tests run on Windows."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NS = {"w": "http://schemas.microsoft.com/wix/2006/wi"}


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / "packaging/windows/mdvu.wxs").read_text()
        self.xml = ET.fromstring(self.source)

    def test_finish_has_an_unconditional_close_event(self):
        events = self.xml.findall('.//w:Publish[@Dialog="ExitDialog"][@Control="Finish"]', NS)
        self.assertTrue(any(e.get("Event") == "EndDialog" and e.get("Value") == "Return"
                            and e.text.strip() == "1" for e in events))

    def test_shortcut_and_associations_reference_the_installed_file(self):
        shortcut = self.xml.find('.//w:Shortcut[@Id="ApplicationStartMenuShortcut"]', NS)
        self.assertEqual(shortcut.get("Target"), "[#MdvuExe]")
        self.assertNotIn("[APPLICATIONFOLDER]mdvu.exe", self.source)
        commands = [r.get("Value") for r in self.xml.findall('.//w:RegistryValue', NS)
                    if '%1' in r.get("Value", "")]
        self.assertEqual(commands, ['"[#MdvuExe]" "%1"'] * 2)

    def test_associations_match_supported_markdown_inputs(self):
        keys = self.xml.findall('.//w:RegistryKey[@Root="HKMU"]', NS)
        extensions = {key.get("Key").split("\\")[-1] for key in keys
                      if key.get("Key", "").startswith("Software\\Classes\\.")}
        self.assertEqual(extensions, {".md", ".markdown", ".mdown", ".mkd"})

    def test_scope_updates_directory_resolution(self):
        # SetDirectory is WiX's before-CostFinalize assignment. A type-51 property
        # assignment after CostFinalize changes text without recosting file paths.
        self.assertIsNone(self.xml.find('.//w:SetProperty[@Id="APPLICATIONFOLDER"]', NS))
        self.assertEqual(len(self.xml.findall('.//w:SetDirectory[@Id="APPLICATIONFOLDER"]', NS)), 2)
        for control in ("InstallShield", "InstallNoShield"):
            events = self.xml.findall(f'.//w:Control[@Id="{control}"]/w:Publish', NS)
            recost = next(e for e in events if e.get("Event") == "SetTargetPath")
            end = next(e for e in events if e.get("Event") == "EndDialog")
            self.assertEqual(recost.get("Value"), "APPLICATIONFOLDER")
            self.assertLess(int(recost.get("Order")), int(end.get("Order")))


if __name__ == "__main__":
    unittest.main()
