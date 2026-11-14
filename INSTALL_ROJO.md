# Install Rojo (dan tool Roblox lainnya)

Panduan memasang Rojo lewat **Rokit**, lalu menghubungkannya ke Roblox Studio.

## 1. Install Rokit

**Windows (PowerShell):**

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

**macOS / Linux:**

```bash
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

Setelah selesai, **tutup lalu buka lagi** terminal, kemudian cek:

```bash
rokit --version
```

## 2. Siapkan folder proyek di drive D

Ekstrak starter kit ke drive D, misalnya `D:\Projects\dive-for-pearls-starter`, lalu masuk ke foldernya:

```powershell
cd D:\Projects\dive-for-pearls-starter
```

Kalau prompt PowerShell belum pindah ke D, jalankan `D:` dulu, lalu `cd` ke folder di atas.

Catatan lokasi:

- **Proyek, file kode, dan file place Studio** ada di D (folder di atas).
- **Rokit dan binary tool-nya** (rojo, stylua, dll.) disimpan oleh installer di folder user Windows (`C:\Users\<nama>\.rokit`). Ukurannya kecil, jadi tidak masalah tetap di C. Kalau ingin dipindah juga ke D, cek `rokit --help` atau README Rokit apakah lokasi instalasinya bisa diubah.

## 3. Inisialisasi Rokit dan tambahkan Rojo

```bash
rokit init
rokit add rojo-rbx/rojo
```

- `rokit init` membuat file `rokit.toml` yang mencatat versi tool proyek ini.
- Jika muncul pertanyaan "trust this tool?", jawab **yes**.
- Jika format `rojo-rbx/rojo` ditolak, cek `rokit add --help`.

Cek:

```bash
rojo --version
```

## 4. Install plugin Rojo ke Studio

```bash
rojo plugin install
```

Lalu **restart Roblox Studio**. Plugin Rojo muncul di tab **Plugins**.

Cara ini lebih aman daripada mencari di Creator Store: versinya pasti cocok dengan CLI dan tidak ada risiko plugin palsu.

## 5. Hubungkan ke Studio

Di folder proyek (yang berisi `default.project.json`):

```bash
rojo serve
```

Biarkan terminal ini tetap terbuka. Di Studio, buka place-mu, lalu klik **Plugins → Rojo → Connect**.

## 6. Tambahkan tool lain

```bash
rokit add JohnnyMorganz/StyLua
rokit add Kampfkarren/selene
rokit add JohnnyMorganz/luau-lsp
rokit add lune-org/lune
```

Cek semuanya:

```bash
stylua --version
selene --version
luau-lsp --version
lune --version
```

## 7. Commit file versi tool

```bash
git add rokit.toml
git commit -m "chore: add rokit toolchain"
```

Dengan begitu, komputer lain cukup menjalankan `rokit install` untuk mendapatkan versi tool yang sama.

## Troubleshooting

| Masalah | Solusi |
| --- | --- |
| `rokit` / `rojo` is not recognized | Tutup semua terminal dan VS Code, lalu buka lagi supaya PATH ter-refresh |
| Gagal Connect di Studio | Pastikan `rojo serve` masih jalan, dan dijalankan di folder yang berisi `default.project.json` |
| Error versi plugin tidak cocok | Jalankan ulang `rojo plugin install`, lalu restart Studio |
| Kode di Studio tertimpa | Jangan pakai Rojo dan Script Sync bersamaan untuk service yang sama |

## Sumber

- Rokit: https://github.com/rojo-rbx/rokit
- Rojo docs: https://rojo.space/docs
