# Dive for Pearls 🐚 — Game Design Document

Nov 14, 2026 · @XHARP

## Ringkasan

Dive for Pearls adalah game Roblox tentang menyelam mencari kerang, membuka mutiaranya, menetaskan teman laut, lalu menyelam lebih dalam lagi. Loop-nya sederhana dengan unsur gacha yang kuat, dirancang supaya anak betah dan mau kembali tanpa memakai dark pattern.

| Aspek | Keputusan |
| --- | --- |
| Target utama | Anak SD (sekitar 7–12 tahun) |
| Target sekunder | SMP–SMA, orang dewasa boleh ikut |
| Platform | Roblox, mobile-first (juga PC, tablet, konsol) |
| Bahasa | Inggris sederhana sebagai utama, plus terjemahan Indonesia |
| Genre | Koleksi + gacha + idle, sesi pendek |

**Empat pilar (jantung game):**

1. **Penasaran** — "Ada apa di bawah sana?" Laut makin dalam makin gelap dan aneh: dari laut nyata sampai Palung Mariana, lalu laut fantasi.
2. **Kejutan** — "Aku dapat apa?" Setiap kerang dan Telur Laut yang dibuka adalah momen gacha yang dramatis.
3. **Teman** — "Ini peliharaanku." Hewan laut yang ikut menyelam dan dikoleksi.
4. **Kembali lagi** — "Pasti ada yang menunggu." Kerang yang sedang matang, Koin dari akuarium, dan event terjadwal.

**Pembagian peran:** AFK membuat pemain lebih kuat, menyelam memberi kejutan, menunggu memberi alasan untuk kembali.

## Core loop

AFK menaikkan kedalaman, kedalaman membuka kerang yang lebih langka, dan mutiara hasil gacha mempercepat AFK berikutnya. Gacha dan idle menjadi satu sistem yang saling mengunci, dan bagian ini paling sulit ditiru clone.

&#91;embedded content: core loop Dive for Pearls · 9 langkah, 2 putaran balik\]

Putaran kiri membawa mutiara kembali ke Ruang Tekanan sebagai pengali; putaran kanan membawa Telur Laut menjadi teman yang ikut menyelam. Kalimat untuk pemain: menyelam cari kerang, buka mutiaranya, tetaskan teman laut, lalu menyelam lebih dalam lagi.

## Stat dan ekonomi

Versi awal memakai pola 1 + 1 + 1: satu stat utama, satu mata uang, satu sistem pengali. Atribut lain dibuka bertahap lewat update (progressive disclosure), tepat saat pemain mulai merasakan kebutuhannya.

| Elemen | Fungsi | Sumber | Batas |
| --- | --- | --- | --- |
| Batas Kedalaman (meter) | Stat utama; menentukan zona dan seberapa dalam pemain bisa menjelajah | Ruang Tekanan saat AFK di server | Tanpa batas |
| Koin | Mata uang utama untuk upgrade yang tidak acak | Menjual mutiara, Koin per detik dari akuarium, katalog Robux | — |
| Tiket Telur | Satu-satunya cara membuka Telur Laut (gacha teman) | Misi dan event (sulit didapat); Robux saat habis | Langka |
| Pengali (mutiara dipakai) | Mempercepat Ruang Tekanan | Mutiara hasil gacha | Dibatasi total |
| Oksigen | Lama satu kali selam | Tetap 90 detik di MVP; Tabung Oksigen menyusul | Ada batas (sekitar 3 menit) |
| Kecepatan renang | Efisiensi mengumpulkan dan kabur dari monster | Tetap di MVP; Sirip menyusul | Ada batas |

**Aturan ekonomi:** Telur Laut dibuka dengan Tiket, bukan Koin. Karena Koin tidak lagi membeli item acak, Koin boleh dijual dengan Robux. Tiket didapat gratis dari misi dan event, dan bisa dibeli dengan Robux saat habis; tiket berbayar mengikuti aturan paid random item (lihat Monetisasi).

**Yang bisa dibeli dengan Koin:**

| Upgrade | Efek | Batas | Kapan |
| --- | --- | --- | --- |
| Level Ruang Tekanan | Kedalaman naik lebih cepat | Bertingkat | MVP |
| Slot Akuarium | Lebih banyak kerang matang sekaligus dan mutiara dipajang | Bertingkat | MVP |
| Slot Teman | Lebih banyak teman aktif | Bertingkat | MVP |
| Dekorasi Akuarium | Kosmetik untuk pamer | — | MVP |
| Sirip | Kecepatan renang | Bertingkat | Update minggu 1 |
| Tabung Oksigen | Lama selam | Sampai sekitar 3 menit | Saat zona dalam dibuka |
| Alat zona (senter, dll.) | Membuka zona tertentu | — | Seiring zona baru |

