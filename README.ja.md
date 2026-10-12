# hk-lineageos-build-on-dgx-spark

[English](README.md) | **日本語**

NVIDIA DGX Spark（ARM64、Ubuntu 24.04）で LineageOS 24.0（Android 17）をビルドするための手順と記録。

AOSP と LineageOS が公式にサポートしているビルドのホストは x86_64 だけです。この記録は非公式の実験で、
結果は保証しません。

## 結果の一覧

| 日付 | 対象 | ソース | 結果 | 時間 |
|---|---|---|---|---|
| 2026-10-04 | カーネル：`LineageOS/android_kernel_asus_sdm660`（Asus X00TD 用の設定） | lineage-24.0 @ `a598e30e2dd2`（4.19.325） | **成功**（ホストの clang 18） | 約 135 秒 |
| 2026-10-04 | 同上、ホストの gcc 13 | 同上 | 失敗（下の「既知の問題」） | — |
| 2026-10-05 | Android 全体：`lineage_X00TD-cp2a-userdebug` → `m bacon` | lineage-24.0 | **成功**（LFI の検証は有効、制約は「手順 2」） | 通算は未計測 |
| 2026-10-05 以降 | 別の sdm660 の端末（device tree は非公開）：`userdebug` の全体と、`system` `system_ext` `product` `vendor` `odm` の 5 つのイメージ | lineage-24.0、同じパッチ | **成功**（同じ制約。パッチの追加はなし） | 最初の通しは X00TD の出力を再利用して 13 分 40 秒。以後の 5 イメージは増分 |

この記録が示すのは「ビルドが通ること」までで、公式のビルドとバイナリは同じになりません（下の比較）。

## 環境

| 項目 | 値 |
|---|---|
| 機械 | NVIDIA DGX Spark（DGX OS 7.2.3） |
| CPU | 20 コア（Cortex-X925 ×10 ＋ Cortex-A725 ×10） |
| メモリ | 128 GB（LPDDR5x、CPU と GPU で共有） |
| OS | Ubuntu 24.04.4 LTS、Linux 6.17.0-1031-nvidia、aarch64 |
| ディスク | カーネルだけなら 5 GB。Android 全体はソース約 220 GB ＋ ビルド出力（合わせて 400 GB 以上を見込む） |

入れたパッケージ（Ubuntu 24.04 の標準のリポジトリ、2026-10-04 の版）：

| パッケージ | 版 |
|---|---|
| clang / lld / llvm | 1:18.0-59~exp2（clang 18.1.3） |
| device-tree-compiler | 1.7.0-2build1 |
| libssl-dev | 3.0.13-0ubuntu3.16 |
| libelf-dev | 0.190-1.1ubuntu0.1 |
| lz4 | 1.9.4-1build1.1 |
| ccache | 4.9.1-1 |
| gcc（参考） | 4:13.2.0-7ubuntu1 |
| make / bison / flex / m4 / bc / cpio | 4.3 / 3.8.2 / 2.6.4 / 1.4.19 / 1.07.1 / 2.15 |

## 手順 1：カーネル

LineageOS の sdm660 の 4.19 カーネルは arm64 のターゲットなので、DGX Spark ではホストの道具でそのまま
ネイティブにビルドできます。AOSP の x86_64 の prebuilts（clang、kernel-build-tools）は要りません。

```sh
git clone https://github.com/jetbee/hk-lineageos-build-on-dgx-spark
cd hk-lineageos-build-on-dgx-spark

# 1. パッケージを入れる（sudo が要ります）
./scripts/setup-host.sh

# 2. ソースを取る（約 1.4 GB）
git clone --depth=1 -b lineage-24.0 \
  https://github.com/LineageOS/android_kernel_asus_sdm660 ~/src/android_kernel_asus_sdm660

# 3. ビルドする（X00TD の設定）
./scripts/build-kernel.sh ~/src/android_kernel_asus_sdm660 X00TD
#   → ~/src/android_kernel_asus_sdm660/out-X00TD/arch/arm64/boot/Image.gz-dtb

# 4. （任意）prebuilt kernel として使う一式を作る
./scripts/package-kernel.sh ~/src/android_kernel_asus_sdm660 out-X00TD
#   → Image.gz-dtb、config、kernel-headers/、BUILD_INFO.txt、SHA256SUMS
```

`build-kernel.sh` がしていること：

