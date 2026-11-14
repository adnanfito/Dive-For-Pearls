# Setup Dive for Pearls + Claude Code

Panduan pasang alat supaya Claude Code hemat token, jarang salah, dan hasilnya rapi.

## 1. Yang perlu diinstall (urut)

| # | Alat | Fungsi | Kenapa hemat token |
| --- | --- | --- | --- |
| 1 | Git | Version control | Bisa `/rewind` dan rollback tanpa minta Claude memperbaiki ulang |
| 2 | VS Code + ekstensi **Claude Code** | Editor + agen | Claude bekerja langsung di file proyek |
| 3 | Roblox Studio (versi terbaru) | Game engine | Pakai **MCP server bawaan Studio**, tidak perlu MCP pihak ketiga |
| 4 | **Rokit** | Pengelola versi tool | Semua tool terkunci versinya, hasil sama di semua komputer |
| 5 | **Rojo** (lewat Rokit) + plugin Rojo di Studio | Sinkron file ke Studio | Claude mengedit file biasa, bukan menebak isi Studio |
| 6 | **StyLua** (lewat Rokit) | Formatter | Claude tidak perlu membahas atau merapikan format |
| 7 | **Selene** (lewat Rokit) | Linter | Error ketahuan lewat CLI singkat, bukan lewat playtest panjang |
| 8 | **luau-lsp** (lewat Rokit) + ekstensi VS Code "Luau Language Server" | Type checker | Salah tipe ketahuan tanpa menjalankan game |
| 9 | **Lune** (lewat Rokit) | Menjalankan Luau di luar Studio | Rumus dan peluang gacha bisa dites dalam hitungan detik |

Perintah Rokit (jalankan di folder proyek):

```bash
rokit init
rokit add rojo-rbx/rojo
rokit add JohnnyMorganz/StyLua
rokit add Kampfkarren/selene
rokit add JohnnyMorganz/luau-lsp
rokit add lune-org/lune
```

Catatan: luau-lsp butuh file definisi tipe Roblox untuk analisis penuh. Cek README luau-lsp untuk flag `--definitions` versi terbaru, lalu sesuaikan perintah type check di `AGENTS.md`.

**Yang sengaja TIDAK diinstall:** MCP server Roblox buatan komunitas. Studio sudah punya MCP bawaan, dan setiap MCP server tambahan ikut memakan konteks.

## 2. Hubungkan Studio

1. Buka Studio, buat place baru, simpan ke folder proyek (file `.rbxlx` sudah di-ignore).
2. Terminal: `rojo serve`. Di Studio: Plugins → Rojo → Connect.
3. Studio: tombol **Assistant** (kanan atas) → ⋯ → **Manage MCP Servers** → pastikan MCP aktif → di **Quick connect** aktifkan **Visual Studio Code**. Restart Studio/VS Code kalau belum muncul.
4. Tes: minta Claude membuat `src/server/Test.server.luau`, lalu cek muncul di Explorer. Minta Claude memakai Roblox MCP untuk menampilkan isi Workspace.

## 3. Taruh GDD di repo

Export GDD dari dokumen ke Markdown, simpan sebagai `docs/GDD.md`. Claude membaca bagian yang dibutuhkan saja.

## 4. Struktur file konfigurasi agen

```
CLAUDE.md                 dibaca Claude Code (mengimpor AGENTS.md)
AGENTS.md                 aturan proyek untuk semua agen (Claude, Codex, Cursor)
.claude/settings.json     izin otomatis untuk tool CLI + larangan membaca file berat
.claude/rules/anti-slop.md  aturan anti-slop, dimuat setiap sesi
.claude/rules/luau.md     aturan Luau, hanya dimuat saat Claude membuka file .luau
```

Jaga `CLAUDE.md`, `AGENTS.md`, dan file rules masing-masing di bawah 200 baris. Semua file ini dimuat setiap sesi, jadi setiap baris tambahan adalah token tambahan di setiap request.

## 5. Kebiasaan hemat token di Claude Code

- `/clear` setiap pindah ke tugas yang tidak berhubungan. Pakai `/rename` dulu kalau mau kembali lagi nanti lewat `/resume`.
- `/compact` saat sesi panjang tapi tugasnya masih sama.
- `/model`: pakai **Sonnet** untuk coding sehari-hari, **Opus** untuk desain arsitektur dan bug yang sulit.
- `/effort` lebih rendah untuk tugas sederhana (rename, ubah teks, tambah baris Config).
- **Plan mode** (Shift+Tab) untuk fitur besar. Salah arah saat rencana jauh lebih murah daripada salah arah setelah kode ditulis.
- Tekan **Esc** begitu Claude salah arah. `/rewind` untuk kembali ke checkpoint.
- `/context` untuk melihat apa yang memakan konteks, `/usage` untuk melihat pemakaian.
- `/mcp` untuk mematikan MCP server yang tidak dipakai.
- Prompt spesifik: sebut file, fungsi, dan hasil yang diharapkan.

## 6. Urutan pembangunan

1. Fondasi: Config, Formulas (+ tes Lune), Types, Remotes, DataService
2. Menyelam: dermaga, 2 zona, oksigen, Lift Gelembung, meteran kedalaman
3. Kerang dan akuarium: memungut, waktu matang, buka mutiara di server, pakai/pajang/jual
4. Ruang Tekanan: AFK menaikkan kedalaman, pengali, progress bar zona
5. Teman dan tiket: telur, pity, Sonar/Magnet, Index
6. Monster, pingsan, kerang jatuh
7. UI lengkap dan tutorial 5 menit pertama
8. Event, misi harian, monetisasi, analytics

Satu fase = beberapa sesi kecil. Commit setiap langkah yang berhasil.

## 7. Yang tetap kamu review sendiri

- Semua kode Robux: product ID, gamepass, `ProcessReceipt`.
- Validasi remote dan perhitungan di server (anti-exploit).
- Angka balancing dan odds.
- Setiap tool call MCP yang mengubah Studio, sebelum di-approve.