Slot dan kapasitas boleh juga dijual dengan Robux sebagai jalan pintas (tidak acak). Level Ruang Tekanan dan Telur Laut biasa tetap hanya dengan Koin.

## Sistem idle

AFK di dalam server menaikkan Batas Kedalaman dan memberi Koin penuh; offline hanya memberi Koin lebih pelan. Ini membuat pemain memilih tetap di server daripada keluar, tanpa menghukum yang offline.

**Ruang Tekanan.** Tabung kaca di markas tempat penyelam melatih tubuhnya menahan tekanan air. Selama pemain berada di dalamnya dan online, Batas Kedalaman naik terus. Kecepatannya ditentukan level Ruang Tekanan (Koin) dikali pengali dari mutiara yang dipakai.

| Situasi | Ruang Tekanan | Akuarium (Koin per detik) | Kerang di akuarium |
| --- | --- | --- | --- |
| AFK di server | Kedalaman naik | 100% | Terus matang |
| Offline | Berhenti | Sekitar 50%, maksimal 8 jam terkumpul | Terus matang |

**Tampilan saat AFK:**

- Angka besar "Batas Kedalaman: 1.240 m" yang terus naik, dengan angka kecil melayang ("+12 m").
- Progress bar ke zona berikutnya, misalnya "Zona Senja: 1.240 / 2.000 m".
- Pengali aktif terlihat, misalnya "x5 (Mutiara Emas)".
- Pemandangan zona berikutnya terlihat samar di luar kaca; warna air di tabung makin gelap mendekati ambang.
- Saat ambang tercapai: perayaan besar dan tombol "Selam sekarang" yang langsung membawa ke Lift Gelembung.
- Kedalaman tampil di atas nama pemain dan di leaderboard server.

**Saat pemain kembali:** layar sambutan menampilkan Koin yang terkumpul dan jumlah kerang yang siap dibuka.

**Aturan keseimbangan:**

- Kerang hanya didapat dari menyelam aktif, jadi gacha mutiara hanya terjadi saat bermain.
- Diminishing returns: setelah sekitar 2 jam AFK berturut-turut, Ruang Tekanan sedikit melambat.
- Interaksi ringan berkala (tombol kumpulkan Koin, kerang baru matang, kotak hadiah waktu bermain) supaya anak tidak perlu auto-clicker. Roblox biasanya mengeluarkan pemain yang diam sekitar 20 menit.
- Pengali dibatasi supaya pemain tidak melompati zona sebelum sempat menikmatinya.
- Hadiah waktu bermain di menit 5, 15, 30 dan 60, dengan progress bar.

## Dunia dan zona

Setiap zona adalah area terpisah dengan titik mulai kedalamannya sendiri; pemain tidak pernah berenang dari 0 m. Laut nyata dulu sampai Palung Mariana, lalu berlanjut ke laut fantasi tanpa batas.

| Zona | Ambang (mulai) | Tipe | Target waktu main kumulatif | Kapan |
| --- | --- | --- | --- | --- |
| Pantai Dangkal | 0 m | Nyata, tanpa monster | Langsung | MVP |
| Terumbu Karang | 50 m | Nyata, ada ubur-ubur | Sekitar 2 menit (tutorial) | MVP |
| Zona Senja | 200 m | Nyata, mulai gelap | Sekitar 20 menit | Update |
| Zona Tengah Malam | 1.000 m | Nyata, makhluk bercahaya | Sekitar 2 jam | Update |
| Jurang | 4.000 m | Nyata | Sekitar 8 jam | Update |
| Palung Mariana | 11.000 m | Titik terdalam di Bumi, lalu misteri | Sekitar 1 hari | Update |
| Atlantis | 50.000 m | Fantasi | Sekitar 3 hari | Update |
| Laut Kristal | 1 juta m | Fantasi | Sekitar 1 minggu | Update |
| Laut Lava | 20 juta m | Fantasi | Sekitar 2 minggu | Update |
| Laut Bintang | 400 juta m | Fantasi | Sekitar 1 bulan | Update |

Aturan untuk zona fantasi berikutnya: ambang zona baru = ambang zona sebelumnya × 20. Target waktu main dipakai untuk menyetel rumus Ruang Tekanan.

Angka di tabel adalah struktur awal, belum balancing final. Nama zona laut nyata mengikuti lapisan laut yang dipakai ilmuwan, jadi ada nilai edukasi yang disukai orang tua.

**Lift Gelembung.** Teleport dari dermaga ke titik mulai zona yang sudah terbuka. Zona yang belum terjangkau tampil terkunci dengan keterangan, misalnya "Butuh 2.000 m (kamu 1.240 m)".