```sh
CFG="vendor/sdm660-perf_defconfig vendor/common.config vendor/debugfs.config vendor/X00TD.config"
make O=out-X00TD ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang $CFG
make O=out-X00TD ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang -j$(nproc)
```

- ホストが aarch64 なので、`CROSS_COMPILE` は要りません。
- 出力は `Image.gz-dtb`（Image.gz の後ろに dtb を付けた形。X00TD のデバイスツリーの `BOARD_KERNEL_IMAGE_NAME` と同じ）。
- LineageOS の公式のビルドが使うのは AOSP の prebuilt clang です。ここで使っているのは Ubuntu の clang 18 なので、出来たものはバイナリとしては同じになりません。

## 手順 2：Android 全体

`lineage_X00TD-cp2a-userdebug` の `m bacon` が、DGX Spark 上で最後まで通りました（2026-10-05。ソースは lineage-24.0）。
失敗を直しながら何度も再開したため、通算の所要時間は測っていません（最後の 2 回の再開は、増分で 6〜14 分でした）。
そのあと、別の sdm660 の端末（device tree は非公開）の全体と 5 つのイメージも、追加の修正なしで通りました。
**公式のビルドとは別物**です。下の「制約」を読んでください。

### 段取り

1. パッケージ：`scripts/setup-host.sh`（`imagemagick` と `python3-pil` はブートアニメーション用の `mogrify` のため）。
2. ソース：lineage-24.0 を `repo sync`（X00TD の local_manifests とブロブを含めて約 220 GB）。
3. ARM64 の prebuilts：`scripts/fetch-arm64-prebuilts.sh`（clang、Go、Rust、JDK 21。出どころは公式の配布元で、
   版・URL・sha256 は `SOURCES.txt` に残ります）。
4. Rust：`scripts/make-rust-musl-toolchain.sh`（musl 版の rustc を組みます。理由はスクリプトの冒頭）。
5. prebuilts をツリーから見えるようにする：`scripts/place-arm64-prebuilts.sh`（シンボリックリンクだけ）。
6. ホスト arm64 用の修正を当てる：`scripts/apply-patches.sh <ツリー>`（`patches/` の 13 プロジェクト・16 本を `git am` します。
   コミッターの名前とメールは環境変数か `git config` で用意してください）。
7. bison：当てたあと、`prebuilts/build-tools/linux-arm64/bin/bison` を `bison.real` に改名し、
   `scripts/bison-arm64-wrapper.sh` を `bison`（実行可能）として置きます（バイナリはパッチに入れていないためです）。
8. ビルド：`scripts/build-full.sh <ツリー> lineage_X00TD-cp2a-userdebug <ログ>`（既定の対象は `bacon`）。
   イメージだけなら `scripts/build-images.sh <ツリー> <lunch の対象> <ログ> systemimage vendorimage ...`。

注：`make-rust-musl-toolchain.sh` と `build-images.sh`（ダミーのツリーで、`-j` の自動決定と古い時刻の対策の動作）は、単体で確認しました。
`place-arm64-prebuilts.sh` と `apply-patches.sh` は、この記録で手で行った操作をまとめたもので、
パッチは元のコミットの直前の状態に当たる（`git apply --check` と、当てた結果が元のブランチと一致）ことまで確認しました。
まとめた形でのツリー全体の通し実行は、確認していません。

### 直したことと理由（要約。`patches/` の各パッチに詳しい説明があります）

| 場所 | 内容 |
|---|---|
| `build/make` | aarch64 を `HOST_ARCH=arm64`、`linux-arm64` として扱う。`HOST_OUT` を Soong に合わせる。`clang/HOST_arm64.mk` を追加 |
| `build/soong` | Rust の host 側（musl の std、`RUSTC_BOOTSTRAP=1`）、`host_second_srcs`（32 ビットの host が無い）、Common のインストール先、サンドボックスに musl のローダーと libc++ を入れる（bison、m4 など）、x86 専用のコンパイラ引数（`-msse3` など）を落とす |
| `prebuilts/build-tools` | bison、flex、m4、make に arm64 の対象を足す。bison はデータの場所を自分のパスから決めるので、ラッパーで補う（`bison.real`） |
| `prebuilts/jdk/jdk21`、`tools-lineage`、`clang/host/linux-x86` | javap、mogrify（ImageMagick が無ければ Pillow で代用）、llvm の道具を arm64 に向ける |
| `vendor/lineage` | カーネルの host ツールを、機械の libc と、システムの lz4（あれば pahole）でビルドする（x86 の sysroot と lz4 を使わない） |
| `bionic` | カーネルヘッダーの清掃ツールが読む libclang を arm64 のものにする |
| `system/sepolicy` | `getopt()` の戻り値を `char` ではなく `int` で受ける（aarch64 の `char` は unsigned で、`-1` と比べても終わらない。全体に `-fsigned-char` を付ける方法は、toybox を壊したので採りませんでした） |
| `system/librustutils`、`prebuilts/rust-toolchain`、`external/rust` | arm64 の host でも、ビルド済みの std（対になる proc_macro がある）を使う。`aarch64-paging` は端末だけで有効にする |
| `frameworks/libs/binary_translation` | berberis の生成ツールを arm64 のホストで有効にする（解析を通すため。x86 エミュレータは作りません） |

