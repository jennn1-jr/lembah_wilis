# Wisata Lembah Wilis

Aplikasi operasional internal untuk pencatatan tiket, pemeriksaan penutupan
harian, dan pemantauan laporan Wisata Lembah Wilis.

## Peran pengguna

- **Loket** mencatat rentang nomor seri tiket, tiket gratis, dan pembayaran;
  laporan dapat disimpan sebagai draft atau dikirim ke Kasir.
- **Kasir** memeriksa tiket dan pembayaran, mencatat temuan atau koreksi, lalu
  memverifikasi laporan.
- **Pengelola** melihat laporan terverifikasi, ringkasan operasional, grafik
  pendapatan, serta mengelola kategori tiket dan mengekspor laporan ke CSV,
  Excel, atau PDF.

## Data dan alur

- Akun dibaca dari `users/{emailLowercase}` dan memiliki role `loket`, `kasir`,
  atau `pengelola`.
- Laporan harian disimpan pada `daily_reports/{YYYY-MM-DD}`. Temuan dan koreksi
  berada pada subcollection `discrepancies` dan `corrections`.
- Kategori tiket disimpan pada `ticket_types`.
- Jumlah tiket fisik dihitung dari rentang nomor seri inklusif. Tiket berbayar
  adalah tiket fisik dikurangi tiket gratis. Pendapatan adalah tunai ditambah
  QRIS/transfer.
- Indeks Firestore yang diperlukan tercatat di [firestore.indexes.json](./firestore.indexes.json).

Firestore Rules tidak disimpan di repository ini. Pastikan Rules yang aktif
membatasi setiap operasi berdasarkan autentikasi dan role sebelum aplikasi
digunakan dalam operasional.

## Menjalankan aplikasi

Gunakan Flutter yang mendukung Dart SDK `^3.9.0`, lalu jalankan:

```shell
flutter pub get
flutter run
```

Konfigurasi Firebase platform tersedia pada `lib/firebase_options.dart`.
Jangan menyimpan service-account key atau kredensial admin di aplikasi klien.

## Validasi

```shell
dart format .
flutter analyze --no-pub
flutter test --no-pub
```

## Checklist sebelum rilis

- Verifikasi Firestore Rules pada proyek Firebase yang akan digunakan.
- Siapkan signing key rilis dan application ID yang telah didaftarkan pada
  Firebase; konfigurasi development saat ini bukan signing produksi.
- Uji unduhan CSV, XLSX, dan PDF pada perangkat/browser target.
- Uji tampilan serta alur tiap role pada ponsel, tablet, dan desktop.