**Di dalam zona.** Pemain boleh turun sejauh Batas Kedalamannya. Makin dalam di satu zona, kerangnya makin bagus, jadi kenaikan stat terasa bahkan sebelum zona berikutnya terbuka. Di dasar zona ada gerbang ke zona berikutnya.

**Batas tekanan (tanpa hukuman berat):**

- 90–100% dari batas: pinggir layar gelap, suara "krek" pelan, meteran kuning.
- Tepat di batas: layar retak tipis, meteran merah, tulisan "Tekanan terlalu kuat!".
- Memaksa turun: gerak ke bawah melambat, oksigen terkuras 3 kali lebih cepat, lalu pemain terdorong naik ke batas aman. Pemain tidak pingsan dan kerang tidak jatuh.
- Opsional: "Zona Nekat" pada 10% terakhir sebelum batas, kerangnya sedikit lebih bagus tapi oksigen cepat habis.

**Skala meteran per zona.** Ukuran peta tiap zona mirip, tapi satu langkah turun setara jarak berbeda (1 m di Pantai, bisa 10.000 m di Laut Kristal), supaya angkanya terasa besar tanpa peta raksasa.

**Pasang–surut real-time,** serentak se-server. Saat surut, pantai terbuka dan kerang biasa mudah didapat. Saat pasang, bagian dalam lebih kaya kerang langka tapi monster lebih aktif.

## Menyelam, monster, dan oksigen

Monster dihindari, bukan dilawan; tidak ada mati. Aturannya mudah diingat: tekanan berarti tidak bisa turun, oksigen habis berarti kerang jatuh.

**Satu kali selam.** Oksigen 90 detik (MVP). Kerang tersebar cukup banyak supaya mudah ditemukan. Teman pendamping membantu sesuai kemampuannya. Pemain bisa naik kapan saja lewat tombol "Naik", lalu kembali ke dermaga.

**Monster.**

- Monster kecil (ubur-ubur, belut, kepiting): kalau tersentuh, oksigen berkurang dan pemain sedikit terdorong.
- Gaya "lucu-seram": mata melotot, gigi lucu, cukup bikin deg-degan tanpa menakutkan.
- Raja Gurita (update): boss bersama satu server yang menjaga Kerang Raksasa. Pemain bekerja sama mengalihkan tentakelnya, hadiahnya dibagi ke semua yang ikut.

**Kalau oksigen habis:**

1. Oksigen 20%: layar berkedip biru, bunyi peringatan, tombol besar "Naik!".
2. Oksigen 0: karakter pingsan dengan animasi lucu.
3. Teman pendamping mendorong pemain ke permukaan (pelampung kalau belum punya teman).
4. Kerang yang sedang dibawa jatuh ke dasar dan ditandai di peta. Hanya pemiliknya yang bisa memungutnya kembali, dalam batas waktu sekitar 10 menit.

Tidak ada kerugian permanen selama pemain kembali mengambilnya. Desain ini menjaga ketegangan untuk anak SMP tanpa membuat anak SD frustrasi.

## Kerang dan mutiara

Mencari kerang dibuat gampang, membukanya butuh waktu sesuai rarity. Setiap kerang selalu berisi sesuatu: mutiara, atau sesekali Telur Laut.

**Waktu matang di akuarium** (titik awal, disesuaikan lewat playtest):

| Kerang | Waktu matang | Fungsi |
| --- | --- | --- |
| Biasa | Sekitar 1 menit | Hadiah cepat saat sedang main |
| Bercahaya | Sekitar 10 menit | Tetap seru dalam satu sesi |
| Langka | Sekitar 1 jam | Alasan tetap di server atau kembali sebentar lagi |
| Raksasa / Event | Sekitar 4–8 jam | Janji untuk kembali besok |

5–10 kerang pertama pemain baru langsung matang, supaya mereka merasakan serunya membuka sebelum mengenal sistem menunggu.

**Antisipasi saat menunggu:** kerang makin bercahaya mendekati matang, warnanya memberi petunjuk rarity, ada countdown di atas setiap kerang, notifikasi saat matang (jika diaktifkan), dan Kerang Raksasa bergetar sesekali.

**Rarity mutiara** (contoh angka, belum balancing):

| Rarity | Warna |
| --- | --- |
| Putih | Putih |
| Pink | Pink |
| Biru | Biru |
| Emas | Emas |
| Hitam | Hitam |
| Pelangi | Pelangi |

Ukuran mutiara acak, dan nilainya naik di zona yang lebih dalam. Peluang, nilai, dan bonus tiap rarity ada di bagian Balancing awal.

**Tiga pilihan untuk setiap mutiara** (tiga tombol besar dengan ikon supaya anak SD tidak bingung):

