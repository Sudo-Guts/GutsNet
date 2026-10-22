#!/usr/bin/env python3
"""Pruebas reales en chroot con UID sin privilegios y una carpeta compartida."""
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

SHELL = Path(__file__).resolve().parents[1] / "out/gutsnet-shell"
UID = 65534
GID = 65534
SHARED_GID = 65533


@unittest.skipUnless(os.geteuid() == 0, "La prueba de chroot requiere sudo.")
class ShellTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gutsnet-jail-test-")
        self.addCleanup(self.temp.cleanup)
        self.jail = Path(self.temp.name) / "jail"
        binary = self.jail / "usr/local/bin/gutsnet-shell"
        binary.parent.mkdir(parents=True)
        for folder in (self.jail, self.jail / "usr", self.jail / "usr/local", binary.parent):
            folder.chmod(0o755)
        shutil.copyfile(SHELL, binary)
        binary.chmod(0o755)
        self.shared = self.jail / "compartido"
        self.shared.mkdir()
        os.chown(self.shared, 0, SHARED_GID)
        self.shared.chmod(0o2770)
        self.secret = self.jail / "secreto.txt"
        self.secret.write_text("FUERA_DEL_AREA_COMPARTIDA\n")
        self.secret.chmod(0o644)

    def run_shell(self, command=None, script=None):
        arguments = ["chroot", f"--userspec={UID}:{GID}", f"--groups={SHARED_GID}",
            str(self.jail), "/usr/local/bin/gutsnet-shell"]
        if command is not None:
            arguments.extend(["-c", command])
        return subprocess.run(arguments, input=script, text=True, capture_output=True, timeout=5)

    def ok(self, command):
        result = self.run_shell(command)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def denied(self, command):
        result = self.run_shell(command)
        self.assertNotEqual(result.returncode, 0, command)
        self.assertNotIn("FUERA_DEL_AREA_COMPARTIDA", result.stdout)
        return result

    def test_create_read_and_delete_document(self):
        self.ok("write informe.txt Hola desde la cuenta restringida")
        self.assertEqual(self.ok("cat informe.txt").stdout, "Hola desde la cuenta restringida\n")
        info = (self.shared / "informe.txt").stat()
        self.assertEqual(info.st_uid, UID)
        self.assertEqual(info.st_gid, SHARED_GID)
        self.assertEqual(stat.S_IMODE(info.st_mode), 0o660)
        self.ok("rm informe.txt")
        self.assertFalse((self.shared / "informe.txt").exists())

    def test_create_and_navigate_subdirectories(self):
        result = self.run_shell(script="mkdir documentos\ncd documentos\nmkdir apuntes\n"
            "cd apuntes\nwrite red.txt Redes de Computadoras\npwd\nls\ncat red.txt\n"
            "cd ../..\npwd\nls\nexit\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertIn("/compartido/documentos/apuntes", result.stdout)
        self.assertIn("documentos/", result.stdout)
        self.assertIn("Redes de Computadoras", result.stdout)
        self.assertEqual((self.shared / "documentos/apuntes/red.txt").read_text(),
            "Redes de Computadoras\n")
        folder = (self.shared / "documentos").stat()
        self.assertEqual(folder.st_gid, SHARED_GID)
        self.assertEqual(stat.S_IMODE(folder.st_mode), 0o2770)

    def test_touch_and_write_preserve_existing_contents(self):
        self.ok("touch vacio.txt")
        self.assertEqual((self.shared / "vacio.txt").stat().st_size, 0)
        self.ok("write conservar.txt Contenido original")
        self.ok("touch conservar.txt")
        self.denied("write conservar.txt Otro contenido")
        self.assertEqual((self.shared / "conservar.txt").read_text(), "Contenido original\n")

    def test_delete_empty_and_nonempty_folders(self):
        self.ok("mkdir vacia")
        self.ok("rmdir vacia")
        self.ok("mkdir carpeta")
        self.ok("mkdir carpeta/hija")
        self.ok("write carpeta/hija/nota.txt Apunte")
        self.denied("rmdir carpeta")
        self.denied("rm carpeta")
        self.ok("rm -r carpeta")
        self.assertFalse((self.shared / "carpeta").exists())

    def test_cannot_leave_shared_root(self):
        for command in ("cd ..", "cd /", "cd /etc", "cd /compartido/..", "cd ../compartido",
            "ls /usr", "cat /secreto.txt", "cat ../secreto.txt", "touch ../../escapar.txt",
            "mkdir /compartido2", "write /secreto.txt cambiar", "rm /secreto.txt",
            "rm -r /compartido", "rmdir /compartido"):
            with self.subTest(command=command):
                self.denied(command)
        self.assertEqual(self.secret.read_text(), "FUERA_DEL_AREA_COMPARTIDA\n")
        self.assertTrue(self.shared.is_dir())

    def test_nested_traversal_never_changes_area(self):
        result = self.run_shell(script="mkdir nivel\ncd nivel\ncd ../..\npwd\n"
            "touch ../../escapar.txt\ncd ..\ncd ..\npwd\nexit\n")
        self.assertIn("/compartido/nivel", result.stdout)
        self.assertNotEqual(result.stderr, "")
        self.assertFalse((self.jail / "escapar.txt").exists())
        self.assertTrue(self.secret.exists())

    def test_absolute_shared_path_and_return_home(self):
        self.ok("mkdir /compartido/notas")
        result = self.run_shell(script="cd /compartido/notas\nwrite materia.txt Redes\ncd\npwd\nexit\n")
        self.assertEqual(result.stderr, "")
        self.assertEqual((self.shared / "notas/materia.txt").read_text(), "Redes\n")

    def test_symlink_cannot_redirect_read_or_write(self):
        (self.shared / "enlace.txt").symlink_to("/secreto.txt")
        (self.shared / "salida").symlink_to("/")
        for command in ("cat enlace.txt", "touch enlace.txt", "write enlace.txt cambiar",
            "cd salida", "cat salida/secreto.txt", "touch salida/escapar.txt",
            "mkdir salida/nueva", "rm salida/secreto.txt", "rm -r salida/usr"):
            with self.subTest(command=command):
                self.denied(command)
        self.assertEqual(self.secret.read_text(), "FUERA_DEL_AREA_COMPARTIDA\n")
        self.ok("rm enlace.txt")
        self.assertFalse((self.shared / "enlace.txt").is_symlink())
        self.assertTrue(self.secret.exists())

    def test_recursive_delete_unlinks_symlinks_without_following(self):
        self.ok("mkdir borrar")
        (self.shared / "borrar/enlace").symlink_to("/")
        (self.shared / "borrar/.oculto con espacios").write_text("archivo de SFTP")
        self.ok("rm -r borrar")
        self.assertFalse((self.shared / "borrar").exists())
        self.assertTrue(self.secret.exists())
        self.assertTrue((self.jail / "usr/local/bin/gutsnet-shell").exists())

    def test_cannot_delete_current_directory_or_ancestors(self):
        result = self.run_shell(script="mkdir padre\ncd padre\nmkdir hija\ncd hija\n"
            "rm -r /compartido/padre\nrmdir .\npwd\nexit\n")
        self.assertNotEqual(result.stderr, "")
        self.assertTrue((self.shared / "padre/hija").is_dir())

    def test_commands_cannot_execute_programs_or_redirections(self):
        for command in ("sh", "bash", "/bin/sh", "sudo id", "exec sh", "uname -a",
            "touch nota;id", "touch nota > archivo", "cat $(id)", "touch .oculto",
            "mkdir uno dos", "rm -rf /"):
            with self.subTest(command=command):
                self.denied(command)
        self.ok("write literal.txt $(id); /bin/sh > archivo")
        self.assertEqual((self.shared / "literal.txt").read_text(), "$(id); /bin/sh > archivo\n")
        self.assertFalse((self.shared / "archivo").exists())

    def test_listing_can_repeat_without_losing_entries(self):
        self.ok("touch prueba.txt")
        result = self.run_shell(script="ls\nls\nls\nexit\n")
        self.assertEqual(result.stdout.count("prueba.txt"), 3)
        self.assertEqual(result.stderr, "")

    def test_cat_rejects_fifo_and_large_files(self):
        os.mkfifo(self.shared / "tuberia")
        (self.shared / "grande.txt").write_bytes(b"a" * (1024 * 1024 + 1))
        (self.shared / "grande.txt").chmod(0o644)
        self.denied("cat tuberia")
        self.denied("cat grande.txt")

    def test_oversized_input_is_rejected_and_session_continues(self):
        self.denied("touch " + "a" * 4096)
        result = self.run_shell(script="touch " + "a" * 4200 + "\ntouch valido.txt\nexit\n")
        self.assertIn("Comando demasiado largo", result.stderr)
        self.assertEqual(list(self.shared.iterdir()), [self.shared / "valido.txt"])


if __name__ == "__main__":
    required = (1 << 0) | (1 << 6) | (1 << 7) | (1 << 18)
    caps = next((int(line.split()[1], 16) for line in Path('/proc/self/status').read_text().splitlines()
        if line.startswith('CapEff:')), 0)
    if os.geteuid() != 0 or caps & required != required:
        sys.exit('ERROR: estas pruebas necesitan sudo con permisos de chroot y cambio de UID/GID.')
    unittest.main(verbosity=2)
