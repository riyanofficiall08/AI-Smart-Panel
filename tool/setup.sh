#!/usr/bin/env bash
# Jalankan dari root proyek:  bash tool/setup.sh
# Folder android/ SUDAH ikut repo (Embedding V2 + Kotlin native). Skrip ini hanya menyiapkan config & dependency.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "Flutter belum terpasang / tidak ada di PATH"; exit 1; }

[ -f config/dart_defines.json ] || { cp config/dart_defines.example.json config/dart_defines.json; echo "[!] config/dart_defines.json dibuat dari contoh — isi SUPABASE_URL & SUPABASE_ANON_KEY Anda."; }
flutter pub get
echo
echo "Debug APK   :  flutter build apk --debug --dart-define-from-file=config/dart_defines.json"
echo "Release APK :  butuh android/key.properties (lihat README §5)"