- **Pakai** sebagai pengali Ruang Tekanan.
- **Pajang** di akuarium untuk menghasilkan Koin per detik.
- **Jual** untuk Koin langsung.

**Batas pengali:** total luck dan pengali dibatasi (misalnya peluang tiap rarity maksimal 3 kali nilai dasar) supaya mutiara langka tetap terasa langka.

## Teman Penyelam

Teman didapat lewat gacha dan berperan sebagai pendamping yang ikut menyelam dengan kemampuan unik. Teman membantu, tapi tidak memainkan game untuk pemain.

**Sumber teman:**

- **Telur Laut** di dermaga, dibuka dengan **Tiket Telur**, bukan Koin. Tiap zona punya telurnya sendiri; telur zona dalam butuh tiket lebih banyak dan berisi teman lebih hebat.
- **Tiket Telur sengaja sulit didapat:** hanya dari misi (quest) dan event. Kalau habis, tiket bisa dibeli dengan Robux.
- **Telur pertama gratis** di tutorial, supaya setiap pemain langsung punya teman.
- **Kejutan dalam kerang:** peluang sangat kecil sebuah kerang berisi Telur Laut.

**Teman seperti class.** Selain kemampuan aktif saat menyelam, teman yang dibawa memberi bonus persen stat pasif, misalnya +5% kecepatan Ruang Tekanan atau +10% Koin akuarium. Bedanya dengan sistem class di game lain: tetasan baru tidak menggantikan teman lama, semua tetap tersimpan di koleksi.

**Laju tiket gratis** perlu dibalancing hati-hati. Rekomendasi awal: misi harian memberi sekitar 1 tiket per hari, ditambah tiket dari event dan pencapaian zona baru. Kalau terlalu jarang, pemain gratis merasa terhalang dan berhenti main sebelum sempat membeli apa pun.

**Rarity:**

| Rarity | Contoh | Kemampuan |
| --- | --- | --- |
| Biasa | Ikan Badut, Kepiting | Bonus kecil |
| Langka | Lumba-lumba, Anjing laut | Kemampuan inti |
| Epik | Penyu, Berang-berang | Kemampuan kuat |
| Legendaris | Paus Bungkuk, Manta Raksasa | Kemampuan ganda |
| Mitos | Naga Laut, Kraken Kecil | Kemampuan unik dan efek visual besar |

Ada juga varian mutasi dari zona tertentu, misalnya Lumba-lumba Emas atau Penyu Kristal.

**Kemampuan saat menemani menyelam:**

| Teman | Kemampuan | Kapan |
| --- | --- | --- |
| Lumba-lumba | Sonar: menandai kerang tersembunyi di sekitar | MVP |
| Anjing laut | Magnet: kerang dalam radius kecil terkumpul otomatis | MVP |
| Penyu | Perisai: monster mengincar penyu, bukan pemain | Update |
| Berang-berang | Sesekali mengupgrade kerang yang dipungut satu tingkat (final) | Update |

Kemampuan dibuat membantu, bukan menggantikan: sonar hanya menandai, magnet radiusnya kecil.

**Supaya gacha seru, bukan bikin frustrasi:**

- **Pity:** misalnya setiap 20 tetasan tanpa Epik, tetasan berikutnya dijamin Epik atau lebih, dengan progress bar terlihat.
- **Teman kembar berguna:** 3 teman sama digabung menjadi versi lebih kuat (bintang 2, bintang 3).
- **Animasi tetas dramatis:** telur bergetar, retak, cahaya dengan warna petunjuk rarity.

**Slot dan Index:** MVP satu slot pendamping; slot tambahan dibuka dengan Koin atau gamepass. Teman yang tidak dibawa masuk Index koleksi: setiap jenis unik +1% Koin (maks +50%), dan setiap 5 jenis unik memberi 1 Tiket. Teman tidak bisa di-trade.

## 5 menit pertama

Pemain baru harus merasakan menyelam, membuka mutiara, dan mendapat teman dalam 5 menit, tanpa teks panjang. Momen menang pertama dijamin.

| Waktu | Yang terjadi | Tujuan |
| --- | --- | --- |
| 0:00–0:30 | Spawn di dermaga, panah besar mengajak lompat ke laut | Langsung main |
| 0:30–1:30 | Selam pertama di Pantai Dangkal, ambil 3 kerang, tanpa monster | Rasa mampu |
| 1:30–2:00 | Taruh kerang di akuarium; kerang pertama langsung matang | Hadiah instan |
| 2:00–2:30 | Buka kerang pertama: dijamin mutiara Pink, dengan efek besar | Menang pertama |
| 2:30–3:00 | Pilih: pakai, pajang, atau jual (dipandu) | Mengenal pilihan |
| 3:00–3:30 | Dapat Telur Laut gratis, menetas jadi teman pertama | Ikatan dengan teman |
| 3:30–4:00 | Masuk Ruang Tekanan sebentar; angka kedalaman naik, progress bar ke Terumbu terlihat | Mengenal AFK |
| 4:00–4:30 | Selam ke Terumbu Karang, ketemu ubur-ubur pertama | Tantangan baru |
| 4:30–5:00 | Pengumuman: "Bulan Purnama dalam 12 menit!" | Alasan bertahan |