環境変数（`scripts/build-images.sh` が設定します）：`SOONG_NINJA=ninja`（siso は x86 専用）、
`SKIP_ABI_CHECKS=true`（arm64 の `header-abi-dumper` が無い）、`SOONG_DISABLE_CLIPPY=true`（arm64 の `clippy-driver` が無い）、
`THINLTO_USE_MLGO=false`（arm64 の clang には MLGO のモデルが無い）、`OUT_DIR=out`（絶対パスだと Soong が止まる箇所がある。
別のディスクに置くときは `out` をシンボリックリンクにする）。ビルドは `env -i` のきれいな環境で走らせます
（シェルの `grep` を別のものに置き換える関数などがビルドのスクリプトに入り込むのを防ぐため）。

### 制約（今の版で、公式のビルドと違うところ）

- **clang の名前に注意**：LineageOS は `clang-r596125` を指定します（`vendor/lineage` の release の設定）。Google は
  その arm64 版を出していないので、この記録では `clang-r584948b`（22.0.1）を `clang-r596125` と `clang-stable` の名前で
  使っています。ツリーの表示は r596125 でも、中身は r584948b です。MLGO（機械学習の最適化）は無効です。
  このため、ネイティブのコードはバイナリとして公式と同じになりません（下の比較）。
- **LFI**（Android 17 の軽量サンドボックス）：r584948b の LFI 書き換えは、`memset` の `dc zva` を書き換えません。
  新しい `lfi-verify` が `dc zva must use x28` で止まります（`libopus` の `memset` 部分）。この記録では、x86 のホストで
  r596125 を使って作った `libopus_lfi_bin`（LFI の検証を通ったもの）を借りて、**検証を有効のまま**通しました。
  借りたバイナリはこのリポジトリに含めません（ビルドの成果物で、再現できる形の入手方法がありません）。
  検証を飛ばす方法もありますが、そのビルドは配布にも公式の提出にも使えないので、ここでは扱いません。
- **arm64 版の `clang-r596125` が出たら**：(1) 取ってきて `clang-r596125` と `clang-stable` のリンク先を替える、
  (2) 借りた LFI のバイナリをやめる、(3) `THINLTO_USE_MLGO=false` を外す。それで済む構えです。
- ImageMagick（`mogrify`）は `apt install imagemagick`。ツリーの arm64 用 `mogrify` は、システムの `/usr/bin/mogrify` があればそれを呼び、
  無ければ Pillow で代用します（ブートアニメーションの画素が少し変わる可能性があります）。
- ビルドのサンドボックス（nsjail）は x86 専用です。「Build sandboxing disabled due to nsjail error」と出ますが、想定の動きです（sbox は使われます）。

### 気をつけること

- **古い時刻の罠**：`rsync -a` のように時刻を保つコピーでプロジェクトを更新すると、前のビルドの途中で変えたファイルが
  前の出力より古く見え、ninja が飛ばして、イメージに古い内容が残ることがあります。`scripts/build-images.sh` は、
  `STALE_REPOS` に挙げたプロジェクトで、最後に成功したビルドのコミットから変わったファイルの時刻を更新してから始めます。
- **`-j`（並列数）とメモリ**：メモリは他の処理と共有しています。`build-images.sh` は、空きメモリ ÷ 3 GB（2 以上、`nproc` 以下）を使います。
  3 GB は目安で、**測った値ではありません**。128 GB の機械で `-j20` を使って、メモリ不足は起きていません。ピークは測っていません。