Ambang Terumbu (50 m) tercapai lewat AFK sekitar 2 menit di Ruang Tekanan pada langkah 3:30–4:00, jadi langkah 4:00 tidak butuh aturan khusus.

## Event dan sosial

Event serentak se-server adalah mesin lonjakan pemain; trading dan pamer adalah mesin komunitas. Event dibuat terjadwal dan countdown-nya selalu terlihat.

**Event:**

| Event | Isi | Kapan |
| --- | --- | --- |
| Bulan Purnama | Kerang bercahaya muncul di semua zona, terjadwal dengan countdown | MVP |
| Raja Gurita | Boss bersama, membuka Kerang Raksasa, hadiah dibagi | Update minggu 4 |
| Admin Event akhir pekan | Drop terbatas saat developer hadir di server | Update |
| Event musiman | Mutiara dan teman bertema (Halloween, Natal, Lebaran) | Update |
| Kolaborasi | Crossover dengan game lain setelah game cukup besar | Jangka panjang |

**Sosial dan kompetisi:**

- Batas Kedalaman tampil di atas nama pemain dan di leaderboard server.
- Leaderboard "Mutiara Terbesar Minggu Ini".
- Kunjungan ke akuarium pemain lain, dengan tombol like.
- Trading mutiara (update minggu 3), dengan layar konfirmasi dua sisi dan countdown sebelum setuju untuk melindungi anak dari penipuan.
- Panggung Buka Kerang (update): kerang langka dibuka di dermaga dan ditonton satu server; momen ini mudah direkam untuk TikTok.

**Pelajaran dari pasar:** Steal an Egg tumbuh dengan update setiap Sabtu dan crossover, tapi turun ke sekitar 6% dari puncaknya dalam 25 hari, dan clone langsung bermunculan. Storage Hunters kehilangan separuh pemain karena jadwal update tidak jelas. Konten harus disiapkan sebelum rilis.

## Visual dan UX

Gaya kartun cerah, bulat, dan imut yang menarik anak-anak, ringan untuk HP, dan bisa dibaca di layar kecil.

**Visual:**

- Warna cerah kontras tinggi: laut biru toska jernih, terumbu warna-warni, tanpa warna kusam.
- Bentuk bulat dan sederhana untuk kerang, ikan, teman.
- Teman bermata besar dan ekspresif (senang, kaget).
- Monster "lucu-seram", bukan horor.
- Warna zona berubah bertahap: pantai terang, laut dalam gelap dengan makhluk bercahaya, zona fantasi berwarna ajaib (kristal ungu, lava oranye, laut bintang).
- Warna rarity konsisten di semua tempat: putih, hijau, biru, ungu, emas, pelangi. Anak cepat hafal dan langsung heboh saat melihat cahaya emas.

**UX:**

- Mobile-first: joystick plus satu tombol, tombol besar, UI tidak menutupi layar, diuji di HP kelas bawah.
- Teks seminimal mungkin, perbanyak ikon, supaya anak yang belum lancar membaca tetap bisa main.
- Tiga tombol besar berikon setiap kali mutiara didapat (pakai, pajang, jual).
- Tombol "Upgrade Maks" untuk upgrade berulang.
- Layar sambutan saat kembali: Koin terkumpul dan kerang siap dibuka.

**Nama dan ikon:**

- Nama: Dive for Pearls (dengan emoji kerang di judul). Pola kata kerja + benda seperti Grow a Garden dan Steal an Egg. Perlu dicek apakah sudah dipakai game aktif di Roblox.
- Ikon: satu gambar jelas, misalnya kerang terbuka dengan mutiara bercahaya dan lumba-lumba di sampingnya.
- Siapkan 2–3 versi ikon dan uji dengan fitur uji thumbnail Roblox.

## Monetisasi dan kebijakan Roblox

Gacha teman memakai Tiket yang langka: gratis dari misi dan event, bisa dibeli dengan Robux saat habis. Koin boleh dijual karena tidak lagi membeli item acak.

| Item | Bayar dengan | Catatan |
| --- | --- | --- |
| Hatch instan kerang | Robux, harga mengikuti sisa waktu | Tombol kecil di samping countdown, tanpa pop-up berulang |
| 2x kecepatan matang selama 5 menit | Iklan berhadiah (13+) | Pemain di bawah 13 dapat jalur gratis setara, 1–2 kali sehari dari login atau hadiah waktu bermain |
| Koin bonus | Iklan berhadiah (13+) | Jumlahnya mengikuti progres, misalnya setara 10 menit penghasilan akuarium |
| Katalog: Koin, slot, gamepass, kosmetik | Robux | Aman karena tidak acak |
| Tiket Telur | Gratis dari misi dan event; Robux saat habis | Tiket berbayar = paid random item, aturan di bawah |
| Dihindari | — | Pop-up tawaran berulang, pengali berbayar tanpa batas |

**Aturan tiket berbayar:**

- Odds setiap teman ditampilkan di layar telur sebelum membuka.
- Teman tidak bisa di-trade sama sekali, jadi aturan larangan trading hasil paid random item otomatis terpenuhi. Yang di-trade hanya mutiara, yang selalu berasal dari kerang gratis.
- PolicyService: pemain di wilayah yang membatasi paid random items tidak bisa membeli tiket, tapi tetap bisa memakai tiket gratis.
- Pity berlaku untuk tiket gratis maupun berbayar.
- Total bonus stat dari teman dibatasi bersama pengali mutiara, supaya pembeli tiket tidak terlalu jauh di depan pemain gratis.

**Kebijakan Roblox yang wajib dipatuhi:**

- **Paid random items:** item acak yang dibeli dengan Robux, langsung maupun lewat mata uang yang dibeli dengan Robux, wajib menampilkan odds numerik. Hasilnya tidak boleh di-trade atau dijual untuk apa pun yang bernilai. Wajib memakai PolicyService untuk membatasi akses sesuai wilayah.
- **Boost peluang berbayar:** odds baru wajib diperbarui secara dinamis saat boost aktif.
- **Simulated gambling dilarang:** jangan pakai chip, taruhan, jackpot, atau gaya kasino. Setiap kerang dan telur selalu berisi sesuatu.
- **Disclosure:** isi Maturity and Compliance Questionnaire dengan jujur bila ada paid random items.

**Etika untuk target anak:** riset menemukan hubungan antara belanja loot box dan masalah judi pada remaja 16–18 tahun (Zendle dkk., 2019). Arah sebab-akibatnya belum pasti, tapi ini risiko reputasi nyata di mata orang tua.

**Iklan dan anak di bawah 13:** Roblox hanya menampilkan rewarded video ads ke pengguna 13 tahun ke atas, sedangkan target utama kita anak SD. Iklan tetap dipasang untuk pemain SMP–SMA, tapi pendapatan dari anak SD akan datang dari katalog dan tiket.

**Roblox Kids:** Roblox sedang menguji tipe akun berbasis umur, dan Indonesia termasuk wilayah awal. Game harus lolos tinjauan supaya bisa dimainkan akun anak, jadi monetisasi yang bersih juga kebutuhan bisnis. Syarat detailnya perlu dicek di DevForum sebelum rilis.

## MVP, roadmap, dan teknis

Rilis kecil tapi lengkap loop-nya, lalu update setiap Sabtu dengan jadwal yang diumumkan di depan. Konten 4 minggu pertama disiapkan sebelum rilis.

**Isi MVP:**

- [ ] Dermaga, Lift Gelembung, 2 zona (Pantai Dangkal, Terumbu Karang)
- [ ] Menyelam dengan oksigen tetap 90 detik, 1 jenis monster kecil, alur pingsan dan kerang jatuh
- [ ] Ruang Tekanan dengan level dan pengali mutiara
- [ ] Akuarium: kerang matang bertingkat, mutiara dipajang menghasilkan Koin per detik
- [ ] 6 rarity mutiara dengan pilihan pakai, pajang, jual
- [ ] Telur Laut (2 jenis), 8–10 teman, pity, gabung teman kembar, Lumba-lumba dan Anjing laut
- [ ] Pasang–surut real-time dan event Bulan Purnama
- [ ] Hadiah waktu bermain, layar sambutan saat kembali
- [ ] Grup Roblox dengan hadiah bergabung, sistem kode

**Roadmap:**

| Minggu | Update |
| --- | --- |
| Rilis | MVP |
| 1 | Sirip, teman baru (Penyu, Berang-berang) |
| 2 | Zona Senja, event Bulan Purnama besar |
| 3 | Trading mutiara |
| 4 | Raja Gurita, Panggung Buka Kerang |
| Berikutnya | Tabung Oksigen, zona dalam dan fantasi, event musiman, kolaborasi |

**Teknis wajib:**