- ビルドが失敗したら、同じコマンドで再開できます（増分）。最初の失敗で止まるのは ninja の既定の動きです。

### x86 のビルドとの比較（X00TD）

ファイル単位のチェックサムの比較（`rsync -rnc` のドライラン、symlink 除く）です。

| 種類 | ファイル数 | 違い | 一致 |
|---|---:|---:|---:|
| ネイティブ（.so、bin） | 3003 | 1921 | 1082 |
| その他（apex、データ） | 3577 | 55 | 3522 |
| テキスト／設定 | 977 | 9 | 968 |
| dex2oat（odex、vdex、art） | 518 | 355 | 163 |
| メディア／フォント | 507 | 0 | 507 |
| apk | 174 | 66 | 108 |
| jar／dex | 56 | 4 | 52 |
| 合計 | 8812 | 2410 | 6402（72.7%） |

- ファイルの集合は同じです（片側にしかないファイルは 0）。
- 違うテキストは、`build.prop` 系（日時、ホスト、fingerprint）と `build-manifest.xml` だけです。
- ネイティブ、それを含む apex、それに依存する dex2oat が違うのは、コンパイラ（clang の版と MLGO）の違いです。
- `framework.jar` など jar 4 個は `classes.dex` だけが違います。javac の出力と `d8.jar` は一致しており、原因は未特定です。
- 結論：バイナリ同一は、コンパイラが違うので望めません。ネイティブのコンパイラとビルドのメタ情報に依存しない部分は、一致します。

## 既知の問題と制約

- **公式には未対応**：AOSP と LineageOS のビルドのホストは x86_64 だけがサポートされています。ここでの手順は、上流の更新で壊れることがあります。
- **gcc 13 ではカーネルが通らない**：`kernel/sched/walt.h` と `include/trace/events/sched.h` で、printf の書式と引数の型が合わず、`-Werror=format` で止まります。Qualcomm のコードは clang を前提にしているので、clang を使ってください。
- **libssl-dev が要る**：無いと `scripts/extract-cert.c` で `openssl/bio.h` が無いと言われて止まります。
- **ソースを更新したとき**：新しい clang の警告が `-Werror` で止まる場合があります。記録した版（上の表）から始めてください。

## リポジトリの中身

| パス | 中身 |
|---|---|
| `scripts/setup-host.sh` | パッケージの導入 |
| `scripts/build-kernel.sh` | sdm660 カーネルのビルド |
| `scripts/package-kernel.sh` | prebuilt kernel の一式の作成 |
| `scripts/fetch-arm64-prebuilts.sh` | arm64 の prebuilts（clang、Go、Rust、JDK）の取得と、出どころの記録 |
| `scripts/make-rust-musl-toolchain.sh` | arm64 ホスト用の Rust（musl の rustc とローダーのラッパー） |
| `scripts/place-arm64-prebuilts.sh` | arm64 の prebuilts をツリーに見せるシンボリックリンク |
| `scripts/apply-patches.sh` | `patches/` をツリーに `git am` で当てる |
| `scripts/bison-arm64-wrapper.sh` | arm64 の bison がデータの場所を見つけるためのラッパー |
| `scripts/build-images.sh` | きれいな環境で、`-j` の自動決定と古い時刻の対策つきで、イメージをビルドする |
| `scripts/build-full.sh` | `build-images.sh` を呼んで全体（`bacon`）をビルドする |
| `patches/` | ホスト arm64 用の修正（プロジェクトごとの `git am` 用パッチ、13 プロジェクト・16 本） |
| `tools/dts-extract.py` | dtc で逆にした DTS から 1 つのノードを取り出し、phandle の番号をラベルに書き換える |
| `tools/dt-devname-hashes.py`、`tools/dsi-cmds-format.py` | デバイスツリーの調査用の小さな道具 |

## 出典

- Actinis, "Building AOSP on ARM64: From an 8 GB Jetson to DGX Spark"（2026-06-26） https://actinis.io/blog/building-aosp-on-arm64
  — ARM64 のホストで AOSP をビルドするための修正の項目と、DGX Spark での所要時間（2 時間 13 分）。
  このリポジトリの修正は、記事の考え方を参考に書き直したもので、記事の diff は含みません。
- LineageOS https://github.com/LineageOS

## ライセンス

Apache License 2.0（`LICENSE`）。