- Semua pengacakan gacha dilakukan di server, tidak pernah di client.
- Penyimpanan data aman dan proteksi duplikasi item sebelum trading dibuka.
- Semua zona dalam satu place dengan streaming, supaya event serentak dan leaderboard server tetap hidup.
- Skala meteran kedalaman per zona.

**Analytics sejak hari pertama:** retensi hari ke-1 dan ke-7, durasi sesi rata-rata, menit saat pemain baru keluar, dan CTR thumbnail.

**Peluncuran:** rilis global (bahasa Inggris sederhana plus Indonesia), kode hadiah saat target like tercapai, klip TikTok/Shorts momen buka langka, dan kerja sama YouTuber Roblox Indonesia sebagai langkah awal.

**Validasi sebelum produksi penuh:** prototipe kecil (1 zona, 10 jenis kerang, 1 event) diuji ke 20–30 anak, lihat apakah mereka kembali keesokan harinya.

## Keputusan desain

Semua keputusan dipilih yang paling sederhana dibuat dan paling mudah ditambah konten tanpa mengubah kode.

| Topik | Keputusan | Alasan |
| --- | --- | --- |
| Efek Berang-berang | Sesekali mengupgrade kerang yang dipungut satu tingkat | Efeknya terlihat, tidak menumpuk luck tersembunyi |
| Nama | Dive for Pearls | Pencarian web tidak menemukan game Roblox dengan nama ini; tetap cek langsung di pencarian Roblox sebelum publish |
| Ambang Terumbu (50 m) | Dicapai lewat AFK singkat sekitar 2 menit di dalam tutorial | Sekaligus mengajarkan Ruang Tekanan, tanpa aturan khusus |
| Teman yang tidak dibawa | Masuk Index koleksi: setiap jenis unik +1% Koin (maks +50%), dan setiap 5 jenis unik memberi 1 Tiket | Koleksi tetap bernilai, dan reward-nya otomatis bertambah saat teman baru ditambahkan |
| Trading | Hanya mutiara; teman tidak bisa di-trade | Tidak perlu menandai asal teman, cocok dengan teman sebagai class, aman dengan tiket berbayar |
| Tiket Telur | 1 tiket = 1 telur di semua zona; telur zona dalam berisi pool teman lebih bagus | Satu harga, mudah dipahami, mudah ditambah zona |
| Pengali | Dijumlahkan (aditif), bukan dikalikan, dengan batas total | Angka tidak meledak saat konten bertambah |

## Balancing awal

Semua angka adalah titik awal untuk disimulasikan di spreadsheet lalu disesuaikan lewat playtest. Yang dikunci adalah rumusnya, supaya zona dan item baru cukup ditambah sebagai satu baris data.

**Ruang Tekanan:**

- Laju kedalaman: 0,5 × 1,15^(level − 1) meter per detik, dikali (1 + total bonus pengali).
- Harga upgrade: 20 × 1,25^(level − 1) Koin.
- Offline: berhenti. Setelah 2 jam AFK berturut-turut, laju turun menjadi 75%.

**Kerang:**

| Tingkat kerang | Peluang muncul | Waktu matang | Luck mutiara |
| --- | --- | --- | --- |
| Biasa | 70% | 1 menit | x1 |
| Bercahaya | 22% | 10 menit | x1,5 |
| Langka | 7% | 1 jam | x2 |
| Raksasa | 1% | 6 jam | x3 |

Peluang kerang bagus naik saat pemain mendekati dasar zona. Total luck dari semua sumber dibatasi x3.

**Mutiara** (nilai dasar di Pantai Dangkal):

| Rarity | Peluang dasar | Koin per detik dipajang | Harga jual | Bonus saat dipakai |
| --- | --- | --- | --- | --- |
| Putih | 60% | 1 | 30 | +5% |
| Pink | 25% | 3 | 90 | +10% |
| Biru | 10% | 10 | 300 | +20% |
| Emas | 4% | 40 | 1.200 | +40% |
| Hitam | 0,9% | 200 | 6.000 | +80% |
| Pelangi | 0,1% | 1.500 | 45.000 | +150% |

Rumus skala: nilai mutiara = nilai dasar × 4^(indeks zona), dengan Pantai = 0. Harga jual = Koin per detik × 30. Slot mutiara dipakai: 1 di MVP, sampai 3 lewat upgrade.

**Teman** (berlaku untuk setiap Telur Laut):

| Rarity | Peluang | Bonus stat pasif |
| --- | --- | --- |
| Biasa | 55% | +2% |
| Langka | 30% | +4% |
| Epik | 12% | +8% |
| Legendaris | 2,7% | +15% |
| Mitos | 0,3% | +25% |

Pity: Epik atau lebih dijamin setiap 20 tetasan, Legendaris atau lebih setiap 120 tetasan. Gabung 3 teman sama: bonus x1,5 per bintang. Total bonus teman dibatasi +100%.

**Akuarium:** 8 slot awal (kerang matang dan mutiara dipajang memakai slot yang sama), +2 slot per upgrade sampai 40. Harga: 100 × 2^(jumlah upgrade) Koin. Offline: 50% Koin, maksimal 8 jam.

**Tiket Telur.** Ada dua angka yang perlu ditentukan: berapa tiket gratis yang bisa didapat pemain, dan berapa harga tiket dalam Robux.

| Sumber tiket gratis | Jumlah |
| --- | --- |
| Menyelesaikan 3 misi harian | 1 per hari |
| Login hari ke-7 berturut-turut | +2 |
| Membuka zona baru | +2 |
| Setiap 5 jenis teman unik di Index | +1 |
| Event besar | 3–5 |

Target: pemain gratis yang aktif mendapat sekitar 8–10 tiket per minggu.

| Paket Robux | Harga |
| --- | --- |
| 1 tiket | 49 R$ |
| 5 tiket | 199 R$ |
| 15 tiket | 499 R$ |

Harga Robux adalah contoh dan perlu dibandingkan dengan game sejenis sebelum rilis.

## Arsitektur yang scalable

Konten baru (zona, mutiara, teman, telur, event) ditambah lewat data, bukan kode baru. Ini yang membuat update setiap Sabtu realistis untuk tim kecil.

- **Data-driven:** zona, mutiara, kerang, teman, telur, misi, dan event disimpan sebagai tabel konfigurasi (ModuleScript). Menambah zona = satu baris data + satu area peta.
- **Satu modul rumus:** semua rumus balancing (laju, harga, nilai, peluang) ada di satu tempat, supaya mudah disimulasikan dan diubah.
- **Server-authoritative:** semua pengacakan, pembelian, dan perhitungan Koin di server. Client hanya menampilkan.
- **Data pemain:** session locking dan schema berversi, supaya data aman saat update dan bebas duplikasi item sebelum trading mutiara dibuka.
- **Satu place dengan streaming:** semua zona di place yang sama, dimuat sesuai kebutuhan.
- **Event terjadwal dari konfigurasi:** jadwal event dan isinya diatur lewat data, bukan diedit manual setiap minggu.
- **Analytics bernama konsisten:** setiap aksi penting (selam, buka kerang, tetas, beli, keluar) dicatat dengan nama event yang sama sejak MVP.

**Pesaing yang perlu dipantau:** ada game Roblox bertema menyelam yang mengajak pemain menyelam ke dasar laut dan membawa pulang loot sebanyak mungkin sebelum waktu habis. Temanya mirip; pembeda kita ada di gacha mutiara, Ruang Tekanan, dan teman.

## Sumber

- [Roblox Creator Docs — Paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items)
- [Roblox DevForum — Simulated gambling policy](https://devforum.roblox.com/t/are-roulettes-the-casino-ones-allowed-on-roblox/3229821)
- [Roblox DevForum — Definition of gambling on Roblox](https://devforum.roblox.com/t/the-definition-of-gambling-on-roblox/1287336/5)
- [games.gg — Steal an Egg Speed Guide](https://games.gg/roblox/guides/steal-an-egg-speed-how-to-increase-speed-fast/)
- [StudioKrew — Top Roblox games, September 2026](https://studiokrew.com/blog/?p=2016)
- [RoWatcher — Is Steal An Egg dying?](https://rowatcher.com/games/10563114921/steal-an-egg/dying)
- [AllThings.How — Why Storage Hunters lost half its players](https://allthings.how/why-storage-hunters-open-world-lost-half-its-roblox-players/)
- [RoWatcher — Fastest-growing Roblox games, March 2026](https://rowatcher.com/news/the-10-fastest-growing-roblox-games-in-march-2026)
- [Ryan, Rigby, Przybylski (2006) — The motivational pull of video games](https://www.rochester.edu/news/printable.php?id=2719)
- [Loewenstein — Information gap theory of curiosity](https://nautil.us/curiosity-depends-on-what-you-already-know-235803)
- [Zendle, Meyer, Over (2019) — Adolescents and loot boxes](https://pmc.ncbi.nlm.nih.gov/articles/PMC6599795)

* [Roblox DevForum — More creators can now use Rewarded Video Ads](https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678)
* [Roblox Creator Docs — Rewarded video ads](https://create.roblox.com/docs/en-us/production/promotion/rewarded-video-ads)
* [Gaming Amigos — Roblox advertising policy overhaul](https://www.gamingamigos.com/post/roblox-overhaul-advertising-policies)
* [Roblox DevForum — Roblox Kids and Select global launch](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717)
